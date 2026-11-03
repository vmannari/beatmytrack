"""Task-only patch with forward/reverse checks; never writes the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = ["AGENTS.md", "DEVELOPMENT_STATUS.md"]
added = ["game/tests/review_game_startup_2026_11_02.gd", "game/tests/review_app_resources_2026_11_02.gd",
         "docs/GAME_LOADING_REVIEW_2026_11_02.md", *[
             "docs/evidence/game-loading-review-2026-11-02/" + name
             for name in ("run_review.py", "summarize.py", "checkpoint.py")]]
if "--seed" in sys.argv:
    for path in changed:
        target = evidence / "task-base" / path
        assert not target.exists(), "Never overwrite the task baseline"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / path, target)
    print("Task baseline saved.")
    sys.exit(0)

def normalized(path):
    return path.read_bytes().replace(b"\r\n", b"\n")

parts, before, after = [], {}, {}
for path in changed + added:
    old = normalized(evidence / "task-base" / path) if path in changed else b""
    new = normalized(root / path)
    before[path], after[path] = old, new
    parts.append("diff --git a/" + path + " b/" + path + "\n")
    if path in added:
        parts.append("new file mode 100644\n")
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True), new.decode().splitlines(keepends=True),
                                    fromfile="a/" + path if path in changed else "/dev/null", tofile="b/" + path))
patch = evidence / "task.patch"
patch.write_bytes("".join(parts).encode())
owned = root / "build/game-loading-review-20261102" / ("checkpoint-" + str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root / "build/game-loading-review-20261102").resolve())
for path in changed:
    target = owned / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(before[path])
directory = "--directory=" + owned.relative_to(root).as_posix()
commands = []
for arguments in (("--check",), (), ("--reverse", "--check"), ("--reverse",)):
    command = ["git", "apply", directory, *arguments, str(patch)]
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
    assert result.returncode == 0, result.stderr
    if arguments == ():
        assert all(normalized(owned / path) == after[path] for path in changed + added)
assert all(normalized(owned / path) == before[path] for path in changed)
assert all(not (owned / path).exists() for path in added)
report = dict(files=changed + added, forward_content_exact=True, reverse_content_exact=True, main_index_written=False,
              patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),
              source_sha256={path: hashlib.sha256(after[path]).hexdigest() for path in changed + added}, commands=commands)
(evidence / "checkpoint.json").write_text(json.dumps(report, indent=2) + "\n")
print("Task-only patch forward/reverse/content checks pass; main index unchanged.")
