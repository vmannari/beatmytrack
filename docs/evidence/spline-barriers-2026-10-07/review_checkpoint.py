"""Scope the tight-spline follow-up against its own task-start source."""
import difflib
import hashlib
import json
import shutil
from pathlib import Path

evidence = Path(__file__).resolve().parent
repo = evidence.parents[2]
summary = (
    "2026-10-07 T01-T04/R01/V03/V05/Q01: owner screenshot's tight-spline crossing fence reproduced "
    "(62/55 sections,1/2 crossings) and corrected with exposed clearance sweep perimeter "
    "(46/47,zero crossings/on-road samples). Retained knots/widths, inner islands, reverse/joined "
    "chains and coincident taps; bounded4-geometry/8-margin cache. Final graphical6656/old barriers7715/"
    "pieces377/workflow252/parser346 pass, original compiler22 golden/five-lap drives preserved. "
    "Cold25.644-33.465ms/warm1.741-2.911ms desktop; actual before/after inspected. "
    "Intermediate offset and diagnostic-hole failures corrected without weakened footprint checks. "
    "No player-file rewrite/phone/device/attachment check/export/install/full Validate/backend deployment; "
    "re-place old crossed runs, actual-map/mobile acceptance remains. "
    "Files/commands/logs/scoped checkpoint: docs/SPLINE_BARRIERS.md.\n\n"
)
for name in ("DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    target = repo / name
    previous = target.read_text(encoding="utf-8-sig")
    if summary not in previous:
        baseline = evidence / "before" / name
        baseline.parent.mkdir(parents=True, exist_ok=True)
        if not baseline.exists(): shutil.copyfile(target, baseline)
        target.write_text(summary + previous, encoding="utf-8")

names = [
    "game/editor/roadside_boundary.gd", "game/editor/roadside_boundary.gd.uid",
    "game/editor/road_pieces.gd", "game/tests/test_spline_barriers.gd", "game/tests/test_spline_barriers.gd.uid",
    "docs/SPLINE_BARRIERS.md", "docs/CONTINUOUS_BARRIERS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
    "docs/evidence/spline-barriers-2026-10-07/review_checkpoint.py",
]
parts = []
hashes = {}
for name in names:
    source = repo / name
    baseline = evidence / "before" / name
    old = baseline.read_text(encoding="utf-8-sig").splitlines(keepends=True) if baseline.exists() else []
    new = source.read_text(encoding="utf-8-sig").splitlines(keepends=True)
    difference = list(difflib.unified_diff(old, new, fromfile=f"a/{name}" if baseline.exists() else "/dev/null", tofile=f"b/{name}"))
    if difference:
        parts.append(f"diff --git a/{name} b/{name}\n")
        parts.extend(difference)
    hashes[name] = hashlib.sha256(source.read_bytes()).hexdigest()
(evidence / "scoped-change.patch").write_text("".join(parts), encoding="utf-8")
(evidence / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")

logs = evidence / "logs"
logs.mkdir(exist_ok=True)
markers = ("SPLINE_FENCE_BEFORE", "CONTINUOUS_BARRIERS:", "ROAD_PIECES_TESTS:", "EDITOR_WORKFLOW_TESTS:", "SCRIPT_PARSE:")
for directory in (repo / "build/logs").iterdir():
    if not directory.is_dir(): continue
    for source in directory.glob("*.log"):
        if source.stat().st_mtime < evidence.stat().st_ctime - 30: continue
        contents = source.read_text(encoding="utf-8-sig", errors="replace")
        if any(marker in contents for marker in markers) or (directory.name.startswith("Import-") and "RoadsideBoundary" in contents):
            shutil.copyfile(source, logs / f"{directory.name}-{source.name}")
print(f"SPLINE_BARRIER_CHECKPOINT: {len(hashes)} source hashes; task-only patch retained")
