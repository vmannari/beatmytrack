"""Record a task-only binary-capable patch without changing the shared index."""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
MODIFIED = ["backend/bmt_backend/app.py", "backend/pyproject.toml",
            "backend/bmt_backend/privacy_pages.py", "backend/bmt_backend/privacy_ui/style.css",
            "backend/README.md", "licenses/ASSETS.md", "AGENTS.md", "DEVELOPMENT_STATUS.md",
            "docs/PHASE_0_PLAN.md"]
NEW = ["backend/bmt_backend/public_pages.py", "backend/tests/test_public_website.py",
       "scripts/prepare_public_website_assets.py", "scripts/review_public_website.py",
       "scripts/preview_public_website.py", "docs/GAME_WEBSITE_2026_10_25.md"]
NEW += [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "backend/bmt_backend/public_ui").iterdir())]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    destination = ROOT / "build/game-website-checkpoint"
    # Reuse the exact owned directory only; no recursive removal/move is needed.
    destination.mkdir(parents=True, exist_ok=True)
    for name in MODIFIED:
        original = destination / "before" / name
        original.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUT / "before" / name, original)
    for name in MODIFIED + NEW:
        result = destination / "after" / name
        result.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, result)
    diff = subprocess.run(["git", "-c", "core.autocrlf=false", "diff", "--no-index", "--binary",
                           "--", "before", "after"], cwd=destination, capture_output=True)
    assert diff.returncode == 1, diff.stderr.decode(errors="replace")
    patch = diff.stdout
    for old, new in ((b"a/before/", b"a/"), (b"a/after/", b"a/"),
                     (b"b/before/", b"b/"), (b"b/after/", b"b/")):
        patch = patch.replace(old, new)
    patch_path = OUT / "task-only.patch"
    patch_path.write_bytes(patch)
    results = []
    for directory, reverse in ((ROOT, True), (destination / "before", False)):
        command = ["git", "-c", "core.autocrlf=false", "apply", "--check"]
        if reverse:
            command.append("--reverse")
        command.append(str(patch_path))
        check = subprocess.run(command, cwd=directory, capture_output=True)
        results.append({"directory": str(directory.relative_to(ROOT) or "."), "reverse": reverse,
                        "exit_code": check.returncode, "stderr": check.stderr.decode(errors="replace")})
        assert check.returncode == 0, results[-1]
    records = []
    for name in MODIFIED + NEW:
        original = OUT / "before" / name
        records.append({"path": name, "sha256": sha(ROOT / name),
                        "before_sha256": sha(original) if name in MODIFIED else None})
    record = {"patch": patch_path.name, "sha256": sha(patch_path), "bytes": patch_path.stat().st_size,
              "files": records, "checks": results, "shared_index_modified": False}
    (OUT / "checkpoint.json").write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"files": len(records), "bytes": record["bytes"], "checks": results}))


if __name__ == "__main__":
    main()
