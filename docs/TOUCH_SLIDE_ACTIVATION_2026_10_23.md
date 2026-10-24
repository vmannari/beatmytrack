# Driving buttons follow finger position — 2026-10-23

The owner requests steering, gas and brake activation whenever a finger enters a
button area, including a finger that first touched elsewhere on the screen.

## Requirements and implementation

- **TSA01:** Track every touch begun while driving controls are enabled and
  visible, including touches outside the driving targets. On every button drag,
  resolve the current target using the existing safe bounds, original-face
  priority and nearest-face arbitration for enlarged hit areas. Entering a target
  applies full input immediately. Direct transfers between all five buttons,
  including gas/brake and handbrake, release the previous action in the same event.
- **TSA02:** Keep independent per-finger input, shared-button occupancy, immediate
  steering reversal, pressed artwork and steering haptics. Leaving and returning
  works without another touch-down. Preserve the existing 28-unit exit tolerance
  and lower pedal fade; a different button's resolved target always takes priority.
- **TSA03:** Release/cancellation, disabling, hiding, focus loss, backgrounding,
  layout replacement, resize and explicit release clear tracked state. Late drags
  cannot resurrect a cleared gesture. Horizontal/joystick steering and the shared
  relative gas/brake axis retain their first-contact origins and captured drag
  behavior. Their separate handbrake button supports slide entry.
- **R01/G01/Q01:** Preserve canonical driving and existing artwork/layout. Add
  focused viewport-input coverage, actual native screenshots and a scoped patch.

Runtime change: `game/ui/touch_controls.gd`. Regression coverage:
`game/tests/test_touch_slide_activation.gd`. The existing padding test changes
only its old prohibition on gas-to-brake transfer, which the owner's request
supersedes. The existing layout and device-probe edge-fade assertions remain.

## Actual validation

Godot 4.7.2, Windows, with separate workspace APPDATA directories:

| Check | Result |
| --- | --- |
| Slide activation, headless | 1,253 checks, zero failures |
| Slide activation, Compatibility/OpenGL | 1,259 checks, zero failures |
| Slide activation, desktop Mobile/Vulkan | 1,259 checks, zero failures |
| Existing target padding | 1,218 checks, zero failures |
| Existing relative axes | 1,642 checks, zero failures |
| Existing mobile controls | 747 checks, zero failures |
| Existing control layout, including viewport probe | 407 checks, zero failures |
| Existing driving/replay | 72 checks, zero failures |
| Full project script parser | 1,041 scripts, zero failures |

The focused test covers all source/destination button pairs, outside entry,
exit/reentry, cancellation, multiple occupants, simultaneous steering/pedals,
three aspect ratios, three sizes, mirroring, legacy layout, transformed canvas,
safe insets and lifecycle resets. Both native renderers capture slide-acquired
left/gas, a direct gas-to-brake transfer and neutral artwork after exit. These are
synthetic viewport events on Windows, not physical touchscreen gestures.

Repeat each check with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/touch-slide-activation-2026-10-23/run_validation.ps1 -Test test_touch_slide_activation -Mode headless
```

Use `gl_compatibility` or `mobile` for native captures. The same runner accepts the
existing test names listed in `report.json`. Logs, source hashes, screenshots,
initial interruptions and the Git-checkable task patch are under
`docs/evidence/touch-slide-activation-2026-10-23/`.

## Corrections and remaining acceptance

The first script launch hit Windows execution policy; the repeat used the normal
process-scoped Bypass flag. Initial layout/driving tests lacked isolated writable
APPDATA and stopped at their file assertions; those processes were stopped and
the complete tests passed with workspace-only user data. An initial change
removed the old pedal edge fade; the existing viewport probe caught it, and the
fade and its original assertions were restored. Final native assertions pass;
their shutdown logs retain four ObjectDB instances/one resource still in use.
Sandboxed launches also report unavailable root-certificate-store access. No
network behavior or production shutdown behavior was changed for this task.

Client reload and owner/device slide feel remain. No phone/tablet attachment
check, physical-device test, APK export/install, account/backend mutation or
deployment was performed. Concurrent work is preserved.
