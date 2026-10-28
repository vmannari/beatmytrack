# One track report option in the race pause menu

RPT01: The race pause menu keeps **Report track** and removes **Track creator**, which previously opened player reporting/blocking. The existing cloud-track/client availability guard and track-report action stay intact. Runtime change: one removed row in `game/ui/race_pause_menu.gd`.

The capture helper `game/tests/capture_race_pause_track_report.gd` and its UID produce local native screenshots using fictional track metadata and a client without networking. The helper opens the report form without submitting it. Existing unrelated changes in the menu's button sizing are preserved and excluded from the [task-only checkpoint](evidence/race-pause-track-report-2026-10-26/checkpoint.patch).

Actual validation with pinned Godot 4.7.2, Compatibility rendering and isolated workspace user data:

- Existing pause integration: **17 checks, zero failures**, runner exit 0. Pausing, frozen presentation, Settings, Resume and compact capture pass.
- Native visual capture, exit 0: [1280×720](evidence/race-pause-track-report-2026-10-26/pause-1280x720.png) and [960×540](evidence/race-pause-track-report-2026-10-26/pause-960x540.png) show Resume, Restart, Settings, Report track, Help and Quit. There is one reporting row.
- The action opens [Report track](evidence/race-pause-track-report-2026-10-26/report-track-960x540.png), retaining the fixture's exact track/version IDs. No report was submitted.
- Task-scoped whitespace and reverse-patch checks pass.

Commands run from the repository root in PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/race-pause-track-report/user'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_race_pause_track_report.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_pause_menu.gd -Graphical -RenderingMethod gl_compatibility -TestArgument evidence=res://../docs/evidence/race-pause-track-report-2026-10-26/integration -CommandTimeoutSeconds 120
git diff --check -- game/ui/race_pause_menu.gd
git apply --check --reverse docs/evidence/race-pause-track-report-2026-10-26/checkpoint.patch
```

The first sandboxed capture could not read the Windows certificate store. Only this task's failed capture processes were stopped before retrying with native access. The first native capture helper then accessed a null HUD map before explicitly binding the fixture; this helper issue was corrected. A subsequent capture exposed a startup-focus pause that toggled back to driving; final screenshots explicitly retain the paused state. Final capture and existing integration both exit 0. The integration logs a 167 ms startup frame; no performance claim is made.

Reload and owner/device appearance and touch acceptance remain. No device attachment check or device test, APK, real authentication, report submission, deployment, owner-process restart, staging or commit was performed. The development entry point refreshes generated client identity outside this task's runtime checkpoint. [Machine-readable report](evidence/race-pause-track-report-2026-10-26/report.json).
