# Electric powered drift, second small increase — 2026-10-28

EDE01 makes the rear slide a little easier while accelerating and turning. Electric22 changes only its version and `power_lateral_response_scale` from 0.265 to 0.25. EDE02 retains every other Electric21 configuration field, including brake/reverse, regeneration20, motor power, steering, launch response and the high-speed slide fade. Shared physics remains 0.75. R01 preserves unrelated work and other-car identities; Q01 checks onset, speed, recovery, deterministic replay and server verification locally.

At 50 km/h, full steering and 65% accelerator, peak slip increases from 20.423 to 21.490 degrees (+5.23%). Onset moves from 291.7 to 283.3 ms; straightening recovery moves from 183.3 to 191.7 ms. After the sampled powered turn, speed is 71.69 versus 72.88 km/h. Across 84 speed/steering/pedal cases, maximum slip is 21.980 degrees, recovery is at most 200 ms, and at least 98.333% of the previous final speed is retained. All sampled powered turns still accelerate. The test retains its existing 24-degree, 300-ms and 98% bounds rather than relaxing them.

Actual checks:

- New comparison regression: 417 checks, zero failures, against the exact Electric21 resource saved before editing. Includes mirrored steering, exact replay, unchanged straight acceleration/braking/reverse/regen and unchanged light-pedal turns.
- Retained brake/reverse regression: 105 checks, zero failures. Its reference explicitly adopts the later power-slide value to isolate the existing controls contract. Evidence output now accepts a separate directory instead of replacing the preceding task's captures.
- Over and under: seven checks, zero failures; five ordered laps, 34,706 inputs, zero contacts and exact replay.
- Independent verifier and project parser outcomes are in [report.json](evidence/electric-drift-easier-2026-10-28/report.json), with their original console logs.

Runtime scope is one resource, `game/resources/cars/electric.tres`. Supporting changes add `test_electric_drift_easier.gd`, update the current identity/reference/output destination in `test_electric_brake_reverse.gd`, and replace only Electric's expected handling version/hash in the local backend fixture. Electric22's hash is `0d8db0dea914a4db8e37517b76c4989be2144bd8ba9c6b78d75d4b775aecbf9e`. The actual service brake still stops from 72 km/h in 1.2833 s. Historical and unrelated car resource hashes remain unchanged; the verifier reports Classic/Formula absent from the concurrently retired catalogue rather than attributing their removal to this task.

Commands actually run through the pinned `scripts/dev.ps1` entry point, with task-owned APPDATA profiles and empty `BMT_API_URL`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_drift_easier.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_brake_reverse.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-drift-easier-2026-10-28/controls'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_over_under.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-drift-easier-2026-10-28/driving'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-drift-easier-2026-10-28/verify_canonical.py
python docs/evidence/electric-drift-easier-2026-10-28/checkpoint.py
```

The initial sandbox engine start fails its root-certificate-store read; the isolated unsandboxed engine run passes. The original failed log remains. Dev-wrapper generated metadata is archived separately and excluded from the scoped checkpoint. Concurrent bodywork, garage, hovercraft, account/backend and other source edits are preserved. This resource-only feel adjustment adds no visible UI and performs no capture/world/art regeneration.

Reload/rebuild and owner driving-feel acceptance remain. Matching backend/current Electric contracts are required before online use. No physical-device attachment query or device test, APK/AAB, real authentication/purchase, owner-save mutation, live submission/deployment, owner-process restart, main-index staging, commit or merge is performed. No phone or frame-rate claim is made.
