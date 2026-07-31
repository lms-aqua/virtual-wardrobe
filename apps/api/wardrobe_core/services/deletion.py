"""Hard-deletion services (right to erasure).

Deletes are genuinely destructive for sensitive data: object bytes are removed
from storage, not just DB rows. Full-account deletion also scrubs PII and
revokes all sessions so the account cannot be used again.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select, update

from wardrobe_core import audit
from wardrobe_core.config import get_settings
from wardrobe_core.db import get_sessionmaker
from wardrobe_core.enums import DeletionScope, DeletionStatus, UserStatus
from wardrobe_core.logging import get_logger
from wardrobe_core.models import (
    Avatar,
    BodyScan,
    DeletionRequest,
    Outfit,
    ScanImage,
    Session,
    User,
)
from wardrobe_core.storage import get_storage, user_prefix

log = get_logger("deletion")


async def hard_delete_scan(db, scan: BodyScan) -> None:
    """Delete a scan's image objects + rows + the scan itself."""
    settings = get_settings()
    storage = get_storage()
    images = (
        await db.execute(select(ScanImage).where(ScanImage.scan_id == scan.id))
    ).scalars().all()
    for img in images:
        storage.delete_object(settings.s3_bucket_scans, img.object_key)
        await db.delete(img)
    await audit.record(
        db, action="scan.deleted", actor_user_id=scan.user_id,
        target_type="scan", target_id=str(scan.id),
    )
    await db.delete(scan)


async def run_deletion_request(request_id: uuid.UUID) -> None:
    settings = get_settings()
    storage = get_storage()
    maker = get_sessionmaker()

    async with maker() as db:
        req = await db.get(DeletionRequest, request_id)
        if req is None or req.status == DeletionStatus.completed:
            return
        req.status = DeletionStatus.processing
        await db.commit()

        user_id = req.user_id

        # Purge ALL objects under the user's namespace across every bucket.
        for bucket in (
            settings.s3_bucket_scans,
            settings.s3_bucket_avatars,
        ):
            storage.delete_prefix(bucket, user_prefix(user_id))

        # Delete owned rows. FKs cascade measurements/outfit_items/scan_images.
        await db.execute(delete(BodyScan).where(BodyScan.user_id == user_id))

        if req.scope == DeletionScope.full_account:
            await db.execute(delete(Avatar).where(Avatar.user_id == user_id))
            await db.execute(delete(Outfit).where(Outfit.user_id == user_id))
            # Revoke every session.
            await db.execute(
                update(Session)
                .where(Session.user_id == user_id, Session.revoked_at.is_(None))
                .values(revoked_at=datetime.now(UTC))
            )
            # Scrub PII + tombstone the user (email replaced to free the unique key).
            await db.execute(
                update(User)
                .where(User.id == user_id)
                .values(
                    status=UserStatus.deleted,
                    email=f"deleted+{user_id}@invalid.local",
                    apple_sub=None,
                )
            )

        req.status = DeletionStatus.completed
        req.completed_at = datetime.now(UTC)
        await audit.record(
            db, action="account.deletion_completed", actor_user_id=user_id,
            target_type="deletion_request", target_id=str(req.id),
            meta={"scope": req.scope.value},
        )
        await db.commit()
        log.info("deletion.completed", user_id=str(user_id), scope=req.scope.value)
