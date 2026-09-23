# Personal track ratings — 2026-09-23

Requirements: owner request; R01 (local persistence), V03/V05 (responsive menu UI), Q01 (regression evidence). Personal local ratings are authorized by this request; online aggregate ratings remain deferred.

Owner correction: offer the rating directly on the on-track Race Complete screen, not as a Results popup. After 0.75 seconds, a black-and-gold rating section fades in beneath the existing sign over 0.25 seconds. Unrated finishes wait for a star, Skip, or tap-to-continue; already-rated finishes retain their existing automatic transition. A star saves immediately and continues to Results. Skip writes nothing and allows another prompt after a later race. Already-rated track identities are suppressed across cars, physics versions and application restarts. Retry/navigation guards prevent a delayed prompt appearing during another race. Editor practice does not prompt.

Race Complete includes an editable personal rating row beneath the two Where You Stand cards. Unrated tracks show empty stars. Existing original star icons are reused. No new external assets or services.

Persistence: optional `settings.track_ratings` dictionary in LocalRecords schema 2, keyed by NativeTrack.identity, values integral 1–5. Existing saves need no migration. Uses the existing verified temporary write, backup and committed-state rollback. Failure keeps the on-track rating available with visible retry copy. Tracks with the same identity retain their rating after edits; renamed copies with new identities are separate.

Changed files: game/core/app.gd, game/ui/race_complete.gd, game/ui/track_rating.gd and .uid, game/ui/race_cues.gd, game/core/game.gd, game/persistence/local_records.gd, game/tests/test_race_results.gd; this document and status entries. Existing unrelated working-tree changes retained.

Actual validation through pinned Godot 4.7.2 via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ...`:
- Initial TestResults was interrupted and initial CaptureResults failed because the new global class had not been imported.
- Import passed and registered TrackRating.
- CaptureResults: 179 checks, zero failures, captures at 1280×720, 1920×1080 and 2400×1080.
- TestResults: 164 checks, zero failures.
- TestRecords: 53 checks, zero failures.
- `git diff --check -- game/core/app.gd game/persistence/local_records.gd game/tests/test_race_results.gd`: passed, line-ending notices only.

Checks exercise delayed appearance, skip without a saved rating, repeat offering after skip, dismissal on selection, reload, identity isolation, suppression and persisted inline editing, plus existing results/reward/navigation regressions.

Evidence: [prompt](evidence/race-results/track-rating-prompt.png), [editable rating](evidence/race-results/race-complete-1280x720.png). Both inspected on desktop. No Android export or physical-device test performed. Remaining acceptance: owner review of timing and touch interaction on phone. Ratings are personal to this installation; no aggregate or account sync.

## On-track placement correction

The Results timer and popup builder were removed. Game presentation now passes the existing local records adapter to the finish cue, independently of canonical simulation. Existing stars remain editable on Race Complete. Rating controls use original code-native black/gold styling and the existing star glyphs; no generated or third-party assets were added. Waiting coasts the presentation vehicle only; race time and telemetry remain frozen at the line.

Actual follow-up commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureResults` passes 184 checks; `-Action TestPractice` passes 49 checks (existing two ObjectDB instances leaked at shutdown). CaptureResults covers the actual on-track delay and hold, skipping, saving/reload, automatic transition for rated tracks, no Results popup, and editable standings. [Corrected finish capture](evidence/race-results/track-rating-on-finish.png) inspected. Earlier popup screenshot above is superseded. No physical-device test or Android export performed. Remaining acceptance: owner review of finish styling/timing and touch interaction on phone.

## Play gallery rating badges

Owner request adds rating and vote count to every playable track card (R01/V03/V05/Q01). TrackTile draws a compact star/score/count badge on the lower-right scenic area, replacing the LOCAL caption. TrackBrowser supplies each track's saved rating by identity. Unrated is `— (0)`; rated is e.g. `4.0 (1)`. Changing a rating replaces that single local vote. These are actual installation-local votes, not invented community totals; tooltips identify their local scope. No shared-rating service exists in this slice. Draft and preview cards do not display the badge.

Changed files: game/ui/track_tile.gd, game/ui/track_browser.gd, game/tests/capture_premium_menus.gd, status documents and this report. Existing star assets reused.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureMenus` — 490 checks, zero failures, at 1280×720, 960×540 and 1600×720. Fixtures include rated and unrated cards with identity/value/count assertions. `git diff --check -- game/ui/track_tile.gd game/ui/track_browser.gd game/tests/capture_premium_menus.gd` passed with line-ending notices only.

Desktop and compact captures inspected: [gallery](evidence/track-ratings/gallery-1280x720.png), [compact gallery](evidence/track-ratings/gallery-960x540.png). Ratings in these isolated test captures are explicitly seeded fixtures; owner records were not changed. No phone test or export performed. Owner visual acceptance and physical-device readability remain outstanding; aggregate ratings require a future shared vote source.

## Centered stars and saved-rating confirmation

Owner follow-up (R01/V03/V05/Q01): star buttons now explicitly center their icons horizontally and vertically, including the standings editor. On a successful finish-screen save, the selected stars fill immediately and the heading confirms the value (e.g. YOU RATED THIS TRACK 4 / 5). Keep this visible for 0.7 seconds, then fade the finish cues over 0.4 seconds before entering Results. Repeated selections and tap-to-continue are blocked during confirmation. Skip retains its direct continuation; failed saves remain available for retry. Reset cancels confirmation and clears the old panel reference.

Changed: game/ui/track_rating.gd, game/ui/race_cues.gd, game/core/game.gd, game/tests/test_race_results.gd and these status/evidence documents. No simulation contract changed.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureResults` — final run passes 198 checks, zero failures. Tests cover centered icon alignment, exact filled-star count, saved value, input lock and delayed continuation. Intermediate capture exposed an invalid HUD cast in the new fixture and a stale queued panel reference; both corrected before the final passing run. `git diff --check` on changed tracked code passed with line-ending notices only. [Confirmation screenshot](evidence/race-results/track-rating-confirmed.png) inspected on desktop. No physical-device test or export; owner acceptance of timing and touch presentation remains.
