"""Provider interfaces. Product code depends only on these Protocols."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol, runtime_checkable


@dataclass
class QualityResult:
    score: float  # 0..1
    passed: bool
    reasons: dict[str, bool]


@dataclass
class AvatarResult:
    glb_bytes: bytes
    thumbnail_png: bytes
    measurements_cm: dict[str, float]
    shape_params: dict[str, float]
    confidence: float
    # True when produced by a mock provider — surfaced to the UI so we never
    # imply a real reconstruction happened.
    is_mock: bool = True


@runtime_checkable
class ScanQualityService(Protocol):
    def evaluate(self, images: dict[str, bytes]) -> QualityResult: ...


@runtime_checkable
class AvatarGenerationProvider(Protocol):
    def generate(
        self, *, images: dict[str, bytes], height_cm: float | None, hints_cm: dict[str, float]
    ) -> AvatarResult: ...


@dataclass
class FitResult:
    transform: dict[str, float]
    scale: dict[str, float]
    notes: list[str] = field(default_factory=list)


@runtime_checkable
class GarmentFittingEngine(Protocol):
    def fit(
        self, *, avatar_measurements_cm: dict[str, float], garment_measurements: dict
    ) -> FitResult: ...
