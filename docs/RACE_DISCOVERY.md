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

## Mode icons and immediate hero previews - 2026-10-01

Requirements R01/V03/V04/G03/Q01. Replaced the left rail glyphs with original authored vector trophy, chequered flag, target and friends artwork. Consistent optical weight, subtle fills, sharper mipmapped textures, clearer inactive contrast and bordered tiles retain the existing dimensions and placeholder behavior. No external artwork or generated assets are used.

Cold selections now paint title, creator, biome scenery and route outline directly from catalog metadata before compilation/download completes. Preview distance is marked approximate; canonical geometry replaces it when ready. Cached tracks still resolve immediately. The fixed records area remains quiet during preparation: the owner's follow-up removed the flashing "Loading track records" text. Previous-track records are hidden until the selected track is ready; actual failures retain an actionable error. Race stays disabled until preparation completes. Rapid choices and stale worker/download results cannot restore obsolete heroes or unlock an unrelated track.

Desktop profiling (same Speedy/Knot content hashes before and after):

| Track | Before: hero waited for ready | After: selection handler | After: first hero frame | After: race preparation ready |
| --- | --- | --- | --- | --- |
| Speedy | 343.267 ms | 1.332 ms | 22.583 ms | 358.034 ms |
| Knot | 453.029 ms | 1.341 ms | 22.775 ms | 486.887 ms |

This improves visible response, not compilation speed. Timings are desktop samples, not a phone performance guarantee. Raw logs are in [evidence](evidence/race-icons-latency-2026-10-01/after-profile.log), alongside the before log.

Changed files: new `game/ui/race_mode_icons.gd`, `game/ui/track_browser.gd`, `game/tests/test_menu_loading.gd`, `profile_menu_selection.gd`, `capture_premium_menus.gd`, this document, status/phase notes and evidence. The capture harness follows the current workspace's existing Race-first navigation (no Home tab); the production app navigation changes belong to separate work.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `ProfileMenus` before/after: passed; identical compiled track hashes.
- `TestMenuLoading`: final **28 checks, zero failures**, including synchronous rapid hero previews, quiet pending records, stale work/cache handling and failed downloads.
- `TestMenus`: **36 checks, zero failures**.
- `CaptureMenus`: final **913 checks, zero failures**, three landscape sizes. Early runs exposed stale Home-tab assumptions and an attempted backdrop tap inside the drawer; the harness now tests dismissal using the actual exposed Create tab, preserving the underlying-navigation assertion.
- Scoped `git diff --check`: passed.
- Android SDK `adb devices`: empty list. No phone attached, physical-device test or Android export performed.

Inspected [desktop](evidence/race-icons-latency-2026-10-01/tracks-populated-fixture-1280x720.png) and [compact landscape](evidence/race-icons-latency-2026-10-01/tracks-populated-fixture-960x540.png) captures. Populated records/cards are disposable fixtures. Owner icon approval and physical-phone latency/touch acceptance remain outstanding.


## Hero crossfade trial - 2026-10-01

Requirements R01/V03/V04/G03/Q01. Owner accepted a 160 ms scenery crossfade with a subtle title and route-outline fade. New selections immediately update metadata; title, creator and outline fade from 65% to full opacity over 160 ms. Scenery stays opaque underneath fading outgoing layers to avoid a dark flash. Interrupted outgoing layers retain their current opacity and expire independently within 160 ms; no transitions are queued. Same-selection record/favorite/compilation refreshes do not start a second fade. Panels, records, buttons and carousel remain stationary.

Changed files: `game/ui/track_browser.gd`, `game/tests/test_menu_loading.gd`, transition fixture additions in `game/tests/capture_premium_menus.gd`, this document, status/phase notes and evidence.

Actual pinned-engine commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `TestMenuLoading`: final **32 checks, zero failures**. Checks immediate titles, readable opacity, rapid-selection layers, cleanup, final opacity and existing async safety. Initial exact float comparison was corrected to an approximate comparison.
- `CaptureMenus`: final **1072 checks, zero failures**, at 1280x720, 960x540 and 1600x720. Adds mid-fade opacity, fixed bounds, immediate interrupt title and layer cleanup checks. The presentation-only fixture uses Pine -> Desert -> Winter; canonical race selection/records are deliberately retained and do not represent those metadata fixtures.
- Scoped `git diff --cached --check`: passed.
- Android SDK `adb devices`: empty list; no phone attached. No Android export or physical-device test.

Inspected [desktop mid-fade](evidence/hero-crossfade-2026-10-01/hero-crossfade-mid-1280x720.png) and [compact settled hero](evidence/hero-crossfade-2026-10-01/hero-crossfade-settled-960x540.png). Interrupted and wide captures plus test logs are in the same evidence directory. Owner motion/visual acceptance and physical-phone smoothness remain outstanding.


## Search drawer reference - 2026-10-01

Requirements R01/V03/V04/G03/Q01. Replaced the native Search popup with a navy right-hand modal drawer over a dimmed Race screen. Includes Name or creator / Name / Creator choices, outlined input with inline clear, live match count, highlighted title matches, existing scenery thumbnails and biome icons, real metadata route outlines, four initial previews with expandable additional results, Clear and yellow Show N tracks. Scrollable results retain fixed header/footer controls. No generated artwork or new dependencies.

Search previews combine the draft query/scope with current filters and sorting through the existing discovery provider. Typing does not change the underlying gallery until Show tracks or Enter; a result tap applies the search and selects that track directly. Clear previews an empty query while preserving scope/filters. Close, Escape and backdrop taps discard pending changes. Focus cycles inside the drawer, carousel input is suspended while open, and the virtual keyboard is dismissed on supported platforms at close. Catalog refreshes update visible matches. Missing scenic/technical tags and server freshness timestamps from the reference are not fabricated.

Changed files: new `game/ui/track_search_drawer.gd`, integration in `game/ui/track_browser.gd`, search interaction/capture checks in `game/tests/capture_premium_menus.gd`, this document, status/phase notes and evidence.

Actual commands used the pinned engine via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `CaptureMenus`: final **1351 checks, zero failures**, at 1280x720, 960x540 and 1600x720. Covers initial empty query, live name/creator matches, scope taps, zero results, more results, apply, clear/cancel, backdrop isolation, result selection and row-content bounds, alongside existing Race/filter/transition regressions.
- `TestMenuLoading`: **32 checks, zero failures** after integration.
- `CheckScript -ScriptPath res://ui/track_search_drawer.gd`: passed. Initial shadowed local variable parse error was corrected; the stalled initial test process was stopped and rerun successfully.
- Scoped `git diff --cached --check`: passed.
- Android SDK `adb devices`: empty list. No phone attached, Android export or physical-device test.

Visual iteration corrected empty-draft initialization, duplicate input borders, unsupported desktop keyboard warnings and result-row spacing. Inspected [default drawer](evidence/search-drawer-2026-10-01/search-default-1280x720.png) and [compact name search](evidence/search-drawer-2026-10-01/search-name-960x540.png). Evidence uses disposable gallery fixtures with shared sample route geometry, not actual distinct circuits. Owner visual acceptance and physical-phone keyboard/safe-area/scroll behavior remain outstanding.


## Track-card title containment - 2026-10-01

Requirements R01/V03/V04/Q01. Owner pointed out capitals extending above the solid footer. Compact cards now use 16 px titles instead of 21 px. The title baseline derives from the footer top plus four pixels of padding and actual font ascent. Longer names shrink to a 12 px minimum within the available width; extreme names retain the existing bounded card presentation and full tooltip. Creator attribution moves slightly lower in compact cards to preserve separation. Noncompact cards retain their 21 px starting size and also use footer-relative placement.

Changed files: `game/ui/track_tile.gd`, this document, status/phase notes and evidence. Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: final **1351 checks, zero failures**, at three landscape sizes. Scoped `git diff --cached --check`: passed. Android SDK `adb devices`: empty list; no phone attached, Android export or device test. Inspected [compact cards](evidence/card-title-footer-2026-10-01/tracks-populated-fixture-960x540.png); desktop capture and raw log are in the same directory. Owner visual/device acceptance remains outstanding.


## Creator padding and centered card routes - 2026-10-01

Requirements R01/V03/V04/Q01. Owner requested more space below creator attribution and centered track profiles. Creator baseline is now 12 logical pixels above the card bottom (previously six on compact cards); the compact solid footer increases from 44 to 50 pixels to preserve title/creator separation within the same card dimensions. Both compact and regular route drawing now use symmetric image-area insets, removing the old 30-pixel horizontal offset on compact cards and small vertical offsets.

Changed files: `game/ui/track_tile.gd`, this document, status/phase notes and evidence. Actual `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: **1351 checks, zero failures** at three landscape sizes. Scoped `git diff --cached --check`: passed. Android SDK `adb devices`: empty list; no phone attached, device test or Android export. Inspected [compact cards](evidence/card-centering-2026-10-01/tracks-populated-fixture-960x540.png); desktop evidence and log are alongside it. Owner visual/device acceptance remains outstanding.
