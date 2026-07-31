"""SQLAlchemy ORM models — the source of truth for the schema.

Portability: uses ``sqlalchemy.Uuid`` (native UUID on Postgres, CHAR on others)
and ``JSON`` so the same models run on Postgres (prod) and SQLite (tests).
Every owned row carries a ``user_id`` FK; the authorization layer enforces that
a requester may only touch rows they own (returning 404 on mismatch).
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from wardrobe_core import enums
from wardrobe_core.db import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    apple_sub: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    display_unit: Mapped[str] = mapped_column(String(8), default="metric", nullable=False)
    # Adult attestation captured at signup; scanning is gated on this + consent.
    is_adult: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    status: Mapped[enums.UserStatus] = mapped_column(
        Enum(enums.UserStatus, native_enum=False, length=16),
        default=enums.UserStatus.active,
        nullable=False,
    )

    consents: Mapped[list[Consent]] = relationship(back_populates="user")
    sessions: Mapped[list[Session]] = relationship(back_populates="user")


class Consent(Base, TimestampMixin):
    """Append-only consent ledger. Revocation writes revoked_at, never deletes."""

    __tablename__ = "user_consents"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    kind: Mapped[enums.ConsentKind] = mapped_column(
        Enum(enums.ConsentKind, native_enum=False, length=16), nullable=False
    )
    version: Mapped[str] = mapped_column(String(32), nullable=False)
    granted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="consents")


class Device(Base, TimestampMixin):
    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    platform: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Session(Base, TimestampMixin):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    device_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("devices.id", ondelete="SET NULL"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="sessions")


class BodyScan(Base, TimestampMixin):
    __tablename__ = "body_scans"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[enums.ScanStatus] = mapped_column(
        Enum(enums.ScanStatus, native_enum=False, length=16),
        default=enums.ScanStatus.created,
        nullable=False,
    )
    capture_mode: Mapped[enums.CaptureMode] = mapped_column(
        Enum(enums.CaptureMode, native_enum=False, length=16),
        default=enums.CaptureMode.camera,
        nullable=False,
    )
    quality_score: Mapped[float | None] = mapped_column(nullable=True)
    quality_reasons: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    retain_raw_images: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    height_cm: Mapped[float | None] = mapped_column(nullable=True)

    images: Mapped[list[ScanImage]] = relationship(
        back_populates="scan", cascade="all, delete-orphan"
    )


class ScanImage(Base, TimestampMixin):
    """One captured view. object_key points into the PRIVATE scans bucket.

    Rows and their objects are hard-deleted together (never soft-deleted)."""

    __tablename__ = "scan_images"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    scan_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("body_scans.id", ondelete="CASCADE"), index=True, nullable=False
    )
    # Free-form label: one of the classic views (front/left/back/right) OR a
    # 360°-capture frame id like "frame_0007". Kept unique per scan.
    view: Mapped[str] = mapped_column(String(32), nullable=False)
    object_key: Mapped[str] = mapped_column(String(512), nullable=False)
    mime: Mapped[str | None] = mapped_column(String(64), nullable=True)
    bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    uploaded: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    scan: Mapped[BodyScan] = relationship(back_populates="images")

    __table_args__ = (Index("ix_scan_images_scan_view", "scan_id", "view", unique=True),)


class ScanJob(Base, TimestampMixin):
    __tablename__ = "scan_jobs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    scan_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("body_scans.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[enums.JobStatus] = mapped_column(
        Enum(enums.JobStatus, native_enum=False, length=16),
        default=enums.JobStatus.created,
        nullable=False,
    )
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    progress: Mapped[int] = mapped_column(Integer, default=0, nullable=False)  # 0..100


class Avatar(Base, TimestampMixin):
    __tablename__ = "avatars"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    scan_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("body_scans.id", ondelete="SET NULL"), nullable=True
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    mesh_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    thumb_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    confidence: Mapped[float | None] = mapped_column(nullable=True)
    status: Mapped[enums.AvatarStatus] = mapped_column(
        Enum(enums.AvatarStatus, native_enum=False, length=16),
        default=enums.AvatarStatus.processing,
        nullable=False,
    )

    measurements: Mapped[AvatarMeasurement | None] = relationship(
        back_populates="avatar", cascade="all, delete-orphan", uselist=False
    )


class AvatarMeasurement(Base, TimestampMixin):
    __tablename__ = "avatar_measurements"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    avatar_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("avatars.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    height_cm: Mapped[float | None] = mapped_column(nullable=True)
    shoulder_cm: Mapped[float | None] = mapped_column(nullable=True)
    chest_cm: Mapped[float | None] = mapped_column(nullable=True)
    underbust_cm: Mapped[float | None] = mapped_column(nullable=True)
    waist_cm: Mapped[float | None] = mapped_column(nullable=True)
    hip_cm: Mapped[float | None] = mapped_column(nullable=True)
    inseam_cm: Mapped[float | None] = mapped_column(nullable=True)
    torso_cm: Mapped[float | None] = mapped_column(nullable=True)
    arm_cm: Mapped[float | None] = mapped_column(nullable=True)
    thigh_cm: Mapped[float | None] = mapped_column(nullable=True)
    calf_cm: Mapped[float | None] = mapped_column(nullable=True)
    neck_cm: Mapped[float | None] = mapped_column(nullable=True)
    shape_params: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    pose_params: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    source: Mapped[enums.MeasurementSource] = mapped_column(
        Enum(enums.MeasurementSource, native_enum=False, length=16),
        default=enums.MeasurementSource.estimated,
        nullable=False,
    )

    avatar: Mapped[Avatar] = relationship(back_populates="measurements")


class Garment(Base, TimestampMixin):
    __tablename__ = "garments"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    brand: Mapped[str] = mapped_column(String(128), nullable=False)
    name: Mapped[str] = mapped_column(String(256), nullable=False)
    category: Mapped[enums.GarmentCategory] = mapped_column(
        Enum(enums.GarmentCategory, native_enum=False, length=16), nullable=False
    )
    gender_neutral: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    layering_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    compatible_avatar_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    mesh_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    thumb_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    product_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    price_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fabric_props: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    sizes: Mapped[list[GarmentSize]] = relationship(
        back_populates="garment", cascade="all, delete-orphan"
    )


class GarmentSize(Base, TimestampMixin):
    __tablename__ = "garment_sizes"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    garment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("garments.id", ondelete="CASCADE"), index=True, nullable=False
    )
    size_label: Mapped[str] = mapped_column(String(16), nullable=False)
    measurements: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    fit_offsets: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    garment: Mapped[Garment] = relationship(back_populates="sizes")


class Outfit(Base, TimestampMixin):
    __tablename__ = "outfits"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    avatar_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("avatars.id", ondelete="SET NULL"), nullable=True
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)

    items: Mapped[list[OutfitItem]] = relationship(
        back_populates="outfit", cascade="all, delete-orphan"
    )


class OutfitItem(Base, TimestampMixin):
    __tablename__ = "outfit_items"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    outfit_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("outfits.id", ondelete="CASCADE"), index=True, nullable=False
    )
    garment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("garments.id", ondelete="CASCADE"), nullable=False
    )
    size_label: Mapped[str | None] = mapped_column(String(16), nullable=True)
    layer_index: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    visible: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    fit_adjust: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    outfit: Mapped[Outfit] = relationship(back_populates="items")


class UserPreference(Base, TimestampMixin):
    """Free-form per-user client preferences (units, customization, favorites)
    synced across devices. One row per user; ``data`` is opaque client JSON."""

    __tablename__ = "user_preferences"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    data: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)


class AuditEvent(Base, TimestampMixin):
    """Security audit log. Never stores raw scans, tokens, or signed URLs."""

    __tablename__ = "audit_events"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True
    )
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    target_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    target_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    ip: Mapped[str | None] = mapped_column(String(64), nullable=True)
    meta: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class DeletionRequest(Base, TimestampMixin):
    __tablename__ = "deletion_requests"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    scope: Mapped[enums.DeletionScope] = mapped_column(
        Enum(enums.DeletionScope, native_enum=False, length=16), nullable=False
    )
    status: Mapped[enums.DeletionStatus] = mapped_column(
        Enum(enums.DeletionStatus, native_enum=False, length=16),
        default=enums.DeletionStatus.requested,
        nullable=False,
    )
    idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
