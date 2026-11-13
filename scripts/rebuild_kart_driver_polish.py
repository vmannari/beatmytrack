"""Ordered native refresh with exact source/revision fences and private profiles."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/kart-driver-polish-2026-11-12"
WORK = ROOT / "build/kart-driver-polish-2026-11-12"
RUNNER = ROOT / "scripts/run_kart_driver_polish.py"


def run(name, script, *args):
    subprocess.run([sys.executable, str(RUNNER), name, script, *args], cwd=ROOT,
                   check=True, stdout=subprocess.DEVNULL)
    print(name, "passed", flush=True)


def identity(name):
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
               "$ErrorActionPreference='Stop'; . ./scripts/build_identity.ps1; "
               "Write-ClientBuildIdentity (Get-Location).Path 'build/kart-driver-polish-2026-11-12/identity'"]
    with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
        subprocess.run(command, cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    data = json.loads((WORK / "identity/client-build-identity.json").read_text(encoding="utf-8-sig"))
    (OUT / f"{name}.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


def sources():
    files = []
    for folder in ("game/vehicle", "game/resources", "game/ui", "game/track"):
        files.extend(p for p in (ROOT / folder).rglob("*")
                     if p.suffix in (".gd", ".tres", ".json", ".gdshader", ".gdshaderinc"))
    files.extend(p for p in (ROOT / "game/assets/vehicles").rglob("*")
                 if p.is_file() and p.suffix in (".res", ".json", ".png")
                 and "modular_car_bases_v1" not in p.parts and "modular_kits_v1" not in p.parts
                 and p.name != "manifest.json")
    files.extend(p for p in (ROOT / "game/assets/liveries").rglob("*") if p.suffix in (".png", ".svg", ".json"))
    files.extend(ROOT / f for f in ("scripts/build_identity.ps1", "scripts/garage_preview_identity.ps1",
                                    "scripts/prepared_asset_identity.ps1", "godot-version.txt"))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    identity("identity-for-art")
    for name, script in (("art-bases", "bake_modular_car_bases"), ("art-kits", "bake_modular_car_kits"),
                         ("art-garage", "bake_garage_cars")):
        run(name, "res://tests/" + script + ".gd", "--headless", "--", "--vehicle=kart")
    run("catalogue-art", "res://tests/test_kart_refinement_ui.gd", "--rendering-method", "gl_compatibility",
        "--", "--bake-art", "--evidence-root=res://../docs/evidence/kart-driver-polish-2026-11-12/catalogue")
    run("news-art", "res://tests/bake_news_car_photos.gd", "--rendering-method", "gl_compatibility", "--",
        "--vehicle=kart", "--evidence-root=res://../docs/evidence/kart-driver-polish-2026-11-12/news")
    run("livery-art", "res://tests/bake_livery_previews.gd", "--rendering-method", "gl_compatibility", "--", "--vehicle=kart")
    run("header-art", "res://tests/bake_kart_finishing_art.gd", "--rendering-method", "gl_compatibility", "--", "--header-only")
    before = sources()
    first = identity("identity-final-before")
    (OUT / "refresh-inputs.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    run("final-all-bases", "res://tests/bake_modular_car_bases.gd", "--headless")
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run, "final-kits-" + car, "res://tests/bake_modular_car_kits.gd",
                            "--headless", "--", "--vehicle=" + car)
                for car in ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")]
        for job in jobs:
            job.result()
    run("final-all-garage", "res://tests/bake_garage_cars.gd", "--headless")
    run("final-header-template", "res://tests/bake_header_simple_compact.gd", "--headless")
    run("final-garage-pictures", "res://../scripts/bake_garage_previews.gd", "--rendering-method", "gl_compatibility")
    after = sources()
    changed = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    (OUT / "refresh-source-receipt.json").write_text(json.dumps({"input_count": len(before), "changed": changed}, indent=2))
    assert not changed, "Sources changed during final native refresh"
    final = identity("identity-final-after")
    assert first["modular_car_sha256"] == final["modular_car_sha256"], "Prepared geometry fingerprints changed"
    run("final-import", "@import")
    run("prepared-preflight", "res://tests/check_prepared_assets.gd", "--headless")
    with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
        subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    print("KART_DRIVER_REFRESH: stable sources and both strict preflights passed", flush=True)


if __name__ == "__main__":
    main()
