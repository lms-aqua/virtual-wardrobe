"""Current-user endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.enums import DeletionScope
from wardrobe_core.models import DeletionRequest, User
from wardrobe_core.schemas import DeletionRequestOut, UserOut
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
