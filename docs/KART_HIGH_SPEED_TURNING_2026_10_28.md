# Shorter go-kart turns at higher speeds - 2026-10-28

KHT01 tightens the go-kart's actual driven turning radius at higher speeds. Kart-6 raises lateral grip from 72 to 80 m/s², within the existing authored range. This increases the available cornering force where the current kart runs out of grip. KHT02 retains its steering angle/ramp/reduction, yaw cap, power, brakes, reverse, soil penalties, geometry and 140 km/h cap. Shared physics stays `arcade-planar-0.75`. R01 preserves concurrent work; Q01 checks matched-speed paths, symmetry, recovery, deterministic replay and five-lap verification.

Full-steering radii are measured from travelled distance divided by accumulated travel-direction angle after three seconds of settling. The quantized pedal controller holds the same requested speed using each unmodified handling resource; smaller radii cannot pass by slowing down.

| Speed | Kart-5 | Kart-6 | Shorter radius |
| --- | --- | --- | --- |
| 80 km/h | 6.860 m | 6.183 m | 9.86% |
| 100 km/h | 10.707 m | 9.634 m | 10.01% |
| 120 km/h | 15.420 m | 13.875 m | 10.02% |
| 140 km/h | 20.994 m | 18.891 m | 10.02% |

At 45% steering the reductions are 2.36% at 80, 7.04% at 100, 9.57% at 120 and 9.95% at 140 km/h. Full-steering circles through 60 km/h remain effectively unchanged; all sampled 10-30 km/h circles remain within 0.004% of the previous radius. This changes the high-speed radius relative to the prior tune; the radius still grows naturally as speed rises.

The focused regression passes 148 checks with no failures. The original tune fails 10 of those same checks before the change, covering the expected identity, higher-speed radius and PB separation. Eighteen speed/steering pairs cover 10-140 km/h with matched-speed original/revised circles and mirrored revised circles. All circles complete, maintain at least 98% of requested speed, stay within the bounded tightening envelope, retain less than 12 degrees of slip, settle within 350 ms and replay exactly at 120/30 Hz step batches. Four 3,600-tick straight acceleration/braking/lift/reverse sequences remain tick-exact against Kart-5; sustained top speed is still 140 km/h.

Retained kart 42/0, cross-car checks plus kart laps 113/0, shared handling 88/0 and rewind 61/0 pass. Kart completes five laps on Arto4, Hiekka and Ovaali3 with zero contacts and exact input replay. A separate native engine verifies a 12,787-input five-lap generated race at 106,554 ms with lap ticks `[2621, 2541, 2542, 2541, 2542]`. The retained Compact backend five-lap replay also passes. The pinned preferred dependency parse for the new regression passes.

Two broader checks retain unrelated failures. The project-wide parser stops at `game/tests/fixtures/parking_hall_before/garage_page.gd:67`, whose saved Garage methods call the missing `_build_wash_requirement()`; this fixture and its base Garage source are outside this task. The backend manifest assertion expects retired `classic` and `formula` IDs because the appearance schema retains historical identities while the active catalogue has six vehicles. The catalogue and canonical sources are byte-exact against task start, and kart resource tuning cannot change that ID set. The original assertions remain untouched. The two selected backend tests therefore report one pass and one failure, rather than a full backend pass.

The first sandboxed native invocation cannot read the Windows root certificate store. Offline native runs use a task-owned APPDATA profile and empty API URL through the existing automatic escalation path. The first independent verification helper assumes every active car exists in the older local fixture and stops on its absent Hovercraft entry after successfully verifying the race. The corrected helper records that missing coverage and checks every present contract; the Hovercraft fixture is not invented or modified. Raw initial logs remain in the evidence folder.

Runtime scope is one resource: `game/resources/cars/kart.tres`. Supporting changes add the focused regression and an exact Kart-5 test fixture, update only the current identity assertion in `test_kart.gd`, and refresh only Kart's expected version/hash in the local backend fixture. The new configuration hash is `9faf4795507b76a82d36c54745ec3c4a689576aa54a5b1c2613c24e8ced280d1`. Shared simulation/config/catalogue sources and six other car-resource sources remain byte-exact against task start. Documentation, raw receipts and the checked source-only patch are in [the evidence folder](evidence/kart-high-speed-turning-2026-10-28/report.json). Generated build identities are archived and excluded from that patch; concurrent source changes remain preserved. The patch uses no main Git index.

Commands actually run, with `$env:APPDATA` set to the task-owned `tmp/kart-high-speed-turning-profile` and `$env:BMT_API_URL=''`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_high_speed_turning.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_cars.gd -TestArgument '--car=kart'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_handling.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rewind.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/export_kart_speed_replay.gd -TestArgument '--output=res://../docs/evidence/kart-high-speed-turning-2026-10-28/kart-race.json'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/test_kart_high_speed_turning.gd
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/kart-high-speed-turning-2026-10-28/verify_canonical.py
./.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py::test_real_engine_manifest_pins_every_competitive_config backend/tests/test_verifier.py::test_real_five_lap_race_replays_identically -q --basetemp=tmp/kart-high-speed-backend-tests
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/kart-high-speed-turning-2026-10-28/summarize.py
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/kart-high-speed-turning-2026-10-28/checkpoint.py
```

The original focused run additionally sets `--evidence-root=res://../docs/evidence/kart-high-speed-turning-2026-10-28/original`. Python verification uses the pinned `BMT_GODOT_BIN`, local `BMT_GAME_PROJECT` and `PYTHONPATH=backend`; it never connects to the live service.

Reload/rebuild and matching backend/online car contracts are required before online use of Kart-6. Owner driving-feel and physical-device acceptance remain. No physical-device attachment query/test, APK/export, owner-save mutation, live submission/deployment, authentication/purchase, owner-process restart, main-index staging, commit or merge was performed. No UI/art change or phone-performance claim is made. The broader failures above remain release/merge limitations.
