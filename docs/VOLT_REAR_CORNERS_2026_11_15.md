# Volt rear corners corrected (2026-11-15)

The sharp dents above both rear wheels are removed by locally restoring the original rear skin and its normals. The door seams and handles from the previous repair remain intact. [Matched left/right corner comparison](evidence/volt-rear-corners-2026-11-15/rear-corners-comparison.png).

**VRC01 - Correct the deformation locally.** Close-up diagnosis traces the dents to the heavily reduced side skins, already present before the latest 10% iteration. The original native rear skin replaces that reduced region from local Z=1.20 m, with a short transition ending at Z=1.42 m. The leading door surface is retained. Both halves use identical join subdivisions; polygons also split at the end of the transition so no fitted triangle extends into the native corner region. All existing camera, scale and articulation settings remain.

The independent proof passes **14/0**. Original encoded door vertices are retained; sampled door geometry differs by at most 0.000031 mm from the prior model. The restored rear region differs by less than 0.00002 mm from the native source, versus 2.07/2.99 mm for the rejected reduced skins. Native rear normals remain within 0.000063 after encoding. Both sides retain one connected surface, one boundary loop, Euler characteristic one and zero nonmanifold edges. The original deformed model rejects the native-surface gate. The first candidate also exposed a 5.9-9.3 micrometre triangle-plane error across the transition endpoint; splitting those polygons fixes it without relaxing the one-micrometre gate.

**VRC02 - Preserve the door repair and other geometry.** Two new side meshes retain the protected master policy through assembly and distance selection. Two existing exact detail recipes reference these meshes; two new surface-frame recipes preserve every other member and all existing reduction rows. Fourteen contour resources receive metadata-only backing identity updates, with their GPU data unchanged. This is twenty Electric-only production resources, with no production GDScript, handling, full-quality model or other-car authoring.

The existing clearance/coverage checks are retained in a new correction fixture with the intentionally changed whole-side hashes and protected triangle total. All **7,443** checks pass; before/after seam and handle GPU streams are also exact in stock/fitted source and prepared models. The original iteration fixture remains unchanged as a historical whole-side identity control. Full-quality GPU streams and articulation remain byte-exact to the task-start prepared snapshot.

| Model | Before | Corrected |
|---|---:|---:|
| stock | 14,217 | 15,254 |
| fitted | 21,669 | 22,706 |
| full | 114,648 | 114,648 |

The correction costs **1,037 racing triangles**. Volt's corrected stock model is still 1,761 triangles (10.35%) below the 17,015 count before the previous seam-repair/reduction iteration. No additional simplification is applied to offset the repair. This prioritizes the requested appearance correction. Actual encoded buffers and surface counts are retained in [prepared measurements](evidence/volt-rear-corners-2026-11-15/prepared.json); there is no FPS or physical-device performance claim.

**VRC03 - Qualify receiving consumers and publish a checkpoint.** The actual stock/fitted prepared models are captured from the front, rear, both sides, roof/door/handle close-ups, distance and three dedicated rear-corner views. Each desktop renderer has 32 matched before/after pairs, equal root transforms, stable references and exact baseline restoration. The receiving Garage/race, all racing kit choices, icon appearance/capture/cache/cancellation and washing assertions are exercised. The complete Volt prepared resource scope is validated separately; unrelated model readiness is not inferred.

| Check | Actual result |
|---|---|
| source-models | VOLT_CORNER_TESTS 11 checks, 0 failures |
| prepared-models | VOLT_CORNER_TESTS 15 checks, 0 failures |
| door-clearance | STEP10_VOLT 7443 checks, 0 failures |
| all-kits | MODULAR_CAR_ASSETS: 966 checks, 0 failures |
| parser | PRODUCTION_PARSE 580 scripts, 0 failures |
| driving | DRIVING_TESTS: 72 checks, 0 failures |
| prepared-final | PREPARED_ASSETS 125 resources; 511 checks, 0 failures |
| native-gl_compatibility | DETAIL_NATIVE_COMPLETE 133 checks, 0 failures |
| native-mobile | DETAIL_NATIVE_COMPLETE 133 checks, 0 failures |
| app-gl_compatibility | CAR_SIMPLIFICATION_APP 8 checks, 0 failures |
| app-mobile | CAR_SIMPLIFICATION_APP 8 checks, 0 failures |
| icons-gl_compatibility | HEADER_ICON_CAPTURE: 60 checks, 0 failures |
| icons-mobile | HEADER_ICON_CAPTURE: 60 checks, 0 failures |
| wash-gl_compatibility | CAR_WASH: 316 checks, 0 failures |
| wash-mobile | CAR_WASH: 316 checks, 0 failures |

The cache rebuild and closure fence cover **19,934 live consumed inputs**. A concurrent livery update temporarily removed its catalogue and changed shared code/artwork during the first bake. That parse attempt, the stale prepared-hit control and the rejected twenty-input fence are retained; no concurrent content is reverted or provenance restamped. A second complete bake rejected a further concurrent Hover SVG change. Both quality families are actually rebuilt against the final accepted inputs. The first wash-fixture run exposed leftover Rally-specific selectors after scoping it to Volt; those selectors were corrected to exercise Volt throughout, with the failed receipt retained and every wash assertion preserved. A first desktop Mobile icon run reached its unchanged 20-second readiness deadline during the ongoing cache rebuild; that failed run is retained separately from the final receiving check. No cold-start or device icon latency claim is made. The inherited synchronous standalone Garage insertion then stalled under Vulkan (281.484-second initial stop and three diagnostic stops, all exact task-owned helper PIDs). Early window sizing and a post-race draw barrier did not resolve that legacy path. The correction fixture uses the receiving App's progressive Garage opening and cached carousel settings (`game/core/features/garage.gd`), adds an explicit readiness gate and retains every original washing assertion and pixel threshold. That old synchronous insertion path remains unqualified; no production runtime change is made for it. All diagnostic receipts and the owned-process stop receipt are retained. Final washing passes 316 checks per renderer. The cached carousel emits existing native raw-image loading warnings for concurrently generated selection portraits; the six-picture/25,592-input portrait validator passes, and those images are preserved. No export claim is made. The new header/shared picture and legacy catalogue picture are regenerated, with native imports verified. Challenger remains excluded from authoring. Other source/code/index changes are preserved.

Representative actual commands; exact engine arguments, isolated profiles, errors and timings are in per-command receipts:

```powershell
python scripts/run_volt_corners.py baseline res://tests/capture_volt_corners_baseline.gd
python scripts/run_volt_corners.py survey res://tests/survey_volt_corners.gd --headless
python scripts/run_volt_corners.py build-bounded-rear res://tests/build_volt_corners.gd --headless
python scripts/check_volt_corners_geometry.py
python scripts/run_volt_corners.py stage-repair-retry res://tests/stage_volt_corners.gd --headless
python scripts/publish_volt_corners.py
python scripts/refresh_volt_corners.py
python scripts/qualify_volt_corners.py
python scripts/artwork_volt_corners.py
python scripts/close_volt_corners.py
python scripts/checkpoint_volt_corners.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Publication bindings](evidence/volt-rear-corners-2026-11-15/publication.json), [closure](evidence/volt-rear-corners-2026-11-15/closure.json), [source patch](evidence/volt-rear-corners-2026-11-15/source.patch) and [checkpoint receipt](evidence/volt-rear-corners-2026-11-15/source-checkpoint.json) record the exact task scope. The private source-only checkpoint applies/reverses byte-for-byte without using the shared index. Derived assets require rebuilding after a reversal. Standard retention runs without a task pin. No phone/device test, export, backend request, deployment or owner-save/process action is performed. Reload and owner appearance acceptance remain.
