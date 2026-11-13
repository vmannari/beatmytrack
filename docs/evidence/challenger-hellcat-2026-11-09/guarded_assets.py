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
OUT = ROOT / "build/challenger-hellcat-guarded-assets"
OUT.mkdir(parents=True, exist_ok=True)
PROFILE = OUT / "private-profile"
(PROFILE / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(PROFILE / "Circuit01Lab/backend.cfg").write_text('[backend]\nurl=""\n', encoding="utf-8")
ENV = {**os.environ, "APPDATA": str(PROFILE), "BMT_API_URL": ""}
GODOT = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"


def sources():
    files = [p for folder in ("game/vehicle", "game/resources", "game/ui")
             for p in (ROOT / folder).rglob("*") if p.suffix in (".gd", ".tres", ".json", ".gdshader", ".gdshaderinc")]
    files += [ROOT / "scripts/build_identity.ps1", ROOT / "scripts/garage_preview_identity.ps1", ROOT / "scripts/prepare_challenger.py", ROOT / "game/tests/bake_challenger_hellcat.gd", ROOT / "game/legal/third_party_notices.gd", ROOT / "game/legal/challenger_hellcat_notices.txt"]
    files += [p for p in (ROOT / "game/assets/vehicles/challenger_hellcat_v1").glob("*") if p.suffix in (".res", ".json")]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


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
        ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/challenger-hellcat-guarded-assets'"])


before = sources()
(OUT / "source-before.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
identity("identity-before")
identity_before = json.loads((OUT / "client-build-identity.json").read_text(encoding="utf-8-sig"))
(OUT / "identity-before.json").write_text(json.dumps(identity_before, indent=2), encoding="utf-8")
engine("bases", "res://tests/bake_modular_car_bases.gd")
with ThreadPoolExecutor(max_workers=3) as pool:
    jobs = [pool.submit(engine, "kits-"+car, "res://tests/bake_modular_car_kits.gd", ["--vehicle="+car])
            for car in ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")]
    for job in jobs:
        job.result()
engine("garage", "res://tests/bake_garage_cars.gd")
engine("header", "res://tests/bake_header_simple_compact.gd")
engine("artwork", "res://tests/bake_super_rally_art.gd", native=True)
engine("pictures", "res://../scripts/bake_garage_previews.gd", native=True)
after = sources()
(OUT / "source-receipt.json").write_text(json.dumps({"before": before, "after": after,
    "changed": [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]}, indent=2), encoding="utf-8")
assert before == after, "Sources changed during final bake"
identity("identity-after")
identity_after = json.loads((OUT / "client-build-identity.json").read_text(encoding="utf-8-sig"))
assert identity_before["modular_car_sha256"] == identity_after["modular_car_sha256"], "Model fingerprints changed during bake"
engine("prepared", "res://tests/check_prepared_assets.gd")
run("picture-preflight", [sys.executable, "scripts/check_garage_previews.py"])
print("SUPER_RALLY_ASSETS: stable sources and both strict preflights pass", flush=True)
