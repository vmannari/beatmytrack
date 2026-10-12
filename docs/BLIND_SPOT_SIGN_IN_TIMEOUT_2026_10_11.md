# Blind Spot sign-in timeout, 2026-10-11

Owner: Blind Spot times out on Windows while loading the track; suspects sign-in. Requirements RLOAD07 (reuse completed credential renewal for race-start priority), RLOAD08 (trace actual Blind Spot with isolated data), B01/B05/B07/R01/Q01. No new user-facing text or layout.

## Findings and fix

Blind Spot's existing immutable document is8,846bytes/21pieces/3objects/96route points. A real isolated native metadata-to-race start completed locally in1,895.645ms; repeat809.647ms. Both were actual five-lap Game starts, with no completed race or score. This does not establish the duration on the owner's exact installed client.

Read-only live backend probes returned health/ready/bootstrap HTTP200 in192.48/424.74/123.10ms. The limited recent request sample included48 successful refreshes within82seconds and a successful ordinary ticket in42.4ms. Template-only logs deliberately omit account credentials and identities, so those refreshes cannot be attributed to the owner or their specific race. No live server timeout was established.

The actual client dispatcher had a reproducible sign-in queue defect: two requests start with expired access. One renews credentials successfully, then retries its original non-race read while retaining the rotation lock. The race's old401 reply arrives after that renewal, but `_renew_session` waits for the entire held read even though valid replacement access is already available. Existing35s renewal-queue/30s HTTP waits can consume a substantial part of the45s race-loading deadline. The baseline regression reports15checks/3failures, one for each Free Race/Rivalry/challenge ticket route. It releases the held read after the bounded assertion; it is not a measurement of an actual45s production wait.

A seven-line correction in `game/backend/backend_client.gd` retries **only actual POST race-ticket routes**, using the already changed, nonempty access credential and the exact original payload/idempotency key. It leaves both the read owner's mutation and renewal locks intact. The original generation checks reject account changes. No extra refresh is minted, no failed invariant is bypassed, and non-ticket operations retain their serialized renewal behavior. Credentials are not added to persistence or logs. The45s recovery timer and existing ticket/manifest/world gates remain.

`game/tests/test_refreshed_ticket_priority.gd` adds all three routes, account change during the early retry, explicit non-ticket serialization, one-renewal ownership and key checks. Initial focused15/3fail became15/0; expanded final26/0.

## Actual live starts and diagnostic corrections

`game/tests/profile_blind_spot_start.gd` is an opt-in native profiler. Its fixture/helper files are prepared under ignored `build/blind-spot-timeout-20261011/`; they are not runtime dependencies. The local run uses the existing cached document. The live run obtains a fresh public head and compares its manifest to `/v1/manifest`, signs in the existing ordinary `cloud-test-observer` development identity in isolated records/cache, and starts the normal Free Race path.

Current public head: all nine pinned contract fields and Compact configuration match the active verifier. Signed-in native starts completed in3,220.849ms and1,543.047ms; five laps, loading overlay closed, no game error. Initial ticket HTTP253ms/repeat208ms; initial world-loading848ms/repeat444ms. These starts issued two uncompleted diagnostic tickets. They produced no score/rating/resume writes or completed race results. The existing account/session files of the owner were neither adopted nor modified by these diagnostics.

Earlier diagnostic attempts were rejected correctly: the original artificial diagnostic identity cannot enter ordinary public racing, and the first cached Blind Spot version had an obsolete verifier contract. Three artificial attempts and two obsolete-version attempts were denied. The latter shares the same document hash as the current head but has a different immutable version; the current published head was fetched read-only and used, without changing server/player data or weakening pin checks. One early profiler retried after an exclusive offline dialog and hit a second-window error; it now stops immediately on failure. Denied attempts and failed runs are not counted as successful starts.

The owner's exact previously timed-out coroutine is unavailable: no matching active Windows game was found, and concurrent desktop test processes rotate the shared default Godot log. The owner reported Loading track, while the reproduced renewal queue directly affects Connecting race. The wording may be generic, but that cannot be assumed. This patch resolves a confirmed sign-in defect and passes current-head starts; it is not proof that every cause of the owner's prior timeout is eliminated. Restart/retry on the owner's actual Windows game remains the direct acceptance check. No sign-out, production deployment, session deletion or automatic offline substitution is required by this source change.

## Actual commands and outcomes

All Godot commands use pinned4.7.2.stable.ed1daf0bf through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Actual outcome |
|---|---|
| `-Action TestScript -ScriptPath res://tests/test_refreshed_ticket_priority.gd` | Baseline15/3fail; final26/0 |
| `-Action TestScript -ScriptPath res://tests/test_expired_ticket_priority.gd` |19/0 |
| `-Action TestScript -ScriptPath res://tests/test_race_ticket_priority.gd` |26/0 |
| `-Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd` |28/0 |
| `-Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical` |18/0; expected synthetic Connecting race/Preparing start timeout warnings retained |
| `-Action TestApp` |99/0 |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` |508scripts/0fail |
| `-Action TestScript -ScriptPath res://tests/profile_blind_spot_start.gd -Graphical` |Two real local starts,1.896/0.810s |
| `.tools/backend-venv/Scripts/python.exe build/blind-spot-timeout-20261011/run_live.py` |Final existing ordinary observer/current-head run: two signed-in starts,3.221/1.543s; earlier rejected runs recorded above |
| `.tools/backend-venv/Scripts/python.exe build/blind-spot-timeout-20261011/inspect_live.py` |Read-only sanitized health and recent route timings |

Runtime change: `game/backend/backend_client.gd`. Added two test/profiler scripts and UIDs; documentation/status/plan updated. Native viewport rendering is exercised; no visible UI changes require new presentation screenshots. Evidence under `docs/evidence/blind-spot-timeout-2026-10-11/` includes sanitized live/local measurements, public pinned-contract comparison, initial regression failure and final test receipts. Private session/config/secret files and raw logs containing credentials are excluded.

The connected OnePlus DN2103 was checked read-only; no running game process was found on that phone. User confirmed Windows. No phone/device timing test, Android export/install, fullValidate, backend/schema/physics change or production deployment was performed. The only live race writes were the two isolated uncompleted diagnostic tickets; normal five laps, exact completed-ticket results, durable uploads, optional ghosts and public/artificial isolation remain intact.

Task-only review ref: `refs/codex/blind-spot-sign-in-timeout-20261011`. Receipt and binary-capable text patch accompany the evidence; HEAD and the user's index remain unchanged. The runtime source requires restarting the Windows game to use the fix.
