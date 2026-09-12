# Forgiving surfaces and track presentation — 2026-09-12

Owner feedback: incidental objects caused too many collisions, and the track presentation did not match the car. Requirements: G01 handling, G02/R03 circuit and ordered laps, V01/V02 coherent original presentation, R01 offline native boundaries. This is a focused revision of the four authorized handling fixtures; handling approval and the wider art roadmap remain open.

## Driving changes

The offline block-role configuration now maps vegetation to grass, small rocks/holes/posts to low rough patches, and small markers/round islands to curbs. Overhead sign graphics are decoration. Actual walls, substantial structure footprints, bridge rails and deep water remain blocking. These are explicit test-game interpretations, not claims about the original game's object physics. Source art was inspected for classification only.

Grass and rough ground apply speed-dependent resistance through the existing surface system. With speed `v` in m/s, grass uses grip 0.65 and resistance `2 + 0.65v` m/s²; rough uses grip 0.65 and `2 + 0.9v`. This reduces entry speed even with throttle held while permitting acceleration from rest. Dirt, curb and ford responses remain as before. There is no impact bounce on these soft materials.

At 72 km/h with full throttle, the 0.5-second test ends at **67.30 km/h on grass** and **60.33 km/h on rough ground**, with zero contacts. Coasting on rough ends at 42.46 km/h versus 71.25 on asphalt. Tests also verify reverse slowdown, no stationary propulsion, acceleration out of soft terrain and entry/exit through a six-metre rough patch.

| Track | Ground solid cells before → after | Three AI lap times (s) | Contacts |
|---|---:|---|---:|
| FREEWAY | 26,022 → 1,480 | 17.703 / 17.251 / 17.233 | 0 |
| 1WAY | 3,939 → 2,357 | 29.343 / 27.995 / 27.947 | 0 |
| 66 | 5,519 → 1,641 | 21.014 / 19.624 / 19.610 | 0 |
| OFFROAD | 6,926 → 1,480 | 29.506 / 28.567 / 28.568 | 0 |

Counts are occupied 0.25 m grid cells, not numbers of objects; deep water and upper rails are excluded. The native bridge arrays, spawn, finish gate and checkpoint rectangles/order were compared against the previous commit and are unchanged. Native AI routes regenerate around the revised surfaces, still using source progression hints. Rough patches remain avoidance hints for the conservative planner even though players can drive through them. OFFROAD's previous post-pair spacing rule remains applied to the now-soft patches; no new manual tracing or geometric correction was added. Global scale stays 0.25 m/source pixel: the 9 m reference road is 5.68 current car-body widths. FREEWAY remains the first handling benchmark.

## Presentation changes

Original `track-kit-2` uses charcoal asphalt, natural green ground, muted dirt/gravel and curb paint, with matching matte bridge materials. Two small native material-coverage textures replace thousands of ground rectangles. Interpolated coverage selects crisp surface contours rather than displaying filtered legacy colours. Any boundary rounding is limited to interpolation within the native cells; the debug view shows the exact collision/surface grid.

Exposed barrier sides are batched without internal walls, removing the previous ribbed seams. Sparse procedural grass tufts and small gravel shapes remain below the car and are non-colliding. A checkered finish is clipped to the local finish road rather than painted across unrelated lanes inside the broad practice gate. The camera, physical car dimensions and lighting remain unchanged. No external artwork, source sprites, runtime dependencies or image-generation assets were added.

Final inspected Windows captures: [FREEWAY](evidence/terrain-freeway.png), [1WAY](evidence/terrain-1way.png), [66](evidence/terrain-66.png), [OFFROAD](evidence/terrain-offroad.png).

## Contracts and changed files

- `scripts/slicks/config.json`, `convert.py`, `golden.json` and the four `game/resources/tracks/slicks_*_test.json` fixtures: revised offline roles, regenerated paths and deliberate golden refresh. Source hashes remain unchanged.
- `docs/native_track.schema.json`: `surface-grid-v2` adds material 7, drive-through rough. Fixtures are content version 2; `NativeTrack.read` still accepts existing v1 data. No persistent save migration is involved.
- `game/track/native_track.gd`, `game/vehicle/vehicle_simulation.gd`: surface response and physics identity `arcade-planar-0.6`. Handling parameters stay `handling-0.8`; recorded runs retain content hashes and physics identity, so this is not represented as the previous rules/content combination.
- `game/track/native_track_visual.gd`, `terrain.gdshader`, `bridge_presentation.gd`: original presentation kit. `game/tests/test_tracks.gd`: soft-surface driving regressions. Status, plan, import notes, provenance and this evidence document updated alongside them.

## Actual commands and results

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows Compatibility renderer / RTX 3090:

- `.tools/review/Scripts/python.exe scripts/slicks/convert.py build/slicks_handoff/slicks_codex_handoff`: regenerated all four fixtures.
- `.tools/review/Scripts/python.exe scripts/slicks/test_convert.py build/slicks_handoff/slicks_codex_handoff`: four converter tests passed, including golden bytes and original source metadata. All four JSONs additionally passed `jsonschema.validate` against the revised native schema. [Evidence](evidence/terrain-converter-tests.txt).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: import, 24 parses, startup, **56 driving + 76 track checks passed**. Complete three-lap JSON replays match exactly on Windows, all three upper/lower crossings retain their layers, and the ramp continuity guards still pass. [Driving log](evidence/terrain-driving-tests.txt), [track log](evidence/terrain-track-tests.txt).
- `TestTracks` was also run during iteration. One new test initially conflated non-collision traversal with travelling eight metres in 0.5 seconds; the stronger resistance correctly made that distance shorter. It now checks positive movement separately and adds a finite six-metre patch entry/exit test. Existing lap, collision, replay and ramp guards were retained.
- `Snapshot -Track slicks_<name>_test` succeeded for all four final views and compiled/rendered the final finish-paint clipping. Earlier delayed AI captures at 1WAY tick 1457 and 66 tick 875 were also inspected. A delayed OFFROAD capture stalled after losing focus; only that capture process was terminated. Its immediate replacement succeeded. Final evidence uses fresh successful captures, not stale files.
- `git diff --check`: passed.

## Remaining acceptance

Drive across vegetation and rough markers both with throttle held and while coasting; verify that speed loss feels useful without making recovery tedious. Check that low terrain and actual walls are visually distinguishable in motion. The material values remain tuning proposals. Surface response samples the car centre, not individual tyres; the circular collider, broad practice gates and off-route bridge limitations remain. Some source-grid silhouettes and transparent-mask edge irregularities are still visible; structure footprints remain simple test geometry. This is an improved handling-test presentation, not a finished environment art set.

No physical-phone test, APK export or phone performance measurement was performed; device attachment was not verified. Human feel, bright-screen readability and device performance acceptance remain pending.
