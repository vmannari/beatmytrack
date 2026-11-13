"""Detach mutable asset hardlinks after concurrent bakes; never change live assets."""
import hashlib
import json
from pathlib import Path
import shutil
import os

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / "build/game-profile-2026-11-12/snapshot/game"
OUT = ROOT / "docs/evidence/game-profile-2026-11-12"
asset_root = STAGE / "assets"
assert asset_root.resolve() == asset_root.absolute()
manifest = {}
changed = []
for target in asset_root.rglob("*"):
    if not target.is_file():
        continue
    if not target.resolve().is_relative_to(asset_root.resolve()):
        raise ValueError("Asset target escaped the private snapshot")
    source = ROOT / "game/assets" / target.relative_to(asset_root)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    temp = target.with_name(target.name + ".profilecopy")
    shutil.copy2(source, temp)
    if hashlib.sha256(temp.read_bytes()).hexdigest() != digest or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        changed.append(str(source.relative_to(ROOT)))
    os.replace(temp, target)
    manifest[str(target.relative_to(STAGE))] = digest
source_imports = ROOT / "game/.godot/imported"
private_imports = STAGE / ".godot/imported"
if private_imports.resolve() == source_imports.resolve():
    temporary_imports = STAGE / ".godot/imported-profile-copy"
    shutil.copytree(source_imports, temporary_imports)
    for source in source_imports.rglob("*"):
        if not source.is_file():
            continue
        copied = temporary_imports / source.relative_to(source_imports)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(copied.read_bytes()).hexdigest() != digest:
            changed.append(str(source.relative_to(ROOT)))
        manifest[".godot/imported/"+source.relative_to(source_imports).as_posix()] = digest
    # Remove only the verified junction itself, never its live contents.
    assert private_imports.resolve() == source_imports.resolve()
    os.rmdir(private_imports)
    os.replace(temporary_imports, private_imports)
for relative in ("core/build_identity.gd", "project.godot"):
    shutil.copy2(ROOT / "game" / relative, STAGE / relative)
    manifest[relative] = hashlib.sha256((STAGE / relative).read_bytes()).hexdigest()
(OUT / "frozen-assets.json").write_text(json.dumps(dict(files=manifest, changed_during_copy=changed, imports="Private byte-checked copy", assets="All asset hardlinks detached into private byte-checked copies"), indent=2))
print(json.dumps(dict(copied=len(manifest), changes=changed, free_bytes=shutil.disk_usage(ROOT).free)), flush=True)
if changed:
    raise SystemExit(1)
