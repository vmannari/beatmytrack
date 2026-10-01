# Race discovery reference pass ? 2026-10-01

Requirements: R01, V03, V04, G03, Q01. Owner request: rename Play to Race, adopt the supplied discovery composition, place a continuously scrollable/swipeable track strip at the bottom, add Search beside Filters, and use an icon-only right rail with Free race and placeholders.

## Delivered

The shared navigation now reads Race. A large selected-track scenic panel carries the title, creator, real route outline, five-lap count, measured distance per lap, favorite and race actions. Records and the race-time comparison sit below it, followed by the track carousel and Random track / Filters / Search / Race actions. The right rail uses accessible hover descriptions and disabled Coming soon placeholders for the other modes. Both race actions use the existing selection/loading gate.

The carousel supports touch swipe, desktop drag, mouse wheel, scrollbar and arrow controls. Crossing the gesture threshold cancels the tap action, including favorite stars. Rendering stays bounded to twelve nearby cards while the scroll extent covers the full filtered catalog. Name/creator search, biome/sort/collection filters, favorites and random selection use the existing catalog/provider. Refreshes with unchanged filters preserve the scroll position. Shared-track high scores remain available; rating opens a compact dialog to avoid pushing the bottom actions outside the phone viewport.

Artwork reuses the existing original biome illustrations; the supplied reference is not copied into shipping assets. This is a layout adaptation, not a recreation of its lighthouse/car illustration. Runtime unavailable records stay empty; populated evidence is explicitly metadata/comparison fixtures and is not claimed racing history. Gameplay, camera, physics, accounts and backend contracts are unchanged.

## Changed files

- `game/core/app.gd`: shared Race label (other existing uncommitted work preserved).
- `game/ui/track_browser.gd`: discovery composition, filters/search dialogs, carousel virtualization, route facts, placeholders and rating dialog.
- `game/ui/track_carousel.gd`: gesture ownership and desktop scrolling.
- `game/ui/track_tile.gd`: compact carousel cards with readable route silhouettes; other tile consumers retain their layout.
- `game/ui/menu_icon.gd`: original filter, trophy and target vectors.
- `game/tests/capture_premium_menus.gd`: actual graphical/gesture/search/large-catalog and cloud-control bounds checks; waits for account startup and isolates populated catalog fixtures from live refreshes.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and evidence.

## Actual verification

All Godot commands used the pinned build through `scripts/dev.ps1`:

| Command | Outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus` | Final 661 checks, zero failures; 1280?720, 960?540 and 1600?720 graphical captures. Viewport-dispatched touch swipes, swipe-vs-tap/favorite separation, Search/Filters opening, name/creator search, 1,000 extra catalog entries and final-entry reachability, bounded rendering, cloud action bounds and navigation. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus` | 26 checks, zero failures. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenuLoading` | 19 checks, zero failures, including superseded/cached selections and race locking. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://ui/track_browser.gd` | Initial parse passed. Intermediate edits had parse failures, corrected before final graphical suite. |
| `git diff --check` (task files) | Passed; CRLF normalization notices only. |
| `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe devices` | Empty device list. No phone attached. |

Early graphical runs exposed vertical overflow and outdated paging/account fixture assumptions, fixed before the final pass. One intermediate swipe assertion incorrectly assumed 280 pixels remained on the widest viewport; it now checks movement up to the available scroll extent. No failing behavior invariant was removed.

## Evidence and remaining acceptance

- [Desktop carousel](evidence/race-discovery-2026-10-01/tracks-populated-fixture-1280x720.png)
- [Compact landscape carousel](evidence/race-discovery-2026-10-01/tracks-populated-fixture-960x540.png)
- [Wide comparison fixture](evidence/race-discovery-2026-10-01/tracks-data-fixture-1600x720.png)
- [Shared-track control layout fixture](evidence/race-discovery-2026-10-01/tracks-cloud-controls-fixture-1280x720.png)

Desktop and compact screenshots were inspected. Owner visual acceptance, physical-phone swipe/keyboard/safe-area testing and Android export remain outstanding. No physical-device test or Android export was performed. New rail modes remain placeholders; this pass does not add friends, seasons or challenges. No new art generation or production deployment.


## Owner corrections ? stable layout and full-card scrolling (2026-10-01)

Requirements R01/V03/V04/G03/Q01. This follow-up supersedes the initial right-rail, duplicate hero action and arrow/scrollbar descriptions above.

- Hero, records, gallery and bottom action regions now allocate space independently of track content. Fixed-width record/standings columns and clipped title text stop long names or additional scores from moving adjacent sections. Async track selection keeps the previous details visible until the new track is ready; the single race button shows loading and remains disabled during selection.
- The icon-only mode rail is on the left. Its redundant Random action is removed. The hero Race action is removed; bottom-right Race is the sole race-start action.
- Random track, Filters and Search each have an equal 196?60 logical-pixel target.
- Carousel arrows and visible scrollbar are removed. Card widths adapt to fit a whole number of cards within the available width, with at most a few pixels of centering remainder. Dragging follows the pointer continuously; release animates to the nearest complete-card boundary over 0.18 seconds. Mouse-wheel input animates one card per step, and keyboard focus scrolls to full-card boundaries. New gestures, random selection, resizing and catalog refresh cancel obsolete snap animations.

Changed files: `game/ui/track_browser.gd`, `game/ui/track_carousel.gd`, `game/tests/capture_premium_menus.gd`, `game/tests/test_menu_loading.gd`, this document, AGENTS/status/phase notes and the new evidence directory. No changes to physics, replay, camera, backend or asset provenance.

Actual commands (pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):

- `CheckScript -ScriptPath res://ui/track_browser.gd`: passed.
- `CaptureMenus`: final **730 checks, zero failures**, at 1280?720, 960?540 and 1600?720. Checks exact section rectangles across long titles, local/shared tracks and comparison data; left rail, duplicate removal, equal control widths; continuous drag then card-boundary settling, wheel scrolling, thousand-entry reachability and existing search/navigation behavior.
- `TestMenuLoading`: **21 checks, zero failures**, including unchanged rectangles while async selections are pending and after completion.
- `TestMenus`: **26 checks, zero failures**.
- Scoped `git diff --check`: passed (CRLF notices only).
- `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe devices`: no device attached. No Android export or physical-device test.

Intermediate graphical runs caught a mouse-wheel step rounding back to its starting card and an obsolete idle snap interfering with catalog changes. Both were corrected; final tests retain scroll movement and final-entry reachability assertions.

Inspected evidence: [desktop](evidence/race-discovery-stable-2026-10-01/tracks-populated-fixture-1280x720.png), [compact landscape](evidence/race-discovery-stable-2026-10-01/tracks-populated-fixture-960x540.png), [wide scrolled row](evidence/race-discovery-stable-2026-10-01/tracks-storm-fixture-1600x720.png), [three-score shared-track fixture](evidence/race-discovery-stable-2026-10-01/tracks-cloud-controls-fixture-1280x720.png). All populated cards/scores remain disposable evidence fixtures. Remaining acceptance: owner visual review and physical-phone swipe feel/safe-area/keyboard checks.


## Filter drawer and fractional rating ? 2026-10-01

Requirements R01/V03/V04/G03/Q01. Owner supplied a right-hand filter drawer reference, requested reuse of existing icons (especially biomes), then replaced the pictured rating buttons with a slider in 0.1 increments. The mode rail stays on the left and the preceding stable Race layout remains intact.

Implemented a modal right-hand drawer over a dimmed Race screen, with Show (Recommended / Favorites / My tracks), the existing six biome choices/icons, race-count choices, minimum-rating slider, sorting, active-filter count, Reset, close and a live Show N tracks action. The existing menu icon set is reused; only the missing close glyph was added. The central content can scroll on constrained viewports while the header/footer remain fixed; all groups fit without scrolling at the tested landscape sizes.

Choices remain a draft until Show tracks. Close, backdrop tap and Escape discard changes and restore carousel input/focus. Reset changes the draft filters but preserves the separate search query. The displayed match count includes the current search, collection, biome and minimum rating. Rating ranges from Any (0) to 5, with 0.1 input/keyboard steps and larger whole-star visual tick marks. Touch tapping and dragging are explicitly handled without depending on touch-to-mouse emulation. Sorting by rating uses cloud aggregate ratings for shared tracks and existing local ratings for local tracks; unrated tracks are excluded only when the minimum exceeds zero.

The current backend/catalog does not expose completed race counts. Low / Medium / High and Most raced are therefore visibly disabled with an explanation. No counts are fabricated from votes or leaderboard population. The read-model supports future supplied counts: Low 0?9, Medium 10?49, High 50+ (proposed UI thresholds, no backend contract changes). Recommended preserves the existing default name order; personalized recommendations are not added.

Changed files: `game/ui/track_filter_drawer.gd` (new drawer), `track_browser.gd` (integration and active count), `track_discovery_provider.gd` (combined fractional rating/race-count filtering and rating sort), `menu_icon.gd` (close glyph), `game/tests/capture_premium_menus.gd`, `test_menu_presentation.gd`, this document, AGENTS/status/phase notes and evidence.

Actual commands used the pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CheckScript -ScriptPath res://ui/track_browser.gd`: passed.
- `CaptureMenus`: final **922 checks, zero failures** at 1280?720, 960?540 and 1600?720. Includes viewport touch choices, slider tap/drag/clamping, keyboard 0.1 adjustment, live counts, zero results, apply/reset/reopen/cancel, backdrop dismissal without underlying navigation, full drawer fit and existing Race layout/carousel regressions.
- `TestMenus`: **36 checks, zero failures**, including exact fractional boundaries, missing ratings/counts, compound filters and local/shared rating order.
- `TestMenuLoading`: **21 checks, zero failures**.
- Scoped `git diff --check`: passed (CRLF normalization notices only).
- `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe devices`: no attached device. No physical-phone test or Android export performed.

Initial visual review found clipped Show content and a stale pre-render rating capture; spacing and capture settling were corrected. Additional touch checks found that native slider/backdrop handling did not consume viewport touch events; explicit handling fixed both, and the final suite retains those tests.

Inspected evidence: [default drawer](evidence/filter-drawer-2026-10-01/filters-default-1280x720.png), [4.1 minimum](evidence/filter-drawer-2026-10-01/filters-rating-1280x720.png), [compact landscape](evidence/filter-drawer-2026-10-01/filters-rating-960x540.png), [wide landscape](evidence/filter-drawer-2026-10-01/filters-default-1600x720.png). Populated cards/ratings in evidence are disposable fixtures. Remaining acceptance: owner visual review and actual-phone touch feel/safe-area testing; race-count controls await real catalog data.
