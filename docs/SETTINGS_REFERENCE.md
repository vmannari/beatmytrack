# Reference-led settings (2026-10-03)

Requirements **R01, G03, V03, V04, Q01**. The owner requested the supplied Settings composition, with only configuration options relevant to the current game. The page now uses a left category rail, translucent navy panels, yellow outlined selections, a yellow Apply action and the existing original workshop backdrop/top navigation.

The three categories are:

- **Controls:** Buttons, Analog slider and Analog joystick; the existing full-screen layout editor; accurate desktop shortcut hints, including Space for the handbrake.
- **Haptics:** the existing Off / Light / Medium / Strong steering-button feedback levels.
- **Account:** current profile and the existing Sign in / Manage account flow.

No tilt steering, sensitivity/dead-zone tuning, automatic pedals, audio/graphics settings, accessibility suite, language controls or new account services are implied by the reference. Those are not implemented configuration options in this slice. The supplied reference is design guidance and is not a shipping asset. The new controller/phone/check glyphs are original inline vectors in the existing icon system; steering previews reuse the current control artwork.

Steering and haptic changes are staged until **Apply settings**. Switching categories keeps the draft; leaving Settings without applying discards it. **Customize layout** first commits the staged preferences and then opens the existing editor, whose existing autosave behavior is retained. A failed commit keeps the draft available to retry and reports the failure. **Reset controls** stages the default layout/button steering and Light haptics; applying it preserves records, favorites and account data. Reset is hidden in the Account category. No persistence schema or canonical physics/rules changes are introduced.

Changed files: `game/ui/settings_page.gd`, `game/core/app.gd` (Settings composition only), `game/ui/menu_icon.gd` (three glyphs), `game/tests/capture_settings.gd`, `game/tests/test_control_layout.gd` (Apply step in the existing persistence check), `scripts/dev.ps1` (`CaptureSettings` action), this document, status/phase notes and evidence. Pre-existing changes in these shared files remain in place.

Actual commands from the repository root, using the pinned **4.7.2.stable.official.ed1daf0bf** engine:

| Command | Actual outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Passed; new SettingsPage class registered. Existing Android build-tools fallback message remains. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureSettings` | Final run: **142 checks, zero failures**. Nine actual Godot captures across 1280×720, 960×540 and 1600×720. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestControlLayout` | **215 checks, zero failures**, including saved layout reaching the race HUD. Its 90-event synthetic input probe ran on Windows. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus` | **48 checks, zero failures**. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Passed engine/template/tool prerequisites; a DN2103 phone was attached. |
| `git diff --check -- game/core/app.gd game/ui/menu_icon.gd game/tests/test_control_layout.gd scripts/dev.ps1` | Passed; Git emitted existing line-ending notices. |

The graphical suite exercises the gear entry, all three categories, stable panel geometry, touch target heights, keyboard text fit, apply/reload, retained staged preferences, leaving without apply, default restoration of every control field, favorite preservation, failed-write rollback/retry, actual layout-editor return and the existing sign-in entry. All persistence fixtures live in a disposable test profile.

Initial checks exposed an action-list insertion conflict in the concurrently changing dev script, a test incorrectly expecting a return value from the void record loader, the previous immediate-save test contract and strict floating-point dictionary equality after JSON reload. These were corrected; the reset test now checks every persisted control field with the existing approximate-float comparison convention. Visual inspection also caught a wrapping layout error in keyboard descriptions; horizontal expansion and explicit shortcut-fit checks resolve it. No failing invariant was removed.

Evidence: [desktop Controls](evidence/settings-2026-10-03/settings-controls-1280x720.png), [compact Controls](evidence/settings-2026-10-03/settings-controls-960x540.png), [wide Controls](evidence/settings-2026-10-03/settings-controls-1600x720.png), [Haptics](evidence/settings-2026-10-03/settings-haptics-960x540.png), [Account](evidence/settings-2026-10-03/settings-account-1280x720.png), and the saved test logs in `docs/evidence/settings-2026-10-03/`. These are rendered game UI, not mockups or physical-device screenshots.

Remaining acceptance: owner visual approval, physical-phone reach/readability/vibration checks and real signed-in account review. No Android export/install/device test, real Google sign-in, production deployment or full physics/replay suite was performed for this UI change. Desktop compact captures preserve the project's 1280×720 logical layout and do not prove phone usability. The existing mixed working tree was not committed wholesale; a scoped Git review patch is saved with the evidence.
