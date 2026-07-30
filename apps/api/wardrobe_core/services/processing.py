"""Scan → avatar processing pipeline.

Runs identically inline (dev/test) or inside the Dramatiq worker: it opens its
own DB session so behavior does not depend on the caller. Enforces upload
validation, quality gating, mock avatar generation, GLB publishing, and — per
the privacy baseline — hard-deletes raw scan images afterward unless the user
opted to retain them.
"""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from wardrobe_core import audit
from wardrobe_core.config import get_settings
from wardrobe_core.db import get_sessionmaker
from wardrobe_core.enums import AvatarStatus, JobStatus, ScanStatus
from wardrobe_core.logging import get_logger
from wardrobe_core.models import Avatar, AvatarMeasurement, BodyScan, ScanImage, ScanJob
from wardrobe_core.providers import get_avatar_provider, get_quality_service
from wardrobe_core.storage import avatar_mesh_key, avatar_thumb_key, get_storage
from wardrobe_core.uploads import validate_image

log = get_logger("processing")

_MEASUREMENT_FIELDS = (
    "height_cm", "shoulder_cm", "chest_cm", "underbust_cm", "waist_cm", "hip_cm",
    "inseam_cm", "torso_cm", "arm_cm", "thigh_cm", "calf_cm", "neck_cm",
)


async def process_scan(scan_id: uuid.UUID) -> None:
    settings = get_settings()
    storage = get_storage()
    maker = get_sessionmaker()

    async with maker() as db:
        scan = (
            await db.execute(
                select(BodyScan)
                .where(BodyScan.id == scan_id)
                .options(selectinload(BodyScan.images))
            )
        ).scalar_one_or_none()
        if scan is None:
            log.warning("processing.scan_missing", scan_id=str(scan_id))
            return

        job = (
            await db.execute(select(ScanJob).where(ScanJob.scan_id == scan_id))
        ).scalar_one_or_none()

        async def fail(code: str) -> None:
            scan.status = ScanStatus.failed
            if job:
                job.status = JobStatus.failed
                job.error_code = code
            await audit.record(
                db, action="scan.failed", actor_user_id=scan.user_id,
                target_type="scan", target_id=str(scan.id), meta={"error_code": code},
            )
            await db.commit()

        scan.status = ScanStatus.validating
        if job:
            job.status = JobStatus.processing
            job.attempts += 1
        await db.commit()

        # 1) Load + validate every uploaded image (magic-byte + size re-check).
        images: dict[str, bytes] = {}
        allowed = settings.allowed_image_mime_set
        for img in scan.images:
            if not img.uploaded:
                continue
            try:
                data = storage.get_object(settings.s3_bucket_scans, img.object_key)
            except Exception:  # noqa: BLE001
                await fail("image_fetch_failed")
                return
            ok, detail = validate_image(
                data, allowed=allowed, max_bytes=settings.max_upload_bytes
            )
            if not ok:
                await fail(f"invalid_image:{detail}")
                return
            images[img.view] = data

        # 2) Quality gate.
        quality = get_quality_service().evaluate(images)
        scan.quality_score = quality.score
        scan.quality_reasons = quality.reasons
        if not quality.passed:
            await fail("low_quality")
            return

        # 3) Generate avatar (mock).
        scan.status = ScanStatus.processing
        await db.commit()
        result = get_avatar_provider().generate(
            images=images, height_cm=scan.height_cm, hints_cm={}
        )

        avatar = Avatar(
            user_id=scan.user_id,
            scan_id=scan.id,
            version=1,
            confidence=result.confidence,
            status=AvatarStatus.processing,
        )
        db.add(avatar)
        await db.flush()

        # 4) Publish GLB + thumbnail to the PRIVATE avatars bucket.
        scan.status = ScanStatus.optimizing
        mkey = avatar_mesh_key(scan.user_id, avatar.id)
        tkey = avatar_thumb_key(scan.user_id, avatar.id)
        storage.put_object(settings.s3_bucket_avatars, mkey, result.glb_bytes, "model/gltf-binary")
        storage.put_object(settings.s3_bucket_avatars, tkey, result.thumbnail_png, "image/png")
        avatar.mesh_key = mkey
        avatar.thumb_key = tkey
        avatar.status = AvatarStatus.completed

        m = AvatarMeasurement(avatar_id=avatar.id)
        for field in _MEASUREMENT_FIELDS:
            if field in result.measurements_cm:
                setattr(m, field, result.measurements_cm[field])
        m.shape_params = result.shape_params
        db.add(m)

        # 5) Privacy: hard-delete raw scan images unless retained.
        if settings.delete_raw_scans_after_avatar and not scan.retain_raw_images:
            for img in list(scan.images):
                storage.delete_object(settings.s3_bucket_scans, img.object_key)
                await db.delete(img)
            await audit.record(
                db, action="scan.raw_images_deleted", actor_user_id=scan.user_id,
                target_type="scan", target_id=str(scan.id),
            )

        scan.status = ScanStatus.completed
        if job:
            job.status = JobStatus.completed
        await audit.record(
            db, action="avatar.created", actor_user_id=scan.user_id,
            target_type="avatar", target_id=str(avatar.id),
            meta={"is_mock": result.is_mock, "confidence": result.confidence},
        )
        await db.commit()
        log.info("processing.completed", scan_id=str(scan_id), avatar_id=str(avatar.id))
