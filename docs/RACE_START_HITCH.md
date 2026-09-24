# Race-start hitch investigation — 2026-09-24

Requirements: Q01 / V05 / G01. Owner reports a brief freeze roughly five seconds into a race on desktop and phone. Root cause and a gameplay fix remain unconfirmed.

Added `game/tests/profile_race_start.gd` and `scripts/dev.ps1 -Action ProfileRaceStart -Track <local-id>`. This graphical diagnostic includes countdown and early frames, reports main simulation/rules/presentation/effect costs, exercises moving/stationary/repeated starts, and does not save scores or settings. It overrides focus-loss pause only inside the diagnostic. It validates elapsed simulation ticks and actual driving distance. First run drives before a stationary pass can warm effect resources.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ProfileRaceStart
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ProfileRaceStart -Track track_acf29166cceaaa42
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ProfileRaceStart -Track track_3e26605a8a90165e
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -DesertCostProfile -Baseline -SkipInstall -Seconds 15 -ReportName race-start-phone-2026-09-24
```

The Ajorata attempt was interrupted following the owner's request to use another track. Subsequent testing uses Speedy (desert). An initial Speedy diagnostic was invalidated by desktop focus-loss pause; the runner was corrected and rerun. Starter-track moving runs did not reproduce the reported freeze. These are observations, not a passing acceptance test for the bug.

Speedy desktop evidence: [stationary-first capture](evidence/race-start-2026-09-24/speedy-desktop.log). Both driving runs had worst post-countdown frames below 21 ms; larger scene-start frames occur before driving. Stationary run had an isolated 92.9 ms frame near countdown completion. Final [driving-first capture](evidence/race-start-2026-09-24/speedy-driving-first.log) passed all live-simulation checks: 71.99/71.82 m driven, 1333/1330 ticks. Worst driving frames were 36.769/21.487 ms; the first run included a 30.994 ms frame at tick 636 (5.3 seconds driving), without a corresponding script-cost spike, absent from the repeat. This does not establish the reported freeze or its cause. Concurrent desktop activity limits isolated timing attribution.

Attached DN2103, existing installed APK (no export/install): [phone report](evidence/race-start-phone-2026-09-24/desert.json). 120.49 m driven, median 16.705 ms, p95 20.511 ms, maximum 31.564 ms, zero frames above 33 ms. Existing mobile probe excludes five seconds after race creation, including the three-second countdown, so this measurement covers approximately driving seconds 2–17 and cannot rule out earlier startup stalls. Diagnostic markers were removed and normal play restored. The APK hash file describes the local APK, not a freshly verified installed binary.

No gameplay, physics, camera or artwork changes. Changed files are the diagnostic, dev entry point, this report, status/plan and evidence. No claim that the owner's hitch is fixed. Remaining acceptance: reproduce the owner's exact trigger/vehicle/track, determine whether it happens stationary and on every restart versus only first launch, then compare an attributable fix on both devices. No full physics regression or new APK build was needed for diagnostic-only changes.
