"""Archive and round-trip the task's sources without touching the shared Git index."""
import difflib
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BUILD = ROOT / "build/daily-page-loading-20261114"
FILES = ["game/core/features/daily.gd", "game/ui/daily_result_card.gd",
         "game/ui/track_of_day_page.gd", "game/persistence/daily_menu_cache.gd",
         "game/persistence/daily_menu_cache.gd.uid", "game/tests/test_daily_page_loading.gd",
         "game/tests/test_daily_page_loading.gd.uid", "scripts/run_daily_page_loading.py"]


def main():
    if not (OUT / "before").exists():
        shutil.copytree(BUILD / "before", OUT / "before")
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
        assert (scratch/name).read_text(encoding="utf-8") == (ROOT/name).read_text(encoding="utf-8"), name
    subprocess.run([*command, "--check", "--reverse", str(path)], cwd=ROOT, check=True)
    subprocess.run([*command, "--reverse", str(path)], cwd=ROOT, check=True)
    for name in FILES:
        original = OUT / "before" / name
        if original.exists():
            assert (scratch/name).read_text(encoding="utf-8") == original.read_text(encoding="utf-8"), name
        else:
            assert not (scratch/name).exists(), name
    (OUT / "checkpoint.json").write_text(json.dumps({"files": hashes, "forward": True, "reverse": True,
                                                   "comparison": "exact source with LF normalization"}, indent=2)+"\n", encoding="utf-8")
    print(f"SOURCE_CHECKPOINT {len(FILES)} files, forward and reverse exact after LF normalization")


if __name__ == "__main__":
    main()
