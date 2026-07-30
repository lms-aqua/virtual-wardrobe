"""Garment catalog (shared, not user-owned). Assets are served via signed URLs
from the private garments bucket."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.models import Garment, User
from wardrobe_core.schemas import GarmentOut
from wardrobe_core.storage import get_storage

router = APIRouter(prefix="/garments", tags=["garments"])


def _serialize(g: Garment, settings: Settings) -> GarmentOut:
    storage = get_storage()
    out = GarmentOut.model_validate(g)
    if g.thumb_key:
        out.thumb_url = storage.presign_get(settings.s3_bucket_garments, g.thumb_key)
    if g.mesh_key:
        out.mesh_url = storage.presign_get(settings.s3_bucket_garments, g.mesh_key)
    return out


@router.get("", response_model=list[GarmentOut])
async def list_garments(
    _: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> list[GarmentOut]:
    rows = (
        await db.execute(
            select(Garment).options(selectinload(Garment.sizes)).order_by(Garment.name)
        )
    ).scalars().all()
    return [_serialize(g, settings) for g in rows]


@router.get("/{garment_id}", response_model=GarmentOut)
async def get_garment(
    garment_id: uuid.UUID,
    _: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> GarmentOut:
    g = (
        await db.execute(
            select(Garment).where(Garment.id == garment_id).options(selectinload(Garment.sizes))
        )
    ).scalar_one_or_none()
    if g is None:
        raise HTTPException(status_code=404, detail="not found")
    return _serialize(g, settings)
