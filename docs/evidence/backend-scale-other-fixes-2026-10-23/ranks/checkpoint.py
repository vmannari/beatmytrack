"""Create a task-only checkpoint, excluding concurrent Rivalry P1 changes."""
import difflib
import hashlib
import json
from pathlib import Path

directory = Path(__file__).resolve().parent
root = directory.parents[3]
existing = {"backend/bmt_backend/runs.py":"runs.py",
            "backend/bmt_backend/economy_models.py":"economy_models.py",
            "backend/bmt_backend/rivalry.py":"rivalry.py"}
new = ["backend/bmt_backend/leaderboard_ranks.py",
       "backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py",
       "backend/tests/test_bounded_leaderboard_ranks.py"]
patch = []
hashes = {}
for path, snapshot in existing.items():
    before = (directory / "before" / snapshot).read_text()
    after = (root / path).read_text()
    # Concurrent terminology cleanup changed module introductions only.
    after = before.splitlines(True)[0] + "".join(after.splitlines(True)[1:])
    if path.endswith("rivalry.py"):
        start, stop = "def skill_score(", "def require_member("
        after = before[:before.index(start)] + after[after.index(start):after.index(stop)] + before[before.index(stop):]
        after = after.replace("from sqlalchemy import case, func, or_, select, update", "from sqlalchemy import func, or_, select, update")
        after = after.replace("    BoardTimeCount,\n", "")
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),fromfile="a/"+path,tofile="b/"+path))
    hashes[path] = hashlib.sha256((root/path).read_bytes()).hexdigest()
for path in new:
    after = (root/path).read_text()
    patch.extend(difflib.unified_diff([],after.splitlines(True),fromfile="/dev/null",tofile="b/"+path))
    hashes[path] = hashlib.sha256((root/path).read_bytes()).hexdigest()
(directory/"task-only.patch").write_text("".join(patch))
(directory/"source-hashes.json").write_text(json.dumps(hashes,indent=2)+"\n")
print(json.dumps({"files":len(hashes),"patch_lines":len(patch)}))
