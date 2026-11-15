"""Validate the native selection portraits before Android export."""
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]

def check():
    directory = ROOT / "game/assets/garage/selection_portraits_v1"
    data = json.loads((directory / "provenance.json").read_text(encoding="utf-8"))
    identity = (ROOT / "game/core/build_identity.gd").read_text(encoding="utf-8")
    revision = re.search(r'const HEADER_PREVIEW_SHA256: String = "([a-f0-9]{64})"', identity)
    assert revision and data["revision"] == revision[1], "Selection portraits need a current-source rebake"
    garage_revision = re.search(r'const GARAGE_PREVIEW_SHA256: String = "([a-f0-9]{64})"', identity)
    assert garage_revision and data["garage_revision"] == garage_revision[1], "Selection lighting needs a current-source rebake"
    assert data["version"] == "garage-selection-portrait-1"
    for key, source in (("recipe", "game/tests/support/garage_car_portrait.gd"), ("producer", "game/tests/bake_garage_selection_portraits.gd")):
        assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == data[key], f"Selection portrait {key} changed; rebake required"
    catalog = (ROOT / "game/vehicle/vehicle_catalog.gd").read_text(encoding="utf-8")
    ids = set(re.findall(r'"([^"]+)"', re.search(r'const IDS: Array\[String\] = \[([^\]]+)\]', catalog)[1]))
    assert set(data["pictures"]) == ids, "Selection portraits must cover every available car"
    for vehicle, digest in data["pictures"].items():
        pixels = (directory / f"{vehicle}.png").read_bytes()
        assert pixels[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", pixels[16:24]) == (512, 288), vehicle
        assert hashlib.sha256(pixels).hexdigest() == digest, f"Damaged selection portrait: {vehicle}"
    presets = (ROOT / "game/export_presets.cfg").read_text(encoding="utf-8")
    for filters in re.findall(r'^include_filter="(.*)"', presets, re.M):
        assert "assets/garage/selection_portraits_v1/*.png" in filters
        assert "assets/garage/selection_portraits_v1/provenance.json" in filters
    return {"pictures": len(ids), "revision": revision[1], "stable_bake_inputs": data["source_count"]}

if __name__ == "__main__":
    print("GARAGE_SELECTION_PICTURES " + json.dumps(check()))
