# Steering press haptics — 2026-09-25

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
