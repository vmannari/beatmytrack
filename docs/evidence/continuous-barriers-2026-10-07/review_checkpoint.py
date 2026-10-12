"""Retain a task-only review patch without staging unrelated workspace work."""
import difflib
import hashlib
import json
import shutil
from pathlib import Path

evidence = Path(__file__).resolve().parent
repo = evidence.parents[2]
summary = (
    "2026-10-07 T01-T04/R01/V03/V05/Q01: barrier placement fixed: Road edge/Line/Curve fit shared endpoints, "
    "smooth road normals/curve gestures and honor size while keeping rail thickness/height. Bounded optional v5 "
    "length drives both native collision and shared meshes; existing compiler22 hashes/tyre sizes retained. "
    "Final headless7715/graphical7719/native backend5, pieces377/creator113/workflow252/review51/browser67/"
    "refinement32/parser338 pass; dense512-point curve49 sections3.568/4.444ms desktop. "
    "Inspected actual before/after/bend/Line/Curve captures; task-only checkpoint preserves unrelated work. "
    "Intermediate fixture/parser/missing-concurrent-audio/native-probe failures corrected and recorded. "
    "No phone/device/attachment check/export/install/full Validate/backend deployment; matching verifier "
    "source needed for publishing new fitted fields, owner/mobile acceptance remains. "
    "Actual files/commands/logs/limits: docs/CONTINUOUS_BARRIERS.md.\n\n"
)
for name in ("DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    target = repo / name
    previous = target.read_text(encoding="utf-8-sig")
    if summary.split(":", 1)[1] not in previous:
        baseline = evidence / "before" / name
        baseline.parent.mkdir(parents=True, exist_ok=True)
        if not baseline.exists(): shutil.copyfile(target, baseline)
        target.write_text(summary + previous, encoding="utf-8")

names = [
    "game/editor/object_runs.gd", "game/editor/object_runs.gd.uid",
    "game/editor/road_pieces.gd", "game/editor/editor_canvas.gd",
    "game/editor/creator_objects.gd", "game/editor/track_document.gd",
    "game/track/creator_prop_visual.gd", "game/track/native_track_visual.gd",
    "docs/schemas/creator-track-v5.schema.json",
    "game/tests/test_continuous_barriers.gd", "game/tests/test_continuous_barriers.gd.uid",
    "docs/CONTINUOUS_BARRIERS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
    "docs/evidence/continuous-barriers-2026-10-07/native_check.py",
    "docs/evidence/continuous-barriers-2026-10-07/review_checkpoint.py",
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
explicit = {
    "TestPieces-12352", "TestCreator-24644", "TestWorkflow-10852",
    "TestScript-30748", "TestRefinement-24264", "TestScript-29996", "TestScript-16736",
    "Import-1872", "CheckScript-18736", "Import-32604",
}
for directory in (repo / "build/logs").iterdir():
    if not directory.is_dir(): continue
    for source in directory.glob("*.log"):
        contents = source.read_text(encoding="utf-8-sig", errors="replace")
        if directory.name in explicit or "CONTINUOUS_BARRIERS:" in contents or "BARRIER_DENSE_CURVE" in contents or "BackendClient" in contents or "res://tests/test_continuous_barriers.gd" in contents:
            shutil.copyfile(source, logs / f"{directory.name}-{source.name}")
shutil.copyfile(repo / "build/continuous-barriers-native-document.json", evidence / "native-document.json")
print(f"BARRIER_CHECKPOINT: {len(hashes)} source hashes; task-only patch retained")
