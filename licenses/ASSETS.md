# Asset provenance

| Asset | Origin | Use |
|---|---|---|
| Bootstrap scene/layout/text | Original project work, 2026-09-11 | Development startup screen |
| Procedural compact car | Original `game/vehicle/car_visual.gd`, 2026-09-11 | Fictional 4.25 × 1.8 m handling stand-in; no brand or reference mesh |
| Handling yard, cones, circles and barriers | Original `game/track/playground_visual.gd`, 2026-09-11 | Procedural test geometry; no external assets |
| Matte toon materials and pooled skid marks | Original project code using Godot built-ins | Handling presentation baseline |
| Default UI font | Bundled Godot font | Engine-bundled asset; include relevant engine third-party notices when distributing |
| Blueprint PNGs, PDF/DOCX/XLSX and HTML crops | Owner-supplied specification, preserved unchanged | Design review only; outside `game/`, never exported |
| Four native Slicks-derived layouts | Owner-supplied `slicks_codex_handoff.zip`, converted from FREEWAY/1WAY/66/OFFROAD `.SS` and DAT geometry masks | Internal handling fixtures only; source and output SHA-256 in `scripts/slicks/golden.json`; no original textures/sprites in runtime |
| Slicks parser and corrected resource decoder | Supplied handoff's `tools/`, copied unchanged to `scripts/slicks/` | Development tooling outside export root; no upstream license was supplied and none is inferred |
| Native track converter, meshes, surface materials and debug views | Original project implementation around supplied layout data | Flat project materials and geometric collision stand-ins; no imported vehicle identity or graphic assets |

The original ZIP, DAT, SS files and corrected reference renders remain under ignored `build/slicks_handoff/`, outside the export root. Source track author/top-ten player records are not copied into native maps. Derived layouts are test adaptations, not licensed production content; shipping/distribution clearance remains unverified.

No finished production car/environment, external shader, audio or purchased asset has been introduced. Reference-board branded vehicles are not licensed game assets.

Godot is MIT licensed. Before distributing an exported build, include the pinned engine's MIT text and applicable third-party notices. Use the engine distribution or [official license page](https://godotengine.org/license/) for the exact notices. No license is assigned here to owner-provided reference material or to the project's source code on the owner's behalf.

Track-kit-2 (2026-09-12): terrain coverage shader, matte palette, curb/checkered finish paint, exposed barrier meshes and low grass/gravel geometry are original project code. Coverage textures are generated from native material IDs at load time, not imported legacy artwork. Source layouts retain the internal-test provenance above.

Track-kit-3 (2026-09-12): Pine country, Coastal heath and Desert mesa palettes; faceted scrub, narrow pines and low stone clusters; broad terrain tonal planes, shoreline contours and batched finish paint are original code in `game/track/track_theme.gd`, `native_track_visual.gd` and `terrain.gdshader`. Creator previews share the same allowlisted surface palettes. No image generation, imported bitmap, new dependency or external art was used. Scenery is presentation-only and does not add collisions; road/deck clearance keeps it away from driving lines. Native Slicks layout provenance is unchanged.

Menu presentation (2026-09-12): pit bay, floor markings, equipment and lighting are original procedural geometry in `game/ui/menu_stage.gd`; the existing fictional car is reused. No commercial game images or generated posters are runtime assets.

Barlow Regular and Barlow Condensed SemiBold are bundled static menu fonts, Copyright 2017 The Barlow Project Authors, under SIL Open Font License 1.1. The complete license is included at `game/assets/fonts/OFL.txt`. Sources: [Barlow Regular](https://github.com/google/fonts/blob/main/ofl/barlow/Barlow-Regular.ttf), [Barlow Condensed SemiBold](https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-SemiBold.ttf), [license](https://github.com/google/fonts/blob/main/ofl/barlowcondensed/OFL.txt). Downloaded 2026-09-12, unmodified. SHA-256: Regular `95AA02C7C43096E0DD44D787BA6216864A67157E402ADAB59B35572E0C1577EA`; Condensed SemiBold `7B619D14BC2327509A9EF32B0890F709626F7ECC9FF61191C2A4314C5499D2D9`; OFL `186D750EB496A4C17A76385F82BE6AEA2AC1CF2DE074A811D63786CF374EA73F`. The engine default font remains available for non-menu UI.

Track-kit-5 (2026-09-14): world-space pigment/asphalt shaders, inverted-hull contours, revised procedural pine tiers, ivory car palette and drawn driving-control icons are original project code. Owner example is design reference only, not imported or generated runtime imagery. Existing source-layout and font provenance remains unchanged.

Track-kit-6 (2026-09-14): revised branch masses, sparse grass strokes, gravel shoulder shader and inside-bend kerb meshes are original procedural project code. Silmukka review capture uses the local owner-authored track without copying its saved document.

Painted grass v1 (2026-09-14): generated with the built-in image_gen tool from the original written prompt in `docs/PAINTED_GRASS_PROMPT.md`. Saved as `game/assets/textures/painted_grass_v1.png`, SHA-256 `0B7E9991DCCEA8CA5BB420CDAA9F489AF847AFAC78FACE20FCC65EC0AD1D72D8`. Owner board is design reference only; no board crop shipped. Original 1254-square PNG preserved; Godot import produces 1024-square mipmapped runtime texture. Prototype asset pending visual/performance acceptance.
