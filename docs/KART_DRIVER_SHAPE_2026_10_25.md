# Kart driver shape correction — 2026-10-25

The owner rejects the driver's rubber-like body and asks for proper shapes. This revision addresses KDS01-KDS03 / V02-V05 / R01 / G01 / Q01.

| Requirement | Result |
| --- | --- |
| KDS01: recognisable seated anatomy | The torso has a narrower waist, broader ribcage, shallow paired chest planes, sloped shoulders and a narrow collar base. Sleeves follow two long-bone axes joined through a short tangent-continuous elbow return. Upper arms, elbows, forearms and wrists have distinct elliptical sections. Thighs, knees, calves and ankles have separate volumes. Existing hand/boot locations and seated leg proportions remain. |
| KDS02: tailored cloth | Roughness 1.0 and metallic specular 0.04 replace the previous rubber helper. Dark chest/knee panels, small shoulder yokes, cuff bands and shallow compression folds belong to the suit. The main watertight torso/limb joins remain. Face-centre rays validate actual panel/cuff backing against the actual suit triangles. |
| KDS03: production assets and regressions | Both native desktop renderers show the prepared production model. Matching body shadow, catalogue/news art and all49 appearance photos are regenerated/imported. Actual Garage/race presentation and retained construction, seat fit, proportions, mechanical and kart checks pass. |

Matched native views: [before front](evidence/kart-construction-fixes-2026-10-25/model/full-driver.png), [after front](evidence/kart-driver-shape-2026-10-25/model/full-driver.png); [before side](evidence/kart-construction-fixes-2026-10-25/model/full-driver-side.png), [after side](evidence/kart-driver-shape-2026-10-25/model/full-driver-side.png); [simple model](evidence/kart-driver-shape-2026-10-25/model-mobile/simple-driver.png); [actual Garage](evidence/kart-driver-shape-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-driver-shape-2026-10-25/native/race.png).

Actual tests: new shape **38**, retained construction **32**, fit **32**, proportions **24**, model **86/86 Compatibility/desktop Mobile**, mechanical **172**, actual Garage/race **15/15**, kart handling **42**, and parser **1209** scripts, all with zero failures. Exact task-start driver reloaded only in isolated process memory gives **38 checks/32 expected failures**. New measurements inspect the actual mesh widths/sections, actual opaque material and actual cloth backing; they do not call the authoring profile. Old assertions/tolerances remain unchanged.

The first draft's limb sections and shoulder silhouette remained too soft in native review; the final form narrows the neck base, introduces the short elbow return and more clearly elliptical/tapered sections. A later panel review found chest strips extending over the torso's shoulder openings and mismatched cuff/sleeve sampling. Chest strips now stop before those openings, and cuff columns match the existing sleeve rings. The independent face backing audit is retained. First images and full verification are archived in draft-first and before-panel-fit. All meshes except the eight chest/cuff resources are byte-identical across that last panel adjustment. An initial direct PowerShell script call was refused by local execution policy; all actual native runs then use the standard Bypass wrapper through pinned scripts/dev.ps1.

Visible detailed/simple triangles: **94,928/29,374**, below the unchanged95,000 detailed cap. Prepared meshes: **254**, with **222 byte-identical** originals; ten prior torso/limb resources retire,26 new resources appear and six common zipper/piping resources change. Retired originals are retained under before and retired-meshes. Body shadow: **1210** triangles. Four wheel shadow binaries remain identical. No new textures, shaders, per-frame work, lights or external assets are introduced.

Runtime source scope is game/vehicle/kart_driver.gd. game/tests/test_kart_driver_shape.gd adds the review regression. Exact helmet, kart assembly, geometry helper, corrected seat attachments, driver neck pose, hand/boot locations, production camera and kart configuration are preserved. Shared source hashes and allowed concurrent changes are recorded and excluded from the task checkpoint. The shared sources remain stable during the recorded final native/handling/parser commands. Native startup hitch logs are retained; no frame-pacing/device-performance claim is made.

Actual commands, each with per-job arguments, exit codes, logs and shared-source hashes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/run.ps1 -Job draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/run.ps1 -Job bake
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase final
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase all
python docs/evidence/kart-driver-shape-2026-10-25/finalize.py
```

The all phase reruns the exact old-source comparison, all final tests/art/import/handling/parser jobs, then model and actual Garage/race in desktop Vulkan Mobile. Engine4.7.2 is pinned by scripts/dev.ps1. APPDATA/LOCALAPPDATA are isolated under build/kart-driver-shape. The existing missing Android build-tools warning is retained; this task does not build an APK.

The isolated Git checkpoint uses exact task-start source/assets and current shared documents with only this task block removed. Its binary patch passes whitespace and reverse-application checks. The main Git index and concurrent work are untouched.

Client reload and owner appearance acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; physical-device appearance, motion and cost remain untested.
