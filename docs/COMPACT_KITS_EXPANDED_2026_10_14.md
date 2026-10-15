# Compact fitted kits: ten choices per category, 2026-10-14

CKX01–CKX05 / CKT01–CKT06 / GCS01–GCS04 / V04–V06 / G01 / R01 / Q01. The owner requests refined kits and ten options in each compact-car category. Garage → Tuning now offers **40 independently selectable choices: Original plus nine alternatives per category**, retaining all previous stable part IDs and local version-one settings. The 24 additions are original native geometry, rather than colour-only variants.

| Category | Ten choices |
|---|---|
| Hood | Original, Twin louvres, Rally scoop, Power dome, Track extractor, Raised cowl, Twin intakes, Reverse intake, Pressed ribs, Vented dome |
| Rear aero | Original, Roof lip, Ducktail, GT wing, Touring spoiler, Pedestal wing, Swan neck, Twin blade, Rally wing, Endurance wing |
| Rims | Original, Forged five, Split six, Turbine, Cross mesh, Deep dish, Rally disc, Sport six, Slim ten, Tri spoke |
| Body kits | Original, Street, Rally, Club sport, Heritage, Touring, Wide arch, Endurance, Gravel, Urban sport |

The hoods retain the exact original fender/front/cowl edges. Intake/extractor openings remove sheet geometry and have recessed interiors, side walls, rolled mouths, grille bars or raised blades; cowl/ribs/dome changes are pressed into the fitted panel. Wings have closed airfoil tips, different spans/chords/sweeps and mount profiles, actual roof saddles/seals/fasteners and tailored endplates. Swan neck uses upper clamps; Twin blade has two separate airfoils. Rims share the original tyre opening, wheel centres and articulated pivots, with open shaped spokes, stepped dish, small captive hardware, beads, hubs, drilled-disc presentation and stationary calipers. Body choices vary skirts, bumper-path valances, painted/trim arches, rocker blades, mudflaps/brackets, diffuser fins and canards.

Close-up review exposed extensions intersecting the original rolled fender beneath them. Both previous Rally/Club and new arch kits now include that exact underlying roll before adding their extension. Arch fasteners follow the corrected sheet; 48 full/simple mesh assertions check clearance above the original fender. Geometry remains cosmetic, with the original tyres and suspension/steering frames, handling, scoring and contracts.

Ten cards use a horizontal native touch/keyboard scroll row, keeping the main car pane and actions usable at 960×540, 1280×720 and 1600×720. Focus and returning to a category reveal its selected card. The actual car, paint/pattern/sticker bindings, camera, turntable, reflections and exact local dirt/wash state remain across part edits. Reset and atomic save/failure rollback keep their established behavior.

The existing fast path remains: 40 native 384×112 photographs per renderer are prepared offline; the runtime thumbnail cache still retains at most sixteen images, around 3.5 MiB of mipmapped RGBA texels. Cold category browsing creates no preview car/world. The immutable part catalog grows to **1,268 full/simple patches and caps**, independently cached by part/quality rather than combination. All source surface-array hashes match the prepared resources. Compressed meshes occupy 4,725,630 bytes; the 80 source photos occupy about 1.83 MB. Garage replaces only the selected cosmetic frames. Ordinary race assembly and the stock detailed/simpler budgets remain unchanged.

All **10,000 combinations per detail level** have exact visible-triangle bounds from the independent part contributions. The real maximum assembled model matches the computed maximum: **167,082 detailed / 64,686 simpler triangles**, below the existing 170,000 limit. Stock simpler models additionally use their existing five shadow proxies (2,220 triangles); customized simpler models retain actual fitted geometry shadows. These bounds are geometry counts, not equal GPU cost or phone frame-pacing acceptance.

The concurrently introduced prepared-car template exposed unstable internal node names during the expanded tests. A small integration fix assigns explicit sibling names before cloning/packing, preserving stored body/wheel/brake/kit paths. Offline bakers and source-equivalence checks bypass whole-car templates. Optional race ghost geometry is now prepared only for a target; the workflow fixture exercises that current path without saving a fabricated personal best.

Runtime changes: `game/vehicle/vehicle_customisation.gd`, `compact_kits.gd`, new `compact_kit_variants.gd`, the compact rollover outline in `car_visual.gd`, the small `prepared_car_cache.gd` naming fix, `game/ui/compact_kit_thumbnail.gd` and `garage_page.gd`; refreshed `game/assets/vehicles/compact_kits_v1/`. Tests/tools update the native baker, all-option touch workflow, geometry/source checks, profile and close captures; new `test_expanded_compact_catalog.gd` and `capture_compact_kit_catalog.gd` produce combination proofs and review sheets. No external model, trademark/logo, AI bitmap service, new dependency or runtime network call is introduced.

Actual pinned-engine commands use `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kit_geometry.gd -TestArgument '--parts-only' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_expanded_compact_catalog.gd -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-kits-expanded-2026-10-14/compatibility' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_customisation_speed.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_incremental_compact_kits.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_compact_kit_catalog.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_compact_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-kits-expanded-2026-10-14/close-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_customisation.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/compact-kits-expanded-2026-10-14/timings-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_car_models.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Paired renderer checks/captures use the corresponding `-RenderingMethod mobile -RenderingDriver vulkan` command and a separate evidence directory. Final outcomes: geometry/winding/panel fit **5,228**, source/combination/rolled-fender proofs **1,539**, all-choice workflow **487 + 487**, exact prepared data/retained menus **1,398 + 1,398**, incremental identity/paint/condition **322 + 322**, close/reflection-layer/rotation captures **657 + 657**, ordinary racing models **85**, and script compilation **699**; zero failures in these final runs. Reflection lifecycle/pixel results and command receipts are recorded in the delivery ledger.

Both final timing runs use the full app and the actual Garage, with isolated local records (`standalone_real_garage=false`). The optional standalone diagnostic also retains the actual Garage at app content bounds; it was added while concurrent account/startup edits interrupted the measurements. No standalone timing is presented here.

| Actual desktop dispatch | Compatibility | Mobile/Vulkan |
|---|---:|---:|
| Kit category switches, including cold pictures | 5.18–54.30 ms | 4.18–33.83 ms |
| Changed new parts across the runs | 9.62–59.43 ms | 25.61–202.36 ms |
| The final sweep of all 24 additions | 9.62–47.80 ms | 25.61–172.60 ms |

The 202 ms Mobile outlier is the first Cross mesh application. The forty-photo catalog exceeds the sixteen-image cache, so repeated traversal across every category intentionally reloads evicted photographs. This adds small bounded loading work; it does not reintroduce the earlier seconds-long whole-car preview construction. These runs are from a shared desktop host, not a paired phone performance improvement or sustained frame-pacing result. First-render values and every row are preserved in the JSON receipts.

[Hood catalog](evidence/compact-kits-expanded-2026-10-14/catalog-compatibility/hood.png), [aero catalog](evidence/compact-kits-expanded-2026-10-14/catalog-compatibility/aero.png), [rim catalog](evidence/compact-kits-expanded-2026-10-14/catalog-compatibility/rims.png), [body catalog](evidence/compact-kits-expanded-2026-10-14/catalog-compatibility/body.png). The close-view directories contain ten builds with front/rear, hood/rim/aero/body views and rotation samples on both renderers.

Initial failures remain in the command receipts: a typed conditional cap array, unstable cached articulation path, a roll fixture resetting model scale, stock-only proxy triangles in the independent-count fixture, unimported concurrent livery photos, and the old always-created ghost assertion. These were corrected with their fit, budget, shading, path and integration assertions retained. Concurrent race-loading override, track-compiler syntax and account-preload failures also interrupted late checks; those unrelated sources were repaired by their owner. The first compiler diagnostic used the wrong `track/` path, then used the actual `editor/` file. Final full-app timing and parser checks succeed after those repairs.

Reviewable task-only two-commit checkpoint: `build/compact-kits-expanded/checkpoint-repo`. `docs/evidence/compact-kits-expanded-2026-10-14/delivery.json` records source/asset hashes, actual command logs, timing rows and commit IDs; `task-only.patch` is reverse-checked against the isolated review checkout. Concurrent constructor/loading/sticker work is retained in the workspace and excluded from the task delta. The shared branch/index is not changed by this task.

AAA remains the owner's quality target. Actual-phone touch/readability, brightness, aliasing, maximum-kit frame pacing/shadows and sustained thermals require device review. No phone test, APK export/install, live/backend writes, production deployment or full physics merge regression was performed in this slice. Desktop timing is subject to shared-host activity and is not phone FPS.
