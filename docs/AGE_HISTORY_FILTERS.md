# Race age and personal-history filters ? 2026-10-01

Requirements: R01/V03/V04/G03/Q01; owner request for creation-age and raced/not-raced filters.

Created: Any time, last 7, 30 or 90 days. Cutoff is inclusive and uses UTC seconds outside simulation. Cloud tracks use version created_at (not republish time). New local tracks use first successful save time in an adjacent .created metadata file; edits preserve it without changing canonical track JSON/hashes. Existing local/builtin tracks without dates remain unknown, included only under Any time. Imported tracks first saved locally use their local first-save time. Date metadata is local and does not travel in exported track JSON.

Your races: Any, Raced, Not raced. Completed valid races persist the track identity atomically alongside PBs. History spans cars/rules on this device and is not account-synced. Practice/incomplete races do not count. Old PB saves have only opaque rules hashes, so historical track identities cannot be recovered by this metadata-only query; history begins with races saved by this revision. Cloud history is per immutable version. No player files are deleted.

Both choices combine with existing filters/search and participate in draft preview counts, apply, cancel, Reset and the active filter badge. The expanded drawer scrolls with its actions fixed at the bottom; opening resets to its heading.

Changed files: game/ui/track_filter_drawer.gd, track_discovery_provider.gd, track_browser.gd, track_search_drawer.gd, track_catalog.gd; game/persistence/local_records.gd and track_library.gd; game/tests/test_menu_presentation.gd, test_records.gd and capture_premium_menus.gd; documentation and screenshots.

Actual commands via pinned scripts/dev.ps1 (powershell -NoProfile -ExecutionPolicy Bypass -File):
- TestMenus: 48 checks, zero failures (cutoffs, unknown/future dates, combination, persistence, stable creation dates).
- TestRecords: 54 checks, zero failures (including transactional rollback and race-history write).
- TestCreator: 113 checks, zero failures.
- CaptureMenus: 1534 checks, three failures in section-rectangle stability assertions after long-title/comparison/cloud fixtures at 1600x720. All filter assertions pass, including touch selection at all three sizes. Earlier run also exposed drawer opening scroll, fixed and passing in final run. Broader suite is not green.
- TestCatalog: fails obsolete last-page expectation and nonexistent _page call; catalog now uses continuous carousel. No assertions weakened to hide this failure.
- Scoped git diff --check: passed.
- Android SDK adb devices: one phone attached. No phone test or export performed.

Inspected compact screenshot: [30 days + Not raced](evidence/age-history-filters-2026-10-01/filters-age-history-960x540.png). Desktop and wide evidence are in the same directory. Remaining acceptance: owner visual review, physical-phone scrolling/touch, cross-device/account history if requested, and broader menu/catalog test failures.
