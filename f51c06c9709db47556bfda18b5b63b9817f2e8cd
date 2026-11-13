# Kart helmet redesign — 2026-10-25

The owner rejects the previous helmet and requests a redesign. KH01–KH03 / V02–V05 / R01 / Q01 replace its spherical construction with an original full-face competition helmet: tucked neck opening, forward chin guard, shaped cheeks/temples, lower crown, a larger eye port, fitted visor/seal/brow lip, hinge hardware and restrained intake/vent details. This supersedes the helmet portion of the preceding kart refinement only.

`game/vehicle/kart_helmet.gd` owns the new shell and fittings. `kart_model.gd` calls it in place of the old spherical helmet, chin shaping and painted crown stripe. The shell wraps around a real eye aperture rather than covering the eyes with opaque paint underneath a visor overlay. A native mesh ray through the eye port reaches the rear shell; the corresponding chin ray hits the integrated front guard. Height-profile tangents agree between stations and match the analytic crown to avoid the first review's horizontal shading bands.

The kart retains the existing pose, suit/knees, steering, seat, bodywork, bumper, exhaust, lights, canonical wheel locations, collision/handling and production camera. **196 existing prepared mesh files are byte-identical** to the task-start files. The 12 old helmet mesh resources are backed up and retired; 22 new helmet resources produce 218 current full/simple resources in the manifest. The exact helmet source SHA-256 is now part of the existing preparation contract. Only the body shadow changes shape; matching wheel shadow resources remain.

The complete visible kart is 88,600 triangles detailed / 26,244 simpler, within the existing unchanged 95,000-triangle test limit. The current prepared mesh files total 1,010,670 bytes. The increase from 86,096/25,280 is 2,504/964 triangles. There is no new runtime callback, light, transparent pass, external dependency, AI/media service or manufacturer asset.

All 49 kart livery photographs, the native catalogue image and newspaper photo have been regenerated and imported so the current helmet appears wherever the kart is shown. Other vehicles' art is excluded by the existing per-vehicle bake filters. Original code-authored geometry and shared CompactFinish materials retain the established provenance.

Matched native review views:

- [Previous helmet front](evidence/kart-helmet-redesign-2026-10-25/before-model/full-helmet-front.png) and [side](evidence/kart-helmet-redesign-2026-10-25/before-model/full-helmet-side.png).
- [Redesigned helmet front](evidence/kart-helmet-redesign-2026-10-25/model/full-helmet-front.png), [side](evidence/kart-helmet-redesign-2026-10-25/model/full-helmet-side.png), [rear](evidence/kart-helmet-redesign-2026-10-25/model/full-helmet-rear.png), and [seated driver](evidence/kart-helmet-redesign-2026-10-25/model/full-driver.png).
- Actual Garage/race captures are in `native/` and `native-mobile/`; matched studio views are in `model/` and `model-mobile/`. The close-up cameras are evidence-only.

The pinned engine is Godot `4.7.2.stable.official.ed1daf0bf`, invoked through `scripts/dev.ps1`. APPDATA/LOCALAPPDATA and fixture records point inside the workspace's disposable build directories. Native runs require Windows certificate-store access outside the sandbox. Commands:

```powershell
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--baseline','--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/before-model')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_kart_model.gd
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/model')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/model-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--bake-art','--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/art')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart','--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/news')
./scripts/dev.ps1 Import
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-helmet-redesign-2026-10-25/native-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
```

Actual counts, saved logs, source/asset hashes, preserved simulation/config/camera hashes and the task-only Git checkpoint are recorded in [report.json](evidence/kart-helmet-redesign-2026-10-25/report.json). The baseline captured 20 views successfully; the first unbaked design passed 73 checks and retained the visually detected shell bands in `first-review/`. Correcting the profile interpolation preserves the test thresholds and geometry assertions. The final model passes **75 checks in each desktop renderer**, and actual Garage/race integration passes **14 checks in each**. Catalogue art has one successful save check; all 49 livery photographs and one correctly framed newspaper photograph are refreshed. The final full-project parser passes **1,160 scripts**. Its initial run could not resolve `GameFonts.SYMBOLS` in a concurrently added translation test; a subsequent import and parser attempt reported that the new font was not imported. After its native cache became available, the final fresh parser passed without editing font sources or weakening any assertion. All initial logs remain. Import retains the isolated Android build-tools directory warning. Headless handling/replay were not rerun for this helmet-only presentation change; the preceding task's verified results remain historical evidence rather than new results.

Owner helmet appearance acceptance and physical-device motion/frame-pacing/cost checks remain. Desktop App startup hitches, if logged, are retained in the native logs; this redesign makes no performance certification. An already running client must reload to replace loaded scripts, meshes and photographs. No phone attachment check/test, APK build/install, real sign-in/purchase, live backend mutation, deployment or owner-process restart was performed. Earlier/concurrent work and the normal Git index are preserved.
