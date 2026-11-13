# Challenges icon from the HTML demo

CHI01/CHI02/R01/Q01: The native Challenges navigation button and Challenges empty
state now use the exact target-and-arrow geometry from the HTML demo's `i-target`
symbol. `MenuIcon.CHALLENGES_ART` owns the shared vector; the race rail scales its
24-unit coordinates onto the existing 64-unit canvas. Stroke width, round caps
and joins match the demo. Existing selected/unselected colors, texture caches,
mipmaps, button dimensions and navigation behavior remain.

Runtime changes: `game/ui/menu_icon.gd` and `game/ui/race_mode_icons.gd` only.
The HTML demo and other navigation glyphs are unchanged.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1
-Action TestScript -ScriptPath res://tests/test_race_mode_carousel.gd -Graphical
-RenderingMethod gl_compatibility -CommandTimeoutSeconds 90`. With isolated
workspace APPDATA and `BMT_RACE_MODE_CAPTURE_DIR`, the pinned engine passes
**52 checks, zero failures**, including actual menus at 1280×720 and 960×540.
XML comparison confirms exact HTML/native path and circle attributes. Targeted
`git diff --check` and reverse applicability/whitespace checks of the task-only
patch pass.

The initial incomplete edit caused a missing-constant parser error; the shared
constant was restored before successful verification. A restricted run hit the
Windows certificate-store boundary; approved native verification passed. The
failed isolated test process was identified from its exact command, parent and
parser log, then closed. No owner game process was restarted.

[Native Challenges capture](evidence/challenges-html-icon-2026-10-25/native/challenges-960x540.png),
[report and hashes](evidence/challenges-html-icon-2026-10-25/report.json), and
[task-only checkpoint](evidence/challenges-html-icon-2026-10-25/scoped-change.patch).
Reload the client to pick up the icon. Owner/device appearance acceptance remains;
no device attachment check or physical-device test, APK, live mutation or deployment.
