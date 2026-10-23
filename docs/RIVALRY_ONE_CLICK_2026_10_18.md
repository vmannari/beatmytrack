# Rivalry starts from the first Race tap — 2026-10-18

RSC01–RSC03 / R01 / Q01: the owner reports needing to press Race twice to start a Rivalry race. A real-adapter, isolated viewport-input reproduction confirms that the first mouse click or touch tap is silently discarded when a background refresh is waiting for appearance synchronisation. `refresh()` sets `busy` before `_fetch()` announces the new state; the existing enabled button calls a start handler that immediately returns for `rivalry.busy`. The original-source regression reports 16 checks with four failures: no ticket and no race for each input type during that window.

RSC01 retains the explicit start, displays the existing loading overlay immediately and waits for the already-running refresh before requesting the race ticket. RSC02 preserves the selected account/car scope, navigation, group/week, immutable track version, active/available state, duplicate-start guard and existing loading deadline. Changed competition data produces actionable feedback; deliberate account changes or navigation cancel quietly. RSC03 keeps the Race action available during a refresh of an already-confirmed, current snapshot and prevents deferred page activation or polling from starting another refresh under race loading. Cached snapshots, completed weeks, unavailable tracks and other busy actions retain their original restrictions.

R01 preserves five competitive laps, server-issued authorization, normal results first, existing ghost selection/retry behavior and scoring. There is no canonical physics/rules/track/backend change.

## Changed files

- `game/core/app.gd`: wait and validate the retained start; distinguish background refresh presentation; suppress redundant polling/page-activation refreshes during loading.
- `game/ui/weekly_rivalry_page.gd`: retain the Race action during a usable background refresh, while loading and unavailable states remain disabled.
- `game/tests/test_rivalry_one_click.gd`: actual viewport mouse/touch dispatch, real refresh/ticket adapter, controlled appearance/current responses, exactly one authorization, five laps, duplicate starts, redundant refreshes, changed group/version/availability, navigation/account cancellation and loading timeout.
- `game/tests/test_rivalry_entry.gd`: give appearance synchronisation its own fixture response, so a held membership response exercises membership rather than being consumed by a different endpoint. Every existing assertion remains.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report: requirement/status/evidence bookkeeping.

## Actual validation

| Check | Result |
|---|---|
| Original ignored-first-input reproduction | 16 checks, four expected failures |
| Final focused headless / Compatibility / desktop Mobile | 54 / 54 / 54 checks, zero failures |
| Existing start-failure / ghost-and-retry | 29 / 17 checks, zero failures |
| Weekly Rivalry / track detail / results Continue | 1115 / 321 / 60 checks, zero failures |
| Corrected membership-entry fixture | 66 checks, zero failures |
| App | 141 checks, zero failures |
| Project parser | 896 scripts, zero failures |

All new cases use a nonexistent fixture origin with overridden transport, disposable records/library/cloud storage and no live service. Native Compatibility and desktop Mobile captures show the loading cover after one input while membership is held, followed by the actual five-lap race. Inspected examples:

- [Compatibility: first click waiting for refresh](evidence/rivalry-one-click-2026-10-18/compatibility/waiting-refresh-mouse.png).
- [Desktop Mobile: one touch starts the race](evidence/rivalry-one-click-2026-10-18/desktop-mobile/started-current-touch.png).

Actual repository-root command forms, using the pinned executable through the existing entry point:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-one-click/profile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_one_click.gd -CommandTimeoutSeconds 180

$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-one-click/compatibility-profile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_one_click.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -TestArgument '--evidence=res://../docs/evidence/rivalry-one-click-2026-10-18/compatibility' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_one_click.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence=res://../docs/evidence/rivalry-one-click-2026-10-18/desktop-mobile' -CommandTimeoutSeconds 180
```

The same headless `TestScript` form ran `test_rivalry_start_failure.gd`, `test_rivalry_ghost_retry.gd`, `test_weekly_rivalry.gd`, `test_rivalry_track_detail.gd`, `test_rivalry_entry.gd`, `test_rivalry_results_continue.gd`, `test_script_parse.gd` and `test_app.gd`; regression profiles are under `build/rivalry-one-click/{regression-profile,broad-profile,entry-profile,parser-profile}`. Full captured command output is retained in the evidence logs. The focused deadline case deliberately emits the existing deadline timer and logs its expected timeout warning.

## Initial attempts and remaining acceptance

The first sandbox attempt could not access the Windows certificate store; approved native runs use workspace profiles. Initial input fixtures were corrected to populate server standings, await covered world preparation before leaving the race, return to detail between attempts, and finish a simulated menu transition before clicking. These corrections retain the actual button dispatch and every intended assertion.

The older membership-entry suite initially reports 66 checks and 30 failures. Loading saved pre-task App and page sources in a separate fixture scene reproduces the exact same 30 failures. Its service fixture did not distinguish `/rivalry/appearance` from the membership response it intended to hold. Returning the appearance response independently restores all 66 checks, with no weakened runtime or test assertions. The separate baseline loader initially needed a script-type alias correction; both attempts are retained. No working runtime source was swapped for the baseline comparison.

`evidence/rivalry-one-click-2026-10-18/source-checkpoint.patch` contains only this task, against saved sources or reconstructed bookkeeping bases that retain other work. Concurrent editor/visual/publication/native work and the existing mixed working tree are preserved. Owner workflow acceptance and physical-device confirmation remain. No phone attachment check or device test, APK/export/install, live backend mutation or deployment was performed.
