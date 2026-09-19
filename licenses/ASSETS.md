# Asset provenance

Illustrated compact menu art (2026-09-14): `game/assets/menu/compact_illustration_v1.png`, 1672×941 PNG, SHA-256 `BBDBA87BF42B41EFAFF8EC2E98D355125590AEA04EC343C1A330522D1DBDD8B0`. Generated with built-in image_gen from the exact prompt in `docs/ILLUSTRATED_MENU_PROMPT.md`; copied unmodified into the game. Original fictional compact illustration, using the owner image as style guidance; no source-reference crop or real vehicle name/logo is imported. Lossless/mipmapped import. This menu-only 2D artwork is distinct from the existing gameplay mesh. Owner visual acceptance remains open.

Handling audio (2026-09-14): `game/vehicle/tire_audio.gd` synthesizes an original filtered-noise/harmonic tyre-scrub loop in memory. No third-party recording, downloaded asset, AI audio service or external dependency is used. Presentation-only prototype pending human listening and phone acceptance.

Premium menus (2026-09-14): `game/ui/menu_stage.gd` contains original procedural roadside pine/lake, coast, desert and workshop scenery with an independent menu camera. It reuses the existing fictional `CarVisual`; no reference vehicle, photo, generated poster or third-party asset is imported. `menu_brand.gd` and `menu_icon.gd` provide original typography composition, racing strokes and vector navigation glyphs using the existing OFL Barlow fonts. `track_tile.gd` draws original cartographic terrain washes behind the saved circuit geometry; these are route illustrations, not photographs of individual tracks. Scenery and vehicle detail remain prototype art pending owner acceptance.

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


## Original car roster, 2026-09-15

New `game/vehicle/vehicle_models.gd` contains original authored pickup, classic sports and Formula geometry using the existing matte toon/ink kit. Fictional identities; no manufacturer meshes or badges.

Menu illustrations below were generated with the built-in image_gen tool using the existing original compact illustration as style reference; no supplied branded reference ships. Each is a 1672?941 PNG with project-local storage and mipmaps. Exact prompts: `docs/CAR_ART_PROMPTS.md`. Generated artwork is for the local slice; owner/shipping asset acceptance remains open.

| Asset under `game/assets/menu/` | SHA-256 |
|---|---|
| pickup_illustration_v1.png | D515AA67A37BFFC6BAB47B103CEFE5A019C35E00DDAB4F0C8176D49E1FE629B8 |
| classic_illustration_v1.png | D68A6E45051F76516558DA71E3E9C4E3431F638F78CF869DD5E4C890BD0AFDEC |
| formula_illustration_v1.png | 13C6F22BBBA62CF62AB75BB46E189B3C2C38CD67C68299505B5A029BB77AFB78 |

## Original go-kart, 2026-09-16

`game/vehicle/vehicle_models.gd` adds original authored kart and seated driver geometry using the existing matte toon/ink kit. Fictional identity; no external meshes or manufacturer branding.

`game/assets/menu/kart_illustration_v1.png` is an original 1672x941 PNG generated by the built-in image_gen tool using existing original Formula artwork as style reference. Native-size mipmapped project-local import. SHA-256 `98F5849E234B88F95028F3450EE8186708E0C6268DB2CF8026E33403421ED1D6`. Exact prompt: `docs/KART_ART_PROMPT.md`. No supplied branded image ships; generated art remains subject to owner/shipping review.

## 2026-09-17 catalog retirement

The 194 converted Slicks circuits are no longer runtime assets. Their unchanged regression fixtures are under `game/tests/fixtures/legacy_tracks/`, excluded from exports by `tests/*`. Original provenance is retained in that directory's catalog.json; source archives remain outside the game export root. `game/resources/tracks/starter_circuit.json` is an original circuit generated from the project's existing TrackDocument default layout by `game/tests/generate_starter.gd`, using the existing cleared track kit; no external track geometry was used.

## Biome picker icons (2026-09-18)

`game/assets/editor/biome_pine.svg`, `biome_coast.svg`, and `biome_desert.svg`: original project-authored SVG landscape icons created by Codex for the required biome picker. No external images or copied references. Editable vector sources ship with the game.

## Object model refinement (2026-09-18)
Original code-authored geometry in creator_prop_visual.gd and native_track_visual.gd, with shared in-engine creator thumbnails. No third-party model, image, texture or vehicle identity imported. Fictional parked utility vehicles. See docs/OBJECT_MODELS.md for scope and evidence.

2026-09-18: `game/assets/editor/biome_night_city.svg` and `biome_winter.svg` are original project-authored editable vector illustrations (winter derived from the project pine card), with no third-party/reference assets.


## Discovery menu art ? 2026-09-18
`game/assets/menu/discovery-biomes.png` and `discovery-workshop.png` are original built-in imagegen outputs created for this project. The supplied menu board is a style reference only and is not shipped. The biome texture is illustrative scenery; actual route lines and all UI are drawn in Godot. No logos, real vehicle identities or third-party photographs are included in these two images. Prompts: `docs/DISCOVERY_MENU_PROMPTS.md`. Generated art still needs owner shipping review.

2026-09-19 Storm: `game/assets/editor/biome_storm.svg` is original editable vector artwork derived from the project pine card. `game/assets/audio/storm_rain.wav` and `storm_thunder.wav` are original synthesized audio, reproducibly generated by `scripts/generate_storm_audio.py` using Python standard-library math/noise. No third-party source assets or runtime dependencies.

2026-09-19: `game/track/storm_lens.gdshader` is original project-authored procedural lens refraction code. Owner-linked Reddit post is a directional reference only; no third-party shader/media ships.

2026-09-19: `game/track/storm_wet_glass.gdshader` adapts the layered procedural bead/hash/refraction approach in the owner-supplied shader attachment (2381afe3-faca-46be-ab17-8031a0e5b942/pasted-text.txt), with project-authored occupancy, rivulets, pause-aware clock integration and lighting. Supplied mockup is a visual reference only and is not shipped. No external media or packages imported.

2026-09-19: `game/assets/menu/discovery-storm.png` is original built-in image_gen artwork for Storm menu track cards. No third-party reference assets supplied or shipped. Prompt and generation record: `docs/STORM_MENU_PROMPT.md`.
