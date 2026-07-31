"""Tests for 1.4 backend: real avatar mesh, admin CRUD, sync, sessions, progress."""

from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import select

from tests.conftest import auth_headers, grant_scan_consent
from tests.helpers import run_full_scan
from wardrobe_core.config import get_settings
from wardrobe_core.db import get_sessionmaker
from wardrobe_core.models import User
from wardrobe_core.storage import avatar_mesh_key, get_storage


async def _make_admin(email: str) -> None:
    maker = get_sessionmaker()
    async with maker() as db:
        u = (await db.execute(select(User).where(User.email == email))).scalar_one()
        u.is_admin = True
        await db.commit()


async def test_real_avatar_glb_is_generated(client: TestClient) -> None:
    settings = get_settings()
    storage = get_storage()
    headers = auth_headers(client, "mesh@example.com")
    grant_scan_consent(client, headers)
    result = run_full_scan(client, headers, height_cm=182)

    # Job reached 100% progress.
    job = client.get(f"/jobs/{result['job_id']}", headers=headers).json()
    assert job["progress"] == 100

    me = client.get("/me", headers=headers).json()
    avatar = client.get("/avatars", headers=headers).json()[0]
    glb = storage.get_object(
        settings.s3_bucket_avatars, avatar_mesh_key(_uuid(me["id"]), _uuid(avatar["id"]))
    )
    # A REAL mesh, not the empty placeholder.
    assert glb[:4] == b"glTF"
    assert len(glb) > 10_000


async def test_preferences_sync(client: TestClient) -> None:
    headers = auth_headers(client, "prefs@example.com")
    assert client.get("/me/preferences", headers=headers).json()["data"] == {}
    put = client.put("/me/preferences", headers=headers, json={"data": {"units": "imperial"}})
    assert put.status_code == 200
    got = client.get("/me/preferences", headers=headers).json()
    assert got["data"]["units"] == "imperial"


async def test_list_scans_and_sessions(client: TestClient) -> None:
    headers = auth_headers(client, "list@example.com")
    grant_scan_consent(client, headers)
    run_full_scan(client, headers)
    scans = client.get("/scans", headers=headers).json()
    assert len(scans) == 1
    sessions = client.get("/me/sessions", headers=headers).json()
    assert len(sessions) >= 1
    sid = sessions[0]["id"]
    assert client.delete(f"/me/sessions/{sid}", headers=headers).status_code == 204


async def test_admin_garment_crud(client: TestClient) -> None:
    user = auth_headers(client, "shopadmin@example.com")
    # Non-admin is forbidden.
    body = {"brand": "B", "name": "Tank", "category": "top"}
    assert client.post("/garments", headers=user, json=body).status_code == 403

    await _make_admin("shopadmin@example.com")
    admin = auth_headers(client, "shopadmin@example.com")  # fresh session, now admin
    created = client.post("/garments", headers=admin, json={
        "brand": "B", "name": "Tank Top", "category": "top", "price_cents": 1200,
        "sizes": [{"size_label": "M", "measurements": {"chest_cm": 98}}],
    })
    assert created.status_code == 201, created.text
    gid = created.json()["id"]
    patched = client.patch(f"/garments/{gid}", headers=admin, json={"price_cents": 999})
    assert patched.status_code == 200
    assert client.delete(f"/garments/{gid}", headers=admin).status_code == 204


async def test_admin_audit_requires_admin(client: TestClient) -> None:
    user = auth_headers(client, "notadmin@example.com")
    assert client.get("/admin/audit", headers=user).status_code == 403
    await _make_admin("notadmin@example.com")
    admin = auth_headers(client, "notadmin@example.com")
    r = client.get("/admin/audit", headers=admin)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def _uuid(s: str):  # noqa: ANN202
    import uuid

    return uuid.UUID(s)
