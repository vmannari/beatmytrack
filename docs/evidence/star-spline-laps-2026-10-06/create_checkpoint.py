"""Save only this task's deltas against the retained task-start sources."""
from pathlib import Path
import difflib
import hashlib
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
CHANGED = [
    "game/race/track_session.gd", "game/race/race_rules.gd",
    "game/tests/test_checkpoint_rules.gd", "game/tests/test_bridge_exit_checkpoints.gd",
    "backend/bmt_backend/contracts.py", "backend/bmt_backend/tracks.py",
    "backend/bmt_backend/rivalry.py", "backend/tests/test_verifier.py",
    "backend/tests/test_review_reliability.py", "backend/tests/fixtures/verified_oval.json",
    "scripts/dev.ps1",
]
NEW = [
    "game/tests/test_star_spline_laps.gd", "game/tests/test_star_spline_laps.gd.uid",
    "game/tests/capture_star_spline_gates.gd", "game/tests/capture_star_spline_gates.gd.uid",
    "game/tests/fixtures/star_spline_lap.json", "docs/STAR_SPLINE_CHECKPOINTS.md",
]
baseline = {path: (OUT / "before" / path).read_text(encoding="utf-8") for path in CHANGED}
baseline.update({path: "" for path in NEW})
for path in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    entry, rest = (ROOT / path).read_text(encoding="utf-8").split("\n\n", 1)
    assert "docs/STAR_SPLINE_CHECKPOINTS.md" in entry
    baseline[path] = rest
patch = []
hashes = {}
for path, before in baseline.items():
    after = (ROOT / path).read_text(encoding="utf-8")
    patch.append(f"diff --git a/{path} b/{path}\n")
    if not before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile="a/" + path if before else "/dev/null", tofile="b/" + path,
    ):
        patch.append(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n")
    hashes[path] = {
        "before_normalized_sha256": hashlib.sha256(before.encode()).hexdigest(),
        "after_normalized_sha256": hashlib.sha256(after.encode()).hexdigest(),
    }
(OUT / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
print(f"SCOPED_STAR_CHECKPOINT: {len(baseline)} files; Git index untouched")
