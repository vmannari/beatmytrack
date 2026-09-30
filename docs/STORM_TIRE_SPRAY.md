# Storm tire spray (2026-09-30)

Requirements: V01/V02/V04/V05/Q01; owner requests tire water spray during wet-road driving.

All four tires emit a short low mist fan and finer droplets on Storm asphalt, including elevated road surface cells. Ordinary straight driving emits without throttle, braking or drifting; intensity rises smoothly between 1.5 and 22 m/s using each tire's contact velocity. Wheelbase/track width come from the selected vehicle, as in existing tire effects. Fans follow opposite contact travel with an outward component that remains correct in reverse. Existing bridge presentation supplies contact height.

Surface checks are per wheel. Non-road terrain, dry biomes, jumps, rolls and stopped vehicles do not emit water spray. Existing particles briefly finish their flight after leaving the road. Pause freezes water simulation through speed_scale; restarting and confirmed rewind clear the effect, and rewind hiding also covers the new child emitters. Existing dust/snow/smoke behavior remains in the shared effect system; restart now clears all effect particles as well as tire trails.

Allocation is lazy on Storm driving: four mist emitters (72 particles each, 0.55 s lifetime) and four droplet emitters (96 each, 0.38 s), capped at 672 particles. World-space GPU particles use the existing soft billboard material and 120 Hz particle cadence to avoid separated batches at road speed. No particle shadows, downloaded assets, added dependencies or simulation changes.

Changed files: game/vehicle/sand_dust.gd (emitters, wheel sampling, freeze/cleanup), game/core/game.gd (pause/restart integration), game/tests/test_storm.gd (behavior checks and capture), status/phase notes and this document/evidence. Unrelated pre-existing game/headlight changes remain separate from this checkpoint.

Actual commands, through pinned Godot 4.7.2 with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42`: final **88 checks, zero failures**, no shader/script errors. Includes unchanged state snapshot, lazy dry-theme allocation, straight rolling, speed response, seven non-road surfaces, bridge-deck emission, reverse direction and outward fan, all five car widths, independent road-edge wheels, stationary/airborne/roll suppression, pause/resume and restart/rewind clear. Existing wet handling/replay/weather checks pass.
- `TestDesert`: **53 checks, zero failures** in the shared tire-effect system.
- `git diff --check` and `git diff --cached --check`: pass (line-ending notices only).

[Driving spray](evidence/storm-tire-spray/driving.png) / [Later position](evidence/storm-tire-spray/driving-later.png), both inspected. The graphical harness moves a presentation state at 18 m/s on the actual Storm creator-road fixture while holding race simulation paused; the HUD consequently shows paused/zero speed. These are real GPU-particle captures, not a completed or timed lap.

No Android export or physical-device test performed; device attachment was not checked. Owner in-motion acceptance, mobile GPU/overdraw/frame pacing and dedicated bridge-height imagery remain outstanding. Desktop tests do not establish physical-phone performance.
