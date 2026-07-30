"""Body-scan endpoints: create, presigned upload, complete, delete.

A scan can only be created with an active adult 'scan' consent on file. Uploads
go straight to the PRIVATE scans bucket via presigned POST (size + type
enforced by the storage policy). Completion re-validates objects server-side
and dispatches avatar generation.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core import audit
from wardrobe_core.config import Settings
from wardrobe_core.deps import get_current_user, get_db, settings_dep
from wardrobe_core.enums import ConsentKind, JobStatus, ScanStatus
from wardrobe_core.models import BodyScan, Consent, ScanImage, ScanJob, User
from wardrobe_core.routers._common import owned_or_404
from wardrobe_core.schemas import (
    ScanCompleteResponse,
    ScanCreate,
    ScanOut,
    UploadUrlRequest,
    UploadUrlResponse,
)
from wardrobe_core.services.processing import process_scan
from wardrobe_core.storage import get_storage, scan_image_key

router = APIRouter(prefix="/scans", tags=["scans"])


async def _has_active_scan_consent(db: AsyncSession, user_id: uuid.UUID) -> bool:
    row = (
        await db.execute(
            select(Consent.id).where(
                Consent.user_id == user_id,
                Consent.kind == ConsentKind.scan,
                Consent.revoked_at.is_(None),
            )
        )
    ).first()
    return row is not None


async def _load_scan(db: AsyncSession, scan_id: uuid.UUID, user_id: uuid.UUID) -> BodyScan:
    scan = (
        await db.execute(
            select(BodyScan)
            .where(BodyScan.id == scan_id)
            .options(selectinload(BodyScan.images))
        )
    ).scalar_one_or_none()
    if scan is None or scan.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="not found")
    return scan


@router.post("", response_model=ScanOut, status_code=201)
async def create_scan(
    payload: ScanCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BodyScan:
    if not user.is_adult:
        raise HTTPException(status_code=403, detail="adults_only")
    if not await _has_active_scan_consent(db, user.id):
        raise HTTPException(status_code=403, detail="scan_consent_required")
    scan = BodyScan(
        user_id=user.id,
        capture_mode=payload.capture_mode,
        height_cm=payload.height_cm,
        retain_raw_images=payload.retain_raw_images,
    )
    db.add(scan)
    await audit.record(db, action="scan.created", actor_user_id=user.id, target_type="scan")
    await db.flush()
    await db.refresh(scan, attribute_names=["images"])
    return scan


@router.get("/{scan_id}", response_model=ScanOut)
async def get_scan(
    scan_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BodyScan:
    return await _load_scan(db, scan_id, user.id)


@router.post("/{scan_id}/upload-url", response_model=UploadUrlResponse)
async def create_upload_url(
    scan_id: uuid.UUID,
    payload: UploadUrlRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
) -> UploadUrlResponse:
    scan = await _load_scan(db, scan_id, user.id)
    if payload.content_type.lower() not in settings.allowed_image_mime_set:
        raise HTTPException(status_code=400, detail="disallowed_content_type")

    key = scan_image_key(user.id, scan.id, payload.view.value)
    existing = next((i for i in scan.images if i.view == payload.view), None)
    if existing is None:
        db.add(ScanImage(scan_id=scan.id, view=payload.view, object_key=key,
                         mime=payload.content_type, uploaded=False))
    else:
        existing.object_key = key
        existing.mime = payload.content_type
        existing.uploaded = False
    scan.status = ScanStatus.uploading
    await db.flush()

    presigned = get_storage().presign_post(
        settings.s3_bucket_scans, key, payload.content_type, settings.max_upload_bytes
    )
    return UploadUrlResponse(
        view=payload.view,
        url=presigned["url"],
        fields=presigned.get("fields", {}),
        max_bytes=settings.max_upload_bytes,
    )


@router.post("/{scan_id}/complete", response_model=ScanCompleteResponse)
async def complete_scan(
    scan_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(settings_dep),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> ScanCompleteResponse:
    scan = await _load_scan(db, scan_id, user.id)
    storage = get_storage()

    # Confirm each expected object actually landed in storage.
    present = 0
    for img in scan.images:
        head = storage.head_object(settings.s3_bucket_scans, img.object_key)
        if head is not None:
            img.uploaded = True
            img.bytes = head.get("size")
            present += 1
    if present < 4:
        raise HTTPException(status_code=400, detail="all_four_views_required")

    # Idempotent job creation.
    job = (
        await db.execute(select(ScanJob).where(ScanJob.scan_id == scan.id))
    ).scalar_one_or_none()
    if job is None:
        job = ScanJob(
            scan_id=scan.id, user_id=user.id, status=JobStatus.queued,
            idempotency_key=idempotency_key,
        )
        db.add(job)
    scan.status = ScanStatus.queued
    await db.commit()

    if settings.run_jobs_inline:
        await process_scan(scan.id)
    else:
        from wardrobe_core.worker import process_scan_actor

        process_scan_actor.send(str(scan.id))

    await db.refresh(scan)
    await db.refresh(job)
    return ScanCompleteResponse(scan_id=scan.id, job_id=job.id, status=scan.status)


@router.delete("/{scan_id}", status_code=204)
async def delete_scan(
    scan_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    scan = await owned_or_404(db, BodyScan, scan_id, user.id)
    from wardrobe_core.services.deletion import hard_delete_scan

    await hard_delete_scan(db, scan)
    await db.commit()
