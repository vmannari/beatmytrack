# Garage customisation switching, 2026-10-13

GCS01–GCS04 / CKT01–CKT06 / LV01–LV06 / V04–V06 / G01 / R01 / Q01: the owner reports very slow customisation menu switches. The largest reproduced stall was the first Body kits category: **8.02 seconds of synchronous work**. Every cold category constructed four complete detailed cars, generated missing analytical kit meshes, batched them and rendered photographs on the menu callback.

The delivered fix loads the same native photographs prepared offline, with the same camera, lighting, pigments and mip filtering. A cold kit category creates no 3D world/car. The immutable kit patches/caps are also prepared offline and loaded on demand; all 368 surface-array hashes match the original authored data exactly. There is a fallback for missing assets. These assets add 1,722,984 bytes of compressed meshes and 705,385 bytes of source PNGs; runtime retains the existing sixteen-image cache, around 3.5 MiB of mipmapped RGBA texels, and the existing bounded catalog of full/simple kit meshes.

Patterns/Colours/Stickers now retain their native controls for the current car. Switching tabs hides/shows their content rather than recreating 24 image tiles or three full colour pickers. The workbench remains attached through Tuning/Care navigation and is replaced when the car changes. Sticker placement still has one disposable editor, clears stale control references, and presents the active controls first for focus/lookup. Selection styles refresh only when their state changes. Unchanged paint saves and unchanged fitted-part applications avoid redundant writes/model rebuilds.

Installing kits in the Garage now replaces only the changed cosmetic frame. The actual car/sprung body, original tyres, wheel-spin/steering pivots, unselected parts, paint, camera, stage and local dirty/wash state survive. Hood, rear aero/body and rim/caliper frames remain separate menu batches; the frame count stays bounded (four rotating rim frames plus four stationary brake frames). Only Garage compact models use this editable layout; ordinary race cars retain their original assembly and drawing budgets. This removes the additional full-car installation stall found in the Mobile/Vulkan probe, including a 3,784 ms first rim application that now takes about 119 ms.

Actual desktop Compatibility/RTX 3090 dispatch timings from the same isolated app runner:

| Action | Before | Final |
|---|---:|---:|
| First Tuning entry | 2,435.99 ms | 43.20 ms |
| First Rear aero category | 1,311.72 ms | 12.26 ms |
| First Rims category | 1,532.88 ms | 11.29 ms |
| First Body kits category | 8,021.07 ms | 13.80 ms |
| Repeated Patterns tab | about 107–111 ms | 1.53–2.15 ms |
| Repeated Colours tab | about 49–54 ms | 1.43–1.55 ms |
| Repeated Stickers tab | about 14–17 ms | 1.21–1.47 ms |
| Installing changed parts | about 173–241 ms | 7.59–34.59 ms |

The first Body category's first rendered frame fell from 8,059.97 to 17.87 ms. These are short desktop measurements, not phone FPS or sustained thermal results. First Colours/Sticker initialization still takes about 44–46 ms in this run. Primary layout changes between Customise and Tuning remain around 33–35 ms. Final Mobile/Vulkan installs take about 20–165 ms, with category dispatch about 2–15 ms; full-car installation before partial replacement was about 0.58–0.81 s with the 3.78 s rim outlier. There is no paired initial Mobile category baseline or phone improvement claim.

Changed runtime files: `game/ui/compact_kit_thumbnail.gd`, `garage_livery_menu.gd`, `garage_page.gd`, `livery_tile.gd`, `car_showroom.gd`; `game/vehicle/compact_kits.gd`, `car_visual.gd`, `compact_coachwork.gd`, `compact_detail.gd`, `livery_graphics.gd`, `visual_geometry.gd`. New shipping assets: `game/assets/vehicles/compact_kits_v1/`, with original provenance and geometry hashes. New export-excluded tools/checks: `game/tests/bake_compact_kit_previews.gd`, `profile_garage_customisation.gd`, `test_garage_customisation_speed.gd`, `test_incremental_compact_kits.gd` and UIDs.

Actual commands use pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_customisation.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_customisation.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/garage-customisation-speed-2026-10-13/final'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_garage_customisation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/garage-customisation-speed-2026-10-13/final-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_customisation_speed.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_customisation_speed.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_incremental_compact_kits.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_incremental_compact_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Final prepared-data/menu checks: **450 Compatibility + 450 Mobile, zero failures**. All mesh-array hashes and sixteen imported preview pixels are exact; cold previews allocate no live 3D worlds. Incremental fitted-part checks **130 + 130** retain the actual car/body/wheels, unselected parts, paint and exact dirty/wash snapshot, with the same triangles as fresh models. Existing livery/persistence/input checks **355 Compatibility + 355 Mobile**, kits **219 + 219**, reflection lifecycle/pixels **25**, and unchanged ordinary racing model checks **85** pass; all **677 scripts** compile. The delivery ledger records command receipts.

The initial retained-menu run caught hidden sticker actions and stale car-dependent roof controls; these were corrected without changing assertions. Experimental whole-car assembly/indexing caches offered little benefit and produced small paired pixel differences, so they were reverted; those failing captures remain diagnostic evidence, not shipped changes or passes. The final implementation instead replaces only changed Garage parts while preserving the original race assembly path. The bake script's initial unsupported digest call was corrected; raw-image checks now read PNG buffers without export-path warnings.

Actual paired timings, captures and source/checkpoint receipts live under `docs/evidence/garage-customisation-speed-2026-10-13/`. [Final menu](evidence/garage-customisation-speed-2026-10-13/final/final.png). A task-only two-commit review repository is at `build/garage-customisation-speed/checkpoint-repo`; the shared main branch/index and unrelated work are preserved.

No phone interaction/performance test, APK export/install, backend/live write or production deployment was performed. Phone acceptance remains outstanding. The Android export preset includes all resources and does not exclude these prepared assets, but no fresh export is claimed. Fitted triangle geometry/finishes, camera/turntable/reflections, local cosmetics and canonical handling/scoring remain. The editable Garage's stock compact uses 52 meshes versus 50, and the tested fitted configuration 62 versus 57: a small additional menu draw cost for independent updates. Gameplay drawing budgets remain unchanged.
