# Cumulative ad cadence — 2026-10-24

The owner clarifies that the configured **N completed races OR X active game minutes** must accumulate across sessions, with no automatic ad before the first race of each session. This supersedes the session-local counter behavior in the October 22 placement report. A session here means one app launch; background/foreground changes retain the same session.

## Resulting behavior

- **CAD01:** Completed ordinary races and active game milliseconds since the last shown interstitial persist locally in `ad_cadence.json`, alongside the install's root records and outside individual account profiles. Restarting, signing in/out, or changing the configured N/X does not reset these counters. Time away, pause, results, loading and creator/practice exclusions retain their original treatment. No cross-device synchronization is added.
- **CAD02:** A separate, unsaved `session_races` count starts at zero on every launch. The interstitial controller refuses presentation until an ordinary race has completed during that launch, even when saved counters are already due and an apparent break is supplied. The first completed race may show a carried-over ad. This guard is independent of remote tuning and is not reinstated after an ad within the same launch.
- **CAD03:** Studio's player preview accepts completed races this session separately from cumulative race/time totals. A due policy remains suppressed at zero session races. Its timeline now starts from the entered counters and supports `session:0`, which resets session delay/cap/cooldown state while retaining cumulative totals. Desktop and narrow browser checks cover this behavior.
- **R01:** Existing remote N/X bounds, optional AND policy, first-ad delay, hard minima, rewarded cooldown, session cap, fresh permission, paid ad-free suppression, exact-result/account fencing and rewarded-resume authority remain. Both cumulative counters still reset only after an actual interstitial show; no-fill/failure retains them. No live policy, migration, provider integration or deployment is performed.

For example, with N=3, two finishes in one launch and one finish in the next launch trigger an ad after that new launch's first race. If X minutes were already reached in an earlier launch, opening the menu still shows no ad; the next ordinary race must finish first.

## Persistence and practical limits

The new schema-1 state contains only `schema`, `races` and `active_msec`, bounded to the existing 100 races / 7,200,000 milliseconds supported by policy. Loading is limited to 256 bytes and validates whole, finite, nonnegative values and the exact shape. Missing/invalid data starts safely behind the first-race guard. It contains no account identity, entitlement, experiment assignment or provider proof.

The existing atomic JSON helper writes through a temporary file and rename. During ordinary play one owned low-priority writer coalesces progress, with an active-time checkpoint every 15 seconds and requests on finishes, pauses and shown-ad resets. Background/shutdown joins pending work and commits the latest snapshot, preventing an older asynchronous write from overwriting newer counters. The App's background handler flushes after stopping its monotonic time sample. Session delay, cap usage, rewarded cooldown and current-session finishes intentionally remain session-local.

Failed saves retain in-memory progress and can retry; unavailable storage cannot guarantee cross-launch persistence. A foreground process crash/force-kill can lose progress since the most recent checkpoint, normally at most 15 seconds of time. Ordinary backgrounding and clean shutdown flush exact current values. No attempt is made to reconstruct progress held only in memory by an already-running pre-update client. A local client restart is required to use the change.

## Changed sources and actual checks

Runtime: `game/platform/race_ad_breaks.gd`, `game/core/app.gd`. Studio preview: `backend/bmt_backend/game_config.py`, `backend/bmt_backend/admin_ui/game_config.js`. Tests: new `game/tests/test_cumulative_ad_cadence.gd` and UID; updated existing race-ad/configuration tests, `backend/tests/test_game_config.py`, and `scripts/test_game_configuration_console.py`. This report and the three project status records describe the new contract. Original sources and the task-only patch are retained under `docs/evidence/cumulative-ad-cadence-2026-10-24/`.

| Actual command/check | Outcome |
| --- | --- |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_cumulative_ad_cadence.gd -CommandTimeoutSeconds 180` | **28 checks, 0 failures**. Relaunches, both counters, nondefault N/X, due carryover, first-race guard, no-fill, AND, checkpoint/coalescing, invalid state and save recovery. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_race_ad_breaks.gd -CommandTimeoutSeconds 240` | **63 checks, 0 failures**. Existing lifecycle plus actual App background commit, relaunch and first-race finish. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_game_configuration.gd -CommandTimeoutSeconds 180` | **40 checks, 0 failures**. Existing remote permission, delay, AND/minima, cooldown and cap coverage retained; its race fixture now explicitly completes a race. |
| `scripts/dev.ps1 TestApp -CommandTimeoutSeconds 240` | **141 checks, 0 failures**. |
| `.tools/backend-venv/Scripts/python.exe -m pytest tests/test_game_config.py -k 'not postgres' -q`, from `backend/` | **14 passed**, 56 existing dependency/SQLite reflection warnings. New preview cases cover race-due and time-due suppression before the first session race and eligibility afterward. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_game_configuration_console.py --output docs/evidence/cumulative-ad-cadence-2026-10-24/browser` | **13 workflows, zero page errors**. Owned temporary loopback service/database and browser only; existing services/accounts untouched. |
| Focused Ruff and Python compilation | Passed. Browser execution supplies actual JavaScript parsing; standalone `node` was unavailable. |
| Pinned Godot import | Exit 0; new test UID registered. |
| Full script scan | Final **1,064 scripts, 0 failures**. Initial scan failed on the concurrent Desert `desert_dune_edges.gd:5` constant expression. That source changed independently to `Array[Array]`; no Desert source was changed by this task. |
| Scoped whitespace and task-patch reverse check | Final receipts in `report.json`. |

Godot commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, exact pinned engine `4.7.2.stable.official.ed1daf0bf`, and task-specific `.tools/cumulative-ad-cadence-*-user` APPDATA directories. Windows certificate-store access used the established sandbox exception. Assertions were retained; the existing ownership/configuration fixtures were updated to establish a completed session race instead of assigning only the cumulative count.

Actual Studio screenshots:

- [Due counters, first-session-race suppression](evidence/cumulative-ad-cadence-2026-10-24/browser/preview-first-race-gate-desktop.png)
- [Cumulative timeline, desktop](evidence/cumulative-ad-cadence-2026-10-24/browser/preview-cumulative-desktop.png)
- [Cumulative timeline, 390px](evidence/cumulative-ad-cadence-2026-10-24/browser/preview-cumulative-narrow.png)

No phone/tablet attachment check or physical-device test was performed. No APK/export/install, live account/backend mutation, provider-console change, purchase or deployment was performed. Matching client/Studio/API rollout, owner cadence acceptance and actual device acceptance remain; production provider/consent prerequisites remain as documented for the existing debug/demo bridge. Concurrent Desert, Challenge/Garage, security and configuration work and owner processes are preserved.
