# Analog steering menu — 2026-09-25

Requirements R01/V03/V05/Q01 and owner request: expose analog steering as an easy menu choice.

Settings now offers Buttons, Analog slider and Analog joystick directly. Existing proportional steering adapters supply partial steering according to finger displacement; release centers the input. Selection uses the existing control-layout-v1 schema and atomic save, preserving all control positions and sizes. Save failures restore the committed selection and show an error. Existing defaults are preserved. The layout editor uses matching names, and returning from it refreshes the selected menu mode. Haptic preferences remain applicable to all modes. No physics or schema changes.

Changed files: `game/core/app.gd`, `game/ui/control_layout_editor.gd`, `game/tests/test_control_layout.gd`, this document, status/plan and [compact Settings evidence](evidence/analog-steering/settings-960x540.png).

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with:

- `-Action TestControlLayout`: final 211 checks pass, plus 72 synthetic Windows viewport checks. Covers menu selection/reload, preserved pedal geometry, analog partial/full/released input and saved layout reaching a race. Initial added test had a duplicate local variable name; corrected before the passing run.
- `-Action CaptureMenus`: 502 checks pass across three sizes; compact screenshot inspected.
- `-Action ExportAndroid -QuickValidation`: succeeds, including startup, 74 driving, 18 catalog and 26 menu checks. Existing SDK 35.0.1 fallback and driving shutdown warnings remain.
- `-Action InstallAndroid`, `-Action LaunchAndroid`: succeed on attached phone.
- `git diff --check`: passes, line-ending notices only.

No physical touchscreen driving/ergonomics test performed. Owner acceptance: select each analog mode, try light and full steering with throttle held, release to center, restart to confirm selection, and customize placement. iOS untested. Full physics replay regression not run because canonical simulation is unchanged.
