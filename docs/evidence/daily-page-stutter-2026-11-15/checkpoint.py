"""Verify a task-only source patch in disposable scratch; never use the index."""
import difflib
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BUILD = ROOT / "build/daily-page-stutter-20261115"
FILES = ["game/core/app.gd", "game/core/features/daily.gd",
         "game/core/features/selected_track.gd", "game/race/selected_event.gd",
         "game/ui/garage_preloader.gd",
         "game/tests/profile_daily_page_stutter.gd", "game/tests/profile_daily_page_stutter.gd.uid",
         "game/tests/test_daily_page_stutter.gd", "game/tests/test_daily_page_stutter.gd.uid",
         "scripts/run_daily_page_stutter.py"]


def main():
    scratch = BUILD / "patch-check"
    assert scratch.resolve().is_relative_to((ROOT / "build").resolve())
    scratch.mkdir(parents=True, exist_ok=True)
    patch = []
    hashes = {}
    for name in FILES:
        original = OUT / "before" / name
        current = ROOT / name
        old = original.read_text(encoding="utf-8") if original.exists() else ""
        new = current.read_text(encoding="utf-8")
        target = scratch / name
        if original.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(old.encode())
        elif target.exists():
            raise RuntimeError(f"Unexpected scratch file: {target}")
        patch.append(f"diff --git a/{name} b/{name}\n")
        if not original.exists():
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                        fromfile=f"a/{name}" if original.exists() else "/dev/null",
                                        tofile=f"b/{name}"))
        archived = OUT / "after" / name
        archived.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(current, archived)
        hashes[name] = {"before": hashlib.sha256(original.read_bytes()).hexdigest() if original.exists() else None,
                        "after": hashlib.sha256(current.read_bytes()).hexdigest()}
    path = OUT / "source-only.patch"
    path.write_bytes("".join(patch).encode())
    command = ["git", "apply", "--unsafe-paths", f"--directory={scratch.as_posix()}"]
    subprocess.run([*command, "--check", str(path)], cwd=ROOT, check=True)
    subprocess.run([*command, str(path)], cwd=ROOT, check=True)
    for name in FILES:
        assert (scratch / name).read_text(encoding="utf-8") == (ROOT / name).read_text(encoding="utf-8"), name
    subprocess.run([*command, "--check", "--reverse", str(path)], cwd=ROOT, check=True)
    subprocess.run([*command, "--reverse", str(path)], cwd=ROOT, check=True)
    for name in FILES:
        original = OUT / "before" / name
        if original.exists():
            assert (scratch / name).read_text(encoding="utf-8") == original.read_text(encoding="utf-8"), name
        else:
            assert not (scratch / name).exists(), name
    (OUT / "checkpoint.json").write_text(json.dumps({"files": hashes, "forward": True, "reverse": True,
                                                    "comparison": "exact source with LF normalization"}, indent=2)+"\n", encoding="utf-8")
    print(f"SOURCE_CHECKPOINT {len(FILES)} files, forward and reverse exact after LF normalization")


if __name__ == "__main__":
    main()
