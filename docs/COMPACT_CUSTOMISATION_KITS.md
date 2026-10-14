# Compact customisation kits, 2026-10-13

The compact now has four independent cosmetic part categories in Garage → Tuning. Tapping a rendered part preview installs it immediately and saves its local ID; Reset kits restores the original geometry. The same installed car appears in the Garage carousel, ordinary races, ghosts built from that race car, and the rivalry awards car. Other cars show a concise availability state.

| Requirement | Category | Alternatives to Original |
|---|---|---|
| CKT01 | Hood | Twin louvres, Rally scoop, Power dome |
| CKT02 | Rear aero | Roof lip, Ducktail, GT wing |
| CKT03 | Rims | Forged five, Split six, Turbine |
| CKT04 | Body kits | Street, Rally, Club sport |
| CKT05 | Local selection | Independent choices, native touch/keyboard controls, immediate preview/save, reload, reset and failed-write rollback |
| CKT06 / G01 / R01 | Integration | Actual race/awards car, paint/graphics/washing, articulated wheels, unchanged canonical handling/PB keys |
| V04 / V05 / V06 / Q01 | Review | Both desktop rendering paths, three UI sizes, actual close-ups/motion, measured bounded work, isolated task checkpoint |

There are twelve alternatives and four original choices, allowing 256 combinations. No prices, ownership grants, performance tuning or online cosmetic fields are introduced.

## Fit and authored construction

`game/vehicle/compact_kits.gd` authors original geometry against the compact's actual analytical hood, roof, body-width and bumper profiles. All measurements are unscaled model metres and inherit the existing `HandlingConfig.BODY_SCALE`. The original tire radii, wheel centres, steering and suspension pivots remain exact.

Hood boundaries use the actual pressed-sheet function; vent and scoop openings remove the corresponding sheet cells, with inner walls, recessed backing and raised louvre blades. The scoop has a rolled intake edge and grille; the dome has a softly pressed raised centre and the existing accent pigment. Aero uses the hatch's roof edge; the GT wing has a solid curved airfoil, closed rounded end plates, paired pylon/saddle/gasket mounts and fasteners. Forged rims use shaped open spokes, rolled beads, recessed hubs/lugs/valves and visible drilled brake-disc detail; calipers stay on the steering pivots while rims/discs roll. Street skirts/valances follow the body and bumper paths; Rally adds fitted arch extensions and mudflaps; Club sport adds painted arches, splitter ends and diffuser fins.

Existing paint, satin alloy and matte rubber finishes remain shared and correctly bound. The concurrent patterned-livery/sticker implementation is retained: kit surfaces enter its existing opaque paint/condition flow. Saved wash voxels keep the original compact bounds rather than stretching when a wing is added. Conservative presentation-only rollover support includes the new aero/body extents; it never changes canonical state.

Prepared meshes are cached by individual part/quality, rather than player combination. The exhaustive catalog creates 368 cached meshes across full/simple detail, including closure caps. Optional simple models use fewer grid samples; customized models retain their own actual shadow geometry instead of the stock-only shadow proxies. Static parts still batch by material and moving frame. All tested combinations remain below 170,000 triangles; measured maximum is 164,398 versus 104,558 for the full original car. This is additional visual geometry, with no claim of equal raster/shadow cost.

The merged Customise sidebar moves the same preview between containers. `CarShowroom` retains its reflection views through immediate tree re-entry and disposes them after a real detach or destruction. Explicit bidirectional transfer and teardown assertions pass; the existing floor/deck pixel/lifecycle checks also pass. This resolves the exposed partial/released reflection-array error without replacing the room, pedestal or camera.

`game/ui/compact_kit_thumbnail.gd` renders the same fitted models in one-shot 384×112 previews focused on the selected part, preserves their aspect ratio, caches at most sixteen mipmapped images (about 3.5 MiB of RGBA texels), and frees the completed 3D worlds. The live Garage keeps its existing room, pedestal, camera/zoom and two bounded planar reflections.

## Files and local data

New: `vehicle/vehicle_customisation.gd`, `vehicle/compact_kits.gd`, `ui/compact_kit_thumbnail.gd` and their UIDs, plus `tests/test_compact_kits.gd`, `tests/test_compact_kit_geometry.gd`, `tests/capture_compact_kits.gd` and UIDs (paths under `game/`).

Changed: `game/vehicle/car_visual.gd`, `compact_coachwork.gd`, `compact_detail.gd`, `racing_car_models.gd`, `vehicle_weathering.gd`; `game/ui/garage_page.gd`, `car_showroom.gd`, `weekly_rivalry_page.gd`, `weekly_rivalry_finale.gd`, `rivalry_victory_car.gd`; `game/core/game.gd`, `app.gd`; `game/persistence/local_records.gd`; project instructions/status/phase log. A small explicit three-argument SHA256 overload fix in the concurrently introduced `scripts/build_identity.ps1` allowed empty-file hashing in Windows PowerShell. Generated build IDs and unrelated concurrent changes are excluded from the task checkpoint.

The optional local settings collection is `vehicle_customisation.compact = {version:1, hood:<ID>, aero:<ID>, rims:<ID>, body:<ID>}`. Strict validation rejects unknown cars/categories/IDs and extra fields; missing data yields Original. JSON numeric versions normalize back to the native version type. Existing atomic records/backup recovery and failed-save rollback are reused; paint/condition collections remain separate. Handling, collision, race tickets, verification contracts and competitive PB keys do not include these cosmetic IDs.

Provenance: all kit geometry and preview staging are original code authored for this owner's fictional compact, derived from the project's authorized native fitting profiles. No external vehicle model, brand logo, reference image, generated bitmap, runtime AI call or new dependency is used. Existing project artwork/material provenance continues to apply.

## Actual checks and captures

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`; desktop RTX 3090. Commands use the prescribed entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kit_geometry.gd -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/compact-kits-2026-10-13/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_compact_kits.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_compact_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/compact-kits-2026-10-13/close-mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_reflections.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDriving
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Final geometry checks: **2,592, zero failures**, including all 256 combinations at both detail levels, unit finite normals/clockwise triangles, exact hood edges, bounded caches/geometry, solid GT-blade volume, saved wash mapping, and full-roll floor clearance/canonical-state invariance. Actual Garage interaction/captures: **219 Compatibility + 219 Mobile/Vulkan, zero failures**; local reload/reset/failure rollback, every part tap, three sizes, paint/pattern integration, unchanged room/stage/camera, ordinary race/ghost and awards construction, bidirectional preview transfers and real teardown. Close-up/reflection/motion captures: **244 per renderer**, including 120 rotating frames each. Existing transition **23**, floor/deck reflections **25**, wash **1,383**, driving **72**, records **54**, rewind **61**, awards **1,970**, parser **649 scripts**, all pass. Doctor found no attached phone. Final command logs are recorded in the delivery ledger.

Initial runs exposed typed-array construction, pre-tree thumbnail camera initialization, numeric JSON equality, excessive small-hardware tessellation and surface winding/closure defects. These were corrected without loosening the budget or assertions. Actual close-up inspection caught the initially degenerate GT blade/end plates; final closed solids and volume checks address that defect. The first sandboxed import could not read Windows certificates; the authorized pinned import outside the sandbox passed. No clean full-Validate or physical-device pass is claimed.

[Tuning screen](evidence/compact-kits-2026-10-13/compatibility/tuning-1280.png), [Mobile screen](evidence/compact-kits-2026-10-13/mobile/tuning-1280.png), [Club front](evidence/compact-kits-2026-10-13/close-compatibility/club-front.png), [GT wing](evidence/compact-kits-2026-10-13/close-compatibility/club-aero.png), [Turbine rim](evidence/compact-kits-2026-10-13/close-compatibility/club-rim.png), [Rally scoop](evidence/compact-kits-2026-10-13/close-compatibility/rally-hood.png). The evidence directory also contains Original/Street/Rally/Club front, rear, hood, rim, aero and body views, individual UI options, three sizes, merged livery and motion samples on both renderers. Lighting may differ between renderers; no pixel-identical claim.

Aggregate desktop render work sums the main 1600×900 Garage viewport and its two 768×432 reflections over 120 rotating Club frames. The final reports are `close-compatibility/render-work.json` and `close-mobile/render-work.json`. This short shared-host measurement is not a matched stock cost comparison, phone FPS, sustained thermal test or performance acceptance.

Reviewable task-only two-commit checkpoint: `build/compact-kits/checkpoint-final-repo`; task patch, source hashes and command receipts: `docs/evidence/compact-kits-2026-10-13/delivery.json`. The shared main branch/index and unrelated work are preserved.

Remaining acceptance: owner review of all silhouettes/materials toward the requested AAA quality target, actual-phone brightness/aliasing/touch fit, maximum-combination frame pacing/shadows and thermal performance, and broader physical-device driving/rewind/bridge clearance with the fitted presentation. No phone was attached for the final device check. No phone kit test, APK export/install, backend/live writes or production deployment was performed. Cosmetic IDs are currently local; synchronization to other devices is outside this slice.
