# Compact geometry corrections - 2026-10-10

Requirements: CG01 (rear-side/hatch joins), CG02 (rounded visible corners), CG03 (credible mirrors), CG04 (restored door seams), CG05 (curved sheet windshield); GS01-GS04/GL01-GL06/G01/V06/R01/Q01. The owner provides close rear/side images and explicitly rejects gaps, harsh corners, the mirror shape, missing door lines and spherical windshield curvature.

The previous side skin, rear face and hatch used independent outlines. One shared width/depth/radius profile now owns the lower rear shoulders, corners and face. The hatch and cabin corners continue that profile. Corner tessellation is shared across the body/hatch and cabin/roof joins, so the actual baked polygons match rather than only their analytical curves. The roof has rounded front/rear corners and meets the cabin perimeter at the same height. The body waist profile has continuous endpoint derivatives. Tail-light tiles and hatch hardware follow the revised rear skin.

Front/rear bumpers have rounded plan corners, a closed rounded cross-section and end caps. Mirrors use closed rounded housings, a thinner fore/aft profile, a small rear-facing glass insert and a capsule mount attached to the door pillar. Door gaps follow the actual skin with a small outward relief; their lower corners are rounded. They previously sat inside the updated steel surface. Saved body/accent colors, functional headlights/brake lights and wheel transforms remain unchanged.

Front/rear glazing now uses a shallow ruled sheet: 18mm curvature across the car, straight vertical generators and rounded seals. It replaces the former radial/spherical centre bulge and accompanying normal approximation. The side-window bow drops to 8mm. The glass, seal, hatch and front-pillar coordinates derive from the same cabin profile. Studio/race glass materials retain their existing isolation. Cosmetic mirror rollover support is updated to cover the new housing bounds; canonical collisions, dimensions, handling, camera, timing and verification are not changed.

Runtime loads revision2 original native geometry: **42 coachwork surfaces plus four glazing/seal surfaces, 46 resources, 581652 bytes**. Prior revision1 resources remain preserved. All baked arrays are checked exactly against editable source; actual rear/roof shared boundaries are compared in both directions within **0.2mm** in model metres. The existing all-resources export rule includes these assets. No external media service or purchased mesh/texture was added. Source/native hashes and provenance: `game/assets/vehicles/compact_coachwork_v2/manifest.json`, its PROVENANCE.md and `licenses/ASSETS.md`.

Changed files: `game/vehicle/compact_coachwork.gd`, `compact_detail.gd`, `compact_glazing.gd`, `car_visual.gd`; existing offline `game/tests/bake_compact_coachwork.gd` and `test_garage_studio.gd`; new `game/tests/test_compact_joints.gd`; revision2 native resources/manifest/provenance, license/status/plan entries, this document and the historical Garage studio follow-up link. No main app, canonical simulation, other car models or backend changes. [Task-only text and binary Git checkpoint](evidence/compact-joints-2026-10-10/scoped-change.patch) preserves earlier/concurrent workspace work.

Actual commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with normal Windows engine log/certificate access. Native Garage fixtures disable API requests and redirect records/library/cloud paths to isolated storage. No actual player/account/score writes.

| Actual command | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd` | Final **46 meshes, 581652 bytes**, offline native bake succeeds |
| `-Action TestScript -ScriptPath res://tests/test_compact_joints.gd -Graphical` | Final **368 checks, zero failures**; analytical rear/roof edges, actual baked edge vertices, straight glass generators and 16-20mm cross-car curve, preserved wheel transforms and nine native actual-app views |
| `-Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical` | Final **71 checks, zero failures**; all 46 source/bake arrays exact, finite/UV surfaces, shared production model, material/livery contracts, studio/race glass isolation, batching, six views and rotating render measurements |
| `-Action TestVehicleBatch` | **35 checks, zero failures**; all cars retain exact source/batched geometry and bounds, independent wheels and brake response. That intermediate Compact had 76160 triangles; final studio/source-parity check covers the later matching-corner tessellation |
| `-Action TestSuspension` | **59 checks, zero failures**; updated cosmetic mirror support preserves wheel/suspension/ramp/roll presentation |
| `-Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical` | **115 checks, zero failures**, saved per-car colors/picker/reset/save failure and race application |
| `-Action TestApp` | **99 checks, zero failures**, existing menus/editor/race/results/PB flow |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **467 scripts, zero failures** |
| `adb devices -l` | OnePlus Pad 2 OPD2403/f0ba474a attached; **no phone attached** |
| Scoped whitespace / reverse Git checkpoint checks | Pass |

The source/bake fixture now explicitly checks all 42 revised coachwork meshes and four glass/seal resources, rather than retaining the obsolete 14-resource count from the previous visual revision. No physical/verification requirement or failing assertion was weakened. Intermediate 36/38/42-resource bakes were superseded by the final matching-edge revision.

Final model inspection: **83712 triangles, 48 batched mesh instances, 60322 UV vertices**. Final desktop studio construction observed **187.397ms**. RTX3090/Compatibility rotating SubViewport samples: CPU median **0.521ms**, p95 **0.755ms**; GPU median **0.250ms**, p95 **0.262ms**. These are desktop observations, not device/whole-app/thermal performance claims; the denser close-up asset still needs physical-device review.

Inspected final actual app captures: [rear left](evidence/compact-joints-2026-10-10/rear-left-1280.png), [rear right](evidence/compact-joints-2026-10-10/rear-right-1280.png), [side and door lines](evidence/compact-joints-2026-10-10/side-left-1280.png), [front/windshield](evidence/compact-joints-2026-10-10/front-left-1280.png), [roof joins](evidence/compact-joints-2026-10-10/roof-1280.png), and [rear at 960](evidence/compact-joints-2026-10-10/rear-left-960.png). These use the actual shared car asset and authored default colors; no generated poster or owner data was used.

No physical-device test, Android export/install, full Validate, backend deployment or production action was performed for this task. Remaining acceptance: owner close-up silhouette/seam/mirror/windshield review and real phone/tablet performance. Restart the client to rebuild existing showroom/race instances with the revised geometry. Prior broader menu issues remain documented separately; this task does not claim to resolve them.


## Mirror proportions and marked nose corner follow-up

The owner requests50% taller/thinner mirrors and a rounded upper-front corner. [The narrow follow-up](COMPACT_MIRROR_AND_CORNER.md) changes only the mirror resources and adds six rounded nose patches. Earlier model counts and measurements above describe the previous checkpoint.
