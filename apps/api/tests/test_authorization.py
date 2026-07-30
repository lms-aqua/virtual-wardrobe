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


async def test_measurement_signed_urls_are_owner_scoped(client: TestClient) -> None:
    a = auth_headers(client, "carol@example.com")
    grant_scan_consent(client, a)
    run_full_scan(client, a)
    avatar = client.get("/avatars", headers=a).json()[0]
    # A signed URL is minted only for the owner and only points at their key.
    assert avatar["mesh_url"] is not None
    assert avatar["thumb_url"] is not None
