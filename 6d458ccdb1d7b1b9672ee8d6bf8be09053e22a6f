# Kart driver size, posture and suit revision — 2026-11-08

The owner rejects the first imported driver's posture and photographic red overalls, then explicitly asks for a larger driver. KTF01–KTF04 supersede the prior imported driver's size, pose and clothing appearance. The selected tomkart model and its attribution remain.

| Requirement | Change |
| --- | --- |
| KTF01 — seated posture | Pelvis sits farther into the original bucket. Knees rise from the near-straight 0.375-height target to 0.49; geometric joint flexion increases from about 21° to 51.36°. Torso recline changes from 16° to 27°. Helmet and upper collar are aligned separately so the head looks forward rather than reclining with the chest. Source limb seams share the same offline deformation. |
| KTF02 — match the game | The photographic suit/glove textures are removed from the production materials. Cloth uses the game's native toon diffuse and disabled specular, roughness 1.0 and zero metallic specular. Slate cloth, quiet shoulder yokes, a dark collar and charcoal boots/gloves use four flat vertex colours. No source fabric highlights, folds, text or logos are sampled into those colours. The bulky 102-triangle neck restraint is removed. Helmet graphics and their prior branding removal remain. |
| KTF03 — larger driver | Authored anatomy scale increases from 0.34 to 0.42, a 23.53% increase. Torso, helmet and limb thickness grow; arm/leg lengths are reposed to preserve the existing steering wheel, floor and pedals. Actual helmet vertex width is independently compared with the archived previous mesh. The original cockpit width/depth and floor/head-height gates remain unchanged. |
| KTF04 — complete integration | Native driver, body shadow, four modular base modes, 60 kart modules, Garage template, catalogue/news/header pictures and 49 kart livery photographs are refreshed. Credits include these modifications. No kart chassis, seat, controls, camera or canonical handling source is edited. |

The native driver now contains **1,343 triangles / seven surfaces**: all selected source geometry except the removed 102-triangle neck-restraint piece. Source UVs, positions outside the deliberate pose change and original source normals transformed through that pose remain available. The source archive still contains the complete original 1,445-triangle model. No skeleton, runtime posing or runtime media generation is introduced. The native resource shrinks from 2,837,831 to 1,324,836 bytes; this is file accounting, not a device performance claim.

Matched side-view comparison: [rejected posture](evidence/kart-driver-fit-style-2026-11-08/before-side-right.png), [revised production posture](evidence/kart-driver-fit-style-2026-11-08/frozen-results/simple-side-right-gl_compatibility.png). Also see [front](evidence/kart-driver-fit-style-2026-11-08/frozen-results/simple-front-gl_compatibility.png), [actual Garage](evidence/kart-driver-fit-style-2026-11-08/app-compatibility/garage-1280.png), and [actual race](evidence/kart-driver-fit-style-2026-11-08/app-compatibility/race.png). Owner appearance acceptance remains; structural assertions do not establish aesthetic acceptance.

## Sources and reproduction

Changed authoring/test files are `scripts/prepare_kart_driver.py`, `game/tests/bake_tomkart_driver.gd`, `game/tests/review_tomkart_driver.gd`, `game/tests/test_tomkart_driver.gd`, and `scripts/run_kart_driver_review.py`. Runtime geometry is `game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res`; unused suit/glove PNGs retire, with copies retained in the task-start archive. `game/legal/kart_driver_notices.txt` records the new adaptations, and `licenses/ASSETS.md` records their provenance. The runtime `kart_driver.gd` seat builder is unchanged in this revision.

The existing source ZIP, license and imagegen helmet-retouch output are reused from the first task. This revision changes native geometry/materials; it does not generate or repaint another bitmap. The original texture edits remain documented in [the previous implementation](KART_TOMKART_DRIVER_2026_11_08.md).

The exact pinned engine remains `4.7.2.stable.official.ed1daf0bf`. The established `scripts/dev.ps1` wrapper terminates on this machine's known certificate-store diagnostic, so the task runner checks that exact version and invokes it through the existing crash-dialog helper, with private offline APPDATA/LOCALAPPDATA and Dummy audio. The runner now detects script errors and terminates only its own child tree; the 900-second timeout also stops that owned tree. No owner process is touched.

```powershell
python scripts/prepare_kart_driver.py docs/evidence/kart-tomkart-driver-2026-11-08/source/race_car_driver_-_low_poly.zip --output build/kart-driver-fit-style-2026-11-08/candidate
python scripts/run_kart_driver_review.py candidate-bake res://tests/bake_tomkart_driver.gd --headless -- --preview
python scripts/run_kart_driver_review.py before res://tests/review_tomkart_driver.gd --rendering-method gl_compatibility -- --before
python scripts/run_kart_driver_review.py candidate res://tests/review_tomkart_driver.gd --rendering-method gl_compatibility
python scripts/run_kart_driver_review.py final-driver-bake res://tests/bake_tomkart_driver.gd --headless
python scripts/run_kart_driver_review.py direct-final res://tests/test_tomkart_driver.gd --headless
python scripts/run_kart_driver_review.py shadow-bake res://tests/bake_kart_model.gd --headless
python scripts/run_kart_driver_review.py kit-meshes res://tests/bake_kart_kits.gd --headless
powershell -NoProfile -ExecutionPolicy Bypass -Command ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/kart-driver-fit-style-2026-11-08/identity'"
python scripts/run_kart_driver_review.py kart-bases res://tests/bake_modular_car_bases.gd --headless -- --vehicle=kart
python scripts/run_kart_driver_review.py kart-kits res://tests/bake_modular_car_kits.gd --headless -- --vehicle=kart
python scripts/run_kart_driver_review.py kart-garage res://tests/bake_garage_cars.gd --headless -- --vehicle=kart
```

All actual commands, exit codes, logs and timings are retained in `docs/evidence/kart-driver-fit-style-2026-11-08/*.json` and `*.log`. The existing catalogue, news, livery, header and five-Garage-picture bakers run with their original recipes. Since livery photographs belong to the existing conservative shared dependency tree, the full 20-base / 442-module / five-Garage / header-template preparation sequence runs after those photographs. No cache guard is relaxed.

## Checks and retained findings

The direct native-mesh test passes **59/0**. The initial both-renderer cache/fit/style matrix passes **74/0 each**, including actual prepared hits in all four modes and full-detail Garage restoration. Actual App Garage/race tests pass **16/0 each desktop renderer**, driving **72/0**, and Garage washing **45/0**. The independent checks cover actual raised knee geometry, actual enlarged helmet width, finite normals, the restricted cloth palette, no cloth texture/specular highlights, steering/wheel articulation, paint isolation and all material roles. Final receipts and preserved-asset comparisons are recorded in `final-summary.json`.

Initial drafts and failed logs remain. An incorrect removal-count assertion was corrected to 1,445 − 102 = 1,343; its failed preview process alone was explicitly identified and stopped after the sandbox refused termination. The corrected baker completes normally. A first enlarged draft exceeded the unchanged 1.4 cockpit-length gate by 0.54 mm; shifting the pelvis 5 mm forward resolves it without widening the gate. The original height, width, floor, material-finiteness and motion assertions remain. Native previews additionally exposed the helmet reclining with the torso, which was corrected before applying the result. The game retains first-use native frame hitches and the existing Windows root-certificate warning; no FPS/loading/hardware-memory gain is claimed.

The original imported-driver test's 1,445-triangle/eight-textured-material assertions describe the rejected version. The revised tests explicitly require removal of the neck-restraint role and the new texture-free toon cloth instead. Earlier retired-driver and legacy Garage-cache findings remain documented in the previous task, without weakening their assertions.

Task-start files and their hashes are retained under `before/`. The source-only checkpoint compares against that task-start copy, preserving the previous uncommitted work and the main Git index. The verification receipt pins 102 vehicle/configuration source files. Owner PC reload and appearance acceptance remain. No device query/test, APK build/install, owner-save edit, owner-process restart, backend request or deployment is performed.


## Final source isolation and live-work boundary

Concurrent sixth-car work changed `vehicle_catalog.gd` and then shared car/cache helpers while final validation was running. Final live matrices retain **76 checks / 5 strict cache-hit failures each renderer**, with the exact changed source names in their diagnostics. The earlier complete **468-resource / 1,925-check / 0-failure** preflight and successful 442-module rebuild are retained as earlier receipts, not current whole-live-build acceptance. Other work's generated build identity and sources are preserved.

A separate project under `build/kart-driver-fit-style-2026-11-08/frozen` uses the already qualified simpler-model source copy, reconciled to **all 102 exact pinned source hashes** plus this task's actual adapted driver, shadow, art, legal and tests. Three differing baseline leaves are restored from byte-matching sources; the receipt lists them. Its independent Git index supports the normal build-identity recipe without touching the main index. Kart bases, all 60 kart modules and the Garage template are rebuilt there. Final frozen driver/cache/style checks pass **76/0 each desktop renderer**; frozen actual Garage/race checks pass **16/0** in Compatibility. The frozen and live driver `.res` files are byte-identical. Frozen binaries are kept isolated and are not copied over current live work. Only the captured pictures/reports are copied to `frozen-results/`.

Four unrelated Garage PNGs and four kart wheel shadows remain byte-exact to this task's start. The repeated Forklift and Volt photographs differ by three and one pixels respectively, and are retained as controls; their original PNGs are preserved. The source-only checkpoint reverse-application check and Python compilation pass. Final live export/cache readiness requires reconciling the concurrent sixth-car changes; this task does not overwrite those changes or claim a qualified Android update.
