# Shallow collision repair — 2026-10-07

Requirements: **G01** driving feel; **V04/V06** contact presentation/audio; **T03** pinned immutable race contracts; **Q01** bounded mobile work. The owner authorized all four recommendations in `SHALLOW_COLLISION_ANALYSIS.md`.

## Delivered behavior

1. **Continuous sliding.** Native resolution refines the first contact, separates by a 1 mm skin and consumes remaining motion through a bounded, repeatedly swept slide. Another touch of the same face no longer removes the whole tangent velocity. Genuine additional contact planes constrain motion; every segment still checks the original occupied cells and collision layer. Existing deep rail/corner overlaps retain safe retreat rather than automatic relocation through the obstacle. A shallow flat overlap can recover and keep sliding.
2. **Stable face response.** The nearest exact face supplies geometric separation/path projection. A local covariance fit supplies the response normal only for long, coherent exposed contours. The fit rejects short/curved/nonlinear support; new creator elevated spans keep exact rail-tip normals. Grid edges still decide acceptance, so fitted normals cannot replace solid geometry with a permissive plane. Samples use fixed row and direction order; there is no random, clock, I/O or frame-rate input to this process.
3. **Proportional scrape resistance.** Tangent loss for a scrape is bounded by 0.15 times normal velocity change. Hard impact needs both rising normal speed (blend starts at the existing 2 m/s setting and reaches full at 8 m/s) and incidence (0.08–0.30 of total speed). The existing vehicle-specific hard-impact loss, recoil and bounded turning remain. Gentle alignment uses a 24/s response at the pinned 120 Hz, with an explicit equality regression for the collision tick duration. The circle footprint, car dimensions, controls, surfaces and checkpoint contract remain unchanged.
4. **Separate feedback.** Per-step observer outputs provide the actual hard collision velocity change and scrape direction/speed/strength. They are reset before each simulation tick and do not influence driving or the competitive snapshot. The game feeds hard impact to shake/suspension/glass/audio, and scrape to restrained body loading plus a quiet friction loop. Tyre-stack impulses report their actual resolved change. The friction loop reuses the existing cleared `loose.wav` recording at low gain/pitch; the bounded voice count increases from 17 to 18. Pause, airborne/roll/countdown, leaving contact, retry and rewind suppress/clear its queued feedback. Audio provenance and original clip bytes are retained.

Measured compact, clean asphalt, 108 km/h entry with a 2° chassis/velocity angle to the wall:

| Measure | Physics 0.50 | Physics 0.51 |
| --- | ---: | ---: |
| Single contact tangent-speed loss | 9.851% | 0.524% |
| One-second coasting progress, 0.5 m grid | 3.796 m | 28.680 m |
| Speed after that second | effectively 0 km/h | 100.057 km/h |

The same isolated graphical run uses the shipping car, overhead camera and audio presenters. Inspected [before](evidence/shallow-collision-fix-2026-10-07/before.png) / [after](evidence/shallow-collision-fix-2026-10-07/after.png) screenshots and original [before audio](evidence/shallow-collision-fix-2026-10-07/before.wav) / [after audio](evidence/shallow-collision-fix-2026-10-07/after.wav) are retained. These are diagnostic asphalt-wall scenes, not phone captures or acceptance of driving feel. Two 120-frame sequences remain in `build/shallow-collision-fix/captures`.

## Replay and backend contracts

Physics is now **`arcade-planar-0.51`**. Replay schema, handling resources/config hashes, compiler 22, road gates v19 and five ordinary race laps remain. Backend compatibility upgrades immutable track metadata into the current attempt contract and includes .50 publications in eligible-track queries; board identities retain the new physics pin. There is no historical score rewrite or deployment.

The original verified oval changes **only** its expected physics version. Its document, 12,757 inputs, five lap ticks and exact 106,308 ms result are preserved and reverified. The owner's old Over and under recording depends on .50 contact movement: it cannot complete the same gates under .51. Exact task-start runtime sources are archived under `backend/tests/fixtures/physics_050/*.gd.txt`; a disposable historical verifier still checks all five original lap ticks, the 7,786-tick/64,880 ms result, and truncated/trailing-input rejection. The native regression uses export-excluded copies of the same contact/step methods. Current verification separately rejects an unfinished historical trajectory. No bypass ships, no recording is shortened and no timing/gate invariant is relaxed.

The cloud/NAS verifier needs a matching backed-up rollout before this client can race online. This task does not authorize a production deployment, alter live services or migrate standings.

## Changed files

- `game/track/native_track.gd`, `playground_data.gd`: support fit, swept slide and impulse/energy response.
- `game/vehicle/vehicle_simulation.gd`, `vehicle_state.gd`, `handling_config.gd`, `loose_tyres.gd`: version, observer outputs, setting documentation and actual stack impulse.
- `game/core/game.gd`, `game/vehicle/car_visual.gd`, `vehicle_audio.gd`: separate impact/scrape routing and presenters. Concurrent soundtrack changes are preserved.
- `backend/bmt_backend/contracts.py`, `rivalry.py`: current physics contract and track eligibility.
- `game/tests/test_shallow_collisions.gd`, `analyze_shallow_collisions.gd`, `capture_shallow_collisions.gd`, `fixtures/legacy_contact_physics.gd`: behavioral matrix, measurements, in-engine evidence and historical fixture.
- `game/tests/test_rejected_race_replay.gd`, `test_vehicle_audio.gd`, `test_menu_loading.gd`: preserved historical checks/current rejection, 18-voice bound, and complete current mock contracts (`run_id` and `test_drivers_available`). Assertions remain intact.
- `backend/tests/test_verifier.py`, `test_review_reliability.py`, `fixtures/verified_oval.json`, `fixtures/README.md`, `fixtures/physics_050/*`: exact/current contract coverage and provenance.
- `scripts/dev.ps1`: includes the new behavioral suite in full validation.
- This report, status/phase entries and `docs/evidence/shallow-collision-fix-2026-10-07`: commands, source hashes, scoped review patch and retained outcomes. The mixed working tree is not committed as one change.

## Actual commands and verification

All native runs use `scripts/dev.ps1`, exact **Godot 4.7.2.stable.official.ed1daf0bf**, and a task-specific `APPDATA` under `build/shallow-collision-fix`. The runs need access to the Windows certificate store outside the filesystem sandbox. Existing player saves/account configuration are not used.

```powershell
$env:APPDATA = Join-Path $PWD 'build/shallow-collision-fix/userdata-focused-final'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shallow_collisions.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/analyze_shallow_collisions.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_shallow_collisions.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Validate -CommandTimeoutSeconds 300
# Each of these also ran individually through TestScript:
# test_vehicle_audio.gd, test_desert_audio.gd, test_rejected_race_replay.gd,
# bridge/creator/road/suspension/kerb/soil/vehicle/rewind/records/camera scripts.
$env:BMT_GODOT_BIN = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:BMT_GAME_PROJECT = Join-Path $PWD 'game'
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py backend/tests/test_review_reliability.py backend/tests/test_rivalry.py -k 'not postgres' -q
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/contracts.py backend/bmt_backend/rivalry.py backend/tests/test_verifier.py backend/tests/test_review_reliability.py
```

The behavioral suite covers all five cars, 36–144 km/h single brushes, mirrored response, energy, 0.25/0.5 m grids, 0/30/45/75° walls, translated raster phases, exact repeats, real closed corners, steering away, reverse, thin-wall tunnelling and contact/audio lifecycle. The diagnostic additionally records 180 isolated contacts and 60 one-second wall traces, each repeated. Exact four-circuit historical three-lap replays and multiple native five-lap routes remain checked; historical three-lap diagnostics do not change ordinary lap count.

Final results and all initial failures are summarized in `evidence/shallow-collision-fix-2026-10-07/results.json`; original command logs are retained alongside it. Backend selected tests passed **115**, with **46 PostgreSQL cases deselected** because the local server was unavailable. The selected Python lint and scoped whitespace checks passed. Final audio **1,434**, desert audio **25**, and retained native replay **11** checks passed with clean command exits. The actual recorded mixer outputs were audible in PCM and below clipping; listening acceptance remains with the owner.

Final full validation parsed **324 scripts** and passed the driving/handling/replay, **20,024** new scrape checks, **167** original contacts, **2,527** bridge exits, creator/road/bridge/hazard/soil/suspension/app/records/ghost/camera/menu checks through the raster audit. It stops at **eight existing compiler-raster golden mismatches**. A separately staged build restored to the exact archived **physics 0.50** reproduces the same eight failures, proving they are independent of this contact change; the golden file is retained without regeneration. The remaining night lighting **15**, deletion **20**, menus **48**, kart **32**, cars **105**, and balance **1** checks all passed with command exit 0 in the follow-up batch. Full Validate is therefore **not claimed green**. Some existing bridge/HUD/hazard/camera tests emit shutdown ObjectDB warnings; the final cycle-related resource errors are resolved.

Intermediate failures were repaired rather than hidden: embedded rail relocation was rejected by five old assertions and the safe retreat path restored; three kart/Formula rotated-wall cases needed perpendicular exposed-edge samples without relaxing the limits; a test normal used the wrong Vector2 direction and was corrected; stale upload/menu mocks were brought to the actual interface; the first capture's PCM getter loop was stopped and changed to one buffer read. A new `PlaygroundData`→`VehicleSimulation` script dependency caused teardown resource errors: removing that cycle with the same pinned tick value resolves the cleanly rerun editor/audio tests. Initial mixed/PostgreSQL runs and pre-fix teardown failures are retained, not presented as passing tests.

One captured desktop axis-wall sample spent approximately **0.38 ms per simulation step** versus **0.14 ms** before the repair; this is an instrumented Windows/RTX 3090 result, not mobile p95 or a thermal measurement. The solver bounds slide contacts to 12 and surface sampling to a local patch. Phone CPU/GPU cost, cross-platform replay equivalence, owner driving/ear acceptance and wider object-course motion acceptance remain open. No phone attachment check, physical-device test, APK export/install or backend deployment was performed.

## Owner-requested extra slowdown — 2026-10-07

The owner accepts the repaired contact feel and asks for slightly more slowdown. **G01/T03:** scrape friction rises from **0.15 to 0.18**, a **20% increase** in scrape resistance. Physics advances to **`arcade-planar-0.52`** and local backend/fixture contract pins follow it; .51 publications remain eligible under the new attempt contract. Native collision geometry, slide refinement, normal fitting, recoil, yaw/alignment and feedback thresholds remain as delivered. No historical score or recorded input is rewritten. The original oval changes only its expected physics pin and still verifies exactly.

At the same compact 108 km/h / 2° brush, tangent loss increases from **0.524% to 0.629%** per contact. After one second of coasting alongside the wall, speed changes from **100.057 to 99.082 km/h**, and progress from **28.680 to 28.511 m**. The final [physics .52 capture](evidence/scrape-drag-2026-10-07/physics052.png) uses the same car/camera scene; the saved [physics .51 capture](evidence/scrape-drag-2026-10-07/physics051.png) remains available for comparison.

The old no-snag test coupled continuity to the .15 tuning's final-speed floor. The requested steady slowdown supersedes that numerical target. It now retains the **85% total travel** bound and additionally checks **every tick** for lost movement (at least 50% of incoming tangential travel) and **under 5% abrupt contact loss**. Energy, mirrored response, single-contact retention, exact repeats, corner/rail safety, reverse, steering-away and feedback checks remain intact. This measures snagging directly instead of treating gradual, requested speed loss as a freeze. Preliminary 0.20/0.17/0.16/0.155 trials exposed the old speed-target coupling; their failures were retained and no solver invariant was suppressed.

Changed files: the friction constant in `playground_data.gd`; physics pin in `vehicle_simulation.gd`; local `contracts.py`/`rivalry.py` compatibility and associated verifier/review/oval expected pins; per-tick diagnostics in `analyze_shallow_collisions.gd`/`test_shallow_collisions.gd`; a version-derived capture caption; this report, status/phase entries and `evidence/scrape-drag-2026-10-07`. The latter contains task-start hashes, scoped patch, original command logs, actual measurements and final results.

Actual pinned commands use isolated `APPDATA=build/scrape-drag-2026-10-07/...`: `scripts/dev.ps1 -Action TestScript` for `test_shallow_collisions.gd` and `analyze_shallow_collisions.gd`; the same action with `-Graphical` for `capture_shallow_collisions.gd`; `-Action Validate -CommandTimeoutSeconds 300`; selected backend `test_verifier.py`, `test_review_reliability.py`, `test_rivalry.py` with `-k 'not postgres'`; a final canonical-verifier repeat on the selected tune; and Python lint/scoped whitespace checks. All scripts use `powershell -NoProfile -ExecutionPolicy Bypass -File` and the exact pinned Godot.

Final counts/outcomes are recorded in `evidence/scrape-drag-2026-10-07/results.json`. The new behavioral **20,024** and diagnostic **14,820** checks pass. The broader selected backend run passes **116** tests, with **46 PostgreSQL cases deselected**; the final verifier repeat uses the actual .18 tune. Capture checks pass with unclipped recorded audio. No phone attachment check/device driving, APK export/install, service rollout or production action was performed. Physical-device feel and the matching backend rollout remain acceptance items; prior eight compiler-raster golden failures and shutdown warnings are retained rather than claimed fixed.

## Considerably stronger slowdown — 2026-10-07

The owner rejects the .52 increase as barely noticeable and explicitly requests considerably more slowdown. **G01/T03:** `SCRAPE_FRICTION` rises from **0.18 to 1.0** and physics advances to **`arcade-planar-0.53`**. This keeps the same normal-impulse-based, dissipative response; it adds no timers, stored contact history, acceleration compensation or new dependencies. Swept geometry, skin, coherent normals, alignment, recoil and scrape/crash feedback separation stay as delivered.

The same compact 108 km/h, 2° brush now has **3.492%** tangent-speed loss on the first contact instead of **0.629%**. After one second:

| Input | Physics .52 | Physics .53 |
| --- | ---: | ---: |
| Coasting | 99.082 km/h; 28.511 m | **75.953 km/h; 24.276 m** |
| Full throttle | 135.430 km/h; 33.752 m | **110.858 km/h; 29.315 m** |

Exact values are retained in `evidence/strong-wall-drag-2026-10-07/physics052.json` and `physics053.json`. Inspected [new capture](evidence/strong-wall-drag-2026-10-07/after.png) / [previous capture](evidence/strong-wall-drag-2026-10-07/physics052.png) and the actual unclipped recorded `after.wav` accompany the measurements. This is appreciably stronger road-speed scrub, not a return to false contact freezes.

The owner-requested balance replaces the old 98%-retention/85%-cumulative-travel/light-scrub targets. Single 0.1–5° contacts must still retain at least **90%** of tangential speed. Across translated/rotated walls, each resolved tick still moves at least **50% of incoming tangential travel**, with no contact discontinuity of **20% or more**; progress stays positive. Energy, left/right symmetry, real blockers, immediate steering away, reverse, thin-wall sweeps, hard head-on recoil and exact replay assertions remain. New outcome checks additionally require the actual compact 2° one-second coast below **90 km/h**, powered contact below **120 km/h**, and both above **50 km/h** with continuous movement. These balance changes implement the explicit stronger-slowdown request; no geometry or timing/security invariant was removed.

Changed files: `game/track/playground_data.gd`, `game/vehicle/vehicle_simulation.gd`, `game/tests/test_shallow_collisions.gd`; the local backend `contracts.py`/`rivalry.py`, verifier/review assertions and oval expected physics pin; this report and status/phase/evidence. The oval's original inputs, track document and exact timing are retained. Historical .50 source/input checks remain. Concurrent road-gates **v20** changes are preserved rather than reverted; immutable current attempts pin .53 and old scores remain separate.

Actual commands use isolated `APPDATA=build/strong-wall-drag-2026-10-07/...`, exact Godot **4.7.2.stable.official.ed1daf0bf**, and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `TestScript` for `analyze_shallow_collisions.gd` and `test_shallow_collisions.gd`, `TestScript -Graphical` for the existing `capture_shallow_collisions.gd`, and full `Validate -CommandTimeoutSeconds 300`. Selected backend `test_verifier.py`, `test_review_reliability.py`, `test_rivalry.py` run with `-k 'not postgres'`; Python lint and scoped whitespace checks also run. Original command logs, final outcomes, hashes and the scoped patch are retained in `evidence/strong-wall-drag-2026-10-07`.

Behavioral **20,268** / diagnostic **14,820** checks pass, including actual slowdown targets under both pedal conditions. Selected backend **121** tests pass / **50 PostgreSQL cases deselected**. The native capture passes with no PCM clipping. Full regression's final outcome is recorded in `results.json`; retained raster-golden and ObjectDB-warning limits remain. No physical-phone driving/attachment check, export/install, live backend deployment or historical score migration was performed. Matching verifier rollout and owner/device feel acceptance remain open.

The actual full run parsed **332 scripts** and passed handling/replay, the new strong-scrub suite, original contacts, bridge exits, creator/geometry/hazard/kerb/ice/desert checks. A concurrent `ObjectRuns` editor addition invalidated the class cache during the storm stage and stopped the command with a parse error. An explicit pinned `Import` refresh followed by storm **91**, soil **163**, suspension **59**, records **54**, rewind **57**, personal ghosts **38**, camera **1,332**, cars **105**, kart **32** and historical replay **11** checks all completed with zero failures and aggregate command exit 0. This is not a full-green Validate claim. Existing ObjectDB warnings and earlier raster-golden limitations are retained. No unrelated editor source was reverted or altered.
