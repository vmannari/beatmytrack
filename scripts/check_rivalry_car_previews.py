"""Reject missing, altered or stale photographs of the actual Rivalry cars."""
import hashlib
import json
from pathlib import Path
import re

from qualify_rivalry_real_previews import geometry_inputs, source_fingerprint

ROOT = Path(__file__).resolve().parents[1]


def check():
    folder = ROOT / "game/assets/menu/rivalry_cars_v2"
    provenance = json.loads((folder / "provenance.json").read_text(encoding="utf-8"))
    catalog = (ROOT / "game/vehicle/vehicle_catalog.gd").read_text(encoding="utf-8")
    match = re.search(r'const IDS: Array\[String\] = \[([^\]]+)\]',catalog)
    assert match, "Cannot read active vehicle IDs"
    vehicles = set(re.findall(r'"([^"]+)"',match[1]))
    assert provenance["schema"] == "rivalry-actual-car-photos-2", "Wrong Rivalry photograph schema"
    assert provenance["size"] == [512,320] and provenance["neutral"] == "808080", "Wrong image/paint contract"
    assert set(provenance["cars"]) == vehicles, "Every active car needs its actual photograph"
    expected = {vehicle+"_"+role+".res" for vehicle in vehicles for role in ("image","mask")}
    assert set(provenance["textures"]) == expected, "Rivalry image/mask pairs are incomplete"
    pinned = (ROOT / "godot-version.txt").read_text().strip().split(".")
    display_version = ".".join(pinned[:3])+"-"+pinned[3]+" ("+pinned[4]+")"
    assert provenance["engine"]==display_version, "Rebake Rivalry pictures with the pinned engine"
    baker = ROOT / "game/tests/bake_rivalry_car_previews.gd"
    assert hashlib.sha256(baker.read_bytes()).hexdigest() == provenance["baker_sha256"], "Rivalry photograph baker changed; rebake"
    inputs = geometry_inputs()
    current = source_fingerprint(inputs)
    if current != provenance["sources"]:
        changed = sorted(rel for rel in current.keys() | provenance["sources"].keys() if current.get(rel) != provenance["sources"].get(rel))
        raise ValueError("Actual-car Rivalry pictures are stale; refresh/bake/publish with scripts/qualify_rivalry_real_previews.py: "+", ".join(changed[:8]))
    for name, expected_hash in provenance["textures"].items():
        assert hashlib.sha256((folder/name).read_bytes()).hexdigest() == expected_hash, "Altered Rivalry picture: "+name
    print(f"RIVALRY_CAR_PREVIEWS: {len(vehicles)} actual vehicles, {len(expected)} exact textures, {len(inputs)} current inputs / {len(current)} fingerprints")


if __name__ == "__main__":
    check()
