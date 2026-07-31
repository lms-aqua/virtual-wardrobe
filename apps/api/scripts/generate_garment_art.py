"""Generate flat garment artwork for the catalog and attach it to each garment.

Run:  python -m scripts.generate_garment_art

Every catalog garment ships with `thumb_key` unset, so the iOS client falls back
to a category symbol and the wardrobe reads as a grid of coloured blocks. This
renders a simple flat garment silhouette per item, uploads it to the private
garments bucket and sets `thumb_key`; the existing `/garments` route already
presigns `thumb_url` from that key, and the client already prefers a real image
over the symbol. No API or app change is required.

Deliberately dependency-free: shapes are rasterised into a numpy array (numpy is
already a dependency via the mesh generator) and encoded with a small stdlib PNG
writer, so this adds no new packages to the image.

Idempotent: garments that already have a thumb_key are skipped unless --force.
"""

from __future__ import annotations

import argparse
import asyncio
import struct
import zlib

import numpy as np
from sqlalchemy import select

from wardrobe_core.config import get_settings
from wardrobe_core.db import get_sessionmaker
from wardrobe_core.enums import GarmentCategory
from wardrobe_core.models import Garment
from wardrobe_core.storage import get_storage

SIZE = 512

# ---------------------------------------------------------------------------
# PNG encoding (stdlib only)
# ---------------------------------------------------------------------------


def encode_png(rgb: np.ndarray) -> bytes:
    """Encode an (H, W, 3) uint8 array as a PNG."""
    height, width, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


# ---------------------------------------------------------------------------
# Colour
# ---------------------------------------------------------------------------

# Colour words carried by catalog names. Matched longest-first so "light wash"
# wins over "wash".
COLOUR_WORDS: dict[str, tuple[int, int, int]] = {
    "white": (238, 238, 234),
    "ivory": (240, 234, 220),
    "cream": (238, 228, 205),
    "blush": (232, 190, 190),
    "black": (38, 38, 42),
    "charcoal": (66, 68, 74),
    "heather grey": (150, 152, 158),
    "grey": (140, 142, 148),
    "navy": (38, 52, 88),
    "blue": (78, 108, 160),
    "indigo": (54, 74, 118),
    "light wash": (128, 156, 196),
    "denim": (72, 96, 142),
    "olive": (104, 108, 68),
    "sage": (150, 166, 140),
    "emerald": (32, 118, 90),
    "burgundy": (108, 34, 48),
    "rust": (166, 84, 48),
    "camel": (186, 146, 96),
    "tan": (188, 152, 110),
    "brown": (110, 80, 56),
    "beige": (206, 190, 164),
    "khaki": (176, 158, 118),
    "stone": (176, 172, 160),
    "floral": (196, 130, 150),
    "striped": (110, 130, 170),
}

CATEGORY_FALLBACK: dict[GarmentCategory, tuple[int, int, int]] = {
    GarmentCategory.top: (110, 94, 252),
    GarmentCategory.bottom: (76, 86, 112),
    GarmentCategory.dress: (200, 108, 158),
    GarmentCategory.outerwear: (76, 78, 92),
    GarmentCategory.footwear: (198, 198, 206),
}


def colour_for(name: str, category: GarmentCategory) -> tuple[int, int, int]:
    lowered = name.lower()
    for word in sorted(COLOUR_WORDS, key=len, reverse=True):
        if word in lowered:
            return COLOUR_WORDS[word]
    return CATEGORY_FALLBACK.get(category, (140, 140, 150))


# ---------------------------------------------------------------------------
# Shapes — normalised polygons in a 0..1 square, y increasing downward
# ---------------------------------------------------------------------------

TEE = [
    (0.30, 0.20), (0.40, 0.16), (0.60, 0.16), (0.70, 0.20),
    (0.86, 0.32), (0.78, 0.42), (0.71, 0.36), (0.71, 0.84),
    (0.29, 0.84), (0.29, 0.36), (0.22, 0.42), (0.14, 0.32),
]
COAT = [
    (0.28, 0.18), (0.40, 0.14), (0.60, 0.14), (0.72, 0.18),
    (0.88, 0.34), (0.80, 0.46), (0.74, 0.40), (0.74, 0.88),
    (0.26, 0.88), (0.26, 0.40), (0.20, 0.46), (0.12, 0.34),
]
PANTS = [
    (0.30, 0.16), (0.70, 0.16), (0.72, 0.88), (0.56, 0.88),
    (0.50, 0.50), (0.44, 0.88), (0.28, 0.88),
]
DRESS = [
    (0.34, 0.18), (0.42, 0.14), (0.58, 0.14), (0.66, 0.18),
    (0.72, 0.34), (0.66, 0.38), (0.82, 0.88), (0.18, 0.88), (0.34, 0.38), (0.28, 0.34),
]
SHOE = [
    (0.16, 0.62), (0.34, 0.60), (0.44, 0.48), (0.54, 0.46),
    (0.60, 0.56), (0.84, 0.64), (0.86, 0.72), (0.16, 0.72),
]

SHAPES = {
    GarmentCategory.top: TEE,
    GarmentCategory.outerwear: COAT,
    GarmentCategory.bottom: PANTS,
    GarmentCategory.dress: DRESS,
    GarmentCategory.footwear: SHOE,
}


def polygon_mask(points: list[tuple[float, float]], size: int) -> np.ndarray:
    """Even-odd scanline fill, supersampled 3x for smooth edges."""
    ss = 3
    n = size * ss
    xs = np.array([p[0] for p in points]) * n
    ys = np.array([p[1] for p in points]) * n
    mask = np.zeros((n, n), dtype=bool)

    for y in range(n):
        crossings = []
        for i in range(len(points)):
            y0, y1 = ys[i], ys[(i + 1) % len(points)]
            x0, x1 = xs[i], xs[(i + 1) % len(points)]
            if (y0 <= y < y1) or (y1 <= y < y0):
                crossings.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        crossings.sort()
        for a, b in zip(crossings[0::2], crossings[1::2], strict=False):
            mask[y, int(max(0, a)) : int(min(n, b))] = True

    # Box-downsample to antialias.
    return mask.reshape(size, ss, size, ss).mean(axis=(1, 3))


def render(name: str, category: GarmentCategory) -> bytes:
    rgb = colour_for(name, category)
    shape = SHAPES.get(category, TEE)
    alpha = polygon_mask(shape, SIZE)[..., None]

    # Neutral studio backdrop, slightly tinted by the garment so the grid reads
    # as varied without the tiles shouting.
    top = np.array([32, 32, 36], dtype=float)
    bottom = np.array([22, 22, 26], dtype=float)
    ramp = np.linspace(0, 1, SIZE)[:, None, None]
    canvas = top * (1 - ramp) + bottom * ramp
    tint = np.array(rgb, dtype=float) * 0.10
    canvas = canvas + tint

    garment = np.array(rgb, dtype=float)[None, None, :] * np.ones((SIZE, SIZE, 3))
    # Soft vertical shading so the silhouette reads as fabric, not a flat decal.
    shade = 1.0 - 0.18 * np.linspace(0, 1, SIZE)[:, None, None]
    garment = garment * shade

    out = canvas * (1 - alpha) + garment * alpha
    return encode_png(np.clip(out, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------------------


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="regenerate existing artwork")
    args = parser.parse_args()

    settings = get_settings()
    storage = get_storage()
    bucket = settings.s3_bucket_garments

    async with get_sessionmaker()() as db:
        garments = (await db.execute(select(Garment))).scalars().all()
        done = 0
        for g in garments:
            if g.thumb_key and not args.force:
                continue
            png = render(g.name, g.category)
            key = f"catalog/{g.id}/thumb.png"
            storage.put_object(bucket, key, png, "image/png")
            g.thumb_key = key
            done += 1
        await db.commit()
        print(f"Artwork: {len(garments)} garments, {done} rendered, bucket={bucket}")


if __name__ == "__main__":
    asyncio.run(main())
