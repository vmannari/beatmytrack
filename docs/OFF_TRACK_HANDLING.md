# Off-track wheel response

Date: 2026-09-20  
Requirements: G01, G03, R01, R03, R07

The owner requested a faster penalty when leaving the track and a handling response when only some wheels leave it.

## Terrain steering texture tuning - 2026-09-22

The loose-ground tyre-deflection peak increases from 1.15 to 1.45 rad/s². It remains a small bounded addition to yaw acceleration, scales from one to four loose-surface wheel contacts, fades in with speed, and is zero on asphalt. Two world-space waves provide irregular left/right variation without runtime randomness, wall-clock input or display-rate dependence, so identical input and terrain still replay exactly. Physics identity advances to `arcade-planar-0.38`; stored records are retained but no longer compare across the changed rules key.

Changed files:

- `game/vehicle/vehicle_simulation.gd`
- `game/tests/test_soil.gd`
- `DEVELOPMENT_STATUS.md`
- `docs/PHASE_0_PLAN.md`
- `docs/OFF_TRACK_HANDLING.md`

Actual commands and outcomes:

- Pinned Godot 4.7.2 `--check-only` parses passed for `vehicle_simulation.gd`.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 -Action TestSoil`: 163 checks passed. Measured spatial disturbance range was -0.693 to +1.443 rad/s², inside the 1.45 bound; full-soil speed after 0.5 seconds remained 15.322 m/s.
- `... -Action TestDriving`: 74 checks passed, including exact JSON replay and camera framing. Godot reported two existing leaked ObjectDB instances at exit.
- `... -Action TestHandling`: 88 checks passed, including exact replays and three diagnostic OFFROAD laps.
- `... -Action TestKart`: its kart phase passed 32 checks. The command later failed in the chained car suite on the four existing pickup/classic/formula/kart detailed-model steering-wheel/body checks (71 car checks, four failures); no handling failure was reported.

Known limits and acceptance: this is deliberately mild terrain texture, not a scripted pull or retained spin. Owner feel approval during sustained grass and sand driving remains required. No physical-phone test or Android export was performed.

## Implemented behavior

- All five vehicles now sample loose-surface contact at the four canonical wheel centres, including elevated-deck isolation. Previously this was enabled only for the kart.
- Soil drag is proportional to the number of affected wheels. Full grass/dirt contact uses stronger speed-dependent scrub, while one- and two-wheel excursions react before the chassis centre leaves asphalt.
- Unequal left/right contact adds a bounded yaw demand toward the wheels in soil. It is deterministic, reverses with travel direction and disappears on rejoin.
- Physics identity advances from `arcade-planar-0.29` to `arcade-planar-0.30`; old PB records remain stored but are not comparable under the new rules key.

At 24 m/s, the focused two-wheel edge fixture measured 18.408 m/s after 0.5 seconds versus 23.738 m/s on clean asphalt, with 18.372 degrees of heading pull. The kart edge fixture measured 8.242 m/s after one second. These are synthetic boundary tests, not claims about every track geometry.

## Changed files

- `game/vehicle/handling_config.gd`
- `game/vehicle/vehicle_simulation.gd`
- `game/tests/test_soil.gd`
- `game/tests/test_kart.gd`
- `DEVELOPMENT_STATUS.md`
- `docs/OFF_TRACK_HANDLING.md`

## Actual verification

Commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestSoil`: 116 checks, zero failures.
- `TestKart`: 32 checks, zero failures.
- `TestDriving`: 74 checks, zero failures; its existing four ObjectDB shutdown leaks remain.
- `TestHandling`: 88 checks, zero failures, including exact JSON replays and three diagnostic laps on each retained fixture.
- `TestRecords`: 53 checks, zero failures.

`TestCars` was attempted but did not emit results and was stopped after hanging in headless startup; it is not reported as passed. No screenshot was required for this non-visual canonical change. No phone was attached and no physical-device test was performed.

## Remaining acceptance

- Owner feel check for whether the edge pull is strong enough without feeling like an artificial snap.
- Physical-phone driving check, especially rapid leave/rejoin behavior under touch steering.
- Full regression suite and cross-car balance suite before merging this physics change.

## Stronger follow-up - 2026-09-20

The owner found the initial impact too mild. Physics `arcade-planar-0.31` raises the bounded asymmetric pull from 0.85 to 1.10 rad/s at full side imbalance and increases both the constant and speed-dependent soil scrub. The lower-speed fade now reaches full strength at 14 m/s rather than 16 m/s, while crawl-speed escape remains available.

At 24 m/s, the same half-second two-wheel edge fixture now finishes at 16.885 m/s with 21.848 degrees of heading pull, compared with 18.408 m/s and 18.372 degrees in physics 0.30. Full-soil speed is 15.322 m/s after half a second. The kart edge fixture finishes at 6.596 m/s after one second, compared with 8.242 m/s in physics 0.30.

Follow-up validation: `TestSoil` passed 125 checks, `TestDriving` passed 74 and `TestRecords` passed 53. The kart portion of `TestKart` passed 32 checks. That command then continued into the chained car suite, where 67 of 71 checks passed and four existing detailed-model steering-wheel/body checks failed for pickup, classic, formula and kart; the chained command is therefore not reported as passed. Total relevant passing checks for this follow-up: 284. The driving test reported two ObjectDB instances at shutdown. No phone was attached and no device test was performed.

## Single-tyre near-spin follow-up - 2026-09-20

The owner requested that catching even one tyre off track should almost spin the car. Physics `arcade-planar-0.32` raises asymmetric soil yaw demand from 1.10 to 4.80 rad/s at full side imbalance. One binary wheel contact creates 2.40 rad/s demand before the existing per-car maximum-yaw clamp. A deterministic 60-tick (0.5-second) verge-catch state retains that rotation after a corner probe clears; equal left/right contact does not begin a new spin. The response retains the speed fade below 18 m/s and reverses with travel direction. Replay snapshots include the catch duration and strength.

The exact one-tyre fixture enters at 24 m/s and measures 54.211 degrees of heading rotation, 2.194 rad/s remaining yaw and 22.567 m/s speed after half a second. The two-wheel edge fixture measures 53.338 degrees and 15.830 m/s; full balanced soil retains zero soil-induced yaw and measures 15.322 m/s.

Actual validation: `TestSoil` passed 127 checks, `TestDriving` passed 74, `TestHandling` passed 88 (including exact replays and retained three-lap fixtures), and `TestRecords` passed 53. Total: 342 checks, zero failures. `TestDriving` reported two ObjectDB instances at shutdown. No phone was attached and no physical-device test was performed.

## Natural verge-tug correction - 2026-09-20

The owner rejected the 0.32 single-tyre response as unnatural. Physics `arcade-planar-0.33` replaces the forced 60-tick near-spin with an 18-tick (0.15-second) tyre-load transient and reduces one-wheel yaw demand from 2.40 to 1.60 rad/s. Normal yaw response still eases the rotation in and out, so a brief contact unsettles the car without dictating a half-second spin after rejoining. Strong proportional speed loss remains unchanged.

The exact one-tyre fixture now rotates 16.542 degrees over half a second and settles to 0.014 rad/s remaining yaw, versus the rejected 54.211 degrees and 2.194 rad/s in physics 0.32. It retains 23.411 m/s from a 24 m/s entry. Sustained two-wheel contact remains severe at 47.272 degrees and 15.988 m/s because those tyres remain continuously loaded by the verge.

Actual validation: `TestSoil` passed 128 checks, `TestDriving` passed 74, `TestHandling` passed 88 and `TestRecords` passed 53. Total: 343 checks, zero failures. Exact replay and the retained three-lap fixtures pass. `TestDriving` reported two ObjectDB instances at shutdown. No phone was attached and no physical-device test was performed.

## Differential wheel-drag correction - 2026-09-20

The owner reported that the authored transient still felt unnatural and could disappear while cornering. Physics `arcade-planar-0.34` removes the timed verge-pull state. Each contacted wheel now contributes longitudinal soil resistance on its side of the car. The left/right force difference becomes angular acceleration using vehicle mass, half track width and rotational inertia, and is applied independently after steering response. It therefore adds to or opposes the current corner rather than being masked by the steering yaw target. Equal left/right soil contact cancels torque, contact removal ends torque immediately, and no hidden rotation timer remains. Strong proportional speed loss is unchanged.

On the first 120 Hz tick, one tyre produces 0.053 rad/s yaw versus zero for the clean car. A dedicated established-corner check verifies that the same force changes existing steering yaw in the physically correct direction. A momentary one-wheel touch leaves no scripted spin: after half a second it has rotated 1.097 degrees and returned to zero yaw. Sustained two-wheel contact produces 18.499 degrees and reduces 24 m/s to 17.003 m/s in half a second; balanced full-soil contact produces no differential torque and finishes at 15.322 m/s.

Actual validation: `TestSoil` passed 130 checks, `TestDriving` passed 74, `TestHandling` passed 88 and `TestRecords` passed 53. Total: 345 checks, zero failures. Exact replay and retained three-lap fixtures pass. `TestDriving` reported four ObjectDB instances at shutdown. No phone was attached and no physical-device test was performed.

## Loose-surface shake and steering texture - 2026-09-21

The owner requested grass-equivalent shake on sand and small irregular steering impacts on both surfaces. Physics `arcade-planar-0.36` separates presentation roughness from drag: native grass and sand now both request full speed-scaled off-road camera rumble, while asphalt requests none. Canonical handling adds a small yaw acceleration from two fixed spatial waves, weighted by the number of wheels on grass/sand and speed. This is deterministic from position, has no random or display-rate dependency, varies in both directions and stops immediately when all wheels return to the road. Differential wheel-drag torque and longitudinal penalties remain intact.

At 20 m/s with four loose-surface wheel contacts, the five-position fixture spans -0.550 to +1.145 rad/s² of irregular yaw acceleration. Partial contact scales by wheel count. The existing physical verge metrics remain effectively unchanged: first-tick one-wheel yaw is 0.071 rad/s, sustained two-wheel contact produces 22.755 degrees and 16.789 m/s after half a second, and balanced full soil finishes at 15.322 m/s.

Actual validation: `TestSoil` passed 160 checks, the dedicated camera-shake suite passed 6, `TestDriving` passed 74, `TestHandling` passed 88 and `TestRecords` passed 53. Total: 381 checks, zero failures. Exact replay and retained three-lap fixtures pass. `TestDriving` reported two ObjectDB instances at shutdown. This is a motion-only presentation change, so no static screenshot was produced. No phone was attached and no physical-device test was performed.

## Stronger physical wheel torque - 2026-09-20

The owner accepted the differential-force behavior but requested a slightly stronger impact. Physics `arcade-planar-0.35` adds a 1.35 loose-verge bite coefficient to the wheel-force moment. Longitudinal soil drag, wheel sampling, contact duration and steering response remain unchanged; there is still no retained or scripted yaw after contact ends.

First-tick one-wheel yaw rises from 0.053 to 0.072 rad/s. A momentary contact rotates 1.481 degrees and returns to zero yaw. Sustained two-wheel edge loading produces 22.726 degrees over half a second, compared with 18.499 degrees in physics 0.34, while speed remains comparable at 16.790 m/s. Full balanced soil remains 15.322 m/s with no differential torque.

Actual validation: `TestSoil` passed 130 checks, `TestDriving` passed 74, `TestHandling` passed 88 and `TestRecords` passed 53. Total: 345 checks, zero failures. Exact replay and retained three-lap fixtures pass. `TestDriving` reported four ObjectDB instances at shutdown. No phone was attached and no physical-device test was performed.
