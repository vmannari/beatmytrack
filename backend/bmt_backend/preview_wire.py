"""Omit only exact preview identities explicitly retained by the caller."""
import hashlib

from .storage import canonical_json


def compact_previews(result, known):
    known = set(known)
    for item in result.get("items", []):
        if "points" not in item:
            continue
        digest = hashlib.sha256(canonical_json(item["points"])).hexdigest()
        item["preview_hash"] = digest
        if digest in known:
            del item["points"]
    return result
