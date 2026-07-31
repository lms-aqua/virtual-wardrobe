"""Swappable CV provider interfaces + factory (see ADR-0001).

The factory returns mock implementations for now. Real SMPL-X / LiDAR / vendor
providers register here later with zero product-code changes.
"""

from __future__ import annotations

from wardrobe_core.providers.base import (
    AvatarGenerationProvider,
    AvatarResult,
    GarmentFittingEngine,
    QualityResult,
    ScanQualityService,
)
from wardrobe_core.providers.mock import (
    DeterministicScanQualityService,
    MeasurementScalingFittingEngine,
    MockAvatarGenerationProvider,
)

_avatar_provider: AvatarGenerationProvider = MockAvatarGenerationProvider()
_quality_service: ScanQualityService = DeterministicScanQualityService()
_fitting_engine: GarmentFittingEngine = MeasurementScalingFittingEngine()


def get_avatar_provider() -> AvatarGenerationProvider:
    return _avatar_provider


def get_quality_service() -> ScanQualityService:
    return _quality_service


def get_fitting_engine() -> GarmentFittingEngine:
    return _fitting_engine


__all__ = [
    "AvatarGenerationProvider",
    "AvatarResult",
    "GarmentFittingEngine",
    "QualityResult",
    "ScanQualityService",
    "get_avatar_provider",
    "get_quality_service",
    "get_fitting_engine",
]
