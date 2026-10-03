# Missed checkpoint presentation — 2026-10-03

Requirements: R01/V03/V04/Q01. The owner's supplied gameplay reference authorizes this marker/banner presentation. The final owner correction removes the window-edge arrow and keeps the banner visible for every missed checkpoint, superseding the initial off-screen-only request. The separate bridge-entry report was explicitly withdrawn; this task changes no checkpoint acceptance, physics, rules or camera configuration.

The missed gate now has an amber dashed line across the physical road and two translucent approach chevrons pointing in the required crossing direction. There is no floating text. Development acceptance extensions remain available in code but are hidden by default. Mesh vertices use the accepted road layer and bridge height; these drawings have no collision.

Whenever a checkpoint is missed, a dark slanted banner uses the reference's amber outline, circular exclamation and double end stripes. Its only direction arrow points from the car towards the checkpoint in the current camera view. The banner remains visible with on-screen, partially visible, off-screen and behind-camera gates. There is no window-edge arrow or viewport/occlusion-based visibility test. Recovery, restart and finish clear the banner.

All artwork is original editable Godot mesh/control drawing code. The owner reference is inspiration and is not bundled as a game asset. Existing cleared project fonts are reused.

Changed runtime files: `game/ui/checkpoint_marker.gd`, new `game/ui/checkpoint_notice.gd` and its Godot UID, `game/ui/playground_hud.gd`, `game/core/game.gd`. Validation: `game/tests/capture_checkpoints.gd` now uses a deterministic built-in document rather than depending on a retired player-file ID. Documentation: this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and the evidence directory below.

Actual commands used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action and arguments | Actual result |
| --- | --- |
| `CaptureCheckpoints -Screen dust-cloud` before editing | 17 checks, zero failures; baseline capture retained. |
| `Doctor` | Matching engine/templates available; physical DN2103 attached. |
| `Import` | Pass; nonfatal pre-existing Android build-tools version warning. |
| `CaptureCheckpoints` final | 132 checks, zero failures; actual miss/recovery, live car-to-gate bearing, no floating label, road spans, three landscape sizes, six off-screen bearings, persistence for visible/partially visible/returning gates, behind-camera bearing, restart and finish. |
| `CaptureCheckpoints -Screen dust-cloud` final | 24 checks, zero failures; ground-height underpass marker, car-to-gate bearing and actual recovery retained. |
| `TestRouteValidation` | 266 checks, zero failures. |
| `TestRewind` | 57 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` final | 248 scripts, zero failures. |

The first updated capture exited 1 because the live follow-camera process overwrote the test's temporary camera placement during a render wait. The fixture now suspends that process during deliberate camera-bearing cases; actual driving presentation and recovery assertions remain enabled. Earlier 124/131-check captures tested the initial off-screen-only contract. Persistence assertions were updated to the owner's explicit final correction; the final expanded capture passes 132. No planned or physical-device test is recorded as passed.

Inspected desktop screenshots and raw final logs: [evidence](evidence/missed-checkpoint-2026-10-03/). [Visible road gate](evidence/missed-checkpoint-2026-10-03/onscreen-1280x720.png), [off-screen warning](evidence/missed-checkpoint-2026-10-03/offscreen-1280x720.png), [compact warning](evidence/missed-checkpoint-2026-10-03/offscreen-960x540.png), [underpass](evidence/missed-checkpoint-2026-10-03/underpass.png). Six size/state captures cover 1280×720, 960×540 and 1600×720. The before image uses the underpass fixture; compare it with `underpass.png`, not the different ordinary-road fixture.

Remaining acceptance: owner visual review, real driving/moving bearings and touch/safe-area/readability on the phone. No Android export, install or device driving was performed. No full project regression or phone GPU/thermal measurement. Existing HUD/world artwork outside this marker is unchanged by this task. The workspace already contained substantial unrelated edits; a source-only task patch against saved pre-task files is retained in the evidence directory, explicitly excluding concurrent unrelated core/physics changes. No mixed-workspace commit or production action.
