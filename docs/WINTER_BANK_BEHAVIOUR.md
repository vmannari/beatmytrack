# Packed Winter banks and pushed snow — 2026-10-12

The owner accepts the Winter appearance and requests much harder bank resistance, difficult movement inside a bank and visible snow being pushed. This local slice changes the driving interaction while preserving the accepted bank/road artwork, camera and prepared bank geometry. Owner acceptance of the strength and physical-device behavior remains open.

## Requirements and implementation

- WE38, harder entry: `game/track/snow_banks.gd` samples wheels, body center and both bumper overhangs. Swept, height-weighted drag dissipates fast entry and sideways travel without bouncing the car or counting a wall crash. Sweep work is bounded; ordinary 120 Hz travel remains within that bound.
- WE39, difficult movement and recovery: resistance has a strong speed-dependent term and a smaller crawling term. Full throttle and reverse can work the car out. All five cars are checked from rest and on entry; normal road handling stays exact against the captured physics55 implementation.
- WE40, pushed snow: `game/vehicle/sand_dust.gd` (`winter-spray-5`) adds two fixed 24-fragment pools. Scene-lit white clumps spread to opposite sides of the actual leading body contact, including below the previous 0.8 m/s spray threshold. Entry fragments and wheel snow remain. Stationary, airborne, elevated and clear-road cars stop the pushed snow. Restart/rewind cleanup includes both pools. The bank mesh remains fixed; displaced snow is represented by short-lived fragments.
- Q01: a half-metre spatial index selects the same prepared contact triangles in the same order. Dense samples and triangle boundaries compare bit-exactly to the original height kernel. Old prepared snapshots can fall back to that kernel. The heavier contact model measures roughly 0.03 ms per tick on this desktop after indexing. This is a standalone contact measurement, not whole-frame or phone timing.
- `game/core/game.gd` binds a sparse half-metre cosmetic height field derived once from the actual bank meshes, including clumps and bridge tapers. It contains 9,083 cells on the capture track and takes about 19–21 ms to rebake in the desktop diagnostic. Runtime particle height uses a few dictionary lookups, avoiding terrain raycasts/triangle searches. Its conservative local envelope keeps fragments above opaque irregular snow.
- G01/R01 and replay/pinning: `game/vehicle/vehicle_simulation.gd` advances `arcade-planar-0.55`→`0.56`. Inputs, snapshots, five ordinary laps, compiler geometry and trajectory verification format remain. Local records retain their earlier physics keys. A matching backend physics pin is required for online use; this task makes no production deployment or historical-board migration.

Companion changes: `game/tests/test_snow_bank_behaviour.gd`, export-excluded `fixtures/snow_bank_simulation_055.gd` and `soft_snow_banks_055.gd`, `game/tests/test_ice.gd`, `scripts/dev.ps1`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The older two-second soft-bank escape expectation is replaced by deliberately slow eight-second recovery, retaining forward/reverse escape checks for every car. Full Validate includes the new behavioral suite.

## Actual outcomes

All engine commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1` with PowerShell process execution policy Bypass and normal Windows certificate/graphics access. Graphics checks ran on an RTX 3090.

| Arguments after `scripts/dev.ps1` | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd -TestArgument @('--output-dir=res://../docs/evidence/winter-bank-behaviour-2026-10-12/headless')` | Final headless: 51,845 checks, 0 failures, including missing-index fallback |
| New suite with `-Graphical -TestArgument @('--capture')` | Compatibility: 52,032 checks, 0 failures; 180 actual driving frames, 80 frames pushing snow, two entry bursts |
| Previous row with `-RenderingMethod mobile` | Mobile Vulkan: 52,032 checks, 0 failures; same driving/contact outcomes |
| `-Action TestHandling`, `TestDriving`, `TestRewind` | Respectively 88, 72 and 61 checks, all pass; full diagnostic races and exact replay included |
| `-Action TestKerbs`, `TestSuspension`, `TestHazards`, `TestBridgeContacts` | Respectively 31, 59, 160 and 16 checks, all pass |
| `-Action TestIce` | 69 checks, 0 failures after contact-index optimization |
| `-Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd` | 80 checks, 0 failures; prepared Winter contacts/canonical driving remain exact |
| `-Action Doctor` | Pinned engine/templates found; DN2103 phone attached; no physical-device test performed |

The final headless suite verifies the last prepared-snapshot fallback addition. The preceding graphical captures verify the same optimized contact kernel and final effect rendering.

Actual local backend command: `./.tools/backend-venv/Scripts/python.exe -m pytest -q backend/tests/test_verifier.py::test_real_five_lap_race_replays_identically backend/tests/test_verifier.py::test_new_contacts_do_not_relabel_historical_inputs`: 2 passed, one existing Starlette/httpx deprecation warning. The retained ordinary fixture remains exactly 12,757 ticks with lap ticks `[2634,2532,2531,2530,2530]`. Backend fixture/pin edits made concurrently by another task are preserved and excluded from this checkpoint.

| Car | Speed after 0.3 s bank entry, new / old (m/s) | Two-second bank crawl, new / old (m) |
| --- | --- | --- |
| Compact | 0.760 / 11.983 | 2.293 / 10.636 |
| Pickup | 1.799 / 12.951 | 1.820 / 10.170 |
| Classic | 0.743 / 11.760 | 2.418 / 10.640 |
| Formula | 0.928 / 10.899 | 1.510 / 9.454 |
| Kart | 0.600 / 7.343 | 2.005 / 8.607 |

Entry starts at 20 m/s. These are controlled comparisons against the frozen wheel-only force on identical bank geometry, not accepted balance targets. All cars power across the bank and reverse back onto ice within the recovery test. Exact JSON trajectories at batches 1/2/4/8 and restored impact-state futures pass. Non-bank driving across all five biomes matches physics55 exactly.

The first contact benchmark with coarse buckets took about 744 µs per call on the desktop. Final indexed measurements are approximately 29–30 µs; the geometry/height comparisons ensure this optimization does not change contact results. Sequential samples vary with machine load. Two active particle draws and at most 48 additional short-lived fragments replace any need for continuous large clouds. No phone frame-time, thermal or touch-play claim is made.

Initial failures are retained: a rewind fixture captured at tick25 instead of its normal tick24 stride; that fixture was corrected. The GPU visibility check then caught particles hidden inside the taller cosmetic banks; the actual mesh height bake fixes their origin. An initialization-order failure from binding before `SandDust` existed was corrected with the initial post-construction binding and a guard on later weather updates. No failing requirement was removed. Final hidden/shown GPU probes measure 301 Compatibility and 269 Mobile pixels belonging to the pushed fragments at contact.

## Evidence and acceptance

[Driving motion](evidence/winter-bank-behaviour-2026-10-12/motion.html), [pushed snow](evidence/winter-bank-behaviour-2026-10-12/push-visible.png), [Mobile motion](evidence/winter-bank-behaviour-2026-10-12/mobile/motion.html), [all-car measurements](evidence/winter-bank-behaviour-2026-10-12/headless/measurements.json), [contact cost](evidence/winter-bank-behaviour-2026-10-12/contact-profile.json). The closer inspection camera is confined to this evidence; the gameplay camera remains unchanged.

Restart the client and try a fast bank entry, sustained throttle inside it and braking/holding reverse to recover. Owner acceptance remains for force strength, snow visibility and all-car feel. No Android build/install or phone behavior/performance test, full all-domain Validate, production deployment or live write was performed. Existing online contracts must use the new physics pin; this task does not silently change committed tickets or PBs.

The isolated task-only Git checkpoint/source patch is under `build/winter_bank_behaviour`. Concurrent Desert, reflection, prop and backend work remains; the shared validation script patch contains only the new snow-bank entry. Main Git index/HEAD are preserved. Motion HTML remains in workspace evidence instead of being duplicated in the checkpoint.
