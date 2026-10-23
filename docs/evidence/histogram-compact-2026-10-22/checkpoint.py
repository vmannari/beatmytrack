"""Build a review patch containing this task's changes, preserving concurrent work."""
import ast
import difflib
import hashlib
import json
import re
from pathlib import Path

root = Path.cwd()
folder = Path(__file__).resolve().parent
base_folder = folder / "task-base"
base_folder.mkdir(exist_ok=True)


def function_ranges(source):
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    result = {}
    for node in ast.parse(source).body:
        if isinstance(node, ast.FunctionDef):
            first = min([node.lineno, *(d.lineno for d in node.decorator_list)])
            result[node.name] = offsets[first - 1], offsets[node.end_lineno]
    return result


paths = ["backend/bmt_backend/histogram_population.py", "backend/bmt_backend/histogram_snapshots.py",
         "backend/bmt_backend/runs.py", "backend/tests/test_compact_histograms.py",
         "docs/schemas/results-comparison-v1.schema.json", "docs/schemas/time-histogram-v1.schema.json",
         "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
chunks, fingerprints = [], {}
for name in paths:
    path = root / name
    current = path.read_text(encoding="utf-8")
    original_path = folder / ("before-docs" if name in paths[-3:] else "before") / name.replace("/", "__")
    previous = original_path.read_text(encoding="utf-8") if original_path.exists() else ""
    if name in paths[-3:]:
        # Other tasks can append status entries after our initial capture too.
        # Remove only this task's exact entry from the current document.
        heading = (r"^## Compact shared histogram comparison override \(2026-10-22\)\n"
                   if name == "AGENTS.md" else "^")
        previous, count = re.subn(heading + r"2026-10-22 HCO01-HCO03/R01/Q01:[^\n]*\n\n",
                                  "", current, count=1, flags=re.MULTILINE)
        assert count == 1, name
    if name == "backend/bmt_backend/runs.py":
        # Other ongoing work changed admission elsewhere in this module. Rebase
        # the original histogram functions onto the current surrounding file.
        old_ranges, new_ranges = function_ranges(previous), function_ranges(current)
        targets = ("best_lap_times", "results_comparison", "comparison_populations",
                   "comparison_statements", "comparison_own_times", "population_comparison")
        edits = []
        for target in targets:
            start, end = new_ranges[target]
            replacement = previous[slice(*old_ranges[target])] if target in old_ranges else ""
            if target not in old_ranges:
                while end < len(current) and current[end] == "\n":
                    end += 1
            edits.append((start, end, replacement))
        previous = current
        for start, end, replacement in sorted(edits, reverse=True):
            previous = previous[:start] + replacement + previous[end:]
        previous = previous.replace("from .histogram_population import SNAPSHOT_OWN_LIMIT, HistogramPopulation",
                                    "from .histogram_population import HistogramPopulation")
    (base_folder / name.replace("/", "__")).write_text(previous, encoding="utf-8")
    chunks.extend(difflib.unified_diff(previous.splitlines(keepends=True), current.splitlines(keepends=True),
        fromfile="a/" + name if previous else "/dev/null", tofile="b/" + name))
    fingerprints[name] = {"task_base_sha256": hashlib.sha256(previous.encode()).hexdigest(),
                          "current_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
(folder / "task-only.patch").write_text("".join(chunks), encoding="utf-8")
(folder / "checkpoint.json").write_text(json.dumps({"files": fingerprints,
    "note": "runs.py task base retains concurrent admission changes; status bases retain all current concurrent entries and omit only this task's exact dated entry. No commit or other source reset performed."}, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"task_files": len(paths), "patch_bytes": (folder / "task-only.patch").stat().st_size}))
