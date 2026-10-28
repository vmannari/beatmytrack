# Electric continuous convex hood - 2026-10-27

The owner identifies a hood that drops from the cowl and then flattens toward the nose. The requested shape is a mainly convex bonnet. This pass corrects the actual prepared surface while retaining the lower corners, inward panel taper, fitted lights, physical car configuration and original finishes.

[Open the matched before/after viewer](evidence/electric-convex-hood-2026-10-27/before-after.html). Side view is selected first; the other angles and both detail levels/renderers are available.

## Requirements and construction

- ECV01: A continuous convex main panel, with forward slope increasing toward the nose and no flat shelf.
- ECV02: Blend the convex panel across the hood into the low fenders, retaining existing taper, crown, symmetry, seam and no-S-bend bounds.
- ECV03 / Q01: Current prepared geometry, shadows, Garage template and electric photos; native before/after and actual Garage/race evidence; one scoped Git checkpoint.
- R01: Preserve canonical simulation/configuration, collision/wheel positions, input/camera, rear/cabin form, materials, Garage lighting/reflections, economy/saves and concurrent work.

The previous spatial smoothstep drop changed the hood's slope distribution: it descended quickly behind the nose and flattened farther forward. The new loft keeps the centre Bezier's original longitudinal controls and lowers only its first two height controls. Its front and rear endpoint tangents remain, while its control-polygon grades decrease smoothly toward the cowl. The correction is spread across the upper panel and vanishes into the low fenders. A 1.5 mm C2 fairing carries that loft through the tapered leading corners.

The upper correction is restricted to painted front surfaces above the protected wheel openings. The analytic deformation Jacobian transports normals, and width/upper-surface queries use the same mapped frame as the prepared mesh. Fitted lights and the original wheel/tub protection remain. Mesh construction is offline/prepared; there is no per-frame vertex deformation.

## Verification and retained findings

The new regression cuts actual prepared triangles at fixed X positions, samples 40 mm longitudinal runs in model coordinates (35.2 mm at the existing physical scale) and measures the whole panel's slope reversal. This catches a shelf that the older per-20-mm local reversal limit allowed. It also requires at least 80% convex runs, a forward grade at least two degrees above the rear grade and no nearly horizontal main-panel shelf. The exact task-start model fails 18 of the first 30 checks; expanded outboard coverage fails 24 of 40. The original results remain.

The first narrow correction passes main-panel convexity but fails the existing transverse crown checks. Broadening it retains those original bounds. The next draft passes the original hood, nose and fairing gates but expanded outboard coverage identifies a small leading-panel slope reversal. Its source, measurements and native views are retained before the continuous leading fairing correction. No original shape threshold is removed or relaxed.

Final command outcomes, geometry/source/asset hashes, measured sections and remaining acceptance are recorded in [report.json](evidence/electric-convex-hood-2026-10-27/report.json). Capture saves, construction assertions and visual review are recorded separately.

| Completed check | Outcome |
| --- | --- |
| Whole-panel convexity, full/simple | 40 checks, zero failures; task-start 40/24 |
| Original nose / fairing / hood | 22 / 28 / 28 checks, zero failures |
| Lower corners / tapered bonnet / surface joins | 30 / 34 / 34 checks, zero failures |
| Whole-car construction / rounded front | 54 / 8 checks, zero failures |
| Native model, Compatibility and desktop Mobile | 34 checks each, zero failures |
| Original quality fixture, both renderers | 60 checks each, zero failures |
| Actual Garage and race, both renderers | 70 checks each, zero failures |
| Electric racing representation | 23 checks, zero failures |
| Project parser | 1346 scripts, zero failures |
| Matched final native views | 22 per renderer, zero save failures |

Across fixed-X sections at 0, 0.30, 0.50 and 0.60 model metres, at least 92.3% of the sampled runs bend convexly. The centre's forward grade is 7.56 degrees versus 4.35 degrees near the cowl; the outer sampled strip is 8.64 versus 2.98 degrees. These are whole-panel measurements, not just adjacent-vertex limits. The original transverse crown, panel taper and low-corner thresholds remain unchanged.

Visible geometry stays at 158270 triangles full and 78940 simple, within the existing 170000 cap. Five simplified shadow meshes total 7694 triangles. The final loft raises the outer brow by about 2.35 mm in model coordinates relative to task start while retaining the low-corner gate; it does not claim an exact repeat of the previous 70.4 mm lowering. Protected wheel clearance stays 33 mm in model coordinates (29.0 mm at the existing physical scale).

The v13 bake contains 864 prepared resources with the current coachwork and assembly hashes. All 865 historical v12 files remain byte-exact. The Garage template and all 53 electric pictures are refreshed, with picture dimensions and the other cars' shadow/provenance entries retained. Prepared resource file bytes change with the versioned serialized paths; the byte audit does not claim unchanged resource files across versions.

The first import and initial App/racing/parser attempts encountered concurrently changing editor classes (`RoadPieces.stamp_materials` and `JumpProfiles`). Their logs remain alongside the successful import/class-cache refresh and reruns. No editor source was changed for this task. Desktop App logs retain frame hitches; this shape pass does not establish a frame-time or phone-performance guarantee.

## Scope and delivery

Runtime source scope is `game/vehicle/electric_coachwork.gd`; the new versioned root is `electric_coachwork_v13`. Earlier v12 resources remain. Only electric derived assets are refreshed. The isolated binary Git checkpoint is checked/applied and compared byte-for-byte, without staging, committing or resetting the shared index.

The assembly, glass shader, car configuration, simulation, camera, showroom and all original electric test fixtures match task-start snapshots. Concurrent Garage preloader and CompactDetail cache-generation changes remain in the workspace and are excluded from the checkpoint. The coachwork source SHA-256 is `4754b78451afa51ba95f4a94534bb155f6c51218815cee552d3a9beb448d2445`; source and asset inventories are adjacent to the report.

Reload/rebuild is needed in an existing editor/game. Owner appearance/motion acceptance and physical-device cost acceptance remain. No physical-device attachment check/test, APK, real authentication/purchase, owner-save/live mutation, deployment, merge or owner-process restart is performed.
