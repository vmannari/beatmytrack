# Required biome selection ? 2026-09-18

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
