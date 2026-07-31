"""Outfit CRUD. Outfits are user-owned; cross-account access returns 404.
Saved outfits sync across devices because they are fetched by the same account
from any client."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from wardrobe_core import audit
from wardrobe_core.deps import get_current_user, get_db
from wardrobe_core.models import Avatar, Garment, Outfit, OutfitItem, User
from wardrobe_core.routers._common import owned_or_404
from wardrobe_core.schemas import OutfitCreate, OutfitOut, OutfitPatch

router = APIRouter(prefix="/outfits", tags=["outfits"])


async def _check_avatar(db: AsyncSession, avatar_id: uuid.UUID | None, user_id: uuid.UUID) -> None:
    """An outfit may only reference an avatar the caller owns.

    This was previously taken straight from the request body, so any account
    could attach another account's avatar to its own outfit. 404 (not 403) keeps
    it indistinguishable from a nonexistent avatar.
    """
    if avatar_id is None:
        return
    await owned_or_404(db, Avatar, avatar_id, user_id)


async def _check_garments(db: AsyncSession, items: list) -> None:
    """Every referenced garment must exist.

    Garments are a shared catalog rather than user-owned, so this is an
    existence check, not an ownership one. Without it the FK was written
    unvalidated: silently orphaned on SQLite (foreign keys are off by default)
    and a 500 IntegrityError on Postgres instead of a 4xx.
    """
    ids = {it.garment_id for it in items}
    if not ids:
        return
    found = set(
        (await db.execute(select(Garment.id).where(Garment.id.in_(ids)))).scalars().all()
    )
    missing = sorted(str(i) for i in ids - found)
    if missing:
        # Literal 422 rather than the status constant: Starlette renamed
        # HTTP_422_UNPROCESSABLE_ENTITY to ..._CONTENT, and the old spelling now
        # emits a deprecation warning while the new one is not present on older
        # versions. The number is stable across both.
        raise HTTPException(
            status_code=422,
            detail={"error": "unknown_garment", "garment_ids": missing},
        )


async def _load(db: AsyncSession, outfit_id: uuid.UUID, user_id: uuid.UUID) -> Outfit:
    outfit = (
        await db.execute(
            select(Outfit).where(Outfit.id == outfit_id).options(selectinload(Outfit.items))
        )
    ).scalar_one_or_none()
    if outfit is None or outfit.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="not found")
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
    await _check_avatar(db, payload.avatar_id, user.id)
    await _check_garments(db, payload.items)
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
        await _check_garments(db, payload.items)
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
