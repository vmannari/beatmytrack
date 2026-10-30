from pathlib import Path
import hashlib
import json
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
target = work / "source"
assert not (work / "source-manifest.json").exists(), "Preserve an already frozen snapshot"
paths = subprocess.check_output([
    "git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard",
    "--", "game", "native", "scripts", "godot-version.txt", ".gitignore",
]).decode("utf-8").split("\0")
names = {name for name in paths if name and not name.startswith(("game/.godot/", "game/android/")) and (root / name).is_file()}
for suffix in ("*.so", "*.dll"):
    names.update(path.relative_to(root).as_posix() for path in (root / "game/platform").rglob(suffix))
rows = []
for name in sorted(names):
    data = (root / name).read_bytes()
    destination = target / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    rows.append({"path": name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
# Use existing import products; the pinned import gate validates the copied project.
cache = root / "game/.godot"
if not (target / "game/.godot/imported").exists():
    shutil.copytree(cache / "imported", target / "game/.godot/imported")
for name in (".gdignore", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
    if (cache / name).is_file():
        shutil.copy2(cache / name, target / "game/.godot" / name)
drift = [row["path"] for row in rows if hashlib.sha256((root / row["path"]).read_bytes()).hexdigest() != row["sha256"]]
assert not drift, f"Sources changed while copying: {drift}"
(work / "source-manifest.json").write_text(json.dumps({"files": rows, "root_matches_after_copy": True}, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"frozen_files": len(rows), "source_bytes": sum(row["bytes"] for row in rows), "root_matches_after_copy": True}))
