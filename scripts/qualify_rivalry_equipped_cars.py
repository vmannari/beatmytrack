"""Offline native equipped-car checks using a disposable private source copy."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

import qualify_rivalry_simple_cars as runner
from qualify_rivalry_real_previews import geometry_inputs

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/rivalry-equipped-cars-2026-11-13"
OUT = ROOT / "docs/evidence/rivalry-equipped-cars-2026-11-13"
PROJECT = ROOT / "build/rivalry-real-previews-2026-11-13/project/game"
OWNED = ["ui/rivalry_simple_car.gd", "ui/rivalry_preview_finish.gdshader",
         "tests/test_rivalry_simple_car.gd", "tests/test_rivalry_car_photos.gd",
         "tests/test_rivalry_equipped_cars.gd", "tests/test_rivalry_custom_cars.gd",
         "tests/profile_deep_loading.gd"]


def sources():
    return [p for p in (ROOT / "game").rglob("*") if p.is_file()
            and p.relative_to(ROOT / "game").parts[0] not in ("assets", ".godot", "android", "tmp", "build")]


def prepare(full=False):
    assert full and PROJECT.is_dir(), "Reuse the existing disposable real source/assets fixture"
    for p in [ROOT / "game" / rel for rel in OWNED]:
        target = PROJECT / p.relative_to(ROOT / "game")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, target)
    return PROJECT


def refresh():
    before = geometry_inputs()
    copied = []
    for rel, digest in before.items():
        source = ROOT / rel
        target = PROJECT.parent / rel
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied.append(rel)
    after = geometry_inputs()
    assert before == after, "Concurrent vehicle changes; retry the snapshot"
    assert all(hashlib.sha256((PROJECT.parent / rel).read_bytes()).hexdigest() == digest for rel, digest in after.items())
    for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
        shutil.copy2(ROOT / "game/.godot" / name, PROJECT / ".godot" / name)
    for p in sources():
        target = PROJECT / p.relative_to(ROOT / "game")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p,target)
    (WORK / "snapshot.json").write_text(json.dumps({"geometry_inputs":after,"copied":copied},indent=2))
    print(json.dumps({"source_inputs":len(after),"refreshed":len(copied)}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--refresh", action="store_true")
    args, forwarded = parser.parse_known_args()
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    if args.refresh:
        refresh()
        return 0
    runner.WORK, runner.OUT, runner.prepare = WORK, OUT, prepare
    sys.argv = [sys.argv[0],args.name,"--full",*forwarded]
    status = runner.main()
    path = OUT / (args.name+"-receipt.json")
    receipt = json.loads(path.read_text())
    receipt["source_scope"] = "Real private source/assets/import copies; reused disposable fixture; no live links"
    path.write_text(json.dumps(receipt,indent=2)+"\n")
    return status


if __name__ == "__main__":
    sys.exit(main())
