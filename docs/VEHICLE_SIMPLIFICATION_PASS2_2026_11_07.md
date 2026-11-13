# Second vehicle simplification pass — 2026-11-07

The second pass keeps the approved standard models everywhere. All five vehicles gain more efficient LOD triangle ordering and substantially smaller personal-ghost meshes. The Hovercraft also gains conservative detail levels on its separate rubber skirt. The original full-detail geometry, materials, glass, articulation and half-pixel car LOD policy remain available and unchanged.

## Requirements and implementation

| ID | Delivered change | Verification |
|---|---|---|
| VSP201 | Offline `car_mesh_lods.gd` orders each existing LOD's triangles for vertex-cache reuse. | Every old LOD triangle, corner winding, geometric error and master GPU attribute/index buffer compared exactly across the 468 active prepared resources. Only triangle order changes on the existing LOD families. |
| VSP202 | Hover's separate `SportPressureSkirt` can simplify alongside the already eligible fan rotors. | Overhead, close, rear and macro comparisons of stock/fitted cars in daylight and Night on both desktop renderers. Layered hull, canopy, deck, ducts, glass and shadow-only meshes keep the prior exclusions. |
| VSP203 | `PersonalGhost` indexes equal vertices after generating the original normals. | Every expanded triangle corner retains the exact original position and normal, including order, for all five stock and fitted models. Existing four-entry/16 MiB cache bounds include index bytes; its key carries an indexed-mesh revision. Playback/state checks also pass. |
| VSP204 | Rebuild and qualify the prepared library and native appearance; retain reviewable evidence. | Source-stable complete pipeline, structural/native controls, scoped commands, captures and task-only binary/source checkpoint. |

Production edits are [car_mesh_lods.gd](../game/vehicle/car_mesh_lods.gd) and [personal_ghost.gd](../game/vehicle/personal_ghost.gd). The shared audit now accepts an explicit baseline directory; new [second-pass regression](../game/tests/test_vehicle_second_pass.gd) and [diagnostic probe](../game/tests/profile_vehicle_second_pass.gd) provide incremental controls. No runtime simplification or new setting is added.

## Measured reductions

Stock Hovercraft visible primitive counts in the same 1280×720 native scene:

| View | Previously accepted LOD | Second pass | Further reduction |
|---|---:|---:|---:|
| Overhead | 68,114 | 56,594 | 16.91% |
| Close | 68,978 | 61,298 | 11.13% |
| Tightest macro | 68,978 | 68,978 | Full detail retained |

These counts include the unchanged fixture floor. Fitted Hover also removes 11,520 primitives overhead and 7,680 in the close view. The other four vehicles retain their existing visible triangle sets; their new benefit is index reuse rather than further decimation.

A deterministic 16-entry LRU vertex-cache simulation over the first two finest existing LODs gives:

| Vehicle | Misses before → after | Fewer simulated misses |
|---|---:|---:|
| Rally / Compact | 91,380 → 67,244 | 26.4% |
| Kart | 71,253 → 51,687 | 27.5% |
| Forklift | 114,548 → 95,022 | 17.0% |
| Volt | 94,063 → 62,961 | 33.1% |
| Hovercraft rotors | 3,605 → 2,997 | 16.9% |

This is a CPU cache model, **not measured hardware vertex work, FPS or loading time**. The probe used the archived accepted assets before the new skirt LODs were baked.

Stock personal-ghost memory, including all indices:

| Vehicle | Conservative cache accounting, bytes before → after | Actual mesh buffers, bytes before → after |
|---|---:|---:|
| Rally / Compact | 7,319,520 → 2,551,704 | 6,099,600 → 1,719,780 |
| Kart | 6,278,400 → 2,143,536 | 5,232,000 → 1,437,480 |
| Forklift | 10,476,864 → 3,544,584 | 8,730,720 → 3,244,844 |
| Volt | 8,681,760 → 3,038,592 | 7,234,800 → 2,773,320 |
| Hovercraft | 5,188,320 → 1,778,856 | 4,323,600 → 1,194,140 |

The accounting reduction is 65.0–66.2%; actual buffer reduction is 61.7–72.5%. Triangle count and ordered geometry remain exact. Indexing occurs after normal generation to preserve the original shading seams. The estimate retains 24 bytes per vertex plus four bytes per index even when native compression/index width uses less.

Prepared scene files total 78,385,496 → 78,643,204 bytes: **257,708 bytes larger**. This pass reduces ghost memory and drawing work rather than package size. All 468 active scenes refresh with their dependency receipts. Four menu photographs are byte-exact; the Hover photograph refreshes with mean RGB difference 0.000670/255, maximum channel difference 15/255 and seven pixels above 8/255 in its 2048×512 image. Five-picture provenance passes against 157 current source hashes.

## Validation and controls

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, through `scripts/run_no_crash_dialog.py`. `scripts/dev.ps1` verified the entry point on the initial probe. All engine processes use task-private APPDATA/LOCALAPPDATA, disabled backend configuration and Dummy audio. Native windows are off screen. The normal Windows execution context was required after the sandbox certificate-store startup failure; no owner process/profile was used.

| Check | Actual result |
|---|---|
| Complete prepared-asset pipeline | 468 resources; 1,925 checks / 0 failures; five exact current native photographs / 157 source hashes; no source changes during or after baking |
| Exhaustive arrays, raw GPU buffers, attachments, LOD triangles and stock/fitted ghost geometry/budgets | 70,724 checks / 0 failures |
| Compatibility native | 786 checks / 0 failures; 80 body and 20 ghost comparisons |
| Desktop Mobile native | 786 checks / 1 frame-restoration failure; all appearance/geometry/count checks pass |
| Compact Mobile repeat | 161 checks / same 1 restoration failure |
| Original accepted Compact against itself, Mobile | 161 checks / same 1 restoration failure, identical metrics |
| Existing personal-ghost recording/playback/state suite | 38 checks / 0 failures |
| Existing driving suite | 72 checks / 0 failures |

The original appearance gates remain mean RGB difference below 0.25/255 and fewer than 0.5% of pixels differing by more than 8/255. Across all body comparisons, the worst mean is 0.004389/255 and the worst above-8 fraction is 0.01375%. Original-frame restoration still requires a maximum of 1/255 and was **not relaxed**. Mobile's stock Compact Night overhead frame changes 26 of 921,600 pixels by at most 2/255 on restoration; the before→candidate and before→restored metrics are identical. The old-against-old control reproduces the same failure. It remains an explicitly unpassed renderer stability check.

The initial new ghost test incorrectly assumed native pixel identity would follow exact indexed geometry. Compatibility instead showed up to 4/255 channel differences despite exact expanded corners. A positive control adds a sequential index buffer to the **identical raw GPU vertex/normal streams**, without merging or re-encoding any vertex; it reproduces these tiny indexed-draw differences. Final tests keep exact ordered positions/normals and the established appearance gates, and additionally bound candidate maximum error by that sequential-index control plus the existing one-byte rendering allowance. Ghost native images are therefore visually qualified, **not claimed pixel-identical**. Compatibility's worst ghost mean difference is below 0.000575/255 with no pixels above 8/255; Mobile ghosts are pixel-identical in the recorded final cases. Initial failures and controls are retained.

Primary native runs produce 560 PNGs. [Hover close and macro comparison](evidence/vehicle-simplification-pass2-2026-11-07/hover-comparison.png) was inspected for skirt shape, seams and layered-surface speckles. Full native frames, restoration images, raw reports, original sources/assets and initial diagnostics are in [the evidence directory](evidence/vehicle-simplification-pass2-2026-11-07/). [summary.json](evidence/vehicle-simplification-pass2-2026-11-07/summary.json) contains the measurements without rounded prose values.

## Commands and retained findings

The task runner records exact executable arguments, owned PIDs, duration and exit codes under [commands](evidence/vehicle-simplification-pass2-2026-11-07/commands/). The runner itself is `build/vehicle-simplification-pass2-2026-11-07/run.py`. Actual invocations included:

```powershell
python build/vehicle-simplification-pass2-2026-11-07/run.py probe res://tests/profile_vehicle_second_pass.gd --entry
python build/vehicle-simplification-pass2-2026-11-07/run.py assets res://tests/check_prepared_assets.gd --pipeline --timeout 1800
python build/vehicle-simplification-pass2-2026-11-07/run.py structural-final res://tests/test_vehicle_second_pass.gd
python build/vehicle-simplification-pass2-2026-11-07/run.py final-gl res://tests/test_vehicle_second_pass.gd --renderer gl_compatibility --timeout 600 -- --output=res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/final-gl
python build/vehicle-simplification-pass2-2026-11-07/run.py final-mobile res://tests/test_vehicle_second_pass.gd --renderer mobile --timeout 600 -- --output=res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/final-mobile
python build/vehicle-simplification-pass2-2026-11-07/run.py mobile-repeat res://tests/test_vehicle_second_pass.gd --renderer mobile --timeout 600 -- --vehicle=compact --output=res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/mobile-repeat
python build/vehicle-simplification-pass2-2026-11-07/run.py mobile-accepted-control res://tests/test_vehicle_second_pass.gd --renderer mobile --timeout 600 -- --vehicle=compact --accepted-control --output=res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/mobile-accepted-control
python build/vehicle-simplification-pass2-2026-11-07/run.py ghosts res://tests/test_personal_ghosts.gd
python build/vehicle-simplification-pass2-2026-11-07/run.py driving res://tests/test_driving.gd
```

The first probe assumed the wrong internal LOD serialization; the pinned engine uses alternating edge/index-array values. Its failed log remains alongside the corrected `probe-final` result. The initial structural audit's 368 failures were autogenerated ancestor Node3D names; normalization now applies only to engine-generated numeric names and compares their exact type/sibling position. Authored names, transformations, topology and buffer assertions remain strict. The initial ghost pixel-identity failures and native Mobile restoration failures are preserved, with no failed production geometry or established appearance assertion discarded.

## Checkpoint and limits

[task.patch](evidence/vehicle-simplification-pass2-2026-11-07/task.patch) is an isolated task-only source/binary checkpoint, with forward/reverse application and byte checks in [checkpoint-receipt.json](evidence/vehicle-simplification-pass2-2026-11-07/checkpoint-receipt.json). It includes the two production edits, audit/probe fixtures, changed prepared scenes/photograph/provenance and scoped documentation/evidence. Concurrent Kart handling and other work, generated build identity and the main Git index are excluded. The root index remains byte-exact to the starting SHA-256 recorded in the receipt.

No physical device query/test, APK export/install, owner-save/process change, live/backend request, backend rollout or deployment was performed. Phone FPS, thermal/memory behaviour, owner appearance acceptance and a rebuilt tablet update remain unverified. This pass makes no whole-game performance or loading-time claim.
