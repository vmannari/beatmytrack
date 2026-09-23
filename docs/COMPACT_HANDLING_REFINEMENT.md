# Compact driving-feel comparison — 2026-09-19

## Scope and requirements

Owner request: refine the compact for a little more drifting while keeping it accessible, intuitive and fun, then retain the result as another option for comparison. Requirements **G01/R01/R03/R07** apply: responsive recoverable handling, quantized controls, deterministic simulation and handling-specific records/replays.

The new compact-only **Drift+** option is separate. Original+ is restored unchanged and remains the startup default; Original and the other four vehicles are unchanged.

## Tune and selection

After the owner requested a midpoint between Original+ and the strong rear-drive revision, `game/resources/compact_fun.tres` now defines `handling-0.19-compact-rwd`, still displayed as **Drift+**. This is an accessible arcade approximation rather than an axle/limited-slip differential simulation. Relative to Original+, lateral grip changes 54 → 52 m/s², lateral response 14 → 12.5 /s, slide threshold 0.26 → 0.21 rad and sliding grip 0.92 → 0.88. While steering, throttle adds 0.25 rad/s of bounded rotation and up to 8% cornering grip loss. Coasting does not apply either effect, so the car remains calmer off power. Steering onset remains calmer at 24 input/s and grip recovery increases 5 → 8 /s so unwinding settles the slide quickly.

The handling popup lists Drift+ beside Original+, Original, Planted, Balanced and Playful. Selecting any entry restarts the current attempt as before. Debug comparison supports key **6** for Drift+. Original+ remains index 4/default, so existing startup behavior does not silently change.

Engine force, maximum speed, braking, longitudinal grip, throttle pull, steering angle, yaw limit, collision response, physical dimensions, surfaces and camera are unchanged. The fixed 120 Hz simulation algorithm and physics identity remain `arcade-planar-0.29`; Drift+'s distinct resource snapshot/version gives it a separate record key, preserving old PB data without comparing it to the new tune.

## Measured behavior and verification

The final 24 m/s, 0.8-steering, full-throttle 100-tick maneuver measures **29.46°** in Drift+, between **17.61°** in Original+ and **39.18°** in the rejected stronger Drift+ revision. The regression now enforces a 25–32° midpoint band. In a separate 0.6-second corner, full throttle produces **12.73° slip and 62.38° heading change**, while coasting with identical steering produces **7.34° and 52.78°**. This retains clear power oversteer without the previous large angle. The slide settles below 0.03 rad after unwinding. A ten-second full-throttle/full-lock stress run remains bounded at **19.04 m/s and 33.23°**, below a broadside spin.

Commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.

- `TestHandling`: **88 checks passed**. It covered frozen Original+ identity, power-on versus coast slip/rotation, explicit recovery, the full-lock bound, energy rules, exact replay for all six presets and four Original+ diagnostic tracks.
- `TestDriving`: **74 checks passed**, covering default Original+ selection, separate Drift+ presence, direct Drift+ switching in race and practice, input lifecycle, recovery, bounds and exact replay. The final run emitted a two-instance ObjectDB shutdown warning.
- `CaptureHandling`: passed. The updated 1672×941 selector capture was inspected: all six choices fit without clipping, Drift+ is first, and Original+ remains selected. Evidence: `build/handling-selector.png` (generated workspace evidence, not a shipping asset).
- `TestCars`: the earlier handling run completed all 15 five-lap runs with zero contacts and exact replays. The command exited 1 at **91/95 checks** because existing detailed-model child-count assertions failed for pickup, classic, Formula and kart after earlier visual batching. Compact's corresponding check passed; these unrelated assertions were not weakened.
- `TestTracks`: **167 checks passed**; all four legacy diagnostic circuits completed three laps with zero contacts and the collision, bridge, surface and tyre regressions passed.
- `TestCarBalance`: **1 check passed**. The previously measured Drift+ compact result was 4.558 s on the 18 m skidpad; Formula remained ahead at 3.608 s.
- `git diff --check`: passed with line-ending conversion warnings only.

Subjective fun, touch comfort and recovery still require owner driving. No phone/device test or APK export was performed; attachment status was not checked. Cross-device float determinism is not claimed.
