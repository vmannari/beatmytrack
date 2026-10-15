# Compact aero silhouettes and lower rear wings, 2026-10-14

CAV01–CAV05 / CKX01–CKX05 / GCS01–GCS04 / V04–V06 / G01 / R01 / Q01. The owner rejects the similar-looking spoilers/wings and requests more variation, with some large wings farther behind the car and lower. Garage → Tuning → Rear aero now offers **13 choices**, retaining all ten previous saved IDs and adding Whale tail, Drag deck and Split wing. The other categories retain their ten choices.

The collection now spans a flush roof lip, a small fitted hatch ducktail, an upswept hatch spoiler, tall roof wings, a curved rally hoop, lower rear wings, two rear airfoils, a broad whale tail, a flat drag deck with a Gurney lip and two separated wing halves. The main differences are actual geometry, support location, height, aft position, chord/sweep, tips and endplate silhouettes. Several existing names change to describe the revised models; saved IDs/version-one local data remain valid.

| Saved ID / displayed choice | Final mounting and form |
|---|---|
| `stock` / Original | Factory hatch/roof |
| `lip` / Roof lip | Existing small flush roof edge |
| `ducktail` / Ducktail | Pressed painted hatch root with a small raised tail |
| `wing` / GT wing | Existing tall roof-mounted reference wing |
| `touring` / Hatch sweep | Low, curved painted hatch spoiler with upswept tips |
| `pedestal` / Low rear wing | Metal hatch saddles; low single blade farther aft |
| `swan` / Swan neck | Swept roof wing with upper clamps and curved necks |
| `biwing` / Rear twin blade | Two staggered rear blades on one hatch assembly |
| `rallywing` / Rally hoop | Strong curved span and wide outer roof supports |
| `endurance` / Endurance rear | Broad lower blade behind the hatch, braced mounts, machined endplates and small rear lip |
| `whale` / Whale tail | Broad painted tail with raised outer edges and an integral hatch root |
| `drag` / Drag deck | Long, flat low rear deck and upright trailing lip |
| `splitwing` / Split wing | Two swept independent blades with a real centre opening |

Large blade centres use the compact's unscaled model metres. Low rear wing is **y1.255 / z2.215**, Rear twin blade **y1.510 / z2.240** (lower element y1.325), and Endurance rear **y1.390 / z2.345**, versus the retained GT reference at roughly **y1.79 / z1.33**. They are visibly lower and farther aft in identical side-camera captures. Original body scale, tyres/wheel centres, canonical collision/handling/scoring and driving camera remain.

Rear saddles follow the actual `CompactCoachwork.rear_skin` below the hatch glazing. Curved rubber seals and metal plates have complete back/front/wall/bevel geometry and captive fasteners, with load-bearing struts/braces connecting to the blades. Separate endplate meshes have rounded machined corners and closed faces; airfoil tips are capped, including the split wing's inner ends. Integral tails use the actual rear metal root. Finite normals, clockwise shading, glass clearance, conservative roll support and exact canonical-state invariance are checked. A strict footprint check caught about 3 mm of excess endplate overhang; the contour was shortened rather than increasing the bound. Rear saddle edge-pair/manifold and solid-volume checks pass.

The main Garage keeps the actual car/body/wheel pivots, paint/patterns/stickers, camera/zoom/turntable, reflections and exact local dirt/wash state while replacing only the aero frame. The native 13-card row remains scrollable, with saved/reset/focus selection visibility and atomic reload/failure rollback. Both-renderer workflow checks exercise all 43 part choices, including actual race, optional ghost and awards construction.

Fast browsing remains based on offline actual-model photographs and immutable prepared geometry. Aero previews use a common side/rear crop showing mounting height and aft placement; main Garage/race cameras are unchanged. Contact-sheet review caught clipping on the tallest wing; the common crop was widened for all aero photos. The thumbnail cache still holds at most sixteen mipmapped textures (about 3.5 MiB of RGBA texels), and cold card creation allocates no car/world. The complete full/simple geometry catalog now has **1,244 meshes**, versus 1,268 before this pass. Compressed mesh resources total **4,817,279 bytes**; 86 source photos total **1,985,870 bytes**. The baker's `--aero-only` path regenerates this category and preserves all other part resources/photos; previous-manifest obsolete aero files are retired only by validated exact filenames within the generated mesh directory.

All **13,000 combinations per quality** retain the existing 170,000 triangle bound. Actual maximum assembled visible counts remain **167,082 detailed / 64,686 simpler** and equal the independent per-part sum. Stock detailed Compact remains 104,558 triangles / 50 meshes; simpler stock remains 39,594 visible triangles plus the original five shadow proxies / 2,220 shadow triangles. Fitted simpler models retain their actual silhouette shadows. These are geometry/draw checks, not equal raster cost or phone frame-pacing acceptance.

Final actual checks: fit/closed-saddle/glass/roll/edit retention **834 headless + 834 Mobile/Vulkan**, source geometry/winding/panel fits **5,192**, exact source/combination catalog **1,527**, all-choice local workflow **520 Compatibility + 520 Mobile**, prepared data/retained controls/cache **1,380 + 1,380**, ordinary racing models **85**, reflection lifecycle/pixels **25**, parser **714 scripts**; zero failures in these final runs. Native captures include 39 identical side/rear/mount views and one 13-choice contact sheet per renderer. The initial manifest-count fixture compared parsed floating JSON numbers with an integer dictionary; per-category numeric checks retain exact counts and fix that false failure. Source/asset hashes, successful and diagnostic command receipts, scoped checkpoint and timing rows are in the delivery ledger.

[13-choice sheet](evidence/compact-aero-variety-2026-10-14/compatibility/catalog.png), [Mobile sheet](evidence/compact-aero-variety-2026-10-14/mobile/catalog.png), [lower endurance side](evidence/compact-aero-variety-2026-10-14/compatibility/endurance-side.png), [tall GT side](evidence/compact-aero-variety-2026-10-14/compatibility/wing-side.png), [hatch mounts](evidence/compact-aero-variety-2026-10-14/compatibility/endurance-mount.png), [split wing](evidence/compact-aero-variety-2026-10-14/compatibility/splitwing-rear.png), [drag deck](evidence/compact-aero-variety-2026-10-14/compatibility/drag-rear.png).

Commands use pinned Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical -TestArgument '--aero-only' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--aero-only' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_aero_variety.gd -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_aero_variety.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14/fit-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kit_geometry.gd -TestArgument '--parts-only'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_expanded_compact_catalog.gd -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14/workflow-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_customisation_speed.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_compact_aero_variety.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14/compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_customisation.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14/timings-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_car_models.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-aero-variety-2026-10-14/reflections'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

The paired workflow/asset/capture/timing commands use `-RenderingMethod mobile -RenderingDriver vulkan` and separate evidence roots. In the shared desktop RTX 3090 measurements, aero category dispatch was **37.18–40.20 ms Compatibility / 30.47–30.87 ms Mobile**, and revised/new wing application **9.17–30.14 ms / 24.92–52.96 ms**. The complete rows include first-render latency. These timings used the final geometry and the earlier narrower photo crop; the final crop retains the same photo dimensions/filter/cache path. They are not phone FPS, a paired device improvement or sustained performance claims.

Changed runtime: new `game/vehicle/compact_aero.gd`; aero dispatch in `compact_kits.gd`; `vehicle_customisation.gd` IDs/names; presentation-only aero roll extents in `car_visual.gd`; native photo crop/cache version in `game/ui/compact_kit_thumbnail.gd`. The existing hood/body/rim generator is retained. Updated baker/catalog/workflow/cache/profile tools and two new aero fit/capture tools have UIDs; generated aero photos/meshes/manifest/provenance and project instructions/status are included in the scoped checkpoint. All geometry/captures are original native project work; no external asset, branded model, generated AI bitmap, runtime service or new dependency is added.

Task-only two-commit review: `build/compact-aero-variety/checkpoint-repo`; patch, hashes and actual command ledger: `docs/evidence/compact-aero-variety-2026-10-14/delivery.json`. The shared branch/index and unrelated concurrent work remain. AAA remains the owner's quality target; actual-phone brightness/aliasing/touch fit, new overhangs during driving and maximum-combination frame pacing/thermals still need device review. No phone test, APK export/install, backend/live writes, production deployment or full physics merge regression was performed in this aero task.
