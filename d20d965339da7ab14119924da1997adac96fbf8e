# Sign-in card fits the window — 2026-10-25

SIF01: Fit the complete sign-in card within the window without scrolling.
SIF02: Keep provider, Guest, language, privacy, retry and account setup controls visible.
R01/Q01: Verify actual native layouts and retain a patch containing only this task.

The screen now centers a 600-unit-wide card directly inside the window margins. The card uses 16-unit padding, eight-unit gaps, a 32-unit heading and the existing full-size action targets. Google artwork stays proportional at a 60-unit height. The decorative brand above the card uses its native size and hides when longer status copy needs the space. Provider responses and window resizing recompute that decision. All existing authentication and privacy behavior remains in its existing controllers.

Changed runtime files: `game/core/app.gd` (account composition only) and `game/ui/account_panel.gd` (spacing and dimensions only). Existing uncommitted localization and other work is preserved. `game/tests/capture_sign_in_fit.gd` captures isolated native views and checks the actual card/control rectangles, absence of scrolling ancestors and retained response/resize behavior. Project summaries and this report record the change. The runner also refreshes its established build identity files; these are excluded from the task patch.

The original native diagnostic found 21 overflowing cards in 32 state/window combinations. The offline card was 712 units high, beginning at y=138 in a 720-unit viewport. The corrected offline card is 549 units high and begins at y=121. The retry card is 611 units high; the longer error fixture is 661 units high and stays inside the window with the brand hidden. Every checked card has at least 16 logical units of window clearance.

Actual commands from the repository root used the pinned 4.7.2 standard console build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_sign_in_fit.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_sign_in_fit.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--output=C:/Codes/Godot/Beat my track/docs/evidence/sign-in-fit-2026-10-25/final-compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_sign_in_fit.gd -Graphical -RenderingMethod mobile -TestArgument '--output=C:/Codes/Godot/Beat my track/docs/evidence/sign-in-fit-2026-10-25/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_localization.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
git diff --check -- game/core/app.gd game/ui/account_panel.gd
git apply --reverse --check docs/evidence/sign-in-fit-2026-10-25/checkpoint.patch
```

The final geometry diagnostic passed 763 checks headless and 763 on desktop Mobile. Native Compatibility passed 760 checks before the final three retained response/resize checks were added to the diagnostic; runtime sources were identical. Four window sizes (1280×720, 960×540, 1600×720 and 800×600), nine account states and all visible control bounds were checked. Existing localization passed 60 checks; the existing app flow passed 141. These are native desktop results, not physical-device results.

Initial setup attempts encountered sandbox certificate/directory access restrictions and PowerShell execution-policy restrictions; the supported runner with process-local execution-policy bypass and reviewed native execution completed. An intermediate diagnostic reported 39 failures: 36 incorrectly counted the hidden country-selector popup's own scroll list; three exposed the logo's comparison against an expanding container instead of the actual available window height. The diagnostic now checks the card's ancestors, and the implementation compares against the window. The original inset/containment requirements were retained. Logs remain in the evidence folder.

Native views:

- [Before, 960×540](evidence/sign-in-fit-2026-10-25/before/offline-960x540.png)
- [Complete card, 960×540](evidence/sign-in-fit-2026-10-25/final-compatibility/offline-960x540.png)
- [Retry state, 960×540](evidence/sign-in-fit-2026-10-25/final-compatibility/retry-960x540.png)
- [Long error, 960×540](evidence/sign-in-fit-2026-10-25/final-compatibility/long-error-960x540.png)
- [Desktop Mobile, 960×540](evidence/sign-in-fit-2026-10-25/mobile/offline-960x540.png)

Machine-readable results, source hashes, retained failures and the task-only review patch are in `docs/evidence/sign-in-fit-2026-10-25/report.json` and `checkpoint.patch`. The patch is checked in reverse against the working files without staging or reverting concurrent work.

Remaining acceptance: reload the client/view and review the layout and touch interaction on the owner's device. The existing canvas stretch establishes at least a 720-unit logical height for landscape windows. Arbitrarily long future messages or unapproved translations are outside the measured fixtures. No device attachment check or physical-device test was performed. No APK, deployment, real sign-in/purchase, owner-process restart or live backend mutation was performed.
