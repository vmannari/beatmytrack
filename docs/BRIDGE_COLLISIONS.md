# Bridge collisions and ramp motion — 2026-09-21

Requirements: **G01/G03/R01/R03/R07** (deterministic driving, collision layers and replay), **V02/V04/V05/Q01** (vehicle presentation and evidence). Owner request: stop entering ramps from underneath, remove Knit phantom collisions, and make ramp motion less rigid.

## Findings and changes

The saved local Knit (`track_3db76e7338edcf28`) reproduced 287 collision samples during a diagnostic sweep of its centreline. Expanding bridge membership by the collision radius connected otherwise separate spans: a car leaving a ramp inherited the upper layer of a nearby perpendicular bridge. The combined deck grid also let one bridge's rails hit a car still on another bridge's low exit ramp. Actual span membership now ends at the ramp endpoint, and upper collision/support/escape queries ignore cells belonging to other spans. Existing ground obstacles remain active below bridges.

Creator ramps previously stamped no underside collision. Ground collision now covers the low underside and low side rails, while the separately compiled upper road stays open. The shared clearance is 2.20 m (tallest local car, 42 cm deck and a small allowance); the central tunnel remains open. These cells use the existing ramp mesh rather than generic barrier cubes. The raster remains the existing 0.5 m grid, so boundaries retain its spatial tolerance.

Physics is **arcade-planar-0.37**, compiler **creator-compiler-17**. Recompilation changes content hashes and prevents old records from being compared as if collision rules were unchanged. No player save is edited or deleted. A read-only copy of the owner's Knit is retained in export-excluded test fixtures.

Vehicle presentation adds tick-driven vertical inertia, capped at 0.55 m, with gravity, pitch response and a landing compression impulse. Signed slope changes compress at ramp entry and unload at the crest instead of always compressing. Slow travel remains planted; fast travel can briefly rise above the surface and settle. This is cosmetic: canonical jump state, handling, route timing and collision immunity are unchanged. Hazard jumps/rolls and restart reset the ramp presentation; duplicate snapshots do not advance it. Camera calibration is unchanged.

Changed runtime files: `game/track/creator_bridges.gd`, `game/track/native_track.gd`, `game/track/native_track_visual.gd`, `game/editor/track_compiler.gd`, `game/vehicle/vehicle_simulation.gd`, `game/vehicle/car_visual.gd`, `game/core/game.gd`, regenerated `game/resources/tracks/starter_circuit.json` (version only). Tests/evidence: `game/tests/test_bridge_contacts.gd`, its UID, `game/tests/fixtures/knit_bridge_regression.json`, `game/tests/test_creator.gd` (new compiler hash golden), `game/tests/test_suspension.gd`, `scripts/dev.ps1`, this document, development/phase status and `docs/evidence/bridges-2026-09-21/`.

## Commands and actual outcomes

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, which verifies Godot **4.7.2.stable.official.ed1daf0bf**.

| Action | Result |
| --- | --- |
| `TestBridgeContacts` | 16 checks pass. Six complete Knit sweeps (both directions, centre and ±1 m) have zero collisions. Low underside blocks swept entry from both tunnel directions; upper ramp and central lower crossing remain clear; upper rails still block. |
| `TestConstruction` | 74 checks pass; five-lap bridge race has zero contacts, traverses both levels, and replays exactly after JSON round trip. |
| `TestSuspension` | 19 checks pass, including planted 3 m/s traversal, bounded unloading at 24 m/s, landing and reset. |
| `CaptureSuspension` | 27 checks pass; four ordinary suspension and four ramp captures saved. |
| `CaptureBridgeHUD` | 157 checks pass; real gameplay presentation captured in Compatibility. |
| `GenerateStarter` | Succeeds; checked diff contains only compiler version 16 → 17. |
| `TestCreator` | 112 checks pass after pinning the compiler-17 golden; starter geometry/road-area assertions remain unchanged. |
| `TestHazards` | 150 checks pass. |
| `TestPieces` | 340 checks pass, including two five-lap races with zero contacts. |
| `TestKerbs` | 31 checks pass. |
| `Validate` | First attempt passes import, all 151 script parses, startup, driving (74), handling (88), route validation (55), native tracks/replays (167), extra tracks (27), retirement (24), placement (24), road approval (19), start line (27), then stops at the old compiler golden. That golden was subsequently updated and the creator suite passes. |
| `Validate` retry | Interrupted by engine exit `-1073741819` (access violation) during parse of unchanged `persistence/handling_recorder.gd`. No full-suite pass is claimed. |
| `CheckScript -ScriptPath res://persistence/handling_recorder.gd` | The script that hit the engine crash passes on independent retry. |
| `git diff --check` | Passes; only repository line-ending conversion notices. |

The individual construction/hazard/pieces/kerb runs above were completed after the full-suite interruption. Original and retry full logs are saved with the evidence. Existing full-app/navigation and later suites were not reached by these full runs.

The workspace already contained substantial unrelated changes. [Task-only Git patch](evidence/bridges-2026-09-21/task-changes.patch) is the review checkpoint against that pre-task workspace; it excludes the earlier edits. `python temp/create_bridge_checkpoint.py` generated it and `git apply --reverse --check docs/evidence/bridges-2026-09-21/task-changes.patch` verifies it against the final working files without changing them. No merge or commit of unrelated work was made.

## Evidence and acceptance

Ramp captures: [climb](evidence/bridges-2026-09-21/ramp-climb.png), [crest](evidence/bridges-2026-09-21/ramp-crest.png), [descent](evidence/bridges-2026-09-21/ramp-descent.png), [settled](evidence/bridges-2026-09-21/ramp-settled.png). [Gameplay bridge capture](evidence/bridges-2026-09-21/bridge-hud-creator-race.png).

No physical phone test or Android deployment was performed. Remaining acceptance: owner driving Knit (including wider/off-line approaches), subjective ramp movement at gameplay camera scale on all five cars, and phone appearance/performance. The bounded visual lift is not a general physical 3D jump solver.

## Damped suspension follow-up — 2026-09-21

Owner feedback: ramp motion felt like one sway followed by an abrupt static pose. Requirements **V02/V04/V05/Q01/R01**. `CarVisual` now retains pitch velocity through touchdown and flat-road travel using a spring with a 0.5 damping ratio. The whole-car airborne rotation blends smoothly into the sprung body correction as the tyres regain support. Heave and pitch have separate, softer spring/damper values, with smaller slope impulses; lateral roll retains its previous response. The existing 0.55 m visual lift bound and canonical physics/collisions remain unchanged.

In the 0.25-radian exit-response test, residual pitch is -0.0350 radians after 0.4 s, +0.00424 after 0.8 s, and -0.00000167 after 2 s: a small rebound followed by a much smaller return, then rest. Those samples match at 30/60/120 Hz. Duplicate snapshots freeze the spring and canonical snapshots remain untouched.

Changed files: `game/vehicle/car_visual.gd`, `game/tests/test_suspension.gd`, this document and the development/phase status notes. A [follow-up Git patch](evidence/bridges-2026-09-21/damping/task-changes.patch) records only this tuning against the pre-follow-up workspace.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSuspension` initially passed 19 checks. Final `CaptureSuspension` passes **141 checks**, including 30/60/120 Hz decay checks, still captures and 105 animation frames. The first animation capture failed because directory creation needed a global filesystem path on Windows; correcting that path made the rerun pass. `TestBridgeContacts` passes **16 checks**, with zero collisions on all six Knit sweeps. The existing `.tools/review/Scripts/python.exe` and Pillow assembled captured frames into the animation; no dependency was installed. `git apply --reverse --check` verifies the follow-up patch without changing working files.

[Ramp motion animation](evidence/bridges-2026-09-21/damping/ramp-motion.gif) · [Frame sequence](evidence/bridges-2026-09-21/damping/motion-sequence.jpg) · [Capture log](evidence/bridges-2026-09-21/damping/suspension-capture.log).

No phone test or deployment was performed for this follow-up. Owner acceptance of motion in ordinary gameplay and on the other vehicle models remains outstanding. This presentation-only change does not change physics/rules versions and did not trigger another full physics regression run.
