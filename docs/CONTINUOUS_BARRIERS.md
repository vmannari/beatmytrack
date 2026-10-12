# Continuous barrier placement — 2026-10-07

Follow-up: the owner's steep spline screenshot exposed a remaining folded inside offset. [The spline correction](SPLINE_BARRIERS.md) replaces that offset with the exposed expanded-sweep perimeter; final spline 6,656 checks and original barrier 7,715 checks pass. Re-place existing crossed runs to regenerate them.

Requirements: **T01–T04, R01, V03/V05, Q01**. Owner request: fence/barrier placement modes should produce smooth continuous runs along roads.

Road edge, Line and Curve now fit concrete barriers, wooden fences, guardrails and wire fences between shared endpoints. Straight runs fit their chosen ends; curved runs use shorter chords with at most 6 cm path deviation at 1x size. Free Curve gestures receive two smoothing passes while retaining their endpoints. Road-edge offsets average adjoining road normals instead of stepping between tangents. Both road sides, reversed placement and the selected size preset work. Width/height remain consistent as section length varies. Endpoint posts cover rail joins.

Previously, Road edge stamped complete 6 m pieces every 6.2 m and used the tangent at each stamp. Free Line/Curve stamped full-size pieces at path midpoints. Neither method made adjoining endpoints coincide; runs also ignored size presets.

## Changed files and contract

- `game/editor/object_runs.gd` (+ `.uid`): shared deterministic section fitting and curve smoothing.
- `game/editor/road_pieces.gd`: continuous road-edge offset and selected scale.
- `game/editor/editor_canvas.gd`: shared free-run builder; Road edge forwards scale.
- `game/editor/creator_objects.gd`: fitted collision footprints, bounds and selection outlines.
- `game/editor/track_document.gd`, `docs/schemas/creator-track-v5.schema.json`: optional physical `length` of 0.01–18 m, restricted to the four fixed barrier types.
- `game/track/creator_prop_visual.gd`, `game/track/native_track_visual.gd`: shared fence/barrier meshes using fitted length without shrinking thickness/height.
- `game/tests/test_continuous_barriers.gd` (+ `.uid`): geometry, saved-contract, native collision, actual editor gesture, save and undo regressions/captures.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and task evidence.

This additive optional field remains in creator-track-v5. Existing documents without `length` retain their compiler-22 behavior and content hashes; the retained creator goldens pass unchanged. New documents include length in their immutable hash. Older validators reject the unknown field: publishing new fitted runs requires the matching backend verifier source update. No player files, published revisions or scores were rewritten; physics/rules/compiler identities and gameplay camera are unchanged.

Tyres retain physical size and existing free-line arrangement; cones remain spaced objects. The 96-object cap remains: a capped run creates a continuous prefix. Sections remain individually selectable/movable/deletable. Existing saved runs are not automatically reshaped.

## Actual verification

Pinned `4.7.2.stable.official.ed1daf0bf`, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Tests use process-local `APPDATA=build/barrier-test-user`; the app fixture injects separate records/library/cloud roots. Windows certificate-store access needed approved elevated execution. No external service writes or sign-in.

| Actual arguments | Result |
| --- | --- |
| `-Action Import` | Completed after correcting a new mesh parameter/local-name collision. |
| `-Action TestScript -ScriptPath res://tests/test_continuous_barriers.gd -Graphical` | **7,374 checks, zero failures**, real gestures, native collision, save/reload and whole-run undo/redo. |
| Final `-Action TestScript -ScriptPath res://tests/test_continuous_barriers.gd` / `-Graphical` | **7,715 / 7,719 checks, zero failures**, including the dense-curve probe and exported native fixture. 512-point curve, 49 sections: **3.568 ms** headless / **4.444 ms** graphical on this desktop. |
| `-Action TestPieces` | **377 checks, zero failures**; retained golden hash and two five-lap canonical drives with zero contacts. |
| `-Action TestCreator` | **113 checks, zero failures**; five biome hashes and historical three-lap diagnostic drives. |
| `-Action TestWorkflow` | **252 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_editor_review_fixes.gd` | **51 checks, zero failures**. |
| `-Action TestRefinement` | **32 checks, zero failures**; existing 27-instance shutdown warning. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **338 scripts, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_object_browser.gd` | **67 checks, zero failures**; shared object meshes/palette/placement choices. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/continuous-barriers-2026-10-07/native_check.py` | **5 checks, zero failures**; actual local backend native validation twice, 31 sections, identical `track_content_hash=6ce0a3693f95bfa0fd960e788249edab6abaddaba85d8ab7f6cd344a04cdf4e8`. |
| `git diff --check --` (seven modified runtime/schema files) | Exit 0, no whitespace errors; existing Git CRLF normalization notices. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/continuous-barriers-2026-10-07/review_checkpoint.py` | Task-only patch and 16 source hashes retained; original shared index untouched. |

Initial capture fixtures had an invalid theme, a StringName start-line key, wrong world/screen input coordinates and an incomplete wait for latest scenery. Those fixture issues were corrected; final inspected captures show actual fences on a valid document. Baseline capture loads the archived original RoadPieces placement source in the test harness and commits its output through the editor. Updated captures use real two-tap/drag placement.

After adding a dense-curve timing probe, a headless rerun stopped on unrelated concurrent soundtrack work: `res://assets/audio/locked_in_v1/menu_theme.ogg` was referenced before the asset existed. An isolated snapshot with the old soundtrack source also failed because the concurrently updated Game now used a newer music method signature. The isolated snapshot was safely removed and its failed-import log retained. Once the concurrent asset was available, the final **7,715 / 7,719** checks passed in the actual current workspace. This task did not edit soundtrack files. Native fixture attempts first used an unsuitable layout-only track and then the wrong result-key name; the final probe uses original connected roads, a placed start line and the documented `track_content_hash`. No failing invariant was weakened.

## Evidence and remaining acceptance

Actual inspected 1280×720 editor output:

- [Original road-edge fence](evidence/continuous-barriers-2026-10-07/before/road-edge-fence.png).
- [Continuous road-edge fence](evidence/continuous-barriers-2026-10-07/after/road-edge-fence.png).
- [Continuous bend](evidence/continuous-barriers-2026-10-07/after/road-edge-fence-bend.png).
- [Line](evidence/continuous-barriers-2026-10-07/after/line-fence.png) and [smoothed Curve](evidence/continuous-barriers-2026-10-07/after/curve-fence.png).

Pre-edit sources, actual logs, task-only review patch and source hashes are retained under `docs/evidence/continuous-barriers-2026-10-07/`. The review checkpoint is against task-start sources; unrelated workspace edits remain intact.

Owner visual acceptance and physical Android finger feel/performance remain. **No phone/device test, attachment check, Android export/install, full Validate, backend deployment or production action was performed.**
