"""Private native renders of real cars and offline Rivalry UI qualification."""
import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

import qualify_rivalry_simple_cars as runner

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/rivalry-real-previews-2026-11-13"
OUT = ROOT / "docs/evidence/rivalry-real-previews-2026-11-13"
PROJECT = WORK / "project/game"
USE_PHOTO = False
USE_OLD_APP = False
USE_OLD_PHOTO = False
OWNED = ["ui/rivalry_simple_car.gd", "ui/rivalry_car_photo.gdshader",
         "core/app.gd",
         "tests/bake_rivalry_car_previews.gd", "tests/test_rivalry_car_photos.gd", "tests/test_rivalry_simple_car.gd",
         "tests/test_rivalry_custom_cars.gd", "tests/profile_deep_loading.gd",
         "tests/test_rivalry_ready_entry.gd", "tests/test_rivalry_view_polish.gd"]


def geometry_inputs():
    spec = json.loads((ROOT / "game/vehicle/prepared_asset_dependencies.json").read_text())
    paths = []
    for directory in ["vehicle", "resources", "assets/vehicles", "assets/liveries", "assets/fonts"]:
        for p in (ROOT / "game" / directory).rglob("*"):
            if not p.is_file() or p.suffix in (".uid", ".import"): continue
            rel = p.relative_to(ROOT).as_posix()
            # Catalogue pictures are generated outputs, not inputs to the
            # stock, plain-paint car construction used by this photograph.
            if "/previews_v2/" in rel: continue
            if any(fnmatch.fnmatchcase(rel, pattern) for pattern in spec["excluded"]): continue
            paths.append(p)
    paths += [ROOT / "game" / p for p in ["ui/garage_environment.gd", "ui/showroom_studio.gd", "ui/studio_sky.gdshader"]]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def source_fingerprint(inputs):
    """Retain every path/hash while keeping packaged provenance small."""
    direct, trees = {}, {}
    for rel, digest in inputs.items():
        if rel.startswith("game/assets/"):
            tree = "/".join(rel.split("/")[:3])
            trees.setdefault(tree,{})[rel] = digest
        else:
            direct[rel] = digest
    for tree, files in trees.items():
        direct["tree:"+tree] = hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
    return direct


def prepare(full=False):
    if (WORK / "snapshot.json").exists():
        prior = json.loads((WORK / "snapshot.json").read_text())
        if prior["geometry_inputs"].pop("game/tests/bake_rivalry_car_previews.gd",None) is not None:
            prior["baker_tracked_per_capture"] = True
            (WORK / "snapshot.json").write_text(json.dumps(prior,indent=2))
            (OUT / "snapshot.json").write_text(json.dumps(prior,indent=2))
    if not (WORK / "snapshot.json").exists():
        paths = [p for p in (ROOT / "game").rglob("*") if p.is_file()
                 and p.relative_to(ROOT / "game").parts[0] not in (".godot", "android", "tmp", "build")]
        before = geometry_inputs()
        for p in paths:
            target = PROJECT / p.relative_to(ROOT / "game")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        cache = PROJECT / ".godot"
        cache.mkdir(exist_ok=True)
        for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
            source = ROOT / "game/.godot" / name
            if source.exists(): shutil.copy2(source, cache / name)
        shutil.copytree(ROOT / "game/.godot/imported", cache / "imported", dirs_exist_ok=True)
        shutil.copytree(ROOT / "backend/tests/fixtures", PROJECT.parent / "backend/tests/fixtures", dirs_exist_ok=True)
        after = geometry_inputs()
        mismatches = [rel for rel in before.keys() | after.keys() if before.get(rel) != after.get(rel)
                      or not (PROJECT.parent / rel).is_file()
                      or hashlib.sha256((PROJECT.parent / rel).read_bytes()).hexdigest() != after.get(rel)]
        receipt = {"geometry_inputs":after, "changed_during_copy":mismatches,
                   "scope":"Real private source/assets/imports; no junctions, hardlinks or shared profile"}
        (WORK / "snapshot-attempt.json").write_text(json.dumps(receipt, indent=2))
        if mismatches: raise RuntimeError(f"Snapshot inputs changed: {mismatches[:12]}")
        (WORK / "snapshot.json").write_text(json.dumps(receipt, indent=2))
        (OUT / "snapshot.json").write_text(json.dumps(receipt, indent=2))
    for rel in OWNED:
        if (ROOT / "game" / rel).exists():
            target = PROJECT / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "game" / rel, target)
    if USE_PHOTO:
        shutil.copy2(WORK / "proposed/rivalry_simple_car.gd", PROJECT / "ui/rivalry_simple_car.gd")
    if USE_OLD_APP:
        shutil.copy2(WORK / "before/game/core/app.gd", PROJECT / "core/app.gd")
    if USE_OLD_PHOTO:
        shutil.copy2(WORK / "before/game/ui/rivalry_simple_car.gd", PROJECT / "ui/rivalry_simple_car.gd")
    if full: return PROJECT
    minimal = WORK / "minimal"
    minimal.mkdir(exist_ok=True)
    (minimal / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Real Rivalry car previews"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=610\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    for rel in ["ui/rivalry_simple_car.gd", "ui/rivalry_car_photo.gdshader", "tests/test_rivalry_car_photos.gd", "tests/test_rivalry_simple_car.gd"]:
        target = minimal / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / rel, target)
    shutil.copytree(PROJECT / "assets/menu/rivalry_cars_v2", minimal / "assets/menu/rivalry_cars_v2", dirs_exist_ok=True)
    return minimal


def publish():
    snapshot = json.loads((WORK / "snapshot.json").read_text())
    current = geometry_inputs()
    if current != snapshot["geometry_inputs"]:
        changed = [rel for rel in current.keys() | snapshot["geometry_inputs"].keys()
                   if current.get(rel) != snapshot["geometry_inputs"].get(rel)]
        raise RuntimeError(f"Refuse stale preview publication: {changed[:12]}")
    report = json.loads((OUT / "bake.json").read_text())
    assert report["baker_sha256"] == hashlib.sha256((ROOT / "game/tests/bake_rivalry_car_previews.gd").read_bytes()).hexdigest()
    assert set(report["cars"]) == {"compact", "super_rally", "electric", "kart", "forklift", "hovercraft"}
    dest = ROOT / "game/assets/menu/rivalry_cars_v2"
    dest.mkdir(parents=True, exist_ok=True)
    files = {}
    for vehicle, data in report["cars"].items():
        for role, expected in data["hashes"].items():
            name = vehicle+"_"+role+".res"
            src = PROJECT / "assets/menu/rivalry_cars_v2" / name
            assert hashlib.sha256(src.read_bytes()).hexdigest() == expected
            shutil.copy2(src, dest / name)
            files[name] = expected
    provenance = dict(report, sources=source_fingerprint(current), source_input_count=len(current), textures=files)
    (dest / "provenance.json").write_text(json.dumps(provenance, indent=2)+"\n")
    (OUT / "publication.json").write_text(json.dumps({"textures":files,"input_fence_exact":True},indent=2)+"\n")
    print(json.dumps({"published_textures":len(files),"source_inputs":len(current)}))


def refresh():
    before = geometry_inputs()
    for p in (ROOT / "game").rglob("*"):
        if not p.is_file() or p.relative_to(ROOT / "game").parts[0] in ("assets", ".godot", "android", "tmp", "build"): continue
        target = PROJECT / p.relative_to(ROOT / "game")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p,target)
    for rel in before:
        target = PROJECT.parent / rel
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT / rel,target)
    for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
        source = ROOT / "game/.godot" / name
        if source.exists(): shutil.copy2(source,PROJECT / ".godot" / name)
    after = geometry_inputs()
    changed = [rel for rel in before.keys() | after.keys() if before.get(rel)!=after.get(rel)
               or not (PROJECT.parent/rel).is_file()
               or hashlib.sha256((PROJECT.parent/rel).read_bytes()).hexdigest()!=after.get(rel)]
    prior = json.loads((WORK/"snapshot.json").read_text())
    history_path = OUT/"refreshes.json"
    history = json.loads(history_path.read_text()) if history_path.exists() else []
    history.append({"previous_inputs_changed":[rel for rel in before.keys()|prior["geometry_inputs"].keys() if before.get(rel)!=prior["geometry_inputs"].get(rel)],"copy_changed":changed})
    history_path.write_text(json.dumps(history,indent=2))
    if changed: raise RuntimeError(f"Refresh inputs changed: {changed[:12]}")
    receipt = {"geometry_inputs":after,"changed_during_copy":[],"scope":"Refreshed real private source/assets; no shared links"}
    (WORK/"snapshot.json").write_text(json.dumps(receipt,indent=2))
    (OUT/"snapshot.json").write_text(json.dumps(receipt,indent=2))
    print(json.dumps({"refreshed_inputs":len(after),"previous_differences":len(history[-1]["previous_inputs_changed"])}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--bake", action="store_true")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--photo", action="store_true")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--before-canvas-wait", action="store_true")
    parser.add_argument("--before-photo", action="store_true")
    parser.add_argument("--only", default="")
    args, forwarded = parser.parse_known_args()
    global USE_PHOTO, USE_OLD_APP, USE_OLD_PHOTO
    USE_PHOTO = args.photo
    USE_OLD_APP = args.before_canvas_wait
    USE_OLD_PHOTO = args.before_photo
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    if args.publish: publish(); return 0
    if args.refresh: refresh(); return 0
    os.environ["BMT_REAL_CAR_EVIDENCE"] = str(OUT)
    os.environ["BMT_REAL_CAR_ONLY"] = args.only
    runner.WORK = WORK
    runner.OUT = OUT
    runner.prepare = prepare
    sys.argv = [sys.argv[0],args.name,*forwarded]
    if args.bake: sys.argv += ["--full","--script","res://tests/bake_rivalry_car_previews.gd"]
    status = runner.main()
    receipt_path = OUT / (args.name+"-receipt.json")
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text())
        receipt["source_scope"] = "Real private source/assets/import copies; no shared links"
        if args.bake and receipt["exit_code"]==0 and not receipt["diagnostics"]:
            changed = receipt["changed_files"]
            allowed = {"assets/menu/rivalry_cars_v2/"+car+"_"+role+".res" for car in ["compact","kart","forklift","electric","hovercraft","super_rally"] for role in ["image","mask"]}
            if set(changed) <= allowed:
                receipt["input_unchanged_except_declared_bake_outputs"] = True
                receipt["declared_output_changes"] = changed
                status = 0
        receipt_path.write_text(json.dumps(receipt,indent=2)+"\n")
    return status


if __name__ == "__main__":
    sys.exit(main())
