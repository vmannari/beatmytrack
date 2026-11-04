"""Produce and round-trip a task-only patch using an isolated Git index/repo."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
SCRATCH = ROOT / "build/volt-door-fender-fit/checkpoint"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before = json.loads((EVIDENCE / "baseline.json").read_text())
    additions = ["game/tests/test_volt_door_fender_fit.gd", "scripts/run_volt_fit.py",
                 "docs/VOLT_DOOR_FENDER_FIT_2026_11_03.md"]
    paths = sorted(set(before) | set(additions))
    SCRATCH.mkdir(parents=True, exist_ok=False)
    index = ROOT / ".git/index"
    index_before = digest(index)
    env = os.environ.copy()
    for variable in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        env.pop(variable, None)

    def git(*arguments):
        return subprocess.run(["git", "-C", str(SCRATCH), "-c", "core.autocrlf=false",
                               "-c", "core.hooksPath=" + str(SCRATCH / "empty-hooks"),
                               *arguments], env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, check=True).stdout

    for relative, expected in before.items():
        source = EVIDENCE / "before" / relative
        assert digest(source) == expected, relative
        target = SCRATCH / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    (SCRATCH / "empty-hooks").mkdir()
    git("init")
    git("add", "--", ".")
    git("-c", "user.name=Codex task checkpoint", "-c", "user.email=codex@local.invalid",
        "commit", "-m", "Task-start Volt door and fender snapshot")
    for relative in paths:
        source = ROOT / relative
        target = SCRATCH / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    git("add", "-N", "--", *additions)
    patch = EVIDENCE / "task-only.patch"
    patch.write_bytes(git("diff", "--binary", "--no-ext-diff"))
    changed = git("diff", "--name-only").decode().splitlines()
    final = EVIDENCE / "final"
    for relative in paths:
        target = final / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SCRATCH / relative, target)
    hashes = {relative: digest(final / relative) for relative in paths}
    git("apply", "--reverse", "--check", str(patch))
    git("apply", "--reverse", str(patch))
    assert all(digest(SCRATCH / p) == h for p, h in before.items())
    assert all(not (SCRATCH / p).exists() for p in additions)
    git("apply", "--check", str(patch))
    git("apply", str(patch))
    assert all(digest(SCRATCH / p) == h for p, h in hashes.items())
    assert digest(index) == index_before
    receipt = {"changed_files": changed, "changed_count": len(changed),
               "patch_bytes": patch.stat().st_size, "reverse_content_exact": True,
               "forward_content_exact": True, "main_index_unchanged": True,
               "final_sha256": hashes}
    (EVIDENCE / "checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(len(changed), "files; reverse and forward contents exact; main index exact")


if __name__ == "__main__":
    main()
