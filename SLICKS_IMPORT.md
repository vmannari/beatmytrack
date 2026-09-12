# Slicks-derived handling fixtures

Implemented 2026-09-11 for the owner's explicit four-track handling-test request. Requirements: **G01** handling, **G02/R03** circuit and ordered lap foundations, **R06** immediate retry, **R01** native/offline boundaries; debug evidence supports **V01** inspection, not camera calibration approval. This is an internal practice fixture set, not the full Phase 5 competition/timing feature.

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run -Track slicks_freeway_test
```

The other IDs are `slicks_1way_test`, `slicks_66_test`, and `slicks_offroad_test`. Without `-Track`, the existing handling yard remains the default. Click **Track F5** or press **F5** to cycle FREEWAY, 1WAY, 66, OFFROAD, yard. W/Up accelerates, A/D steers, S/Down/Space brakes; R immediately resets the car and three-lap practice session. Existing tuning, presets, recording and touch controls remain available.

**F4** toggles the full-track top-down debug view; driving still uses the unchanged high-oblique camera profile. **F7** cycles route/checkpoint view, original AI regions/targets, and original block bounds/IDs. White shows stored spawn/direction and the native finish gate, gold shows ordered source checkpoint regions, cyan shows the generated native path. The geometry underneath is the native surface/collision data, not a source screenshot. **F9** toggles the conservative diagnostic AI and restarts. AI sends normal quantized controls through the same car simulation; it never teleports the car.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run -Track slicks_offroad_test -Overview -AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Snapshot -Track slicks_freeway_test -Overview
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Snapshot -Track slicks_1way_test -AI -CaptureTick 1700
```

`Snapshot` captures the actual window into `build/<track-id>.png` without rerunning validation. `Capture` validates first. `CaptureTick` waits for that simulation tick, then captures and exits. `TestTracks` runs the focused track suite; `Validate` runs both runtime suites and checks parsing/startup.

Keep delayed captures focused: normal focus-loss pause still applies. One late recapture was interrupted/closed before completion; an earlier successfully saved moving capture is retained. The wrapper now requires `CAPTURE_SAVED` and rejects a closed window instead of accepting a stale PNG; a subsequent immediate 1WAY snapshot passed.

## Inspection and smallest extension

Before changes, the project had only `PlaygroundData`: rectangular asphalt bounds, two circular concrete islands and a spawn. `PlaygroundVisual` shared those shapes with collision resolution. There was no editor/import pipeline, circuit resource, surface classifier, checkpoint/lap session or AI representation. The car is **4.25 × 1.8 m**, with a **1.55 m radius circular collider** and 2.55 m wheelbase. Its collider is wider than the rendered body. Simulation coordinates `(x,y)` map to world `(x,0,-y)`; heading zero points along simulation +Y.

The small extension is a `NativeTrack` Resource subclass of `PlaygroundData`, consumed by the existing vehicle step. It stores a generic native surface grid, merged mesh rectangles, ordered checkpoint regions, a closed route, spawn and directed finish. Surface grip/resistance belong to game code, not the imported maps. No handling preset or car dimensions changed. Native collision uses the existing bounce/energy-loss parameters, with swept circle sampling against occupied cells. The yard's surface multiplier remains 1 and extra resistance 0.

`NativeTrackVisual` uses `VisualGeometry` and the existing matte materials; original trees/buildings/rocks become simple concrete collision stand-ins. Curb colours, textures, lettering, crowds and tiny sprite details are not reproduced. These are deliberately unpolished handling fixtures.

Changed files are grouped into `scripts/slicks/` (converter, supplied tools, config and golden tests), `game/resources/tracks/` (four native maps), `game/track/native_track*.gd` and `playground_data.gd` (surfaces/collision/meshes), `game/race/track_session.gd` (practice laps), `game/input/route_driver.gd` (AI), `game/vehicle/vehicle_simulation.gd` and `vehicle_state.gd` (surface factors/layer state), `game/core/game.gd`, `game/ui/playground_hud.gd` and `track_debug.gd` (selection/presentation), `game/persistence/handling_recorder.gd` (versioned diagnostics), `game/tests/`, and `scripts/dev.ps1`. The native contract is in `docs/native_track.schema.json`; status, plan, README, AGENTS, provenance and evidence are updated alongside it.

## Import another track

Compatibility code lives only in `scripts/slicks/`. The two supplied parser/renderer modules are retained as supplied; `convert.py` adds data-driven semantic conversion. The runtime never opens `.SS`, `SLICKS.DAT`, Python or reference images. The sole legacy-shaped runtime payload is optional debug metadata, consumed by `TrackDebug`.

The inspected ZIP was `C:/Codes/Godot/Racing game/racing-game/temp/slicks_codex_handoff.zip`, extracted to ignored `build/slicks_handoff/slicks_codex_handoff`. Keep original files outside `game/`.

```powershell
.tools/review/Scripts/python.exe scripts/slicks/convert.py build/slicks_handoff/slicks_codex_handoff
.tools/review/Scripts/python.exe scripts/slicks/convert.py <extracted-package> --track ANOTHER --output game/resources/tracks
.tools/review/Scripts/python.exe scripts/slicks/test_convert.py build/slicks_handoff/slicks_codex_handoff
```

The supplied decoder uses Pillow, already available in the existing ignored review environment. No dependency was installed and there is no runtime dependency. Place additional v2 tracks under the package's `original_tracks/`; use the corresponding DAT. Review any unknown block IDs/upper flags in `config.json`: conversion fails instead of silently guessing them. Register an additional native ID in `game/core/game.gd` to expose it in this small test selector.

Conversion directly indexes DAT resources by block ID, rotates clockwise about the top-left placement, preserves file-order compositing and treats palette zero as transparent. It classifies decoded masks by block role, discards artistic pixel colours, and merges surface runs into native rectangles. No screenshot was traced. The source checkpoints and computer regions remain in original order. Computer targets are clearance-adjusted seeds; bounded pathfinding routes around native obstacles, then subdivision produces a conservative waypoint path. Runtime obstacle anticipation steers the diagnostic driver away from barriers. This is not an optimal racing line or an overtaking AI.

`golden.json` pins each source file and native output hash. The converter emits UTF-8/LF bytes explicitly; a regression test caught and fixed the original Windows CRLF mismatch. Review geometry and rerun driving checks before deliberately refreshing these hashes after config changes.

## Scale and measured width

`config.json` owns `car_width_m=1.8`, `representative_road_width_px=36`, `target_car_widths=5`, and the car's collision radius. The resulting global scale is **0.25 m per source pixel**, making the whole canvas **80 × 50 m**. The 36-pixel reference section becomes **9 m / five car widths**. No track has a separate global scale.

The original layouts are not uniformly wide. These reproducible axis-aligned transects measure contiguous native asphalt/curb cells, not minimum clearance or an everywhere-normal road-width guarantee:

| Track | Source-coordinate transect | Width | Car widths |
|---|---|---:|---:|
| FREEWAY | vertical at (180,150), bottom straight | 9.75 m | 5.42 |
| FREEWAY | horizontal at (270,100), right bend | 11.00 m | 6.11 |
| FREEWAY | vertical at (120,20), broad upper section | 13.50 m | 7.50 |
| 1WAY | vertical at (160,30), start straight | 8.25 m | 4.58 |
| 1WAY | horizontal at (25,110), left straight | 12.25 m | 6.81 |
| 66 | horizontal at (20,100), left approach | 12.25 m | 6.81 |
| 66 | horizontal at (290,80), broad right approach | 14.50 m | 8.06 |
| OFFROAD | vertical at (110,110), narrow straight | 6.50 m | 3.61 |
| OFFROAD | horizontal at (290,125), right approach | 10.00 m | 5.56 |

Wider sections and OFFROAD's narrow road are retained to preserve their character. The five-width scale reference is not a claim that every section is 4–6 widths. Effective obstacle clearance must also account for the 3.1 m circle diameter.

## Corrections and inferred semantics

Only **OFFROAD** needed a manual geometry rule: `track_corrections.OFFROAD.post_pair_spread_px=4` moves each of its three block-53 post pairs outward by **1 m per post**. Their original gaps were unsuitable for the existing circular collider. The converter applies the rule by block ID and paired row, not by tracing a picture. Roads, source spawn, checkpoint bounds and original debug bounds stay unchanged. FREEWAY, 1WAY and 66 have no manual geometry corrections. All four generated AI paths are algorithmically adjusted for clearance.

- 1WAY's 39/40 blocks and 66's 51/52 blocks define raised decks with native rail collision. OFFROAD's opposing 41/42 ramps infer two short decks; 49 defines their rails. The lower road passes underneath. Local route-index continuity chooses the correct branch at each crossing. Disconnected deck-shaped decorative signs are excluded when the source route never traverses them.
- Block roles and bridge collision semantics are inferred from the corrected resources; the original game's physics tables are not decoded. Heights are prototype presentation values. Shared spatial ramp meshes and axle-sampled car height/pitch now smooth layer approaches (see docs/RAMP_FIX.md). Jump physics, underside detail and car-to-car interactions are not implemented. There is one planar vehicle and one bridge axis per native fixture; arbitrary future multi-axis bridge networks need an explicit extension.
- OFFROAD's route-targeted water block group becomes a shallow ford with reduced grip and resistance. Other water remains impassable. This is an explicit handling-test interpretation, not a claim about the original game's exact water rules. Ramps are dirt on the ground layer; panic points and dynamic sprite behaviour are unsupported.
- Native finish gates use the centre of stored block-0 markings for 1WAY, 66 and OFFROAD. FREEWAY has no block-0 line, so its transverse finish is inferred through the stored start and direction. Gate half-width is conservatively 9 m; visible paint is clipped to drivable ground.
- Checkpoints are swept **rectangular entry regions**, as documented in the supplied parser, not diagonal gates. Forward entry and original order are required before a directed finish counts. 66's finish sits inside CP1: the observed CP1 entry on the finish approach carries into the next lap, preserving cyclic order without requiring two circuits per lap.

## Actual results and evidence

All commands used the pinned `4.7.2.stable.official.ed1daf0bf`. `scripts/dev.ps1 Validate` passed import, 23 script parses, startup, **56 driving checks** and **48 track checks**. Four Python converter tests passed, including all four golden outputs, source metadata preservation, clockwise rotation, lossless rectangle coverage and unknown-role rejection. No test assertion was removed or relaxed. An isolated baseline comparison and load-order probes identified a pinned-engine cold class-resolution leak; preloading the native Resource class in the driving test bootstrap removes the retained script without filtering errors from validation.

| Track | Loads / three laps | AI lap times (seconds) | Contacts | Crossing result |
|---|---|---|---:|---|
| FREEWAY | Pass | 18.237, 17.769, 17.723 | 0 | No bridge |
| 1WAY | Pass | 31.498, 30.124, 30.088 | 0 | Upper deck and both underpasses traversed |
| 66 | Pass | 23.168, 21.970, 21.983 | 0 | Both figure-eight layers traversed |
| OFFROAD | Pass | 30.585, 29.592, 29.606 | 0 | Both short decks, lower crossing and ford traversed |

These are conservative AI runs, not human best laps or approved balance. Standing first laps start timing immediately on reset; there is no countdown. 1WAY slightly exceeds the normal 10–30-second target under this deliberately cautious driver. All four full three-lap input recordings replay exactly, including lap times and layer state, after JSON roundtrip in eight-tick batches on this engine/Windows machine. Tests also cover reversed/camped/incomplete checkpoint attempts, high-speed gate sweeps, frozen three-lap results, thin-wall tunnelling, upper-only rail collision and grass response.

Reviewed actual graphical captures against all four supplied reference renders:

- [FREEWAY overview](docs/evidence/slicks_freeway_topdown.png)
- [1WAY overview](docs/evidence/slicks_1way_topdown.png) and [moving bridge view](docs/evidence/slicks_1way_driving.png)
- [66 overview](docs/evidence/slicks_66_topdown.png)
- [OFFROAD overview](docs/evidence/slicks_offroad_topdown.png)
- [Runtime evidence](docs/evidence/slicks-track-tests.txt), [converter evidence](docs/evidence/slicks-converter-tests.txt)

Actual commands included ZIP extraction, `convert.py`, `test_convert.py`, `dev.ps1 TestTracks`, `dev.ps1 Validate`, `dev.ps1 Snapshot -Track <each-id> -Overview`, the 1WAY tick-1700 AI snapshot, `dev.ps1 Doctor`, and `git diff --check`. During failure diagnosis the exact pinned console also ran focused suites directly; normal build/run/test entry points remain `scripts/dev.ps1`. Temporary baseline copies, probes and logs are under ignored `build/`.

**FREEWAY is the best first handling benchmark:** its continuous road and varied bends expose steering response, corner scrub, braking and throttle recovery without bridge or mixed-surface interpretation. Use 1WAY for transitions/hairpins, 66 for wide line choice and a figure-eight crossing, and OFFROAD for narrow clearances, dirt, ford and crossing stress.

## Remaining acceptance

Owner-driven laps, recovery from deliberate off-route excursions, human handling approval, overtaking and phone performance are still untested. The practice counter is not the full competition validator: there is no persistent PB, countdown, anti-cheat verification, comprehensive shortcut proof or cross-platform determinism claim. The broad source checkpoint regions permit some off-road line choice.

`Doctor` actually failed because matching Android templates, SDK/ADB/build-tools and JDK are missing. Device attachment could not be enumerated; no physical-phone test or APK export was performed. No release deployment or production asset clearance is claimed. See `licenses/ASSETS.md` for provenance.

2026-09-12 handling update: owner requested a smaller car. Road/source scale stays 0.25 m/pixel; car body width is now 1.584 m (88%), so the 9 m reference road spans 5.68 body widths. All 48 track checks passed, including zero-contact three-lap runs on all four fixtures with handling-0.8. See docs/DRIVING_PLAYGROUND.md for scale/steering changes and limits.
