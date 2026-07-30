"""Authentication: email magic links (+ Sign in with Apple stub).

Dev/test flow: POST /auth/magic-link returns the token so the flow can complete
without real email. In production the token is only emailed and the response is
``{sent: true}``. Verifying a token creates the user (if new), records adult
attestation, opens a Session, sets the httpOnly cookie, and returns a bearer
token for native clients.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_db, rate_limit, settings_dep
from wardrobe_core.logging import get_logger, mask_email
from wardrobe_core.models import Session, User
from wardrobe_core.schemas import (
    AuthTokenResponse,
    MagicLinkDevResponse,
    MagicLinkRequest,
    MagicLinkVerify,
)
from wardrobe_core.security import make_magic_token, make_session_token, read_magic_token

router = APIRouter(prefix="/auth", tags=["auth"])
log = get_logger("auth")


@router.post(
    "/magic-link",
    response_model=MagicLinkDevResponse,
    dependencies=[Depends(rate_limit("magic-link", limit=5, window_seconds=300))],
)
async def request_magic_link(
    payload: MagicLinkRequest, settings: Settings = Depends(settings_dep)
) -> MagicLinkDevResponse:
    if not payload.is_adult:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="adults_only: you must attest that you are 18 or older",
        )
    token = make_magic_token(payload.email, is_adult=payload.is_adult)
    # TODO(phase-8): send via SMTP/MailHog. For now we log a masked line.
    log.info("magic_link.issued", email=mask_email(payload.email))
    return MagicLinkDevResponse(sent=True, dev_token=None if settings.is_production else token)


@router.post("/magic-link/verify", response_model=AuthTokenResponse)
async def verify_magic_link(
    payload: MagicLinkVerify,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> AuthTokenResponse:
    data = read_magic_token(payload.token)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="invalid or expired token"
        )
    email = data["email"]
    user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
    if user is None:
        user = User(email=email, is_adult=bool(data.get("is_adult")))
        db.add(user)
        await db.flush()
        await audit.record(db, action="user.created", actor_user_id=user.id)

    session = Session(
        user_id=user.id,
        expires_at=datetime.now(timezone.utc) + timedelta(seconds=settings.session_ttl_seconds),
    )
    db.add(session)
    await db.flush()

    token = make_session_token(str(session.id))
    response.set_cookie(
        key=settings.session_cookie_name,
        value=token,
        max_age=settings.session_ttl_seconds,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="strict",
        path="/",
    )
    await audit.record(db, action="auth.login", actor_user_id=user.id)
    return AuthTokenResponse(access_token=token, user_id=user.id)


@router.post("/apple", response_model=AuthTokenResponse)
async def sign_in_with_apple() -> AuthTokenResponse:
    # Interface reserved. Real implementation validates the Apple identity token
    # (JWKS + audience/issuer checks) and maps apple_sub → user. Disabled until
    # APPLE_* env is configured.
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Sign in with Apple not configured in this environment",
    )
