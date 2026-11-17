"""Isolated experiments for halving loading; never modifies shipping sources."""
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path
import profile_game_overview as runner

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/loading-half-review-2026-11-17"
OUT = ROOT / "docs/evidence/loading-half-review-2026-11-17"
PROJECT = WORK / "snapshot/game"
runner.PROJECT = PROJECT
runner.OUT = OUT

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_file(path, content):
    temporary = path.with_name(path.name + ".half-review-temp")
    temporary.write_bytes(content.encode("utf-8") if isinstance(content, str) else content)
    os.replace(temporary, path)  # Break immutable snapshot hardlinks before edits.

def sources():
    files = [PROJECT / "project.godot", ROOT / "godot-version.txt"]
    files += [p for p in PROJECT.rglob("*") if p.is_file()
              and ".godot" not in p.parts and p.suffix in
              (".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".scn", ".tscn", ".res", ".json", ".dll")]
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in files}

runner.sources = sources

def prepare():
    previous = ROOT / "build/loading-review-2026-11-17/snapshot/game"
    assert not PROJECT.exists()
    def ignore(folder, names):
        return [n for n in names if n == "shader_cache" or n.endswith(".half-review-temp")]
    if previous.is_dir():
        shutil.copytree(previous, PROJECT, copy_function=os.link, ignore=ignore)
        manifest = json.loads((ROOT / "docs/evidence/loading-review-2026-11-17/snapshot.json").read_text())["files"]
    else:
        # Reproduction must not require retaining the preceding disposable copy.
        live=ROOT/"game"
        def live_ignore(folder,names):
            relative=Path(folder).relative_to(live)
            if str(relative)=='.': return [n for n in names if n in ('android','build','tmp')]
            if relative.as_posix()=='.godot': return [n for n in names if n not in ('imported','global_script_class_cache.cfg','extension_list.cfg','uid_cache.bin')]
            return ignore(folder,names)
        shutil.copytree(live,PROJECT,ignore=live_ignore)
        manifest={}
    changed, unstable = [], []
    for relative, old in manifest.items():
        source = ROOT / "game" / relative
        if not source.is_file():
            continue
        current = digest(source)
        if current != old or digest(PROJECT / relative) != current:
            replace_file(PROJECT / relative, source.read_bytes())
            if digest(PROJECT / relative) != current or digest(source) != current:
                unstable.append(relative)
            changed.append(relative)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "snapshot.json").write_text(json.dumps(dict(reconciled=changed, unstable=unstable,
        method="Immutable preceding private snapshot hardlinks; changed live files copied by atomic replacement; every experiment replaces files atomically"), indent=2))
    assert not unstable, unstable
    print(json.dumps(dict(files=len(manifest), refreshed=len(changed), unstable=unstable)))
    sync()

def sync():
    copied, unstable = [], []
    source_root = ROOT / "game"
    for source in source_root.rglob("*"):
        relative = source.relative_to(source_root)
        if not source.is_file() or relative.parts[0] in ("android", "tmp", "build"):
            continue
        if ".godot" in relative.parts and "imported" not in relative.parts and source.name not in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
            continue
        target = PROJECT / relative
        current = digest(source)
        if not target.is_file() or digest(target) != current:
            target.parent.mkdir(parents=True, exist_ok=True)
            replace_file(target, source.read_bytes())
            if digest(target) != current or digest(source) != current: unstable.append(relative.as_posix())
            copied.append(relative.as_posix())
    (OUT/"sync.json").write_text(json.dumps(dict(copied=copied, unstable=unstable),indent=2))
    assert not unstable, unstable
    print(json.dumps(dict(copied=len(copied),unstable=unstable)))

if __name__ == "__main__":
    if sys.argv[1:] == ["prepare"]:
        prepare()
    elif sys.argv[1:] == ["sync"]:
        sync()
    elif sys.argv[1:] == ["restore-observers"]:
        for relative in ["core/app.gd", "core/game.gd", "core/features/race.gd", "race/world_render_preparation.gd", "tests/profile_loading_fixes.gd"]:
            replace_file(PROJECT/relative, (ROOT/"game"/relative).read_bytes())
        print("Restored the five preceding private observer files from current production sources")
    else:
        assert PROJECT.is_dir(), "Prepare the private project first"
        raise SystemExit(runner.main())
