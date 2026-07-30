"""Pydantic request/response schemas — the validated API boundary."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from wardrobe_core import enums


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---- Auth ----
class MagicLinkRequest(BaseModel):
    email: EmailStr
    # Adult attestation is required to sign up / scan (adults only).
    is_adult: bool = Field(description="User attests they are 18+")


class MagicLinkVerify(BaseModel):
    token: str


class MagicLinkDevResponse(BaseModel):
    """In non-production, the token is returned so dev/tests can complete flow.
    In production this endpoint returns only {sent: true}."""

    sent: bool
    dev_token: str | None = None


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: uuid.UUID


# ---- User ----
class UserOut(ORMModel):
    id: uuid.UUID
    email: EmailStr
    display_unit: str
    is_adult: bool
    status: enums.UserStatus
    created_at: datetime


# ---- Consent ----
class ConsentCreate(BaseModel):
    kind: enums.ConsentKind
    version: str = "1.0"


class ConsentOut(ORMModel):
    id: uuid.UUID
    kind: enums.ConsentKind
    version: str
    granted_at: datetime
    revoked_at: datetime | None


# ---- Scans ----
class ScanCreate(BaseModel):
    capture_mode: enums.CaptureMode = enums.CaptureMode.camera
    height_cm: float | None = Field(default=None, ge=50, le=260)
    retain_raw_images: bool = False


class ScanImageOut(ORMModel):
    view: enums.ScanView
    uploaded: bool


class ScanOut(ORMModel):
    id: uuid.UUID
    status: enums.ScanStatus
    capture_mode: enums.CaptureMode
    quality_score: float | None
    retain_raw_images: bool
    created_at: datetime
    images: list[ScanImageOut] = []


class UploadUrlRequest(BaseModel):
    view: enums.ScanView
    content_type: str


class UploadUrlResponse(BaseModel):
    view: enums.ScanView
    url: str
    fields: dict
    max_bytes: int


class ScanCompleteResponse(BaseModel):
    scan_id: uuid.UUID
    job_id: uuid.UUID
    status: enums.ScanStatus


# ---- Avatars ----
class MeasurementOut(ORMModel):
    height_cm: float | None = None
    shoulder_cm: float | None = None
    chest_cm: float | None = None
    underbust_cm: float | None = None
    waist_cm: float | None = None
    hip_cm: float | None = None
    inseam_cm: float | None = None
    torso_cm: float | None = None
    arm_cm: float | None = None
    thigh_cm: float | None = None
    calf_cm: float | None = None
    neck_cm: float | None = None
    source: enums.MeasurementSource = enums.MeasurementSource.estimated


class MeasurementPatch(BaseModel):
    height_cm: float | None = Field(default=None, ge=50, le=260)
    shoulder_cm: float | None = Field(default=None, ge=10, le=120)
    chest_cm: float | None = Field(default=None, ge=30, le=250)
    underbust_cm: float | None = Field(default=None, ge=30, le=250)
    waist_cm: float | None = Field(default=None, ge=30, le=250)
    hip_cm: float | None = Field(default=None, ge=30, le=250)
    inseam_cm: float | None = Field(default=None, ge=30, le=150)
    torso_cm: float | None = Field(default=None, ge=20, le=120)
    arm_cm: float | None = Field(default=None, ge=20, le=120)
    thigh_cm: float | None = Field(default=None, ge=20, le=120)
    calf_cm: float | None = Field(default=None, ge=15, le=100)
    neck_cm: float | None = Field(default=None, ge=15, le=80)


class AvatarOut(ORMModel):
    id: uuid.UUID
    version: int
    status: enums.AvatarStatus
    confidence: float | None
    mesh_url: str | None = None
    thumb_url: str | None = None
    is_mock: bool = True
    measurements: MeasurementOut | None = None
    created_at: datetime


# ---- Garments ----
class GarmentSizeOut(ORMModel):
    size_label: str
    measurements: dict | None = None


class GarmentOut(ORMModel):
    id: uuid.UUID
    brand: str
    name: str
    category: enums.GarmentCategory
    gender_neutral: bool
    layering_order: int
    thumb_url: str | None = None
    mesh_url: str | None = None
    product_url: str | None = None
    price_cents: int | None = None
    sizes: list[GarmentSizeOut] = []


# ---- Outfits ----
class OutfitItemIn(BaseModel):
    garment_id: uuid.UUID
    size_label: str | None = None
    layer_index: int = 0
    visible: bool = True
    fit_adjust: dict | None = None


class OutfitItemOut(ORMModel):
    garment_id: uuid.UUID
    size_label: str | None
    layer_index: int
    visible: bool
    fit_adjust: dict | None


class OutfitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    avatar_id: uuid.UUID | None = None
    items: list[OutfitItemIn] = []


class OutfitPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    items: list[OutfitItemIn] | None = None


class OutfitOut(ORMModel):
    id: uuid.UUID
    name: str
    avatar_id: uuid.UUID | None
    items: list[OutfitItemOut] = []
    created_at: datetime


# ---- Jobs / deletion ----
class JobOut(ORMModel):
    id: uuid.UUID
    status: enums.JobStatus
    error_code: str | None


class DeletionRequestIn(BaseModel):
    scope: enums.DeletionScope = enums.DeletionScope.full_account


class DeletionRequestOut(ORMModel):
    id: uuid.UUID
    scope: enums.DeletionScope
    status: enums.DeletionStatus
    completed_at: datetime | None
