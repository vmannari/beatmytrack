# Free Race track list - 2026-10-17

FRL01 opens Free Race with a vertical grid of the existing scenic track cards. FRL02 opens the retained hero, records, carousel and Race action on selection, with an X returning to the same list position. FRL03 places the detail favorite star below the X. G01 preserves racing, five laps and selected publication contracts. R01 keeps the existing metadata, pagination and cache bounds. Q01 covers native input and rendered views.

The list fills the area above the original Random track / Filters / Search / refresh actions. Its columns respond to the available design width. On smaller physical windows the existing 1280x720 game canvas scales normally. Cards retain their biome artwork, actual metadata outlines, names, creators, ratings and independent favorite controls. Track details and their comparison reads start after selection. Filter/search drawers block both galleries while open.

Only nearby rows have controls. A 5,000-track fixture reaches distant pages while retaining the existing 15-page metadata cache. The inactive carousel cannot pull the list back to page zero. Failed pages wait for explicit refresh; closing a detail invalidates pending selection presentation. Exposure collection follows the visible gallery. Reconciled cards select their current metadata.

## Implementation

- `game/ui/track_browser.gd`: list, view switching, close control, lowered detail star, paging and visible-card exposure handling.
- `game/tests/test_free_race_list.gd`: isolated full-app touch/wheel, selection, favorite, close, drawer, empty/unavailable and distant-page checks.
- Existing app/detail, paging, histogram and menu-gesture fixtures explicitly open a detail where needed. Primary page gestures are tested outside the new scroll area; arrival ownership is tested against the visible vertical list.

No backend code, saved-data schema, canonical simulation, track artwork or assets were changed by this task. Concurrent safety, achievements, Night rendering and other working-tree changes are retained.

## Evidence and checks

Final native checks: 73 headless, 85 Compatibility and 85 Mobile, all passing. App 101, catalog 21, discovery paging 269, page gestures 240, race modes 42, menu presentation 41, selected-detail speed/cache 27, histogram hydration 22 and parser 854 also pass. The two old loading suites still fail; their same removed `_resolve_thread` reference and cache assumptions reproduce with the saved original TrackBrowser. The initial broader app shader failure is retained; its rerun passes.

Exact commands, logs, hashes, initial failures and final outcomes are recorded in [report.json](evidence/free-race-list-2026-10-17/report.json). The task-only patch is [task-only.patch](evidence/free-race-list-2026-10-17/task-only.patch).

Native test screenshots use 27 server-shaped fixture records, with the existing real card artwork and starter route; they are not a live-service catalog acceptance claim. The paging stress fixture contains 5,000 metadata records.

- [List, 1280x720](evidence/free-race-list-2026-10-17/gl_compatibility/list-1280x720.png)
- [Selected detail with X and lower star](evidence/free-race-list-2026-10-17/gl_compatibility/detail-1280x720.png)
- [Return to the scrolled list](evidence/free-race-list-2026-10-17/gl_compatibility/returned-1280x720.png)
- [Mobile renderer, 960x540 list](evidence/free-race-list-2026-10-17/mobile/list-960x540.png)
- [Mobile renderer, 960x540 detail](evidence/free-race-list-2026-10-17/mobile/detail-960x540.png)

Initial setup attempts hit Windows script execution policy and sandbox user-log/certificate access; the commands use process-scoped policy and isolated workspace APPDATA. An early compact test forced a 960-unit logical canvas, overflowing the retained detail view; the corrected fixture uses the game's existing 1280x720 scaling. A Mobile run encountered a concurrently introduced texture before its import was ready; an import attempt also encountered a locked temporary Windows audio DLL. Subsequent native UI runs are recorded separately. Final visual review also found that carousel cards retained their hidden preparation widths; resizing retained controls to the settled carousel width fixes the clipped first card. The preserved initial view is `initial-detail-card-width.png`, and the final distant-selection check requires the entire selected card to be visible. Broader regressions retain their actual failures, including historical `_resolve_thread` references and the observed road shader compile error.

Owner appearance acceptance remains. No phone attachment check or device test, APK, live backend read/mutation/deployment, or FPS claim was performed by this task.
