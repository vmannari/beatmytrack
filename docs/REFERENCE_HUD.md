# Reference HUD and bridge style

Owner reference and follow-ups, 2026-09-15. Requirements **V02/V03/V04/V05/G01/R01/R07**: shaped illustrated HUD, no camera button, blue steel/concrete bridges, and a minimap sourced exclusively from placed roads on new creator tracks.

## Result

- Shaped, rounded instrument panels with ink borders; lap fraction in warm yellow, separate track title, stopwatch timer, pause/resume glyph and race menu. Restart and Tracks are in the functional menu; Handling remains visible.
- The minimap always uses `RoadPieces.section_outline` for placed road pieces, including curves, width transitions and bridges. Its bounds also come only from those outlines. Moving race waypoints or painting surfaces cannot change it. Roads without waypoints are included. There is no waypoint, painted-surface or converted-track fallback; tracks without placed pieces use a compact lap/title card.
- The player marker follows actual vehicle position, clamped to the map bounds when off course. Road strips render as small triangles to avoid failure when long outlines shrink to minimap scale.
- Raised steering buttons and grooved brake/throttle pedals retain the existing touch zones, sizing and handedness. Speed drives both the numerical display and instrument segments. RPM is not simulated and no fictional RPM readout was added.
- Creator bridges use blue folded steel rails, concrete uprights and warm concrete deck edges. Native bridges share those materials and add uprights within existing rail cells. Bridge presentation version is `bridge-ramps-3`. New uprights remain inside solid rail footprints; no new underpass obstacles or handling changes.
- Practice retains its untimed controls, Restart, Edit here and handling selector. No camera button is present.

## Changed files

- `game/ui/hud_frame.gd`, `hud_glyph.gd`, `hud_road_map.gd`: original scalable drawings and placed-road minimap.
- `game/ui/playground_hud.gd`, `race_hud_style.gd`, `touch_controls.gd`: layout, styling, menu actions and touch faces.
- `game/core/game.gd`: minimap track binding and split lap caption/value only in this checkpoint.
- `game/track/creator_bridge_visual.gd`, `bridge_presentation.gd`: rail/post/fascia presentation.
- `game/tests/test_bridge_hud.gd`: placed-road independence, paint exclusion, no fallback, extra placed roads, menu actions, layout and existing bridge tests.
- Development status, phase plan, this document and screenshots.

All drawings and mesh details are original code. Existing licensed Barlow fonts are reused. The supplied picture is reference material, not a shipping asset. Separate local menu, suspension and race-start edits were preserved and excluded from this checkpoint.

## Actual commands and results

Commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot **4.7.2.stable.official.ed1daf0bf**.

| Action | Result |
|---|---|
| `Import` | Passed. Environment still reports missing Android build-tools. |
| `TestBridgeHUD` | 88 checks, zero failures. Includes unchanged minimap after waypoint edits/paint, placed roads beyond the lap route, no empty-piece fallback, actual menu restart/exit and compact/wide layout. |
| `CaptureBridgeHUD` | Final run: 92 checks, zero failures, four screenshots saved with no rendering errors. |
| `TestDriving` | 70 checks, zero failures. |
| `TestPractice` | 33 checks, zero failures; six actual untimed laps. Includes separate local race-start checks in the shared working tree. |
| `TestConstruction` | 73 checks, zero failures; five bridge laps with zero contacts and upper/lower traversal. |
| `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` | Final run passed; owner Curvy read-only capture, all route/model images, unchanged native cells and flat-road normal audit. |

**264 focused headless checks pass**. Exit-time ObjectDB warnings remain (four in Driving; two in BridgeHUD, Practice and Construction). Full Validate, Android export and device tests were not performed for this presentation slice.

## Screenshots and acceptance

- [Owner Curvy: placed-road minimap, HUD and bridge](evidence/reference-hud/curvy-bridge.png)
- [Creator bridge and racing controls](evidence/reference-hud/creator-race.png)
- [Legacy track: compact card without minimap](evidence/reference-hud/native-compact.png)
- [Widescreen practice](evidence/reference-hud/practice-wide.png) and [paused practice](evidence/reference-hud/practice-paused.png)

Screenshots are desktop engine captures through the normal gameplay camera. No phone test was performed. Owner art acceptance, phone readability, physical touch feel, cutouts and mobile rendering cost remain to be checked. Native raster bridge silhouettes retain their existing cell geometry.
