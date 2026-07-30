"""End-to-end MVP flow + privacy guarantees.

Mirrors the spec's minimum E2E test: register → consent → scan → mock avatar →
add shirt → save outfit → second device sees it → delete → assets 404."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, grant_scan_consent, seed_garment
from tests.helpers import run_full_scan
from wardrobe_core.config import get_settings
from wardrobe_core.storage import avatar_mesh_key, get_storage


async def test_full_flow_and_cross_device_sync(client: TestClient) -> None:
    garment_id = await seed_garment()

    # 1) register + consent
    device1 = auth_headers(client, "user@example.com")
    grant_scan_consent(client, device1)

    # 2) scan → mock avatar
    result = run_full_scan(client, device1, height_cm=180)
    assert result["status"] == "completed"

    avatars = client.get("/avatars", headers=device1).json()
    assert len(avatars) == 1
    avatar = avatars[0]
    assert avatar["status"] == "completed"
    assert avatar["is_mock"] is True  # never claims real reconstruction
    # measurements were estimated from height
    assert avatar["measurements"]["height_cm"] == 180.0

    # 3) add a shirt + save outfit
    created = client.post(
        "/outfits",
        headers=device1,
        json={
            "name": "Everyday",
            "avatar_id": avatar["id"],
            "items": [{"garment_id": str(garment_id), "size_label": "M", "layer_index": 10}],
        },
    )
    assert created.status_code == 201
    outfit_id = created.json()["id"]

    # 4) second device (same account) sees the outfit → cross-device sync
    device2 = auth_headers(client, "user@example.com")
    synced = client.get(f"/outfits/{outfit_id}", headers=device2)
    assert synced.status_code == 200
    assert synced.json()["name"] == "Everyday"
    assert len(synced.json()["items"]) == 1


async def test_raw_scans_deleted_after_avatar(client: TestClient) -> None:
    headers = auth_headers(client, "privacy@example.com")
    grant_scan_consent(client, headers)
    result = run_full_scan(client, headers)

    # The scan's image rows are gone (hard-deleted) after avatar generation.
    scan = client.get(f"/scans/{result['scan_id']}", headers=headers).json()
    assert scan["images"] == []


async def test_delete_scan_and_account_erases_assets(client: TestClient) -> None:
    settings = get_settings()
    storage = get_storage()
    headers = auth_headers(client, "erase@example.com")
    grant_scan_consent(client, headers)

    run_full_scan(client, headers)
    me = client.get("/me", headers=headers).json()
    avatar = client.get("/avatars", headers=headers).json()[0]
    mesh_key = avatar_mesh_key_for(me["id"], avatar["id"])

    # avatar object exists in private storage
    assert storage.head_object(settings.s3_bucket_avatars, mesh_key) is not None

    # Permanent account deletion
    resp = client.post("/account/deletion-request", headers=headers, json={"scope": "full_account"})
    assert resp.status_code == 202
    assert resp.json()["status"] == "completed"

    # Session revoked → token no longer works
    assert client.get("/me", headers=headers).status_code == 401
    # Avatar object erased from storage
    assert storage.head_object(settings.s3_bucket_avatars, mesh_key) is None


def avatar_mesh_key_for(user_id: str, avatar_id: str) -> str:
    import uuid

    return avatar_mesh_key(uuid.UUID(user_id), uuid.UUID(avatar_id))
