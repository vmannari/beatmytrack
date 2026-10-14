# Desert sand, low banks and localized dust

Owner request, 2026-10-12. DS01 darker sand/texture shape; DS02 low irregular sand piles; DS03 compacted road variation and longitudinal wear; DS04 road-to-bank transition; DS05 bank-to-terrain transition; DS06 directional daylight/shadows; DS07 localized dust. Preserve V02/V04/V05/G01/R01/Q01, five laps, canonical surfaces/handling/scoring, and local car condition. The later owner clarification retains the tire-mark colour exactly; `skid_trails.gd` is unchanged.

This supersedes the earlier flat-only desert shoulders and dense nine-second desert clouds. The owner explicitly says banks need not match the reference's prominence or height. Banks are original non-colliding geometry, approximately 13–26 cm high, with asymmetric eroded crowns, buried feet, smooth normals and broken runs. World-space placement varies length/width/spacing, rejects footprints on visible road polygons and structural road cells, and caps deposits at 600. The inspected saved circuit has 317 deposits, 19,020 extra opaque triangles, in the existing shoulder batch. No additional render batch or texture asset is introduced. Shader samples and geometry work increase; no unchanged-performance claim is made.

Existing original dune artwork receives modestly darker pigment, more defined ripples and stronger material relief. The road uses a darker compacted-sand pigment and bounded variations at several scales. Tangent-aligned wear continues through the decorative edge strip; granular shoulders gradually mix into the same world-space dune artwork at pile feet and outer edges. Desert has a continuous diffuse material to avoid hard lighting bands on shallow deposits. Directional daylight moves from -58 to -46 degrees pitch, with less ambient fill; warm sunlight remains. Gameplay camera, HUD and physical sizes are unchanged.

Desert wake particles last 1.4 seconds instead of nine, with smaller cards, bounded growth, lower opacity and stronger damping. Contact puffs and sand grains remain; standing still emits no desert clouds. Bridge birth-height, roof clipping and biome restoration remain. No runtime AI, external dependency, backend request or change to canonical dust-independent driving is introduced. Reference images are guidance and are not copied into shipping assets; original artwork provenance remains in the existing desert prompt documents.

Changed runtime files: `game/track/native_track_visual.gd` (presentation kit 151, build/cache integration and fringe UVs), `desert_sand_banks.gd`, `desert_road.gdshader`, `surface_detail.gdshaderinc`, `creator_road.gdshaderinc`, `track_theme.gd`, `game/vehicle/sand_dust.gd` (presentation 22). New shader/script UIDs are included. Tests: `test_desert.gd`, `test_bridge_dust.gd` and new task-owned `capture_desert_refinement.gd` (+UID). Only explicitly superseded dust/daylight assertions change; existing replay, surface and bridge protections remain.

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual action | Outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/capture_desert_refinement.gd -Graphical -TestArgument '--stage=before'` | Six baseline views, canonical cells/hash preserved, zero piles. |
| Same command with `--stage=after` | Six final Compatibility views; all 57,060 pile vertices checked for low height, buried toes and structural-road clearance; cells/hash preserved. |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--stage=mobile'` | Six desktop Mobile/Vulkan views, identical geometry and cells/hash checks. This is not a physical-phone test. |
| `TestDesert` | 88 checks, zero failures, including five-car exact replay and packed-sand/off-road behavior. |
| `TestShoulders` | Union test plus 71 visual-join and 18 internal-contour checks, zero failures. |
| `TestSoil` | 163 checks, zero failures, including tire trails. |
| `TestScript -ScriptPath res://tests/test_bridge_dust.gd -Graphical` | 121 actual GPU/lifecycle checks, zero failures after import. |
| `TestRoadCache` | 66 checks, zero failures. |
| `Import` | Pass; new scripts/shader registered. |
| `TestBiomes` | 107 checks, five failures at `New repeats required selection with fresh identity`, one for each biome. Existing editor unsaved-draft confirmation flow at `app.gd::_new_document` prevents the old fixture's immediate transition; unrelated to desert appearance. No all-suite pass is claimed; assertion and app behavior preserved. |
| `Doctor` | Matching templates/tools available; empty attached-device list. |

Initial capture needed normal Godot user-log access outside the workspace; permitted rerun succeeded. A fixture used the wrong trail property (`skid_trails` instead of `trails`), corrected before completed baseline evidence. First low-bank check caught a few structural-road vertices; placement rejection was corrected and the unchanged clearance assertion passes. Fresh presentation versions invalidate older mesh caches during revisions. Bridge/Mobile attempts encountered newly added unrelated global classes (`AudioLoop`/`PropNature`) before registration; import and reruns succeed. Historical desert capture directories and player documents/saves were not overwritten.

Evidence: [before bend](evidence/desert-refinement-2026-10-12/before/route-35.png), [final bend](evidence/desert-refinement-2026-10-12/after/route-35.png), [bank detail](evidence/desert-refinement-2026-10-12/after/bank-detail.png), [driving dust](evidence/desert-refinement-2026-10-12/after/driving-dust.png), [settled wake](evidence/desert-refinement-2026-10-12/after/settled-dust.png), and [desktop Mobile bend](evidence/desert-refinement-2026-10-12/mobile/route-35.png). Inspected on both desktop renderers; Compatibility retains the stronger golden finish while Mobile is more muted. Still captures use the normal driving camera except the explicitly diagnostic bank close-up. The moving dust probe samples the actual route without racing or saving results; initial baseline dust views used an off-road straight probe, so only static route views are exact-pose comparisons.

Task-only two-commit Git checkpoint: `build/desert_refinement/checkpoint-repo`; patch, source baselines, hashes and actual logs are under `docs/evidence/desert-refinement-2026-10-12`. Shared Git branch/index and unrelated ongoing work are preserved.

During checkpoint review, concurrent prop-art changes in later `native_track_visual.gd` functions and its later kit increment to 152 were detected. They remain in the live workspace but are excluded from the desert checkpoint, which records this task's kit 151. No prop-art change is claimed as desert work.

No phone is attached; no device rendering/performance or manual touch test was performed. No Android export/install, full Validate/physics merge, backend operation or deployment. Remaining acceptance: owner visual review of bank height/spacing and road contrast; moving-camera filtering and painted-road/junction/bridge joins on representative tracks; sustained physical-device performance. The exact reference track is not available in this fixture. Broader editor test failure remains recorded above.
