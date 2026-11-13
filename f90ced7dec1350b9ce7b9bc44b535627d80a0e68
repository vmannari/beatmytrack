# Weekly Rivalry summary popup, 2026-10-26

The completed week now opens a decorated summary over the existing weekly screen. **Back to results**, the close icon, Escape and Enter dismiss it. The existing **Continue to next week** button remains on the weekly screen and owns the existing rollover flow.

RSP01: The popup presents the authoritative final position, total points, actual contested track victories and existing weekly highlights. It reuses the earned award art: laurels for a podium, crown and a bounded confetti flourish for a champion, and the Perfect Week badge only for five outright victories. Unranked/ordinary completed weeks do not receive a fabricated award. There is no extra vehicle viewport or scrollbar in the summary.

RSP02: Opening or dismissing the popup keeps the exact weekly page instance and component rectangles. `weekly_rivalry_page.gd`, `rivalry_share_dialog.gd` and `rivalry_award_art.gd` are byte-identical to the task-start snapshots. The normal podium, standings, numbered tracks, Share and Continue retain their existing placement and behavior. Only the existing standings list scrolls.

RSP03: A reviewed summary is suppressed for the same account scope, group, week, vehicle and Circuit mode during the current App session. This is an in-memory review marker, not a saved acknowledgement or a server operation. Dismissal does not enroll, advance, save settings, alter scores, copy to the clipboard or share anything. Restarting the App may show the still-pending completed week again until the user continues.

RSP04: Only a current authoritative completed overview with five tracks can open the popup. Cached/sample results, stale account scopes, details, racing/loading and menu transitions cannot open it. Other owned windows finish first. Navigation or a changed membership silently removes a stale summary without marking it reviewed. Changed final facts replace an unreviewed summary. Busy background refreshes retain the currently visible snapshot. The owned-window lifecycle supplies modal input blocking, scrim, keyboard dismissal and restored focus.

R01: The popup fits four viewport sizes from 960x540 to 1938x1282 and live resizing in both desktop renderers. Header/date, award title, crown, Perfect Week badge, metric cards, highlights and the dismissal action are checked against the actual dialog bounds. Existing catalogue strings translate the event/date, metric captions and Back to results action. Existing model-supplied award/highlight phrases retain their existing English fallback where no catalogue entry exists; comprehensive translation of those domain phrases remains separate acceptance work.

Q01: The focused suite uses the real App and a deterministic local Rivalry service fixture. It checks six earned-result states, exact facts, unchanged page geometry and saves, one popup per reviewed membership, authoritative refresh, changed results, navigation/account invalidation, other-modal deferral, background refresh, live resize, localized layouts, underlying mouse blocking, Escape and Enter. Existing UI suites explicitly dismiss the new popup before inspecting the original page; all original scoring, awards, geometry and rollover assertions remain.

Runtime changes are the new `game/ui/rivalry_summary_dialog.gd` and narrow scheduling/context additions in `game/core/app.gd`. Tests add the focused popup suite, an isolated task-start comparison runner, and explicit dismissal in the existing result, awards, layout, week-completion, Share and weekly hub fixtures. Shared App changes made concurrently by other work are preserved and excluded from the task-only review patch.

Actual pinned Godot 4.7.2 results:

| Check | Result |
| --- | --- |
| Popup, native Compatibility | 954 checks, 0 failures |
| Popup, desktop Mobile/Vulkan | 954 checks, 0 failures |
| Shared weekly layout, headless | 3012 checks, 0 failures |
| Existing Continue/rollover | 38 checks, 0 failures |
| Awards domain checks | 64 checks, 0 failures |
| All-script parser | 1260 scripts, 0 failures |
| Task-start App, new automatic-popup requirement | 3 checks, 1 expected failure: no summary opens |
| Broader weekly hub | 1190 checks, 3 existing active-podium height failures |
| Exact task-start App/page in isolated memory | 1192 checks, same 3 hub failures; two extra reload assertions |

The retained hub assertion requires podium height at most 194; current and task-start both measure 203 at all three sizes. No failing assertion is changed. Initial focused-run navigation timing failure and the intervening concurrent Garage override-signature parse failure are retained in the evidence; the final focused suites pass. The earlier independent Share-dialog geometry findings are outside this popup change; no new Share layout pass is claimed.

Commands, snapshots, source/image hashes and the scoped review patch are recorded in [report.json](evidence/rivalry-summary-popup-2026-10-26/report.json). All App fixtures use disposable saves under `build/rivalry-summary-popup/userdata`, with `BMT_API_URL` disabled by the tests. The baseline runners reload exact task-start sources only inside their own engine process and never overwrite runtime files.

[Champion popup](evidence/rivalry-summary-popup-2026-10-26/ui/champion-1280x720.png), [Perfect Week at 960x540](evidence/rivalry-summary-popup-2026-10-26/ui/perfect-960x540.png), and [weekly screen after dismissal](evidence/rivalry-summary-popup-2026-10-26/ui/results-1280x720.png) show the actual native UI. Matched desktop Mobile captures are in the `ui/mobile` directory.

Reload and owner appearance/touch acceptance remain. No physical-device test or device attachment check, APK/build/install, real authentication/purchase, owner-save or live database mutation, deployment or owner-process restart was performed. No staging or commit; concurrent changes are preserved.
