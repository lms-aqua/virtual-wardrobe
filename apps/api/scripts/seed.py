"""Seed the shared garment catalog + an admin user.

Run:  python -m scripts.seed
Idempotent-ish: skips garment seeding if garments already exist; always ensures
the admin user's is_admin flag. Set ADMIN_EMAIL to control the admin account.
"""

from __future__ import annotations

import asyncio
import os

from sqlalchemy import select

from wardrobe_core import models  # noqa: F401
from wardrobe_core.db import Base, get_engine, get_sessionmaker
from wardrobe_core.enums import GarmentCategory
from wardrobe_core.models import Garment, GarmentSize, User

SAMPLE = [
    ("Sample", "Classic T-Shirt", GarmentCategory.top, 10, {"chest_cm": 100}, 1900),
    ("Sample", "Blouse", GarmentCategory.top, 12, {"chest_cm": 96}, 3400),
    ("Sample", "Hoodie", GarmentCategory.outerwear, 30, {"chest_cm": 110}, 5900),
    ("Sample", "Summer Dress", GarmentCategory.dress, 20, {"chest_cm": 92, "hip_cm": 98}, 6400),
    ("Sample", "Jeans", GarmentCategory.bottom, 20, {"waist_cm": 80, "inseam_cm": 78}, 7200),
    ("Sample", "Skirt", GarmentCategory.bottom, 20, {"waist_cm": 76}, 4200),
    ("Sample", "Jacket", GarmentCategory.outerwear, 35, {"chest_cm": 112}, 9900),
    ("Sample", "Sneakers", GarmentCategory.footwear, 5, {}, 8500),
]
SIZES = ["S", "M", "L"]
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@virtualwardrobe.local").lower()


async def main() -> None:
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    maker = get_sessionmaker()
    async with maker() as db:
        # Admin user
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

        existing = (await db.execute(select(Garment.id))).first()
        if existing:
            print("Garments already seeded; nothing to do.")
            return
        for brand, name, category, layer, meas, price in SAMPLE:
            slug = name.lower().replace(" ", "-")
            g = Garment(
                brand=brand, name=name, category=category, layering_order=layer,
                gender_neutral=True, fabric_props={"stretch": 0.1},
                price_cents=price, product_url=f"https://example.com/shop/{slug}",
            )
            for size in SIZES:
                g.sizes.append(GarmentSize(size_label=size, measurements=meas))
            db.add(g)
        await db.commit()
        print(f"Seeded {len(SAMPLE)} sample garments.")


if __name__ == "__main__":
    asyncio.run(main())
