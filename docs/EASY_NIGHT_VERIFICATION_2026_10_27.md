# Easy night verification — 27 October 2026

**ENV01** check the reported Easy night race; **ENV02** exercise the existing
rounding fix with its rewind case; **ENV03/Q01** distinguish live service failure
from a rejected path and confirm the final result.

The race is now **verified by the live backend**. The successful verification
event is dated **20:59:38 Helsinki time**, and the client's saved upload is marked
done with no failure. The normal client retired the saved replay after success.
This investigation did not submit, retry, rewrite or retire the owner's race.

The original recording had 5,307 recorded inputs and a 579-tick rewind, leaving
4,728 elapsed ticks. Its independently rounded lap summary totalled 4,727. That
is the same local encoder issue fixed in
[the preceding task](RACE_RESULT_TICK_ROUNDING_2026_10_27.md). No additional
runtime change was necessary. A native probe ran the actual patched
`CloudTracks._submit_saved` with an in-memory transport stub and disabled journal
writes: only the invalid optional hint was omitted, while original path samples,
rewind receipt/timeline and ghost were retained. No real authentication or
submission occurred in the probe.

The resulting original path passes all five ordered laps offline in **0.4902
ms**, with lap ticks **[1054, 966, 902, 905, 901]**. An isolated native regression
for these exact counts and rewind offsets passes **15 checks / 0 failures**,
including startup recovery, strict original rejection, evidence/key preservation,
incident duration and corrected cumulative boundaries.

The normal client's live upload then encountered a separate infrastructure
failure. At **20:55:20**, the worker logged an `OSError` at
`bmt_backend.gcs_storage:_request:96`; the failed attempt took **54.5568 seconds**
and returned `verifier_unavailable`. This is the transport exception path for
object-storage requests. The sanitized log does not identify the specific object
or the underlying DNS/TLS/socket cause. It does not establish a provider outage
or an invalid race. Existing retry behavior retained the run. At **20:59:38**,
the same run logged `verification_complete` with **4,728 ticks**, **1.830202 ms**
of verification compute and **0.3742 seconds** for the successful attempt. The
additional time between attempts is not assigned to an unmeasured cause.

Actual commands use `.tools/backend-secure-venv/Scripts/python.exe` with
`build/easy-night-verification-2026-10-27/check_readonly.py`, the pinned Godot
4.7.2 binary with `--headless --path game --script
res://tests/test_easy_night_verification.gd`, isolated test data and absolute log
paths, and bounded `gcloud.cmd logging read` filters for the submitted run.
Existing corporate TLS trust was used without disabling certificate validation.
Only credential-free timing/status evidence is retained in the report.

Probe-only findings are retained: Windows rejects `NUL` as a Godot log target;
the corrected probe logs only a safe status and deletes its temporary packet
immediately. Comparing the optional ghost inside Godot avoids conflating its
unchanged dictionary with JSON numeric serialization. An initial assertion that
all job metadata must remain unchanged raced the owner's real upload progress;
the final check preserves immutable ticket/key/evidence identity while allowing
normal status updates. The owner then independently completed the upload.

New task files are the focused test, this note and its evidence/checkpoint.
Concurrent runtime work and the preceding rounding implementation remain
untouched. No device attachment query/test, APK, cloud mutation/deployment,
owner-save mutation, real authentication, purchase, owner-process restart or
main-index staging/commit/merge was performed. Physical-device and future
end-to-end latency acceptance remain; this one race's live acceptance is proven.

See [the evidence report](evidence/easy-night-verification-2026-10-27/report.json).
