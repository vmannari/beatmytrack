# Tighter Electric turning — 2026-10-28

ETR01 reduces the Electric's turning radius. Electric24 changes only version, the continuous base radius2.5to2.3m and its speed-progression parameter70to75. ETR02 retains the recent41000N acceleration, powered slide0.25, mass, steering angle/ramp, yaw cap, regeneration20, brake/reverse and speed caps. Shared physics remains0.75. R01 preserves unrelated work; Q01 checks actual path radii, speed, symmetry, replay, drift recovery and five-lap verification.

Measured steady full-steering circles use a quantized pedal controller to hold the requested speed; radius is integrated travelled distance divided by accumulated course angle after settling:

| Speed | Electric23 radius | Electric24 radius | Reduction |
| --- | --- | --- | --- |
| 30 km/h | 3.506 m | 3.239 m | 7.61% |
| 40 km/h | 4.279 m | 3.963 m | 7.39% |
| 60 km/h | 6.492 m | 6.027 m | 7.17% |
| 80 km/h | 9.582 m | 8.913 m | 6.98% |
| 120 km/h | 18.403 m | 17.147 m | 6.83% |

At5/10/20km/h the actual radii remain2.682/2.781/2.991m: the retained physical steering angle already limits these slow turns before the continuous envelope. This task tightens normal-speed racing turns and does not claim tighter parking turns. All eight sampled circles complete at maintained speed, remain mirrored left/right and replay exactly.

The new focused suite passes430/0. All exported Electric fields except version and the two radius fields remain exact against the saved Electric23 resource. Eight circle comparisons retain the original requested-speed, bounded-improvement and symmetry assertions. Across84 powered turns, maximum slip is23.336degrees and straightening recovery is at most208.333ms; the existing24degree/300ms limits remain. Three1200-input straight power/brake/reverse/lift sequences remain tick-exact against Electric23.

Retained brake/reverse102/0, acceleration417/0 and easier-drift417/0 pass. Their previous references explicitly adopt the later radius fields to isolate their respective earlier changes; none claims unchanged turning. The faster launch and rolling times remain unchanged. Actual five-lap, independent verifier and parser outcomes are recorded in [report.json](evidence/electric-turning-tighter-2026-10-28/report.json), with all raw logs. The first five-lap invocation encounters a dev-wrapper build-identity file-sharing collision; its original log is retained and the serialized retry is separate.

Runtime scope is only `game/resources/cars/electric.tres`. Supporting changes add `test_electric_turning_tighter.gd`, update the current identity and later-radius reference in the three preceding focused tests, and change only Electric's expected version/hash in the local backend fixture. Electric24 hashes to `e0929f09740e36823a5f017d2a26956bfd581b847f89d8ba442d6af9d4688799`. The verifier checks other active identities and reports Classic/Formula absent due to their earlier catalogue retirement. The source-only scoped checkpoint avoids the main index; generated build metadata is archived separately. Concurrent work is preserved.

Commands actually run through the pinned engine entry point with task-owned APPDATA profiles and empty `BMT_API_URL`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_turning_tighter.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_brake_reverse.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-turning-tighter-2026-10-28/controls'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_acceleration.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-turning-tighter-2026-10-28/acceleration'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_drift_easier.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-turning-tighter-2026-10-28/drift'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_over_under.gd -TestArgument '--evidence-root=res://../docs/evidence/electric-turning-tighter-2026-10-28/driving'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-turning-tighter-2026-10-28/verify_canonical.py
python docs/evidence/electric-turning-tighter-2026-10-28/checkpoint.py
```

Engine runs use the existing isolated offline approach outside the certificate-store restriction. No physical-device attachment query or device test, APK/AAB, real authentication/purchase, owner-save mutation, live submission/deployment, owner-process restart, main-index staging, commit or merge is performed. No UI/art change or screenshot regeneration is made. Reload/rebuild, matching backend/current Electric contracts for online use, and owner/device steering/drift feel acceptance remain. No full release/merge regression, phone performance or frame-rate claim is made.
