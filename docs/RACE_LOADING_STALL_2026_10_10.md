# Intermittent race loading stalls, 2026-10-10

Requirements: RLOAD05 (bounded loading/recovery), RLOAD06 (expired ticket
priority), B01/B05/B07, R01/Q01. Owner initially reported Over and Under stuck
for minutes, then Blind Spot displaying Connecting race. This stage waits for
race authorization, before construction of the driving scene.

## Evidence and changes

The owner's exact stalled coroutine could not be captured: simultaneous
desktop tests overwrite the shared default Godot log. The inspected live
game initially displayed an active race; a later read-only connection sample
showed pending TCP connections. These observations do not establish the exact
cause of either reported stall.

Two failure mechanisms were reproduced in isolation:

- Suspended rendering leaves the original frame_post_draw await unfinished.
  Baseline bridge/loading suite: eight checks, one expected failure. Normal
  Over and Under setup/revisits completed in approximately 1.06/0.51/0.50s,
  excluding live HTTP. The presentation wait now polls for an actual draw,
  bounded to two seconds when rendering is suspended.
- An expired race ticket waits on the global mutation flag while a durable
  score upload is held. Baseline: 15 checks, three expected failures, one for
  each Free Race/Rivalry/challenge ticket route. Race-ticket credential renewal
  now bypasses that mutation queue and uses a separate serialized renewal
  path. Concurrent expired tickets share one refresh; upload ownership,
  account fences, persisted rotation locks and exact idempotency keys remain.
  The renewal queue itself returns an undelivered busy failure after 35s.

Every loading overlay now owns a 45-second timer. If asynchronous preparation
stops progressing, it closes the overlay, clears the unstarted ticket, removes
a disabled partial race scene and returns to the menu with one actionable
message. Continuations check the owning loading instance before changing
state, so late replies cannot close a newer retry or start a hidden race.
The timer requires the main thread to keep processing; it cannot interrupt a
synchronous engine/geometry/render-driver freeze. Normal draw/countdown,
five laps and canonical racing/score contracts remain unchanged.

Concurrent rating work introduced a reserved Node.owner field and an unchecked
optional rating response during verification. Small adapter corrections rename
the account field and ignore incomplete optional responses. The rest of that
work is preserved; it is not attributed to this loading slice.

Read-only backend health/ready/bootstrap reads returned HTTP200 in
659.79/904.55/388.54ms; a public bootstrap request through the actual Godot
adapter completed HTTP200 in477ms. No authentication, ticket, score, rating or
deployment writes were issued by these probes. The limited recent log sample
contained no selected ticket/refresh rows; no conclusion about the owner's
exact server request is drawn from that absence.

## Actual verification

Pinned Godot 4.7.2 stable ed1daf0bf, through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_expired_ticket_priority.gd` | Final19 checks, zero failures; baseline15/three failures |
| `-Action TestScript -ScriptPath res://tests/test_race_ticket_priority.gd` | 26 checks, zero failures |
| `-Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd` | 28 checks, zero failures |
| `-Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical` | Final18 checks, zero failures; drawing suspension, held reply, actual timer, late reply/retry/navigation, partial scene cleanup and actual bridge starts |
| `-Action TestScript -ScriptPath res://tests/test_race_loading.gd -Graphical` | 83 checks, zero failures; rendered/frozen loading and full countdown |
| `-Action TestApp` | Final99 checks, zero failures |
| `-Action TestScript -ScriptPath res://tests/test_free_race_restart.gd` | Final17 checks, zero failures; 47 ObjectDB shutdown references remain |
| `-Action CheckScript -ScriptPath res://core/app.gd` | Successful application/dependency compilation |

The public probe used a temporary TestScript entrypoint, then removed it.
Backend evidence command:
`.tools/backend-venv/Scripts/python.exe build/race-loading-stuck/inspect_live.py`.
Logs, sanitized read-only receipt and an inspected1280x720 timeout recovery
screenshot are under `docs/evidence/race-loading-stuck-2026-10-10/`.

Initial restricted Godot logging was denied; normal local access allowed runs.
An initial fixture checked countdown after the first revealed physics frame;
it now observes the actual overlay-removal boundary. A minimal held-ticket
fixture lacked the cloud UI interface; the corrected fixture inherits the
real cloud adapter. Both mistakes are recorded, not counted as product passes.
An initial parser/recovery run encountered the concurrent rating errors above.
The broad all-script parser later stopped on an old test referencing the
concurrently removed track_rating_prompt.gd; it is not reported passing.
No assertions were weakened or product contracts relaxed.

Runtime files: `game/core/app.gd`, `game/backend/backend_client.gd`, small
corrections in `game/backend/finish_rating.gd`. New tests:
`game/tests/test_over_under_loading.gd`,
`game/tests/test_expired_ticket_priority.gd`, and their UID files. This report,
DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md record actual results.

Task-only Git review checkpoint: `refs/codex/race-loading-stall-20261010`.
The parent preserves concurrent work with only this task's edits reversed;
the review diff isolates these changes. The working branch/index are retained.

No phone attachment check or physical-device test, APK export/install, full
Validate, backend modification/deployment or real-player writes. Existing
running clients keep their loaded code; restart the desktop game or rebuild
Android to use the fix. Actual signed-in Blind Spot/Over and Under starts,
network interruptions and expired-session revisits remain owner/device
acceptance. The user's exact minutes-long incident remains unattributed.
