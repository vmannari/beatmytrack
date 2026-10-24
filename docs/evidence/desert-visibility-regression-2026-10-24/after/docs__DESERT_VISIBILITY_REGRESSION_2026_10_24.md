# Desert scenery and wind visibility — 2026-10-24

Requirements: DVR01 restore missing Egyptian scenery; DVR02 make ordinary wind readable while driving; DVR03 verify the actual App's cold/cached race path; R01 canonical isolation; G01 native visual evidence; Q01 scoped checkpoint.

## Confirmed regression and repair

Desert relief subdivided the Egyptian family from 79,098 to 89,883 draw corners, leaving `spatial_object_ends` at 79,098. Subsequent spatial preparation detached that family and could fail on the invalid range, losing pyramids and other Egyptian props. The task-original valid-document control fails the exact coverage assertion (`original-headless.log`, 5 checks/1 failure).

Refresh invalidated ranges after deformation, retaining the complete ordered assembly as one draw. Defensively attach the original drawable mesh if a stale prepared packet reaches spatial splitting. Advance the prepared-world visual key to `track-kit-213-desert-prop-ranges`. Exact array comparison against the captured original deformer confirms unchanged vertices, indices and attributes. This repairs presentation metadata; it does not change authored objects or canonical geometry.

Invisible sand sources could also retain all six slots within a radial 36m lease. Retire a site only after its downwind path, lateral scatter and full billboard envelope leave the shader's visible radius. A six-slot starvation regression now checks this explicitly. Lengthen the existing feathered wisps (maximum 8.5m along wind, 3m across) and independent bursts (2.8–4.6s, bounded to fade before cycle rollover). Keep the terrain pigment hue, with muted airborne scattering calibrated per renderer. Final opacity is 0.23 Mobile/0.24 Compatibility. The same six sites, 48 quads/96 triangles, low lift and depth/roof exclusion remain.

## Actual checks

Godot 4.7.2.stable.official.ed1daf0bf, desktop NVIDIA RTX 3090. Commands and exact outcomes are in [report.json](evidence/desert-visibility-regression-2026-10-24/report.json).

| Retained log | Checks/scripts | Failures |
|---|---:|---:|
| app-headless.log | 22 | 0 |
| app-mobile.log | 28 | 0 |
| app-compatibility.log | 28 | 0 |
| wind-headless.log | 55 | 0 |
| wind-mobile.log | 68 | 0 |
| wind-compatibility.log | 68 | 0 |
| chunks-headless.log | 71 | 0 |
| egypt-headless.log | 79 | 0 |
| geometry-headless.log | 5 | 0 |
| desert-headless.log | 87 | 0 |
| biomes-headless.log | 108 | 0 |
| app-suite.log | 141 | 0 |
| parser.log | 1044 | 0 |

The new fixture enters the real App using isolated temporary records, real CPU preparation and production Game installation. It checks fresh and cached worlds, actual pyramid pixels from both road sides, shared cached mesh resources, prepared sand anchors and released loading barriers. It then advances normal seeded ambience and the ordinary camera along a scripted 50km/h route for 18 seconds. Physics/countdown stay frozen only in the owned capture fixture; this is a presentation diagnostic, not an autonomous driver or FPS benchmark.

Sand at >=1% channel contrast: Mobile 15/18 samples, peak 7620 pixels; Compatibility 16/18, peak 10104. The additional stricter >=2% check passes in 12/18 and 9/18 samples respectively. Each qualifying sample needs at least 1,000 pixels; each renderer must have at least nine qualifying samples and a 3,000-pixel peak. The original 1% checks remain. Pixel metrics establish visibility under this fixture, not owner recognition.

The earlier fixed-scenery/original-sand App capture had 10/18 samples and a 3,104-pixel peak on Mobile. Strong-opacity trials were rejected because they violated existing saturation/soft-core invariants. Retained `opacity-*`, `long-wisp-initial-*` and `mobile-saturation-initial.log` document those failures; the final source passes the original thresholds. The initial fixture lacked the offline published-track marker, so the App correctly refused to race; that was a fixture correction, not a runtime bypass. The initial document-key fixture correction is retained separately.

Both renderers preserve all 784 checked opaque roof pixels exactly, with zero bright specks. Pause, background, retry, finish, biome removal and canonical state checks pass. Exact synchronous/cooperative geometry and materials match in all five biomes. Capture logs contain expected hitch diagnostics from explicit GPU readbacks and pixel loops; they are not game frame-rate measurements.

## Review and scope

[Native preview](evidence/desert-visibility-regression-2026-10-24/preview.html) shows the restored pyramids and the exact same driving frame with sand on/off. Its motion links use actual native Game frames with the normal driving camera. No AI-generated screenshots or edited imagery are used.

Changed runtime files: `game/track/native_track_visual.gd` (cache key only), `desert_road_relief.gd` (metadata refresh), `spatial_mesh_chunks.gd` (stale-range retention), `desert_sand_wind.gd` (source leases), `desert_sand_wind.gdshader` (wisps/cadence/scattering). New regression fixture: `game/tests/test_desert_visibility_regression.gd`; existing wind fixture gains an optional evidence-output argument. Status documents and this report record the task. `checkpoint.patch` is relative to task-entry snapshots, preserving the pre-existing dirty tree; reverse application is checked against the working files. Hashes and source snapshots are retained in this evidence directory.

The repaired subdivided Egyptian family uses a complete aggregate draw when its old boundaries are no longer valid. This favours correct complete geometry; reference-device fragment/vertex cost is not measured. Sand has broader transparent coverage at the same instance/triangle budget. Owner recognition on the affected track and physical-device appearance/cost remain to be accepted. The owner has not identified the affected track/platform in this turn. No phone/tablet attachment check, physical-device test, APK/export/install, live account/backend mutation or deployment was performed. Existing owner game/editor processes were preserved. Local game restart is needed to load source changes; installed phone/tablet builds have not been updated.
