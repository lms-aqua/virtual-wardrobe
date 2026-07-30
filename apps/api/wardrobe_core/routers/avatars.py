"""Avatar endpoints. Mesh/thumbnail are served ONLY via short-lived signed URLs
minted after the ownership check — never as public links."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.enums import AvatarStatus, MeasurementSource
from wardrobe_core.models import Avatar, AvatarMeasurement, User
from wardrobe_core.routers._common import owned_or_404
from wardrobe_core.schemas import AvatarOut, MeasurementOut, MeasurementPatch
from wardrobe_core.storage import get_storage

router = APIRouter(prefix="/avatars", tags=["avatars"])


def _serialize(avatar: Avatar, settings: Settings) -> AvatarOut:
    storage = get_storage()
    mesh_url = (
        storage.presign_get(settings.s3_bucket_avatars, avatar.mesh_key)
        if avatar.mesh_key
        else None
    )
    thumb_url = (
        storage.presign_get(settings.s3_bucket_avatars, avatar.thumb_key)
        if avatar.thumb_key
        else None
    )
    measurements = (
        MeasurementOut.model_validate(avatar.measurements) if avatar.measurements else None
    )
    return AvatarOut(
        id=avatar.id,
        version=avatar.version,
        status=avatar.status,
        confidence=avatar.confidence,
        mesh_url=mesh_url,
        thumb_url=thumb_url,
        is_mock=True,
        measurements=measurements,
        created_at=avatar.created_at,
    )


async def _load(db: AsyncSession, avatar_id: uuid.UUID, user_id: uuid.UUID) -> Avatar:
    avatar = (
        await db.execute(
            select(Avatar)
            .where(Avatar.id == avatar_id)
            .options(selectinload(Avatar.measurements))
        )
    ).scalar_one_or_none()
    if avatar is None or avatar.user_id != user_id:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="not found")
    return avatar


@router.get("", response_model=list[AvatarOut])
async def list_avatars(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> list[AvatarOut]:
    rows = (
        await db.execute(
            select(Avatar)
            .where(Avatar.user_id == user.id, Avatar.status != AvatarStatus.deleted)
            .options(selectinload(Avatar.measurements))
            .order_by(Avatar.created_at.desc())
        )
    ).scalars().all()
    return [_serialize(a, settings) for a in rows]


@router.get("/{avatar_id}", response_model=AvatarOut)
async def get_avatar(
    avatar_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> AvatarOut:
    avatar = await _load(db, avatar_id, user.id)
    return _serialize(avatar, settings)


@router.patch("/{avatar_id}/measurements", response_model=AvatarOut)
async def patch_measurements(
    avatar_id: uuid.UUID,
    payload: MeasurementPatch,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> AvatarOut:
    avatar = await _load(db, avatar_id, user.id)
    if avatar.measurements is None:
        avatar.measurements = AvatarMeasurement(avatar_id=avatar.id)
        db.add(avatar.measurements)
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(avatar.measurements, field, value)
    avatar.measurements.source = MeasurementSource.manual
    await audit.record(
        db, action="avatar.measurements_edited", actor_user_id=user.id,
        target_type="avatar", target_id=str(avatar.id),
    )
    await db.flush()
    await db.refresh(avatar, attribute_names=["measurements"])
    return _serialize(avatar, settings)


@router.delete("/{avatar_id}", status_code=204)
async def delete_avatar(
    avatar_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> None:
    avatar = await owned_or_404(db, Avatar, avatar_id, user.id)
    storage = get_storage()
    if avatar.mesh_key:
        storage.delete_object(settings.s3_bucket_avatars, avatar.mesh_key)
    if avatar.thumb_key:
        storage.delete_object(settings.s3_bucket_avatars, avatar.thumb_key)
    await audit.record(
        db, action="avatar.deleted", actor_user_id=user.id,
        target_type="avatar", target_id=str(avatar.id),
    )
    await db.delete(avatar)
    await db.commit()
