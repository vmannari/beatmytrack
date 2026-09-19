# Reference-led discovery menu ? 2026-09-18

Requirements: R01, V02?V05, G03, R04/R06/R07 presentation. The owner's new menu reference supersedes the bottom navigation presentation. No physics, rules, gameplay camera, online, progression or commerce changes.

## Implemented

Shared top navigation (Home, Play/library, Create, Garage, settings), stacked original type logo, charcoal/navy surfaces, warm yellow actions, original workshop background and six-card horizontal track gallery. Actual saved route geometry overlays biome illustrations. Search, sorting, biome filtering, favorites, paging, random selection, import, native selected-track preview, five-lap racing, personal best, edit and delete remain functional. The lower selected-track strip keeps the race action visible. Cards are bounded to six per page, with horizontal scrolling when necessary.

Artwork is illustrative biome scenery, not a literal rendering of each circuit. The actual circuit preview remains in the selection strip. A fresh isolated install contains one starter circuit; the populated screenshots explicitly use unsaved metadata fixtures, all sharing the starter outline. No imaginary friends, ratings, currency, history, or records are presented in the runtime catalog. Friend rematches, trending and recent-play history from the reference are outside this presentation slice.

## Changed files

- `game/core/app.gd`: shared top navigation.
- `game/ui/menu_brand.gd`, `menu_style.gd`, `menu_backdrop.gd`: brand, palette and illustrated workshop.
- `game/ui/track_browser.gd`, `track_tile.gd`: horizontal discovery gallery, route cards and selection strip.
- `game/assets/menu/discovery-biomes.png`, `discovery-workshop.png` and import descriptors: original generated art.
- `game/tests/capture_premium_menus.gd`: populated metadata-only gallery capture and paging checks.
- This document, generation prompt record, asset provenance, AGENTS/status/phase notes and screenshot evidence.

## Actual verification

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` and pinned Godot 4.7.2.stable.official.ed1daf0bf.

- `Import`: passed twice; missing Android build-tools warning.
- `TestCatalog`: 18 checks, zero failures; includes a 5,000-entry catalog and bounded paging.
- `TestMenus`: 11 checks, zero failures.
- `TestDeleteTracks`: 19 checks, zero failures.
- `CaptureMenus`: final 331 checks, zero failures. 21 graphical screenshots at 1280?720, 960?540 and 1600?720, including viewport-dispatched navigation, action bounds, results/retry and populated paging. Earlier 259-check capture preceded populated fixtures; intermediate and final populated runs passed 331.
- `TestApp` and `CaptureApp`: both stalled before APP_READY with no test result; their specifically identified test processes were stopped. These are not passes, and their cause remains unresolved. The owner's already-running Godot process was left untouched.
- `Doctor`: failed due to missing matching Android templates, configured SDK/ADB/build-tools and JDK. Device attachment could not be enumerated. No APK export or phone test performed.
- Scoped `git diff --check`: passed, only CRLF normalization notices.

[Fresh library](evidence/discovery-menu/tracks-1280x720.png) ? [Populated fixture](evidence/discovery-menu/tracks-populated-fixture-1280x720.png) ? [Compact fixture](evidence/discovery-menu/tracks-populated-fixture-960x540.png) ? [Home](evidence/discovery-menu/home-first-1280x720.png) ? [Manifest](evidence/discovery-menu/manifest.json).

Owner visual acceptance, physical phone safe areas/readability/reach, human search/select/edit/race flow and device performance remain pending. Compact screenshots retain the logical 1280?720 canvas and do not prove phone readability. The fixture manifest's result examples are synthetic completed-session data, not claimed driven records.

The workspace contains substantial pre-existing edits. A separate presentation-only Git checkpoint under `build/discovery-checkpoint` records the before/after source files without committing unrelated owner work. It is a review checkpoint, not a standalone runnable game.

## Dedicated Storm artwork - 2026-09-19

Owner request, V02/V03/V05: Storm cards previously fell back to the sunny Grass atlas quadrant. Added original 1024x1536 rainy valley illustration with lightning and wet ground, selected explicitly for Storm while retaining the saved-route overlay and card labels. The generated asset was visually inspected. No gameplay or camera changes.

Changed: `game/assets/menu/discovery-storm.png` and import metadata, `game/ui/track_tile.gd`, `game/tests/capture_premium_menus.gd`, `docs/STORM_MENU_PROMPT.md`, license provenance, status/phase notes and evidence. Imagegen skill with built-in image_gen; [final prompt](STORM_MENU_PROMPT.md). The gallery fixture now cycles all five biomes and captures the Storm page separately. Fixtures are metadata-only and do not alter owner tracks.

Actual pinned-wrapper commands: `Import` passed; initial `CaptureMenus` passed 331 checks, then final capture with Storm-page evidence passed 397 checks, zero failures across three sizes. [1280x720 Storm gallery](evidence/storm-menu/tracks-1280x720.png), [compact](evidence/storm-menu/tracks-960x540.png), [wide](evidence/storm-menu/tracks-1600x720.png). Targeted `git diff --check` passed. No new Android export/deployment or phone visual test for this artwork; owner visual approval pending. No combined commit in the mixed workspace.
