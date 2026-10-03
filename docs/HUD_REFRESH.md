# Reference HUD replacement ? 2026-09-21

Requirements: V02/V03/V05, G01 and R01/R03. Owner supplied `temp/HUD` and authorized reuse/modification. This supersedes the prior heavy instrument/card HUD presentation.

## Optional control labels — 2026-10-03

Requirements **R01 / G03 / V03 / V05 / Q01**. Settings → Controls now has **Show labels** beside Customize layout. Turn it off and Apply settings to hide only the Gas, Brake and Handbrake captions. Existing profiles default to visible labels. The boolean `control_labels` is stored through the existing strict, atomic LocalRecords schema 2 preferences; no layout-schema change is needed. Reset controls restores labels, and Reset camera preserves the preference. Leaving without Apply or a failed save retains the committed preference; a failed save keeps the draft available for retry.

Shared released/pressed artwork and the layout editor/selected-control preview respect the preference. Pedal/icon dimensions, placement, opacity, touch targets and pressed feedback stay unchanged. Changing visibility redraws each retained artwork variant once; normal input updates continue to reuse it.

Changed runtime files: `game/ui/settings_page.gd`, `game/persistence/local_records.gd`, `game/core/app.gd`, `game/ui/touch_controls.gd`, `game/ui/touch_control_art.gd`, `game/ui/control_layout_editor.gd`. Existing capture utilities `game/tests/capture_settings.gd` and `game/tests/capture_controls.gd` now exercise preference staging/reload/reset/failure, preview inheritance and unchanged hit areas, and capture the hidden-label result. This document, status/phase notes and evidence are updated too.

Actual pinned-engine commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: **CaptureSettings** 203 checks, **TestRecords** 54, **TestMobileControls** 747 and **TestControlLayout** 487 all pass with zero failures; **CaptureControls** passes five vehicle bindings, 120 scaled/mirrored targets and unchanged targets with hidden labels, producing 11 gameplay captures. **Doctor** passes with DN2103 attached. The initial CaptureSettings run stopped at a duplicate local-variable parse error; the variable was renamed and the complete final run passed without weakening assertions. `git diff --check` also passes.

Inspected [compact Settings](evidence/hud-labels-2026-10-03/settings-controls-960x540.png), [gameplay without labels](evidence/hud-labels-2026-10-03/gameplay-no-labels.png) and [layout without labels](evidence/hud-labels-2026-10-03/layout-no-labels.png). Final logs, three-size Settings captures and the scoped [checkpoint patch](evidence/hud-labels-2026-10-03/checkpoint.patch) are retained. No Android export/install or physical-device test was performed; owner visual and phone touch/relaunch acceptance remain. No canonical changes or mixed-workspace commit.

## Owner-supplied pedal and handbrake artwork — 2026-10-03

Requirements **R01 / G03 / V03 / V05 / Q01**. The owner requested applying the three new pictures under `temp/HUD/pedals`. The taller twelve-hole face is Gas, the shorter six-hole face is Brake, and the circular lever is Handbrake. `game/assets/hud/gas.png` and `brake.png` are replaced; `handbrake.png` and its Godot import settings are added. `game/ui/touch_control_art.gd` uses source regions with the original face proportions and replaces the procedural handbrake drawing with the supplied texture. This also updates the shared artwork in Controls → Customize layout and its selected-control preview.

Existing captions, pedal depression, steering artwork, layout/opacity settings and independent touch targets are retained. Handbrake gets a small depression and yellow ring when pressed. Both pressed/released variants continue to use retained draw lists. No canonical physics, replay, rules, camera or player-save contract changes.

The three runtime PNGs are **byte-for-byte owner-supplied files**, with their transparency retained; no generation or raster editing was performed. This supersedes the old Brake/Gas provenance below. Source files remain under `temp/`; no independent third-party rights verification is claimed.

| Runtime asset | Source filename in `temp/HUD/pedals` | SHA-256 |
|---|---|---|
| `gas.png` | `ChatGPT Image Oct 3, 2026, 04_26_16 PM-1.png` | `dfc8db12346c634bf66eeebfa62be9e86aa83f3dcb415eb9fe86a216f9460902` |
| `brake.png` | `ChatGPT Image Oct 3, 2026, 04_26_17 PM-2.png` | `8c178383e50a6b19cdd0a155505e74963f1c7570b2f80c940d8152001f311f38` |
| `handbrake.png` | `ChatGPT Image Oct 3, 2026, 04_26_17 PM-3.png` | `95da9734ad3fc62edc3a1b1b097e807c98559f69cdea3f27f560be8ca5b3c00d` |

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` using pinned **4.7.2.stable.official.ed1daf0bf**:

- `Import`: exit 0; all three textures imported.
- `TestMobileControls`: 747 checks, zero failures.
- `CaptureControls`: five vehicle bindings and 120 scaled/mirrored action targets pass; ten actual gameplay captures.
- `CaptureControlLayout`: 496 checks, zero failures; editor captures at 1280×720, 960×540 and 1600×720.
- `Doctor`: exit 0; matching templates found and DN2103 attached.

Inspected [released gameplay](evidence/pedal-art-2026-10-03/gameplay-released-1280x720.png), [pressed Gas](evidence/pedal-art-2026-10-03/gameplay-gas-pressed-1280x720.png), [layout](evidence/pedal-art-2026-10-03/layout-1280x720.png) and [compact selected Handbrake](evidence/pedal-art-2026-10-03/layout-handbrake-960x540.png). Logs and a scoped [Git patch](evidence/pedal-art-2026-10-03/checkpoint.patch) are retained in the same evidence folder. Changed files also include this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and evidence. The existing layout capture command refreshes its `control-customization-2026-10-03` screenshots as well. Existing unrelated workspace edits are preserved; no mixed-workspace commit.

No Android export/install, physical-device touch test or mobile performance measurement was performed. Owner visual acceptance and phone appearance/pressed feedback remain outstanding. Desktop gameplay captures use the existing stationary playground fixture.

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
