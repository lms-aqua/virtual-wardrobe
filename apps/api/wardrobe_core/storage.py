"""Private object storage abstraction.

Two backends implement one Protocol:
  - ``S3Storage``     — MinIO/S3 in dev/prod. Buckets are private; uploads use
                        presigned POST with a content-length-range + content-type
                        condition so the client physically cannot exceed limits.
  - ``InMemoryStorage`` — used by tests so no MinIO is required.

Object keys are namespaced by user id, so a bug in one layer cannot silently
serve another user's bytes. Signed GET URLs are short-lived (config TTL).
"""

from __future__ import annotations

import uuid
from typing import Protocol, runtime_checkable

from wardrobe_core.config import get_settings


def scan_image_key(user_id: uuid.UUID, scan_id: uuid.UUID, view: str) -> str:
    return f"users/{user_id}/scans/{scan_id}/{view}.bin"


def avatar_mesh_key(user_id: uuid.UUID, avatar_id: uuid.UUID) -> str:
    return f"users/{user_id}/avatars/{avatar_id}/mesh.glb"


def avatar_thumb_key(user_id: uuid.UUID, avatar_id: uuid.UUID) -> str:
    return f"users/{user_id}/avatars/{avatar_id}/thumb.png"


def user_prefix(user_id: uuid.UUID) -> str:
    return f"users/{user_id}/"


@runtime_checkable
class StorageBackend(Protocol):
    def presign_post(self, bucket: str, key: str, content_type: str, max_bytes: int) -> dict: ...
    def presign_get(self, bucket: str, key: str) -> str: ...
    def head_object(self, bucket: str, key: str) -> dict | None: ...
    def get_object(self, bucket: str, key: str) -> bytes: ...
    def put_object(self, bucket: str, key: str, data: bytes, content_type: str) -> None: ...
    def delete_object(self, bucket: str, key: str) -> None: ...
    def delete_prefix(self, bucket: str, prefix: str) -> int: ...


class S3Storage:
    def __init__(self) -> None:
        import boto3
        from botocore.client import Config as BotoConfig

        s = get_settings()
        self._ttl = s.s3_signed_url_ttl_seconds
        self._public_endpoint = s.s3_public_endpoint_url
        # Path-style addressing is required for MinIO / any non-AWS host behind a
        # reverse proxy: URLs become <endpoint>/<bucket>/<key> instead of
        # <bucket>.<endpoint>/<key> (which would need wildcard DNS + TLS).
        cfg = BotoConfig(signature_version="s3v4", s3={"addressing_style": "path"})
        self._client = boto3.client(
            "s3",
            endpoint_url=s.s3_endpoint_url,
            region_name=s.s3_region,
            aws_access_key_id=s.s3_access_key,
            aws_secret_access_key=s.s3_secret_key,
            config=cfg,
        )
        self._public_client = boto3.client(
            "s3",
            endpoint_url=self._public_endpoint,
            region_name=s.s3_region,
            aws_access_key_id=s.s3_access_key,
            aws_secret_access_key=s.s3_secret_key,
            config=cfg,
        )

    def presign_post(self, bucket: str, key: str, content_type: str, max_bytes: int) -> dict:
        return self._public_client.generate_presigned_post(
            Bucket=bucket,
            Key=key,
            Fields={"Content-Type": content_type},
            Conditions=[
                {"Content-Type": content_type},
                ["content-length-range", 1, max_bytes],
            ],
            ExpiresIn=self._ttl,
        )

    def presign_get(self, bucket: str, key: str) -> str:
        return self._public_client.generate_presigned_url(
            "get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=self._ttl
        )

    def head_object(self, bucket: str, key: str) -> dict | None:
        try:
            resp = self._client.head_object(Bucket=bucket, Key=key)
        except self._client.exceptions.ClientError:
            return None
        return {"size": resp["ContentLength"], "content_type": resp.get("ContentType")}

    def get_object(self, bucket: str, key: str) -> bytes:
        resp = self._client.get_object(Bucket=bucket, Key=key)
        return resp["Body"].read()

    def put_object(self, bucket: str, key: str, data: bytes, content_type: str) -> None:
        self._client.put_object(Bucket=bucket, Key=key, Body=data, ContentType=content_type)

    def delete_object(self, bucket: str, key: str) -> None:
        self._client.delete_object(Bucket=bucket, Key=key)

    def delete_prefix(self, bucket: str, prefix: str) -> int:
        paginator = self._client.get_paginator("list_objects_v2")
        count = 0
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
            if keys:
                self._client.delete_objects(Bucket=bucket, Delete={"Objects": keys})
                count += len(keys)
        return count


class InMemoryStorage:
    """Test/dev backend. Not for production."""

    def __init__(self) -> None:
        self._store: dict[tuple[str, str], tuple[bytes, str]] = {}

    def presign_post(self, bucket: str, key: str, content_type: str, max_bytes: int) -> dict:
        return {"url": f"memory://{bucket}/{key}", "fields": {"Content-Type": content_type}}

    def presign_get(self, bucket: str, key: str) -> str:
        return f"memory://{bucket}/{key}?signed=1"

    def head_object(self, bucket: str, key: str) -> dict | None:
        item = self._store.get((bucket, key))
        if item is None:
            return None
        return {"size": len(item[0]), "content_type": item[1]}

    def get_object(self, bucket: str, key: str) -> bytes:
        return self._store[(bucket, key)][0]

    def put_object(self, bucket: str, key: str, data: bytes, content_type: str) -> None:
        self._store[(bucket, key)] = (data, content_type)

    def delete_object(self, bucket: str, key: str) -> None:
        self._store.pop((bucket, key), None)

    def delete_prefix(self, bucket: str, prefix: str) -> int:
        keys = [k for k in self._store if k[0] == bucket and k[1].startswith(prefix)]
        for k in keys:
            del self._store[k]
        return len(keys)


_backend: StorageBackend | None = None


def get_storage() -> StorageBackend:
    global _backend
    if _backend is None:
        _backend = S3Storage()
    return _backend


def set_storage(backend: StorageBackend) -> None:
    """Override the backend (used by tests / DI)."""
    global _backend
    _backend = backend
