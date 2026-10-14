# Recovery request flood — 2026-10-12

Owner requests the complete root cause of the Race Again `RATE_LIMITED` dialog, a review of similar retry paths, fixes and regression tests. Requirement IDs REC01–REC06, B05/B07, R01, Q01. This is a client reliability change; canonical simulation, scoring, five laps, backend limits and server resource authority are unchanged.

## Confirmed cause

Read-only Cloud Logging inspection of POST traffic between 18:15:00 and 18:27:00 UTC (21:15–21:27 Helsinki) found 1,182 `/v1/resume-recovery` requests from the Godot Windows user agent: 926 HTTP 422, 151 HTTP 401 and 105 HTTP 429. Three `/v1/runs` uploads and one `/v1/run-tickets` request also received 429. The ticket rejection was at 18:24:41.851145 UTC. Logs do not attribute requests to a particular Godot process or account; no CPU/GPU overload conclusion or exact instance count is inferred.

The 17 saved local recovery journals were inspected without changing them. Each contains a confirmed resume, whole-valued tick fields and valid-length operation/race/ticket identities. Godot's JSON parser reloads those integers as floats. The existing recovery path sent the restored dictionary directly. An actual pinned-engine reproduction serialized `ordinal: 1.0`, `input_offset: 3600.0`, `from_tick: 3600.0` and `to_tick: 2400.0`. The existing strict Python `ResumeRecovery`/`Consume` model rejected all four fields with `int_type`. All 17 journals reproduce those same validation errors. Existing native mocks skipped the serialized HTTP boundary and therefore missed this defect.

Recovery retried a prefix of up to 16 files every roughly 5–7.5 seconds, ignoring both terminal validation failures and transient errors. The account budget is shared with race tickets and result uploads. This explains the request flood and why Race Again was blocked. Codex CPU work does not spend this budget. Additional running game instances sharing credentials/journals can amplify the traffic; logs alone do not identify which instances were involved.

## Changes and reviewed adjacent paths

- REC01: `game/backend/resume_recovery.gd` builds a validated recovery request. Only finite, bounded, whole-valued integer fields are cast; fractions, strings, unknown fields and invalid identities are rejected locally. Existing saved journals are repaired at the request boundary without changing charge keys or replaying consumption.
- REC02: one recovery write per five-second interval, rotating bounded scans rather than a permanently retried prefix, scope-wide exponential backoff, bounded `Retry-After` and persisted cooldowns. Definitive rejections are preserved with a failure marker for repair, not repeatedly posted. Authoritatively resolved operations are retired; a failed local removal cannot repeatedly resubmit a known resolved operation. Active uncertain races are never abandoned by the background worker. Account/origin fences remain.
- REC03: `game/backend/backend_client.gd` persists the current access credential alongside the existing refresh credential in the same private session file. Under the existing process lock, a matching explicit login reuses a newer saved credential before rotating again. A rejected cached credential falls back to refresh; login, sign-out and in-flight identity fences remain. This fixes the separately reproduced alternating-instance rotation loop. The live refresh counts alone do not prove that every refresh had this cause. `Retry-After` numeric headers now retain waits up to one hour instead of truncating them to one minute.
- REC04: `game/backend/cloud_tracks.gd` paces background writes (including restore reconciliation and verifier retries) and stops the entire batch on 429. Its saved per-job waits also retain longer server cooldowns. Fresh player race authorization retains its independent path and original ticket/key semantics.
- REC05: `game/backend/track_lifecycle.gd` backs off failed status polling and malformed publication successes, using monotonic in-process deadlines and persisted restart waits. Incomplete published receipts retain a readable prior state; finishing retries are paced too. Explicit publish/retry resets the corresponding wait. Local drafts and proof packages stay intact.
- REC06: `game/tests/test_resume_recovery_budget.gd`, `backend/tests/test_resume_recovery_wire.py` and `scripts/test_recovery_postgres.py` add native and actual-wire/backend regressions. Existing session/recovery/publication tests exercise the new scheduler. The session mock now returns valid `/me` and `/runs` replies; publication retry tests explicitly advance the monotonic deadline instead of only clearing the old wall-clock field.

Also reviewed: result-save queue storage retries, refresh recovery keys/process lock, trajectory/control/rewind upload normalization, telemetry restore normalization/backoff, and challenge/Weekly Rivalry polling backoff. These already retain operation identity or normalize their integer fields. No broad JSON coercion or weaker backend validation was added.

## Actual commands and outcomes

Pinned build: `godot-version.txt`, 4.7.2.stable.official.ed1daf0bf; entry point `scripts/dev.ps1`. Native runs use a task test profile (`$env:APPDATA = Join-Path $PWD 'build/resume-recovery-user'`) and fictional/mock API identities. Windows sandbox attempts failed on the user log directory and certificate store; the same isolated tests then ran with the required system access.

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/<file>`:

| Test file | Final actual outcome |
| --- | --- |
| `test_resume_recovery_budget.gd` | 248 checks, zero failures |
| `test_session_rotation.gd` | 17 checks, zero failures |
| `test_backend_exception_recovery.gd` | 28 checks, zero failures |
| `test_mission_outbox.gd` | 11 checks, zero failures |
| `test_refreshed_ticket_priority.gd` | 26 checks, zero failures |
| `test_local_draft_publication.gd` | 31 checks, zero failures; actual 2605-tick creator lap/436 trajectory samples |

The first native reproduction failed all four integer-type assertions and exported the rejected actual wire. Intermediate regression failures were corrected: test dictionary equality after JSON float reload, scan-order expectations, stale mock HTTP receipts, and tests resetting the previous wall-clock scheduler only. Assertions about operation identity, charges, account isolation and pacing were retained.

`.tools/backend-venv/Scripts/python.exe scripts/test_recovery_postgres.py`: 76 passed, two expected SQLite skips of PostgreSQL-only concurrency cases. Actual Godot-produced saved-journal payloads pass the strict HTTP backend on both SQLite and PostgreSQL, for daily/banked confirmation and abandonment, repeated idempotent recovery, and unchanged rejection of float/fraction/string evidence. The task-owned PostgreSQL 17 container was removed after its ownership label was checked. [Actual backend log](evidence/recovery-rate-limit-2026-10-12/backend-regression.log). The initial direct pytest command encountered 19 connection errors from the stale `.tools/backend-postgres.env` service at localhost:55439; the owned-database rerun resolves this environment failure without editing shared configuration or weakening tests.

Ruff on the changed Python tests/helper and `git diff --check` on the touched tracked files pass.

Broader checks outside the acceptance claim: `test_track_lifecycle.gd` requires its live local integration backend; none was available, so discovery/sign-in/slot setup failed. `test_product_telemetry.gd` returned 54/55 checks with its stale-event expiry expectation failing. Its runtime and test source were not changed by this task; its retry/normalization review is not a claim that the entire telemetry suite passes. No full Validate, physics regression, Android export, installation, backend deployment or live recovery writes were performed.

## Remaining acceptance and delivery

Final Doctor with the real installed tool configuration succeeded and reported an attached DN2103 Android phone. No physical-device race or updated Android build was tested. No visual layout changed, so new UI captures are not applicable.

Restart all running game instances to load these source fixes; older processes can continue posting the original invalid requests. On the updated client, valid old journals settle through the existing authoritative endpoint at the bounded pace. No manual journal deletion, replacement consumption, refund invention, backend schema change or deployment is needed for this fix. An installed APK/executable still needs a separately built updated client before it contains these changes.

The workspace contains extensive pre-existing changes. The review checkpoint for this slice is the task-only patch in this evidence directory; unrelated work is preserved.
