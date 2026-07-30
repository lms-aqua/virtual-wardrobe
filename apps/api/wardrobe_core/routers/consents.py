"""Consent endpoints. Consent is append-only; the 'current' view returns the
latest non-revoked consent per kind."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.deps import get_current_user, get_db
from wardrobe_core.models import Consent, User
from wardrobe_core.schemas import ConsentCreate, ConsentOut

router = APIRouter(prefix="/consents", tags=["consents"])


@router.post("", response_model=ConsentOut, status_code=201)
async def grant_consent(
    payload: ConsentCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Consent:
    consent = Consent(user_id=user.id, kind=payload.kind, version=payload.version)
    db.add(consent)
    await audit.record(
        db, action="consent.granted", actor_user_id=user.id,
        target_type="consent", meta={"kind": payload.kind.value, "version": payload.version},
    )
    await db.flush()
    return consent


@router.get("/current", response_model=list[ConsentOut])
async def current_consents(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[Consent]:
    rows = (
        await db.execute(
            select(Consent)
            .where(Consent.user_id == user.id, Consent.revoked_at.is_(None))
            .order_by(Consent.granted_at.desc())
        )
    ).scalars().all()
    return list(rows)
