"""FastAPI dependencies: DB session, authenticated user, rate limiting.

Auth accepts either an ``Authorization: Bearer <token>`` header (native apps,
tests) or the httpOnly session cookie (web). Both resolve to the same signed
session token, which is an opaque reference to a Session row — so a revoked or
expired session is rejected immediately regardless of transport.
"""

from __future__ import annotations

import time
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core.config import Settings, get_settings
from wardrobe_core.db import get_session
from wardrobe_core.enums import UserStatus
from wardrobe_core.models import Session, User
from wardrobe_core.security import read_session_token


async def get_db() -> AsyncIterator[AsyncSession]:
    async for s in get_session():
        yield s


def settings_dep() -> Settings:
    return get_settings()


def _extract_token(request: Request) -> str | None:
    auth = request.headers.get("Authorization")
    if auth and auth.lower().startswith("bearer "):
        return auth[7:].strip()
    return request.cookies.get(get_settings().session_cookie_name)


async def get_current_user(
    request: Request, db: AsyncSession = Depends(get_db)
) -> User:
    token = _extract_token(request)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="not authenticated")

    raw_session_id = read_session_token(token)
    if not raw_session_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid session")
    try:
        session_id = uuid.UUID(raw_session_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid session"
        ) from None

    session = await db.get(Session, session_id)
    now = datetime.now(UTC)
    expires_at = session.expires_at if session else None
    # SQLite returns naive datetimes; normalize to UTC for a safe comparison.
    if expires_at is not None and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if (
        session is None
        or session.revoked_at is not None
        or expires_at is None
        or expires_at <= now
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="session expired")

    user = await db.get(User, session.user_id)
    if user is None or user.status != UserStatus.active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="no active user")
    return user


async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="admin_only")
    return user


# ---- Rate limiter: Redis-backed (shared across instances), in-process fallback ----
_hits: dict[str, list[float]] = {}
_redis = None


def _get_redis():  # noqa: ANN202
    global _redis
    if _redis is None:
        import redis.asyncio as aioredis

        _redis = aioredis.from_url(
            get_settings().effective_redis_url,
            decode_responses=True,
            socket_connect_timeout=0.25,
            socket_timeout=0.25,
        )
    return _redis


def rate_limit(bucket: str, limit: int, window_seconds: int):  # noqa: ANN201
    async def _dep(request: Request) -> None:
        ip = request.client.host if request.client else "unknown"
        key = f"rl:{bucket}:{ip}"
        # Try Redis first (works across scaled-out instances).
        try:
            r = _get_redis()
            n = await r.incr(key)
            if n == 1:
                await r.expire(key, window_seconds)
            if n > limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="rate limited"
                )
            return
        except HTTPException:
            raise
        except Exception:  # noqa: BLE001 — Redis unavailable → local fallback
            pass
        now = time.monotonic()
        window = _hits.setdefault(key, [])
        cutoff = now - window_seconds
        window[:] = [t for t in window if t > cutoff]
        if len(window) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="rate limited"
            )
        window.append(now)

    return _dep


# Re-export select for routers that need ad-hoc queries.
__all__ = ["get_db", "get_current_user", "rate_limit", "settings_dep", "select"]
