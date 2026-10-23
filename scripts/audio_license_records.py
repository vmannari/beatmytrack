"""Build-time metadata for the four cleared owner-supplied ambience sources."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "game/assets/audio/ambience/source_licenses.json"


def source_license(source_id, original_sha256):
    """Bind the published licence to its reviewed original, never another file."""
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    source = next(item for item in registry["sources"] if item["id"] == source_id)
    if original_sha256 != source["source_sha256"]:
        raise ValueError("Audio source differs from its reviewed licence record")
    return {
        "author": source["author"],
        "license": source["license"],
        "license_url": registry["license_url"],
        "source_url": source["source_url"],
        "license_source_id": source_id,
        "license_verified_on": registry["verified_on"],
        "license_evidence": registry["evidence"],
    }
