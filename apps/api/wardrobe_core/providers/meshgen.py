"""Real parametric humanoid mesh generation → GLB bytes.

This builds an ACTUAL 3D body mesh (not an empty placeholder) from the user's
measurements using primitive geometry welded together. It is still a stylized
parametric estimate, NOT a photogrammetric reconstruction — do not present it as
a real body scan. Any glTF viewer (web, AR QuickLook) can load the result.
"""

from __future__ import annotations

import math

import numpy as np
import trimesh


def _r(circ_cm: float | None, fallback_m: float) -> float:
    """Circumference (cm) → radius (m); fallback already in meters."""
    if circ_cm and circ_cm > 0:
        return (circ_cm / 100.0) / (2 * math.pi)
    return fallback_m


def _m(cm: float | None, fallback_m: float) -> float:
    return (cm / 100.0) if cm and cm > 0 else fallback_m


def _cyl(radius: float, p0, p1, sections: int = 20) -> trimesh.Trimesh:
    return trimesh.creation.cylinder(
        radius=max(radius, 0.01), segment=np.array([p0, p1], dtype=float), sections=sections
    )


def build_avatar_glb(measurements_cm: dict, skin=(217, 181, 156)) -> bytes:
    m = measurements_cm
    h = _m(m.get("height_cm"), 1.70)
    chest_r = _r(m.get("chest_cm"), h * 0.082)
    waist_r = _r(m.get("waist_cm"), h * 0.068)
    hip_r = _r(m.get("hip_cm"), h * 0.083)
    thigh_r = _r(m.get("thigh_cm"), h * 0.055)
    calf_r = _r(m.get("calf_cm"), h * 0.04)
    neck_r = _r(m.get("neck_cm"), h * 0.032)
    inseam = _m(m.get("inseam_cm"), h * 0.45)
    torso_len = _m(m.get("torso_cm"), h * 0.30)
    arm_len = _m(m.get("arm_cm"), h * 0.44)
    shoulder_w = _m(m.get("shoulder_cm"), h * 0.259)
    head_r = h * 0.047

    parts: list[trimesh.Trimesh] = []
    leg_x = hip_r * 0.55
    pelvis_y = inseam
    lower_top = pelvis_y + torso_len * 0.45
    shoulder_y = pelvis_y + torso_len

    # Legs (thigh + calf), feet
    for sx in (-leg_x, leg_x):
        parts.append(_cyl(thigh_r, [sx, pelvis_y, 0], [sx, pelvis_y * 0.5, 0]))
        parts.append(_cyl(calf_r, [sx, pelvis_y * 0.5, 0], [sx, 0.02, 0]))
        foot = trimesh.creation.box(extents=[calf_r * 2, 0.05, head_r * 2.6])
        foot.apply_translation([sx, 0.03, head_r * 0.6])
        parts.append(foot)

    # Torso: pelvis→waist and waist→chest
    parts.append(_cyl((hip_r + waist_r) / 2, [0, pelvis_y, 0], [0, lower_top, 0], sections=28))
    parts.append(_cyl((waist_r + chest_r) / 2, [0, lower_top, 0], [0, shoulder_y, 0], sections=28))

    # Arms
    for sx in (-shoulder_w / 2, shoulder_w / 2):
        parts.append(_cyl(chest_r * 0.28, [sx, shoulder_y, 0], [sx, shoulder_y - arm_len, 0]))

    # Neck + head
    neck_len = head_r * 0.7
    parts.append(_cyl(neck_r, [0, shoulder_y, 0], [0, shoulder_y + neck_len, 0]))
    head = trimesh.creation.icosphere(subdivisions=3, radius=head_r)
    head.apply_translation([0, shoulder_y + neck_len + head_r * 0.9, 0])
    parts.append(head)

    body = trimesh.util.concatenate(parts)
    body.visual = trimesh.visual.ColorVisuals(
        mesh=body, vertex_colors=np.tile([*skin, 255], (len(body.vertices), 1))
    )
    # Center on the ground, facing +Z.
    body.apply_translation([0, 0, 0])
    return body.export(file_type="glb")
