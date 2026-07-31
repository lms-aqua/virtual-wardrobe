"""Garment catalog (shared, not user-owned). Assets are served via signed URLs
from the private garments bucket."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_admin_user, get_current_user, get_db, settings_dep
from wardrobe_core.models import Garment, GarmentSize, User
from wardrobe_core.schemas import GarmentCreate, GarmentOut, GarmentUpdate
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


# ---- Admin CRUD ----
@router.post("", response_model=GarmentOut, status_code=201)
async def create_garment(
    payload: GarmentCreate,
    _: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> GarmentOut:
    g = Garment(
        brand=payload.brand, name=payload.name, category=payload.category,
        gender_neutral=payload.gender_neutral, layering_order=payload.layering_order,
        price_cents=payload.price_cents, product_url=payload.product_url,
        fabric_props=payload.fabric_props,
    )
    for s in payload.sizes:
        g.sizes.append(GarmentSize(size_label=s.size_label, measurements=s.measurements))
    db.add(g)
    await db.flush()
    await db.refresh(g, attribute_names=["sizes"])
    return _serialize(g, settings)


@router.patch("/{garment_id}", response_model=GarmentOut)
async def update_garment(
    garment_id: uuid.UUID,
    payload: GarmentUpdate,
    _: User = Depends(get_admin_user),
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
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(g, field, value)
    await db.flush()
    return _serialize(g, settings)


@router.delete("/{garment_id}", status_code=204)
async def delete_garment(
    garment_id: uuid.UUID,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    g = await db.get(Garment, garment_id)
    if g is None:
        raise HTTPException(status_code=404, detail="not found")
    await audit.record(db, action="garment.deleted", actor_user_id=admin.id,
                       target_type="garment", target_id=str(g.id))
    await db.delete(g)
