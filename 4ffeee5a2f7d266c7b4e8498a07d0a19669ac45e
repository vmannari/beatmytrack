# Kart model review fixes - 2026-10-25

The owner requests fixes to the four findings in the preceding kart review. This changes the kart's presentation geometry and its native photographs. Driving, collisions, wheel locations, helmet design and production camera retain their exact task-start sources.

| Requirement | Correction and evidence |
| --- | --- |
| KMF01 / V02-V05 | Move the broad nose and rolled underside ahead of the front tyres' complete steering envelope; reconnect the narrow central fairing. The conservative longitudinal gap is 0.055148 model metres. Sample all body vertices against the solid rubber volumes at 25 steering angles from -0.6 to +0.6 radians in each detail level. Another 12 combinations per detail level cover pitch +/-0.03 and roll +/-0.036 radians. A small front crossmember end contact exposed by these additional poses is removed by shortening its ends by 0.03 model metres. |
| KMF02 | Narrow the engine plate from 0.39 to 0.30 model metres and shift the case, cylinder/fins/head and attached fittings inward by 0.025 model metres. Plate clearance improves from -0.021773 to +0.028227 model metres. The stricter scan also fixes the small case and lowest-fin contacts omitted by the original review's 2 mm reporting threshold. |
| KMF03 | Derive each retaining band's radius from the same tapered chamber profile. Move each chassis stay's upper end to the fitted band. More circumference segments keep the racing detail fitted too. Actual triangle rays at 16 angles per band verify an inner-band/chamber gap between -0.004 and +0.003 model metres; the old band floated up to 0.01364 metres. |
| KMF04 | Replace the buried tubes with narrow, tapered strips projected onto the outer union of the sleeve surfaces. Actual mesh rays verify cloth backing with no missing samples or buried points, in both detail levels. The retained capsule arms, pose, gloves, helmet and continuous trouser legs are unchanged. |
| R01 / G01 / Q01 | Keep the existing 75-check model suite unchanged, test the actual Garage/race views in both desktop renderers, retain source invariants, refresh all native photos and record the task-only checkpoint. |

The final visual review also found the simpler fairing's stripe clipping into its coarser triangles. Both central stripes now use clipped copies of the actual upper fairing triangles, lifted 0.0015 model metres. Native ray checks cover every stripe triangle's centre; the stripes remain continuously above their supporting surfaces. All new surface projection/clipping happens during mesh creation/baking, with immutable prepared resources used by production. No new frame callback, shader, material role, light or transparent pass is introduced.

There are **218 prepared resources**, of which **188 are byte-identical** to the task-start cache. Thirty old keys retire and thirty new keys replace them. The complete original cache remains in `before/meshes/`; retired and intermediate resources remain in evidence. The matching body shadow is rebuilt; all four wheel shadow binaries remain identical. Visible full/simple triangles are **88,272/26,378**, below the unchanged 95,000 detailed limit. The simple model additionally uses 1,712 shadow-only triangles. All 49 livery images, the catalogue image and newspaper photo are current native renders, imported successfully. The existing Android build-tools directory warning remains in the import log.

Matched native views:

- [Before: front steering](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-steering-0.0.png) and [fixed: centered](evidence/kart-model-fixes-2026-10-25/verified/full-steering-0.0.png), [left limit](evidence/kart-model-fixes-2026-10-25/verified/full-steering--0.6.png), [right limit](evidence/kart-model-fixes-2026-10-25/verified/full-steering-0.6.png).
- [Before: engine](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-engine.png) and [fixed engine/exhaust](evidence/kart-model-fixes-2026-10-25/verified/full-engine.png).
- [Before: sleeve trim](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-controls.png), [fixed full driver](evidence/kart-model-fixes-2026-10-25/verified/full-controls.png), and [simpler driver/stripe](evidence/kart-model-fixes-2026-10-25/verified/simple-controls.png).
- [Actual Garage](evidence/kart-model-fixes-2026-10-25/native/garage-1280.png) and [actual race](evidence/kart-model-fixes-2026-10-25/native/race.png). Desktop Vulkan Mobile counterparts are in `native-mobile/`, `verified-mobile/` and `model-final-mobile/`.

The final focused suite passes **172 checks in each renderer**; the retained model suite passes **75 in each**. Actual Garage/race integration passes **14/14**, with catalogue save **1**, all 49 livery captures and one correctly framed newspaper photograph. Kart handling/replay pass; the full-project parser passes **1164 scripts**. The original and stricter source invariants all agree with task-start SHA-256 values. No existing assertion or threshold is weakened.

The final regression run against the exact backed-up old source records **164 checks / 82 failures**. Early fixture failures (duplicate Godot node names and too few sampled simple-sleeve vertices), the first tighter engine-fin scan, initial coarse clamp fit and the added crossmember body-tilt failure are retained with logs and images. The stripe issue was found by visual inspection after the mechanical checks passed; its before-image remains in `final/simple-controls.png`. The final test adds eight whole-stripe checks to the earlier 164-check regression.

Pinned Godot 4.7.2 is invoked through `scripts/dev.ps1`; APPDATA/LOCALAPPDATA and records are isolated under `build/kart-refinement`. Native Windows runs use approved certificate-store access. The substantive commands are:

```powershell
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/verified')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_kart_model.gd
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/model-final')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/verified-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/model-final-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--bake-art','--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/art')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart','--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/news')
./scripts/dev.ps1 Import
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/native-mobile')
./scripts/dev.ps1 TestKart
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
```

Exact measurements, logs, source/asset hashes and the scoped checkpoint are in [report.json](evidence/kart-model-fixes-2026-10-25/report.json). The checkpoint has an isolated base of task-start kart assets and current shared documents with only this task's block removed; it excludes concurrent changes and leaves the normal branch/index alone. Its binary patch passes `git diff --cached --check` and `git apply --reverse --check` in the isolated repository.

Client reload and owner appearance review remain. Desktop renderer checks do not constitute physical-device motion/frame-pacing/cost acceptance or AAA certification. Logged desktop startup hitches are retained. No device attachment check/test, APK build/install, real authentication/purchase, live backend mutation/deployment or owner-process restart was performed.
