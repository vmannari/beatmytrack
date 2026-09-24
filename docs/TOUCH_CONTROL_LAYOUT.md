# Configurable touch controls — 2026-09-24

Requirement IDs: owner touch-control request 1–12; project R01 / V03 / V05 / Q01.

## Delivered behavior

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
