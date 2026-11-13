# Kart driver replacement â€” 2026-11-08

The owner selected tomkart's **Race Car Driver - Low Poly**, requested removal of the overalls' text, and supplied the downloaded ZIP. This supersedes the earlier code-authored driver and helmet appearance requirements for the current kart.

| Requirement | Implementation |
| --- | --- |
| KTD01 â€” use the selected model | The complete 1,445-triangle source model is posed offline for the existing kart. Its 21 mesh pieces are combined into eight material surfaces; source triangle topology and UVs are retained. The native `driver.res` requires no runtime importer, skeleton, animation, posing, network access or new dependency. |
| KTD02 â€” remove suit text | Chest and sleeve lettering and shoulder logos are removed. Glove and helmet brand marks are also removed. Red/white fabric, seams, boots and the original helmet graphics remain. Built-in imagegen provides the retouching; only the small reviewed removal regions are composited over the original texture atlases. Original dimensions and pixels outside those regions remain unchanged. |
| KTD03 â€” consistent production appearance | Both model quality tiers, fixed/editable prepared bases, the Garage template, body shadow, catalogue/header/news images and all 49 kart livery photographs use the replacement. Existing seat geometry, seat mounts, steering wheel, pedals, chassis and wheels remain. Obsolete procedural suit authoring helpers are removed from the runtime driver script. |
| KTD04 â€” credits and behavior | CC BY 4.0 attribution, source links and modification notes ship in `game/legal/kart_driver_notices.txt`, accessible through Settings â†’ Licences â†’ Kart driver. Canonical physics and camera sources are not edited by this task. |

Native views: [front](evidence/kart-tomkart-driver-2026-11-08/full-front-gl_compatibility.png), [side](evidence/kart-tomkart-driver-2026-11-08/full-side-gl_compatibility.png), [reduced overhead](evidence/kart-tomkart-driver-2026-11-08/simple-overhead-gl_compatibility.png), [actual Garage](evidence/kart-tomkart-driver-2026-11-08/app-compatibility/garage-1280.png), [actual race](evidence/kart-tomkart-driver-2026-11-08/app-compatibility/race.png), and [creator credit](evidence/kart-tomkart-driver-2026-11-08/licences-final/kart-driver.png). Desktop Mobile means the Windows Vulkan renderer, not a tablet test.

Source and license: [model page](https://sketchfab.com/3d-models/race-car-driver-low-poly-0fedfae53537473ba2ee3d9b722e0c66), [tomkart](https://sketchfab.com/tomkart), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The owner-supplied archive is retained under `docs/evidence/kart-tomkart-driver-2026-11-08/source/`. The original asset license is inside that archive. The adapted mesh and three final texture atlases are under `game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/`. Embedded native textures are checked against the reviewed PNGs. Imagegen edit inputs, output atlases, prompt specifications and compositing details are recorded in [imagegen/prompts.json](evidence/kart-tomkart-driver-2026-11-08/imagegen/prompts.json). No model generation service was used.

The offline pose uses shared deformation at the original shoulders, elbows, wrists, hips, knees and ankles. This avoids the disconnected cuffs seen in the first rigid-piece draft. The adapted driver follows the existing sprung body and remains independent of car paint. Head height, cockpit width/depth, finite vertices/normals, all eight materials, all four prepared quality/editability combinations, actual cache hits and the absence of the original driver are checked. The supplied source has no skeleton; steering animation of the driver's hands is not added.

## Commands and reproducibility

All commands run from the repository root. `scripts/dev.ps1` is the initial entry point and enforces the pinned `4.7.2.stable.official.ed1daf0bf` engine. Its native wrapper terminates on this machine's existing Windows root-certificate-store diagnostic. The task runner therefore checks the exact pinned version and invokes that same engine directly through the existing crash-dialog helper. It uses a private offline APPDATA/LOCALAPPDATA profile under `build/kart-driver-tomkart-2026-11-08/profile`, Dummy audio and bounded child processes. Every actual invocation has a JSON receipt and complete log under the evidence directory.

```powershell
python scripts/prepare_kart_driver.py docs/evidence/kart-tomkart-driver-2026-11-08/source/race_car_driver_-_low_poly.zip --output build/kart-driver-tomkart-2026-11-08/candidate
python scripts/run_kart_driver_review.py native-bake res://tests/bake_tomkart_driver.gd --headless
python scripts/run_kart_driver_review.py kart-mesh-bake res://tests/bake_kart_model.gd --headless
python scripts/run_kart_driver_review.py kart-kit-mesh-bake res://tests/bake_kart_kits.gd --headless
powershell -NoProfile -ExecutionPolicy Bypass -Command ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/kart-driver-tomkart-2026-11-08/identity'"
python scripts/run_kart_driver_review.py bases res://tests/bake_modular_car_bases.gd --headless -- --vehicle=kart
python scripts/run_kart_driver_review.py kits res://tests/bake_modular_car_kits.gd --headless -- --vehicle=kart
python scripts/run_kart_driver_review.py garage-base res://tests/bake_garage_cars.gd --headless -- --vehicle=kart
python scripts/run_kart_driver_review.py compatibility res://tests/test_tomkart_driver.gd --rendering-method gl_compatibility -- --prepared
python scripts/run_kart_driver_review.py mobile res://tests/test_tomkart_driver.gd --rendering-method mobile -- --prepared
python scripts/run_kart_driver_review.py ui-compatibility res://tests/test_kart_refinement_ui.gd --rendering-method gl_compatibility -- --evidence-root=res://../docs/evidence/kart-tomkart-driver-2026-11-08/app-compatibility
python scripts/run_kart_driver_review.py ui-mobile res://tests/test_kart_refinement_ui.gd --rendering-method mobile -- --evidence-root=res://../docs/evidence/kart-tomkart-driver-2026-11-08/app-mobile
```

The existing native picture bakers also ran: `scripts/bake_garage_previews.gd`; `test_kart_refinement_ui.gd -- --bake-art`; `bake_news_car_photos.gd -- --vehicle=kart`; `bake_livery_previews.gd -- --vehicle=kart`; and `bake_kart_finishing_art.gd -- --header-only`. Their exact commands are in `pictures.json`, `catalogue.json`, `news.json`, `liveries.json` and `header.json`. The header-only switch preserves the current dedicated Garage thumbnail recipe.

Livery photographs participate in the existing conservative shared dependency tree. After refreshing them, the unchanged other-car assemblies also require renewed prepared receipts. The complete base/module/Garage/header bakers run against the final sources; generated keys and source guards remain intact. Only the kart's model source is changed. A repeated Forklift thumbnail differed; that candidate is retained as evidence, and its exact task-start photograph was restored. All four unrelated Garage PNGs and the kart's four wheel-shadow resources remain byte-identical to the task snapshot.

## Verification and retained findings

Actual integration checks pass in both native desktop renderers: actual Garage/race **16/0 each**, and the replacement-driver matrix initially **70/0 each**, followed by **76/0 each** with embedded-texture and full-detail Garage-template assertions. Driving **72/0**, kart handling **42/0**, Garage washing **45/0**, and the updated Licences page **533/0 headless and 546/0 native Compatibility** pass. The direct driver test with embedded-texture checks passes **61/0**. Final prepared preflight passes **468 resources / 1,925 checks / 0 failures** after the complete picture-tree refresh. Native-picture provenance passes **5 exact images / 155 current source hashes**. Final receipts and results are recorded in `final-summary.json`.

The broad 442-module rebuild exceeded the first runner's 300-second wrapper limit. Its owned native process continued to completion (`MODULAR_KIT_BAKE_COUNT 442`); the timeout is retained as exit 124, not reported as a passed command. The runner now bounds the entire owned child tree at 900 seconds and kills that tree on timeout. Final kart bases/modules were rebuilt again against stable final sources, and the independent complete 468-resource preflight passes.

The older `test_garage_prepared_cars.gd` retains **20 checks / 5 missed-hit failures**: its fixture uses the production default `simple_model=true`, while the retained full-exterior Garage cache explicitly rejects reduced cars. Every car has the same missed-hit failure; all geometry/paint checks pass. That older assertion is not weakened. The new driver matrix explicitly exercises the supported full-detail Garage template as well as all four modular modes, and the actual App tests cover reduced Garage entry.

The first prepared-driver fixture disabled the cache gate used by normal modular restoration, producing four missed-hit assertions even though scene keys, sources and holders were valid. The fixture now enables the production gate; the original assertions remain. The existing Licences test selected Android notices by numeric index; adding a new credit exposed that assumption. It now selects the stable entry ID. A subsequent exact-text check exposed CRLF normalization in the supplied notice; the bundled text uses LF. Initial failed runs and one failed-run teardown diagnostic remain in the logs. Successful final licence and integration runs have no script errors or resource-exit diagnostics; the Windows certificate warning remains. Native race captures retain first-use frame hitches; no loading, FPS, hardware-memory or performance improvement is claimed.

Historical tests of the rejected original sculpted helmet/suit are not appearance acceptance gates for this explicitly selected replacement. Their assertions are not weakened. The original driver source is retained under `before/`; the shared source-only checkpoint and 102-source verification receipt are in `source-only.patch` and `verification-sources.json`. The main Git index is untouched, and concurrent client/backend changes are preserved.

Reload the PC client to see the replacement. Owner appearance acceptance remains. No device attachment query or device test, APK export/install, owner-save edit, owner-process restart, backend request or deployment was performed.
