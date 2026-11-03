"""Check the task's source patch in a disposable tree, without using Git's index."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
WORK = ROOT / "tmp/garage-recovery/checkpoint"
FILES = ["game/ui/garage_preloader.gd", "game/ui/garage_preview_cache.gd",
         "game/ui/preview_touch_input.gd", "game/tests/test_garage_preview_recovery.gd"]
before = {}
after = {}
parts = []
for name in FILES:
    source = HERE / "before" / Path(name).name
    old = source.read_bytes() if source.exists() else b""
    new = (ROOT / name).read_bytes()
    before[name] = old
    after[name] = new
    parts.extend(difflib.unified_diff(
        old.decode().splitlines(keepends=True), new.decode().splitlines(keepends=True),
        fromfile="a/" + name if old else "/dev/null", tofile="b/" + name))
patch = HERE / "source.patch"
patch.write_bytes("".join(parts).encode())
# Recreate only this explicitly bounded disposable checkpoint tree.
if WORK.exists():
    assert WORK.resolve().is_relative_to((ROOT / "tmp/garage-recovery").resolve())
    shutil.rmtree(WORK)
for name, data in before.items():
    if data:
        target = WORK / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
prefix = "--directory=" + WORK.relative_to(ROOT).as_posix()
for flags in [["--check"], [], ["--reverse", "--check"], ["--reverse"]]:
    subprocess.run(["git", "apply", *flags, prefix, str(patch)], cwd=ROOT, check=True)
    if flags == []:
        assert all((WORK / name).read_bytes() == data for name, data in after.items())
for name, data in before.items():
    assert (WORK / name).read_bytes() == data if data else not (WORK / name).exists()
report = {"forward_check": True, "forward_exact": True, "reverse_check": True,
          "reverse_exact": True, "files": {
              name: {"before_sha256": hashlib.sha256(before[name]).hexdigest() if before[name] else None,
                     "after_sha256": hashlib.sha256(after[name]).hexdigest()}
              for name in FILES}}
(HERE / "checkpoint.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("Scoped checkpoint: forward/reverse checks and exact bytes pass")
