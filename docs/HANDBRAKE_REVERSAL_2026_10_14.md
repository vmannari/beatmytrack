# Rapid handbrake steering reversals, 2026-10-14

Owner request: investigate occasional rotation against the expected direction
when rapidly steering left/right and pulling the handbrake. Preserve the
generally accepted handbrake behavior. Owner narrows the reported case to the
Compact on Grass-biome asphalt.

Requirements: HBX01 reproduce both steering directions on actual canonical
asphalt; HBX02 retain correction through rear lock without snapping rotation;
HBX03 preserve ordinary driving, single pulls, stopping, clutch and backward
exits; G01/R01/T01-T04 deterministic, versioned replay/rewind; Q01 actual checks
and owner/device acceptance.

The issue reproduces with the default Original+ Compact: start at 25 m/s,
steer left with 70% throttle for 36 canonical ticks, then reverse to full right
steering and pull the handbrake for 60 ticks. Use native asphalt cells and the
`pine` theme ID that the menu calls Grass. The old car keeps rotating left even
after the front wheels reach full right steering. Over the subsequent half
second it rotates another 92.76 degrees left and ends at -3.7703 rad/s yaw.

Full rear-brake pressure previously blended out the entire normal steering
correction. During a fast reversal, lateral momentum from the first turn can
then dominate the axle model and keep feeding the old rotation. The axle force
signs and planar/world coordinate conventions themselves are consistent.

Physics `arcade-planar-0.58` retains the already-computed, bounded steering
correction when forward motion exceeds 1 m/s and the proposed axle yaw opposes
the current steering demand. Axle force integration, old angular momentum and
the existing yaw limits still contribute; yaw is never assigned the input's
sign. Pressure rise/recovery, clutch, tire forces, inertia scale, tire grip,
steering rates and all handling resources remain unchanged. The correction
also works during the existing finite rear-grip recovery. No new state,
snapshot field, ground probe, latch or persistent controller is added.

The reproduced Compact catches the new direction at tick 12 (0.100 s), retains
its initial leftward rotation, turns 16.76 degrees right over the measured half
second, and ends at +3.4131 rad/s. These are scripted desktop simulation
measurements, not proof of physical-phone feel or a full physical tire model.
Exact native samples are in
[owner-trace.json](evidence/handbrake-reversal-2026-10-14/owner-trace.json).

The new regression checks all five cars at 12/18/25/35 m/s, half/full pulls and
clean/fully dirt-coated tires, plus all six Compact handling profiles. Each
case verifies inherited angular momentum, catching the new direction, bounded
motion, left/right symmetry and no translational energy gain. Repeated pulls
round-trip quantized JSON controls and restore an active countersteer through
rewind. Separate old/new runs compare every snapshot during ordinary forward
and reverse driving and 0.2/0.5/2-second single pulls followed by release.

The original handbrake suite retains its 231 assertions. Its brief-pull
rotation, actual travel-path hairpins and half-turn backward-exit measurements
are unchanged. The new suite passes 394 checks. The initial candidate affected
single-pull settling near rest; the final forward-speed gate preserves that
behavior, and checking proposed axle yaw also covers dirty-tire high-speed
reversals. Assertions were retained. The baseline axle module is unchanged.

Changed source/contracts:

- `game/vehicle/vehicle_simulation.gd`: scoped yaw correction and physics fence.
- `game/tests/test_handbrake_reversal.gd` and its native UID: new regression.
- `scripts/dev.ps1`: include both handbrake suites in full validation.
- `backend/tests/test_verifier.py`, `backend/tests/fixtures/verified_oval.json`
  and the fixture README: pin .58 while preserving replay inputs, track content,
  five-lap ticks and snapshot schema.
- Project instructions/status/plan and this report/evidence.

Pinned Godot is `4.7.2.stable.official.ed1daf0bf`, invoked through
`scripts/dev.ps1`. Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHandbrake
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDriving
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHandling
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestTracks
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestKerbs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSoil
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHazards
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_handbrake_reversal.gd
# Each test below uses the same TestScript invocation and its res://tests/*.gd path.
# test_script_parse, test_launch_start, test_checkpoint_rules,
# test_star_spline_laps, test_star_gate_tolerance, test_checkpoint_bridge_layers,
# test_bridge_entry_checkpoints, test_bridge_exit_checkpoints,
# test_bridge_contacts, test_shallow_collisions, test_extra_tracks,
# test_speed_bumps, test_breakable_props, test_suspension,
# test_snow_bank_behaviour, test_personal_ghosts, test_records,
# test_cars, test_kart, test_grass_road_height.
# From backend/:
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_verifier.py -q --junitxml=../docs/evidence/handbrake-reversal-2026-10-14/logs/verifier.xml
```

Final handbrake 231/reversal 394, driving 72/handling 88, rewind 61/kerbs 31,
soil 163, launch 13328, checkpoints 266, spline laps 51, gate tolerance 156,
bridge layers 259/entry 258/exit 2527/contacts 16, shallow collisions 20268,
extra tracks 27, speed bumps 9045, breakable props 46, suspension 59, snow-bank
behavior 51852, personal ghosts 38, records 54, all-car races 105, kart 32 and
grass/road support 96 pass. The final parser loads
732 scripts with zero failures. Backend verification passes 70 tests, including
the original exact five-lap diagnostic and standalone staging. Its existing
Starlette/httpx deprecation warning remains.

`TestTracks` completes the diagnostic races/replays but reports three failed
lower-passage height assertions (1way/66/offroad). A separate run using the exact
saved .57 simulation produces the same three failures, with the shared current
bridge presentation. These assertions were left intact. The initial headless
hazard run passes all 160 assertions but reports render-resource cleanup errors
at shutdown; the final unchanged rerun exits cleanly with 160 passes. The saved
baseline hazard run also exits cleanly. No cause for the transient cleanup error
is established.

Normal engine logs initially needed approved access to the existing user-data
directory. An initial backend invocation from the repository root lacked the
package import path; running from `backend/` completed all 70 tests. Temporary
baseline scripts needed explicit GDScript types/consistent indentation; corrected
copies and their results are retained as text evidence and were removed from the
project script tree after use.

The source-only [review patch](evidence/handbrake-reversal-2026-10-14/change.patch)
and [SHA-256 receipt](evidence/handbrake-reversal-2026-10-14/source-receipt.json)
include the baseline simulation required by the new regression. Reverse Git
applicability with `--unidiff-zero --ignore-space-change --whitespace=error-all` and scoped
runtime/contract `git diff --check` pass. The broader shared status/plan diff
reports existing blank lines at EOF; those unrelated lines are retained.
Existing Git-index changes, unrelated car/render/editor/road work and player
files are retained. Physics versioning starts distinct .58 record/ticket keys;
historical records are not relabeled. Matching client/verifier rollout is needed
before online .58 attempts.

Whole-project `Validate` was not run; the listed physics/replay checks were.
No Android export/install, phone-driving test, backend deployment or live online
write was performed. Phone attachment was not checked. Owner acceptance of rapid
Compact reversals on Grass asphalt and physical-phone driving remains open.
