# Free Race top-down push - 2026-10-17

FRT01 supersedes the horizontal direction in the previous slide follow-up. Track detail now enters from above while the retained track rows move downward beneath it. Their edges meet throughout the 0.32-second motion. Closing reverses the push: detail exits upward and the same list moves back up to its original scroll position. FRT02 keeps the header, mode rail and shared actions fixed. G01/R01 preserve selection, card contents, saved choices, original racing and bounded metadata/cache behavior. Q01 covers native midpoint input and rendered views.

`game/ui/track_browser.gd` changes only the view transition's geometry: travel follows the viewport height, both horizontal offsets stay zero, and the previous gap is removed. Existing reversal, resize, input blocking, modal and retained-menu cleanup continue to apply. Track-to-track browsing inside detail keeps its existing behavior.

`game/tests/test_free_race_list.gd` checks the above/below positions and touching edges at the real tween midpoint, verifies a vertical drag cannot scroll moving content, and resizes both dimensions while checking the push against the actual viewport height. The earlier selection, close, scroll, favorites, paging, interruption and cleanup checks remain.

Actual commands, outcomes, source hashes and the scoped checkpoint are recorded in [report.json](evidence/free-race-top-push-2026-10-17/report.json) and [task-only.patch](evidence/free-race-top-push-2026-10-17/task-only.patch).

Final checks pass: 155 headless, 173 Compatibility, 173 Mobile, app 101 and parser 854. Final logs contain no warnings or errors.

Native previews:

- [Opening halfway, 1280x720](evidence/free-race-top-push-2026-10-17/gl_compatibility/opening-mid-1280x720.png)
- [Closing halfway, 1280x720](evidence/free-race-top-push-2026-10-17/gl_compatibility/closing-mid-1280x720.png)
- [Mobile opening halfway, 960x540](evidence/free-race-top-push-2026-10-17/mobile/opening-mid-960x540.png)
- [Returned list](evidence/free-race-top-push-2026-10-17/gl_compatibility/returned-1280x720.png)

The captures use the existing isolated 27/5,000-record metadata fixtures. Owner appearance acceptance remains. No phone attachment check or device test, APK, backend change/deployment or FPS claim was performed.
