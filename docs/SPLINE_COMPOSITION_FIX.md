# Spline preservation when adding other roads — 2026-10-06

Follow-up: [open spline-to-spline joins](SPLINE_JOIN_FIX.md) removes inset cap stripes across connections in visual kit115, retaining compiler22 and canonical contacts.

Owner report: a single spline looked acceptable, but adding any other road broke it. Owner clarified that the second road can be completely separate. Requirement IDs: R01, T01–T04, V03–V05, Q01, SP04–SP05; SP06 (stable spline presentation in multi-piece documents).

The second block triggered a different kerb-rendering path: `NativeTrackVisual._build_kerbs` uses canonical kerbs for a solitary piece, then switches to `VisualRoadJoin.kerb_triangles` for multi-piece maps. That decorative helper still constructed spline kerbs from the old folded centreline offsets. A completely separate straight road changed the reproduction fixture from **3,258 clean canonical kerb triangles to 732 old decorative triangles**, losing the curved kerbs and restoring triangular slivers inside the spline. Four independent triangle/mesh/piece-order assertions reproduced the failure before fixing it; before/after real editor captures are retained.

Multi-piece rendering now uses the same clean spline segment construction, curvature classification, bounded offsets and taper as the solitary/canonical path. Other road types retain their cosmetic join fairing and short-sliver rule. Spline kerbs are not subjected to that legacy sliver rule. Masks use cleaned spline contours and respect genuine holes, so unrelated roads preserve the spline exactly and crossing roads hide only kerbs they actually cover. Legacy pieces meeting a spline consult its clean neighbour contour rather than its folded raw outline.

`RoadKerbs.creator_segments` gains an optional internal kind filter so the visual helper can reuse spline segments while retaining all other pieces for exposure/join checks. Its default construction is unchanged. Direct comparison with the task-start physical builder proves exact equality of contact triangles and exclusion masks. **Compiler22, native content identities, physics/rules, authoring schema, point widths and existing recordings are unchanged.** Only **track-kit-114** invalidates previously baked broken meshes. No matching backend rollout is needed for this presentation correction, and no live service was changed.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`; Windows desktop Compatibility/OpenGL on RTX 3090.

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_spline_composition.gd -Graphical`: final **42 checks, zero failures**. Multiple-piece output now contains the same **3,258 triangles** as contacts; a separate straight preserves every spline kerb vertex, normal and UV. Checks cover spline-first/spline-last ordering, connected straight/curve/hairpin/spline pieces, covered-kerb suppression at a real crossing, exact old/new contact triangles and masks, and actual editor placement/undo/redo at 1280×720 and 960×540. Authored spline coordinates and widths remain identical. Before the fix, the first run had **four failures** (15,226 checks included per-vertex finite assertions); these finite assertions were aggregated without changing their coverage in subsequent runs.
- `... TestScript -ScriptPath res://tests/test_spline_borders.gd`: **1,107 headless checks, zero failures**, including steep contours, smooth kerbs, hole preservation and all four legacy-biome renderer comparisons.
- `... TestScript -ScriptPath res://tests/test_spline_road.gd`: **476 checks, zero failures**; five laps, **13,517 ticks / zero contacts**, exact recorded-input replay, point editing/widths, persistence and undo/redo.
- `... TestShoulders`: union-area/triangle checks pass; **71 visual-join** and **18 internal-contour checks**, zero failures. Existing joined legacy roads and decorative sliver handling remain covered.
- `... TestPieces`: **377 checks, zero failures**, including five-lap road races and exact replay.
- `... TestRoadCache`: **66 checks, zero failures**.
- `... TestWorkflow`: **252 checks, zero failures**.
- `... Import`: exit 0 and generates the new test UID. Final `... TestScript -ScriptPath res://tests/test_script_parse.gd`: **312 scripts, zero failures**.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -k 'standalone_verifier or real_five_lap'`: **2 passed / 61 deselected**, including unchanged pinned manifests, the packaged canonical project and retained verified five-lap recordings/times. Existing Starlette deprecation warning retained.

An intermediate crossing assertion failed because its synthetic straight crossed a straight portion with no kerbs to suppress. Moving that fixture over the actual kerb-bearing bend makes the original suppression assertion pass; the assertion was retained. No full Validate, Android export/install or physical-device test was run. Older full-validation/desert-golden limitations remain documented in [SPLINE_BORDER_FIX.md](SPLINE_BORDER_FIX.md) and are not reported as fixed by this task.

## Files, evidence and acceptance

Runtime: `game/track/visual_road_join.gd`, `road_kerbs.gd`, `native_track_visual.gd` (visual version only). Verification: new `game/tests/test_spline_composition.gd` and UID; `scripts/dev.ps1` adds it to Validate. Documentation: this file, the follow-up link in `docs/SPLINE_BORDER_FIX.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Evidence under `docs/evidence/spline-composition-2026-10-06/`: [before](evidence/spline-composition-2026-10-06/before-captures/separate-road.png), [after adding a separate road](evidence/spline-composition-2026-10-06/separate-road.png), [one spline](evidence/spline-composition-2026-10-06/one-spline.png), [connected road](evidence/spline-composition-2026-10-06/connected-road.png), undo/redo and compact captures, copied command logs, task-start source snapshots and a scoped review patch. Screenshots were inspected. The remaining issue badges in these synthetic open-road fixtures indicate unconnected lap routes, independently of spline presentation.

No phone attachment check or device test was performed. Owner visual acceptance on the reported map and physical-phone performance remain outstanding. Player files, live backend/cloud data/services and existing racing contracts were not modified. Concurrent source changes are preserved outside the scoped patch.
