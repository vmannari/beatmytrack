# Free Race High Scores actions - 2026-10-17

FRA01 addresses the owner's clipped Report / block button in the selected track view. FRA02 keeps three score rows, both comparison charts and the complete action row inside the records area. G01/R01 retain the vertical track list, top-down push, close/favorite controls, selected track/version, bounded caches and original racing. Q01 covers native layout and touch activation.

`game/ui/track_browser.gd` now reserves the High Scores column's actual minimum width, including all three text buttons and the section insets, instead of clipping them inside 270 units. The current theme requires 344 units. The records panel follows its allocated slot after layout, removing the initial 24-unit right overrun. Section top padding changes from eight to five units so populated charts and three scores fit the existing 180-unit panel. The buttons retain their full labels, 48-unit height and existing callbacks.

`game/tests/test_free_race_list.gd` adds bounds checks for pending, populated, empty and unavailable scores at 960x540, 1280x720 and 1720x900. Three long driver names and country flags exercise populated rows; both histograms retain their minimum dimensions. Actual viewport touch opens the safety sheet and verifies the selected immutable track version, with no submission. The original list, paging, favorites, push, reversal, resize, close and retained-menu checks remain.

Actual commands, outcomes, logs, source hashes and the task-only checkpoint are recorded in [report.json](evidence/free-race-score-actions-2026-10-17/report.json) and [task-only.patch](evidence/free-race-score-actions-2026-10-17/task-only.patch). The original source reproduces 18 failed checks, including the clipped report target and failed touch activation. Initial padding checks retained the right overrun; the first resize callback was attached before panel construction and produced a nil assignment. The final callback is attached after construction and follows the real slot resize. Those attempts are retained in the evidence logs.

Final checks pass: 233 headless, 263 Compatibility, 263 desktop Mobile, app 101 and parser 854. Final logs contain no warnings or errors.

Native previews:

- [Three scores and complete actions, 1280x720](evidence/free-race-score-actions-2026-10-17/gl_compatibility/scores-populated-1280x720.png)
- [Small window, 960x540](evidence/free-race-score-actions-2026-10-17/gl_compatibility/detail-960x540.png)
- [Report sheet opened by touch](evidence/free-race-score-actions-2026-10-17/gl_compatibility/report-open-1280x720.png)
- [Mobile renderer with three scores](evidence/free-race-score-actions-2026-10-17/mobile/scores-populated-1280x720.png)

The native runs use isolated local metadata and score fixtures. Owner appearance acceptance remains. No phone attachment check or device test, APK, live report, backend change/deployment or FPS claim was performed.
