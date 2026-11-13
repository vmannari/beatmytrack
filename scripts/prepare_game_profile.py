"""Copy a private current project; detect races with concurrent source writers."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import os

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/game-profile-2026-11-12/snapshot"
OUT = ROOT / "docs/evidence/game-profile-2026-11-12"
if (DEST / "game/project.godot").exists():
    raise SystemExit("Snapshot already exists; use the retained measured snapshot or choose a fresh destination before preparing again.")


def inputs():
    found = []
    for p in (ROOT / "game").rglob("*"):
        relative = p.relative_to(ROOT / "game")
        if not p.is_file() or relative.parts[0] in ("android", "tmp", "build", ".godot", "assets"):
            continue
        found.append(p)
    found += [ROOT / "game/.godot" / n for n in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin")]
    return [p for p in found if p.is_file()]


paths = inputs()
before = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
for p in paths:
    target = DEST / p.relative_to(ROOT)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p, target)
shutil.copytree(ROOT / "backend/tests/fixtures", DEST / "backend/tests/fixtures", dirs_exist_ok=True)
asset_root = ROOT / "game/assets"
asset_target = DEST / "game/assets"
if not asset_target.exists():
    for p in asset_root.rglob("*"):
        target = asset_target / p.relative_to(asset_root)
        if p.is_dir(): target.mkdir(parents=True, exist_ok=True)
        elif p.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            os.link(p, target)
for relative in ("game/.godot/imported",):
    target = DEST / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        env = dict(os.environ, BMT_PROFILE_LINK=str(target), BMT_PROFILE_TARGET=str(ROOT / relative))
        subprocess.run(["powershell", "-NoProfile", "-Command", "New-Item -ItemType Junction -Path $env:BMT_PROFILE_LINK -Target $env:BMT_PROFILE_TARGET | Out-Null"], env=env, check=True)
changed = []
for p in paths:
    key = str(p.relative_to(ROOT))
    copied = hashlib.sha256((DEST / key).read_bytes()).hexdigest()
    if before[key] != copied or before[key] != hashlib.sha256(p.read_bytes()).hexdigest():
        changed.append(key)
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "snapshot-manifest.json").write_text(json.dumps(dict(files=before, changed_during_copy=changed, hardlinked_assets="game/assets", shared_read_only_assets=["game/.godot/imported"], reason="Disk space prevents a complete binary snapshot; each run hashes runtime assets before and after. In-place writes to hardlinked files remain visible."), indent=2), encoding="utf-8")
print(json.dumps(dict(files=len(paths), bytes=sum(p.stat().st_size for p in paths), changed=changed)))
if changed:
    raise SystemExit(1)
