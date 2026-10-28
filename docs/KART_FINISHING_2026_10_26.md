# Kart finishing details — 2026-10-26

KFP01–KFP03 / V02–V05 / R01 / G01 / Q01: refine the existing go-kart to match the Compact's level of finish.

The nose and Nassau fairing now have narrow dark borders around their cream inlays. Actual triangle-backed socket fasteners secure the nose, fairing and sidepods; dark outboard rubbing strips finish the pods. Chassis brackets support the fairing. The front steering bellcrank and paired links, rear axle bearing carriers and feet, brake mounting hat, fitted airbox parting seal and retaining clips make the exposed assembly more complete. The engine fins have thin bevelled edges and the tray has recessed socket hardware. All geometry is original code-authored work using the existing CompactFinish materials.

| Requirement | Evidence |
| --- | --- |
| KFP01: restrained bodywork finishing | [Before](evidence/kart-finishing-2026-10-26/before-gl_compatibility/full-front.png), [after](evidence/kart-finishing-2026-10-26/model-gl_compatibility/full-front.png), [actual Garage](evidence/kart-finishing-2026-10-26/native-gl_compatibility/garage-1280.png) |
| KFP02: fitted mechanical details | [Engine](evidence/kart-finishing-2026-10-26/model-gl_compatibility/full-engine.png); retained 160-check tyre/steering/body-tilt, clamp and inlay audit passes. |
| KFP03: prepared production assets and unchanged driving | Both native desktop renderers pass 87 model and 15 Garage/race observations. Kart handling 42, driver shape 38, construction 32, seat fit 32, proportions 24, and parser 1291 pass. |

Detailed geometry changes from 94,928 to **94,870 triangles**; racing geometry changes from 29,374 to **31,506**. The existing 95,000-triangle detailed cap and all prior regression bounds remain. Small hardware uses fewer radial segments; thin engine plates use perimeter bevels instead of six dense grids. No new textures, shaders, lights, dependencies or per-frame processing are introduced. The driver, helmet, main shells and canonical wheel geometry remain. The unchanged kart configuration and simulation sources are hash-checked.

There are 288 prepared mesh resources, including 250 byte-identical originals. Four retired resources are archived under the evidence directory. The body shadow is rebuilt; the four rolling wheel shadow resources remain exact. Catalogue, news, Garage, header and all 49 livery pictures are refreshed from the actual model. Header and Garage photos use the established camera/studio recipes and update only the kart assets. The Garage provenance updates only the kart model/helper dependencies and kart picture hash.

Runtime changes are confined to `game/vehicle/kart_model.gd` and the new `kart_detail.gd`. The bake adds the detail-source digest; the existing model test checks that digest without changing its prior assertions. `game/tests/bake_kart_finishing_art.gd` refreshes the two newly static picture locations. Source, asset, command, log and checkpoint details are in [report.json](evidence/kart-finishing-2026-10-26/report.json).

Actual commands use pinned Godot 4.7.2 through `scripts/dev.ps1`, with disposable APPDATA/LOCALAPPDATA under `build/kart-finishing`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job bake
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/verify.ps1 -Phase geometry
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/verify.ps1 -Phase visual
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/verify.ps1 -Phase assets
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/verify.ps1 -Phase checks
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job native -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-finishing-2026-10-26/run.ps1 -Job import
python docs/evidence/kart-finishing-2026-10-26/finalize.py
```

The initial 95,574-triangle draft failed the unchanged budget assertion. Reducing the new small collars corrects it; the later fitted airbox seal also replaces the first draft's partially buried seam. The sandboxed native run could not read Windows' certificate store; native runs succeeded outside that sandbox. One import encountered a concurrently removed `_review_extra_colours.gd`; its log is retained and the final import passes. A Mobile integration run encountered an unfinished concurrent `challenges_client.gd` declaration and was retried after that edit completed. The packaged all-car Garage-preview checker still rejects the unrelated Electric configuration hash with both current and task-start provenance; the assertion is preserved. Concurrent `car_visual.gd` and `profile_car.gd` changes are recorded and excluded from this task's review patch. Native startup hitches are retained in logs; these captures do not establish device performance.

Reload/rebuild and owner appearance acceptance remain. No physical-device attachment check or test, APK, real authentication/purchase, live mutation, deployment, main-index staging, commit, merge or owner-process restart was performed. Desktop Mobile means Vulkan on the desktop GPU. Physical-device appearance, motion and cost remain untested.
