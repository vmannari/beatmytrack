# Speed bumps — 2026-10-12

Owner request: add a speed bump object to Grass, Storm and Night; braking just before it and accelerating across it while the nose rises should permit a faster crossing.

Requirements: SB01 (three biome palettes), SB02 (rounded traversable bump), SB03 (timed suspension response), SB04 (deterministic replay/rewind), SB05 (local editor storage and visual evidence), G01/R01/T01–T04/V04/V05/Q01. This is a local object/handling slice; no existing owner track or live competitive data was edited.

## Use and behavior

Choose **Objects → Props → Speed bump** in Grass, Storm or Night. It supports the existing place, move, rotate, size, duplicate, delete and undo/redo flow. Standard dimensions are 2 m along travel × 8 m across travel, with an 18 cm smooth crown; rotate its long edge across the road and resize for the desired coverage. The original yellow/dark module mesh is also used in its thumbnail. No downloaded/generated bitmap or external dependency was added.

Brake before reaching the bump, then release into throttle as the front suspension rebounds. The canonical 120 Hz damped pitch spring follows actual longitudinal acceleration. A rising leading axle reduces the bump's dissipative speed loss; held throttle has settled pitch, and held braking keeps the nose loaded. This uses spring motion rather than a pedal-combination bonus. The bump cannot supply forward energy, change maximum speed, or trigger a ballistic jump. Crawling speed is forgiving. Both travel directions, rotation, scale and individual wheel contacts use the same rounded profile; overlapping crowns take their maximum height. Ground bump impacts are excluded on elevated decks, during jumps and during rolls.

The displayed body pitch follows the same spring used for the interaction, with the kart's existing stiffer visual compliance. Four tyre contacts, chassis support and contact shading follow the crown. Unchanged tracks were checked against the exact preceding physics, with byte-exact state equality in all five biomes. Existing free racing, five-lap rules, ordered gates, best-only scoring and local car paint/condition flows remain intact.

## Contracts and changed files

Physics is `arcade-planar-0.54`; compiler is `creator-compiler-24`. Creator JSON remains `creator-track-v5`, with `speed_bump` added to its object enum. HandlingRecorder schema 11 keeps snapshot fields 0–21 and appends `[nose_pitch, pitch_velocity]` at index 22. Rewind uses the existing full property snapshot and restores both values. Input replay formats and trajectory verification are unchanged. Local PB identities already include physics/compiler hashes, so historical records are retained under their earlier keys.

The bump initially advances the visual kit from 132 to 133; the shared working tree subsequently contains another task's Winter kit 136. The task-only checkpoint includes only bump dispatch and its own kit revision, excluding the concurrent Winter art changes.

Changed runtime files: `game/vehicle/speed_bumps.gd`, `vehicle_state.gd`, `vehicle_simulation.gd`, `car_visual.gd`; `game/track/playground_data.gd`, `native_track.gd`, `native_track_visual.gd`, `hazard_visual.gd`, `contact_shading.gd`; `game/core/game.gd`; `game/editor/creator_objects.gd`, `creator_catalog.gd`, `track_compiler.gd`; `game/persistence/handling_recorder.gd`. Companion files: `docs/schemas/creator-track-v5.schema.json`, `game/tests/test_speed_bumps.gd`, `test_speed_bump_contract.gd`, `test_creator.gd`, `test_kerbs.gd`, `test_tracks.gd`, `test_winter_compiler_contract.gd`, `game/tests/fixtures/compiler_raster.json`, `scripts/dev.ps1` (includes both bump suites in full Validate), generated UID files, this document, status/phase/agent instructions and evidence.

The starter hash is `69bd84a2e10e2bada8ae30a58bd2130992634e018e30aeca3a18c34df7b50074`. Before refreshing the eight compiler raster fingerprints, `test_speed_bump_contract.gd` checks their exact compiler-23 fingerprints and unchanged metadata/geometry after normalizing only the version. The same test compares the exact prior physics against 1,800 no-bump state snapshots. No invariant was removed to accept the version change.

## Actual verification

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`. Logs and checkpoint receipts are in [the evidence directory](evidence/speed-bumps-2026-10-12/).

| Arguments after the shared command | Actual outcome |
|---|---|
| `-Action Import` | Passed on normal Windows access. Initial restricted import failed to read the certificate store; it was rerun with the same pinned build. |
| `-Action TestScript -ScriptPath res://tests/test_speed_bumps.gd` | Final headless: 9,045 checks, 0 failures. Includes five cars, equal-speed pedal-history comparisons, real quicker approach, rotated/scaled/opposite-direction crossings, energy bounds, JSON replay/rewind and actual editor/file save/undo. |
| Previous row with `-Graphical` | Final Compatibility/OpenGL: 9,057 checks, 0 failures; actual editor and three biome driving captures. |
| Previous row with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` | Mobile/Vulkan on RTX 3090: 9,057 checks, 0 failures; same state results and captures reviewed. Desktop renderer evidence is not a phone test. |
| `-Action TestScript -ScriptPath res://tests/test_speed_bump_contract.gd -TestArgument '--refresh-bump-golden'` | 1,818 checks, 0 failures before writing the new versioned raster fixtures. |
| `-Action TestDriving`, `TestHandling`, `TestTracks`, `TestCreator` | Respectively 72, 88, 167 and 113 checks; all 0 failures, including full diagnostic races and exact JSON replay at multiple render batch sizes. Driving reports its existing 34 ObjectDB shutdown warning. |
| `-Action TestKerbs`, `TestSuspension`, `TestRewind` | 31, 59 and 61 checks; all 0 failures. |
| `-Action TestHazards`, `TestScript -ScriptPath res://tests/test_object_browser.gd`, `TestApp` | 157, 67 and 99 checks; all 0 failures. |
| `-Action TestCompilerRaster` | Eight updated fingerprints pass. |
| `-Action TestScript -ScriptPath res://tests/test_winter_compiler_contract.gd` | 29 checks, 0 failures. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 549 scripts, 0 failures. |
| Existing `.tools/review/Scripts/python.exe` / `jsonschema.Draft202012Validator` | Schema valid; twelve valid three-biome/scaling examples accepted, four invalid scales rejected. No package installed. |
| `-Action Doctor` | Exact engine/templates found; ADB device list empty. |

At an equal 18 m/s entry speed, the five cars lose 8.06–8.19 m/s cumulatively to the bump under settled throttle versus 4.07–4.16 m/s with brake-release rebound. These isolate suspension timing by retaining actual pedal-generated spring history and then setting identical crossing speed/position. They are not full-approach timings. The separate compact full-approach fixture starts both runs at the same position and speed without relocation: full throttle takes 138 ticks over 22 m and exits at 19.802 m/s; braking then releasing 3 m before the leading-wheel bump center takes 136 ticks and exits at 21.817 m/s. Values demonstrate the requested timing advantage; the owner has not yet accepted this balance.

Initial test fixture failures were corrected: a new Godot dictionary key needed a String key rather than dot insertion, and the editor rotation action is `_rotate_object`. The editor capture now waits for both matching compiled content and its asynchronous visual build, so it shows the actual placed bump rather than a preparation screen. Those initial runs and final logs are retained separately.

[Grass](evidence/speed-bumps-2026-10-12/compatibility/pine-driving.png), [Storm](evidence/speed-bumps-2026-10-12/compatibility/storm-driving.png), [Night headlamp approach](evidence/speed-bumps-2026-10-12/compatibility/night-approach.png), [editor placement/palette](evidence/speed-bumps-2026-10-12/compatibility/object-palette.png). Root PNGs are the corresponding Mobile/Vulkan captures.

## Remaining acceptance

Restart the client, place a bump across a straight and try braking before it, then accelerating across it as the nose begins to rise. Owner acceptance remains for timing window, strength, all-car feel and appearance. Physical-phone touch play, lighting/readability, frame pacing and thermal performance have not been tested; no phone is attached. Very broad/sliding contacts are handled with the same bounded leading/trailing axle rule, not a detailed 3D tyre/suspension solver. Upper-deck bump authoring is not supported by the ground-hazard system.

No Android export/install, full all-domain Validate, backend tests/deployment or live writes were performed. The existing compiler/client-server mismatch remains; this client's additional compiler24/physics54 pins also require a matching backend/catalog rollout before competitive starts. Backend fixtures/compatibility upgrades were not silently rewritten. Deployment still requires explicit authorization. The isolated task-only Git checkpoint preserves the main branch/index and all unrelated work.
