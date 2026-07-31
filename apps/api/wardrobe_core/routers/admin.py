"""Admin-only endpoints: audit log query + basic stats."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core.deps import get_admin_user, get_db
from wardrobe_core.models import Avatar, AuditEvent, BodyScan, Garment, Outfit, User
from wardrobe_core.schemas import AuditEventOut

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/audit", response_model=list[AuditEventOut])
async def audit_log(
    _: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    action: str | None = Query(default=None),
    limit: int = Query(default=100, le=500),
) -> list[AuditEvent]:
    stmt = select(AuditEvent).order_by(AuditEvent.created_at.desc()).limit(limit)
    if action:
        stmt = stmt.where(AuditEvent.action == action)
    rows = (await db.execute(stmt)).scalars().all()
    return list(rows)


@router.get("/stats")
async def stats(
    _: User = Depends(get_admin_user), db: AsyncSession = Depends(get_db)
) -> dict[str, int]:
    async def count(model) -> int:  # noqa: ANN001
        return int((await db.execute(select(func.count()).select_from(model))).scalar() or 0)

    return {
        "users": await count(User),
        "scans": await count(BodyScan),
        "avatars": await count(Avatar),
        "garments": await count(Garment),
        "outfits": await count(Outfit),
    }
