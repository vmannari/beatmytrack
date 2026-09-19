# Premium menus — 2026-09-14

The owner rejected this checkpoint's procedural hero graphics. The later [illustrated menu revision](ILLUSTRATED_MENUS.md) replaces Home/Garage art with an original detailed cel-shaded compact. The layout and gameplay-flow work below remains; its old scenery screenshots are historical.

The owner supplied a nine-screen board and requested a more premium menu feel. This revision covers V02/V03/G03 (art and menu hierarchy), R01 (ordinary five-lap races), R04/R06 (time/PB presentation), and R07 (track discovery). The latest reference's warm yellow primary actions supersede the older white-primary token; the original blueprint files remain unchanged.

## Implemented presentation

Home uses an original roadside scene with the existing fictional compact car on the left and a focused selected-circuit panel on the right. The panel shows the actual surface silhouette, biome, five-lap standing-start format and saved personal target. A first-time player gets a controls hint and first-run objective. Race is the dominant yellow action. Explore and Favorites lead to working library filters.

Home, Garage, Tracks and Create share a bottom navigation dock with original centred vector glyphs. Settings stays in the header. Safe-area margins account for all four edges on mobile. Deep navy surfaces, restrained borders, small corner radii, existing Barlow fonts, gold selection states and clear keyboard focus are shared menu tokens. The editor retains its separate full-screen construction interface.

Garage uses a warm workshop scene and the existing car with actual handling-resource specifications. Menu scenes have separate cameras; their perspective and vehicle framing do not alter the racing camera or canonical car geometry. Static scene rendering runs once and refreshes on resize. Pine, Coast and Desert choose corresponding original scenery.

Tracks has a compact gallery of six route cards, original cartographic terrain illustrations, creator bylines, gold selection and a native selected-track preview. Route lines come from saved metadata; terrain illustrations are not individual track photographs. The full catalog remains bounded/paged, with name/creator search, biome filters, favorites, random choice, import, local edit/delete and remix. Paging is in the top row so all six cards and bylines fit the standard layout. Long unfinished-draft titles now truncate with a tooltip and issue messages wrap, keeping edit/delete actions inside their panel.

Results emphasizes total time, exact PB feedback and measured lap splits. It identifies the standing start and fastest flying lap and shows a bar proportional to each actual lap time. Gameplay HUD is hidden during the debrief and restored on retry. Practice, save-failure and unchanged-PB messages still use the existing integer-millisecond feedback rules. There are no fabricated global rankings, rewards, currencies or purchase panels.

## Changed files

- `game/core/app.gd`: menu shell, Home/Garage/Settings composition, mobile safe margins and result HUD visibility.
- `game/ui/menu_style.gd`, `menu_brand.gd`, `menu_icon.gd`, `menu_backdrop.gd`, `menu_scrim.gd`, `menu_feature.gd`, `circuit_emblem.gd`: shared presentation, original logo composition/vector icons, scene contrast and actual circuit silhouette.
- `game/ui/menu_stage.gd`: original roadside/workshop geometry, lighting and independent menu cameras.
- `game/ui/track_browser.gd`, `track_tile.gd`, `race_results.gd`: discovery cards, selected-track panel and debrief.
- `game/tests/capture_premium_menus.gd`, `scripts/dev.ps1`: isolated graphical capture entry point and action/navigation/HUD checks.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and `licenses/ASSETS.md`: reference override, status, evidence and original-asset provenance.

## Actual commands and outcomes

All Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` with the pinned `4.7.2.stable.official.ed1daf0bf` engine.

- `Import`: passed. Android build-tools warning reflects the missing device toolchain.
- `CheckScript -ScriptPath res://core/app.gd`, plus individual menu stage, library and capture script checks: an initial nonexistent environment enum caused a dependency parse failure; it was corrected. Subsequent scene execution and capture passed.
- `TestApp`: 84 checks, zero failures, including existing editor gestures, save flow, library selection and race/PB round trips.
- `TestMenus`: 11 checks, zero failures, including exact feedback, millisecond ties/carry, practice and failed-save cases.
- `TestRecords`: 53 checks, zero failures.
- `TestCatalog`: 18 checks, zero failures, including 5,000-entry query behavior and six-card construction bound.
- `CaptureMenus`: final 250 checks, zero failures; 18 actual Windows captures at 1280×720, 960×540 and 1600×720. Viewport-dispatched navigation taps, fixed action bounds and retry restoring the HUD/fresh session passed. Initial captures found Garage navigation below the viewport (12 failures across sizes), overlapping scrim bands and the visible gameplay HUD behind results; all were corrected and recaptured. Gallery paging moved to the header after visual review found clipped second-row creator text.
- `Doctor`: failed because matching Android export templates, configured SDK/ADB/build-tools and JDK are absent. Device attachment could not be enumerated. No APK export or physical-phone test was performed.

The first broad `Validate` run in the shared workspace passed import, script parsing and startup, then stopped at one of 56 driving checks: `brake wins simultaneous pedals at rest; no stationary rotation`. Separate handling/simulation changes appeared during this task and are outside the menu checkpoint. No handling invariant was changed to satisfy menu validation. The menu-only checkpoint is isolated from those edits under `build/premium-menu-checkpoint` on branch `menu/premium-20260914`, based on `88435bf`.

The isolated checkpoint's `Validate` passed import, all 86 script parses, startup, 56 driving checks, 163 native-track checks, 27 extra-track checks and 86 creator checks. It then stopped in `test_editor_v2.gd:172`, which calls the removed `_preview_document` app method. That call and missing method are already present in base `88435bf`; the earlier editor UI removed the preview. The wrapper correctly rejects the script error even though the partially run test prints 35 checks/zero failures. Full validation is therefore **not green**, and the remaining suites are not reported as passed by that command.

Separate final commands in the isolated checkpoint passed `TestApp` (84), `TestMenus` (11), `TestRecords` (53), `TestCatalog` (18), `TestDeleteTracks` (19), `TestWorkflow` (94) and `CaptureMenus` (250). Screenshots were regenerated from this menu-only checkpoint after the final changes. Existing editor-preview and concurrent handling failures were retained, not weakened or bundled into this UI change. `git diff --check` passed for the menu checkpoint.

## Actual screenshot evidence

[Home](evidence/premium-menus/home-first-1280x720.png) · [Returning player](evidence/premium-menus/home-returning-fixture-1280x720.png) · [Garage](evidence/premium-menus/garage-1280x720.png) · [Tracks](evidence/premium-menus/tracks-1280x720.png) · [Settings](evidence/premium-menus/settings-1280x720.png) · [Results](evidence/premium-menus/results-fixture-1280x720.png).

[Compact Home](evidence/premium-menus/home-first-960x540.png) · [Compact Tracks](evidence/premium-menus/tracks-960x540.png) · [Wide Home](evidence/premium-menus/home-first-1600x720.png) · [Capture manifest](evidence/premium-menus/manifest.json) · [Actual capture log](evidence/premium-menus/capture-log.txt).

Results and returning-player captures use a controlled completed-session fixture: 108.816 seconds against a 109.000-second previous best. These are presentation fixtures, not claimed driven records. Persistence is redirected to disposable test directories before app startup. Compact 960×540 output retains the project's 1280×720 logical canvas; it is not proof of phone readability or touch acceptance.

## Remaining acceptance and limits

The menus adopt the reference's composition and control language. The existing car and procedural environment remain prototype assets and do not match the reference's detailed vehicle/environment fidelity. No reference image, commercial vehicle identity, new raster art, external dependency or runtime service was added. Coast/Desert menu branches received code review but no individual screenshots in this task.

Owner visual acceptance, actual phone safe areas/reach/readability, human race/retry flow and phone frame pacing/thermal performance remain open. Global standings, leagues, progression, upgrades and commerce remain deferred. Creator practice stays untimed; ordinary menu races stay five laps. There is no menu-only schema, rules or physics version change.
