# Kart helmet, driver and seat fit — 2026-10-25

The owner rejects the still-long chin, asks for a better driver body and identifies the driver intersecting the seat. KDF01-KDF03 / V02-V05 / R01 / G01 / Q01 cover this presentation-only correction.

| Requirement | Result |
| --- | --- |
| KDF01 | Retract the lower chin profile by up to 0.052 model metres and lift its lowest point from 0.737 to 0.765. The actual front ray at y=0.815 meets the chin at z=0.01365. The round crown, real swept eye port, fitted visor and hardware remain. |
| KDF02 | One shaped suit surface follows hips, waist, chest and shoulders; continuous sleeves bend through the elbows, with trim sampled from the same cloth surface. Refined legs/gloves and a balaclava neck connect the seated figure to its helmet. Hands, steering assembly and boots retain their control locations. |
| KDF03 | Replace the closed seat volume with a thin, open bucket: curved pan, rising back, flared sides, 0.012-thick shell/returns and separate inset padding. The shell stays watertight while its occupied cavity is open above and in front. Actual torso/backrest gap is 0.01968 model metres. All 23,424 detailed and 5,856 simple cloth triangle edges clear the seat shell. |

The new kart_driver.gd owns the seat and driver surfaces. Kart model calls it before the existing steering assembly. The baked manifest pins its SHA-256 alongside the model, helmet and geometry sources. Mesh creation occurs offline; production uses immutable prepared geometry and the established opaque materials. No new per-frame callback, transparency pass, light or shader is added.

Native matched review images:

- [Before driver](evidence/kart-driver-fit-2026-10-25/before-model/full-driver.png), [revised driver](evidence/kart-driver-fit-2026-10-25/model/full-driver.png).
- [Before chin](evidence/kart-driver-fit-2026-10-25/before-model/full-helmet-side.png), [shortened chin](evidence/kart-driver-fit-2026-10-25/model/full-helmet-side.png).
- [Before seat/side](evidence/kart-driver-fit-2026-10-25/before-model/full-driver-side.png), [fitted side](evidence/kart-driver-fit-2026-10-25/model/full-driver-side.png), [open seat from above](evidence/kart-driver-fit-2026-10-25/model/full-seat-top.png).
- [Actual Garage](evidence/kart-driver-fit-2026-10-25/native/garage-1280.png), [actual driving view](evidence/kart-driver-fit-2026-10-25/native/race.png), [desktop Mobile driver](evidence/kart-driver-fit-2026-10-25/model-mobile/simple-driver.png).

Final native results: model **86/86** Compatibility/desktop Mobile, focused fit **28/28**, retained tyre/engine/exhaust/sleeve/inlay regression **172**, actual Garage/race **15/15**, kart handling **42**, parser **1179** scripts with zero failures. Catalogue save, 49 appearance photographs, newspaper framing and asset import pass. Visible detailed/simple triangles are **94,296/28,894**, below the unchanged 95,000 limit. There are **230 prepared resources**; 178 are byte-identical, 18 existing keys change, 32 old keys retire and 34 new keys are added. The matching body shadow is 1,320 triangles; all four wheel shadows remain byte-identical. Restoring the kart model's original LF convention leaves all 235 prepared/shadow binaries unchanged; the exact-source/geometry integrity rerun passes **60** checks.

The original-source focused regression is retained in fit-before/ and its log. Its seat cuts through pelvis, torso and thighs, and its cavity rays strike solid material. Early authored review found trouser/seat contacts and an unsupported neck, which were corrected. The first pan lowering was 0.0024 below its retained support bound; raising the actual pan fixed that failure. The old helmet test used z<0 to locate its front edge; the shortened chin is now behind that plane, so the locator uses z<0.08 while retaining the original >0.07 front/rear-rise assertion and all aperture rays/budgets. No invariant or tolerance is weakened. Initial execution-policy/certificate-store failures, a partial-cache diagnostic and PowerShell log-capture mistakes are retained or described in report.json; final command receipts copy the runner's exact native logs.

Exact configuration hashes for all seven cars, shared simulation/handling, Garage/camera/game presentation sources and geometry helpers agree with task start. Within kart_model.gd, chassis/fairings, engine/exhaust/wheels and the complete steering assembly remain text-identical. This includes the accepted 140 km/h kart tune. Concurrent workspace changes are preserved.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, with disposable APPDATA/LOCALAPPDATA under build/kart-driver-fit and fixture records. run.ps1 records its parameters/exit codes and native logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit-before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job bake
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job retained
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job art
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job liveries
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job news
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job native
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job native -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job handling
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job parser
```

[report.json](evidence/kart-driver-fit-2026-10-25/report.json) lists results, hashes, retained failures and the isolated task-only Git checkpoint. The checkpoint compares exact task-start kart assets to the final files, with only this task's additions in shared documents. Its binary patch passes whitespace/reverse-application checks; the normal repository index is untouched.

Client reload and owner appearance review remain. Physical-device testing, attachment checking, APK build/install, real authentication/purchase, live mutation/deployment and owner-process restart were not performed. Desktop Mobile is a desktop renderer test. Native startup hitch logs remain; no device performance claim is made.
