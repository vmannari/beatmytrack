"""Task-only review patch, retaining concurrent physics and unrelated edits.

Actual task-start snapshots remain untouched under before/. For shared files,
derive a review baseline by undoing only this task's explicitly listed edits.
"""
from pathlib import Path
import difflib
import hashlib
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
CHANGED = [
    "game/race/track_session.gd", "game/race/race_rules.gd",
    "game/tests/test_checkpoint_rules.gd", "game/tests/test_bridge_exit_checkpoints.gd",
    "game/tests/test_star_spline_laps.gd", "backend/bmt_backend/contracts.py",
    "backend/bmt_backend/rivalry.py", "backend/tests/test_verifier.py",
    "backend/tests/test_review_reliability.py", "backend/tests/fixtures/verified_oval.json",
    "scripts/dev.ps1",
]
NEW = [
    "game/tests/test_star_gate_tolerance.gd", "game/tests/test_star_gate_tolerance.gd.uid",
    "game/tests/capture_star_gate_tolerance.gd", "game/tests/capture_star_gate_tolerance.gd.uid",
    "docs/STAR_GATE_TOLERANCE.md",
]
baseline = {path: (OUT / "before" / path).read_text(encoding="utf-8") for path in CHANGED}
original = dict(baseline)

for path in ["backend/tests/test_verifier.py", "backend/tests/test_review_reliability.py",
             "backend/tests/fixtures/verified_oval.json"]:
    before = (ROOT / path).read_text(encoding="utf-8").replace("standing-5-road-gates-v20", "standing-5-road-gates-v19")
    if path.endswith("test_verifier.py"):
        start = before.index("def test_spline_gate_rules_do_not_relabel_historical_boards(")
        end = before.index('\n\n@pytest.fixture', start)
        section = before[start:end]
        section = section.replace('previous["rules_key"] = "standing-5-road-gates-v19"', 'previous["rules_key"] = "standing-5-road-gates-v18"')
        section = section.replace('assert previous["rules_key"] == "standing-5-road-gates-v19"', 'assert previous["rules_key"] == "standing-5-road-gates-v18"')
        section = section.replace('previous_board = {**current_board, "rules_key": "standing-5-road-gates-v19"}', 'previous_board = {**current_board, "rules_key": "standing-5-road-gates-v18"}')
        before = before[:start] + section + before[end:]
    elif path.endswith("test_review_reliability.py"):
        before = before.replace('"standing-5-road-gates-v18", "standing-5-road-gates-v19"]', '"standing-5-road-gates-v18"]')
    baseline[path] = before

path = "backend/bmt_backend/contracts.py"
before = (ROOT / path).read_text(encoding="utf-8")
before = before.replace('        "standing-5-road-gates-v19",\n', '')
baseline[path] = before.replace('result["rules_key"] = "standing-5-road-gates-v20"', 'result["rules_key"] = "standing-5-road-gates-v19"')

path = "backend/bmt_backend/rivalry.py"
before = (ROOT / path).read_text(encoding="utf-8")
before = before.replace('("standing-5-road-gates-v18", "standing-5-road-gates-v19", "standing-5-road-gates-v20")', '("standing-5-road-gates-v18", "standing-5-road-gates-v19")')
baseline[path] = before.replace('upper = int(active[field].rsplit("v", 1)[1])', 'upper = 19 if active[field] == "standing-5-road-gates-v19" else 18')

path = "scripts/dev.ps1"
baseline[path] = "".join(line for line in (ROOT / path).read_text(encoding="utf-8").splitlines(keepends=True)
                         if "res://tests/test_star_gate_tolerance.gd" not in line)
baseline.update({path: "" for path in NEW})
for path in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    entry, rest = (ROOT / path).read_text(encoding="utf-8").split("\n\n", 1)
    assert "docs/STAR_GATE_TOLERANCE.md" in entry
    baseline[path] = rest

patch = []
hashes = {}
for path, before in baseline.items():
    after = (ROOT / path).read_text(encoding="utf-8")
    patch.append(f"diff --git a/{path} b/{path}\n")
    if not before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                    fromfile="a/" + path if before else "/dev/null", tofile="b/" + path):
        patch.append(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n")
    hashes[path] = {
        "review_before_normalized_sha256": hashlib.sha256(before.encode()).hexdigest(),
        "after_normalized_sha256": hashlib.sha256(after.encode()).hexdigest(),
    }
    if path in original:
        hashes[path]["actual_task_start_normalized_sha256"] = hashlib.sha256(original[path].encode()).hexdigest()
(OUT / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
print(f"SCOPED_STAR_TOLERANCE_CHECKPOINT: {len(baseline)} files; Git index untouched")
