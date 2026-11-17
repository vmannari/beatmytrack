"""Current-tree loading review using bounded private offline desktop profiles."""
import hashlib
import json
import shutil
import sys
from pathlib import Path
import profile_game_overview as runner

runner.OUT = runner.ROOT / "docs/evidence/loading-review-2026-11-17"
runner.PROJECT = runner.ROOT / "build/loading-review-2026-11-17/snapshot/game"

def sources():
    files = [runner.PROJECT / "project.godot", runner.ROOT / "godot-version.txt"]
    for path in runner.PROJECT.rglob("*"):
        if path.is_file() and path.suffix in (".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".scn", ".res", ".png", ".dll", ".json", ".ctex"):
            files.append(path)
    return {p.relative_to(runner.ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

runner.sources = sources

if __name__ == "__main__":
    if sys.argv[1:] == ["reconcile"]:
        manifest_path = runner.OUT/"snapshot.json"
        manifest = json.loads(manifest_path.read_text())
        source = runner.ROOT/"game"
        repaired = []
        for name, digest in manifest["files"].items():
            p = source/name
            current = hashlib.sha256(p.read_bytes()).hexdigest()
            if current != digest:
                shutil.copy2(p, runner.PROJECT/name)
                assert hashlib.sha256((runner.PROJECT/name).read_bytes()).hexdigest() == current
                manifest["files"][name] = current
                repaired.append(name)
        for name in ("tests/review_startup_2026_11_17.gd",):
            shutil.copy2(source/name, runner.PROJECT/name)
            manifest["files"][name] = hashlib.sha256((source/name).read_bytes()).hexdigest()
        manifest["reconciled_files"] = repaired
        manifest["note"] = "Initial concurrent copy changes retained above; changed files recopied and byte checked. Subsequent probes fence independent snapshot inputs."
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(json.dumps(dict(reconciled=repaired)))
        raise SystemExit(0)
    if sys.argv[1:] == ["prepare"]:
        if runner.PROJECT.exists():
            raise SystemExit("Snapshot already exists")
        source = runner.ROOT / "game"
        def inputs():
            return [p for p in source.rglob("*") if p.is_file()
                    and p.relative_to(source).parts[0] not in ("android", "build", "tmp")
                    and (".godot" not in p.parts or "imported" in p.parts
                         or p.name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"))]
        paths = inputs()
        before = {p.relative_to(source).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
        for p in paths:
            target = runner.PROJECT / p.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        changes = [name for name, digest in before.items()
                   if hashlib.sha256((runner.PROJECT/name).read_bytes()).hexdigest() != digest
                   or hashlib.sha256((source/name).read_bytes()).hexdigest() != digest]
        runner.OUT.mkdir(parents=True, exist_ok=True)
        (runner.OUT/"snapshot.json").write_text(json.dumps(dict(files=before, changed_during_copy=changes,
            method="Independent copies including native libraries, resources and imported textures"), indent=2))
        print(json.dumps(dict(files=len(paths), bytes=sum(p.stat().st_size for p in paths), changed=changes)))
        raise SystemExit(bool(changes))
    raise SystemExit(runner.main())
