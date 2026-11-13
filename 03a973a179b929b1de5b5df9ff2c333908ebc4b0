# Weekly Rivalry track profiles — 2026-10-25

WRP01: Each of the five overview rows overlays its own saved route on its biome picture. WRP02: The cream route has a dark outline, fits without stretching, leaves the numbered corner clear and passes pointer input through to the existing row. R01/Q01: Reuse the existing vector route fitting and preserve competitive data and concurrent work.

The runtime change is fourteen added lines in `game/ui/weekly_rivalry_page.gd`: a small `LapRouteView` subclass and one overlay per thumbnail. It uses the same bounded `document.points` metadata as the existing detail preview. Empty routes remain empty. No new artwork, network reads, dependencies or per-frame geometry work are added.

Native before/after images at 1280×720, 960×540 and 1600×720 are under [the evidence directory](evidence/rivalry-track-profiles-2026-10-25/). Final Compatibility and desktop Mobile visual checks both pass 381 checks, including real pointer press/release, keyboard navigation and score refresh. Desktop Mobile means Vulkan on the PC; no physical-device test or attachment check was performed. The initial Compatibility run passed 372 checks before concurrent podium checks were added.

The broader headless Weekly Rivalry suite reports 1064 checks / six failures: the winner-height and maximum-podium-height assertions at each of three window sizes. Replaying the exact task-start page in isolated process memory reports 1065 checks / the same six failures (one extra baseline compilation check). Those failures are retained, without changing thresholds or the suite. The temporary diagnostic entry point was removed from the game; its source is retained in the evidence directory.

The first default-sandbox runs could not read the Windows root certificate store. Native reruns used separate workspace APPDATA directories. Initial failure logs are retained. No owner process was restarted, and no APK, account/backend operation or deployment was performed.

Existing translations and concurrent podium changes are preserved. `before/` retains the exact original page. `checkpoint-base/` retains the final page with only this task's fourteen additions removed, so [task-only.patch](evidence/rivalry-track-profiles-2026-10-25/task-only.patch) excludes the other work. `git apply --reverse --check` and scoped `git diff --check` pass. No mixed-workspace commit was made.

## Commands

All engine commands use the pinned Godot 4.7.2 entry point, prefixed by `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. The workspace APPDATA directories are `build/rivalry-track-profiles-{user,mobile-user,regression-user,baseline-user,parser-user}`. `BMT_RIVALRY_POLISH_EVIDENCE_DIR` points to this task's evidence directory; the before run also sets `BMT_RIVALRY_POLISH_BEFORE_SOURCE` to its `before/weekly_rivalry_page.gd`.

```powershell
-Action TestScript -ScriptPath res://tests/test_rivalry_view_polish.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--before' -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_rivalry_view_polish.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_rivalry_view_polish.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/capture_rivalry_track_profiles_baseline.gd -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/rivalry-track-profiles-2026-10-25/task-only.patch
git diff --check -- game/ui/weekly_rivalry_page.gd
```

The baseline command used the retained `baseline-diagnostic.gd` temporarily copied into `game/tests/`. Full outputs, final parser outcome and source SHA-256 fingerprints are recorded in `logs/` and `report.json`. Reloading the client and owner/device appearance acceptance remain.
