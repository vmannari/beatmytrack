"""Build a task-only review patch without staging unrelated workspace changes.

Selected zero-context hunks are reversed in memory to reconstruct the task's
baseline. The pre-existing topology preparation is retained in the one mixed
road helper hunk. No runtime source or Git index is modified by this script.
"""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
MARKERS = {
    "game/editor/road_pieces.gd": ["spline", "SplineRoad", "endpoint_width", "sample_index", "_pose(pieces[index],0)"],
    "game/core/app.gd": ["spline", "SplineRoad", "point_width"],
    "game/editor/editor_canvas.gd": ["spline", "SplineRoad", "endpoint_width"],
    "game/editor/track_compiler.gd": ["creator-compiler-21"],
    "game/editor/editor_button.gd": ['glyph == "spline"'],
    "game/tests/test_editor_workflow.gd": ["spline", "SplineRoad"],
    "scripts/dev.ps1": ["test_spline_road"],
    "backend/tests/test_verifier.py": ["spline", "creator-compiler-21", "c64c7d856"],
}
CLEAN = [
    "game/editor/start_line.gd", "backend/deploy/stage_verifier.py",
    "game/tests/test_creator.gd", "game/tests/test_road_pieces.gd",
    "docs/schemas/creator-track-v5.schema.json", "backend/tests/fixtures/verified_oval.json",
]
NEW = [
    "game/editor/spline_road.gd", "game/editor/spline_road.gd.uid",
    "game/tests/test_spline_road.gd", "game/tests/test_spline_road.gd.uid",
    "game/tests/fixtures/spline_circuit.json", "docs/SPLINE_ROADS.md",
]

def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                          text=True, encoding="utf-8", check=True).stdout

baselines = {}
for path, markers in MARKERS.items():
    diff = git("diff", "--unified=0", "--", path)
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines(keepends=True)
    selected = []
    for hunk in re.split(r"(?=^@@ )", diff, flags=re.M)[1:]:
        changed = "\n".join(line for line in hunk.splitlines() if line.startswith(("+", "-")))
        if not any(marker in changed for marker in markers):
            continue
        match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", hunk)
        begin, count = int(match[1]), int(match[2] or 1)
        start = begin if count == 0 else begin - 1
        old = [line[1:] + "\n" for line in hunk.splitlines()[1:] if line.startswith("-")]
        added = [line[1:] + "\n" for line in hunk.splitlines()[1:] if line.startswith("+")]
        assert lines[start:start+count] == added, path
        selected.append((start, count, old))
    for start, count, old in reversed(selected):
        lines[start:start+count] = old
    baseline = "".join(lines)
    if path == "game/editor/road_pieces.gd":
        # This preparation already existed before the spline task.
        baseline = baseline.replace(
            "static func section_geometry(pieces: Array, index: int) -> Dictionary:\n",
            "static func section_geometry(pieces: Array, index: int, topology: Dictionary = {}) -> Dictionary:\n"
            "\tif topology.is_empty(): topology = prepare_endpoints(pieces)\n",
        )
    baselines[path] = baseline
for path in CLEAN:
    baselines[path] = git("show", "HEAD:" + path)
for path in NEW:
    baselines[path] = ""
for path in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    current = (ROOT / path).read_text(encoding="utf-8")
    paragraphs = current.split("\n\n", 1)
    assert "docs/SPLINE_ROADS.md" in paragraphs[0]
    baselines[path] = paragraphs[1]

patch = []
hashes = {}
for path, before in baselines.items():
    after = (ROOT / path).read_text(encoding="utf-8")
    snapshot = OUT / "baseline" / path
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_text(before, encoding="utf-8")
    patch.append("diff --git a/" + path + " b/" + path + "\n")
    if not before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                    fromfile="a/"+path if before else "/dev/null", tofile="b/"+path):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    hashes[path] = {"baseline_sha256": hashlib.sha256(before.encode()).hexdigest(),
                    "final_sha256": hashlib.sha256(after.encode()).hexdigest()}
(OUT / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-hashes.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")
print("SCOPED_CHECKPOINT", len(baselines), "files; Git index unchanged")
