# Prompt times in This week's tracks — 2026-10-22

WRT01–WRT03 / R01 / Q01: the owner reports that their time takes too long to appear in the weekly overview after finishing a race. The overview previously read only the full server snapshot. Immediate result previews and confirmed ticket outcomes were available to the separate result screen, but the overview waited for the subsequent full-board read. A verified receipt already received by the durable-upload status path also waited for the Rivalry poll deadline.

WRT01 displays a first finish or faster weekly PB immediately in its overview row, with **Verifying...** beneath it. Its displayed rank, weekly points and completed-track count remain verified. A slower retry keeps the existing weekly best. WRT02 uses the confirmed ticket outcome for the overview time/rank/completion while the full-board request runs; an older snapshot cannot erase that confirmed time. WRT03 consumes a valid cached verification receipt on the next existing caller tick without another result HTTP request or waiting for the poll deadline. The ordinary HTTP polling interval, server work and failure backoff are unchanged.

The presentation is bounded to the existing last-result state. It does not persist an unverified PB, change server standings, grant points, shorten server verification, or alter the canonical racer. Existing ticket/account/car/group/week fences, normal results first, five laps, best-only scoring, upload durability and retries remain. Pending presentation follows the current last result; durable uploads retain responsibility for earlier races and restart recovery.

## Changed files

- `game/race/weekly_rivalry.gd`: separate overview summary from verified board data, showing pending time only and projecting confirmed receipts through the existing result-board calculation.
- `game/ui/weekly_rivalry_page.gd`: render the summary during both initial construction and retained-row updates, including the pending label and confirmed completion count.
- `game/backend/weekly_rivalry_client.gd`: consume valid cached receipts before the poll deadline.
- `game/tests/test_rivalry_track_time.gd`: real adapter and overview controls with controlled queued/cached/full-board responses, first finishes, faster/slower retries, exact slots, stale snapshots, malformed receipts, retained controls and account reset; native captures at 1280×720 and 960×540.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report: requirements and actual evidence.

## Actual validation

| Check | Result |
|---|---|
| Initial original-source reproduction | 15 checks, 9 failures; includes the initial null-rank formatting fixture error described below |
| Final focused headless | 18 checks, 0 failures |
| Final Compatibility / desktop Mobile | 26 / 26 checks, 0 failures |
| Existing feedback / result board | 18 / 10 checks, 0 failures |
| Weekly Rivalry / track detail | 1115 / 321 checks, 0 failures |
| Results Continue / App | 60 / 141 checks, 0 failures |
| Project parser | 915 scripts, 0 failures |
| Scoped whitespace check | Pass |

All test transport uses controlled fixture responses. No live account or race was submitted. The pending/confirmed native captures were visually inspected; the new time and status fit at both tested sizes. Examples: [pending Mobile at 960×540](evidence/rivalry-time-2026-10-22/final-mobile/pending-960x540.png), [confirmed Compatibility at 960×540](evidence/rivalry-time-2026-10-22/final-gl_compatibility/confirmed-960x540.png). These are desktop renderers, not Android execution or live latency measurements.

Actual repository-root command forms:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-time/final-check-profile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_track_time.gd -CommandTimeoutSeconds 90

$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-time/capture-profile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_track_time.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -TestArgument '--evidence=res://../docs/evidence/rivalry-time-2026-10-22/final-gl_compatibility' -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_track_time.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence=res://../docs/evidence/rivalry-time-2026-10-22/final-mobile' -CommandTimeoutSeconds 120

$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-time/regression-profile'
foreach ($suite in @('test_rivalry_feedback','test_rivalry_result','test_weekly_rivalry','test_rivalry_track_detail','test_rivalry_results_continue','test_app','test_script_parse')) {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath ('res://tests/'+$suite+'.gd') -CommandTimeoutSeconds 180
}
git diff --check -- game/race/weekly_rivalry.gd game/ui/weekly_rivalry_page.gd game/backend/weekly_rivalry_client.gd
```

The pinned executable is Godot 4.7.2 through `scripts/dev.ps1`. Full outputs are in [the evidence logs](evidence/rivalry-time-2026-10-22/logs). The first sandbox run failed to read the Windows root certificate store; native execution with workspace profiles then ran successfully. Initial rank expectations were corrected to the established em dash / `#1` formatting. A later Mobile fixture initially let its poll deadline expire during native capture, producing one failure; the test now explicitly sets a future monotonic deadline before testing malformed/valid cached receipts. That original log is retained as `initial-mobile-deadline-fixture.log`. The first-finish snapshot was also sorted after removing the player's earlier results, matching normal server ordering. No runtime assertions were weakened.

The task-only runtime/test diff is [source-checkpoint.patch](evidence/rivalry-time-2026-10-22/source-checkpoint.patch), against saved pre-task sources under `before/`; concurrent backend, Studio, reward and other workspace work is preserved. Local client restart/update and owner workflow acceptance remain. No phone attachment check or device test, APK/export/install, backend/account/queue mutation or deployment was performed.
