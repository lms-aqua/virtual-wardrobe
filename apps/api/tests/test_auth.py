"""Auth + consent behavior."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers


async def test_magic_link_requires_adult(client: TestClient) -> None:
    r = client.post("/auth/magic-link", json={"email": "kid@example.com", "is_adult": False})
    assert r.status_code == 400
    assert "adults_only" in r.text


async def test_login_and_me(client: TestClient) -> None:
    headers = auth_headers(client, "a@example.com")
    me = client.get("/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "a@example.com"
    assert me.json()["is_adult"] is True


async def test_unauthenticated_is_401(client: TestClient) -> None:
    assert client.get("/me").status_code == 401
    assert client.get("/avatars").status_code == 401


async def test_invalid_token_rejected(client: TestClient) -> None:
    r = client.post("/auth/magic-link/verify", json={"token": "garbage"})
    assert r.status_code == 400


async def test_scan_requires_consent(client: TestClient) -> None:
    headers = auth_headers(client, "noconsent@example.com")
    r = client.post("/scans", headers=headers, json={"height_cm": 175})
    assert r.status_code == 403
    assert "scan_consent_required" in r.text
