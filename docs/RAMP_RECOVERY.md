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
