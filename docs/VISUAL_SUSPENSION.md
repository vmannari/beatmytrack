# Visual suspension — 2026-09-15

## Requirements and behavior

Owner request; G01/V02/V04/V05/R01/R03/R07. Add visual suspension under cornering, acceleration, braking, bumps, jumps and bridge transitions, with occasional hard-contact sparks.

The body now uses a damped spring driven by snapshot velocity changes in the car's local axes. Acceleration raises the nose, braking lowers it, and lateral force rolls the body outward. Collision velocity changes also drive the spring. The wheels retain their road pose while the body moves. Existing canonical kerb heave/pitch/roll and bridge/jump placement remain composed with this body motion. Airborne suspension extends; landing compresses and rebounds. Changing bridge slope adds transient compression and pitch response.

Hard landings (prior descent above 3 m/s) and sharp slope transitions (slope above 0.12 rad and slope-rate × speed above 16) can emit eight warm short-lived sparks above 9 m/s. A 0.4 s cooldown and 24 reusable meshes bound the effect. Airborne/submerged contact and steady inclines emit none. This is a visual scrape approximation, not actual underbody collision detection or damage.

Motion consumes each new snapshot once and integrates springs in 1/120 s substeps. Repeated paused snapshots freeze motion/particles; restart clears both. At low display rates forces are averaged across received snapshots, so cosmetic peaks can differ. No canonical state, physics identity, record schema, grip, speed, camera or collision dimensions changed. No external assets or dependencies.

## Changed files

- `game/vehicle/car_visual.gd`: body spring, contact heuristics and bounded world-space spark pool.
- `game/core/game.gd`: presentation hook after bridge/jump pose, before existing kerb offsets.
- `game/tests/test_suspension.gd`: force direction, settling, pause/reset, immutable state, landing and spark gating checks; optional staged captures.
- `scripts/dev.ps1`: TestSuspension/CaptureSuspension and full-validation inclusion.
- Status/plan, this document and `docs/evidence/suspension/`.

## Actual verification

All engine commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2.

- `-Action CheckScript -ScriptPath res://vehicle/car_visual.gd`: passed.
- `-Action Import`: passed; existing missing Android build-tools diagnostic remains. `git diff --check`: passed (line-ending notices only).
- `-Action TestSuspension`: 13 checks, zero failures.
- `-Action CaptureSuspension`: 17 checks, zero failures, four inspected-engine inspection-view captures. These use staged snapshots and a separate close camera, not a live driving or gameplay camera calibration claim.
- `-Action TestDriving`: 70 checks, zero failures, including 2,400-tick exact same-engine replay at multiple render batch sizes.
- `-Action TestKerbs`: 31 checks, zero failures; existing physical response preserved.
- `-Action Snapshot -Track slicks_1way_test -AI -CaptureTick 450`: successful; car was obscured by the upper bridge at this underpass sample, so this capture cannot establish suspension appearance.
- `-Action Snapshot -Track slicks_freeway_test -AI -CaptureTick 180`: successful gameplay integration capture.

[Rest](evidence/suspension/suspension-rest.png), [cornering](evidence/suspension/suspension-corner.png), [braking](evidence/suspension/suspension-braking.png), [landing sparks](evidence/suspension/suspension-landing.png), [gameplay](evidence/suspension/gameplay.png).

## Remaining acceptance

Owner motion/strength acceptance and sustained high-speed bridge/landing driving review remain open. No continuous-motion video, Android export or physical-phone test performed. `Get-Command adb` found no ADB executable; device attachment could not be enumerated. Phone effect visibility, frame pacing and thermal cost are unmeasured. Full project validation was not rerun for this presentation-only change. Existing unrelated staged and unstaged work was retained; no combined commit was made.
