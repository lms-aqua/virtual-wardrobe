"""Account deletion request endpoint (idempotent)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.models import DeletionRequest, User
from wardrobe_core.schemas import DeletionRequestIn, DeletionRequestOut
from wardrobe_core.services.deletion import run_deletion_request

router = APIRouter(prefix="/account", tags=["account"])


@router.post("/deletion-request", response_model=DeletionRequestOut, status_code=202)
async def request_deletion(
    payload: DeletionRequestIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> DeletionRequest:
    if idempotency_key:
        existing = (
            await db.execute(
                select(DeletionRequest).where(
                    DeletionRequest.user_id == user.id,
                    DeletionRequest.idempotency_key == idempotency_key,
                )
            )
        ).scalar_one_or_none()
        if existing:
            return existing

    req = DeletionRequest(user_id=user.id, scope=payload.scope, idempotency_key=idempotency_key)
    db.add(req)
    await audit.record(
        db, action="account.deletion_requested", actor_user_id=user.id,
        meta={"scope": payload.scope.value},
    )
    await db.commit()

    if settings.run_jobs_inline:
        await run_deletion_request(req.id)
        await db.refresh(req)
    return req
