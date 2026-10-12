# Race-view rating with immediate continuation ? 2026-10-10

## Current requirements

- **RATE05 / RATE01:** Keep **Rate the track** beneath the **Race complete** gantry in the original race view, for both ordinary local and cloud races. Remove the relocated results popup. Existing star/Skip layout and touch targets remain.
- **RATE06 / R01:** A star tap immediately continues to the normal PB/lap summary. No saving spinner, success confirmation, confirmation hold, failure message or network wait is required. Skip also continues immediately. Normal results still precede Rivalry/challenge feedback.
- **RATE07 / B04 / Q01:** A failed save leaves the track unrated; the next completed attempt offers it again. Keep authoritative server qualification, no self-rating, immutable-version votes, account/server fences and idempotent writes. Keep actual five laps and the separate durable/idempotent race upload path.

This request supersedes the results-popup placement and confirmation behavior in `TRACK_RATING_PROMPT_2026_10_10.md`. No backend API, schema, physics, score eligibility or deployment contract changes.

## Implementation

The existing `RaceCues` panel is reused under the finish gantry. Its rating handler continues immediately on selection, instead of waiting for the vote response and a 0.7-second confirmation plus 0.4-second fade. Local save failures restore the previous in-memory rating dictionary and continue without feedback.

For an authenticated cloud attempt, `App` creates a small `FinishRating` service and starts reading the server's existing score while the race is being prepared. The actual start and retry paths both use it. A known zero score on a nonowned version offers the panel at the ordinary 0.75-second finish point; a read arriving during the existing coast can offer it there too. Unknown/unavailable reads do not prolong the coast or invent an unrated state.

A selected cloud rating remains only in memory under the online service, independently of the race/menu nodes. The normal result is displayed and the existing durable recording upload is queued immediately. If server eligibility already exists, a single idempotent vote is attempted in the background. On a first completion, the service waits for the existing verification signal and reads actual server eligibility before attempting the vote. Failed requests are abandoned without vote retries, notifications, optimistic stars or a durable rating outbox. A waiting selection expires after 120 seconds; app exit or account change also discards it. The next attempt reads the actual server vote again. An accepted server vote whose acknowledgement was lost is still found by that next read and suppresses another prompt.

Public creator IDs are copied into compiled cloud presentation metadata after prepared-track restoration, so self-owned tracks do not receive the finish prompt. The backend retains final authority over self-rating, artificial/public qualification and verified completion. Selecting a star never changes score acceptance or creates a fake rating success.

## Changed files

- `game/backend/finish_rating.gd`: per-attempt prefetch and ephemeral best-effort background vote, scope/lifecycle guards and bounded waiting.
- `game/backend/cloud_tracks.gd`: retain `cloud_creator_id` presentation metadata.
- `game/core/app.gd`: prepare the vote service on actual start/retry; remove results-popup creation.
- `game/core/game.gd`: offer the existing finish panel from prefetched cloud state, handle late reads during the coast, and release unselected services on continuation/exit.
- `game/ui/race_cues.gd`: reuse the original panel; remove confirmation and save-error feedback; continue on selection.
- `game/ui/track_rating.gd`: finish selection adapter, no save-feedback captions and rollback of failed local saves.
- Remove `game/ui/track_rating_prompt.gd` and its UID; the unwanted results overlay is retired.
- `game/tests/test_track_rating_prompt.gd`: rewritten around the actual App/Game start, finish and retry flow with fictional HTTP adapters and isolated records.
- `game/tests/test_race_results.gd`: update confirmation expectations to immediate results, and reset the per-attempt results guard when its fixture manually starts another attempt, as an actual retry does.
- This document, the superseded rating document, status/phase log and scoped evidence/checkpoint.

An unrelated concurrent discovery-warming guard in `App` was preserved and excluded from this task's patch. Prior unrelated workspace changes remain.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_rating_prompt.gd -Graphical -TestArgument '--capture-rating=C:/Codes/Godot/Beat my track/docs/evidence/instant-finish-rating-2026-10-10/after' -CommandTimeoutSeconds 90
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_restart.gd
$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/instant-finish-rating-2026-10-10/results'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureResults -CommandTimeoutSeconds 60
git diff --check -- game/core/app.gd game/core/game.gd game/backend/cloud_tracks.gd game/ui/track_rating.gd game/ui/race_cues.gd game/tests/test_race_results.gd
git apply --check --reverse docs/evidence/instant-finish-rating-2026-10-10/scoped-change.patch
```

Final native focused run: **32 checks, zero failures**, including three actual canonical five-lap finishes, original race-view placement before results, compact landscape containment, real pointer star/Skip clicks, same-call normal results and upload enqueue, first-completion verification, deliberately held PUT, failure without retry, actual retry reoffer, successful server score suppression, late prefetch, local save rollback, self-rating suppression and account-change cleanup. The real backend is replaced by fictional adapters; no live player races or votes are submitted. App checks: **99 / zero failures**. Offline/online restart checks: **17 / zero failures**. Scoped whitespace and reverse-patch checks pass.

The broader `CaptureResults` does **not** pass: its prior local recommendation-count failure remains, followed by a third-card out-of-bounds at `test_race_results.gd:329`. The updated local finish/selection/layout assertions produced no failures before that point. The earlier seven confirmation/lap-input/route-input failures disappear after the fixture uses a fresh per-attempt results guard. No recommendation assertion was removed or weakened, and no full results-suite pass is claimed.

Initial corrections are retained in the logs: the new service first used `owner`, a reserved Node member, and was renamed to `account_id`; the actual-results fixture initially omitted its required challenge adapter; retry initially tried assigning a freed service to a typed Node local and now checks a Variant reference before use. The initial parse command failed at the reserved member; subsequent actual runtime and app checks compiled/exercised the corrected code. No standalone successful CheckScript run is claimed for that initial command.

## Evidence and remaining acceptance

Inspected [1280?720 race view](evidence/instant-finish-rating-2026-10-10/after/race-finish-rating-1280x720.png), [960?540 race view](evidence/instant-finish-rating-2026-10-10/after/race-finish-rating-960x540.png), and [immediate normal results while the vote is pending](evidence/instant-finish-rating-2026-10-10/after/immediate-normal-results.png). Actual [logs](evidence/instant-finish-rating-2026-10-10/logs), [result receipt](evidence/instant-finish-rating-2026-10-10/results.json) and [task-only Git checkpoint](evidence/instant-finish-rating-2026-10-10/scoped-change.patch) are retained.

No phone attachment check or device test was performed. No Android export/install, full Validate, backend change, deployment, live Ajorata race or rating write was performed. Restart/rebuild the client to load this change. Remaining acceptance: actual signed-in Ajorata on the installed client, slow/offline verification on the owner's connection, and Android placement/touch behavior. If the initial server score cannot be read before the normal finish coast ends, no prompt blocks results; the next attempt reads again. Ratings intentionally have no persistent retry, while race uploads retain their existing durable recovery.
