# Asphalt-only rise and flicker correction — 2026-10-14

The owner reports flickering and clarifies that the asphalt must rise, while sand stays flat. This supersedes the terrain lowering and sloped shoulders in `GRASS_SLOWDOWN_ROAD_HEIGHT_2026_10_14.md`. The previously requested stronger grass resistance remains in place; this correction changes presentation and its shared support sampler, not simulation or track documents.

Requirements: ARC01 raise asphalt by 50 mm; ARC02 restore original flat loose surfaces and remove competing road/blend draws; ARC03 continuous bridge mouths and visible markings, with matching car/ghost/trail/object support; V05/G01/R01/Q01 retain geometry caches, canonical contracts and actual regression evidence.

Authored asphalt changes from its original 0.012 m surface to 0.062 m, and native asphalt from 0 to 0.050 m. Grass terrain retains its original datum (authored -0.060 m, native 0); sand shoulders return to -0.020 m, ground skirts to -0.040 m and decorative blend strips to their original flat 0.013 m. Desert compacted sand, Winter snow/ice and dirt tracks receive no asphalt rise. These existing render offsets are retained independently of the new 50 mm lift.

Ground asphalt uses one visible owner at overlaps/crossings, with the existing per-piece grain coordinates. The flat asphalt blend uses the existing shoulder clipping/tie rules. Vertical outward-facing rim faces close exposed asphalt edges in the same road draw; dedicated dry/wet shader headers cull hidden back faces while retaining the original shading include. Ground end caps are clipped at matching bridge mouths so their enlarged polygons cannot compete with the shallow ramp. Bridge decks follow the same lift, return to the original finish offset inside the span and match ground asphalt at both mouths. Bridge edge paint, approach markings and expansion joints rise with the deck; structural rails and collision/ramp geometry retain their existing dimensions.

The pure spatial support profile raises asphalt contacts only. Loose grass/sand no longer inherit a negative support height or a sloping shoulder. Existing car, ghost, contact-shadow, dust and tire paths use the shared `BridgeElevation` profile. Finish paint, kerbs, placed hazards/props and moving tires follow the same visual rise. Retained editor prop keys include the local support height; per-position tire support avoids applying a single prototype's height to all tires. Cache byte/count bounds are unchanged. The task introduced `track-kit-198` and `bridge-ramps-6` fences; the combined visual working tree is kit199 / compiler27. Verification began with the separate handbrake physics0.58; a later concurrent physics0.59 was observed after these checks and was not authored by this correction.

Actual pinned Godot 4.7.2 checks, with workspace-local APPDATA:

| Check | Result |
| --- | --- |
| Grass slowdown, actual sand/fringe vertices, bridge mouths/paint and four-biome captures | Compatibility 115/115; Mobile/Vulkan 115/115 |
| Actual Ajorata, Over and under, Star spline overlap ownership and six views each | Compatibility 63/63; Mobile/Vulkan 63/63 |
| Construction, five ordinary laps and editor gestures | 113/113; five laps, zero contacts, 819 upper / 809 lower crossing visits; replay exact |
| Contact shading / road disk cache / editor CPU-GPU road preparation | 23/23, 70/70, 407/407 |
| Prepared race worlds / prepared car resources | 85/85, 162/162 |
| Actual graphical bridge tire guards / dust-layer masks | Compatibility 8/8, 121/121 |
| Bridge contacts / personal ghosts / rewind / creator refinement | 16/16, 38/38, 61/61, 33/33 |
| Backend verifier integration | 70 passed; one existing dependency deprecation warning |
| Final whole-project script parse | 748 scripts, zero failures |

The ownership test checks actual emitted triangle intersections with a 0.0001 m² tolerance for float/geometry clipping precision. It reverses competing horizontal triangles while retaining solid rim slots, whose distinct face normals make silhouette sample ordering a separate rasterisation issue. All 18 settled Vulkan views are pixel-exact. Compatibility has 17 exact views and one shared-edge sample differing by one 8-bit colour level; its bound is one sample / one colour level. All fixed-view stability assertions pass. This is desktop renderer evidence, not physical-phone testing or a general claim about every possible track.

Initial diagnostics are retained: reversing both solid top and vertical faces exposed edge-sample competition, corrected by solid-face culling and testing horizontal ownership separately. A large-world polygon-area calculation was corrected to translate vertices before multiplication. Vulkan's initial captures also differed on unchanged scenery; the final comparison primes both native mesh resources and requires stable fixed images before swapping their draw order. The initial construction test opened Create before asynchronous covered startup completed, allowing startup navigation to remove its canvas; it now waits for the existing `startup_complete` flag, retaining all interaction assertions. Two graphical-only bridge checks were initially launched headless and waited on `frame_post_draw`; only those test processes were stopped and both checks pass in graphical mode.

Commands actually run (render method/driver as in the table):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_asphalt_surface_ownership.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_asphalt_surface_ownership.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File build/asphalt-rise-correction/run-regressions.ps1
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q
```

Graphical bridge checks and corrected construction were also rerun individually through `scripts/dev.ps1`; the regression receipt records final modes/results and retains initial failures separately. Native captures, overlap/pixel JSON, full logs, source-only checkpoint and SHA256 receipts are in `docs/evidence/asphalt-rise-correction-2026-10-14/`. Concurrent Garage, car, handbrake, grass-tire-colour and Winter work is excluded from the checkpoint. No APK, phone run or deployment was performed. Owner appearance/feel and physical-phone moving-view acceptance remain.
