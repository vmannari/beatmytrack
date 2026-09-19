# Winter ice roads - 2026-09-18

Requirements G01/R01/R03/R07/T02/V02/V04/V05. Owner explicitly requested slippery icy winter roads, superseding the earlier cosmetic-only winter scope.

Winter asphalt (surface ID 0) now has 32% of normal road traction, including painted asphalt, placed roads, native roads and elevated asphalt bridge decks. This feeds the existing lateral and combined longitudinal traction budgets: longer slides, longer braking distances and traction-limited acceleration. Dirt, snow-covered off-road ground, water, concrete and hazard behavior keep their existing surface factors. Ice adds no dirt pickup or soil rollover trigger. The multiplier is an initial authored tune awaiting owner driving acceptance.

The shared road shader and palette show cool blue-grey ice with restrained frost streaks. Creator and native bridges use the same winter palette/ice shader. Physics is `arcade-planar-0.27`; visual kit is 31. Physics version participates in replay headers and PB comparison keys, separating new records from pre-ice records without deleting saves. Input/state schemas and geometry remain unchanged; no golden handling fixture values were rewritten.

Changed files: `game/track/native_track.gd`, `track_theme.gd`, `native_track_visual.gd`, `surface_detail.gdshaderinc`, `creator_bridge_visual.gd`, `bridge_presentation.gd`; `game/vehicle/vehicle_simulation.gd`; new `game/tests/test_ice.gd` and generated UID; `scripts/dev.ps1`; updated biome screenshot evidence; this document, biome documentation and development/phase status.

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:

- `TestIce`: 55 checks passed. Checks all eight surface IDs, elevated asphalt, no dirt pickup, braking/sliding/acceleration across all five cars and exact serialized input replay in 1/2/4/8-tick batches. Initial elevated-grip assertion used exact equality between a float32 Vector2 component and a float64 constant; changed that numeric assertion to approximate equality. Full simulation replay equality remains exact.
- `CaptureBiomes`: 41 checks passed; updated [winter road screenshot](evidence/biomes/winter-race.png) inspected.
- `TestCars`: 65 checks passed, including complete five-lap serialized replays for five cars across three circuits.
- `Validate`: import, script parsing and startup succeeded; all domain suites through objects passed (including driving 70, handling 77, route validation 55, tracks 167, creator 99, bridges 91, hazards 150 and ice 55). Winter completed three diagnostic laps with zero contacts and exact serialized replay. Full validation then failed at `test_app.gd`: 86 checks, 9 failures around biome navigation and road-handle dragging, with missing dictionary `length` accesses at `editor_canvas.gd:975`. Neither app test nor editor canvas was modified in this ice task. These failures were not suppressed; a pre-change baseline was not rerun. Some graphical lifecycle tests also reported two ObjectDB instances leaked at exit. Full-suite green status is not claimed.
- Independently after the Validate stop: `TestRecords` 53, `TestCatalog` 18, `TestMenus` 11, `TestCarBalance` 1 checks passed. The standalone kart suite was not reached by Validate; all-car tests and ice tests include the kart.
- Targeted `git diff --check`: passed.

[Full validation output](evidence/winter-ice/winter-validation.log), [five-car replay output](evidence/winter-ice/winter-cars.log), [ice metrics/checks](evidence/winter-ice/ice-tests.log).

From 20 m/s (72 km/h), measured dry/ice stopping distances: compact 11.39/24.03 m; pickup 16.03/29.07 m; classic 10.68/23.18 m; formula 7.21/21.62 m; kart 7.02/20.41 m. Compact half-second sideways-slide distance increases from 1.05 to 2.92 m in the diagnostic fixture.

Remaining acceptance: owner driving feel, icy-road readability in motion and device performance/touch testing. No phone test or Android export performed; attachment was not checked. Existing mixed workspace changes remain uncommitted; no merge performed.

## Milder winter handling and soft snowbanks - 2026-09-18

Owner follow-up: winter felt too slippery and slow; add small snow barriers around the road that slow cars before leaving it. Requirements G01/R01/R03/R07/T02/V02/V04/V05. This supersedes the 32% traction tune above.

Winter asphalt traction is now 60% of dry-road grip. This substantially restores launch speed while retaining lateral slide. The compact's one-second launch speed is 14.27 m/s (14.37 dry, 7.82 with the previous ice tune); its stopping distance from 72 km/h is 12.99 m (11.39 dry, 24.03 previously). Its half-second sideways slide is 1.64 m (1.05 dry, 2.92 previously). All five cars retain at least 80% of their dry one-second launch speed. The pickup's brake-force limit is below the new ice traction limit, so its straight-line stopping distance equals dry-road distance; its lateral slide still increases. The previous severe-ice braking/acceleration assertions were revised for this owner-requested milder tune, retaining exact replay checks and all-car increased-slide checks.

Low snowbanks surround exposed asphalt edges, including painted asphalt and inside islands. The ridge is 0.32 m tall and 1.25 m wide with tapered sides. Deterministic contour construction joins the raster boundary and rounds its steps. Junctions remain open; ground banks stop at bridge approaches and do not catch elevated/airborne cars. Banks are soft, driveable snow, not solid walls: a swept four-wheel contact sample dissipates velocity in any direction, including sideways. Contact begins while the car centre is still on asphalt. No bounce, wall-collision penalty or jump is introduced. The shared ridge triangles determine both rendering and contact. Dirt-only roads retain their earlier surface behavior and do not get asphalt-edge banks.

In the outward-crossing fixture, speed after 0.3 s is 13.01 m/s with snowbanks versus 15.90 m/s with only the ordinary off-road drag. A car starting at the bank can power through it. Contact replays exactly with different tick batching. Snowbanks are rebuilt from track geometry; no user-file migration or deletion is required. Physics 0.28 and visual kit 32 pin this change; new PB keys remain separated from previous physics records.

Changed files: new `game/track/snow_banks.gd` and UID; `game/track/native_track.gd`, `road_kerbs.gd`, `playground_data.gd`, `native_track_visual.gd`; `game/vehicle/vehicle_simulation.gd`; `game/tests/test_ice.gd`; updated biome evidence, this document and development/phase status. Existing kerbs retain their 0.10 m height; the shared contact helper now accepts a per-instance height ceiling for snowbanks.

Actual commands (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`): `Import` passed; `TestIce` passed 69 checks; `CaptureBiomes` passed 41 checks. [Updated winter screenshot](evidence/biomes/winter-race.png) inspected after replacing the initial stepped bank mesh with rounded contour strips. Targeted `git diff --check` passed. `TestCars` passed 95 checks, including complete five-car race/replay coverage. Winter creator diagnostic laps were 21.65 / 21.16 / 21.15 s with zero barrier contacts and exact replay (creator suite: 99 checks passed).

Remaining acceptance: owner driving feel and snowbank appearance; physical-phone controls, frame pacing and large-track snowbank cost. No phone test or Android export performed; attachment was not checked. No combined commit/merge made in the mixed pre-existing workspace.


Snowbank regression outcome: `Validate` passed import, parsing, startup and domain suites through objects, including driving 70, handling 77, route 55, tracks 167, creator 99, road pieces 328, bridge/HUD 91, hazards 150, kerbs 31 and ice/snowbanks 69 checks. It stopped at the same 9 of 86 app assertions reported during the preceding ice pass (biome-navigation expectation and missing road-handle dictionary `length` in `editor_canvas.gd:975`). No assertion was removed to hide those failures. Some lifecycle tests reported ObjectDB leaks at exit. Full validation is not green. Independently, `TestRecords` passed 53, `TestCatalog` 18 and `TestMenus` 11 checks. Remaining standalone kart/balance suites were not reached by Validate; car and snowbank tests exercise all five vehicles.

Evidence: [validation output](evidence/winter-snowbanks/snow-Validate.log), [car replay output](evidence/winter-snowbanks/snow-TestCars.log), [snowbank checks and measured speeds](evidence/winter-snowbanks/ice-tests.log), [final snowbank screenshot](evidence/winter-snowbanks/winter-race.png).
