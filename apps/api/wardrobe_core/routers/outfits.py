"""Outfit CRUD. Outfits are user-owned; cross-account access returns 404.
Saved outfits sync across devices because they are fetched by the same account
from any client."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.deps import get_current_user, get_db
from wardrobe_core.models import Outfit, OutfitItem, User
from wardrobe_core.routers._common import owned_or_404
from wardrobe_core.schemas import OutfitCreate, OutfitOut, OutfitPatch

router = APIRouter(prefix="/outfits", tags=["outfits"])


async def _load(db: AsyncSession, outfit_id: uuid.UUID, user_id: uuid.UUID) -> Outfit:
    outfit = (
        await db.execute(
            select(Outfit).where(Outfit.id == outfit_id).options(selectinload(Outfit.items))
        )
    ).scalar_one_or_none()
    if outfit is None or outfit.user_id != user_id:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="not found")
    return outfit


def _apply_items(outfit: Outfit, items: list) -> None:
    outfit.items.clear()
    for it in items:
        outfit.items.append(
            OutfitItem(
                garment_id=it.garment_id,
                size_label=it.size_label,
                layer_index=it.layer_index,
                visible=it.visible,
                fit_adjust=it.fit_adjust,
            )
        )


@router.post("", response_model=OutfitOut, status_code=201)
async def create_outfit(
    payload: OutfitCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Outfit:
    outfit = Outfit(user_id=user.id, name=payload.name, avatar_id=payload.avatar_id)
    _apply_items(outfit, payload.items)
    db.add(outfit)
    await audit.record(db, action="outfit.created", actor_user_id=user.id, target_type="outfit")
    await db.flush()
    await db.refresh(outfit, attribute_names=["items"])
    return outfit


@router.get("", response_model=list[OutfitOut])
async def list_outfits(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[Outfit]:
    rows = (
        await db.execute(
            select(Outfit)
            .where(Outfit.user_id == user.id)
            .options(selectinload(Outfit.items))
            .order_by(Outfit.created_at.desc())
        )
    ).scalars().all()
    return list(rows)


@router.get("/{outfit_id}", response_model=OutfitOut)
async def get_outfit(
    outfit_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Outfit:
    return await _load(db, outfit_id, user.id)


@router.patch("/{outfit_id}", response_model=OutfitOut)
async def patch_outfit(
    outfit_id: uuid.UUID,
    payload: OutfitPatch,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Outfit:
    outfit = await _load(db, outfit_id, user.id)
    if payload.name is not None:
        outfit.name = payload.name
    if payload.items is not None:
        _apply_items(outfit, payload.items)
    await db.flush()
    await db.refresh(outfit, attribute_names=["items"])
    return outfit


@router.delete("/{outfit_id}", status_code=204)
async def delete_outfit(
    outfit_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    outfit = await owned_or_404(db, Outfit, outfit_id, user.id)
    await db.delete(outfit)
    await db.commit()
