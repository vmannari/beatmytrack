"""Create/check this evaluation's patch without writing the main Git index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = ["AGENTS.md", "DEVELOPMENT_STATUS.md"]
added = ["game/tests/review_race_loading_2026_11_02.gd", "docs/RACE_LOADING_REVIEW_2026_11_02.md",
         "docs/evidence/race-loading-review-2026-11-02/run_review.py",
         "docs/evidence/race-loading-review-2026-11-02/summarize_review.py",
         "docs/evidence/race-loading-review-2026-11-02/checkpoint.py"]
def normalized(path):
    return path.read_bytes().replace(b"\r\n", b"\n")

parts = []
before = {}
after = {}
for path in changed + added:
    old = normalized(evidence / "task-base" / path) if path in changed else b""
    new = normalized(root / path)
    before[path], after[path] = old, new
    parts.append("diff --git a/" + path + " b/" + path + "\n")
    if path in added:
        parts.append("new file mode 100644\n")
    parts.extend(difflib.unified_diff(old.decode("utf-8").splitlines(keepends=True),
                                    new.decode("utf-8").splitlines(keepends=True),
                                    fromfile="a/" + path if path in changed else "/dev/null", tofile="b/" + path))
patch = evidence / "task.patch"
patch.write_bytes("".join(parts).encode("utf-8"))
owned = root / "build/race-loading-review-20261102" / ("checkpoint-" + str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root / "build/race-loading-review-20261102").resolve())
for path in changed:
    target = owned / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(before[path])
directory = "--directory=" + owned.relative_to(root).as_posix()
commands = []
def apply(*args):
    command = ["git", "apply", *args, str(patch)]
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
    assert result.returncode == 0, result.stderr

apply(directory, "--check")
apply(directory)
assert all(normalized(owned / p) == after[p] for p in changed + added)
apply(directory, "--reverse", "--check")
apply(directory, "--reverse")
assert all(normalized(owned / p) == before[p] for p in changed)
assert all(not (owned / p).exists() for p in added)
report = dict(files=changed + added, forward_content_exact=True, reverse_content_exact=True,
              main_index_written=False, patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),
              source_sha256={p: hashlib.sha256(after[p]).hexdigest() for p in changed + added}, commands=commands)
(evidence / "checkpoint.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Task-only patch: forward/reverse/content checks passed in owned directory; no main index write.")
