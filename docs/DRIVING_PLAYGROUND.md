# Driving playground — Phase 2

Requirements: G01 (active driving), R01 (simultaneous controls), R06 (restart), R02/V01 foundations (overhead presentation), A02 preparation (replay experiment). Q01 physical-device acceptance is open. No race, league, economy, backend or editor work is included.

## Launch and first driving session

Open `game/project.godot` using Godot 4.7.2, then F5. The car spawns pointing along the central marked braking lane. The paved yard is bounded by low concrete walls. Two raised islands with painted circles provide corner-entry/slide practice; orange slalom cones are non-colliding visual markers.

1. Select **2 / Balanced**, hold W for about two seconds, then steer with A/D. Steering is relative to the car's nose; the camera never turns with it.
2. Press Space or S to brake before a circle. Compare against releasing W without braking. Stopping should visibly take less distance with the brake.
3. At roughly 60–80 km/h, hold a turn long enough to begin sliding. Release throttle and briefly steer against the slide, then unwind the steering. Look for recovery you can cause deliberately, not a random snap.
4. R restores the start instantly. Repeat with **1 / Stable** and **3 / Loose**. Stable has more rear grip; Loose has less lateral/rear grip and needs more correction. No profile is claimed approved yet.
5. Stop, hold S for 0.35 seconds, and reverse away. W brakes backward movement before driving forward. When both pedals are held, brake takes precedence; there is no hidden boost.
6. F1 toggles telemetry. F2 opens tuning. Change one setting at a time, repeat the maneuver, then F6 to reload the saved preset. Changes/reset cancel an unsaved capture. Escape or focus loss pauses; resuming requires fresh input.

Please report preferred preset, approximate speed, input sequence, and one of: delayed steering, too twitchy, slides too easily, difficult to catch, or too much grip. The first subjective decision is whether correcting a slide is immediate, understandable and satisfying. Keyboard feedback is useful now; phone touch feel remains the real acceptance gate.

## Architecture and handling model

`VehicleSimulation` and `VehicleState` are RefCounted, independent of nodes, render callbacks, input devices and persistence. Each step consumes a quantized `DriveFrame` at 120 Hz. Steering is signed [-127,127]; pedals [0,255]. Simulation (x,y) maps to Godot (x,0,-y); zero heading points along simulation +Y/world -Z, and positive heading turns right. Visual interpolation and camera smoothing never feed back into simulation.

The car retains world velocity while its heading changes. A speed-dependent steering angle produces a target yaw rate, with a mass/inertia response and front/rear grip balance. Lateral correction is capped by available grip; exceeding the slip threshold reduces grip gradually. Default presets disable added throttle yaw/grip loss and automatic countersteer assistance. Throttle adds velocity along the nose; manual countersteering changes the heading relative to momentum. Acceleration/braking share a traction budget with cornering. This is a compact arcade approximation, not a tire/load-transfer simulator.

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

- 56 checks pass.
- From rest: 36.54 m/s after three seconds of full throttle.
- From 24 m/s: 16.35 m braking versus 31.53 m coasting during the next 1.33 seconds.
- Seeded 24-degree slide: below 0.04 radians after 1.5 seconds of released input, with grip recovered above 0.99.
- Same 0.8-steering test: about -10.0 degrees slip under power, -4.9 degrees after lifting.
- 2,400 quantized inputs roundtripped through JSON reproduce identical final state at 1/2/4/8 ticks per render batch. This is not cross-platform proof, nor a frame pacing benchmark.

An early wall-bound test found float32 rounding could place the center less than a micrometer outside the mathematical limit; collision placement was corrected with an inward separation rather than loosening the test. A graphical inspection found reversed winding on generated car panels; faces were corrected and recaptured.

Android SDK/JDK/templates remain unavailable at the configured paths; no APK/device run was performed. No timing/PB/checkpoint circuit yet, no audio/haptics yet, no final material/outline pipeline, no independent per-axle tire solver and no mobile thermal profiling. Do not expand into other product systems on the strength of automated checks alone.

## Owner handling iteration: tighter Formula-inspired response

Handling version `handling-0.3` responds to the owner's large-turning-radius feedback (G01). This is an original tuning pass toward the requested Slicks 'n' Slide Formula feel, not a reconstruction of its physics. Balanced remains the default. Steering reaches full input in 83 ms instead of 125 ms; reduced yaw inertia makes direction changes quicker. High-speed steering reduction is 65% instead of 80%, with a larger maximum steering angle. Stronger lateral grip and slip grip let the path follow the nose while preserving power-induced slip. Stable and Loose share the tighter steering with separate grip balances. The live grip slider now covers the new values.

A full-steering, half-throttle quarter-turn test measures travelled distance divided by the change in **velocity direction**, rather than body heading. Starting at 43/65/86 km/h, effective turn radius fell from 15.36/25.27/41.44 m to 7.56/10.66/15.61 m. Speed evolves during these maneuvers; these are not constant-speed circle radii. Three regression checks require at least 25% improvement against the preserved old configuration. All 46 checks pass, including replay and recovery. Acceleration and straight braking metrics remain unchanged.

Restart the running project (F8 then F5) to load the revised script defaults. Select 2/Balanced and repeat a 60?80 km/h turn around an island, then try a quick left-right change and a lift/countersteer recovery. The owner still needs to judge whether it matches the desired feel. Windows scripted capture: `docs/evidence/driving-formula.png`; physical Android was not tested.

## Owner acceleration/top-speed iteration (handling-0.4)

G01: increased shared engine force from 10,500 to 16,500 N and maximum speed from 34 to 46 m/s (122.4 to 165.6 km/h) in `game/vehicle/handling_config.gd`. All three presets inherit the increase. Steering/grip tuning remains from handling-0.3. Stronger engine force also accelerates reverse faster, with the same delayed engagement and 7 m/s reverse cap.

Actual Windows `scripts/dev.ps1 Validate` passed import, 17 script parses, startup and all 50 checks. Measured 0?100 km/h improves from 3.63 to 2.13 seconds; speed after three seconds is 36.54 m/s. Straight-line simulation reaches the 165.6 km/h cap. Quarter-turn effective radii are now 8.24/11.43/17.05 m at initial 43/65/86 km/h under half throttle; the extra acceleration widens these slightly from handling-0.3 but all retain the required improvement over the original handling. New top-speed steering/recovery checks pass, as do braking, collisions, all presets and exact replay. Camera visibility tests now use the configured maximum speed. Evidence: `docs/evidence/driving-tests.txt`.

Restart with F8 then F5; try 2/Balanced, launch down the braking lane, then brake into a circle and accelerate out. The compact yard limits sustained top-speed driving; the top-speed measurement uses the isolated simulation without walls. Owner feel evaluation and physical Android testing remain pending.

## Owner corner-speed iteration (handling-0.5)

G01: `vehicle_simulation.gd` previously removed lateral velocity without redirecting its energy, causing excessive corner scrub. Grip now redirects 85% of the removed lateral energy into signed longitudinal motion, before pedals and resistance. This is an arcade energy-retention rule, exposed as `corner_energy_retention` in `handling_config.gd`; zero reproduces the previous calculation. Retention fades for broadside slides and preserves reverse direction. Braking, drag and collision loss are not refunded. Physics identity is now `arcade-planar-0.3`; old physics captures are not equivalent to this build.

Actual Windows `scripts/dev.ps1 Validate`: import, 17 parses, startup and 53 checks pass. A 108 km/h start with 0.6 steering and no throttle for one second ends at 103.7 km/h versus 95.1 with retention disabled. Forward velocity also improves. A 1,200-tick steering/recovery check confirms no energy gain without throttle. Existing braking, speed caps, recovery, collisions and exact same-engine replay pass. Acceleration remains 2.13 seconds to 100 km/h and top speed 165.6 km/h. Half-throttle quarter-turn radii at initial 43/65/86 km/h become 8.75/12.71/19.58 m because the car carries more speed; all remain substantially tighter than the original handling. Evidence: `docs/evidence/driving-tests.txt`.

Restart F8 then F5, select Balanced and compare a sustained turn under throttle against a lift through the same corner. Check that it carries speed without feeling like steering supplies a boost. Physical Android and subjective owner acceptance remain pending.

## Owner balance correction (handling-0.6)

G01: owner found retention excessive and sliding too strong. Reduced corner energy retention from 0.85 to 0.50; increased Balanced lateral grip 45 -> 50, rear grip 0.95 -> 1.0, slide grip 0.85 -> 0.92 and lateral response 14 -> 17. Reduced throttle rotation 0.35 -> 0.20 and throttle grip loss 0.12 -> 0.07. Stable/Loose also receive stronger grip, while Loose retains its more playful balance. Changes are in the handling Resource defaults and preset Resources; simulation algorithm stays arcade-planar-0.3.

Actual `scripts/dev.ps1 Validate` passed import, 17 parses, startup and 54 checks. The 108 km/h one-second coasting turn now ends at 101.2 km/h, versus 103.7 in handling-0.5. With the new grip but retention disabled it ends at 97.4. Powered corner slip falls from 27.0 to 13.1 degrees; lifting yields 4.7 degrees. Tight-turn radii at initial 43/65/86 km/h are 8.63/11.66/16.27 m. Acceleration/top speed stay 2.13 seconds to 100 km/h and 165.6 km/h. The retention regression now requires both an improvement over disabled retention and at least 6 km/h speed scrub, explicitly reflecting the owner's corrected target. Added a powered-slip upper bound; recovery, no-energy-gain, braking and replay invariants still pass. Evidence: docs/evidence/driving-tests.txt.

Restart F8/F5, select Balanced and repeat a sustained powered turn followed by lifting. Expect noticeable speed scrub and a more planted rear. Subjective acceptance and physical Android tests remain pending.

## Speculative analysis tune (handling-0.7 / arcade-planar-0.4)

G01: inspected the owner-supplied speculative analysis. Accepted fast input-to-heading response, slower trajectory response, nose-directed acceleration, natural countersteering and progressive grip. These are prototype hypotheses, not independently verified original-game physics. Existing world-space momentum, weak coast drag, explicit speed cap and decisive brakes already cover several recommendations.

Changed steering response 12 -> 30 /s (full input in 33 ms) and yaw inertia 850 -> 500. Disabled added throttle rotation, throttle grip loss and automatic countersteer assistance in all three presets; optional tuning fields remain available. Replaced binary slip-threshold grip selection with a smooth interpolation over one to two times the configured slip threshold. Kept speed-sensitive steering, no stationary rotation, current grip strength and 50% corner-energy retention to preserve the owner's recent less-slide/moderate-scrub preference. Did not adopt the proposed 0.90?0.97 lateral retention per 60 Hz tick, which would greatly increase sliding versus this tune. Surface expansion and changing braking to act along the velocity vector are deferred; this pass targets steering and slide generation.

Actual Validate: import, 17 parses, startup and 56 checks pass. New checks verify a 50 ms tap rotates the chassis before the trajectory catches up, and throttle pulls a seeded slide toward the nose without auto-yaw. Replaced the old test demanding throttle-induced rotation because that behavior is deliberately disabled. Powered corner slip is 10.0 degrees versus 13.1 previously; coasting turn from 108 km/h ends at 100.6. Acceleration/top speed remain 2.13 seconds to 100 km/h and 165.6 km/h. Recovery, brakes, no steering-generated energy, collisions and same-engine replay pass. Radius comparisons use legacy parameters under the current algorithm, not playback of the old physics version. Evidence: driving-tests.txt and inspected scripted Windows capture driving-momentum.png under docs/evidence.

Restart F8/F5, select Balanced, tap steering briefly at 60?80 km/h, then try turn-in / lift / unwind / throttle. Expect the nose to respond quickly and the path to follow with a short delay. This still needs owner evaluation; no original-game handling equivalence or Android test is claimed.

## Smaller car and faster turning ? 2026-09-12

G01 / V01 owner feedback: the tracks still did not feel fun; car slightly too big and too slow to turn. Handling-0.8 scales the physical car to 88%: base body 3.74 x 1.584 m, wheelbase 2.244 m, circular collision radius 1.364 m. Shared BODY_SCALE drives car mesh, wheelbase/collision defaults, rear skid axle/spacing and mark width. This is the owner's explicit physical-size adjustment, not the earlier 1.15 camera-calibration operation. Camera, roads and source package remain unchanged. The reference 9 m road now spans about 5.68 body widths rather than five.

Steering angle increases 0.60 -> 0.65 rad, yaw limit 2.2 -> 2.7 rad/s, Balanced lateral grip 50 -> 58 m/s?; Stable/Loose grip 60/50. Quarter-turn radii at initial 43/65/86 km/h improve from 7.87/10.62/14.84 m to 6.38/8.73/12.40 m. Powered corner slip is 13.0 degrees (within the existing 18-degree guard); acceleration/top speed remain 2.13 s to 100 km/h and 165.6 km/h. Single-circle body approximation remains a limitation.

Actual `scripts/dev.ps1 Validate`: first attempt crashed natively during parsing (exit -1073741819); fresh invocation passed all 23 parses, startup, 56 driving checks and 48 track checks. All four diagnostic AI runs completed three laps with zero contacts and replay checks passed. No failed handling invariant was relaxed: the island overlap check now uses the configured physical radius, and the legacy steering comparison explicitly retains its original wheelbase. Graphical FREEWAY launch/capture succeeded and was inspected: docs/evidence/smaller-car.png. Updated driving and track evidence retained. No Android test was performed; human fun/handling acceptance remains open.

Restart the running project from the editor, select FREEWAY with the Track button/F5, then choose 2/Balanced. Try turning into its tight bends and switching left/right; compare available clearance and whether the car turns soon enough without sliding wide. F5 inside the running game selects tracks.

## Collision rebound - 2026-09-12

G01 owner feedback: impacts should visibly bounce instead of feeling like a full stop. Handling-0.9 increases the shared restitution parameter from 0.12 to 0.38. Solid walls, islands and bridge rails use the same response. This returns 38% of impact-normal speed; glancing impacts retain their existing tangential momentum damping. No minimum kick or extra energy is added, so gentle taps remain mild. Soft terrain remains a speed penalty.

Changed runtime file: `game/vehicle/handling_config.gd` (version and restitution only). `game/tests/test_tracks.gd` adds actual post-impact travel under held throttle and glancing-impact energy/direction checks. The existing resolver, ramp recovery, physics identity arcade-planar-0.7, track content and schema remain unchanged; no golden-content migration is needed. All three handling presets inherit the new restitution. Status, plan and test evidence accompany this update.

Before tuning, `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTracks` failed both new rebound checks: the held-throttle impact moved away only 0.183 m, with initial rebound speed 9.34 km/h. Existing track checks passed. The comparison test retains the old restitution as an explicit baseline; no existing invariant was weakened.

Actual final `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: pinned Godot 4.7.2 passed import, 24 parses, startup, 56 driving and 96 track checks. The powered head-on test starts at 72 km/h and accelerates until impact: rebound speed increases to 29.56 km/h and maximum separation over the following 0.5 s grows from 0.183 to 1.443 m. Glancing collision retains over 14 m/s of an 18 m/s tangent component while reflecting outward and losing energy. All four tracks still complete three zero-contact AI laps with identical lap times and exact JSON replay; reverse escape from ramp rails still passes. `git diff --check` passed. Evidence: [before](evidence/bounce-before.txt), [track tests](evidence/bounce-tracks.txt), [driving tests](evidence/bounce-driving.txt).

Close and relaunch the game to load handling-0.9. Try a medium-speed head-on impact and a shallow glancing scrape, with throttle held and released. Rebound strength remains a tuning proposal; subjective feel and low-speed taps need owner evaluation. Validation was headless movement/energy/replay testing, not an observed manual driving session or a new visual asset/UI change. No phone test, APK export or device performance measurement was performed.

## Impact rotation and stronger recoil - 2026-09-12

G01 owner feedback requests both body-direction changes in collisions and a bigger bounce. Handling-0.10 sets restitution to 0.55 (previously 0.38) and adds collision_turn_strength=0.45. The shared bounce response now applies an angular impulse based on impact speed and the car's front/rear and side alignment. Actual heading changes through the existing fixed-step yaw integration; mirrored impacts turn in opposite directions. Centred head-on hits still rebound without an arbitrary spin. The circular collider has no precise contact lever arm, so this is a bounded arcade approximation. Added angular energy is limited to the impact's available energy loss, and angular speed remains capped by maximum_yaw_rate.

The reverse-speed cap previously clipped strong recoil on the next tick. Existing backwards momentum can now exceed the powered reverse limit and dissipate through drag/braking; the reverse pedal cannot add speed above its cap or sustain overspeed recoil. Normal powered reverse stays capped at 7 m/s. No new state fields, art, camera changes or external dependencies were introduced.

Changed files: game/track/playground_data.gd (shared angular collision response), game/vehicle/handling_config.gd (new tuning/version), game/vehicle/vehicle_simulation.gd (recoil preservation and physics arcade-planar-0.8), game/tests/test_tracks.gd (heading, energy, symmetry, stronger rebound and reverse-limit regressions). Track schema/content and golden fixtures remain unchanged. New handling settings are included by the existing diagnostic snapshot mechanism.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTracks` reproduced zero heading change before the fix. It reported four expected angular-response failures plus one newly authored centred-hit fixture whose normal was incorrectly oriented; that fixture's normal was corrected to face the incoming car. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` then passed import, 24 parses, startup, 56 driving + 107 track checks on pinned Godot 4.7.2. Existing invariants were retained; the rebound-distance guard was strengthened from 0.6 m to 2.5 m. `git diff --check` passed.

Measured 45-degree impacts rotate the actual heading by mirrored +/-9.369 degrees over 0.2 s, with bounded yaw and reduced total translational-plus-rotational kinetic energy at impact. The powered head-on test rebounds initially at 42.79 km/h and reaches 3.736 m separation during the next 0.5 s, compared with 1.443 m in the preceding 0.38-restition implementation. All four three-lap AI runs retain their lap times, zero contacts and exact JSON replay; ramp escape remains successful. Evidence: [before](evidence/impact-turn-before.txt), [track results](evidence/impact-turn-tracks.txt), [driving results](evidence/impact-turn-driving.txt).

Close and relaunch to load this version. Manual acceptance: try oblique wall/rail contacts from both sides and compare the stronger rebound at different speeds. High-speed impacts intentionally recoil farther; subjective strength remains tunable. These are headless trajectory/heading measurements, not an observed manual driving session or a new visual asset/UI change. No physical-phone test, APK export or device performance measurement was performed.

## Sustained wall sliding - 2026-09-12

G01 owner feedback: under throttle against an oblique barrier, keep moving along it and gradually align the nose. NativeTrack now sweeps the remaining tangential displacement after a blocked step; every candidate still checks occupied cells and layer continuity. PlaygroundData blends low inward-speed rubbing into full impact response over 0-2 m/s. Rubbing retains tangential momentum and applies gentle, energy-budgeted alignment; hard hits retain the existing restitution and angular impulse. No new simulation state, track schema or content changes. Handling-0.11 / arcade-planar-0.9 identify the behavior change.

Changed runtime files: game/track/native_track.gd, game/track/playground_data.gd, game/vehicle/handling_config.gd and game/vehicle/vehicle_simulation.gd. game/tests/test_tracks.gd adds powered standstill wall-contact checks in both travel directions, nonpenetration, actual heading alignment and exact replay. Status/plan and evidence accompany the change.

Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTracks`: 115 checks, zero failures. From rest at 45 degrees into the wall, holding throttle for 3 seconds travels 8.918 m along it and aligns to 0.934 degrees from parallel in both directions. Initial hard-impact rebound remains 3.736 m. Four fixtures complete three AI laps with zero contacts; ramp escape and replay checks pass.

The circular collider and angle-based torque remain arcade approximations. Exactly square-on contact has no preferred sliding direction; steer to select a side. Close and relaunch the game, then try the pictured angled scrape with throttle held, steering away, and reverse. Owner feel acceptance remains pending. No new art/UI change or manually observed driving capture; tests measure simulation trajectories. No physical-phone test or APK export was performed.

Final validation: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` passed import, 24 script parses, startup, 56 driving and 115 track checks (171 total). The import reports missing Android build-tools; no Android validation is claimed. `git diff --check` passed. Evidence: [track results](evidence/wall-slide-tracks.txt), [driving results](evidence/wall-slide-driving.txt).

## Moderate recoil - 2026-09-12

G01 owner feedback: recoil is now a bit too strong. Handling-0.12 reduces restitution from 0.55 to 0.45, an 18% reduction in returned normal speed. Wall sliding/alignment and impact turning algorithms remain as implemented in physics arcade-planar-0.9. Changed game/vehicle/handling_config.gd and the existing rebound acceptance in game/tests/test_tracks.gd: the earlier minimum 2.5 m represented the superseded larger-bounce request; the new 1.5-3.0 m band requires a visible but moderated rebound, with an upper bound that rejects the previous 3.736 m result. Energy, collision, lap and replay invariants are retained.

Manual acceptance: close and relaunch, then compare the same angled and head-on impacts and a sustained powered wall scrape. This parameter-only change has no new UI/art. Physical-phone testing and owner feel acceptance remain pending.

Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: import, 24 parses, startup and all 171 checks passed (56 driving, 115 track). Powered head-on separation falls from 3.736 to 2.658 m (29% shorter), initial recoil from 42.79 to 35.01 km/h. Wall starts travel 9.93/10.67 m in 3 seconds and align within 0.96 degrees in both directions. All four three-lap AI runs retain zero contacts and exact replay; ramp recovery passes. `git diff --check` passed. Evidence: [tracks](evidence/moderate-recoil-tracks.txt), [driving](evidence/moderate-recoil-driving.txt). Android build-tools remain unavailable; no phone test or APK export occurred.

## Tire contamination and softer recoil - 2026-09-12

G01 owner feedback: further reduce collision recoil and retain a short-lived grip penalty after driving on grass or sand. Handling-0.13 sets restitution to 0.30 (from 0.45). The head-on regression now accepts 0.5-1.8 m separation, reflecting the new owner balance target while retaining a visible bounce and adding an upper bound that rejects the prior 2.658 m result. Wall-slide/alignment behavior is retained.

Physics arcade-planar-0.10 adds tire_dirt (0-1) to canonical state. Native material 1 (grass) deposits half as fast as material 2 (dirt/sand). Full coating takes 40 m on grass or 20 m on dirt. Actual resolved movement drives both accumulation and recovery; standing still does neither. Non-depositing surfaces gradually remove a full coating over 80 m, in either travel direction. At 20 m/s, half/full coatings clear in approximately 2/4 seconds; at 16 m/s a full coating takes 5 seconds. A tiny excursion can clear sooner, and crawling takes longer: there is deliberately no elapsed-time expiry. Exposure saturates at 1, and resetting the simulation restores clean tires.

Contamination progressively reduces lateral response, lateral grip limit and longitudinal traction by up to 25%, in addition to the existing current-surface grip/resistance. It affects grip after returning to asphalt without artificially applying off-road rolling drag there. This remains a single body-centre surface sample and aggregate tire condition, not a per-wheel mud model. No new tire graphics or UI were introduced.

Changed files: game/vehicle/handling_config.gd, vehicle_state.gd and vehicle_simulation.gd; game/track/playground_data.gd and native_track.gd (native material pickup query); game/persistence/handling_recorder.gd; game/tests/test_tracks.gd; status/plan and evidence. Diagnostic manifest schema is now 3: the state array appends tire_dirt at index 13, leaving indices 0-12 unchanged. Consumers must honor schema/physics identity; old captures are historical diagnostics, not compatible current-physics replays. There is no persisted gameplay save migration or native-track content/schema change.

Manual acceptance: close/relaunch, drive briefly then longer on grass/dirt, return to asphalt and compare turn-in/braking through the following 40-80 m. Try the same wall impact and powered scrape. Owner feel acceptance and physical-phone testing remain pending; no APK export or manual graphical driving session was performed.

Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: import, 24 parses, startup, 56 driving and 133 track checks pass (189 total). Head-on recoil is 23.34 km/h initially and 1.186 m separation, versus 35.01 km/h and 2.658 m previously. Wall sliding travels 5.680 m in 3 seconds in both directions and aligns within 0.979 degrees. Added tests verify material/distance-based pickup, longer exposure, asphalt carryover, stationary behavior, clean reset, 80 m recovery at 10/20/-20 m/s, lateral/braking traction loss and repeatable full contamination snapshots. Full coating clears in 4.008 s at 20 m/s and 8.008 s at 10 m/s (one-tick quantization). All four fixtures complete three zero-contact AI laps with exact full JSON replay; OFFROAD times change slightly to 29.498/28.561/28.566 s as expected with surface memory. Ramp recovery and layer tests pass. `git diff --check` passed. Evidence: [track results](evidence/tire-dirt-tracks.txt), [driving results](evidence/tire-dirt-driving.txt). Android import still reports missing build-tools; no phone test or APK export occurred.
