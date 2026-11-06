"""Exercise dependency-tree invalidation using only an owned minimal project."""

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixture = root / "build" / ("prepared-receipt-fixture-" + str(time.time_ns()))
fixture.mkdir(parents=True)
assert fixture.resolve().is_relative_to((root / "build").resolve())
(fixture / "project.godot").write_text(
    'config_version=5\n[application]\nconfig/name="Prepared dependency receipt fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
    encoding="utf-8",
)
spec = json.loads(
    (root / "game/vehicle/prepared_asset_dependencies.json").read_text(encoding="utf-8")
)
for folder in [
    "vehicle",
    "track",
    "ui",
    "assets/liveries",
    "assets/fonts",
    "resources/cars",
    "assets/vehicles/modular_car_bases_v1",
]:
    (fixture / folder).mkdir(parents=True, exist_ok=True)
for rule in spec["rules"]:
    if rule["pattern"].startswith("game/assets/vehicles/"):
        (fixture / Path(rule["pattern"].removeprefix("game/")).parent).mkdir(
            parents=True, exist_ok=True
        )
for name in ["prepared_asset_sources.gd", "prepared_asset_dependencies.json"]:
    shutil.copyfile(root / "game/vehicle" / name, fixture / "vehicle" / name)
for path, value in {
    "vehicle/electric_body_kits.gd": "# electric",
    "vehicle/compact_detail.gd": "# tyre helper",
    "vehicle/electric_glass.gdshader": "# glass",
    "assets/vehicles/electric_rear_lamp_gaps_v1/mesh.res": "mesh",
    "assets/liveries/fixture.svg": "livery",
    "assets/fonts/fixture.ttf": "font",
    "assets/fonts/BarlowCondensed-SemiBold.ttf": "known geometry font",
    "ui/garage_car_cache.gd": "# fixture Garage cache",
    "ui/header_simple_cache.gd": "# fixture header cache",
    "resources/cars/kart.tres": "kart",
}.items():
    (fixture / path).write_text(value, encoding="utf-8")
command = [
    sys.executable,
    str(root / "scripts/run_no_crash_dialog.py"),
    "--",
    os.environ.get(
        "GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    ),
    "--headless",
    "--path",
    str(fixture),
    "--script",
    str(root / "game/tests/test_prepared_dependency_receipts.gd"),
]
environment = os.environ.copy()
environment["APPDATA"] = str(fixture / "private-profile")
(fixture / "private-profile").mkdir()
result = subprocess.run(command, cwd=root, env=environment, check=False, timeout=60)
sys.exit(result.returncode)
