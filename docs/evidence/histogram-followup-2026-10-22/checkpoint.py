"""Reviewable task patch rebased around unrelated concurrent edits."""
import ast
import difflib
import hashlib
import json
import re
from pathlib import Path

root = Path.cwd()
folder = Path(__file__).parent
base_folder = folder / "task-base"
base_folder.mkdir(exist_ok=True)


def ranges(source, kind=ast.FunctionDef):
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1]+len(line))
    return {node.name:(offsets[min([node.lineno, *(d.lineno for d in node.decorator_list)])-1], offsets[node.end_lineno])
            for node in ast.parse(source).body if isinstance(node, kind)}


paths = ["backend/bmt_backend/histogram_population.py", "backend/bmt_backend/histogram_snapshots.py",
    "backend/bmt_backend/histogram_http.py", "backend/bmt_backend/runs.py", "backend/bmt_backend/worker.py",
    "backend/bmt_backend/track_models.py", "backend/bmt_backend/lap_bests.py", "backend/bmt_backend/migrations/versions/0052_histogram_demand.py",
    "backend/tests/test_compact_histograms.py", "backend/tests/test_histogram_snapshots.py",
    "backend/tests/test_histogram_followup.py", "backend/tests/test_histogram_prefix_prototype.py",
    "docs/evidence/histogram-followup-2026-10-22/prefix_prototype.py", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
chunks, fingerprints = [], {}
for name in paths:
    path = root / name
    current = path.read_text(encoding="utf-8")
    before = folder / "before" / name.replace("/", "__")
    previous = before.read_text(encoding="utf-8") if before.exists() else ""
    if name in paths[-3:]:
        pattern = (r"^## Histogram capacity follow-up override \(2026-10-22\)\n" if name == "AGENTS.md" else "^")
        previous, count = re.subn(pattern+r"2026-10-22 HFO01-HFO05/R01/Q01:[^\n]*\n\n", "", current, count=1, flags=re.MULTILINE)
        assert count == 1, name
    if name == "backend/bmt_backend/runs.py":
        old, new = ranges(previous), ranges(current)
        edits = [(new[target][0], new[target][1], previous[slice(*old[target])])
                 for target in ("histogram", "results_comparison", "comparison_own_times")]
        previous = current
        for start, end, replacement in sorted(edits, reverse=True):
            previous = previous[:start]+replacement+previous[end:]
        previous = previous.replace("APIRouter, BackgroundTasks, Depends", "APIRouter, Depends")
        previous = previous.replace(", literal, or_, select", ", select")
    if name == "backend/bmt_backend/worker.py":
        previous = current.replace("if refresh_histogram(app, active_only=True):", "if refresh_histogram(app):", 1)
        block = ('            if not stopping(app):\n'
                 '                from .histogram_snapshots import refresh_one\n'
                 '                refresh_one(app, active_only=True)\n')
        assert block in previous
        previous = previous.replace(block, "", 1)
    if name == "backend/bmt_backend/track_models.py":
        start, end = ranges(current, ast.ClassDef)["HistogramDemand"]
        while end < len(current) and current[end] == "\n":
            end += 1
        previous = current[:start]+current[end:]
    (base_folder / name.replace("/", "__")).write_text(previous, encoding="utf-8")
    chunks.extend(difflib.unified_diff(previous.splitlines(keepends=True), current.splitlines(keepends=True),
        fromfile="a/"+name if previous else "/dev/null", tofile="b/"+name))
    fingerprints[name] = {"task_base_sha256":hashlib.sha256(previous.encode()).hexdigest(),
                          "current_sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
(folder / "task-only.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
(folder / "checkpoint.json").write_text(json.dumps({"files":fingerprints,
    "note":"Function/target-block bases preserve concurrent admission, verifier, model and documentation edits. No Git reset or commit."}, indent=2))
print(json.dumps({"task_files":len(paths), "patch_bytes":(folder / "task-only.patch").stat().st_size}))
