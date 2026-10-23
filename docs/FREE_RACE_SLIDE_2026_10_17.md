# Free Race track view slides - 2026-10-17

FRS01 adds a 0.32-second horizontal slide when a card opens track detail and reverses the motion when X closes it. The full list leaves to the left as detail arrives from the right; returning brings the retained list back from the left. FRS02 keeps the header, mode rail and shared action row fixed. G01/R01 retain the selected track, list scroll, original cards, five-lap racing, metadata and cache bounds. Q01 covers actual native input and intermediate rendered frames.

`game/ui/track_browser.gd` places the existing list and detail controls in one clipped viewport. Both retained views move together through an eased tween, with a small gap. A gesture-blocking layer and paused gallery owners prevent taps or drags on moving content from selecting a track or navigating primary menus. A reversal continues from the displayed position; resizing follows the new viewport width. After settlement only the destination remains visible. No screenshot textures, duplicate track scenes, new backend requests or per-frame layout rebuilds are introduced.

`game/tests/test_free_race_list.gd` samples real opening/closing tweens at halfway, checks clipping, fixed header/rail, blocked touches, unchanged selection and scroll, reversal, resize, open-drawer input protection, retained-menu reparenting and cleanup, and retains the earlier paging/favorites/detail checks.

The initial native check exposed an eight-unit scrollbar minimum offset from anchoring a scroll container before its parent had a size. Using manually sized pages with top-left anchors restores the existing card columns and visible scrollbar, and avoids anchored-size warnings. An initial app run also hit a detached-node lifecycle error; deferred reveal/tween guards and settling a retained moving page protect navigation cleanup. That correction and all actual commands/outcomes are recorded in [report.json](evidence/free-race-slide-2026-10-17/report.json); [task-only.patch](evidence/free-race-slide-2026-10-17/task-only.patch) contains only this follow-up.

Final checks pass: 149 headless, 167 Compatibility, 167 Mobile, app 101, catalog 21 and parser 854. Final UI logs contain no warnings or errors. The app rerun passes after the lifecycle correction.

Native fixture previews:

- [Opening halfway, 1280x720](evidence/free-race-slide-2026-10-17/gl_compatibility/opening-mid-1280x720.png)
- [Closing halfway, 1280x720](evidence/free-race-slide-2026-10-17/gl_compatibility/closing-mid-1280x720.png)
- [Mobile opening halfway, 960x540](evidence/free-race-slide-2026-10-17/mobile/opening-mid-960x540.png)
- [Returned list](evidence/free-race-slide-2026-10-17/gl_compatibility/returned-1280x720.png)

The 27/5,000-record fixtures use existing card artwork and route metadata. These captures do not claim live-service or physical-phone acceptance. The two historical loading-suite failures documented in the original list task remain outside this follow-up.

Owner appearance acceptance remains. No phone attachment check or device test, APK, backend change/deployment or FPS claim was performed.
