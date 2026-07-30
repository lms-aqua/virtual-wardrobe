"""Reusable scan-flow helper for tests."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import make_jpeg
from wardrobe_core.config import get_settings
from wardrobe_core.storage import get_storage

VIEWS = ("front", "left", "back", "right")


def run_full_scan(client: TestClient, headers: dict[str, str], height_cm: float = 175.0) -> dict:
    """Create a scan, upload all 4 views into storage, and complete it.
    Returns the completion response JSON."""
    settings = get_settings()
    storage = get_storage()
    bucket = settings.s3_bucket_scans

    scan = client.post(
        "/scans", headers=headers, json={"height_cm": height_cm}
    ).json()
    scan_id = scan["id"]

    for view in VIEWS:
        resp = client.post(
            f"/scans/{scan_id}/upload-url",
            headers=headers,
            json={"view": view, "content_type": "image/jpeg"},
        )
        assert resp.status_code == 200, resp.text
        url = resp.json()["url"]
        key = url.split(f"{bucket}/", 1)[1]  # memory://bucket/<key>
        storage.put_object(bucket, key, make_jpeg(), "image/jpeg")

    done = client.post(f"/scans/{scan_id}/complete", headers=headers)
    assert done.status_code == 200, done.text
    return {"scan_id": scan_id, **done.json()}
