"""CCG03: refresh all six cars with complete source and output receipts."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from run_car_coarse_models import ROOT, OUT, WORK, run

IDS = ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")


def sources() -> dict[str, str]:
    selected = []
    for directory in ("game/vehicle", "game/resources", "game/ui", "game/track"):
        selected += [p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in
                     (".gd", ".gdshader", ".gdshaderinc", ".json", ".tres")]
    selected += [p for p in (ROOT / "game/assets/vehicles").rglob("*") if p.is_file()
                 and p.suffix in (".res", ".png") and not any(x in p.parts for x in
                    ("modular_car_bases_v1", "modular_kits_v1"))]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in selected}


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
