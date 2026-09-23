# Sand dust clouds

## Implemented 2026-09-20

Requirements: **R01, V02, V04, V05, Q01**. Sand contact now produces a presentation-only two-layer wheel effect in ordinary races and creator practice. Four wheel emitters leave soft world-space dust behind; two rear emitters add short, denser grains under substantial slip. Asphalt, grass, water, snow and bridge decks do not emit sand.

`game/vehicle/sand_dust.gd` owns the bounded six-emitter effect. Dust is camera-facing suspended volume: 360 particles per wheel emitter, 2.05 m source quads, 5.20-second life and 3.65x final expansion. They rotate independently, decelerate and retain useful opacity through most of their life. The warmer pale-sand colour is `#D1B380` at 0.48 peak alpha. Spray remains a separate 0.65-second, 0.15 by 0.25 m fast gravity-driven layer.

The earlier foreground compositing override was rejected because it drew new ground dust over the car immediately. Dust begins at the same approximately 2.5 cm tyre-contact height as the trails and retains normal scene depth testing. After owner feedback that the delayed version appeared only after the car was gone, source scale increased to 0.24 and alpha reaches useful density at 2.5% of life (about 0.13 seconds). It grows to 0.62 scale by 0.62 seconds while rising, then through 1.60 at 2.18 seconds toward 3.65. Young dust is therefore visible directly at the tyre without covering the car; older elevated clouds naturally enter the camera's car depth and grow large enough to cover it. Bridge height is applied before the contact offset.

The procedural sinusoidal card shader was also rejected as visually artificial. Dust now uses the original authored [dust puff texture and saved prompt](assets/DUST_PUFF_PROMPT.md). Runtime shading consumes its alpha and luminance, applies the shared light sand tint, and randomly rotates/scales overlapping instances. The tiny sand-grain spray remains procedural because it is read as individual fast debris rather than cloud volume.

The effect samples the same four contact positions as the physical tire marks but now uses a dedicated emission response. Speed produces only a light baseline cloud; lateral tyre velocity, slip angle, braking and yaw progressively raise density. Front dust is reduced during a slide, rear load varies across the car, and spray uses a nonlinear high-slip response. Initial direction is opposite each wheel point's translational plus rotational velocity, after which strong damping lets the cloud settle rather than travelling with the car. The system reads canonical state but never writes to simulation, timing, grip or track data.

Changed files: `game/vehicle/sand_dust.gd`; integration in `game/core/game.gd`; shared visual intensity access in `game/vehicle/skid_trails.gd`; focused coverage and capture in `game/tests/test_soil.gd`; status documents; [ground-origin evidence](evidence/soil/sand-dust-clouds.png) and [mature raised-cloud evidence](evidence/soil/sand-dust-risen.png).

## Actual verification

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CheckScript -ScriptPath res://vehicle/sand_dust.gd`: passed with Godot 4.7.2.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CheckScript -ScriptPath res://core/game.gd`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 Import`: passed and imported `dust_puff_v1.png` with Godot 4.7.2.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestSoil`: **146 checks passed** headlessly. Coverage includes the authored puff material, emitter topology, 5.2-second lifetime, broad footprint, depth contract, ground-level origin, upward launch/lift, immediate tyre response, nonlinear heavy-slip response, rear/front bias, spray threshold and asphalt shutoff.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestDriving`: **74 checks passed**. The command reported two ObjectDB instances leaked at exit; no assertion failed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CaptureSoil`: **153 checks passed** on the Compatibility renderer and regenerated separate ground-origin and mature raised-cloud evidence.

## Limits and acceptance

Particle simulation is GPU presentation and is not replay-verifier state; emission strength and placement are deterministic inputs, while individual particle variation need not reproduce byte-for-byte. The original sand-only boundary was superseded by the grass/asphalt extension below. No physical-phone deployment, sustained particle performance measurement or in-motion owner review was performed. Remaining acceptance is density/colour/readability during real laps on the target phone, especially ensuring the strongest plume does not hide the next braking point.

## Grass and asphalt extension — 2026-09-20

Requirements: **R01, V02, V04, V05, Q01**. The same wheel-contact presenter now covers grass and dry asphalt without changing handling. Grass has four blade/clipping emitters plus two heavier rear mud-fleck emitters. A normal crossing produces a sparse clipping response; speed and lateral slip progressively increase the blades, while mud follows a nonlinear high-slip curve and remains absent during clean rolling. The rejected first version used camera-facing fragments and looked pasted onto the image. Clippings are now actual thin 3D boxes and mud uses low-poly 3D grains, both born at each wheel, launched opposite wheel-point velocity, independently rotating and falling under gravity. Clippings live for 1.05 seconds; denser mud lasts 0.78 seconds.

Dry asphalt has four pale-grey smoke emitters with no rolling baseline: they begin only beyond meaningful slip/lateral-speed or heavy braking thresholds, bias the rear axle and cap at 0.48 intensity. Repeated review showed that denser use of the irregular dust sprite still exposed separate smoke patches, so asphalt no longer shares that texture. It uses a dedicated smooth radial haze shader with 900 particles per wheel, only 0.040 peak alpha, 1.50-second life and 1.6x terminal expansion. The owner's real-race screenshot then exposed a separate cadence problem: at 30 Hz, fast-moving emitters released dense batches at visibly separate world positions. Smoke alone now simulates at the canonical 120 Hz vehicle rate, closing those spatial gaps; dust and physical debris remain at the cheaper 30 Hz rate.

Focused evidence: [grass clippings and mud](evidence/soil/grass-clippings-mud.png) and [heavy-slip asphalt smoke](evidence/soil/asphalt-tire-smoke.png). `TestSoil` passes **155 headless checks**, including physical 3D debris meshes, the smoke-specific uniform-haze material, 120 Hz smoke cadence, continuous-smoke capacity, no smoke under normal asphalt grip, bounded/rear-biased smoke under heavy slip, clipping-only normal grass crossing and clipping-plus-mud heavy grass slip. `CaptureSoil` passes **164 graphical checks** on the Compatibility renderer. The prior `CheckScript` passed after the surface extension.

No physical-phone deployment or particle-load profiling was performed. The combined worst case now has more GPU particle emitters per car, although mutually exclusive surface gating prevents sand, grass and asphalt layers from emitting together at one wheel. Remaining acceptance is in-motion density and performance on the target phone. Snow/water-specific airborne effects remain out of scope.
