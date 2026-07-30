"""Status and category enums, stored as portable VARCHARs (native_enum=False)."""

from __future__ import annotations

import enum


class UserStatus(str, enum.Enum):
    active = "active"
    deleted = "deleted"


class ConsentKind(str, enum.Enum):
    scan = "scan"  # required to perform a body scan
    train = "train"  # separate, optional: reuse scans to improve models


class ScanStatus(str, enum.Enum):
    created = "created"
    uploading = "uploading"
    uploaded = "uploaded"
    validating = "validating"
    queued = "queued"
    processing = "processing"
    optimizing = "optimizing"
    completed = "completed"
    failed = "failed"
    deleting = "deleting"
    deleted = "deleted"


class ScanView(str, enum.Enum):
    front = "front"
    left = "left"
    back = "back"
    right = "right"


class CaptureMode(str, enum.Enum):
    camera = "camera"
    lidar = "lidar"


class AvatarStatus(str, enum.Enum):
    processing = "processing"
    completed = "completed"
    failed = "failed"
    deleted = "deleted"


class MeasurementSource(str, enum.Enum):
    estimated = "estimated"
    manual = "manual"


class JobStatus(str, enum.Enum):
    created = "created"
    queued = "queued"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class GarmentCategory(str, enum.Enum):
    top = "top"
    dress = "dress"
    bottom = "bottom"
    outerwear = "outerwear"
    footwear = "footwear"


class DeletionScope(str, enum.Enum):
    scans_only = "scans_only"
    full_account = "full_account"


class DeletionStatus(str, enum.Enum):
    requested = "requested"
    processing = "processing"
    completed = "completed"
