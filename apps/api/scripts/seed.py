"""Seed the shared garment catalog with sample, non-copyrighted placeholders.

Run:  python -m scripts.seed
Idempotent: does nothing if garments already exist.
"""

from __future__ import annotations

import asyncio

from sqlalchemy import select

from wardrobe_core import models  # noqa: F401
from wardrobe_core.db import Base, get_engine, get_sessionmaker
from wardrobe_core.enums import GarmentCategory
from wardrobe_core.models import Garment, GarmentSize

SAMPLE = [
    ("Sample", "Classic T-Shirt", GarmentCategory.top, 10, {"chest_cm": 100}),
    ("Sample", "Blouse", GarmentCategory.top, 12, {"chest_cm": 96}),
    ("Sample", "Hoodie", GarmentCategory.outerwear, 30, {"chest_cm": 110}),
    ("Sample", "Summer Dress", GarmentCategory.dress, 20, {"chest_cm": 92, "hip_cm": 98}),
    ("Sample", "Jeans", GarmentCategory.bottom, 20, {"waist_cm": 80, "inseam_cm": 78}),
    ("Sample", "Skirt", GarmentCategory.bottom, 20, {"waist_cm": 76}),
    ("Sample", "Jacket", GarmentCategory.outerwear, 35, {"chest_cm": 112}),
    ("Sample", "Sneakers", GarmentCategory.footwear, 5, {}),
]
SIZES = ["S", "M", "L"]


async def main() -> None:
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    maker = get_sessionmaker()
    async with maker() as db:
        existing = (await db.execute(select(Garment.id))).first()
        if existing:
            print("Garments already seeded; nothing to do.")
            return
        for brand, name, category, layer, meas in SAMPLE:
            g = Garment(
                brand=brand, name=name, category=category, layering_order=layer,
                gender_neutral=True, fabric_props={"stretch": 0.1},
            )
            for size in SIZES:
                g.sizes.append(GarmentSize(size_label=size, measurements=meas))
            db.add(g)
        await db.commit()
        print(f"Seeded {len(SAMPLE)} sample garments.")


if __name__ == "__main__":
    asyncio.run(main())
