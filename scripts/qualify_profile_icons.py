"""Sequential native profile-icon checks with private copies and user profiles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

import qualify_rivalry_simple_cars as runner
from qualify_rivalry_real_previews import geometry_inputs

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/profile-icon-simplification-2026-11-13"
OUT = ROOT / "docs/evidence/profile-icon-simplification-2026-11-13"
PROJECT = ROOT / "build/rivalry-real-previews-2026-11-13/project/game"
BASELINE = False
OWNED = ["ui/rivalry_simple_car.gd", "ui/header_icon_renderer.gd",
         "ui/header_car_appearance_cache.gd", "ui/header_car_icons.gd",
         "tests/profile_header_icon_loading.gd", "tests/test_header_icon_capture.gd",
         "tests/test_header_icon_lod_policy.gd",
         "tests/test_profile_car_startup.gd", "tests/test_header_equipped_cache.gd",
         "tests/test_header_staged_preparation.gd", "tests/test_shared_graphics_header.gd"]


def prepare(full=False):
    assert full and PROJECT.is_dir()
    for rel in OWNED:
        p = ROOT / "game" / rel
        if not p.exists(): continue
        target = PROJECT / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        source = WORK / "before/game" / rel if BASELINE and (WORK / "before/game" / rel).exists() else p
        shutil.copy2(source, target)
    return PROJECT


def refresh():
    before = geometry_inputs()
    # Prepared bases/kits are runtime inputs even though they are excluded
    # from geometry build keys. Include them in this timing fixture so stale
    # private caches cannot accidentally benchmark procedural fallback.
    runtime = {p.relative_to(ROOT / "game").as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
               for folder in [ROOT / "game/assets", ROOT / "game/.godot/imported"]
               for p in folder.rglob("*") if p.is_file()}
    copied = []
    inputs = {**{rel.removeprefix("game/"):digest for rel,digest in before.items()},**runtime}
    for rel, digest in inputs.items():
        target = PROJECT / rel
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "game" / rel, target)
            copied.append(rel)
    for p in (ROOT / "game").rglob("*"):
        if not p.is_file() or p.relative_to(ROOT / "game").parts[0] in ("assets", ".godot", "android", "tmp", "build"): continue
        target = PROJECT / p.relative_to(ROOT / "game")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p,target)
    after = geometry_inputs()
    assert before == after, "Concurrent geometry changed; retry the private snapshot"
    assert all(hashlib.sha256((PROJECT.parent/rel).read_bytes()).hexdigest()==digest for rel,digest in after.items())
    assert all(hashlib.sha256((ROOT / "game" / rel).read_bytes()).hexdigest()==digest and hashlib.sha256((PROJECT/rel).read_bytes()).hexdigest()==digest for rel,digest in runtime.items()), "Runtime assets changed while copying; retry"
    for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
        shutil.copy2(ROOT / "game/.godot" / name, PROJECT / ".godot" / name)
    (WORK / "snapshot.json").write_text(json.dumps({"geometry_inputs":after,"runtime_inputs":runtime,"copied":copied},indent=2))
    print(json.dumps({"source_inputs":len(after),"runtime_inputs":len(runtime),"refreshed":len(copied)}))


def refresh_prepared():
    before = geometry_inputs()
    folders = ["assets/vehicles/modular_car_bases_v1", "assets/vehicles/modular_kits_v1", "assets/menu/header_car_templates_v1"]
    runtime = {p.relative_to(ROOT / "game").as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
               for folder in folders for p in (ROOT / "game" / folder).rglob("*") if p.is_file()}
    runtime["core/build_identity.gd"] = hashlib.sha256((ROOT / "game/core/build_identity.gd").read_bytes()).hexdigest()
    inputs = {**{rel.removeprefix("game/"):digest for rel,digest in before.items()},**runtime}
    copied = []
    for rel,digest in inputs.items():
        target = PROJECT / rel
        if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(ROOT / "game" / rel,target)
            copied.append(rel)
    after = geometry_inputs()
    assert before==after, "Model sources changed; retry"
    assert all(hashlib.sha256((ROOT / "game" / rel).read_bytes()).hexdigest()==digest and hashlib.sha256((PROJECT/rel).read_bytes()).hexdigest()==digest for rel,digest in inputs.items()), "Prepared inputs changed; retry"
    data={"geometry_inputs":after,"prepared_runtime_inputs":runtime,"copied":copied,"scope":"Current model sources, prepared bases/kits/header and matching build keys; unrelated App/assets remain pinned"}
    (WORK / "prepared-snapshot.json").write_text(json.dumps(data,indent=2))
    print(json.dumps({"model_sources":len(after),"prepared_inputs":len(runtime),"refreshed":len(copied)}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--refresh-prepared", action="store_true")
    parser.add_argument("--before", action="store_true")
    parser.add_argument("--startup-phase", default="")
    parser.add_argument("--startup-profile", default="")
    parser.add_argument("--startup-car", default="compact")
    args, forwarded = parser.parse_known_args()
    global BASELINE
    BASELINE = args.before
    if args.startup_phase:
        os.environ["BMT_HEADER_STARTUP_PHASE"] = args.startup_phase
        os.environ["BMT_HEADER_STARTUP_PROFILE"] = args.startup_profile
        os.environ["BMT_HEADER_STARTUP_CAR"] = args.startup_car
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    if args.refresh:
        refresh()
        return 0
    if args.refresh_prepared:
        refresh_prepared()
        return 0
    runner.WORK, runner.OUT, runner.prepare = WORK, OUT, prepare
    sys.argv = [sys.argv[0],args.name,"--full",*forwarded]
    status = runner.main()
    path = OUT / (args.name+"-receipt.json")
    receipt = json.loads(path.read_text())
    receipt["before_header_renderer"] = BASELINE
    receipt["source_scope"] = "Real private source/assets/import copies; no live links; only owned UI/tests refreshed"
    path.write_text(json.dumps(receipt,indent=2)+"\n")
    return status


if __name__ == "__main__":
    sys.exit(main())
