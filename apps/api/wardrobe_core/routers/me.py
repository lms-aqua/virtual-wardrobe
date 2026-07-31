"""Current-user endpoints."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.enums import DeletionScope
from wardrobe_core.models import DeletionRequest, Session, User, UserPreference
from wardrobe_core.schemas import (
    DeletionRequestOut,
    PreferenceIn,
    PreferenceOut,
    SessionOut,
    UserOut,
)
from wardrobe_core.services.deletion import run_deletion_request

router = APIRouter(tags=["me"])


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)) -> User:
    return user


@router.delete("/me", response_model=DeletionRequestOut)
async def delete_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> DeletionRequest:
    """Permanently delete the account: scans, avatars, measurements, outfits."""
    req = DeletionRequest(user_id=user.id, scope=DeletionScope.full_account)
    db.add(req)
    await audit.record(db, action="account.deletion_requested", actor_user_id=user.id)
    await db.commit()
    if settings.run_jobs_inline:
        await run_deletion_request(req.id)
        await db.refresh(req)
    return req


# ---- Preferences sync (units, customization, favorites, …) ----
@router.get("/me/preferences", response_model=PreferenceOut)
async def get_preferences(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> PreferenceOut:
    pref = (
        await db.execute(select(UserPreference).where(UserPreference.user_id == user.id))
    ).scalar_one_or_none()
    if pref is None:
        return PreferenceOut(data={}, updated_at=datetime.now(UTC))
    return PreferenceOut(data=pref.data, updated_at=pref.updated_at)


@router.put("/me/preferences", response_model=PreferenceOut)
async def put_preferences(
    payload: PreferenceIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PreferenceOut:
    pref = (
        await db.execute(select(UserPreference).where(UserPreference.user_id == user.id))
    ).scalar_one_or_none()
    if pref is None:
        pref = UserPreference(user_id=user.id, data=payload.data)
        db.add(pref)
    else:
        pref.data = payload.data
    await db.flush()
    await db.refresh(pref)
    return PreferenceOut(data=pref.data, updated_at=pref.updated_at)


# ---- Session / device management ----
@router.get("/me/sessions", response_model=list[SessionOut])
async def list_sessions(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[Session]:
    rows = (
        await db.execute(
            select(Session)
            .where(Session.user_id == user.id, Session.revoked_at.is_(None))
            .order_by(Session.created_at.desc())
        )
    ).scalars().all()
    return list(rows)


@router.delete("/me/sessions/{session_id}", status_code=204)
async def revoke_session(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    sess = await db.get(Session, session_id)
    if sess is None or sess.user_id != user.id:
        raise HTTPException(status_code=404, detail="not found")
    sess.revoked_at = datetime.now(UTC)
    await audit.record(db, action="session.revoked", actor_user_id=user.id,
                       target_type="session", target_id=str(sess.id))
