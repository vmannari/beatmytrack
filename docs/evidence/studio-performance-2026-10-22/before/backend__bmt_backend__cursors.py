"""Opaque bounded cursors, validated as data rather than SQL fragments."""
import base64
import json

from fastapi import HTTPException


def encode_cursor(value: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(value, separators=(",", ":")).encode()).decode().rstrip("=")


def decode_cursor(value: str) -> dict:
    try:
        if len(value) > 400:
            raise ValueError
        result = json.loads(base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True))
        if not isinstance(result, dict):
            raise TypeError
        return result
    except (TypeError, ValueError, UnicodeError):
        raise HTTPException(422, "INVALID_CURSOR") from None
