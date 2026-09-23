# Reference HUD replacement ? 2026-09-21

Requirements: V02/V03/V05, G01 and R01/R03. Owner supplied `temp/HUD` and authorized reuse/modification. This supersedes the prior heavy instrument/card HUD presentation.

## Result and files

- `game/ui/playground_hud.gd`: circular map/lap composition, open race and current-lap timers, round pause/menu actions, handling pill and semicircular speed display. Current lap is yellow; target is white. Practice remains untimed with Restart/Edit here.
- `game/core/game.gd`: binds the actual TrackSession to the HUD; no canonical simulation changes in this slice.
- `game/ui/hud_frame.gd`, `hud_road_map.gd`, `race_hud_style.gd`: lightweight frames, regular licensed Barlow typography, cached actual placed-road map with live blue position marker. Existing no-legacy/no-painted-road map contract retained.
- `game/ui/touch_control_art.gd`, `game/assets/hud/`: supplied steering and metal pedal artwork, retained pressed-state drawing and independent existing touch zones, scaling and handedness. All five vehicles use the new shared HUD artwork.
- `game/tests/test_bridge_hud.gd`: dynamic seven-lap witness, separate clocks, penalty inclusion, finish retention, reset, minute rollover and revised 120-unit semicircular gauge height budget. Other existing overlap/input/state checks remain.
- This document, development status, phase plan and evidence folder.

Race/lap clocks derive from simulation ticks and session penalties, freeze with the session and reset on restart. Final lap time stays visible at finish. Minute formatting truncates centiseconds to avoid 00:60.00. The speed arc follows actual speed on the existing 0?180 km/h scale; it does not invent RPM.

## Asset provenance

`steering.png`, `brake.png`, `gas.png` are byte-for-byte copies of owner-supplied numbered elements (7), (9), (10), respectively. They are displayed through texture regions with dynamic captions/pressed treatment; the original source files are preserved. Owner supplied AI-generated filenames and explicit reuse authorization; no independent third-party rights verification is claimed. The target screenshot and static sample map/laps/times are not embedded into gameplay. No generated world, vehicle or camera replacement is part of this task.

## Actual validation

Pinned Godot 4.7.2.stable.official.ed1daf0bf through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action | Result |
| --- | --- |
| `Import` | Passed; Android target build-tools fallback warning remains. |
| `CaptureBridgeHUD` | Final: 107 checks, zero failures, four desktop engine captures. Initial run exposed two obsolete rectangular speed-card height expectations, updated to the new semicircle budget. |
| `TestMobileControls` | 555 checks, zero failures, including simultaneous touches, cancellation, size/handedness and non-overlapping enlarged targets. Headless run. |
| `TestPractice` | 33 checks, zero failures; six untimed laps, zero collisions. |
| `CaptureControls` | Five vehicle bindings, 120 scaled/mirrored action targets passed; ten desktop captures. |
| `Validate -QuickValidation` | Import/startup plus 74 driving, 18 catalog and 22 menu checks passed. Full regression suite not run. |

Practice/driving retain existing exit-time ObjectDB warnings (2/4 instances). No Android export, installation, phone test or mobile performance measurement was performed. Remaining acceptance: owner visual approval, physical-phone legibility, cutouts and touch feel/performance. Existing unrelated workspace edits are preserved; the scoped patch is a review artifact rather than a commit of the mixed working tree.

## Evidence

- [Race with dynamic sample 3/7 and distinct session clocks](evidence/hud-2026-09-21/race.png) ? controlled session values for the capture, not a completed driving run.
- [960?540 layout](evidence/hud-2026-09-21/compact.png)
- [Wide untimed practice](evidence/hud-2026-09-21/practice.png), [paused practice](evidence/hud-2026-09-21/paused.png)
- [Pressed steering and throttle](evidence/hud-2026-09-21/pressed.png)
- [HUD capture log](evidence/hud-2026-09-21/bridge-hud-capture.log), [controls log](evidence/hud-2026-09-21/controls-capture.log)


## Subtle backings and depressed pedals ? 2026-09-21

Owner follow-up, V02/V03/V05/G01/R01: `hud_frame.gd` adds feathered translucent charcoal behind lap status, both clocks and the speed gauge, and strengthens the circular minimap fill. Existing round action/steering and handling-pill backings remain. `touch_control_art.gd` now presses pedal faces down into stationary dark mounting recesses with vertical foreshortening and slight width reduction. Pedals and captions retain their normal colour; captions stay stationary. Steering feedback is unchanged. No input geometry, simulation or timing changes.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `CaptureBridgeHUD` passed 107 checks and four captures; `TestMobileControls` passed 555 checks; `CaptureControls` passed five vehicle bindings and 120 scaled/mirrored targets with ten captures. Desktop images inspected. No phone test or mobile performance measurement was performed; physical-device appearance/touch feel and owner visual acceptance remain pending.

[Race backings](evidence/hud-2026-09-21/backings/race.png), [released pedals](evidence/hud-2026-09-21/backings/released.png), [pressed gas pedal](evidence/hud-2026-09-21/backings/pressed.png), [scoped follow-up checkpoint](evidence/hud-2026-09-21/backings/followup.patch). Changed files: the two UI scripts, this document, development status, phase plan and the evidence folder. Existing unrelated workspace edits preserved.


## Stable timers and aligned lap backing ? 2026-09-21

Owner follow-up, V03/V05/R01: `playground_hud.gd` enables Barlow's tabular numeral feature (`tnum`) for both clocks and reserves their initial time-string dimensions. Changing digits no longer changes the centred text width. `hud_frame.gd` derives the lap scrim from the actual status container's global rectangle with symmetric padding, and redraws when that container moves/resizes. This replaces the hardcoded position and handles the no-minimap layout too.

`test_bridge_hud.gd` now verifies equal text widths across all ten digits at both font sizes, unchanged race/lap label rectangles across narrow/wide digits and minute rollover, and lap-backing centring/enclosure at both race viewport sizes. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBridgeHUD` ? final 157 checks, zero failures, four desktop captures. The intermediate run passed 149 checks before adding live layout-transition coverage. [Inspected race capture](evidence/hud-2026-09-21/stable-timers/race.png), [log](evidence/hud-2026-09-21/stable-timers/bridge-hud-capture.log), [scoped checkpoint](evidence/hud-2026-09-21/stable-timers/fix.patch).

Changed files: the two UI scripts, the HUD test, this document, status/phase plan and evidence. No phone test performed; owner/device visual acceptance remains. Simulation, timer values and controls are unchanged.
