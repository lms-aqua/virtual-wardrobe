"""Mock CV providers.

CLEARLY LABELED MOCKS. These do NOT perform real body reconstruction. The
avatar is a parametric estimate derived from the user's stated height using
published anthropometric ratios, packaged as a minimal (empty-scene) GLB so the
whole product workflow runs locally. Do not present its measurements as
tailoring- or medical-grade.
"""

from __future__ import annotations

import json
import struct

from wardrobe_core.providers.base import (
    AvatarResult,
    FitResult,
    QualityResult,
)

# Approximate proportion-of-height ratios (unisex, rough). Estimates only.
_RATIOS = {
    "shoulder_cm": 0.259,
    "chest_cm": 0.520,
    "underbust_cm": 0.460,
    "waist_cm": 0.430,
    "hip_cm": 0.520,
    "inseam_cm": 0.450,
    "torso_cm": 0.300,
    "arm_cm": 0.440,
    "thigh_cm": 0.310,
    "calf_cm": 0.210,
    "neck_cm": 0.200,
}

# Smallest valid PNG (1x1 transparent), used as a placeholder thumbnail.
_PLACEHOLDER_PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
    "890000000d49444154789c6360000002000100ffff03000006000557bffabc00"
    "00000049454e44ae426082"
)


def _minimal_glb() -> bytes:
    gltf = {
        "asset": {
            "version": "2.0",
            "generator": "VirtualWardrobe mock avatar (NOT a real reconstruction)",
        },
        "scene": 0,
        "scenes": [{"nodes": []}],
        "nodes": [],
    }
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b" " * pad
    chunk = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes  # 'JSON'
    total = 12 + len(chunk)
    header = struct.pack("<III", 0x46546C67, 2, total)  # 'glTF', version 2
    return header + chunk


class DeterministicScanQualityService:
    """Deterministic checks. Placeholders exist for future ML detectors."""

    def evaluate(self, images: dict[str, bytes]) -> QualityResult:
        required = {"front", "left", "back", "right"}
        reasons = {
            "all_views_present": required.issubset(images.keys()),
            "front_non_trivial": len(images.get("front", b"")) > 1024,
            "left_non_trivial": len(images.get("left", b"")) > 1024,
            "back_non_trivial": len(images.get("back", b"")) > 1024,
            "right_non_trivial": len(images.get("right", b"")) > 1024,
            # Future ML checks (pose, occlusion, full-body detection):
            "ml_pose_ok": True,  # placeholder — always true in mock
        }
        passed = all(reasons.values())
        score = sum(1 for v in reasons.values() if v) / len(reasons)
        return QualityResult(score=round(score, 3), passed=passed, reasons=reasons)


class MockAvatarGenerationProvider:
    def generate(
        self, *, images: dict[str, bytes], height_cm: float | None, hints_cm: dict[str, float]
    ) -> AvatarResult:
        h = height_cm or 170.0
        measurements = {"height_cm": round(h, 1)}
        for key, ratio in _RATIOS.items():
            measurements[key] = round(h * ratio, 1)
        # User-supplied hints override estimates (manual measurements win).
        for key, value in hints_cm.items():
            if value is not None:
                measurements[key] = round(float(value), 1)

        shape_params = {"height_norm": round((h - 150.0) / 50.0, 4)}
        return AvatarResult(
            glb_bytes=_minimal_glb(),
            thumbnail_png=_PLACEHOLDER_PNG,
            measurements_cm=measurements,
            shape_params=shape_params,
            confidence=0.45,  # deliberately modest — it is an estimate
            is_mock=True,
        )


class MeasurementScalingFittingEngine:
    """Measurement-based scaling + offsets. No physics simulation (MVP)."""

    def fit(
        self, *, avatar_measurements_cm: dict[str, float], garment_measurements: dict
    ) -> FitResult:
        notes: list[str] = []
        scale = {"x": 1.0, "y": 1.0, "z": 1.0}
        chest = avatar_measurements_cm.get("chest_cm")
        g_chest = (garment_measurements or {}).get("chest_cm")
        if chest and g_chest:
            ratio = max(0.85, min(1.25, chest / g_chest))
            scale["x"] = scale["z"] = round(ratio, 3)
            if ratio >= 1.2:
                notes.append("garment may be tight across chest")
        return FitResult(transform={"y": 0.0}, scale=scale, notes=notes)
