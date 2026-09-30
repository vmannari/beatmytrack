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

## Owner correction: remove clouds and bright road streaks

The owner rejected both kit 93's bright road pattern and the expanding tire mist. Kit 94 restores the kit 91 surface include, creator/terrain material response and bridge wet response, preserving the independently modified bridge Lambert mode. Added reflection emission, road rings and their weather shader global are removed. The preferred neutral charcoal texture and shared Grass edge treatment remain. This explicitly supersedes the stronger wet-reflection experiments; it is not a claim that the original reference's wetness has been matched.

WaterMist emitters are removed entirely. Four droplet-only emitters now have 56 particles each (224 allocated instead of 672), lifetime 0.24 s, bead size 0.04 x 0.10 m, opacity 0.48, no size-growth curve, downward gravity 9.8 m/s2 and lower launch speeds 1.2-3.2 m/s. Emission reaches at most 60%, rising over 3-26 m/s. A dedicated filtered elliptical bead shader replaces the smoke haze material. No expanding puffs remain. Wheel surface gating, reverse/outward fan direction, five-car spacing, pause and clear behavior are retained.

Changed: game/track/surface_detail.gdshaderinc, creator_road.gdshader, terrain.gdshader, bridge_road.gdshader, native_track_visual.gd and storm_weather.gd; game/project.godot; game/vehicle/sand_dust.gd and new water_drop.gdshader; game/diagnostics/surface_material_probe.gd; game/tests/test_storm.gd; status/phase notes and these docs/evidence.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42`: final **85 checks, zero failures**, no shader errors. Three per-material assertions for the removed radiance helper are removed with that owner-rejected feature; wet binding and all behavioral physics/spray tests remain. Spray tests target the remaining droplet emitters.
- `TestSurfaceProfile`: **928 checks, zero failures**, no shader errors.
- `git diff --check` / `git diff --cached --check`: pass.

[Restored road](evidence/storm-correction/road.png) / [Reduced droplets](evidence/storm-correction/droplets.png) / [Later position](evidence/storm-correction/droplets-later.png), inspected at gameplay framing. The same controlled 18 m/s presentation harness is used; paused/zero-speed HUD is expected. No physical-phone test or export; attachment was not checked. Owner in-motion acceptance and mobile performance remain outstanding.
