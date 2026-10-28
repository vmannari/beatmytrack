# Race result tick rounding — 27 October 2026

The reported Compact / Blind spot Weekly Rivalry recording is intact and passes
the normal trajectory verifier offline, including all five ordered laps. Its
upload was blocked locally before a Run entered the verification queue.

**RTR01** diagnose the reported delay and failure; **RTR02** correct newly
captured summaries; **RTR03** recover existing recordings without changing their
evidence, ticket or idempotency identity; **Q01** retain strict validation and
check the original recording offline.

## Cause and correction

The recording contains 11,373 input ticks. Independently rounding the five
interpolated lap durations produced hints totalling 11,371 ticks. The strict
client encoder therefore returned an empty packet and saved
`REPLAY_RECOVERY_REQUIRED` / 422 without making a submission request. Rivalry
continued polling the unsubmitted ticket while showing its pending state. The
exact final live result response was not read; no server-side replay rejection
is inferred from that label.

New hints take differences between the ceilings of cumulative lap crossing
times, matching the integer boundary samples recorded by RaceProof. An
inconsistent or incomplete local timing summary is omitted. Displayed fractional
lap times and canonical simulation remain unchanged.

Old five-integer summaries with only the possible independent-rounding gap
(-2 to +3 ticks relative to elapsed duration, excluding zero) are submitted
without this optional negative-only hint. This restores the existing full path
verification route; it never supplies invented lap times or a score. The strict
wire encoder still rejects inconsistent summaries when explicitly supplied.

Startup discovery also restores jobs stranded with this particular local encoder
failure. It requires matching replay bytes, the original filename/ticket, the
local recording schema and explicit negotiated options. Corrupt or malformed
recordings, larger discrepancies, dismissed jobs and existing server submissions
or rejections are preserved. Recording bytes, keys, rewind events and retry
packet identity are retained. Server ticket expiry and acceptance rules remain.

Runtime scope is `game/backend/backend_client.gd`, `game/backend/cloud_tracks.gd`
and one assignment in `game/core/app.gd`. Concurrent race compatibility and race
render preparation changes remain in place and are excluded from the task
checkpoint.

## Actual verification

- Task-start regression: **47 checks / 3 failures**, reproducing upload failure,
  absent automatic recovery and the missing cumulative-summary helper.
- Final isolated native regression: **93 checks / 0 failures**, including exact
  disk reload, original keys/hashes, lost reply and conflict recovery, rewind net
  duration, 32 fractional-boundary cases and nine corruption/lifecycle controls.
- Retained pending input recovery: **44 checks / 0 assertion failures**;
  non-improving protocol: **25 / 0**; actual App composition: **141 / 0**.
- Final clean pinned script parser: **1,335 scripts / 0 failures**. Concurrent
  additions explain the earlier 1,333-script count.
- Separate verification preparation tests: **27 passed**; trajectory integrity:
  **31 passed**. The combined backend run has **53 passed / 25 setup errors**:
  the existing disposable PostgreSQL listener is unavailable. A normal-access
  socket check also receives connection refused. No backend assertion fails;
  PostgreSQL coverage remains outstanding and is not counted as passing.
- Read-only original recording check: its original summary fails the envelope;
  omitting that summary accepts the original path in **1.741 ms**, at **11,373
  ticks**, with verified lap ticks `[2332, 2146, 2514, 2196, 2185]`.
- Ten nearby cloud verification completions take **0.2931–3.0185 seconds**, with
  **0–1 seconds** of queue wait. No verification failure event was returned by
  the bounded worker failure query. These are observations of nearby races,
  not an end-to-end latency guarantee.

The first local cloud CLI call failed because PowerShell execution policy chose
the `.ps1` entrypoint; subsequent calls use `gcloud.cmd`. Initial normal-sandbox
cloud calls could not write the SDK's authentication database, and the first
normal-access call lacked the configured corporate trust bundle. Read-only
queries succeeded with the project's existing trusted certificate bundle.
No certificate validation was disabled. An initial pytest call lacked
`PYTHONPATH`; it was rerun with the repository backend path.

Early native invocations report the sandbox's root certificate store error even
when all assertions pass. The final focused regression, parser and original
recording check complete with clean process exits using normal OS access and
isolated test data. An initial expected-path fixture compared JSON integer
metadata before disk normalization, and shared upload pacing postponed a second
fixture; the test now compares the actual disk representation and isolates that
restart. Original failed logs are retained.

## Commands and acceptance

Use the pinned `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`, offline
`BMT_API_URL`, isolated test data and absolute `--log-file` paths. Actual test
scripts are `res://tests/test_result_tick_rounding.gd`,
`res://tests/test_pending_input_recovery.gd`,
`res://tests/test_non_improving_runs.gd`, `res://tests/test_app.gd` and
`res://tests/test_script_parse.gd`, each with `--headless --path game --script`.
The final focused run produces `build/result-tick-rounding-2026-10-27/final.log`.

Backend commands use `.tools/backend-secure-venv/Scripts/python.exe -m pytest`
with `PYTHONPATH` set to the absolute `backend` directory. Tests use explicitly
isolated `--basetemp` directories under `build/result-tick-rounding-2026-10-27`.
The read-only original recording check is
`build/result-tick-rounding-2026-10-27/verify_owner_readonly.py`; it reads the
original bytes, compiles the existing public Blind spot source and checks the
path without authenticating or submitting anything. No private recording or
recording fingerprint is included in the evidence artifacts.

Reload the client to apply the fix and let its normal outbox retry eligible saved
uploads. This task does not prove that the live race has subsequently been
accepted. Owner/device end-to-end latency and acceptance remain. No physical
device attachment query/test, APK, cloud deployment or mutation, owner-save
mutation, authentication, purchase, owner-process restart, main-index staging,
commit or merge was performed.

Sources, outcomes and the task-only review checkpoint are in
[the evidence report](evidence/race-result-tick-rounding-2026-10-27/report.json).
