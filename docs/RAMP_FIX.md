# Bridge ramp correction — 2026-09-12

Requirements: G01/G02 handling fixtures and lap preservation; V01/R02 vehicle presentation. The reported teleport came from assigning either zero or the entire 3.2 m deck height to the car, while rendering a flat deck.

`game/track/bridge_presentation.gd` now derives longitudinal approaches from native deck cells and the bridge axis. A spatial smoothstep profile rises from ground over a 4 m extension and up to 4 m inside each deck end. The same profile builds road/rail meshes and positions the car from front/rear axle samples, including uphill/downhill pitch. Route progression distinguishes the upper branch from the underpass. Existing rail cells retain their footprint; extensions add road only. Internal rail faces are omitted.

Integration changes are in `game/track/native_track_visual.gd`, `game/core/game.gd` and `game/vehicle/skid_trails.gd`. Skid marks follow ramp height and slope. `game/tests/test_tracks.gd` adds full-lap continuity and ground-level underpass checks. No source tracing, new artwork or dependencies were introduced. Canonical handling, collision rules, checkpoints, native JSON and replay schema are unchanged, so no content/schema migration or golden update is needed.

## Actual verification

Pinned Godot 4.7.2, Windows Compatibility renderer:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: passed import, 24 script parses, startup, 56 driving checks and 57 track checks.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTracks`: passed 57 checks. All four fixtures completed three ordered AI laps with zero barrier contacts and exact JSON replay checks.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Snapshot -Track slicks_1way_test -AI -CaptureTick 1572`: successful capture, inspected.
- Same Snapshot command for `slicks_66_test` at tick 847 and `slicks_offroad_test` at tick 269: successful captures, inspected. Captured interpolated frames can precede the requested physics tick slightly.

| Bridge track | Ticks at intermediate height | Largest height change per 120 Hz tick | Underpass height |
|---|---:|---:|---:|
| 1WAY | 1,020 | 0.046 m | 0 m |
| 66 | 600 | 0.049 m | 0 m |
| OFFROAD | 993 | 0.109 m | 0 m |

FREEWAY has no bridge. The original 3.2 m step is absent on these driven routes. Road widths remain unchanged (9 m reference width / 1.584 m body = 5.68 car widths).

Evidence: [1WAY](evidence/ramps-1way.png), [66](evidence/ramps-66.png), [OFFROAD](evidence/ramps-offroad.png), [track log](evidence/ramps-track-tests.txt), [driving log](evidence/ramps-driving-tests.txt).

## Remaining acceptance

This is road-following presentation over the existing planar simulation, without suspension, gravity, airborne jumps or falling from a ramp edge. Human testing of unusual sideways/off-route ramp exits, reverse approaches and subjective appearance remains pending. Ground barriers retain the prototype cell outline; underside detail remains limited. No physical phone test or APK export was performed; device attachment was not verified. Owner handling approval remains open.
