# Play page reference update - 2026-09-23

Requirements: R01, V03, V05, Q01; owner Play-page reference and six requested presentation changes.

Implemented icons for Recommended, Favorites, My tracks, search, biome and sorting. Surprise me now sits in the bottom action row with an original dice glyph, alongside Main menu and the selected-track yellow Race action. The lower panel has existing original biome scenery, track attribution, stacked personal records, simultaneous race/lap comparison cards under WHERE YOU STAND and a friends area. Play no longer exposes Edit, Remix or Delete, including invalid drafts. Invalid drafts direct users to Create and cannot launch the previously selected race. Existing selection, filters, favorites, pagination and random selection remain in use.

Changed runtime files: game/ui/track_browser.gd, game/ui/menu_icon.gd, game/ui/track_distribution.gd, game/ui/results_icons.gd; game/core/app.gd adds the Home signal connection. Updated game/tests/capture_premium_menus.gd checks chart arrangement, absence of modification actions and actual viewport-touch Home navigation. No new raster assets; original vector icons and existing provenance-tracked scenery are reused.

Actual commands (PowerShell):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://ui/track_browser.gd`: passed on pinned Godot 4.7.2.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus`: 22 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: first pass found 36 footer-boundary failures; corrected gallery height/record spacing. Final pass: 466 checks, zero failures at 1280x720, 960x540 and 1600x720, including touch navigation, favorites and pagination.
- `git diff --check -- game/ui/track_browser.gd game/ui/menu_icon.gd game/ui/track_distribution.gd game/tests/capture_premium_menus.gd`: final check clean after removing a trailing blank line.

Evidence: [populated local gallery](evidence/play-page-2026-09-23/tracks-populated-fixture-1280x720.png), [comparison-data fixture](evidence/play-page-2026-09-23/tracks-data-fixture-1280x720.png), [compact output](evidence/play-page-2026-09-23/tracks-populated-fixture-960x540.png). Desktop screenshots inspected. Gallery names and supplied comparison distributions in these captures are isolated presentation fixtures, not real online records or owner tracks.

Limitations and acceptance: online comparisons and friend challenges are still unconnected. Both comparison cards show explicit empty states in normal local use; no fabricated standings. Challenge friends explains availability. Biome scenery is illustrative rather than an exact rendered track. Physical-phone testing and Android export were not performed; device attachment was not checked. Owner visual acceptance and physical-device readability/touch checks remain. Existing unrelated working-tree changes were preserved.

## Perspective dice follow-up

2026-09-23 V03/V05/Q01: replaced the flat dice glyph in game/ui/menu_icon.gd with an original outlined three-face cube, subtle face shading and perspective pips, following the owner reference. Ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: 466 checks, zero failures across three sizes. Refreshed the above evidence and inspected the 1280x720 screenshot. No physical-phone test or Android export; owner visual acceptance remains.

## More menu and Favorites follow-up

2026-09-23 R01/V03/V05/Q01: removed the More menu (including its Import/Refresh entries) from Play and changed Favorites to the same MenuIcon star used by track cards. Runtime change: game/ui/track_browser.gd. Ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: 454 checks, zero failures across three sizes. The count drops by 12 because the removed menu no longer receives per-capture button-boundary checks. Refreshed evidence and inspected the desktop screenshot. No phone test or Android export; owner visual acceptance remains.

## Footer inset follow-up

2026-09-23 R01/V03/V05/Q01: the Play action row retains the shared 20 px bottom inset at both 1280x720 and 960x540. Owner follow-up restores the natural 8 px spacing between browser rows and instead reduces each gallery card from 196 px to 180 px, its title footer from 77 px to 61 px, and its title type from 25 px to 21 px. Both changed scripts pass `CheckScript`; `CaptureMenus` passes 454 checks at 1280x720, 960x540 and 1600x720, and refreshed desktop/compact captures were inspected. No phone test or Android export was performed.
