# Configurable touch controls — 2026-09-24

Requirement IDs: owner touch-control request 1–12; project R01 / V03 / V05 / Q01.

## Current override: independent controls (2026-10-03)

The owner's newer reference supersedes grouped steering and Brake + handbrake editing. Settings → Controls → Customize layout now has a full-width reference-led toolbar, a separate selected-control panel and a plain navy canvas. Left steer, right steer, brake, handbrake and accelerator can each be dragged by their **3×3 dot grip**, moved, resized and faded independently. Analog slider/joystick remain single movable controls. Reset position changes only the selected position, keeping its size/opacity; Reset restores the full default layout. Other controls never move to make room for an editor drag/resize: conflicting changes are rejected with the previous positions retained.

The saved layout is now [version 2](schemas/control-layout-v2.schema.json), with `steer_left`, `steer_right` and `handbrake` as independent entries. Valid v1 data remains readable and converts in memory; player files, styling of the split groups and standalone analog/accelerator settings are preserved. The two grouped regions split using the original 1280×720 safe-area reference. Exact former grouped button pixels are not guaranteed across migration or screen-size/overlap resolution. New edits save v2 atomically through the existing LocalRecords contract; its file schema remains unchanged. Existing autosave/Done failure behavior is retained, and Back follows the same save-and-close behavior.

Requirements **R01 / G03 / V03 / V04 / V05 / Q01**. Changed runtime files: `game/input/control_layout.gd`, `game/ui/touch_controls.gd`, `game/ui/control_layout_editor.gd`. Updated integration checks: `game/tests/test_control_layout.gd`; new schema, this document, status/phase notes and evidence. Existing artwork is reused; the supplied scenic/chase reference is not an asset and no gameplay camera or canonical physics/rules changes were made by this task. Unrelated current working-tree changes remain intact.

Actual pinned entry-point commands (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):

| Action | Actual outcome |
| --- | --- |
| `CheckScript -ScriptPath res://ui/control_layout_editor.gd` | Passed. |
| `TestControlLayout` | **487 checks, 0 failures**. |
| `CaptureControlLayout` | **496 checks, 0 failures**; 15 actual Godot screenshots across 1280×720, 960×540 and 1600×720. |
| `TestMobileControls` | **747 checks, 0 failures**, on Windows. |
| `TestRecords` | **54 checks, 0 failures**. |
| `TestDriving` | **72 checks, 0 failures**; existing three-instance ObjectDB warning at shutdown. |
| `CaptureSettings` | **150 checks, 0 failures**, including actual editor return and save-error recovery. |
| `Doctor` | Passed pinned engine/template/tool prerequisites; DN2103 attached. |
| `git diff --check -- game/input/control_layout.gd game/ui/control_layout_editor.gd game/ui/touch_controls.gd game/tests/test_control_layout.gd` | Passed. |

The independent-control checks drag **each of the five 3×3 grips**, then verify movement, separate size/opacity, unchanged sibling preferences and actual resolved positions, reset-position behavior, persistence and inactive driving commands during editing. Coverage also includes collision rejection, safe nonoverlapping regions at all three steering methods/handedness/aspects/maximum sizes, simultaneous/cancelled touches, v1 disk load → v2 atomic save with favorite preservation, Settings integration and persisted geometry in an offline timed-race HUD. The race's backend-version annotation is an isolated test fixture, not an actual backend publication or verified driving run. App fixtures now use a disposable profile and wait for asynchronous startup.

Initial checks exposed JSON number-type membership in the new version validator, a missing preview rewind widget, an old drag target now occupied by the independent handbrake, a typed conditional-array assignment in migration and the concurrently updated backend-only Race guard. These were resolved without weakening input, saved-geometry or independence checks. The offline race fixture follows the current guard rather than changing it. Visual inspection removed unrelated preview messages and restored menu theming across the preview CanvasLayer.

Evidence: [selected Brake and nine-dot grips](evidence/control-customization-2026-10-03/selected-brake-1280x720.png), [default controls](evidence/control-customization-2026-10-03/editor-1280x720.png), [compact controls](evidence/control-customization-2026-10-03/editor-960x540.png), [wide controls](evidence/control-customization-2026-10-03/editor-1600x720.png), [compact joystick](evidence/control-customization-2026-10-03/joystick-960x540.png). Exact logs and their source paths are saved in the same directory. A scoped review patch is retained; the mixed workspace was not committed wholesale.

Remaining acceptance: owner visual review and physical-phone drag reach, opacity/readability, presets, save/relaunch and real driving with customized positions. **No Android export/install or physical-device test was performed**, despite an attached phone. No full physics/replay suite or real gamepad/iOS test was performed. Compact desktop captures retain the project's logical layout and are not phone screenshots.

## Original grouped behavior (2026-09-24)

Settings → Driving Controls → Customize layout opens a full-screen editor using the real `PlaygroundHUD`, `TouchControls` and existing `TouchControlArt` textures. Drag steering, accelerator or brake directly; the selected control has a gold outline and its complete initial touch region is visible. Size and Opacity are the only per-control adjustments. A fixed upper toolbar stays outside the usable driving region; the shared race status/pause region remains reserved. Desktop mouse dragging and multitouch selection are supported. The preview intentionally uses a quiet background instead of running a live race.

Steering supports left/right buttons, a horizontal analog control and a circular joystick. Each method retains its own normalized position, scale and opacity. Joystick vertical movement animates the thumb; its horizontal component supplies steering. Existing steering arrow and pedal artwork is reused, with simple track/ring/thumb affordances for the analog methods. Default and Right-handed use left steering/right pedals; Left-handed mirrors that arrangement. Every preset resets all method/pedal settings immediately and remains editable. Reset to default restores all settings.

Pedals press fully on contact. Sliding down toward/beyond the target bottom progressively eases pressure. They remain independent analog channels (0–1); steering stays −1–1. Small excursions retain a 28 UI-unit hold margin. Fingers cannot accidentally transfer between pedals. Two fingers on one pedal combine by maximum strength; releasing either preserves the other. The newest analog steering finger takes ownership, and an older release cannot cancel it. Button steering permits sliding between its left/right halves. Releases, cancellations, disable, focus loss and removal clear owned commands. Keyboard and InputMap commands still combine with touch through `DriverInput`; standard gamepad left-stick steering and trigger pedals are mapped in `project.godot`.

No vehicle, throttle, braking, steering physics or canonical quantization changed. TouchSteering → DriverInput → DriveFrame → existing simulation remains the boundary. A future tilt adapter can feed the same normalized command path without changing physics.

## Persistence and geometry

`settings.control_layout` is a version-1 object in the existing atomic LocalRecords file, validated before write. See [schema](schemas/control-layout-v1.schema.json). It contains steering_type plus buttons/horizontal/joystick/accelerator/brake objects with x, y, scale and opacity. Bounds: normalized x/y 0–1, scale 0.65–1.6, opacity 0.2–1.0. Existing `left_handed` and `touch_scale` are migration fallbacks; old records/player tracks are preserved. Layout changes autosave after 350 ms idle, on drag completion, focus loss, and Done. Failed saves remain visible and retryable. Done does not close after a failed save.

Positions describe travel within the available safe rectangle after the selected size is deducted, rather than pixels. Display safe bounds are transformed into local UI coordinates on Android/iOS. The same geometry drives editor rendering, hit testing and every app-started race. Overlaps resolve to nearby free positions; densely packed layouts fall back to a fitted horizontal arrangement. Large controls can therefore be shifted/reduced on a smaller usable screen without overwriting their saved settings. Hit regions retain padding around the original artwork. Resolved layout geometry is cached; held artwork retains its existing draw lists. Legacy unconfigured diagnostic HUDs keep their old geometry.

The coordinate conversion follows Godot's [viewport/canvas transform documentation](https://docs.godotengine.org/en/latest/tutorials/2d/2d_transforms.html).

## Files

- `game/input/control_layout.gd`, `touch_steering.gd`, `driver_input.gd`: layout schema/presets, steering adapters and per-finger analog strengths.
- `game/ui/control_layout_editor.gd`, `touch_controls.gd`: shared preview/gameplay geometry, editor, safe bounds and finger ownership.
- `game/core/app.gd`, `game/persistence/local_records.gd`, `game/project.godot`: Settings entry, race application, atomic persistence and gamepad mappings.
- `game/tests/test_control_layout.gd`, `game/diagnostics/mobile_control_probe.gd`, `scripts/dev.ps1`: focused tests, opt-in debug device probe and test/capture entry points. Generated `.uid` files accompany new scripts.
- This document, the schema, status/plan entries and `docs/evidence/control-layout/`.

## Actual verification

Commands below were run through the pinned Godot 4.7.2 entry point, using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action | Actual result |
|---|---|
| `-Action Import` | Passed registration/import. |
| `-Action TestControlLayout` | 199 checks, 0 failures; two shutdown ObjectDB warnings from the composed race teardown. |
| `-Action CaptureControlLayout` | 202 checks, 0 failures; nine screenshots, three methods × 1280×720 / 1600×720 / 960×540. |
| `-Action TestMobileControls` | 555 checks, 0 failures. |
| `-Action TestRecords` | 53 checks, 0 failures. |
| `-Action TestMenus` | 22 checks, 0 failures. |
| `-Action ExportAndroid -QuickValidation` | Final export passed: startup, 74 driving, 18 catalog and 22 menu checks. Driving retains two shutdown ObjectDB warnings. SDK tooling reported its existing 35.0.1 fallback. |
| `-Action InstallAndroid` | Final APK installed successfully on connected DN2103, serial PRQKU4U4PREQNRWG. |
| `-Action LaunchAndroid` | Launch command succeeded for the initial exported build; phone remained at its lock screen. |
| `-Action TestApp` | Did not complete: old test expects a text `Create` button and old library controls; nil references at test_app.gd:112 and :59. Its stalled processes were stopped. Those assertions were not weakened. The new focused suite independently passes Settings entry, editor return and starting a race with the persisted layout. |
| `git diff --check` | Passed (line-ending notices only). |

An initial driving regression caught directly injected DriverInput fingers being ignored on drag; fixed, and the original 74 checks now pass unchanged. Initial new tests also caught dense-layout overlap and a stale toolbar width after resize; both were fixed before final capture/export.

The focused suite additionally runs the device probe on **Windows**, with 72 viewport-dispatched multi-finger checks and zero failures. These are synthetic events, not physical Android input. It checks both handedness layouts and all methods, simultaneous steering/gas/brake, handoff, partial pedal input, cancellation and disable. Separate tests cover keyboard/gamepad coexistence, focus loss, malformed-save rejection, reload, direct dragging, presets/reset and method-specific settings.

Desktop screenshots inspected: [buttons](evidence/control-layout/editor-1280x720.png), [joystick](evidence/control-layout/joystick-1280x720.png), [compact](evidence/control-layout/editor-960x540.png). All nine captures and selected logs are retained in the evidence folder.

Final APK: `build/android/circuit01-debug.apk`, SHA256 `31409308907C654DB788FAEE5DD5D18BF40858FB74EE4D302EBBA3091E6422A4`.

## Remaining acceptance

The Android phone was attached but **locked** (`mDreamingLockscreen=true`). Physical multitouch, actual touch ergonomics, cutout/orientation behavior and device performance were **not tested**. An attempted opt-in device probe produced no report while locked; `files/control_probe.json` was removed and its absence verified. No diagnostic marker is left to inject events on the owner's next launch. iOS hardware and physical gamepad were not tested. No full physics replay suite was run because canonical physics was unchanged.

On an unlocked phone, manually verify: each method with sustained gas and brake; new-finger handoff; quick alternating presses; small edge excursions; cancellation/background/resume; drag/resize/opacity at all four usable edges; mirrored layout; reset; then restart the app and start another race. Confirm that visible positions match the editor and no controls intersect display cutouts. For synthetic Android coverage, explicitly create `files/control_probe.json` through `adb shell run-as org.circuit01.handlinglab touch files/control_probe.json`, relaunch, retrieve `files/control_probe_report.json`, then remove the marker. This debug-only probe temporarily hides menus, uses a separate input adapter and never changes player settings.

## Reset-position icon correction (2026-10-03)

V03/Q01: owner reported the target glyph did not read as reset. Changed only the Reset position icon in `game/ui/control_layout_editor.gd` to the existing circular `restart` arrow, matching Reset in the top toolbar. Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureControlLayout`: **496 checks, zero failures**. Inspected the refreshed [desktop screenshot](evidence/reset-position-icon-2026-10-03/controls.png); exact log and a one-line review patch are saved alongside it. No Android export or physical-device test was performed; owner visual acceptance remains.
