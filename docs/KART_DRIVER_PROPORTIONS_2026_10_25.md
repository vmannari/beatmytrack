# Kart driver proportions — 2026-10-25

The owner identifies legs that are unnaturally long compared with the torso. KDP01-KDP02 / V02-V05 / R01 / G01 / Q01 correct the seated proportions and preserve the preceding helmet and open-seat fixes.

The hips move forward by 0.25 model metres. A longer reclined waist/abdomen connects them to the existing chest and shoulders, while shorter thighs/shins bend below the steering wheel. The thin open bucket's pan and lumbar curve follow the new pelvis/back. The helmet, neck, collar, shoulders, arms, hands, boots and pedals keep their original positions; the complete kart assembly and production cameras retain their exact source hashes.

| Actual detailed mesh measurement | Before | Revised |
| --- | ---: | ---: |
| Trouser centre-line length | 0.966269 | 0.730731 |
| Hip-to-shoulder span | 0.294217 | 0.416507 |
| Leg/torso ratio | 3.284 | 1.754 |
| Knee bend, degrees | 16.80 | 27.63 |

Legs are **24.38% shorter**. Measurements average actual baked cloth rings, omit the duplicate seam vertex, and interpolate the spine at hip/shoulder heights. They do not call the production authoring functions. The simpler model independently passes the same bounds with ratio 1.762. These are review bounds for the requested pose, not a universal anthropometric specification.

Native matched review:

- [Before side](evidence/kart-driver-proportions-2026-10-25/before-model/full-driver-side.png), [revised side](evidence/kart-driver-proportions-2026-10-25/model/full-driver-side.png).
- [Before front](evidence/kart-driver-proportions-2026-10-25/before-model/full-driver.png), [revised front](evidence/kart-driver-proportions-2026-10-25/model/full-driver.png), [seat from above](evidence/kart-driver-proportions-2026-10-25/model/full-seat-top.png).
- [Desktop Mobile/simple](evidence/kart-driver-proportions-2026-10-25/model-mobile/simple-driver.png), [actual Garage](evidence/kart-driver-proportions-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-driver-proportions-2026-10-25/native/race.png).

Changed source files are game/vehicle/kart_driver.gd, game/tests/test_kart_driver_fit.gd and the new game/tests/test_kart_driver_proportions.gd. The existing fit fixture's rays follow the moved hips/backrest: hip z changes 0.20 to -0.04, and its 0.05-wide backrest window follows the new torso. Its open-cavity, pan-height, zero mesh-crossing and 0.004–0.035 torso-support-gap invariants remain. The actual back support gap is about 0.0157 model metres. No prior threshold is relaxed. The unchanged model and mechanical suites retain the helmet, watertightness, tyre, engine, exhaust, steering, sleeve and inlay checks.

Final results: **24** proportions, **28** fit, **86/86** Compatibility/desktop Mobile model, **172** retained mechanical checks, **15/15** actual Garage/race, **42** kart handling, and **1182** parsed scripts, all with zero failures. The original prepared model is retained as a **24-check/14-failure** proportions regression; the authored draft passes on its first run. All 49 appearance images, catalogue image and newspaper photo are refreshed and imported. Full/simple visible triangles remain exactly **94,296/28,894**; the unchanged detailed cap is 95,000. Fourteen of 230 prepared mesh binaries change; **216 are byte-identical**. The body shadow has 1314 triangles, and all four wheel shadow binaries remain identical. No new material, shader, light, runtime callback or simulation change is introduced.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, with isolated APPDATA/LOCALAPPDATA under build/kart-driver-proportions. The local wrapper copies exact native logs and writes per-command parameters/exit codes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job proportions-before
foreach ($job in @('proportions-draft','fit-draft','draft','bake','proportions','fit','model','retained','art','liveries','news','import','native','handling','parser')) {
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job $job
}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-driver-proportions-2026-10-25/finalize.py
```

[report.json](evidence/kart-driver-proportions-2026-10-25/report.json) records commands, measurements, source/asset hashes and an isolated task-only Git checkpoint. Its binary patch passes whitespace and reverse-application checks with the repository's real .gitattributes; the normal index is untouched. Concurrent work is preserved.

Client reload and owner visual acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan renderer test. Startup hitch logs remain recorded; this task makes no physical-device performance claim.
