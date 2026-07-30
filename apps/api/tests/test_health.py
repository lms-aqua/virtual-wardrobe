"""Smoke tests for Phase 2: the app boots and security headers are applied."""

from __future__ import annotations

from fastapi.testclient import TestClient

from wardrobe_core.main import create_app


def _client() -> TestClient:
    return TestClient(create_app())


def test_liveness_ok() -> None:
    with _client() as client:
        resp = client.get("/health/live")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert "version" in body


def test_security_headers_present() -> None:
    with _client() as client:
        resp = client.get("/health/live")
    assert resp.headers["X-Content-Type-Options"] == "nosniff"
    assert resp.headers["X-Frame-Options"] == "DENY"
    assert resp.headers["Referrer-Policy"] == "no-referrer"
    assert "default-src 'none'" in resp.headers["Content-Security-Policy"]


def test_docs_hidden_in_production(monkeypatch) -> None:  # noqa: ANN001
    # Rebuild settings + app under production env; docs must be disabled.
    import wardrobe_core.config as config

    monkeypatch.setenv("WARDROBE_ENV", "production")
    config.get_settings.cache_clear()
    with TestClient(create_app()) as client:
        assert client.get("/docs").status_code == 404
    config.get_settings.cache_clear()
