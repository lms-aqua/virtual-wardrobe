"""Server-side upload validation.

Client-supplied MIME types and filenames are NEVER trusted. On scan completion
we fetch the stored object and sniff magic bytes to confirm it is really an
allowed image type, and re-check the size cap.
"""

from __future__ import annotations

MAGIC = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
}


def sniff_image_mime(data: bytes) -> str | None:
    for magic, mime in MAGIC.items():
        if data.startswith(magic):
            return mime
    # HEIC/HEIF: ISO-BMFF box "ftyp" with a heic/heif brand.
    if len(data) >= 12 and data[4:8] == b"ftyp":
        brand = data[8:12]
        if brand in (b"heic", b"heix", b"hevc", b"mif1", b"heif", b"msf1"):
            return "image/heic"
    return None


def validate_image(data: bytes, *, allowed: set[str], max_bytes: int) -> tuple[bool, str | None]:
    if len(data) == 0:
        return False, "empty_file"
    if len(data) > max_bytes:
        return False, "too_large"
    sniffed = sniff_image_mime(data)
    if sniffed is None:
        return False, "unknown_type"
    if sniffed not in allowed:
        return False, "disallowed_type"
    return True, sniffed
