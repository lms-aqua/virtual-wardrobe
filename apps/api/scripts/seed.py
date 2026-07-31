"""Seed the shared garment catalog + an admin user.

Run:  python -m scripts.seed

Adds any catalog garment that is not already present (matched on brand + name),
so re-running after the catalog grows tops it up instead of doing nothing. The
admin user's is_admin flag is always ensured. Set ADMIN_EMAIL to control the
admin account.
"""

from __future__ import annotations

import asyncio
import os

from sqlalchemy import select

from wardrobe_core import models  # noqa: F401
from wardrobe_core.db import Base, get_engine, get_sessionmaker
from wardrobe_core.enums import GarmentCategory
from wardrobe_core.models import Garment, GarmentSize, User

C = GarmentCategory

# ---------------------------------------------------------------------------
# Size grading
#
# Every size used to be seeded with IDENTICAL measurements, which made
# SizeRecommender useless: it picks the size whose chest/waist is closest to the
# user's, and with all sizes equal there was nothing to discriminate. Sizes are
# now graded off a base (the M measurement) with realistic per-step increments.
# ---------------------------------------------------------------------------

ALPHA_SIZES = ["XS", "S", "M", "L", "XL", "XXL"]
# Steps from M, in "size units" (M = 0).
ALPHA_OFFSET = {"XS": -2, "S": -1, "M": 0, "L": 1, "XL": 2, "XXL": 3}

# cm added per size step, by measurement.
GRADE = {
    "chest_cm": 5.0,
    "underbust_cm": 5.0,
    "waist_cm": 4.5,
    "hip_cm": 4.5,
    "shoulder_cm": 1.2,
    "inseam_cm": 1.0,
    "arm_cm": 1.0,
}

# Footwear is graded on its own scale (EU-ish numeric).
SHOE_SIZES = ["39", "40", "41", "42", "43", "44", "45"]


def graded(base: dict[str, float], size: str) -> dict[str, float]:
    """Grade a base (M) measurement set up or down to `size`."""
    step = ALPHA_OFFSET[size]
    out: dict[str, float] = {}
    for key, value in base.items():
        out[key] = round(value + GRADE.get(key, 3.0) * step, 1)
    return out


# ---------------------------------------------------------------------------
# Catalog
#
# Names deliberately carry a colour/material word. The iOS client derives each
# tile's tint from the garment name (GarmentAppearance), so "Indigo Selvedge
# Jeans" and "Charcoal Wool Overcoat" render as visibly different garments
# rather than a wall of identical blocks.
#
# layering_order controls draw order in the 3D try-on: base layers low,
# mid-layers middle, outerwear high, footwear lowest of all.
#
# (brand, name, category, layering_order, base measurements at M, price_cents,
#  fabric_props)
# ---------------------------------------------------------------------------

TOPS = [
    (
        "Northwell",
        "Classic White Tee",
        C.top,
        10,
        {"chest_cm": 100, "shoulder_cm": 45, "arm_cm": 60},
        1900,
        {"stretch": 0.15, "material": "cotton jersey"},
    ),
    (
        "Northwell",
        "Heather Grey Tee",
        C.top,
        10,
        {"chest_cm": 100, "shoulder_cm": 45, "arm_cm": 60},
        1900,
        {"stretch": 0.15, "material": "cotton jersey"},
    ),
    (
        "Northwell",
        "Black Pocket Tee",
        C.top,
        10,
        {"chest_cm": 102, "shoulder_cm": 46, "arm_cm": 61},
        2200,
        {"stretch": 0.15, "material": "cotton jersey"},
    ),
    (
        "Northwell",
        "Navy Striped Tee",
        C.top,
        10,
        {"chest_cm": 100, "shoulder_cm": 45, "arm_cm": 60},
        2400,
        {"stretch": 0.15, "material": "cotton jersey"},
    ),
    (
        "Atelier Fen",
        "Ivory Silk Blouse",
        C.top,
        12,
        {"chest_cm": 94, "shoulder_cm": 41, "arm_cm": 58},
        8900,
        {"stretch": 0.05, "material": "silk"},
    ),
    (
        "Atelier Fen",
        "Blush Crepe Blouse",
        C.top,
        12,
        {"chest_cm": 94, "shoulder_cm": 41, "arm_cm": 58},
        7900,
        {"stretch": 0.06, "material": "crepe"},
    ),
    (
        "Atelier Fen",
        "Black Tie-Neck Blouse",
        C.top,
        12,
        {"chest_cm": 96, "shoulder_cm": 42, "arm_cm": 59},
        8400,
        {"stretch": 0.05, "material": "viscose"},
    ),
    (
        "Harbour & Co",
        "White Oxford Shirt",
        C.top,
        14,
        {"chest_cm": 104, "shoulder_cm": 46, "arm_cm": 63},
        6500,
        {"stretch": 0.03, "material": "oxford cotton"},
    ),
    (
        "Harbour & Co",
        "Blue Chambray Shirt",
        C.top,
        14,
        {"chest_cm": 104, "shoulder_cm": 46, "arm_cm": 63},
        6900,
        {"stretch": 0.04, "material": "chambray"},
    ),
    (
        "Harbour & Co",
        "Olive Flannel Shirt",
        C.top,
        14,
        {"chest_cm": 108, "shoulder_cm": 47, "arm_cm": 64},
        7400,
        {"stretch": 0.04, "material": "brushed flannel"},
    ),
    (
        "Harbour & Co",
        "Charcoal Merino Knit",
        C.top,
        16,
        {"chest_cm": 102, "shoulder_cm": 45, "arm_cm": 62},
        9800,
        {"stretch": 0.2, "material": "merino wool"},
    ),
    (
        "Harbour & Co",
        "Cream Cable Knit",
        C.top,
        16,
        {"chest_cm": 106, "shoulder_cm": 46, "arm_cm": 62},
        11900,
        {"stretch": 0.18, "material": "lambswool"},
    ),
    (
        "Northwell",
        "Navy Polo",
        C.top,
        11,
        {"chest_cm": 102, "shoulder_cm": 45, "arm_cm": 24},
        4200,
        {"stretch": 0.12, "material": "pique cotton"},
    ),
    (
        "Northwell",
        "Sage Linen Shirt",
        C.top,
        14,
        {"chest_cm": 106, "shoulder_cm": 47, "arm_cm": 62},
        6800,
        {"stretch": 0.02, "material": "linen"},
    ),
    (
        "Rill Studio",
        "Rust Ribbed Top",
        C.top,
        10,
        {"chest_cm": 90, "shoulder_cm": 38, "arm_cm": 56},
        3600,
        {"stretch": 0.35, "material": "ribbed modal"},
    ),
    (
        "Rill Studio",
        "Black Turtleneck",
        C.top,
        12,
        {"chest_cm": 94, "shoulder_cm": 40, "arm_cm": 60},
        5400,
        {"stretch": 0.3, "material": "modal knit"},
    ),
]

BOTTOMS = [
    (
        "Ridgeway Denim",
        "Indigo Selvedge Jeans",
        C.bottom,
        20,
        {"waist_cm": 82, "hip_cm": 100, "inseam_cm": 81},
        12900,
        {"stretch": 0.02, "material": "selvedge denim"},
    ),
    (
        "Ridgeway Denim",
        "Washed Black Jeans",
        C.bottom,
        20,
        {"waist_cm": 82, "hip_cm": 100, "inseam_cm": 81},
        9900,
        {"stretch": 0.12, "material": "stretch denim"},
    ),
    (
        "Ridgeway Denim",
        "Light Wash Jeans",
        C.bottom,
        20,
        {"waist_cm": 84, "hip_cm": 102, "inseam_cm": 80},
        8900,
        {"stretch": 0.1, "material": "stretch denim"},
    ),
    (
        "Ridgeway Denim",
        "Wide Leg Jeans",
        C.bottom,
        20,
        {"waist_cm": 80, "hip_cm": 104, "inseam_cm": 79},
        10900,
        {"stretch": 0.04, "material": "rigid denim"},
    ),
    (
        "Harbour & Co",
        "Stone Slim Chinos",
        C.bottom,
        20,
        {"waist_cm": 82, "hip_cm": 100, "inseam_cm": 80},
        7200,
        {"stretch": 0.08, "material": "cotton twill"},
    ),
    (
        "Harbour & Co",
        "Navy Tailored Trousers",
        C.bottom,
        22,
        {"waist_cm": 80, "hip_cm": 100, "inseam_cm": 82},
        11900,
        {"stretch": 0.06, "material": "wool blend"},
    ),
    (
        "Harbour & Co",
        "Charcoal Wool Trousers",
        C.bottom,
        22,
        {"waist_cm": 82, "hip_cm": 102, "inseam_cm": 82},
        13900,
        {"stretch": 0.05, "material": "wool"},
    ),
    (
        "Northwell",
        "Olive Cargo Pants",
        C.bottom,
        20,
        {"waist_cm": 86, "hip_cm": 106, "inseam_cm": 79},
        7900,
        {"stretch": 0.07, "material": "ripstop cotton"},
    ),
    (
        "Northwell",
        "Grey Jersey Joggers",
        C.bottom,
        18,
        {"waist_cm": 80, "hip_cm": 102, "inseam_cm": 74},
        5400,
        {"stretch": 0.3, "material": "cotton fleece"},
    ),
    (
        "Northwell",
        "Khaki Chino Shorts",
        C.bottom,
        18,
        {"waist_cm": 84, "hip_cm": 102, "inseam_cm": 18},
        4900,
        {"stretch": 0.08, "material": "cotton twill"},
    ),
    (
        "Rill Studio",
        "Black Pleated Skirt",
        C.bottom,
        20,
        {"waist_cm": 72, "hip_cm": 98},
        6400,
        {"stretch": 0.03, "material": "polyester crepe"},
    ),
    (
        "Rill Studio",
        "Camel Midi Skirt",
        C.bottom,
        20,
        {"waist_cm": 72, "hip_cm": 98},
        7400,
        {"stretch": 0.05, "material": "wool blend"},
    ),
    (
        "Rill Studio",
        "Denim Mini Skirt",
        C.bottom,
        20,
        {"waist_cm": 74, "hip_cm": 96},
        5200,
        {"stretch": 0.1, "material": "stretch denim"},
    ),
]

DRESSES = [
    (
        "Rill Studio",
        "Black Slip Dress",
        C.dress,
        24,
        {"chest_cm": 90, "waist_cm": 74, "hip_cm": 98},
        9800,
        {"stretch": 0.06, "material": "satin"},
    ),
    (
        "Rill Studio",
        "Emerald Wrap Dress",
        C.dress,
        24,
        {"chest_cm": 92, "waist_cm": 76, "hip_cm": 100},
        11900,
        {"stretch": 0.12, "material": "jersey"},
    ),
    (
        "Rill Studio",
        "Floral Summer Dress",
        C.dress,
        24,
        {"chest_cm": 90, "waist_cm": 74, "hip_cm": 98},
        7900,
        {"stretch": 0.04, "material": "viscose"},
    ),
    (
        "Atelier Fen",
        "Navy Shirt Dress",
        C.dress,
        24,
        {"chest_cm": 96, "waist_cm": 80, "hip_cm": 102},
        10900,
        {"stretch": 0.05, "material": "cotton poplin"},
    ),
    (
        "Atelier Fen",
        "Ivory Linen Dress",
        C.dress,
        24,
        {"chest_cm": 94, "waist_cm": 78, "hip_cm": 100},
        12400,
        {"stretch": 0.02, "material": "linen"},
    ),
    (
        "Atelier Fen",
        "Burgundy Knit Dress",
        C.dress,
        24,
        {"chest_cm": 92, "waist_cm": 76, "hip_cm": 99},
        13900,
        {"stretch": 0.25, "material": "fine knit"},
    ),
]

OUTERWEAR = [
    (
        "Northwell",
        "Grey Pullover Hoodie",
        C.outerwear,
        30,
        {"chest_cm": 112, "shoulder_cm": 49, "arm_cm": 63},
        6900,
        {"stretch": 0.2, "material": "cotton fleece"},
    ),
    (
        "Northwell",
        "Black Zip Hoodie",
        C.outerwear,
        30,
        {"chest_cm": 112, "shoulder_cm": 49, "arm_cm": 63},
        7400,
        {"stretch": 0.2, "material": "cotton fleece"},
    ),
    (
        "Ridgeway Denim",
        "Indigo Denim Jacket",
        C.outerwear,
        32,
        {"chest_cm": 110, "shoulder_cm": 48, "arm_cm": 63},
        11900,
        {"stretch": 0.03, "material": "rigid denim"},
    ),
    (
        "Ridgeway Denim",
        "Black Denim Jacket",
        C.outerwear,
        32,
        {"chest_cm": 110, "shoulder_cm": 48, "arm_cm": 63},
        11900,
        {"stretch": 0.05, "material": "stretch denim"},
    ),
    (
        "Harbour & Co",
        "Charcoal Wool Overcoat",
        C.outerwear,
        36,
        {"chest_cm": 116, "shoulder_cm": 50, "arm_cm": 65},
        28900,
        {"stretch": 0.02, "material": "wool melton"},
    ),
    (
        "Harbour & Co",
        "Camel Wool Coat",
        C.outerwear,
        36,
        {"chest_cm": 116, "shoulder_cm": 50, "arm_cm": 65},
        31900,
        {"stretch": 0.02, "material": "wool cashmere"},
    ),
    (
        "Harbour & Co",
        "Navy Wool Blazer",
        C.outerwear,
        34,
        {"chest_cm": 108, "shoulder_cm": 47, "arm_cm": 64},
        18900,
        {"stretch": 0.04, "material": "wool"},
    ),
    (
        "Harbour & Co",
        "Beige Trench Coat",
        C.outerwear,
        36,
        {"chest_cm": 114, "shoulder_cm": 49, "arm_cm": 64},
        24900,
        {"stretch": 0.02, "material": "cotton gabardine"},
    ),
    (
        "Northwell",
        "Olive Field Jacket",
        C.outerwear,
        32,
        {"chest_cm": 112, "shoulder_cm": 48, "arm_cm": 63},
        13900,
        {"stretch": 0.04, "material": "waxed cotton"},
    ),
    (
        "Northwell",
        "Black Puffer Jacket",
        C.outerwear,
        38,
        {"chest_cm": 120, "shoulder_cm": 51, "arm_cm": 65},
        16900,
        {"stretch": 0.06, "material": "recycled nylon"},
    ),
    (
        "Northwell",
        "Tan Leather Jacket",
        C.outerwear,
        34,
        {"chest_cm": 108, "shoulder_cm": 47, "arm_cm": 63},
        34900,
        {"stretch": 0.03, "material": "lambskin"},
    ),
    (
        "Rill Studio",
        "Cream Cardigan",
        C.outerwear,
        28,
        {"chest_cm": 106, "shoulder_cm": 46, "arm_cm": 61},
        8900,
        {"stretch": 0.22, "material": "cotton knit"},
    ),
]

FOOTWEAR = [
    ("Sole Theory", "White Leather Sneakers", C.footwear, 5, {}, 11900, {"material": "leather"}),
    ("Sole Theory", "Black Canvas Sneakers", C.footwear, 5, {}, 6900, {"material": "canvas"}),
    (
        "Sole Theory",
        "Grey Running Shoes",
        C.footwear,
        5,
        {},
        13900,
        {"material": "engineered mesh"},
    ),
    ("Sole Theory", "Tan Chelsea Boots", C.footwear, 5, {}, 18900, {"material": "suede"}),
    ("Sole Theory", "Brown Leather Derby", C.footwear, 5, {}, 21900, {"material": "calf leather"}),
    ("Sole Theory", "Black Ankle Boots", C.footwear, 5, {}, 17900, {"material": "leather"}),
    ("Sole Theory", "Navy Loafers", C.footwear, 5, {}, 15900, {"material": "suede"}),
]

CATALOG = TOPS + BOTTOMS + DRESSES + OUTERWEAR + FOOTWEAR

ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@virtualwardrobe.app").lower()


def slugify(brand: str, name: str) -> str:
    raw = f"{brand}-{name}".lower()
    return "".join(ch if ch.isalnum() else "-" for ch in raw).strip("-").replace("--", "-")


async def main() -> None:
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    maker = get_sessionmaker()
    async with maker() as db:
        admin = (
            await db.execute(select(User).where(User.email == ADMIN_EMAIL))
        ).scalar_one_or_none()
        if admin is None:
            admin = User(email=ADMIN_EMAIL, is_adult=True, is_admin=True)
            db.add(admin)
        else:
            admin.is_admin = True
        await db.commit()
        print(f"Admin user ready: {ADMIN_EMAIL}")

        # Top up rather than all-or-nothing: the old script bailed entirely if a
        # single garment existed, so growing the catalog never reached a
        # database that had already been seeded.
        existing = {
            (b, n) for b, n in (await db.execute(select(Garment.brand, Garment.name))).all()
        }

        added = 0
        for brand, name, category, layer, base, price, fabric in CATALOG:
            if (brand, name) in existing:
                continue
            g = Garment(
                brand=brand,
                name=name,
                category=category,
                layering_order=layer,
                gender_neutral=True,
                fabric_props=fabric,
                price_cents=price,
                product_url=f"https://example.com/shop/{slugify(brand, name)}",
            )
            if category == C.footwear:
                for size in SHOE_SIZES:
                    g.sizes.append(GarmentSize(size_label=size, measurements={}))
            else:
                for size in ALPHA_SIZES:
                    g.sizes.append(GarmentSize(size_label=size, measurements=graded(base, size)))
            db.add(g)
            added += 1

        await db.commit()
        print(
            f"Catalog: {len(CATALOG)} defined, {added} added, {len(existing)} already present."
        )


if __name__ == "__main__":
    asyncio.run(main())
