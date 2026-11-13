# Faster hovercraft rotation and stronger thrust

Owner request: rotate the hull faster, retain its inertia and increase the throttle push.

HPT01-HPT03/R01/Q01: `game/resources/cars/hovercraft.tres` changes only handling version `hovercraft-1` → `hovercraft-2`, engine force 7,400 → 10,000 N (+35.14%) and maximum yaw rate 1.35 → 1.9 rad/s (+40.74%). Angular inertia (780), steering ramps, lateral damping (0.85), mass, braking and the 130 km/h cap retain their prior values. The shared simulation and other vehicle resources are untouched by this task. The new configuration hash separates records/replays from the previous tune.

## Measured behavior

Both configurations use the same current canonical simulation and quantized inputs. The previous resource is retained byte-for-byte as `game/tests/fixtures/hovercraft_power_turn_before.tres`.

| Fixture | Previous | Current |
| --- | ---: | ---: |
| Hull angle after 0.5 s at 20 m/s, 60% steering, 50% throttle | 12.5267° | 17.6302° |
| Yaw rate at that point | 41.2485°/s | 58.0534°/s |
| Chassis/travel slip at that point | 10.5120° | 14.6525° |
| Speed after one second of full throttle from rest | 43.2526 km/h | 56.7860 km/h |
| 0–60 km/h | 1.4583 s | 1.0667 s |

The unchanged straight coasting/sideways-momentum fixture matches the old state exactly. More than 60% of the original sideways speed remains after half a second. Released yaw persists and then settles instead of snapping to demand. These are desktop simulation measurements; owner feel acceptance remains.

## Actual checks and commands

Godot commands use the pinned `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with disposable workspace APPDATA and an empty `BMT_API_URL`.

- `-Action TestScript -ScriptPath res://tests/test_hovercraft_power_turn.gd`: 127 checks, zero failures. This covers exact allowed parameter changes, turn-in/release, thrust, unchanged coasting, 60 turn/power cases, dissipative unpowered steering, bounded speed, serialized collision replay and rewind continuation.
- `-Action TestScript -ScriptPath res://tests/test_hovercraft.gd -TestArgument --evidence-root=res://../docs/evidence/hovercraft-power-turn-2026-10-28/retained`: 50 checks, zero failures, including the original five retained car hashes/100 state checkpoints, roster, saves, collisions, model and audio checks.
- `-Action TestScript -ScriptPath res://tests/generate_hovercraft_replay.gd -TestArgument --output=res://../docs/evidence/hovercraft-power-turn-2026-10-28/five-lap-replay.json`: five laps, 18,953 elapsed ticks and zero contacts. Original tune evidence is preserved.
- A separately staged native backend imports its class cache and runs both normal trajectory acceptance and independent canonical replay on this synthetic race. Both accept 18,953 elapsed ticks / 157,942 ms with zero contacts; `worker-verification.json` retains both results.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd`: 1,379 scripts, zero failures.

The two existing test helpers gain optional evidence/output destinations so tune reviews do not overwrite earlier receipts. New test/fixture and this document/status entry accompany the one runtime-resource change. No art, camera, UI or shared physics source changes are required. Existing broader-suite limitations remain recorded in the original Hovercraft document.

`docs/evidence/hovercraft-power-turn-2026-10-28/report.json` contains measurements, hashes and final outcomes; `task.patch` is the task-only review checkpoint. Native staged import, replay and logs are retained beside it.

Reload/rebuild to try the new feel. Matching authorized backend/current-track contracts are needed for live online use of the new handling hash; no rollout was performed. No physical-device attachment query/test, APK, live write, owner-save change, owner-process restart, or Git staging/commit/merge was performed. Concurrent Electric/Garage/backend and generated build metadata are preserved. Owner steering/thrust feel and device acceptance remain.
