# Race settings scrollbar padding, 2026-10-08

Requirements: R01, V03, V05, Q01; owner's race-settings overlap report.

`game/ui/race_pause_menu.gd` now wraps the scrolling column in a horizontally expanding `MarginContainer` with 16 logical pixels of right padding. This separates the scrollbar from every control, including the zoom slider and dropdowns, throughout the shared pause drawer. No UI text was added.

Actual validation used pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with `APPDATA` redirected to `build/race-settings-padding-user`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CapturePause -CommandTimeoutSeconds 60
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_race_settings_padding_review.gd -Graphical -CommandTimeoutSeconds 60
git diff --check -- game/ui/race_pause_menu.gd
```

The existing pause-menu check passed **17 checks, zero failures**, covering pause/resume, frozen simulation and particles, settings/back navigation and compact layout. The one-off capture script ran with isolated empty preferences and the Ghost section visible: measured content-to-scrollbar gaps were **16.2 / 16.0 / 16.0** at **1280×720 / 960×540 / 1600×720**. All PNG writes succeeded. The six retained top/bottom settings captures were inspected; the controls have a clear gutter and the bottom Back action remains reachable.

Evidence and a task-only patch are in [race-settings-padding-2026-10-08](evidence/race-settings-padding-2026-10-08). The capture script is retained there and was removed from `game/tests` after review. Actual successful logs are retained alongside it. Existing unrelated work was preserved.

Initial direct script invocation hit the Windows execution policy; `-ExecutionPolicy Bypass` resolved it. Sandboxed graphical attempts failed on the default user log path and Windows root-certificate-store access; isolated `APPDATA` and approved local unsandboxed runs resolved those restrictions. An initial capture invocation outside `res://tests/` was rejected by the build entry point; the temporary review script was then run inside its supported path. A first capture omitted Ghost; final captures include it. No failing invariant was relaxed.

No phone attachment check, physical-device test, Android export/install, full regression suite or deployment was performed. Remaining acceptance: owner visual review and physical-device scrolling/touch review.
