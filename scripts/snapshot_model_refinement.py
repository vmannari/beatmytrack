"""Capture task-start source and protected Challenger controls without Git writes."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-model-refinement-2026-11-12"
OUT.mkdir(parents=True, exist_ok=True)
assert not (OUT / "task-start-hashes.json").exists(), "Never overwrite task-start evidence"
files = set()
for directory in ["game/vehicle", "game/resources/cars", "game/assets/vehicles/challenger_hellcat_v1"]:
    files.update(p for p in (ROOT / directory).rglob("*") if p.is_file())
for directory in ["game/assets/vehicles/modular_car_bases_v1", "game/assets/vehicles/modular_kits_v1",
                  "game/assets/garage", "game/assets/menu", "game/assets/liveries/previews_v2"]:
    files.update(p for p in (ROOT / directory).rglob("*") if p.is_file() and "super_rally" in p.as_posix())
files.update(ROOT / p for p in [".git/index", "game/core/build_identity.gd", "game/project.godot",
                                "game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res",
                                "game/assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res"])
hashes = {}
for path in sorted(files):
    if not path.is_file():
        continue
    relative = path.relative_to(ROOT).as_posix()
    hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    if path.suffix in [".gd", ".gdshader", ".gdshaderinc", ".json", ".tres"] or relative.endswith(("driver.res", "hovercraft_shadow_0.res")):
        target = OUT / "before" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
(OUT / "task-start-hashes.json").write_text(json.dumps(hashes, indent=2))
print(f"Task-start hashes: {len(hashes)} controls")
