# Challenge “Checking time…” delay — 2026-10-11

The owner reports a long Checking time… state in challenge creation. Inspection and a failing reproduction identify a client authentication queue defect capable of holding this state while unrelated requests are in flight. The source lookup itself is a small database query; it does not replay or simulate a race.

Requirement IDs: **CH02, CH09–CH11, CH14, B01, R01, Q01**. Preserve the verified source, exact completed-ticket query, account fencing, refresh-token rotation ownership and durable upload semantics.

## Trace and live evidence

`ChallengeCreate._check_source()` sets `_checking`, then waits for `ChallengesClient.source()`, which calls authenticated GET `/v1/challenges/sources`. Backend `sources()` checks the published track/car/board contract, reads the player's PB or the exact requested completed ticket, and returns status/time. Ghost preparation belongs to creation, not this lookup; no verifier, track compilation or recording download occurs here.

Read-only cloud observations saved sanitized route/status/duration fields only. Twelve source requests were found in the preceding 24 hours. Nine successful lookups took **28.39–66.29 ms** of backend handling; the three 401 responses took **19.71–28.08 ms**. Recent source requests include expired-session responses. Public health/readiness probes succeeded. These server durations exclude transport and client waits and do not identify a particular owner account. No owner session file/token was adopted or modified.

The client already sends healthy authenticated GETs independently. After a 401, however, `_authenticated_read()` waited for the general `_busy` mutation queue. A score upload can hold that queue for its 30-second HTTP timeout, and queued mutations can lengthen the wait. A second case waits behind `_refresh_busy` even after a different request has installed fresh credentials, because the refresh owner retains its lock through its original HTTP retry. Existing race tickets had independent handling for these cases; the challenge source GET did not.

`test_challenge_source_priority.gd` reproduces both boundaries with the real dispatcher and ChallengesClient adapter. The baseline reports **21 checks / four failures**: expired PB lookup and exact-ticket lookup remain pending behind a held upload, and already-renewed lookup remains pending behind a held original read in two account cases. Releasing the held transport lets the baseline complete, so the test distinguishes queue waiting from server computation without waiting for a real 30-second timeout.

## Correction

`game/backend/backend_client.gd` gives the exact GET `/challenges/sources` route the same independent credential handling as actual race-ticket POSTs. It can renew while an unrelated upload remains held, and can retry with already-installed credentials while another request retains its original locks. Generation/identity checks, exact query/payload/key, serialized refresh and lock ownership remain. Other reads and mutations retain their original renewal behavior. A debug-only profiling category now identifies challenge-source encode/HTTP/refresh-queue timings without exposing query strings, tokens, IDs or responses.

No cached or invented PB replaces server verification. No HTTP timeout was shortened, no refresh bypass was added, and no server/physics/UI contract changed. Source requests still use the existing 30-second network timeout if transport itself stalls. This fixes a confirmed client defect; it is not a capture of the owner's exact stalled coroutine or proof that every network-related delay is eliminated.

## Files and actual checks

- Changed runtime: `game/backend/backend_client.gd`.
- Added focused regression: `game/tests/test_challenge_source_priority.gd`.
- Documentation: this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, evidence and review receipt.

All native commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned **4.7.2.stable.official.ed1daf0bf**, and isolated workspace-local APPDATA under `.tools/challenge-source-latency-20261011/`.

| Actual command arguments | Outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_challenge_source_priority.gd` | Baseline 21/four failures; final **27/zero failures**. Final stub-transport PB lookup completed in **20.488 ms** with expired credentials while upload remained held; this is client scheduling evidence, not a live end-to-end latency promise. |
| `TestScript -ScriptPath res://tests/test_race_ticket_priority.gd` | **26/zero failures** |
| `TestScript -ScriptPath res://tests/test_expired_ticket_priority.gd` | **19/zero failures** |
| `TestScript -ScriptPath res://tests/test_refreshed_ticket_priority.gd` | **26/zero failures** |
| `TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd` | **28/zero failures** |
| `TestScript -ScriptPath res://tests/test_challenges.gd` | Headless **161/zero failures**, including exact-result creation/pending/error/source gates. |
| `TestApp` | **99/zero failures** |
| `.tools/backend-venv/Scripts/python.exe .tools/challenge-source-latency-20261011/inspect_live.py` | Two read-only observations: health/readiness and sanitized request timings; second query specifically targets sources. |
| Scoped checkpoint `git diff --check` | Passed. |

The first restricted native attempt emitted a Windows certificate-store access error. The normal-access baseline retains its expected failures, and final/regression logs are clean. No assertions were removed or weakened.

[Baseline](evidence/challenge-source-latency-2026-10-11/baseline.log), [final focused test](evidence/challenge-source-latency-2026-10-11/final.log), [source server timings](evidence/challenge-source-latency-2026-10-11/live-source-read-only.json), [challenge checks](evidence/challenge-source-latency-2026-10-11/challenges.log), [application checks](evidence/challenge-source-latency-2026-10-11/app.log).

## Acceptance and review

Restart the Windows game to load the client fix, then retry challenge creation under the owner's actual sign-in/session/network. Existing debug profiling can separate client refresh-queue time and HTTP time if a delay remains. No owner-specific live coroutine, phone/device test or attachment check, Android export/install, backend change/deployment, player/race/score writes, full Validate or production deployment was performed. Read-only cloud access did not change a service, schema or account. There are no visible UI changes requiring new screenshots.

Review ref: `refs/codex/challenge-source-latency-2026-10-11`; compare it with its snapshot parent. [Checkpoint receipt](evidence/challenge-source-latency-2026-10-11/checkpoint.json) records the task files and preserved HEAD/index.
