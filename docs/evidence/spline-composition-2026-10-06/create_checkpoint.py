"""Build the task-only review patch without staging shared-workspace changes."""
from pathlib import Path
import difflib
import hashlib
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
CHANGED = [
    "game/track/visual_road_join.gd", "game/track/road_kerbs.gd",
    "game/track/native_track_visual.gd", "scripts/dev.ps1",
    "docs/SPLINE_BORDER_FIX.md",
]
NEW = ["game/tests/test_spline_composition.gd", "game/tests/test_spline_composition.gd.uid",
       "docs/SPLINE_COMPOSITION_FIX.md"]
baseline = {path: (OUT / "before" / path).read_text(encoding="utf-8") for path in CHANGED}
baseline.update({path: "" for path in NEW})
for path in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    current = (ROOT / path).read_text(encoding="utf-8")
    entry, rest = current.split("\n\n", 1)
    assert "docs/SPLINE_COMPOSITION_FIX.md" in entry
    baseline[path] = rest
patch = []
hashes = {}
for path, before in baseline.items():
    after = (ROOT / path).read_text(encoding="utf-8")
    patch.append(f"diff --git a/{path} b/{path}\n")
    if not before: patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                    fromfile="a/"+path if before else "/dev/null", tofile="b/"+path):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    hashes[path] = {"before_normalized_sha256": hashlib.sha256(before.encode()).hexdigest(),
                    "after_normalized_sha256": hashlib.sha256(after.encode()).hexdigest()}
(OUT / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-hashes.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")
print(f"SCOPED_SPLINE_COMPOSITION_CHECKPOINT: {len(baseline)} files; Git index untouched")
