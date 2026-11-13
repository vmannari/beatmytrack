"""Collect compact evidence and verify the task-only patch off the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUNS = ROOT / "build/garage-paint-flash-20261107"
SOURCES = ["game/core/app.gd", "game/ui/header_car_appearance_cache.gd",
           "game/tests/test_header_capture_fences.gd", "game/tests/test_deferred_header.gd",
           "game/tests/profile_header_garage_regression.gd", "game/tests/test_garage_paint_flash.gd"]
names = ["before-headless", "before-native", "fixed-headless", "fixed-compatibility",
         "fixed-mobile", "fences-headless", "deferred-headless", "deferred-compatibility",
         "paint-transition-headless", "early-garage-headless"]
validation = {"requirements": ["GFL01", "GFL02", "GFLQ01"], "runs": {}, "sources": {}}
for name in names:
    folder = HERE / "receipts" / name
    folder.mkdir(parents=True, exist_ok=True)
    for filename in ["command.json", "console.log", "report.json", "result.json"]:
        if (RUNS / name / filename).exists():
            shutil.copy2(RUNS / name / filename, folder / filename)
    validation["runs"][name] = json.loads((folder / "command.json").read_text())
for source, destination in [
    ("fixed-compatibility/paint-stays-visible.png", "compatibility-paint-visible.png"),
    ("fixed-mobile/paint-stays-visible.png", "mobile-paint-visible.png"),
    ("fixed-compatibility/header-updated-after-leaving.png", "header-after-leaving.png"),
    ("fixed-compatibility/garage-return.png", "garage-return.png")]:
    shutil.copy2(RUNS / source, HERE / destination)
patch = []
checkpoint = RUNS / "checkpoint"
checkpoint.mkdir(exist_ok=False)
subprocess.run(["git", "init", "--quiet", str(checkpoint)], check=True)
for path in SOURCES:
    current = ROOT / path
    before = HERE / "before" / current.name
    after = HERE / "after" / current.name
    after.parent.mkdir(exist_ok=True)
    shutil.copy2(current, after)
    old_text = before.read_text(encoding="utf-8") if before.exists() else ""
    new_text = current.read_text(encoding="utf-8")
    patch += list(difflib.unified_diff(old_text.splitlines(keepends=True),
                  new_text.splitlines(keepends=True),
                  fromfile="a/"+path if before.exists() else "/dev/null", tofile="b/"+path))
    target = checkpoint / path
    target.parent.mkdir(parents=True, exist_ok=True)
    if before.exists(): target.write_text(old_text, encoding="utf-8", newline="\n")
    validation["sources"][path] = {
        "before_sha256": hashlib.sha256(before.read_bytes()).hexdigest() if before.exists() else None,
        "after_sha256": hashlib.sha256(current.read_bytes()).hexdigest()}
patch_file = HERE / "task-only.patch"
patch_file.write_text("".join(patch), encoding="utf-8", newline="\n")
commands = []
def git_apply(folder, *args):
    command = ["git", "-C", str(folder), "apply", *args, str(patch_file)]
    result = subprocess.run(command, capture_output=True, text=True)
    commands.append({"command": command, "exit_code": result.returncode,
                     "output": result.stdout+result.stderr})
    result.check_returncode()
git_apply(checkpoint, "--check")
git_apply(checkpoint)
for path in SOURCES:
    assert (checkpoint / path).read_text(encoding="utf-8") == (ROOT / path).read_text(encoding="utf-8")
git_apply(checkpoint, "--reverse", "--check")
git_apply(checkpoint, "--reverse")
for path in SOURCES:
    before = HERE / "before" / Path(path).name
    target = checkpoint / path
    assert target.read_text(encoding="utf-8") == before.read_text(encoding="utf-8") if before.exists() else not target.exists()
git_apply(ROOT, "--reverse", "--check")
validation["checkpoint"] = {"commands": commands, "round_trip_content_exact": True}
(HERE / "validation.json").write_text(json.dumps(validation, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs": len(names), "sources": len(SOURCES), "checkpoint_exact": True}))
