# Skip non-improving race verification — 2026-10-26

The owner requests no race verification when a result improves neither personal bests nor Daily/Weekly Rivalry/Challenge standings. The owner explicitly confirms that normal completion rewards remain. Task requirements: **NIS01** authoritative benefit comparison; **NIS02** no verifier/geometry work for skipped results; **NIS03** rewards and immutable retries; **NIS04** client completion/restart compatibility; **NIS05** preserve explicit competitive reuse; **NIS06/R01/Q01** focused tests, retained regressions and a task-only review patch.

## Behaviour

The updated client sends an optional, negotiated five-lap timing summary. The server uses this unverified hint only to discard a score. It can never authorize a new record. Inside the player's locked submission transaction, the server compares:

- Total time against the verified race PB for the exact board, car and rules.
- The fastest flying lap, excluding the standing-start lap, against the verified lap PB.
- The independently earned Weekly Rivalry track best, when this ticket belongs to a week.
- The independently earned Challenge best, or that specific track's best in a multi-track Challenge.

Daily Free Race and Track of the Day use ordinary pinned boards; there is no separate daily best table in the current implementation. A missing PB, missing competition finish, uncertain/malformed evidence, creator validation or any potentially faster result stays on the existing verification path. Ties can skip. A faster competition time still verifies even when the player's global PB is faster, and even when the improvement would not immediately change rank.

A qualifying result completes directly at submission with `status: skipped`, `skip_reason: no_improvement`, zero verification attempts and zero polling delay. It makes no queue reservation, prepares no geometry, checks no trajectory and saves no new ghost. It cannot update race/lap PBs, Rivalry/Challenge bests, their source runs, standings or verified-only SQL projections. A worker also rechecks queued candidates before loading geometry: a result overtaken while waiting can complete without verification.

Completion coins remain server-priced and idempotent. The ordinary 50-coin completion reward remains, as does the existing clean-race bonus under the existing self-reported incident policy. PB bonuses remain impossible for a skipped result. Skipped runs are excluded from verification-dependent achievement/news capture. Reward receipts, current wallets, batch/wait/recovery reads, resume-receipt settlement, account restrictions, artificial/public isolation and bounded history retention remain fenced. The server intentionally does not establish driving authenticity for these non-scoring completions; this is the owner's requested relaxation, not a stronger anti-cheat claim.

Choosing **this completed run** as a new Challenge target is a new competitive use. The client explicitly requests verification through the existing retry endpoint. A durable `verify:<run-id>` marker prevents the worker skipping that request again, including after temporary failure or restart. The original stored trajectory is checked before a target can be created. Its existing reward cannot be credited twice. A normal verified source remains read-only. Successful real-player reuse removes its marker in the result transaction; bounded history cleanup removes obsolete markers with their runs.

## Client and protocol

`non_improving_runs_version: 1` advertises the feature. `claimed_lap_ticks` is optional, must contain exactly five positive integer durations and must sum to the input count minus authorized discarded rewind ticks. Cheap endpoint checks precede any skip; absent or uncertain hints preserve verification. The full verifier continues to derive authoritative timing from the path whenever verification is required.

Lap hints and negotiated options survive the existing durable save queue and local recording journal. Old recordings/options preserve their existing wire bodies and hashes. The packed-path transport retains the summary outside the path payload. Unknown saved options and invalid protocol versions remain rejected. New recordings without a hint, including historical/background recordings not produced through the updated App save flow, conservatively retain verification.

`skipped` is an explicit terminal completion, with ordinary result feedback and no verification spinner. Rivalry/Challenge consumers, reward caching, wake-up hints, upload recovery and the result-based Challenge action understand it. Existing backend status storage already supports this value, so no schema migration or grant change is needed. A matching client/backend rollout is required; neither has been deployed by this task.

The wire schema is updated in `backend/schemas/trajectory-v1.schema.json`. The shared protocol fixture is `game/tests/fixtures/non_improving_run_v1.json`.

## Scope

`backend/bmt_backend/non_improving_runs.py` owns the small classifier and completion path. Existing admission/worker/retry, reward, competition and terminal-status modules integrate it. `game/core/app.gd` captures the five lap times; the backend client and cloud journal negotiate/store/send them. Existing Rivalry/Challenge consumers, finish-rating refresh and the Challenge result view complete skipped results correctly.

No physics, input mapping, car handling, track geometry, ranking arithmetic, prices or purchase implementation changes belong to this task. Concurrent App/input-recording/save-performance work and the earlier trajectory-check improvements are preserved. The review patch isolates this task from pre-existing edits in shared files; test entry-point build-version updates are excluded.

## Actual validation

Full commands and logs are retained in `docs/evidence/non-improving-race-skip-2026-10-26/` and its `report.json`.

| Check | Actual outcome |
|---|---|
| Focused backend skip, competition, account, reward, rewind, retention and explicit-reuse tests | **26 passed / 25 PostgreSQL deselections** in `all-focused-final.log`, including ordinary and terminal-failure recovery for explicit competitive reuse. Earlier focused versions passed 15, 19, 23 and 25 cases as coverage expanded. |
| Real Godot client against disposable authenticated loopback backend | **1 passed / 17 native checks**. Ordinary upload made **zero** race-verifier calls; outbox completion, reward and exact persisted-body retry worked. Explicitly choosing that result as a new Challenge target invoked the verifier **once**, with no second reward. `native-reuse-http.log`. |
| Focused native protocol/restart/completion tests | Headless passed; final Compatibility and desktop Mobile each **26 checks / 0 failures**. No physical-device inference is made. |
| App and dependency parser | Passed with pinned Godot `4.7.2.stable.official.ed1daf0bf`; `parser.log`. |
| Broader backend race/competition/reward/completion/geometry suite | **165 passed, 3 skipped, 114 deselected, 2 failures**. Both failures reproduce with exact task-start modules loaded only in memory. |
| Queue/archive/maintenance slice with expanded skip tests | **37 passed, 7 skipped, 35 deselected, 1 failure**. The failure also reproduces with exact task-start modules. |
| PostgreSQL | Local configured service at port 55439 timed out. No PostgreSQL concurrency pass is claimed. |
| Ruff and task patch checks | Recorded in the final report. The pre-existing import-order finding in `app.py` is outside the changed capability line. |

The unchanged failures are the recorded-practice native setup returning validator-unavailable inside the sandbox, the guarded downgrade past pending creator-achievement events in migration 0054, and the intentionally refused telemetry rollback in migration 0051. Original and final failures are retained in `original-regressions.log`, `original-queue.log`, `backend-regression.log` and `related-final.log`. No invariant or migration guard was relaxed.

An initial native assertion compared JSON-decoded floating-point lap arrays directly with integer arrays; the corrected assertion exercises the actual wire normalization after restart. An initial HTTP retry reconstructed the body from the pre-journal fixture and correctly received 409 because it differed from the persisted recording. The final test retries the exact committed recording and preserves the immutable-body assertion. These failures and corrected runs remain recorded.

Representative actual commands, from the repository root unless noted:

```text
# backend working directory
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_runs.py -q -k 'not postgres' --basetemp=../build/non-improving-all-final
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_http.py -q -s --basetemp=../build/non-improving-reuse-http
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_runs.py tests/test_domains.py tests/test_rivalry.py tests/test_challenges.py tests/test_challenge_series.py tests/test_earned_coins.py tests/test_outcome_reads.py tests/test_verification_preparation.py tests/test_trajectory_integrity.py tests/test_hairpin_gate_contract.py -q -k 'not postgres' -m 'not godot' --basetemp=../build/non-improving-race-regression
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_runs.py tests/test_queue_capacity_slots.py tests/test_cost_archives.py tests/test_maintenance.py -q -k 'not postgres' --basetemp=../build/non-improving-final-related
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_runs.py -q -k postgres -x --basetemp=../build/non-improving-race-postgres

# repository root; BMT_SKIP_NATIVE_ROOT points to isolated task storage
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_non_improving_runs.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_non_improving_runs.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_non_improving_runs.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://core/app.gd
```

Native tests used approved access to the Windows certificate store/native test logs. Runtime data stayed in task-specific workspace folders and disposable databases; no live backend was contacted. Screenshots: [Compatibility](evidence/non-improving-race-skip-2026-10-26/challenge-completed-compatibility.png), [desktop Mobile](evidence/non-improving-race-skip-2026-10-26/challenge-completed-mobile.png).

## Delivery

`checkpoint.patch` is a reviewable task-only patch; no Git commit or merge was made. Remaining acceptance: matching client/backend rollout, owner workflow acceptance and PostgreSQL concurrency/capacity testing when the local service is reachable. Old recordings without timing hints still verify. No device attachment check, physical-device test, APK build, real purchase/authentication, live mutation, deployment or owner-process restart was performed.
