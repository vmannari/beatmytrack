# Required biome selection ? 2026-09-18

## Consistent selected-card treatment - 2026-09-24

Requirements R01/V03/V05. Biome selection no longer depends on how a thin highlight reads against each scenic image. Every unselected image now receives the same subdued tint, while the selected image stays full brightness and gains a solid yellow label band with dark icon and text. The yellow outer selection frame was removed by owner follow-up; every card retains the same neutral 1 px edge. The treatment is identical for Grass, Desert, Night City, Winter and Storm. Biome label bands have square corners.

Changed `game/core/app.gd`, `game/tests/test_biomes.gd`, this document, status/phase notes and the refreshed picker evidence. Actual command `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes` used pinned Godot 4.7.2 and passed 107 checks with zero failures. The refreshed desktop [picker](evidence/biomes/picker.png) was visually inspected; the selected state remains distinct from Storm and the other dark artwork. No phone test or Android export was performed; physical-device readability/touch acceptance remains.

## Reference menu icon match - 2026-09-23

R01/V03/V05: owner's clarification targets only the small biome symbols in the supplied Create reference. Revised the existing vector artwork to its curved folded leaf, narrow rounded cactus, crescent with scalloped clouds and small sparkle stars, delicate six-arm snowflake, and rounded rain cloud with the requested added lightning bolt. Card and summary symbols share the reference's pale blue, with an off-white Night symbol. These are vector recreations rather than screenshot crops. Scenic art and heading remain as accepted.

Changed `game/ui/menu_icon.gd`, `game/core/app.gd`, this document, status/phase notes and existing icon/menu PNG evidence. Actual command `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes`: 92 checks passed, zero failures. Inspected enlarged symbols and the refreshed [picker](evidence/biomes/picker.png). No phone test or export performed; owner visual acceptance remains.

## Filled biome glyph replacement - 2026-09-23

Requirements R01/V03/V05. Replaced the rejected line glyphs with original filled SVG silhouettes: a leaf with one tapered open vein, a cactus with solid rounded arms, a crescent with separated cloud and stars informed by the owner's reference, a sixfold symmetric snowflake and a cloud with lightning and rain. Night reference is composition guidance only; no reference pixels or watermark are shipped. Biome glyphs use a 64-unit design grid rasterized at 112 pixels with mipmaps for the 30/34-pixel UI sizes. Removed obsolete glyph definitions.

Changed files: `game/ui/menu_icon.gd`, capture support in `game/tests/test_biomes.gd`, status/phase notes, this document and `docs/evidence/biomes/` captures. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes`: 92 checks, zero failures after final refinement. Inspected all five enlarged icon PNGs and the [menu capture](evidence/biomes/picker.png). Enlarged evidence: `icon-leaf.png`, `icon-cactus.png`, `icon-night.png`, `icon-snowflake.png`, `icon-storm.png` in that folder. No phone test or export; attachment not checked. Owner visual acceptance and phone rendering remain outstanding.

## Selection details, icons and explicit creation - 2026-09-23

Requirements R01/T01-T04/V03/V05. The five scenic biome cards now select rather than immediately opening the editor. Each card has an original shared vector glyph and the selected card receives a yellow border. A full-width bottom card repeats the selected biome icon/name, provides biome-specific building and driving context, and exposes the explicit yellow **Create track** action. The upper-right **Load track** folder action opens the established Saved tracks library. The existing thin artwork strip below each card label remains.

Changed files: `game/core/app.gd`, `game/ui/menu_icon.gd`, `game/tests/test_biomes.gd`, this document, development status, phase plan and refreshed picker evidence. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes` with pinned Godot 4.7.2. The first run stopped on a duplicate test-variable parse error; the fixture variable was renamed and the final run passed 87 checks with zero failures. The refreshed 1280x720 [picker capture](evidence/biomes/picker.png) was visually inspected. No phone test or Android export was performed; phone attachment was not checked. Remaining acceptance is owner review and physical-phone layout/touch validation.

Follow-up: all five biome glyphs were redrawn with cleaner silhouettes and balanced 24x24 geometry, including a symmetrical branched Winter snowflake. The page heading is now **Select biome**. A repeated `CaptureBiomes` run passed 92 checks with zero failures; the refreshed desktop capture was inspected at rendered card size.

## Track-gallery artwork and overlaid labels - 2026-09-22

Requirements R01/V03/V05. The Create biome picker now uses the same `discovery-biomes.png` and `discovery-storm.png` scenic artwork as the Tracks gallery. Biome names are overlaid near the bottom of each image, leaving a thin strip of uninterrupted artwork visible below the label row. The explanatory "Choice is permanent" sentence has been removed. Selection behavior and biome immutability are unchanged.

Changed files: `game/core/app.gd`, `game/ui/track_tile.gd`, `game/tests/test_biomes.gd`, this document, development status, phase plan and the refreshed picker evidence. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes` passed all 62 checks using pinned Godot 4.7.2. The refreshed 1280x720 [picker capture](evidence/biomes/picker.png) was visually inspected: all five crops fill their cards and every lower overlaid label is readable with artwork visible beneath it. No phone test or Android export was performed; phone attachment was not checked. Owner phone/touch acceptance remains.

Requirements: R01/T01?T04/V03/V05; owner request dated 2026-09-18.

Create navigation and editor New now allocate a fresh blank document and open a required three-card biome selection screen. Selecting Pine forest, Coast or Desert enters the editor. No road pieces, painted surfaces, objects, base track or road layout are inherited. The existing internal route scaffold remains until automatic road-route generation; it is not authored road geometry. Load and Edit still open existing documents, and returning from practice preserves the current track.

The editor biome control is removed. Selection happens before editing history begins, and generic metadata changes reject theme/biome updates. Existing tracks retain their stored theme. No schema or physics contract changes and no player files deleted.

Nature availability: pine trees and fallen logs are forest-only; broadleaf trees, bushes, grass clumps and flowers are forest/coast. Pebbles, rocks and outcrops remain available everywhere, as does racing equipment. Existing placed objects in loaded tracks are retained. Desert starts with Rock selected; Coast with Broadleaf. No new object models were added.

Changed files: `game/core/app.gd`, `game/editor/creator_catalog.gd`, three `game/assets/editor/biome_*.svg` files and import metadata, `game/tests/test_biomes.gd`, `game/tests/test_object_browser.gd`, `scripts/dev.ps1`, this document, development/phase status and asset provenance. SVG illustrations are original editable vector artwork authored for this task, without external/reference assets.

Actual commands (PowerShell with `-NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):
- `Import`: passed with pinned Godot 4.7.2; engine reports Android build-tools directory unavailable.
- `TestBiomes`: 27 checks, zero failures.
- `CaptureBiomes`: same 27 checks, zero failures; desktop 1280?720 captures saved and visually inspected.
- `TestObjects`: 60 checks, zero failures; superseded mutable-biome dialog assertion replaced with absence of editor biome control.

Evidence: [biome picker](evidence/biomes/picker.png), [empty desert and filtered palette](evidence/biomes/desert-editor.png).

Remaining acceptance: owner review of icon style and biome object distribution; real phone touch/layout validation. No device test or Android export performed. Device attachment was not checked. Workspace already contains extensive uncommitted changes from earlier work; no combined Git commit was made.

## Four-biome revision ? 2026-09-18

Requirements R01/T01-T04/V02/V03/V04/V05; owner request: retain grass/desert, retire coast, add night city/winter using street lamps as the main night light source.

The selectable catalog and library filters now offer Grass (existing internal `pine` identity), Desert, Night city and Winter. New SVG cards are original editable project artwork. Existing coast documents are accepted without deleting or rewriting player files; they render and filter as Grass. Coast is not offered for new tracks.

Night city has cool neutral ground, subdued blue ambient/moon lighting and warm real OmniLight3D illumination at placed light poles. Emissive lamp lenses remain visible. Lights rebuild with editor object edits and exist in races; day biomes do not create lamp lights. Lamps use finite 15 m range at normal scale and no local shadows. Users place lamps and buildings using the existing objects palette; no city is automatically populated. Winter uses cool snow ground, snow-tinted pines/rocks and cooler daylight. Existing physical surface IDs and grip remain unchanged: this does not introduce ice physics. Visual kit 30.

Changed files: `game/track/track_theme.gd`, `native_track_visual.gd`, `surface_detail.gdshaderinc`; `game/core/app.gd`, `game.gd`; `game/editor/track_document.gd`, `creator_catalog.gd`, `editor_world.gd`; `game/ui/track_browser.gd`, `track_catalog.gd`; two new `game/assets/editor/biome_{night_city,winter}.svg` illustrations and imports; `game/tests/test_biomes.gd`; creator-v5 and builtin-catalog JSON schemas; development/phase status and asset provenance.

Actual commands using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `Import`: passed, pinned Godot 4.7.2; reports missing Android build-tools directory.
- `TestBiomes`: initial 36 checks passed; final expanded 41 checks passed.
- `CaptureBiomes`: final 41 checks passed. Initial light test incorrectly matched automatically renamed node names; corrected to count actual OmniLight3D nodes. Initial race screenshots were obscured by the test app UI; corrected fixture removes that UI before capturing.
- `TestObjects`: 60 checks passed.
- `TestCreator`: 99 checks passed, including deterministic races for all four biomes.
- `TestCatalog`: 18 checks passed.
- `git diff --check`: reported existing trailing blank lines in development/phase/provenance documents; cleaned those files while updating them.

Desktop captures inspected: [picker](evidence/biomes/picker.png), [night lamps](evidence/biomes/night_city-race.png), [winter](evidence/biomes/winter-race.png). Capture fixtures include placed lamps; new documents still start empty.

Remaining acceptance: owner visual review, phone brightness/readability, touch layout and many-lamp renderer/performance limits (especially Compatibility light limits on large batched meshes). No device test or Android export performed; attachment was not checked. No combined Git commit made because the workspace contains extensive pre-existing uncommitted work.

## Darker night follow-up - 2026-09-18

Owner requested darker areas beyond the lamps. Requirements V02/V04/V05. In `game/track/track_theme.gd`, night ambient energy drops from 0.22 to 0.045 and directional moonlight from 0.16 to 0.025, shared by editor and racing. Street-lamp energy/range and daytime lighting retain their previous values.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureBiomes` using pinned Godot 4.7.2: 41 checks passed, zero failures. Updated [night capture](evidence/biomes/night_city-race.png) visually inspected: dark unlit areas with warm illuminated pools. Changed files: shared theme, refreshed biome evidence, this document and development/phase status. No phone test or Android export performed; attachment not checked. Owner brightness/readability acceptance remains pending. Existing mixed workspace changes remain uncommitted.

The later owner request for physical winter ice supersedes cosmetic-only winter handling above: see [winter ice](WINTER_ICE.md).
