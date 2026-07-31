"""Real parametric humanoid mesh generation → GLB bytes.

Builds a SMOOTH, single-surface anatomical body from the user's measurements
using a signed-distance field (a skeleton of tapered spheres blended with a
smooth-union) sampled on a voxel grid and polygonised with marching cubes, then
Taubin-smoothed. This is a genuine parametric body — NOT a photogrammetric
reconstruction and NOT a likeness of the person's face/identity (that needs a
real capture pipeline). Do not present it as a real body scan.
"""

from __future__ import annotations

import math

import numpy as np
import trimesh
from skimage import measure


def _r(circ_cm: float | None, fb_m: float) -> float:
    return (circ_cm / 100.0) / (2 * math.pi) if circ_cm and circ_cm > 0 else fb_m


def _m(cm: float | None, fb_m: float) -> float:
    return (cm / 100.0) if cm and cm > 0 else fb_m


def _smin(a, b, k):  # noqa: ANN001 — smooth union of two SDFs
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def _bone(a, b, r0, r1, n):  # noqa: ANN001 — spheres along a segment, lerped radius
    a, b = np.array(a, float), np.array(b, float)
    return [(a + (b - a) * t, r0 + (r1 - r0) * t) for t in np.linspace(0, 1, n)]


def _skeleton(m: dict):
    h = _m(m.get("height_cm"), 1.70)
    chest_r = _r(m.get("chest_cm"), h * 0.088)
    waist_r = _r(m.get("waist_cm"), h * 0.072)
    hip_r = _r(m.get("hip_cm"), h * 0.090)
    thigh_r = _r(m.get("thigh_cm"), h * 0.058)
    calf_r = _r(m.get("calf_cm"), h * 0.042)
    neck_r = _r(m.get("neck_cm"), h * 0.036)
    arm_r = h * 0.030
    shoulder_w = _m(m.get("shoulder_cm"), h * 0.26)
    head_r = h * 0.050

    hip_y, chest_y, shld_y = h * 0.50, h * 0.71, h * 0.82
    s: list = []
    s += _bone((0, hip_y, 0), (0, h * 0.61, 0), hip_r, waist_r, 6)
    s += _bone((0, h * 0.61, 0), (0, chest_y, 0), waist_r, chest_r, 7)
    s += _bone((0, chest_y, 0), (0, shld_y, 0), chest_r, chest_r * 0.82, 4)
    s += _bone((-shoulder_w / 2, shld_y, 0), (shoulder_w / 2, shld_y, 0), arm_r * 1.25, arm_r * 1.25, 7)
    s += _bone((0, shld_y, 0), (0, h * 0.86, 0), neck_r, neck_r, 3)
    s += [((0, h * 0.925, 0.005), head_r)]
    for side in (-1, 1):
        sh = (side * shoulder_w / 2, shld_y, 0)
        el = (side * (shoulder_w / 2 + 0.02), h * 0.61, 0)
        wr = (side * (shoulder_w / 2 + 0.03), h * 0.47, 0)
        s += _bone(sh, el, arm_r * 1.05, arm_r * 0.82, 6)
        s += _bone(el, wr, arm_r * 0.82, arm_r * 0.6, 6)
        s += [((wr[0], wr[1] - 0.03, 0.01), arm_r * 0.6)]
    for side in (-1, 1):
        hp = (side * hip_r * 0.5, hip_y, 0)
        kn = (side * hip_r * 0.5, h * 0.27, 0)
        an = (side * hip_r * 0.5, 0.06, 0)
        s += _bone(hp, kn, thigh_r, calf_r * 1.05, 7)
        s += _bone(kn, an, calf_r * 1.05, calf_r * 0.72, 7)
        s += _bone((side * hip_r * 0.5, 0.04, 0.0),
                   (side * hip_r * 0.5, 0.03, head_r * 1.6), calf_r * 0.7, calf_r * 0.5, 4)
    return s


def build_avatar_glb(measurements_cm: dict, skin=(219, 182, 157)) -> bytes:
    spheres = _skeleton(measurements_cm)
    centers = np.array([c for c, _ in spheres], dtype=float)
    radii = np.array([r for _, r in spheres], dtype=float)

    zsquash = 1.18   # flatten front-to-back for a human silhouette
    pad, res, k = 0.06, 0.015, 0.045
    lo = centers.min(0) - radii.max() - pad
    hi = centers.max(0) + radii.max() + pad
    xs = np.arange(lo[0], hi[0], res)
    ys = np.arange(lo[1], hi[1], res)
    zs = np.arange(lo[2], hi[2], res)
    gx, gy, gz = np.meshgrid(xs, ys, zs, indexing="ij")
    P = np.stack([gx.ravel(), gy.ravel(), gz.ravel() * zsquash], axis=1)
    cz = centers.copy()
    cz[:, 2] *= zsquash

    D = np.full(P.shape[0], 1e9)
    for c, r in zip(cz, radii):
        D = _smin(D, np.sqrt(((P - c) ** 2).sum(1)) - r, k)
    grid = D.reshape(gx.shape)

    verts, faces, _n, _v = measure.marching_cubes(grid, level=0.0, spacing=(res, res, res))
    verts += lo
    verts[:, 2] /= zsquash
    mesh = trimesh.Trimesh(vertices=verts, faces=faces)
    trimesh.smoothing.filter_taubin(mesh, iterations=12)
    mesh.visual.vertex_colors = np.tile([*skin, 255], (len(mesh.vertices), 1))
    return mesh.export(file_type="glb")
