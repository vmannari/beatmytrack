# Kart shorter neck — 2026-10-25

The owner identifies the neck as still too long. KSN01-KSN02 / V02-V05 / R01 / G01 / Q01 lower the complete helmet by 0.065 model metres on a static HelmetMount and shorten the balaclava's vertical radius from 0.082 to 0.046, with centre y moving 0.787 to 0.751. The rear collar-to-shell exposure measured from actual mounted geometry falls **0.084 to 0.019 model metres**, a **77.38%** reduction. The helmet now sits close to the collar with a connected lining and zero intersections against collar, torso or shoulder cloth in both detail levels.

Only game/vehicle/kart_driver.gd and game/tests/test_kart_driver_fit.gd change. The previous fixed neck-top-at-0.85 assertion encoded the rejected tall placement; the owner's shorter-neck correction supersedes it. Its connectivity requirement is retained as actual collar/lining overlap, with new 0.004–0.030 exposure and actual helmet/cloth edge checks. The shortened chin and existing seat support/cavity/clearance checks remain. Helmet shape, visor and all helmet binary resources are exact; torso/leg/seat proportions, collar, arms/hands, boots, kart assembly, physics/config and production cameras remain exact.

Matched native views: [before side](evidence/kart-short-neck-2026-10-25/before-model/full-driver-side.png), [shorter neck](evidence/kart-short-neck-2026-10-25/model/full-driver-side.png), [before front](evidence/kart-short-neck-2026-10-25/before-model/full-driver.png), [revised front](evidence/kart-short-neck-2026-10-25/model/full-driver.png), [desktop Mobile/simple](evidence/kart-short-neck-2026-10-25/model-mobile/simple-driver.png), [actual Garage](evidence/kart-short-neck-2026-10-25/native/garage-1280.png), [actual driving](evidence/kart-short-neck-2026-10-25/native/race.png).

Final checks: **32** fit, **24** retained proportions, **86/86** Compatibility/desktop Mobile model, **172** mechanical regression, **15/15** actual Garage/race, **42** kart handling and **1184** parsed scripts, all passing. The original exposed neck fails exactly two of the 32 focused checks; the first revised version passes. There are 230 prepared resources: two replacement neck meshes and **228 byte-identical others**, including every helmet mesh. Detailed/simple triangles decrease from 94,296/28,894 to **93,520/28,706**, retaining the 95,000 cap. All four wheel shadow binaries remain identical; the rebuilt body shadow has 1110 triangles. Catalogue/news/all 49 appearance photos are refreshed and imported. No new material, shader, light, per-frame callback or physics change is added.

Pinned Godot 4.7.2 runs through scripts/dev.ps1 with isolated APPDATA/LOCALAPPDATA under build/kart-short-neck. Actual job commands and exit codes are saved in *-command.json and native logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job fit-before
foreach ($job in @('fit-draft','draft','bake','fit','proportions','model','retained','art','liveries','news','import','native','handling','parser')) {
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job $job
}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-short-neck-2026-10-25/finalize.py
```

[report.json](evidence/kart-short-neck-2026-10-25/report.json) records outcomes, hashes, archived original resources and the isolated task-only Git checkpoint. Its patch passes whitespace and reverse-application checks; the normal index remains untouched. Concurrent work is preserved.

Client reload and owner appearance acceptance remain. No device attachment check/test, APK build/install, authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; startup hitch logs remain and no physical-device performance claim is made.
