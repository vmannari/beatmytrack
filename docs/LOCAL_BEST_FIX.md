# Local best display fix — 2026-09-15

Requirements: R01/R04/R06/R07 (local race flow, timing/PB and persistence).

Tracks queried the Balanced handling partition while ordinary races and Home use the selected handling. This hid valid saved Original+ times. `game/ui/track_browser.gd` now uses `HandlingSelection.config()` and names the displayed label for integration checks. Existing record files and rules partitions are preserved. The owner confirmed Original+ as default; `game/ui/handling_selection.gd` already selects its index 4 at startup.

`game/tests/test_app.gd` now checks the actual Tracks label after results and after a new app instance reloads the saved file. Controlled five-lap fixtures run through the app result handler; these are not human-driven race-time measurements.

Actual commands with pinned Godot 4.7.2.stable.official.ed1daf0bf:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRecords`: 53 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp`: initial added test navigated away from Home before an existing Home assertion, causing a null-label script error. Fixed the test by navigating back before that assertion.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureApp`: final graphical app integration, 100 checks, zero failures; save/reload assertions passed.

Evidence: [Tracks showing 01:48.816](evidence/local-best-fix/tracks-saved-best.png), [app output](evidence/local-best-fix/app-capture.txt), [persistence output](evidence/local-best-fix/records-tests.txt).

No phone test or APK export performed. Remaining acceptance: owner-driven race and restart on the target device. Records remain specific to content, physics, handling and lap rules; older incompatible partitions are retained but not combined. No physics changes. Existing unrelated uncommitted menu work was preserved.
