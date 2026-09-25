# Steering press haptics — 2026-09-25

## Menu configuration follow-up

Settings now provides **Off / Light / Medium / Strong** steering haptics. Light remains the default. Each successful selection previews its 12 ms pulse on handheld devices; Off sends no vibration. The selected choice is yellow. Race and practice controls receive the saved strength at creation.

Persistence contract: optional `settings.steering_haptics`, finite number in [0,1], default 0.2. Menu presets are 0 / 0.2 / 0.5 / 1. Existing schema-2 saves without this field retain their previous behavior. The existing atomic save and rollback apply; failed saves show an error and restore the committed selection.

Changed: `game/core/app.gd`, `game/ui/touch_controls.gd`, `game/platform/steering_haptics.gd`, `game/persistence/local_records.gd`, `game/tests/test_menu_presentation.gd`, this document, status/plan and screenshot evidence.

Actual follow-up commands using the same dev.ps1 prefix below: `TestMenus` passes 26 checks including disabled/strength reload and invalid-value rollback; `TestRecords` passes 53; `TestControlLayout` passes 199 plus 72 synthetic viewport checks; `CaptureMenus` passes 493 checks across three sizes. Compact [Settings screenshot](evidence/steering-haptics/settings-960x540.png) inspected. `ExportAndroid -QuickValidation` succeeds with startup/driving/catalog/menu checks and the existing SDK fallback; `InstallAndroid` and `LaunchAndroid` succeed on the attached phone. `git diff --check` passes. No physical touchscreen or vibration-feel test performed; verify all four choices, preview, restart persistence and race/practice feedback on the phone. iOS remains untested.

Requirements: owner-requested subtle steering feedback; R01/V03/V05/Q01 input usability and platform validation.

Each accepted new touchscreen steering press requests one 12 ms pulse at amplitude 0.2. This includes buttons, horizontal steering and joystick acquisition. Holding, dragging, releasing, canceled events, disabled controls and pedal presses do not request pulses. There is no continuous vibration or direction-crossing pulse. Canonical inputs, physics and replay rules are unchanged.

Changed files: `game/ui/touch_controls.gd` hooks accepted steering presses; `game/platform/steering_haptics.gd` (and generated UID) isolates the handheld API; `game/export_presets.cfg` enables Android VIBRATE. Status and Phase 0 plan link this record. No visual UI changes, so no screenshot required.

API reference: [Godot Input.vibrate_handheld](https://docs.godotengine.org/en/4.6/classes/class_input.html#class-input-method-vibrate-handheld). Device settings can suppress feedback; perceived strength depends on hardware. The adapter runs only on Android/iOS.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned Godot 4.7.2:

- `-Action TestMobileControls`: 555 checks, zero failures.
- `-Action TestControlLayout`: 199 checks, zero failures; 72 additional synthetic Windows viewport checks pass. Existing two ObjectDB shutdown warnings remain.
- `-Action ExportAndroid -QuickValidation`: succeeded; startup, 74 driving, 18 catalog and 22 menu checks pass. Existing SDK 35.0.1 fallback and driving shutdown warnings remain.
- `-Action InstallAndroid`: connected authorized phone, install succeeded.
- `-Action LaunchAndroid`: cold launch succeeded (834 ms reported by Android).
- `git diff --check`: passed, line-ending notices only.

No physical haptic feel or touchscreen test performed. Desktop suites exercise the input paths, not the vibration motor. Owner acceptance: try rapid left/right taps, sustained steering and all three steering methods; confirm a light single pulse per touch and silence on pedals/hold/release. Background/resume should introduce no unsolicited pulses. iOS untested. Full physics regressions were not run because simulation did not change.
