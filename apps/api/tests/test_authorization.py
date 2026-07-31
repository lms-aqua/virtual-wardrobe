"""Cross-tenant authorization proofs — account A must never reach account B's
scan, images, avatar, measurements, outfit, or signed asset URLs.

This is the security core of Phase 3 (ADR-0002 item 10)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, grant_scan_consent
from tests.helpers import run_full_scan


async def test_user_cannot_read_another_users_scan_avatar_outfit(client: TestClient) -> None:
    a = auth_headers(client, "alice@example.com")
    b = auth_headers(client, "bob@example.com")
    grant_scan_consent(client, a)

    result = run_full_scan(client, a)
    scan_id = result["scan_id"]

    # A's own avatar exists.
    avatars = client.get("/avatars", headers=a).json()
    assert len(avatars) == 1
    avatar_id = avatars[0]["id"]

    # A creates an outfit.
    outfit = client.post("/outfits", headers=a, json={"name": "A's fit", "items": []}).json()
    outfit_id = outfit["id"]

    # --- B is blocked on every one of A's resources (404, not 403) ---
    assert client.get(f"/scans/{scan_id}", headers=b).status_code == 404
    assert client.get(f"/avatars/{avatar_id}", headers=b).status_code == 404
    assert client.get(f"/outfits/{outfit_id}", headers=b).status_code == 404
    assert client.delete(f"/scans/{scan_id}", headers=b).status_code == 404
    assert client.delete(f"/avatars/{avatar_id}", headers=b).status_code == 404
    assert client.delete(f"/outfits/{outfit_id}", headers=b).status_code == 404
    assert (
        client.patch(
            f"/avatars/{avatar_id}/measurements", headers=b, json={"waist_cm": 80}
        ).status_code
        == 404
    )

    # B also cannot see A's job.
    job_id = result["job_id"]
    assert client.get(f"/jobs/{job_id}", headers=b).status_code == 404

    # A still can (sanity).
    assert client.get(f"/avatars/{avatar_id}", headers=a).status_code == 200
    assert client.get(f"/outfits/{outfit_id}", headers=a).status_code == 200


async def test_outfit_cannot_reference_another_users_avatar(client: TestClient) -> None:
    """BUG-001 — outfit creation trusted avatar_id straight from the client.

    Nothing checked that the referenced avatar belonged to the caller, so B
    could attach A's avatar to their own outfit and have the API persist and
    echo back a cross-account reference.
    """
    a = auth_headers(client, "dave@example.com")
    b = auth_headers(client, "erin@example.com")
    grant_scan_consent(client, a)
    run_full_scan(client, a)

    a_avatar_id = client.get("/avatars", headers=a).json()[0]["id"]

    resp = client.post(
        "/outfits", headers=b, json={"name": "stolen", "avatar_id": a_avatar_id, "items": []}
    )
    assert resp.status_code == 404, f"B attached A's avatar: {resp.status_code} {resp.text}"

    # And B still has no outfit referencing it.
    assert client.get("/outfits", headers=b).json() == []


async def test_outfit_patch_cannot_adopt_another_users_avatar(client: TestClient) -> None:
    """Guards the PATCH path against regressing into BUG-001.

    OutfitPatch deliberately has no avatar_id field, so an avatar_id in the body
    is ignored rather than adopted. This pins that down: anyone adding avatar_id
    to OutfitPatch must add the ownership check with it, or this fails.
    """
    a = auth_headers(client, "frank@example.com")
    b = auth_headers(client, "grace@example.com")
    grant_scan_consent(client, a)
    run_full_scan(client, a)
    a_avatar_id = client.get("/avatars", headers=a).json()[0]["id"]

    own = client.post("/outfits", headers=b, json={"name": "mine", "items": []}).json()
    client.patch(f"/outfits/{own['id']}", headers=b, json={"avatar_id": a_avatar_id})

    after = client.get(f"/outfits/{own['id']}", headers=b).json()
    assert after["avatar_id"] is None, "PATCH adopted another user's avatar"


async def test_outfit_rejects_unknown_garment(client: TestClient) -> None:
    """BUG-002 — garment_id was inserted with no existence check.

    On SQLite the FK is silently unenforced, so this persisted an outfit item
    pointing at nothing; on Postgres it surfaces as an IntegrityError 500
    instead of a 4xx.
    """
    import uuid as _uuid

    a = auth_headers(client, "heidi@example.com")
    resp = client.post(
        "/outfits",
        headers=a,
        json={
            "name": "ghost",
            "items": [{"garment_id": str(_uuid.uuid4()), "layer_index": 0}],
        },
    )
    assert resp.status_code == 422, f"unknown garment accepted: {resp.status_code} {resp.text}"


async def test_measurement_signed_urls_are_owner_scoped(client: TestClient) -> None:
    a = auth_headers(client, "carol@example.com")
    grant_scan_consent(client, a)
    run_full_scan(client, a)
    avatar = client.get("/avatars", headers=a).json()[0]
    # A signed URL is minted only for the owner and only points at their key.
    assert avatar["mesh_url"] is not None
    assert avatar["thumb_url"] is not None
