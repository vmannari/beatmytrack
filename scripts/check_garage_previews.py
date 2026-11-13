"""Reject stale/missing packaged native Garage previews before export."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check(vehicles=None):
    folder = ROOT / "game/assets/garage/previews_v1"
    provenance = json.loads((folder / "provenance.json").read_text(encoding="utf-8"))
    if provenance.get("simple") is not True:
        raise ValueError("Garage catalogue photographs must use the production reduced models")
    catalog = (ROOT / "game/vehicle/vehicle_catalog.gd").read_text(encoding="utf-8")
    match = re.search(r"const IDS: Array\[String\] = \[([^\]]+)\]", catalog)
    if not match:
        raise ValueError("Cannot read active vehicle IDs from VehicleCatalog")
    expected = set(re.findall(r'"([^"]+)"', match.group(1)))
    aliases = re.search(r"const MODEL_ALIASES: Dictionary = (\{[^\n]+\})", catalog)
    model_aliases = json.loads(aliases.group(1)) if aliases else {}
    if set(provenance["hashes"]) != expected:
        raise ValueError(
            "Native default previews must match the active vehicle catalog"
        )
    if vehicles is not None:
        requested = set(vehicles)
        if not requested or not requested <= expected:
            raise ValueError("Requested preview scope must contain active vehicle IDs")
        expected = requested
    identity = (ROOT / "game/core/build_identity.gd").read_text(encoding="utf-8")
    geometry = re.search(r"MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})", identity)
    if not geometry:
        raise ValueError(
            "Prepared geometry revisions are missing from the build identity"
        )
    revisions = json.loads(geometry.group(1))
    actual_revisions = provenance.get("geometry_revisions")
    if vehicles is not None:
        actual_revisions = {vehicle: (actual_revisions or {}).get(vehicle) for vehicle in expected}
    if actual_revisions != {
        vehicle: revisions[vehicle] for vehicle in expected
    }:
        raise ValueError(
            "Stale Garage preview geometry; rerun scripts/bake_garage_previews.gd"
        )
    scenes = {
        vehicle: hashlib.sha256(
            (ROOT / "game/assets/vehicles/modular_car_bases_v1" / f"{model_aliases.get(vehicle, vehicle)}_simple_editable.scn").read_bytes()
        ).hexdigest()
        for vehicle in expected
    }
    actual_scenes = provenance.get("prepared_scenes")
    if vehicles is not None:
        actual_scenes = {vehicle: (actual_scenes or {}).get(vehicle) for vehicle in expected}
    if actual_scenes != scenes:
        raise ValueError(
            "Garage photographs do not match prepared scenes; rerun scripts/bake_garage_previews.gd"
        )
    if not provenance["sources"]:
        raise ValueError("Native preview source manifest is required")
    for file, digest in provenance["sources"].items():
        if hashlib.sha256((ROOT / file).read_bytes()).hexdigest() != digest:
            raise ValueError(
                f"Stale Garage preview: {file}; rerun scripts/bake_garage_previews.gd"
            )
    for vehicle, digest in provenance["hashes"].items():
        if vehicle not in expected:
            continue
        if (
            hashlib.sha256((folder / f"{vehicle}.png").read_bytes()).hexdigest()
            != digest
        ):
            raise ValueError(f"Changed Garage preview: {vehicle}")
    print(
        f"GARAGE_PREVIEWS: {len(expected)} exact native images, {len(provenance['sources'])} current source hashes"
    )


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--vehicles", help="Explicit comma-separated review scope; default validates every car")
    args = parser.parse_args()
    check(args.vehicles.split(",") if args.vehicles else None)
