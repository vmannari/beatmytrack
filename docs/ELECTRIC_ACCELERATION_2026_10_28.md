# Slightly faster Electric acceleration — 2026-10-28

EAC01 responds to the owner's request for a small acceleration increase. Electric23 changes only its handling version and motor force from 38,000 to 41,000 N (+7.895%). EAC02 retains the recent powered drift setting0.25, launch traction, steering, mass, regeneration20, brake/reverse controls, service brake force, handbrake exclusion and 190 km/h / 7 m/s forward/reverse caps. Shared physics remains 0.75. R01 preserves unrelated work and other-car contracts. Q01 checks launch, rolling acceleration, drift recovery, controls and deterministic five-lap verification.

| Measurement | Electric22 | Electric23 |
| --- | --- | --- |
| 0–72 km/h | 1.0583 s | 1.0500 s |
| 0–100 km/h | 1.4917 s | 1.4667 s |
| 0–144 km/h | 2.2750 s | 2.1917 s |
| 50–100 km/h, full pedal | 0.7667 s | 0.7417 s |
| 50–100 km/h, 65% pedal | 1.4167 s | 1.3167 s |

The moderate-pedal interval improves 7.06%; full-throttle 0–100 improves 1.68%. The retained rear-axle traction budget limits launch improvement: this is not an across-the-board 7.9% acceleration claim. Reverse uses the same stronger motor, with its original delay and speed cap. Service braking still stops from 72 km/h in 1.2833 seconds.

Actual focused checks pass 417/0 against the exact saved Electric22 resource. Every exported field except version/motor force remains equal. The suite checks bounded launch/rolling improvement, exact unpowered braking/lift samples, 84 powered corner combinations, speed caps and replay. Maximum sampled slip is21.815 degrees; straightening recovery is at most200 ms. Existing24-degree/300-ms limits remain. The retained easier-drift comparison passes417/0, and brake/reverse passes104/0; each explicitly normalizes the later motor force in its old reference so it continues to isolate its original behavior. They write separate evidence destinations.

Over and under passes7/0: five ordered laps,34,645 inputs, zero contacts and exact recorded-input replay. The independent verifier and parser results are recorded in [report.json](evidence/electric-acceleration-2026-10-28/report.json), alongside their raw logs. The verifier compares unchanged active other-car identities and explicitly reports Classic/Formula absent due to the earlier concurrent catalogue retirement.

Runtime scope is one resource, `game/resources/cars/electric.tres`. Supporting changes add `game/tests/test_electric_acceleration.gd`, update the two earlier focused tests, and change only Electric's expected identity in `backend/tests/fixtures/verified_oval.json`. Electric23 hashes to `a20ecf35bead7cffcfe503248c4c10b8b8c0ea84659669054f588e518f6431e4`. The source-only scoped patch and reverse-apply check avoid the main index. Task-start and generated build metadata are archived separately; concurrent source changes are preserved and excluded from this patch.

Commands actually run, using the pinned engine through `scripts/dev.ps1`, isolated task-owned APPDATA, and empty `BMT_API_URL`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_acceleration.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_brake_reverse.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-acceleration-2026-10-28/controls'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_drift_easier.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-acceleration-2026-10-28/drift'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_over_under.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-acceleration-2026-10-28/driving'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-acceleration-2026-10-28/verify_canonical.py
python docs/evidence/electric-acceleration-2026-10-28/checkpoint.py
```

The engine runs outside the sandbox to allow its normal certificate-store startup read, with offline isolated profiles. No physical-device attachment query or device test, APK/AAB, authentication/purchase, owner-save mutation, live submission/deployment, owner-process restart, main-index staging, commit or merge is performed. This is a resource-only feel adjustment with no UI/art change or screenshot regeneration. Reload/rebuild, matching backend/current Electric contracts before online use, and owner/device driving-feel acceptance remain. No full release/merge regression, phone performance or frame-rate claim is made.
