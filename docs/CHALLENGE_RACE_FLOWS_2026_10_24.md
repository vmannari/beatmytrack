# Challenge track starts and retries — 2026-10-24

The reported 3×3 sequence is reproduced with the actual App and Game: finish the
first track, Continue to challenge feedback, select another track and Race. The
task-start client fails four of five focused checks, including the exact blank
`Could not start verified retry:` warning. [Original result](evidence/challenge-race-flows-2026-10-24/baseline.log).

## Requirements and causes

| ID | Requirement and change |
| --- | --- |
| CRF01 | Start the selected challenge track. The old `_start_challenge_race` shortcut retried any retained challenge Game. Feedback changed `selected_stage`, so the old Game received the new track's ticket and failed the content-hash check. Feedback now releases the finished Game, and track starts always prepare the selected track. |
| CRF02 | Keep retries attached to their original invitation, account and stage. Store the accepted attempt identity on its Game; use its stage for both ticket and ghost requests. Reject another invitation/account and discard delayed stale responses. Hold the start lock across join, ticket and ghost work. |
| CRF03 | Remove the extra Continue challenge button. Existing challenge, practice and source-setting summaries retain Race again and standard Continue. Ordinary verified free races retain Create challenge. Source-setting Continue preserves the original finished ticket, time, duration and custom settings. |
| CRF04 | Investigate entry, retry, return, failure and completion flows. The matrix below records actual coverage and practical limits. |
| R01/Q01 | Preserve five laps, canonical contracts, server-authoritative tries, best-only verified scores and local result ownership. No physics, scoring, migration or production backend change. |

The warning was blank because retry displayed `challenges.error` even when
`cloud.ticket` rejected the mismatched track and set `cloud.last_error`. Retry now
shows the error from the failing operation and always has actionable fallback text.

The real HTTP sequence also exposed a deferred standings-header callback using
freed controls after rapid verification refreshes. A bound instance method with
weak control references now ignores a retired view. The strict native HTTP check
retains its no-script-errors assertion. Failed joining also rebuilds the current
actions after releasing the start lock, so Join & race remains usable.

## Flow review

| Player action / state | Result and coverage |
| --- | --- |
| First start or Join & race | Selected track goes through normal preparation and its challenge ticket. The start lock begins before joining. |
| Race again from normal results or pause | Same Game and original stage; a fresh accepted ticket consumes that track's next try. Ticket and ghost share the stage identity. Both controls use `_retry_race`. |
| Continue from normal results | Opens challenge feedback immediately. Queued uploads and verification continue independently. The finished Game is released after queue admission. |
| Race again / select another track in feedback | Starts the current selected stage from its own entry; no shortcut to the old Game. All three 3×3 tracks, switching back and single-track formats are checked. Existing custom checks cover stages through the fifth track. |
| Another press while connecting or fetching a ghost | Does not request another ticket or reserve an additional try. |
| No tries / ended challenge | Server rejection or ended-state guard gives an explicit reason; existing detail/feedback actions remain disabled when unavailable. Other tracks retain independent budgets. |
| Optional ghost unavailable | Race can still start; ghost presentation does not determine eligibility. |
| Exit or change stage/invitation/account during delayed work | Does not install a stale race or update a newly selected invitation's budget. A ticket already accepted by the server remains a reserved start under the existing rules. |
| Network or contract failure | No unverified competitive retry. The actual connection/contract reason is shown and another explicit attempt can recover. |
| Result queue admission fails | Continue keeps the original Game/ticket and can transfer the result when storage recovers. No completed recording is discarded by the new feedback cleanup. |
| Guest Try track / retry / Continue | Local practice, no competitive ticket or try debit; returns to challenge selection. Checked for single and multi-track challenges. |
| Creation from a completed race / race to set a target | Exact completed result and original settings remain pinned. No personal-best substitution. Standard Continue completes the source-setting flow. |
| Rematch / cancellation / verified totals | Existing backend tests retain explicit reverse invitations, cancellation fences, independent track budgets and best-only totals requiring every track. |

## Changes

Runtime: `game/core/app.gd`, `game/backend/challenges_client.gd`,
`game/ui/race_results.gd`, `game/ui/challenge_result_view.gd`. Native regression fixtures: new
`test_challenge_race_flows.gd` and `test_challenge_multi_http.gd`, plus the result-action
and ordinary HTTP fixtures. Backend changes are test-only: the new multi-track HTTP
test and current daily-catalogue setup in the existing HTTP fixture. Existing
assertions for the removed button and feedback's private retry shortcut were updated
to the owner's new UI contract and the actual Race handler.

## Actual checks and evidence

Pinned engine: `4.7.2.stable.official.ed1daf0bf`; Windows with isolated workspace
APPDATA, disposable fixture accounts/cache and no external API. Native desktop
Compatibility and Mobile use the RTX 3090; Mobile is a desktop renderer test.

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.
For native scripts the arguments are `TestScript -ScriptPath res://tests/NAME.gd
-CommandTimeoutSeconds 180`; desktop runs add `-Graphical -RenderingMethod
gl_compatibility` or `mobile`.

| Actual check | Result |
| --- | --- |
| Task-start focused reproduction | 5 checks, 4 expected failures |
| `test_challenge_race_flows` headless / Compatibility / desktop Mobile | 34 / 36 / 36 checks, zero failures |
| `test_challenge_result_action` headless / Compatibility | 23 / 29 checks, zero failures |
| `test_challenge_series`, `test_custom_challenge_tracks`, `test_app` | 30 / 55 / 141 checks, zero failures |
| Shared `test_rivalry_ghost_retry`, `test_race_results`, `test_challenges`, `test_challenge_result_view` | 17 / 515 / 216 / 293 checks, zero failures |
| `test_script_parse` | 1,093 scripts, zero failures |
| SQLite backend: `pytest backend/tests/test_challenge_series.py backend/tests/test_custom_challenge_tracks.py backend/tests/test_challenges.py -q -k 'sqlite and not migration'` | 36 passed, 2 skipped, 46 deselected; PostgreSQL and migration checks excluded |
| Real native HTTP: `pytest backend/tests/test_challenge_multi_http.py -q -s` | 1 passed; 26 native checks, no script errors; four real five-lap runs verified with attempts 2/1/1 and one combined total |
| Existing `pytest backend/tests/test_challenges_http.py -q -s` within the combined HTTP run | Both passed: 53 ordinary-flow and 52 race-to-set native checks, zero failures |
| Ruff on the changed Python test files | Passed |

Final shared-results/native HTTP receipts and source hashes are in
[report.json](evidence/challenge-race-flows-2026-10-24/report.json).
Native settled views: [normal summary](evidence/challenge-race-flows-2026-10-24/ui/gl_compatibility/normal-results.png),
[three-track feedback](evidence/challenge-race-flows-2026-10-24/ui/gl_compatibility/three-track-feedback.png),
[Mobile summary](evidence/challenge-race-flows-2026-10-24/ui/mobile/normal-results.png).

Initial restricted runs hit PowerShell execution policy / Windows certificate-store
access. Native tests were rerun with the pinned engine's required host access and
workspace-only saves. Initial HTTP fixtures lacked current daily publication and
called a private retry function after the Game had been released; these fixtures
were corrected to prepare the current catalogue and use the real feedback Race
handler. The first new multi-track HTTP fixture also needed to await the initial
challenge refresh. The subsequent combined run retained one failure from the freed
standings callback despite all 26 multi-track assertions passing; the corrected
runtime passed the strict rerun. Optional initially unbuilt comparison snapshots
returned 503, and empty opponent ghosts returned 404 in the disposable HTTP fixture;
neither blocked challenge racing or verification. No production data was involved.

Evidence-output correction: the old result-action test ignored its supplied output
argument and overwrote six historical Compatibility PNGs in the previous task's
folder. Their original bytes were not recoverable. Its original recorded hashes
and Mobile captures remain; a provenance correction is attached to that folder.
The new captures are saved in this task's `ui/actions/`, and the test's default
destination has been corrected. This affects historical screenshot evidence only.

No phone/tablet attachment check or physical-device test, APK/export/install,
live account mutation, production deployment, purchase or owner-process restart was
performed. Owner device reproduction/feel acceptance and a client reload or rebuilt
client remain. This client fix needs no new server migration; the service must
already support the selected challenge format.
