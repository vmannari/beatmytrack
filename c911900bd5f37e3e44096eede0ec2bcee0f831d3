# Kart helmet reference shape - 2026-10-25

The owner supplies a white full-face racing helmet photograph and asks to fix the kart driver's helmet to that shape. KHR01-KHR03 / V02-V05 / R01 / G01 / Q01 supersede the prior helmet's silhouette. This is original code-authored geometry; the reference photograph and manufacturer logo are not production assets.

`game/vehicle/kart_helmet.gd` now builds a rounder crown with a shorter rear volume, integrated forward chin/jaw and a lower edge rising from front to rear. The front edge stays rounded across the chin. A deeper swept eye aperture has returned rubber edges, a fitted smoked visor/seal and a quiet brow. Two pivots per side use recessed, closed flat links and clean metal screw faces. Small crown intakes, rear extractors, a single front intake, cheek vent rings and a lining return finish the shell. The visor uses the existing opaque material approach; no transparency pass, runtime callback, extra light, external model or image service is added.

The owner reference's important shape relationships are the round cranium, front chin lower than the rear neck, eye-port lower corners rising toward the temples, and close-fitting visor hardware. It is a visual reference, not a measured scan. The original driver pose, collar, suit, kart chassis/bodywork, tyre/engine clearances, exhaust, wheel/steering geometry, lights, kart configuration and production cameras retain their exact task-start sources. A concurrent electric brake-release task changed the shared simulation and handling declarations. Both before/current hashes match its separate evidence report exactly; those sources are preserved and excluded from this helmet checkpoint. The current workspace also passes kart handling32/replay107, including three five-lap runs, after this concurrent change. The initial all-source equality audit correctly rejected the changed shared sources; it was replaced with explicit unchanged kart-asset checks and exact attribution of these two concurrent files.

The model test retains every earlier threshold/assertion. Its helmet node lookup follows the new shell name. New checks inspect the actual shell vertices for at least 0.07 model metres of chin-to-rear rise and cast nine rays through the eye port; the original aperture/chin rays remain. A diagnostic three-quarter helmet camera is added without changing production cameras. Both native detail levels use the same profile and hardware arrangement.

There are **228 prepared meshes**: 32 new helmet resources replace 22 previous ones; **196 other resource binaries are identical**. The original cache and retired resources are archived in `before/meshes/` and `retired-meshes/`. Detailed/simple visible triangles are **93,888/28,562**, below the unchanged 95,000 detailed limit. The matching body shadow has 1302 triangles; all four wheel shadow binaries remain identical. Catalogue/newspaper and all 49 livery photographs were refreshed and imported. The import log retains the existing Android build-tools directory warning.

Native review images:

- [Before front](evidence/kart-reference-helmet-2026-10-25/before-model/full-helmet-front.png), [before side](evidence/kart-reference-helmet-2026-10-25/before-model/full-helmet-side.png).
- [New three-quarter view](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-reference.png), [front](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-front.png), [side](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-side.png), [seated driver](evidence/kart-reference-helmet-2026-10-25/model/full-driver.png).
- [Simpler three-quarter](evidence/kart-reference-helmet-2026-10-25/model/simple-helmet-reference.png), [desktop Mobile side](evidence/kart-reference-helmet-2026-10-25/model-mobile/simple-helmet-side.png), [actual Garage](evidence/kart-reference-helmet-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-reference-helmet-2026-10-25/native/race.png).

The old model has 20 successful baseline capture checks. The first authored version passes 73 geometry/capture checks, but visual inspection finds oversized carrier patches and crown lips; `first-shape/` preserves those. The refined profile passes 79 checks, while close-ups reveal a linkage crossing screw faces. Closed, recessed flat links replace the round linkage and correct that overlap before the final bake. The final model passes **81 checks per desktop renderer**. Retained tyre/engine/exhaust/sleeve/stripe regression passes **172 checks**, and actual Garage/race integration passes **14 per renderer**. Catalogue save and newspaper framing pass, with 49 current livery captures. The full-project parser passes **1167 scripts**. No assertion or budget is relaxed. An initial PowerShell hash-pipeline binding error was corrected before recording the unchanged-source manifest; an invalid combined patch operation was rejected before any file mutation.

Commands use pinned Godot 4.7.2 through `scripts/dev.ps1`, disposable `build/kart-refinement` APPDATA/LOCALAPPDATA and fixture records. Native Windows tests use approved certificate-store access. Final commands:

```powershell
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_kart_model.gd
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/model')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/model-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/retained-fixes')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--bake-art','--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/art')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart','--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/news')
./scripts/dev.ps1 Import
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/native-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
./scripts/dev.ps1 TestKart
```

Measurements, logs, source/asset hashes and the isolated task-only checkpoint are in [report.json](evidence/kart-reference-helmet-2026-10-25/report.json). The checkpoint uses the exact task-start helmet/assets and current shared documents with only this task block removed. Its binary patch passes staged whitespace and reverse-application checks; the normal index/branch remain untouched. Concurrent work is preserved.

Client reload and owner visual acceptance remain. Desktop Mobile/Vulkan is not a physical-device test or AAA certification. Logged desktop startup hitches remain recorded, with phone motion/frame-pacing/cost acceptance outstanding. No device attachment check/test, APK, real authentication/purchase, live backend mutation/deployment or owner-process restart was performed.
