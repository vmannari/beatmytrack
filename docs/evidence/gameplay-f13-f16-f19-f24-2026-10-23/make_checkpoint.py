"""Recreate this task's review patch without changing Git's index."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
before = {r["path"]: r for r in json.loads((EVIDENCE / "before.json").read_text(encoding="utf-8"))}
for name, row in before.items():
    assert hashlib.sha256((EVIDENCE / "before" / name.replace("/", "__")).read_bytes()).hexdigest() == row["sha256"], name

production = [
    "game/core/game.gd", "game/core/app.gd", "game/track/native_track.gd",
    "game/vehicle/creator_queries.gd", "game/vehicle/vehicle_simulation.gd",
    "game/race/attempt_evidence.gd", "game/race/personal_ghost_run.gd",
    "game/race/lap_telemetry.gd", "game/race/rewind_history.gd", "game/race/race_incidents.gd",
    "game/backend/race_proof.gd", "game/backend/result_save_queue.gd",
    "game/diagnostics/race_hitch_monitor.gd", "game/track/native_track_visual.gd",
    "game/track/road_cache_bakes.gd", "game/race/selected_track_preparation.gd",
    "game/race/race_ground_preparation.gd", "game/editor/road_preparation.gd", "game/editor/work_job.gd",
]
tests = ["test_gameplay_f13_f16_f19_f24", "test_road_cache_final_geometry",
         "test_road_cache_f13_original_control", "test_road_build_f13_original_control",
         "test_race_results_f13_original_control"]
paths = production + ["game/tests/" + name + ".gd" for name in tests]
paths += [name + ".uid" for name in paths if name not in before and (ROOT / (name + ".uid")).exists()]
paths += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / "game/tests/fixtures/gameplay_f13_f16_f19_f24_before").iterdir()) if p.is_file()]
paths += ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
          "docs/GAMEPLAY_AUDIT_2026_10_23.md", "docs/GAMEPLAY_F13_F16_F19_F24_2026_10_23.md"]
prefixes = json.loads((EVIDENCE / "document-prefixes.json").read_text(encoding="utf-8"))
patch = []
manifest = []
for name in paths:
    path = ROOT / name
    after = path.read_text(encoding="utf-8-sig")
    old = None
    if name in prefixes:
        assert after.count(prefixes[name]) == 1, name
        old = after.replace(prefixes[name], "", 1)
    elif name in before:
        old = (EVIDENCE / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")
    if old == after:
        continue
    if old is not None:
        target = EVIDENCE / "checkpoint-before" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(old.encode("utf-8"))
    patch.append(f"diff --git a/{name} b/{name}\n")
    if old is None:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff((old or "").splitlines(True), after.splitlines(True),
                                    fromfile="a/" + name if old is not None else "/dev/null", tofile="b/" + name))
    manifest.append({"path": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "new": old is None,
                     "baseline_sha256": hashlib.sha256(old.encode()).hexdigest() if old is not None else None,
                     "baseline_scope": "current minus owned documentation prefix" if name in prefixes else "captured source" if old is not None else "new task file"})
(EVIDENCE / "task-only.patch").write_bytes("".join(patch).encode("utf-8"))
(EVIDENCE / "source-manifest.json").write_bytes((json.dumps(manifest, indent=2) + "\n").encode())
print(f"Checkpoint: {len(manifest)} files; {(EVIDENCE / 'task-only.patch').stat().st_size} bytes; {len(before)} verified backups.")
