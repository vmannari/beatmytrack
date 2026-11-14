"""Refresh five requested cars with source fences; leave Challenger out."""
from concurrent.futures import ThreadPoolExecutor
import fnmatch
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-loading-improvements-2026-11-13"
IDS = ["compact", "kart", "forklift", "electric", "hovercraft"]
SPEC = json.loads((ROOT / "game/vehicle/prepared_asset_dependencies.json").read_text())


def consumed(relative):
    # Match the authoritative model manifest and Garage preview identity:
    # numerical world/cache scripts are not geometry or photograph inputs.
    if relative.startswith("game/track/") and not relative.endswith((".gdshader", ".gdshaderinc")):
        return False
    for rule in SPEC["rules"]:
        if fnmatch.fnmatchcase(relative, rule["pattern"]):
            return bool(set(rule["vehicles"]) & set(IDS))
    return True  # Unknown and shared inputs remain guarded.


def protected_sources():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "game/assets/vehicles/challenger_hellcat_v1").rglob("*") if p.is_file()}


def run(label, script, *options):
    subprocess.run([sys.executable, str(ROOT / "scripts/run_car_loading_improvements.py"), label, "--script="+script, *options],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    print(label, "passed", flush=True)


def sources():
    paths = []
    for directory in ["game/vehicle", "game/resources", "game/ui", "game/track"]:
        paths += [p for p in (ROOT / directory).rglob("*") if p.suffix in [".gd", ".gdshader", ".gdshaderinc", ".json", ".tres"]]
    paths += [p for p in (ROOT / "game/assets/vehicles").rglob("*") if p.suffix in [".res", ".png"]
              and "modular_kits_v1" not in p.parts and "modular_car_bases_v1" not in p.parts]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths
            if consumed(p.relative_to(ROOT).as_posix())}


def identity(label):
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               str(ROOT / "scripts/refresh_car_loading_improvements_identity.ps1")]
    with (OUT / (label + ".log")).open("w", encoding="utf-8") as log:
        subprocess.run(command, cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    data = json.loads((ROOT / "build/car-loading-improvements-2026-11-13/identity/client-build-identity.json").read_text(encoding="utf-8-sig"))
    (OUT / (label + ".json")).write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(label, "passed", flush=True)
    return data


def main():
    selected = IDS
    for option in sys.argv[1:]:
        if option.startswith("--vehicles="):
            selected = option.split("=", 1)[1].split(",")
            assert selected and set(selected) <= set(IDS)
    artwork = "--art-only" in sys.argv
    if artwork:
        for car in selected:
            run("liveries-"+car,"res://tests/bake_livery_previews.gd","--rendering-method","gl_compatibility","--","--vehicle="+car)
            run("news-"+car,"res://tests/bake_news_car_photos.gd","--rendering-method","gl_compatibility","--","--vehicle="+car,
                "--evidence-root=res://../docs/evidence/car-loading-improvements-2026-11-13/news")
        return
    protected_before = protected_sources()
    before = sources()
    (OUT / "refresh-source-before.json").write_text(json.dumps(before, indent=2))
    first = identity("identity-before-bakes")
    for car in selected:
        run("bases-"+car,"res://tests/bake_modular_car_bases.gd","--headless","--","--vehicle="+car,"--reuse-validated-lods")
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run,"kits-"+car,"res://tests/bake_modular_car_kits.gd","--headless","--","--vehicle="+car,"--reuse-validated-lods") for car in selected]
        for job in jobs: job.result()
    for car in selected:
        run("garage-"+car,"res://tests/bake_garage_cars.gd","--headless","--","--vehicle="+car,"--reuse-validated-lods")
    if "compact" in selected:
        run("header-template","res://tests/bake_header_simple_compact.gd","--headless")
    run("garage-pictures","res://../scripts/bake_garage_previews.gd","--rendering-method","gl_compatibility","--","--exclude-vehicle=super_rally")
    after = sources()
    changed = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    protected_after = protected_sources()
    protected_changed = sorted(p for p in protected_before.keys() | protected_after.keys()
                               if protected_before.get(p) != protected_after.get(p))
    (OUT / "refresh-source-receipt.json").write_text(json.dumps({"scope":IDS,"input_count":len(before),"changed":changed,
                "concurrent_excluded_inputs":protected_changed}, indent=2))
    assert not changed, "Authored inputs changed during the prepared refresh"
    final = identity("identity-after-bakes")
    assert all(first["modular_car_sha256"][car] == final["modular_car_sha256"][car] for car in IDS), "Generated output changed scoped geometry revisions"
    run("prepared-preflight","res://tests/check_prepared_assets.gd","--headless","--","--exclude-vehicle=super_rally")
    with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
        subprocess.run([sys.executable,"scripts/check_garage_previews.py","--vehicles="+",".join(IDS)],cwd=ROOT,check=True,stdout=log,stderr=subprocess.STDOUT)
    print("FIVE_CAR_REFRESH: source fence and strict asset/picture preflights passed",flush=True)


if __name__ == "__main__":
    main()
