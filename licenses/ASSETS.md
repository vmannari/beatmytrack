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
