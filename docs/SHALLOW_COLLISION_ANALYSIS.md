# Shallow collision analysis — 2026-10-07

Requirement: **G01**, active driving feel and recoverable contact. Scope is diagnosis and a proposed handling iteration. Shipping physics, tuning, collision geometry, replay identities and backend are unchanged.

## Findings

Three interacting problems explain abrupt low-angle contacts: disproportionate tangential speed loss, false blocking during the slide sweep, and cell-based surface normals. The diagnostic reproduces these in the shipping collision classes; this is stronger evidence than a subjective tuning guess, but does not identify which obstacle the owner's particular collision hit.

### Current response

`VehicleSimulation.step()` runs at 120 Hz. It updates steering, tyres and pedals, attempts movement, then calls `NativeTrack.resolve()`. The car footprint is one orientation-independent circle; the compact radius is 1.364 m. Native solid geometry uses occupied grid cells, including solid scenery and upper bridge rails. Resolution samples movement in increments no longer than 45% of a cell, stops at the last accepted position and sweeps the remaining projected tangential displacement.

The shared `PlaygroundData._bounce()` splits velocity into wall-normal and wall-tangent components. Its crash blend is `smoothstep(0, 2 m/s, inward_speed)`. With the usual `collision_energy_loss = 0.35`, tangent speed is multiplied by `sqrt(1 - 0.35 * blend)`. Recoil returns 30% of inward speed, also multiplied by the blend. Chassis yaw uses an approximation from the heading and wall normal because the circle has no contact lever arm; gentle contact blends yaw 25% toward wall alignment. Every inward response increments `collision_count`, including rubbing, with no separate scrape event.

This scales tangential loss with *all* tangential kinetic energy, even when very little energy points into the barrier. Once inward speed reaches 2 m/s, a single contact removes 19.38% of tangent speed. At 108 km/h that threshold is only 3.82° from the wall tangent; at 144 km/h it is 2.87°. Formula and kart have larger authored collision losses (0.52 and 0.45), giving maximum tangent losses of 30.72% and 25.84% respectively.

Measured compact response at 108 km/h, with velocity initially aligned with the chassis:

| Angle from wall tangent | Inward speed | Tangent speed lost in one contact |
| --- | ---: | ---: |
| 0.5° | 0.262 m/s | 0.82% |
| 1° | 0.524 m/s | 3.02% |
| 2° | 1.047 m/s | 9.85% |
| 3° | 1.570 m/s | 16.84% |
| 5° | 2.615 m/s | 19.38% |

Repeated contact compounds the loss. The blend is smooth, but its chosen range is too narrow to represent gentle racing-speed brushes.

### Slide sweep can erase velocity against the same wall

`NativeTrack._contact()` sums penetration-weighted normals of cell rectangles. Even a continuous axis-aligned wall can acquire a small sideways normal near a cell corner. `resolve()` uses this normal to project the slide. If that candidate still overlaps, it requires either a narrowly axis-aligned normal and existing overlap with safe escape, or it enters the second-blocker safeguard. That safeguard removes uncompleted tangent speed and can zero the whole velocity.

The safeguard is valuable for real corners, but these probes show it also rejecting the same wall. On the **current creator 0.5 m grid**, a 2° coasting brush starts at 108 km/h. At tick 17 (about 0.15 s into the run), the response normal is `(-0.9999901, 0.004446)`. `_bounce()` sees outward motion, so leaves 26.089 m/s unchanged; the remainder of `resolve()` reduces it to **0.025 m/s**. Final one-second speed is effectively zero after only 3.796 m of travel, versus 29.619 m without the wall. The response needs no new inward crash to cause this stop.

The 0.25 m regression grid also reproduces it: a 2° coasting scrape loses almost all 27 m/s at tick 4. The actual bounce only loses about 0.01 m/s on that tick; the slide safeguard removes the rest. A 3° powered scrape on the current 0.5 m grid finishes the one-second trace effectively stopped after 2.001 m, despite held throttle.

### Diagonal walls exaggerate the angle

Rasterized diagonal faces present changing cell-corner normals. In the 0.5 m grid's 30° wall test, a nominal 0.5° brush encounters normal `(-0.843780, -0.536690)` and **1.547 m/s** inward speed, instead of the ideal face's 0.262 m/s. That first contact drops speed from about 29.982 to 24.976 m/s. On the finer 0.25 m grid a corresponding brush encounters 7.436 m/s inward speed. These are specific grid phases, not average behaviour or proof that finer grids are universally worse. They demonstrate sensitivity to position and raster alignment.

### Feedback amplifies these responses

`game/core/game.gd` routes a collision-count increase to camera shake, suspension, glass damage and impact audio using total post-step minus pre-step velocity. That delta includes ordinary steering/braking effects and tangential scrub, rather than a dedicated collision impulse. Camera and suspension start above 2 m/s change; impact audio above 1.2 m/s; glass above 7 m/s. A shallow scrape with excessive scrub can consequently feel and sound like a crash. Conversely, a slide-safeguard stop without an inward response can occur without incrementing the count. Tyre stacks use their own mass-based normal impulse solver, and light props use a separate capped impulse: the shared solid-wall formula does not apply to every obstacle.

## Recommended implementation order

1. **Repair same-wall sliding.** Identify a continuing supporting face, handle numerical contact with a small deterministic tolerance/separation, and preserve motion along that face. Remove only motion into a genuine new blocker. Keep swept corner/rail-tip checks, reverse escape and prevention of stored blocked speed. Increasing the flat-normal threshold alone will not fix diagonal contact.
2. **Stabilize face normals.** Prefer authored object edges or coherent exposed solid contours where available; merge coplanar faces into one support. Do not globally average through real corners or bridge ends. Keep collision geometry authoritative and verify that smoothing cannot let the footprint cross a blocker.
3. **Make scrape friction proportional to contact strength.** A bounded tangential impulse such as `tangent_speed_loss <= friction_coefficient * normal_velocity_change` charges a shallow brush according to its small inward impulse. For illustration only, coefficient 0.15 gives roughly 0.18 m/s (0.6%) tangent loss for the measured 2° compact brush, versus the current 2.95 m/s (9.85%). That number is a proposed audition value, not approved tuning. Continuous pressure must still create resistance, so holding throttle into a wall cannot become a speed advantage. Retain a separately tuned, smooth transition to damaging oblique impacts and head-on rebound; lowering restitution alone mainly reduces recoil and leaves both primary faults intact.
4. **Distinguish scrape feedback from fresh impact.** Gentle contacts should give restrained rubbing audio and body movement; major impact shake/cracks should follow an actual collision impulse. Make alignment gradual and bounded in seconds, preserving steering away. Keep the circle footprint for this focused iteration; a new oriented collider is a larger handling/geometry change and unnecessary to fix the demonstrated faults.

Acceptance should cover 0.1–5° contact at 36–144 km/h, left/right symmetry, coasting/throttle/braking/reverse, all five vehicles, 0.25/0.5 m grids, wall rotations and translations, seams, solid scenery, tyre piles and bridge tips. Require continuous sliding without arbitrary stops, non-increasing total energy, no wall tunnelling, immediate release when steering away and no artificial exit surge. Finish with owner driving, a physical Android test and full replay/regression checks. A shipping physics change needs a new pinned physics identity and matching verifier rollout; existing records must remain in their historical contracts.

## Actual verification and files

Added `game/tests/analyze_shallow_collisions.gd`: 180 isolated response cases across five cars and four speeds; 60 one-second native wall scenarios, each replayed twice; an observing subclass records bounce normals and before/after velocities without modifying the response. File output happens after simulation. Results are retained in `docs/evidence/shallow-collisions-2026-10-07/measurements.json` and command logs. The 2 cm inward normal sample is supplementary and is **not** the exact normal used by the resolver; `events[].bounce_calls` contains actual response normals. Synthetic walls start just clear of contact, on clean asphalt without steering input; they do not recreate a specific saved player run.

Actual commands:

```powershell
# Isolate test data from player saves; use distinct roots per command.
$env:APPDATA = Join-Path $PWD 'build/shallow-collision-analysis/userdata-probe'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/analyze_shallow_collisions.gd
$env:APPDATA = Join-Path $PWD 'build/shallow-collision-analysis/userdata-tracks'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestTracks
```

Pinned Godot `4.7.2.stable.official.ed1daf0bf`: final diagnostic **14,820 checks / zero failures / command exit 0**; existing TestTracks **167 checks / zero failures / command exit 0**, including four historical three-lap exact replays. The diagnostic checks finiteness, energy, mirroring and repeatability; passing these does **not** approve collision feel. Existing from-rest rubbing tests pass while these racing-speed defects remain.

Initial direct PowerShell invocation was blocked by execution policy. Sandboxed engine runs were blocked by player-log and Windows certificate-store access. Isolated-data runs outside the sandbox succeeded. The first complete, uninstrumented diagnostic reported checks passed but failed the wrapper on shutdown resource leaks; subsequent instrumented runs and the final two-grid diagnostic exited cleanly. No failing invariant was removed.

Changed files: the diagnostic, this report, retained JSON/two final logs, and a summary entry in `DEVELOPMENT_STATUS.md`/`docs/PHASE_0_PLAN.md`. No runtime UI change, so screenshots were not produced. No phone attachment check, device test, export/install, backend action or physics implementation was performed. Proposed fixes and owner/device feel acceptance remain open. Existing unrelated workspace changes are preserved; this is a scoped diagnostic checkpoint, not a merge of the mixed workspace.
