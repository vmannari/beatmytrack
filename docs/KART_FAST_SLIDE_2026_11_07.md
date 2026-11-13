# Kart fast-corner slide — 2026-11-07

KFS01: Owner requests a slight slide at full speed in a curve. Kart-13 scales
lateral response to 65% near maximum speed, fading continuously from the original
response at 65% of top speed (91 km/h) to full effect at 90% (126 km/h). This retains
sideways momentum without adding yaw or changing the tire-force limit. Other cars
use the default 1.0 scale, omitted from their canonical configuration snapshots.
Kart version/hash distinguish the changed competitive contract. Both local load
fixture manifests have the new kart identity; no service deployment occurred.

KFS02: Actual ten-second, full-power turns at steering 0.35/0.65/1.0 show sustained
slip 3.964/4.227/4.469 degrees before and 6.796/7.250/7.295 after. Peak is 7.363
degrees. Corner speeds are 133.071/126.929/120.000 km/h. Straightening settles
within 317/333/350 ms. Left/right symmetry and exact four-step presentation replay
pass. Low-speed turns/braking/reverse and straight acceleration/braking/coasting
remain tick-exact; the straight cap remains 140 km/h. Dedicated test: 6328/0.

KFS03: Over and under, Storm Freight and Storm Quarry each complete five ordered
laps with zero contacts (25656/35956/39887 ticks). Full replay and restored-state
replay match exactly: 15/0. Retained turn-speed 18/0, low-speed steering zero
failures, winter grip 55/0, final handling/actual Game 3613/0, kart 42/0, handling
88/0, driving 72/0 and rewind 61/0. Historical selected/winter controls explicitly
reset the later fast-slide parameter instead of weakening their comparisons.

Commands used pinned Godot 4.7.2 and private offline profiles:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_fast_slide.gd` (sandbox Access denied; normal-access rerun passes).
- The same entry point with `test_kart_turn_speed.gd` passes 18 assertions, but its existing resource-at-exit error makes the wrapper reject exit 0.
- `python build/kart-fast-slide/run_checks.py test_kart_fast_slide test_kart_turn_speed test_kart_low_speed_steering test_kart_winter_grip test_kart_final_handling test_kart test_handling test_driving test_rewind` records individual pinned offline runs. Only turn-speed and low-speed tests emit resource cleanup errors; no script errors.
- `python build/kart-fast-slide/run_checks.py test_kart_fast_slide_tracks` records the track/replay checks.
- `python scripts/prepare_car_assets.py --output build/kart-fast-slide/prepared-assets` refreshes dependent prepared assets and checks provenance.

Files: `game/vehicle/handling_config.gd`, `vehicle_simulation.gd`,
`game/resources/cars/kart.tres`, new fast-slide and track tests and prior-tune
fixture, existing kart/final/winter/capture identity checks,
`backend/tests/fixtures/load_trajectory.json`, and pipeline-generated prepared
resources/identities/provenance. Logs and command receipts are under
`build/kart-fast-slide/`.

The complete pipeline passes: 442 modules baked, 468 prepared resources validated
with 1925 checks and zero failures, and five native images with 157 current source
hashes. Source receipts remain unchanged across the bake. The initial pre-bake
stale-asset/provenance failures are expected and retained. A source-only task patch
is retained at `build/kart-fast-slide/task-source.patch`; regenerated binary assets
remain in the workspace.

Limitations: automated checks do not establish the owner's driving feel. No device
test, APK export/install or backend deployment was performed. Tablet feel and
matching service rollout remain. No merge or main-index write; concurrent work
is preserved. This handling change introduces no UI/art change.
