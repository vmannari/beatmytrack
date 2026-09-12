# Shared track themes — 2026-09-12

Owner-authorized menu/creator slice after handling acceptance. Requirements: V02 (coherent matte art), V04 (bounded original asset kit), R03 (shared native track geometry), and the latest request for several phone-editor base themes. Camera calibration remains a separate acceptance check.

`TrackTheme` provides allowlisted `pine`, `coast` and `desert` palettes, named Pine country, Coastal heath and Desert mesa. The editor's surface preview and native track rendering use the same eight surface IDs. Unknown presentation theme IDs fall back to pine; the editor document separately validates authored IDs. Materials change appearance without changing grip, road width, native barriers, bridge profiles or timing data.

Track-kit-3 replaces dotted low cover with original faceted shrub/stone clusters and sparse narrow pines. A 1.3 m grass/soft-cover envelope keeps low props off roads and decks; pines require a 4.4 m envelope, beyond the canopy and projected height at the current follow-camera pitch. Vegetation remains passable under the accepted surface rules. Props never create simulation collision. Terrain has restrained broad tonal planes, narrow surface contours and quiet water bands. The ground sheet no longer casts a rectangular shadow at the native map border.

Scenery uses one baked mesh with vertex colors, capped at 180 clusters (at most 11,340 prop triangles). Finish paint uses two meshes instead of one node per square. The three FREEWAY presentation probes each produced seven visual child meshes and 61 scenery clusters. These counts exclude the car, world light and UI, and are not a measured phone performance budget.

Changed files:

- `game/track/track_theme.gd` and generated `.uid`: shared themes and colors.
- `game/track/native_track_visual.gd`: palette selection, clearances, original prop shapes, mesh batching and map-border shadow removal.
- `game/track/terrain.gdshader`: restrained contour/tonal treatment, curb paint and water bands.
- `game/track/bridge_presentation.gd`: deck and rail materials read the theme palette; bridge geometry/profile unchanged.
- `licenses/ASSETS.md`: original art provenance.
- `docs/evidence/track-kit3-pine.png`, `track-kit3-coast.png`, `track-kit3-desert.png`: inspected actual Windows renders, matching camera/car/native geometry.
- `docs/evidence/track-kit3-bridge.png`: inspected 1WAY bridge material integration (race HUD before the menu slice integration).

Actual validation used `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`, matching `godot-version.txt`:

| Command | Actual outcome |
|---|---|
| `--headless --path game --check-only --script res://track/native_track_visual.gd` | Exit 0; no parse errors |
| `--headless --path game --check-only --script res://track/track_theme.gd` | Exit 0; no parse errors |
| `--headless --path game --check-only --script res://track/bridge_presentation.gd` | Exit 0; no parse errors |
| `--path game res://core/game.tscn -- --track=slicks_freeway_test --capture=.../build/theme-pine.png` | Exit 0; actual driving-scene capture inspected |
| `--path game --script .../build/theme_probe.gd -- --theme=pine` (also coast/desert) | All three exit 0; retained screenshots inspected; no shader/render errors |
| `--path game res://core/game.tscn -- --track=slicks_1way_test --capture=.../docs/evidence/track-kit3-bridge.png` | Exit 0; bridge capture inspected |

The ignored presentation probe constructs the same car, lighting and follow-camera profile over FREEWAY, changes theme metadata only in memory, and captures without a HUD. The first concurrent editor import returned exit 0 but reported the still-in-progress `core/app.gd` missing; it is not recorded as a successful whole-project validation. Integrated validation belongs to the menu/creator slice record.

A subsequent wrapper `Snapshot -Track slicks_1way_test` encountered the in-progress `core/app.gd:169` parse error and was stopped; no capture from that failed run is accepted. The explicit game-scene capture above succeeded. A before/after SHA-256 of native metadata, surface/deck cells, route, spawn, gates and content identity remained identical across visual construction: `ac793a27b46b0ecb7deb9e8e8d8ee1705324dfb900cd9ce355d5dd3ea5020c09` on the pine FREEWAY probe. This checks the presentation/data boundary, not cross-device replay equivalence.

Remaining acceptance: owner review while driving, final comparison to the reference camera fixture, wide-screen visibility and real Android frame pacing/bright-light readability. No physical-phone test or APK export was performed for this art change. Source grid contours and simple native barrier shapes remain visible; this is an original coherent starter kit, not a completed environment asset library. Slicks source layouts retain their existing internal-test provenance.
