"""Regenerate the complete validated car-asset pipeline with pinned offline Godot."""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--output", type=Path, default=ROOT / "build/prepared-car-assets")
p.add_argument(
    "--verify",
    action="store_true",
    help="Validate existing bakes without changing sources or assets.",
)
p.add_argument(
    "--godot",
    default=os.environ.get(
        "GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    ),
)
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
profile = args.output / "private-profile"
(profile / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(profile / "Circuit01Lab/backend.cfg").write_text(
    '[backend]\nurl=""\n', encoding="utf-8"
)
env = os.environ.copy()
env.update(APPDATA=str(profile.resolve()), BMT_API_URL="")
godot = args.godot
version = subprocess.check_output([godot, "--version"], text=True).strip()
assert version == (ROOT / "godot-version.txt").read_text().strip(), version
receipts = []


def run(label, command, timeout=600, required=True):
    started = time.monotonic()
    with (args.output / (label + ".log")).open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT
        )
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                capture_output=True,
                check=False,
            )
            process.wait(timeout=20)
            code = 124
    receipts.append(
        {
            "label": label,
            "command": command,
            "exit_code": code,
            "elapsed_seconds": time.monotonic() - started,
            "owned_pid": process.pid,
        }
    )
    (args.output / "commands.json").write_text(
        json.dumps(receipts, indent=2), encoding="utf-8"
    )
    print(f"{label}: exit {code}", flush=True)
    if code and required:
        raise SystemExit(code)
    return code


def engine(label, script, headless=True, required=True):
    return run(
        label,
        [
            sys.executable,
            str(ROOT / "scripts/run_no_crash_dialog.py"),
            "--",
            godot,
            *(["--headless"] if headless else []),
            "--path",
            str(ROOT / "game"),
            "--audio-driver",
            "Dummy",
            "--rendering-method",
            "gl_compatibility",
            "--script",
            script,
        ],
        required=required,
    )


def identity(label):
    command = (
        ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path '"
        + args.output.resolve().as_posix().replace("'", "''")
        + "'"
    )
    run(
        label,
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
    )


def source_hashes():
    paths = [
        path
        for folder in ("game/vehicle", "game/resources/cars")
        for path in (ROOT / folder).rglob("*")
        if path.is_file()
        and path.suffix in (".gd", ".gdshader", ".gdshaderinc", ".json", ".tres")
    ]
    paths += [
        ROOT / path
        for path in (
            "game/ui/garage_car_cache.gd",
            "game/ui/header_simple_cache.gd",
            "scripts/build_identity.ps1",
            "scripts/garage_preview_identity.ps1",
            "scripts/prepared_asset_identity.ps1",
        )
    ]
    return {
        path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in paths
    }


run(
    "dependency-audit",
    [sys.executable, str(ROOT / "scripts/check_prepared_asset_dependencies.py")],
)
if not args.verify:
    identity("identity-before")
    before = source_hashes()
    initial = json.loads((args.output / "client-build-identity.json").read_text())[
        "modular_car_sha256"
    ]
    if engine(
        "prepared-before", "res://tests/check_prepared_assets.gd", required=False
    ):
        engine("bake-bases", "res://tests/bake_modular_car_bases.gd")
        engine("bake-kits", "res://tests/bake_modular_car_kits.gd")
        engine("bake-garage", "res://tests/bake_garage_cars.gd")
        engine("bake-header", "res://tests/bake_header_simple_compact.gd")
    if run(
        "pictures-before",
        [sys.executable, str(ROOT / "scripts/check_garage_previews.py")],
        required=False,
    ):
        engine(
            "bake-pictures", "res://../scripts/bake_garage_previews.gd", headless=False
        )
    after = source_hashes()
    (args.output / "source-receipt.json").write_text(
        json.dumps(
            {
                "before": before,
                "after": after,
                "changed": [
                    path
                    for path in before.keys() | after.keys()
                    if before.get(path) != after.get(path)
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    assert before == after, (
        "Source changed while baking; rerun the pipeline before accepting these assets."
    )
    identity("identity-after")
    final = json.loads((args.output / "client-build-identity.json").read_text())[
        "modular_car_sha256"
    ]
    assert initial == final, (
        "Generated outputs changed geometry identities; dependency cycle detected."
    )
engine("prepared-preflight", "res://tests/check_prepared_assets.gd")
run(
    "pictures-preflight",
    [sys.executable, str(ROOT / "scripts/check_garage_previews.py")],
)
print("PREPARED_CAR_PIPELINE: verified all current car configurations.", flush=True)
