# Ajorata missing asphalt - 2026-10-16

ARH01: repair the grass patches replacing asphalt on Ajorata. ARH02/G01/R01/Q01: preserve the authored track, canonical driving surfaces, existing asphalt height/finish, bridge ownership, camera and bounded road preparation/caches.

The original Ajorata document reproduces two triangular holes across the lower straight in native Compatibility and Mobile/Vulkan. The holes are missing rendered asphalt, with intact road markings and canonical driving surfaces. The shared convex subtraction helper chose each cutter edge's outward normal using its centroid. A nearly collinear triangle along Ajorata's road edge can round that centroid onto the wrong side of an edge. The resulting reversed clipping half-plane removes a large, unrelated part of the straight.

`game/track/shoulder_mesh.gd` now determines the cutter's orientation once from its signed area, using translated scalar products in double precision. All edges use that consistent winding, and a truly zero-area cutter leaves its source intact. The helper continues to resolve overlapping asphalt and roadside strips into one surface owner. `NativeTrackVisual.VERSION` advances from the task-start `track-kit-203` to `track-kit-204`, fencing prepared meshes, retained worlds and disk artifacts containing the old holes. No cache limit or canonical contract changes.

Runtime changes are limited to that subtraction method and the visual version. Existing Egyptian props and concurrent Winter-prop/editor/backend work are preserved. Ajorata's fixture SHA-256 remains `69e94d9cb34bb4d3277cc2ad3f2c6d1fa34d7b5834b27df412815e611cd8931a`; its current native content hash is unchanged at `abcc56697857a83aa2423f4b5e9b4c5cf2fd67514a36040cf19ae60683af65d3`. Historical Ajorata tests contain an older native-hash expectation; this task pins the actual task-start compiler result and does not alter the fixture or compiler.

`game/tests/test_ajorata_road_coverage.gd` exercises the exact captured source/cutter in `game/tests/fixtures/ajorata_clip_sliver.json`, including both cutter windings and three rotations, plus a zero-area cutter. It scans 72,300 authored road positions at 25 cm intervals separately in CPU-prepared arrays, direct native meshes and uploaded prepared meshes. It also checks the original holes explicitly and preserves exact document/cell/kerb data. Coverage uses double-precision triangle-side tests. A 0.1 mm allowance applies only to points adjacent to numerical Boolean edges; the final scan has one such sample, 0.040551 mm from the original outer edge, zero interior gaps and zero interior overlaps. This allowance does not cover visible missing road.

Actual pinned Godot `4.7.2.stable.official.ed1daf0bf` checks, using isolated workspace APPDATA profiles:

| Check | Result |
| --- | --- |
| Saved original helper against the exact new sliver regression | 14 checks, 2 expected failures; distant road disappears and area is lost |
| Ajorata exact sliver and full CPU/direct/uploaded road coverage | Headless 33/33; Compatibility 33/33; Mobile/Vulkan 33/33 |
| Existing asphalt overlap ownership | Headless 9/9 |
| Existing sand-strip/join/internal contour checks | Union area 30 m2, zero failures; joins 71/71; internal contours 18/18 |
| Existing Underpass returning bends and bridge mouths | 82/82 |
| Existing disk-road-cache serialization and fences | 70/70 |
| Existing prepared race resources | 162/162 |
| Existing editor road direct/worker/prepared/reuse checks | 407/407 |
| Whole-project parser | 798 scripts, zero failures |
| Scoped whitespace check | Pass |

Native evidence is in `docs/evidence/ajorata-road-2026-10-16/`. Compare each renderer's `before/pose-0.png` with `after/pose-0.png`; each phase also contains a full map and three other native driving poses. `game/tests/capture_ajorata_road.gd` records the capture setup. The ordinary road shader, lighting and gameplay follow camera remain unchanged. These captures demonstrate repaired asphalt; they are not whole-screen byte comparisons or phone-performance measurements.

Representative actual commands (PowerShell, repository root):

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/ajorata-road-2026-10-16/profile-tests'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_ajorata_road_coverage.gd -CommandTimeoutSeconds 240
# Native coverage: add -Graphical -RenderingMethod gl_compatibility (or mobile), with a separate profile.
# Original helper reproduction: add -TestArgument '--baseline'.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_ajorata_road.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--phase=after' -CommandTimeoutSeconds 240
```

`report.json` records the actual commands, source/artifact hashes and results; `logs/` retains initial and final attempts. `task-only.patch` is a scoped reviewable checkpoint, excluding unrelated modifications in the shared working tree. No mixed-workspace commit is made.

Initial diagnostics are retained. The first Windows shell attempt was blocked by local execution policy; subsequent commands used the established entry point with process-local execution-policy bypass. A restricted engine launch could not read the Windows certificate store; permitted native runs then completed outside that restriction. An early overlap metric used Geometry2D's near-boundary point classification and reported seven shared-edge samples as overlaps; exact double-precision side tests resolve their actual sides without increasing a tolerance. Initial raw diagnostic coverage also used that point predicate and is retained separately. Concurrent Winter work briefly introduced an unregistered `PropWinterCraft` class; a normal project import refreshed the class cache before the final checks. None of those attempts is represented as a pass.

No phone attachment check or physical-phone test was performed. No APK export/install, backend operation or deployment was performed. Owner appearance acceptance and physical-phone moving-view/performance checks remain.
