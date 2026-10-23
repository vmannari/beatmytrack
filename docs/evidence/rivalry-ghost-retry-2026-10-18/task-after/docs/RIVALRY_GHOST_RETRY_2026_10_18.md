# Rivalry ghost consistency and results retries — 2026-10-18

WR06 / WR07 / WR08 / GH01 / R01 / Q01: the owner reports intermittent ghosts, especially in Rivalry, and requests confirmation that Race Again from results still counts in the weekly standings.

Three presentation defects are corrected. The app previously started a ghost prefetch and later read only its cache; a track that loaded before the request finished started without its selected ghost. The final loading stage and retry now await the same coalesced request. The detail page no longer converts an automatic target policy into permanent Off when the field has no recorded finishes. Retry prepares a missing ghost mesh after replacing local PB recordings with the chosen Rivalry or challenge recording. Explicit no-ghost choices, unavailable recordings, personal preferences, countdown/finish visibility, canonical simulation and bounded interpolation remain unchanged.

Downloads retain the existing transport timeout, eight-entry/8 MiB cache and 30-second freshness policy. Pending callers share one request and receive its validated recording; failures can retry. Account, generation, group, track-slot and run changes fence pending responses. A missing/unavailable ghost remains optional and does not prevent a verified race.

The existing Rivalry retry authorization and scoring flow was correct. Both results actions obtain a distinct weekly ticket and retain the competition result identity. The extended HTTP integration completes three real five-lap attempts with the pinned fixture controls, queues the recordings, receives actual verifier results and checks Rivalry outcomes for the completed retries. Normal-summary Race Again is exercised before the previous result is verified; Rivalry-feedback Race Again is also exercised. Equal-time retries keep the existing weekly PB and award zero additional points. A separate scoring regression covers improved, slower and tied results.

The real login/logout path also exposed an untyped empty array passed through a dynamically typed publication-notification node. That call now supplies `Array[Dictionary]`. Rivalry's deferred standings callbacks accept `Variant` arguments so their existing validity checks can discard freed controls during rapid replacement. These are callback corrections, with no publication/scoring policy change.

## Changed files

- `game/core/app.gd`: awaited selected ghost, retry mesh preparation and typed empty account-callback collection.
- `game/backend/weekly_rivalry_client.gd`: coalesced requests, valid slot keys and stale-response fencing.
- `game/ui/weekly_rivalry_page.gd`: retain targeting policy in empty fields; permit validity checks after deferred controls are freed.
- `game/tests/test_rivalry_ghost_retry.gd` and UID: controlled delayed transport with real adapter/app startup/retry, empty-field recovery, warm cache, Off, download recovery, account fencing and actual mesh visibility.
- `game/tests/test_weekly_rivalry_http.gd`: completed retries through both results actions and actual server outcomes; wait for real profile restoration/navigation.
- `game/tests/test_weekly_rivalry.gd`, `game/tests/test_rivalry_track_detail.gd`: preserve automatic policy without fabricated ghosts.
- `AGENTS.md`, `WEEKLY_RIVALRY.md`, this document and evidence.

## Actual validation

| Check | Result |
|---|---:|
| Focused headless / native Compatibility / desktop Mobile | 17 / 17 / 17 checks, 0 failures |
| Native app, disposable HTTP API, actual verifier | 44 checks, 0 failures; pytest 1 passed |
| SQLite improved/slower/tied best-only scoring | pytest 1 passed |
| Weekly Rivalry / track detail / results Continue | 1115 / 321 / 60 checks, 0 failures |
| Personal ghosts / scalability / Free Race restart | 38 / 17 / 17 checks, 0 failures |
| App / project parser | 140 checks / 865 scripts, 0 failures |

Each native process sets `APPDATA` and `LOCALAPPDATA` to a dedicated directory under `build/rivalry-ghost-retry-2026-10-18`; fixtures also inject records/library/cloud directories. Existing player files and live services are not used. Actual repository-root commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_ghost_retry.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_ghost_retry.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_ghost_retry.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence=res://../docs/evidence/rivalry-ghost-retry-2026-10-18/ui-mobile' -CommandTimeoutSeconds 180
```

The same TestScript command ran `test_weekly_rivalry.gd`, `test_rivalry_track_detail.gd`, `test_rivalry_results_continue.gd`, `test_personal_ghosts.gd`, `test_backend_scalability.gd`, `test_free_race_restart.gd`, `test_app.gd` and `test_script_parse.gd`. From `backend`:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_rivalry_http.py::test_weekly_rivalry_through_native_app -q -s --tb=short --junitxml=../docs/evidence/rivalry-ghost-retry-2026-10-18/http-settled.xml
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest 'tests/test_rivalry.py::test_verified_weekly_bests_points_ties_and_no_attempt_farming[sqlite]' -q --tb=short --junitxml=../docs/evidence/rivalry-ghost-retry-2026-10-18/scoring-sqlite.xml
```

[Logs, XML receipts and task checkpoint](evidence/rivalry-ghost-retry-2026-10-18/). Actual native visibility captures: [cold Compatibility](evidence/rivalry-ghost-retry-2026-10-18/ui/cold-ghost.png), [retry Compatibility](evidence/rivalry-ghost-retry-2026-10-18/ui/retry-ghost.png), [cold desktop Mobile](evidence/rivalry-ghost-retry-2026-10-18/ui-mobile/cold-ghost.png), [retry desktop Mobile](evidence/rivalry-ghost-retry-2026-10-18/ui-mobile/retry-ghost.png). These use controlled fixture poses on the real track. The Compatibility fixture retains a start-light cue after manually skipping countdown; Mobile resets that cue before capture. Cold native hitch diagnostics remain visible; no FPS/speed claim is made.

## Initial attempts and limits

Initial direct invocation hit PowerShell execution policy. CheckScript without its required script argument and restricted native attempts hit user-log/certificate access; final commands use disposable workspace profiles and approved native execution. One rerun collided with the initial open log, so later logs have distinct names. The focused fixture initially set preferences before startup replaced profile records; it now sets them after startup without weakening assertions. The first HTTP run completed all 44 domain checks but failed the strict script-error gate on the account callback type error. Later attempts exposed fixture navigation before profile restoration; the fixture now waits for the actual lifecycle. A configured PostgreSQL instance timed out; the final scoring command explicitly uses SQLite, with no PostgreSQL acceptance claim.

The first native capture encountered a missing import for a concurrently added menu texture. The Import wrapper stopped during an extension scan; direct `Godot --headless --path game --editor --import --verbose` completed local imports, after which both renderer runs passed. Original attempts are retained. Pytest retains its existing Starlette/httpx deprecation warning.

The mixed working tree and concurrent features are preserved. The task checkpoint is a patch against saved sources with unrelated concurrent edits retained in its reconstructed base, not a combined working-tree commit. Owner driving/appearance and physical-device acceptance remain. This task performs no phone attachment check or device test, no APK build/install, no live backend mutation and no deployment.
