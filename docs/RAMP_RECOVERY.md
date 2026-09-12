# Ramp collision recovery — 2026-09-12

Requirements: G01 controllable handling/collision recovery; G02/R03 crossing and lap preservation; R01 versioned deterministic simulation.

## Observed failure

Inspected the owner's running `CIRCUIT / 01 (DEBUG)` window using PowerShell/Win32 `PrintWindow`. The [live screenshot](evidence/ramp-stuck-live.png) shows 1WAY at the ramp entrance, beside a rail, with 281 contacts and a displayed reverse speed of 1.75 m/s. No restart or driving input was sent to that instance. Its exact numerical simulation state was not available; the automated fixtures reproduce the same overlap condition on native bridge geometry rather than claiming to replay the owner's exact drive.

The resolver rejected every overlapping candidate position, including movement away from a rail already intersecting the car's circle. It restored the previous position while retaining outward velocity, so speed could be displayed with no movement. A second issue allowed a step to be collision-tested on the old layer and then committed on the new layer, creating an upper-rail overlap at entry.

## Correction

`game/track/native_track.gd` now checks the candidate route/layer at every swept substep before committing position and layer together. Existing overlaps permit outward movement only when total penetration decreases and no individual occupied cell's penetration increases (one-micrometre tolerance). This lets a car back out while preventing recovery from pushing into another wall. Contact depth remains detectable when opposing normals cancel. There is no forced position jump or reset.

`game/vehicle/vehicle_simulation.gd` advances physics identity to `arcade-planar-0.7`. Track data, surfaces, checkpoint order, ramp presentation, handling configuration and camera are unchanged. No native schema or golden-content refresh is necessary; recording already includes the physics identity.

`game/tests/test_tracks.gd` adds real-track overlap/held-reverse/replay checks for all three bridge fixtures, a swept layer-entry test, immediate retreat after rejected entry, and rejection of a second barrier during overlap recovery. Status, plan and this evidence accompany those three code changes.

## Actual verification

Commands used the pinned Godot 4.7.2 through the repository wrapper:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTracks` before the fix: 82 checks, **three failures**. Outward movement was exactly zero on 1WAY, 66 and OFFROAD. [Before log](evidence/ramp-recovery-before.txt).
- Focused `TestTracks` runs during implementation verified outward movement and then full reverse clearance. An initial 66 reverse fixture had another solid footprint blocking its exit; fixtures now explicitly require an unobstructed exit, while a separate test requires an obstructed exit to stop. The synthetic layer-entry fixture was also corrected to keep its route tangent on the ramp. Existing lap, thin-wall, surface, replay and ramp-height assertions were retained.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: **24 parses, startup, 56 driving checks and 94 track checks passed**. [Driving log](evidence/ramp-recovery-driving.txt), [track log](evidence/ramp-recovery-tracks.txt).
- `git diff --check`: passed.

| Native overlap fixture | Reverse time from rest, including hold delay | Distance until fully clear of the upper rail | New contacts |
|---|---:|---:|---:|
| 1WAY | 99 ticks / 0.825 s | 1.006 m | 0 |
| 66 | 82 ticks / 0.683 s | 0.506 m | 0 |
| OFFROAD | 106 ticks / 0.883 s | 1.262 m | 0 |

Each escape replay matched exactly in eight-tick batches. All four fixtures still complete three ordered AI laps with zero contacts and exact full-race JSON replay; their lap times are unchanged from the previous surface revision. Both bridge layers and continuous ramp height checks still pass.

## Remaining acceptance

Close and relaunch the game to load the new code; **R only resets the existing simulation and does not load this patch**. Try an angled ramp entry on 1WAY, then hold brake to reverse out. Existing genuine barriers still block movement; this is not permission to drive through a rail or an obstructed exit.

The owner's original running instance was left intact and still contains the old code. No manual drive of the corrected build, physical-phone test, APK export or phone performance measurement was performed. Device attachment was not verified. The planar circle collider and presentation-only ramp height remain prototype limitations.

## Rail-tip activation - 2026-09-12

G01/G02/R03/R01 owner follow-up: ramps still produce unwanted contacts and the live car is parked at an affected location. Inspected the running 1WAY window using Win32 PrintWindow; [live view](evidence/ramp-contact-live.png) shows the car intersecting the visible rail end, 759 contacts and 24.13 m/s forward velocity. The window was left intact. Its exact simulation coordinates were unavailable; F3 recording was deliberately not triggered because it restarts the car. Native rail-tip fixtures reproduce a concrete related failure, not an exact replay of the owner's current state.

The previous resolver enabled upper-rail collision only after the centre entered a deck cell. At a ramp end, this let the circular footprint overlap a rail before it became solid. New tests reproduced missed contacts at both ends of 1WAY and OFFROAD (four failures); the diagonal 66 samples were already blocked. Evidence: [before](evidence/ramp-tip-before.txt).

NativeTrack now extends upper-rail detection beyond the longitudinal deck ends by the configured car collision radius. Route direction still distinguishes bridge travel from the crossing beneath it. The first implementation extended detection around every edge and exposed unwanted OFFROAD underpass contacts; the final implementation explicitly excludes transverse edges and retains existing lower-layer behavior there. Detection samples the native deck outline along its bridge axis, including diagonal ramps. No source geometry, road widths, barrier strength, handling tuning or presentation assets were changed.

Changed runtime: game/track/native_track.gd (footprint-aware end detection, used consistently for the starting point, swept candidates and wall-slide candidates), game/vehicle/vehicle_simulation.gd (physics arcade-planar-0.11). game/tests/test_tracks.gd adds both-end contact/retreat fixtures across all three bridge tracks. The pre-existing synthetic layer-entry fixture begins already overlapping the upper rail; it now correctly expects early upper-layer detection while retaining the same blocked-position and contact requirements. State/recording/track schemas are unchanged; no golden-content update or save migration is needed.

Manual acceptance: close and relaunch, retry angled ramp entry near the rail ends on 1WAY, then drive both crossing branches and reverse away from a rail contact. Actual rail impacts still collide; this change prevents late activation inside the car. The single-circle collider and route-based planar layers remain approximations. No corrected-build manual drive, phone test or APK export is claimed.

The expanded footprint regression also exposed a layer-boundary recovery case on 66: the old escape condition compared depth only when both samples used the same layer. Recovery now compares the previous and candidate positions against the candidate layer's geometry, still requiring decreasing total penetration and no increase against any individual occupied cell. This permits retreat across a layer boundary without allowing an inward move through the rail. The dedicated rail-tip fixtures isolate the original upper rail geometry over empty ground: the diagonal ends otherwise sit behind separate ground walls and cannot test upper-rail activation or free retreat independently. Full-track lap, underpass, reverse-recovery and ground-barrier fixtures retain their original geometry. Existing ramp-reverse and second-barrier invariants remain in place.

Final actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: import, 24 parses, startup, 56 driving and 151 track checks pass (207 total). Both-end isolated upper-rail fixtures stop before overlap and immediately retreat without adding contacts on 1WAY, 66 and OFFROAD. Original full-geometry reverse escapes remain 99/82/106 ticks with zero new contacts. All four original tracks complete three AI laps with zero collisions, unchanged times and exact full JSON replay; both crossing layers and continuous ramp heights pass. Softer rebound and tire contamination regressions pass. `git diff --check` passed. Evidence: [track results](evidence/ramp-tip-tracks.txt), [driving results](evidence/ramp-tip-driving.txt). Android build-tools remain unavailable; no phone test or APK export occurred.
