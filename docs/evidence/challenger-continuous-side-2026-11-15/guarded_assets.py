"""Refresh independent chassis in parallel, then strictly verify stable provenance."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "build/challenger-continuous-side-2026-11-15/assets"
OUT.mkdir(parents=True, exist_ok=True)
PROFILE = OUT / "private-profile"
(PROFILE / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(PROFILE / "Circuit01Lab/backend.cfg").write_text('[backend]\nurl=""\n', encoding="utf-8")
ENV = {**os.environ, "APPDATA": str(PROFILE), "LOCALAPPDATA": str(PROFILE / "local"), "BMT_API_URL": "", "BMT_DEV_AUTH_KEY": ""}
GODOT = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"


def sources():
    files = [p for folder in ("game/vehicle", "game/resources", "game/ui")
             for p in (ROOT / folder).rglob("*") if p.suffix in (".gd", ".tres", ".json", ".gdshader", ".gdshaderinc")]
    files += [ROOT / "scripts/build_identity.ps1", ROOT / "scripts/garage_preview_identity.ps1", ROOT / "scripts/prepare_challenger.py", ROOT / "scripts/challenger_detail_geometry.py", ROOT / "scripts/challenger_panel_geometry.py", ROOT / "scripts/challenger_reference_geometry.py", ROOT / "scripts/challenger_shell_geometry.py", ROOT / "scripts/challenger_clean_panels.py", ROOT / "scripts/challenger_exterior_geometry.py", ROOT / "game/tests/bake_challenger_hellcat.gd", ROOT / "game/legal/third_party_notices.gd", ROOT / "game/legal/challenger_hellcat_notices.txt"]
    files += [p for p in (ROOT / "game/assets/vehicles/challenger_hellcat_v1").glob("*") if p.suffix in (".res", ".json")]
    files += list((ROOT / "art_sources/challenger_hellcat_v1").glob("*"))
    files += [ROOT / "scripts/bake_garage_previews.gd"]
    files += [ROOT / "scripts/challenger_side_surface.py",ROOT / "scripts/prepared_asset_identity.ps1",ROOT / "godot-version.txt"]
    files += [p for p in (ROOT/"game/track").glob("*") if p.suffix in [".gdshader",".gdshaderinc"]]
    files += [p for p in (ROOT/"game/rendering").rglob("*") if p.is_file() and p.suffix in [".gd",".gdshader",".gdshaderinc"]]
    files += [p for p in (ROOT/"game/resources").rglob("*") if p.is_file() and p.suffix not in [".uid",".import"]]
    files += [ROOT / ("game/tests/"+name) for name in ["bake_modular_car_bases.gd","bake_modular_car_kits.gd","bake_garage_cars.gd","bake_header_simple_compact.gd","bake_super_rally_art.gd"]]
    for directory in ['game/assets/vehicles','game/assets/liveries','game/assets/fonts']:
        files += [p for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']
                  and 'modular_car_bases_v1' not in p.parts and 'modular_kits_v1' not in p.parts
                  and p.relative_to(ROOT).as_posix()!='game/assets/vehicles/racing_simple_v1/manifest.json']
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in set(files)}


def run(label, command):
    started = time.monotonic()
    with (OUT / (label + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=ROOT, env=ENV, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    (OUT / (label + "-command.json")).write_text(json.dumps({"command": command, "exit_code": result.returncode,
        "script_errors": (OUT / (label + ".log")).read_text(encoding="utf-8").count("SCRIPT ERROR:"),
        "elapsed_seconds": time.monotonic()-started}, indent=2), encoding="utf-8")
    print(label, "exit", result.returncode, flush=True)
    if result.returncode or "SCRIPT ERROR:" in (OUT / (label + ".log")).read_text(encoding="utf-8"):
        raise RuntimeError(label)


def engine(label, script, args=(), native=False):
    run(label, [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", GODOT,
        *([] if native else ["--headless"]), "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
        "--rendering-method", "gl_compatibility", "--script", script, *( ["--", *args] if args else [])])


def identity(label):
    run(label, ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
        ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/challenger-continuous-side-2026-11-15/assets'"])


before = sources()
(OUT / "source-before.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
identity("identity-before")
identity_before = json.loads((OUT / "client-build-identity.json").read_text(encoding="utf-8-sig"))
(OUT / "identity-before.json").write_text(json.dumps(identity_before, indent=2), encoding="utf-8")
if "--pictures-only" not in sys.argv:
    engine("bases", "res://tests/bake_modular_car_bases.gd", ["--vehicle=super_rally","--reuse-validated-lods"])
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(engine, "kits-"+car, "res://tests/bake_modular_car_kits.gd", ["--vehicle="+car,"--reuse-validated-lods"])
                for car in ("super_rally",)]
        for job in jobs:
            job.result()
    engine("garage", "res://tests/bake_garage_cars.gd", ["--vehicle=super_rally","--reuse-validated-lods"])
    engine("header", "res://tests/bake_header_simple_compact.gd")
    engine("artwork", "res://tests/bake_super_rally_art.gd", native=True)
engine("pictures", "res://../scripts/bake_garage_previews.gd", ["--exclude-vehicle="+id for id in ("compact","kart","forklift","electric","hovercraft")], native=True)
after = sources()
(OUT / "source-receipt.json").write_text(json.dumps({"before": before, "after": after,
    "changed": [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]}, indent=2), encoding="utf-8")
assert before == after, "Sources changed during final bake"
identity("identity-after")
identity_after = json.loads((OUT / "client-build-identity.json").read_text(encoding="utf-8-sig"))
assert identity_before["modular_car_sha256"] == identity_after["modular_car_sha256"], "Model fingerprints changed during bake"
engine("prepared", "res://tests/check_prepared_assets.gd", ["--exclude-vehicle="+id for id in ("compact","kart","forklift","electric","hovercraft")])
run("picture-preflight", [sys.executable, "scripts/check_garage_previews.py", "--vehicles=super_rally"])
print("SUPER_RALLY_ASSETS: stable sources and both strict preflights pass", flush=True)

