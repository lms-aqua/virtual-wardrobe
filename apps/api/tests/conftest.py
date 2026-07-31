"""Shared test fixtures.

Env is configured before any wardrobe_core import so config validation passes
and the app uses a throwaway SQLite DB + the in-memory storage backend (no
Postgres / MinIO needed). Jobs run inline so the scan pipeline is deterministic.
"""

from __future__ import annotations

import os
import uuid

os.environ.setdefault("SECRET_KEY", "test-secret-key-not-for-production-use")
os.environ.setdefault("WARDROBE_ENV", "development")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./_vw_test.db")
os.environ.setdefault("RUN_JOBS_INLINE", "true")
os.environ.setdefault("DELETE_RAW_SCANS_AFTER_AVATAR", "true")

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from wardrobe_core import models  # noqa: E402,F401  (populate metadata)
from wardrobe_core.db import Base, get_engine, get_sessionmaker  # noqa: E402
from wardrobe_core.main import create_app  # noqa: E402
from wardrobe_core.storage import InMemoryStorage, set_storage  # noqa: E402


@pytest_asyncio.fixture(autouse=True)
async def _reset_db():
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    set_storage(InMemoryStorage())
    # Reset the in-process rate limiter so per-IP counts don't leak across tests.
    from wardrobe_core.deps import _hits

    _hits.clear()
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
def client() -> TestClient:
    return TestClient(create_app())


# ---- helpers ----
def auth_headers(client: TestClient, email: str, *, adult: bool = True) -> dict[str, str]:
    r = client.post("/auth/magic-link", json={"email": email, "is_adult": adult})
    assert r.status_code == 200, r.text
    token = r.json()["dev_token"]
    assert token
    v = client.post("/auth/magic-link/verify", json={"token": token})
    assert v.status_code == 200, v.text
    return {"Authorization": f"Bearer {v.json()['access_token']}"}


def grant_scan_consent(client: TestClient, headers: dict[str, str]) -> None:
    r = client.post("/consents", headers=headers, json={"kind": "scan", "version": "1.0"})
    assert r.status_code == 201, r.text


def make_jpeg(size: int = 4096) -> bytes:
    return b"\xff\xd8\xff\xe0" + os.urandom(size)


async def seed_garment() -> uuid.UUID:
    from wardrobe_core.models import Garment, GarmentSize

    maker = get_sessionmaker()
    async with maker() as db:
        g = Garment(brand="Sample", name="Classic Tee", category="top", layering_order=10)
        g.sizes.append(GarmentSize(size_label="M", measurements={"chest_cm": 100}))
        db.add(g)
        await db.commit()
        return g.id
