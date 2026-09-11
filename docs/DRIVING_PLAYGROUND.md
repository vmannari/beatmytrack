# Driving playground — Phase 2

Requirements: G01 (active driving), R01 (simultaneous controls), R06 (restart), R02/V01 foundations (overhead presentation), A02 preparation (replay experiment). Q01 physical-device acceptance is open. No race, league, economy, backend or editor work is included.

## Launch and first driving session

Open `game/project.godot` using Godot 4.7.2, then F5. The car spawns pointing along the central marked braking lane. The paved yard is bounded by low concrete walls. Two raised islands with painted circles provide corner-entry/slide practice; orange slalom cones are non-colliding visual markers.

1. Select **2 / Balanced**, hold W for about two seconds, then steer with A/D. Steering is relative to the car's nose; the camera never turns with it.
2. Press Space or S to brake before a circle. Compare against releasing W without braking. Stopping should visibly take less distance with the brake.
3. At roughly 60–80 km/h, hold a turn long enough to begin sliding. Release throttle and briefly steer against the slide, then unwind the steering. Look for recovery you can cause deliberately, not a random snap.
4. R restores the start instantly. Repeat with **1 / Stable** and **3 / Loose**. Stable has more rear grip/recovery/assistance; Loose rotates more under power and needs more correction. No profile is claimed approved yet.
5. Stop, hold S for 0.35 seconds, and reverse away. W brakes backward movement before driving forward. When both pedals are held, brake takes precedence; there is no hidden boost.
6. F1 toggles telemetry. F2 opens tuning. Change one setting at a time, repeat the maneuver, then F6 to reload the saved preset. Changes/reset cancel an unsaved capture. Escape or focus loss pauses; resuming requires fresh input.

Please report preferred preset, approximate speed, input sequence, and one of: delayed steering, too twitchy, slides too easily, difficult to catch, or too much grip. The first subjective decision is whether correcting a slide is immediate, understandable and satisfying. Keyboard feedback is useful now; phone touch feel remains the real acceptance gate.

## Architecture and handling model

`VehicleSimulation` and `VehicleState` are RefCounted, independent of nodes, render callbacks, input devices and persistence. Each step consumes a quantized `DriveFrame` at 120 Hz. Steering is signed [-127,127]; pedals [0,255]. Simulation (x,y) maps to Godot (x,0,-y); zero heading points along simulation +Y/world -Z, and positive heading turns right. Visual interpolation and camera smoothing never feed back into simulation.

The car retains world velocity while its heading changes. A speed-dependent steering angle produces a target yaw rate, with a mass/inertia response and front/rear grip balance. Lateral correction is capped by available grip; exceeding the slip threshold reduces grip gradually. Power adds yaw and reduces grip while cornering; lifting restores it. Countersteer assistance modestly aligns heading toward travel direction. Acceleration/braking share a traction budget with cornering. This is a compact arcade approximation, not a tire/load-transfer simulator.

All important handling parameters live in `vehicle/handling_config.gd` as exported Resource fields with ranges and units. `resources/{stable,balanced,loose}.tres` are editable configurations. The live panel exposes engine force, lateral grip, rear grip, steering response, assistance and throttle rotation; the Inspector exposes mass, brake force, drag, rolling resistance, speed caps, steering angle/reduction, wheelbase, longitudinal grip, slip threshold, sliding grip, recovery, inertia, collision loss and the remaining parameters.

`PlaygroundData` supplies geometry to both `PlaygroundVisual` and collision evaluation. Islands use swept circle intersections; walls enforce center bounds. Collision order is stable, impacts dissipate speed, and a 1 mm separation avoids rounding the center outside a wall. The car currently uses a single circular collision approximation, not its exact body silhouette; side/front clearances therefore differ. Cones intentionally have no collision. Version geometry/collision changes before using this data for competitive runs.

`Game` composes the systems and handles reset/pause/profile changes. `DriverInput` merges keyboard actions with per-finger touch ownership. `TouchControls` clears canceled/released/dragged-out fingers independently. The scene pauses and releases input on focus loss/backgrounding. Synthetic touch tests do not establish physical-device behavior or safe-area suitability.

## Presentation

The car is an original 4.25 × 1.8 m compact with normal wheel sizes, readable nose/glass/lamps and restrained matte materials. Body roll, wheel steering, brake lamps and a fixed pool of 240 skid-mark segments are presentation-only. No reference crops or external assets are shipped.

The initial camera profile is exposed in `resources/camera.tres`: height, pitch, fixed world yaw, baseline extent/magnification, forward/velocity look-ahead, bound, smoothing, orthographic/perspective switch and FOV. Heading follow is an experimental opt-in; the acceptance default stays false. Current extent is 35 / 1.15, with pitch 56 degrees and fixed yaw 18 degrees. These are initial tuning values, **not values inferred or approved from the reference**. All-cardinal-heading visibility checks pass; a matched 1672×941 baseline/target comparison, projected vehicle-bound measurement and full-lap reference approval are still pending.

Godot API references checked during implementation: [Camera3D projection/aspect](https://docs.godotengine.org/en/stable/classes/class_camera3d.html), [touch cancellation](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html), [spatial shading](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). The default toon material is a placeholder capability baseline; it does not establish final graphic-novel art quality.

## Input capture experiment

F3 resets to a fresh run and starts recording. F3 again saves `user://handling_capture.json`; at two minutes the capture automatically saves. A later save replaces that diagnostic file. Pause/focus loss ends and saves an active recording; R, tuning changes and preset changes discard an unsaved recording. Keep a copy of a useful capture before starting another.

The JSON contains schema/physics version, engine description, yard identity, complete handling snapshot, initial state, one quantized input per tick, state checkpoints every 120 ticks and final state. It is a local diagnostic, not a PB, verified replay, upload or persistent progress save. The format is intentionally verbose and capped at 14,400 inputs; compact encoding and cross-device numerical equivalence are future gates.

Use Godot's Project → Open User Data Folder to find the file (`%APPDATA%\Circuit01Lab` on this machine). No file I/O occurs in the simulation step. There is no import of arbitrary user scenes/scripts/resources.

## Validation and limits

`scripts/dev.ps1 Validate` imports/parses the project, runs the scene headlessly and executes `tests/test_driving.gd`. The suite covers acceleration, mass, speed/reverse limits, stopping delay, simultaneous pedals, yaw/countersteering, slide recovery, throttle influence, collision loss/tunnelling/overlap, bounded mixed inputs across all presets, exact same-engine input replay, saved capture contents, scene keyboard integration, pause/reset/focus behavior, touch cancellation/drag, tuning buttons and all-heading camera visibility.

Measured on Windows, Godot `4.7.2.stable.official.ed1daf0bf`:

- 43 checks pass.
- From rest: 23.99 m/s after three seconds of full throttle.
- From 24 m/s: 16.35 m braking versus 31.53 m coasting during the next 1.33 seconds.
- Seeded 24-degree slide: below 0.04 radians after 1.5 seconds of released input, with grip recovered above 0.99.
- Same 0.8-steering test: about -18.3 degrees slip under power, -6.9 degrees after lifting.
- 2,400 quantized inputs roundtripped through JSON reproduce identical final state at 1/2/4/8 ticks per render batch. This is not cross-platform proof, nor a frame pacing benchmark.

An early wall-bound test found float32 rounding could place the center less than a micrometer outside the mathematical limit; collision placement was corrected with an inward separation rather than loosening the test. A graphical inspection found reversed winding on generated car panels; faces were corrected and recaptured.

Android SDK/JDK/templates remain unavailable at the configured paths; no APK/device run was performed. No timing/PB/checkpoint circuit yet, no audio/haptics yet, no final material/outline pipeline, no independent per-axle tire solver and no mobile thermal profiling. Do not expand into other product systems on the strength of automated checks alone.
