"""Cryptographic helpers: magic-link tokens and session tokens.

All tokens are signed with SECRET_KEY via itsdangerous (HMAC). Session tokens
are opaque signed references to a Session row — no user data is embedded, so
revoking a session in the DB immediately invalidates the token.
"""

from __future__ import annotations

import hashlib

from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from wardrobe_core.config import get_settings

_MAGIC_SALT = "vw-magic-link"
_SESSION_SALT = "vw-session"


def _serializer(salt: str) -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(get_settings().secret_key, salt=salt)


def make_magic_token(email: str, *, is_adult: bool) -> str:
    return _serializer(_MAGIC_SALT).dumps({"email": email.lower().strip(), "is_adult": is_adult})


def read_magic_token(token: str) -> dict | None:
    """Return the payload if valid and within TTL, else None."""
    ttl = get_settings().magic_link_ttl_seconds
    try:
        return _serializer(_MAGIC_SALT).loads(token, max_age=ttl)
    except (BadSignature, SignatureExpired):
        return None


def make_session_token(session_id: str) -> str:
    return _serializer(_SESSION_SALT).dumps(session_id)


def read_session_token(token: str) -> str | None:
    ttl = get_settings().session_ttl_seconds
    try:
        return _serializer(_SESSION_SALT).loads(token, max_age=ttl)
    except (BadSignature, SignatureExpired):
        return None


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()
