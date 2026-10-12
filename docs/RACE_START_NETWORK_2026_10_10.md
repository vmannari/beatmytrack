# Complete race-start wait, 2026-10-10

Owner reports occasional waits close to ten seconds and asks whether the
backend is responsible, including new races. Requirements **RLOAD03**: fresh
race authorization must not wait for an earlier score upload;
**RLOAD04**: measure server/network/local stages separately;
**B01/B05/B07/R01/Q01**: preserve authorization, idempotency, durable uploads,
account fences, normal results first and five laps.

The previous repeat-loading timings excluded HTTP and app transitions. They
did not establish a ten-second end-to-end race-start time or its cause.

## Findings and change

The client serialized every authenticated POST behind `_busy`, including new
Free Race, Rivalry and challenge tickets. The durable outbox uses that same
queue for `/runs` uploads. Starting a race during an upload therefore waited
for the complete upload/response before even sending the ticket. The normal
HTTP timeout is 30 seconds. This is a reproduced cause of potentially long
starts, not proof that a particular owner's ten-second wait was an upload.

Healthy race-ticket requests now proceed independently of the mutation
queue. Only the three exact ticket route shapes receive this behavior.
Credential rotation still uses the existing serialized recovery/rotation
lock, stable operation keys and account-generation checks. Concurrent expired
tickets share one refresh. Compression fallback retains the same ticket key.
Other mutations, the score outbox and server eligibility checks retain their
existing behavior. No score upload is canceled or discarded.

Opt-in debug timing separates loading-screen stages from request queue wait,
encoding, whole HTTP, decoding and refresh queue wait. Enable
`BMT_RACE_LOAD_PROFILE=1` in the client process environment or pass
`--profile-race-load` directly to the game. Output is `RACE_LOAD_STAGE` and
`RACE_LOAD_REQUEST` in Godot logs. The request logger prints categories only,
never URLs, account/track/ticket IDs, headers, tokens or payloads. This adds
no player-facing diagnostic text. It is disabled in release behavior.

## Read-only live measurements

Read the development API's 600 recent structured HTTP entries, then bounded
24-hour ticket-related application and platform log samples. No auth session,
ticket, race, profile, score, upload or deployment was created by this probe.

| Server application route | Requests sampled | Median | Maximum |
|---|---:|---:|---:|
| Free Race ticket | 33 | 55.55 ms | 77.53 ms |
| Rivalry ticket | 19 | 73.48 ms | 125.01 ms |
| Challenge ticket | 1 | 57.85 ms | 57.85 ms |
| Rivalry ticket result read | 17 | 43.37 ms | 61.02 ms |
| Public document, recent sample | 165 | 94.77 ms | 393.46 ms |

The platform sample has 70 ticket-related requests, including creation and
result reads, with a **143.31 ms maximum**. This covers the observed server
platform handling, not the owner's connection or delay before sending HTTP.

Fresh public HTTP reads from this workstation measured health at
1,607.37 ms first / 350.71–395.10 ms thereafter; bootstrap 301.63–365.39 ms;
ready 256.88–572.95 ms. An earlier probe had a 1,405.59 ms first health read
and 408.72–625.10 ms bootstrap reads. TLS/connection/network overhead is
therefore material and variable even when server processing is quick.
The sampled backend requests do not exhibit a ten-second processing delay.
The owner's exact device, loading stage and connection were not established.

[Sanitized live receipt](evidence/race-start-network-2026-10-10/live-latency.json).

## Actual validation

Pinned Godot 4.7.2 stable ed1daf0bf, through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestScript -ScriptPath res://tests/probe_race_ticket_queue_before.gd`:
  saved original dispatcher, valid held-upload fixture, **15 checks / three
  expected priority failures**. Each ticket remains blocked until upload
  release; all other assertions pass. Temporary entrypoint removed after
  recording [baseline](evidence/race-start-network-2026-10-10/queue-before.log).
- `TestScript -ScriptPath res://tests/test_race_ticket_priority.gd`:
  final **26 checks / zero failures**. All three tickets complete before
  upload release; both requests survive with their distinct original keys.
  Single/concurrent refresh, compression fallback and account change pass.
  Recorded checks occur after twelve engine frames (62.43–69.18 ms);
  those are observation windows, not real network latency.
  [Final priority log](evidence/race-start-network-2026-10-10/queue-after.log).
- `TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd`:
  **28 checks / zero failures**, including durable upload/refresh recovery.
- `TestScript -ScriptPath res://tests/test_free_race_restart.gd`:
  **17 checks / zero failures**; **31 ObjectDB references at shutdown** remain.
- `TestScript -ScriptPath res://tests/test_race_loading.gd -Graphical`, with
  `BMT_RACE_LOAD_PROFILE=1`: **81 checks / zero failures**; actual frozen
  presentation and full countdown retained. Isolated normal loading first
  total 1,535.62 ms; practice 586.65 ms. These exclude live HTTP and do not
  measure a new community track. [Stage trace](evidence/race-start-network-2026-10-10/stage-trace.log).
- `TestApp`: **99 checks / zero failures**.
- `TestScript -ScriptPath res://tests/test_script_parse.gd`:
  **443 scripts / zero failures**.

Live command:
`.tools/backend-venv/Scripts/python.exe build/race-start-network/inspect_live.py`.
The first log-reading attempt needed explicit JSON output/parsing; corrected
read-only runs succeeded. Initial priority fixtures omitted `manifest.laps`
and returned an incomplete upload response; those fixture errors were fixed,
then the original dispatcher was rerun to isolate its three real failures.
No product assertion was weakened.

Runtime files: `game/backend/backend_client.gd`, `game/ui/race_loading.gd`.
New test: `game/tests/test_race_ticket_priority.gd` and UID. This report, both
status documents and sanitized evidence accompany the task-only Git review
checkpoint `refs/codex/race-start-network-20261010`. Existing app and physics
code are not changed by this follow-up.

No phone attachment check or physical-device test, Android export/install,
full Validate, backend change, live player-score write or deployment. The
client needs a restart/rebuild to use the fix. New/evicted geometry and the
three-second countdown still take time. The exact reported ten-second case
remains an acceptance check using opt-in stage/request logs on the owner's
actual client; no universal startup-time or ten-second-fix claim is made.
