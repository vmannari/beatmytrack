# Open spline-to-spline joins — 2026-10-06

Owner report: connecting two splines creates a double diagonal border across the driving lane, as shown in the supplied close-up. Requirement IDs: R01, T01–T04, V03–V05, Q01, SP04–SP06; SP07 (open joined mouths with no cross-road marking/apron/kerb cap).

Joined spline edge paint and shoulders now stop treating the connection as an exposed end. The two internal cap stripes and sandy strip across the road are removed. The exterior borders remain, including curved kerbs. Both endpoint directions, reversed piece order and unequal widths are covered. Authored spline points and widths remain untouched.

## Cause and correction

The swept spline contour is clipped to a shared join plane. Insetting that **closed** contour by 0.20 m for markings also moved its closing cap 0.20 m into the road. The cap no longer lay on the plane used to recognize an internal connection, so both pieces painted it and added shoulder/fringe geometry across the lane.

`SplineBorders.keep_join_planes` restores whole inset cap edges to the original plane. It matches edges within the existing local mouth region, including asymmetric wide corners; matching only individual vertices missed a wider corner in unequal-width cases. `RoadEdges.presentation_contours` applies this only to presentation. Local cap classification recognizes fragmented edges without applying an infinite cut to a distant returning branch. Presentation normals ignore the closing edge when building roadside strips. The spline cosmetic kerb path uses the same corrected presentation contour, while ordinary road pieces retain their original normal and join treatment.

**Canonical contours/kerbs, surface cells, compiler22, content identities, physics/rules, player files and existing recordings are unchanged.** Tests compare the current physical triangles/masks against the actual task-start builder for twelve joined cases. Only **track-kit-115** advances to invalidate old baked meshes. No backend rollout is needed for this correction, and no live service was changed.

An unrelated concurrent edit left eight spaces on `game/platform/resume_credits.gd:73` inside a tab-indented block, preventing the app/editor from loading. Corrected that one line to two tabs while preserving its complete `free_rewinds` condition. This is a syntax repair only; the existing resume behavior is covered by its regression suite.

## Actual checks

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`; Windows Compatibility/OpenGL on RTX 3090.

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_spline_joins.gd -Graphical`: final **127 checks, zero failures**. Twelve cases cover straight/30°/70°/115° joins, equal/unequal widths, start-to-start, end-to-end, both reversed and piece order reversed. Every inset mouth stays on its shared plane, with no stale inward cap. Actual road-marking and apron mesh probes find **zero triangles crossing the central driving corridor**. The same probe run against the task-start renderer still reproduces the original stripe/apron. Exact original physical triangles/masks and authored coordinates/widths are retained. Real editor desktop, compact and close-up screenshots are saved and inspected.
- Initial graphical reproduction: **44 checks / 16 failures**, with cross-lane marking and apron failures for all eight initial cases. First setup attempt omitted the renderer palette and failed on its empty colour array; initialized it normally. The first whole-edge repair exposed an asymmetric cap corner; extending the complete edge fixes that case.
- The diagnostic lane probe initially used the enlarged miter span, which included legitimate exterior-edge geometry at 115° turns. It now uses the actual shared endpoint width, alongside independent checks of the **entire** cap edge/plane. The original renderer continues to fail that same corridor probe. No failing road invariant was removed.
- `... TestScript -ScriptPath res://tests/test_spline_composition.gd`: **36 headless checks, zero failures**; separate-road preservation, connected variants, crossings and actual undo/redo remain covered. Its 42-check graphical run from the preceding slice included six capture assertions.
- `... TestScript -ScriptPath res://tests/test_spline_borders.gd`: final **1,107 headless checks, zero failures**, including steep borders, holes and four exact legacy-biome renderer comparisons. An intermediate direct call to the generic normal helper changed those legacy arrays; restored the original non-spline normal path and all four assertions pass.
- `... TestShoulders`: union/triangle checks pass, **71 visual-join / 18 internal-contour checks**, zero failures.
- `... TestScript -ScriptPath res://tests/test_spline_road.gd`: **476 checks, zero failures**, including five laps / **13,517 ticks / zero contacts** and exact replay.
- `... TestRoadCache`: **66 checks, zero failures**.
- `... TestWorkflow`: **252 checks, zero failures**.
- `... TestRewind`: **57 checks, zero failures** after the indentation-only dependency repair.
- `... Import`: exit 0; new test UID registered. Final `... TestScript -ScriptPath res://tests/test_script_parse.gd`: **312 scripts, zero failures**.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -k 'standalone_verifier or real_five_lap'`: **2 passed / 61 deselected**, with unchanged compiler22 manifests, packaged spline compilation and the retained verified five-lap recording/times. Existing Starlette deprecation warning retained.

Several intermediate editor captures stopped at the existing resume-script indentation error; `CheckScript -ScriptPath res://platform/resume_credits.gd` identified the exact line, rather than treating them as successful captures. A test-only loop refactor indentation error was also corrected. No full Validate was run; older full-validation/desert-golden limits remain in the preceding slice documents.

## Files and evidence

Runtime: `game/editor/spline_borders.gd`; `game/track/road_edges.gd`, `road_kerbs.gd`, `visual_road_join.gd`, `native_track_visual.gd`; indentation-only `game/platform/resume_credits.gd`. Verification: new `game/tests/test_spline_joins.gd` and UID; `scripts/dev.ps1` adds the test to Validate. Documentation: this file, follow-up link in `docs/SPLINE_COMPOSITION_FIX.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Evidence under `docs/evidence/spline-joins-2026-10-06/`: [before](evidence/spline-joins-2026-10-06/before-captures/join-closeup.png), [after](evidence/spline-joins-2026-10-06/join-closeup.png), [desktop](evidence/spline-joins-2026-10-06/joined-1280x720.png), [compact](evidence/spline-joins-2026-10-06/joined-960x540.png), actual logs and task-start source snapshots. `python docs/evidence/spline-joins-2026-10-06/create_checkpoint.py`, `git apply --reverse --check` on its patch, and scoped `git diff --check` each exit 0. The source-only review checkpoint uses the scoped patch and normalized hashes, preserving concurrent changes and leaving the Git index untouched. Open-road fixture issue badges still represent unconnected lap endpoints, not a failed seam repair. The owner image is diagnostic reference, not a shipping asset.

No phone attachment check, Android export/install or physical-device test was performed. Owner acceptance on the reported map and phone performance remain outstanding. No backend/cloud/NAS deployment, live document/record rewrite or new dependency was performed.
