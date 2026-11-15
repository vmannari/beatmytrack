"""CCG03: refresh all six cars with complete source and output receipts."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import fnmatch
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from run_car_coarse_models import ROOT, OUT, WORK, run

IDS = ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")
SPEC = json.loads((ROOT / "game/vehicle/prepared_asset_dependencies.json").read_text())


def consumed(relative: str) -> bool:
    # Match PreparedAssetSources.vehicles_for, including its conservative
    # shared defaults. World/UI scripts outside that contract are not inputs.
    if any(fnmatch.fnmatchcase(relative, pattern) for pattern in SPEC["excluded"]):
        return False
    for rule in SPEC["rules"]:
        if fnmatch.fnmatchcase(relative, rule["pattern"]):
            return bool(set(rule["vehicles"]) & set(IDS))
    if relative.startswith("game/resources/cars/") and relative.endswith(".tres"):
        return Path(relative).stem in IDS
    return relative.startswith(("game/vehicle/", "game/assets/vehicles/", "game/assets/liveries/",
                                "game/assets/fonts/", "game/resources/")) or relative in (
        "game/ui/garage_car_cache.gd", "game/ui/header_simple_cache.gd", "godot-version.txt") or (
            relative.startswith("game/track/") and relative.endswith((".gdshader", ".gdshaderinc")))


def sources() -> dict[str, str]:
    selected = []
    for directory in ("game/vehicle", "game/resources", "game/ui", "game/track"):
        selected += [p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in
                     (".gd", ".gdshader", ".gdshaderinc", ".json", ".tres")]
    selected += [p for p in (ROOT / "game/assets/vehicles").rglob("*") if p.is_file()
                 and p.suffix in (".res", ".png") and not any(x in p.parts for x in
                    ("modular_car_bases_v1", "modular_kits_v1"))]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in selected if consumed(p.relative_to(ROOT).as_posix())}


def checked(label: str, script: str, *options: str) -> None:
    status = run(label, script, *options)
    if status:
        raise RuntimeError(f"{label} failed; see its receipt")


def identity(label: str) -> dict:
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               str(ROOT / "scripts/refresh_car_coarse_identity.ps1")]
    with (OUT / f"{label}.log").open("w", encoding="utf-8") as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    data = json.loads((WORK / "identity/client-build-identity.json").read_text(encoding="utf-8-sig"))
    (OUT / f"{label}.json").write_text(json.dumps(data, indent=2)+"\n")
    return data


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--reconcile" in sys.argv:
        original = json.loads((OUT / "refresh-inputs.json").read_text())
        before = {p:h for p,h in original.items() if consumed(p)}
        after = sources()
        changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
        excluded_changes = sorted(p for p,h in original.items() if not consumed(p)
                                  and (not (ROOT/p).exists() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h))
        receipt = {"original_input_count":len(original),"consumed_input_count":len(before),
                   "changed_consumed_inputs":changed,"known_nonconsumed_changes":excluded_changes,
                   "routing":"Matches unchanged PreparedAssetSources manifest and default categories"}
        (OUT / "reconciled-fence.json").write_text(json.dumps(receipt,indent=2)+"\n")
        if changed:
            raise RuntimeError("Consumed car inputs changed; rebake affected assets")
        current = identity("identity-reconciled")
        first = json.loads((OUT / "identity-before.json").read_text())
        if first["modular_car_sha256"]!=current["modular_car_sha256"]:
            raise RuntimeError("Car geometry keys changed; rebake affected assets")
        checked("prepared-final", "res://tests/check_prepared_assets.gd", "--headless")
        print("COARSE_RECONCILIATION: unchanged consumed inputs/keys and strict preflight pass",flush=True)
        return
    if "--pictures" in sys.argv:
        checked("garage-pictures", "res://../scripts/bake_garage_previews.gd", "--rendering-method", "gl_compatibility")
        subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT, check=True)
        return
    before = sources()
    (OUT / "refresh-inputs.json").write_text(json.dumps(before, indent=2)+"\n")
    first = identity("identity-before")
    checked("bases", "res://tests/bake_modular_car_bases.gd", "--headless")
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs = [executor.submit(checked, "kits-"+car, "res://tests/bake_modular_car_kits.gd",
                                "--headless", "--", "--vehicle="+car) for car in IDS]
        for job in jobs:
            job.result()
    checked("garage", "res://tests/bake_garage_cars.gd", "--headless")
    checked("header", "res://tests/bake_header_simple_compact.gd", "--headless")
    after = sources()
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    (OUT / "refresh-fence.json").write_text(json.dumps({"input_count":len(before),"changed":changed}, indent=2)+"\n")
    if changed:
        raise RuntimeError("Consumed sources changed during bakes; inspect receipt and refresh affected outputs")
    final = identity("identity-after")
    if first["modular_car_sha256"] != final["modular_car_sha256"]:
        raise RuntimeError("Geometry identity changed during the output refresh")
    checked("prepared-preflight", "res://tests/check_prepared_assets.gd", "--headless")
    print("COARSE_REFRESH: all six prepared scopes pass", flush=True)


if __name__ == "__main__":
    main()
