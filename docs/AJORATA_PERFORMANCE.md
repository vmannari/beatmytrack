# Ajorata phone frame pacing — 2026-09-18

Requirements: owner follow-up on racing stutter; G01 deterministic handling, R01 Android racing, V03/V05 presentation, Q01 measured device performance. Device: attached DN2103 / Android 13 / Mali-G77 MC9. Pinned Godot 4.7.2. This is a debug APK installed in place, preserving the phone's tracks and records.

## Changes

- `game/vehicle/loose_tyres.gd`: compute fixed contact geometry once per physics step, preserving impulse order. Skip zero-effect stationary impulses and stationary world-contact queries. Keep overlap separation, friction budgets, moving-body sweeps and all 16 active solver iterations.
- `game/track/native_track.gd`: reject non-fluid scenery before calculating oil/puddle containment.
- `game/core/game.gd`: calculate the visual water-depth footprint once per frame. Optional composition-level profiling measures simulation, rules, AI and presentation; timing never enters canonical simulation.
- `game/diagnostics/mobile_race_probe.gd`: opt-in debug marker selects an existing local track; bounded unscored drive exercises timed route validation, records tail timings and distance/laps. No AI personal best is saved.
- `scripts/profile_android_frames.ps1`: collect and deduplicate Android SurfaceFlinger actual-present timestamps. Internal process intervals alone do not establish display smoothness.
- `game/tests/legacy_tyres_reference.gd`, `test_tyre_equivalence.gd`: frozen original solver and 12,000 exact whole-state differential comparisons, including resting stacks, collisions, piles, walls and elevated cars. Added to full validation in `scripts/dev.ps1`.

No handling constants, physics tick rate, track data, camera framing or graphics quality changed in this pass. Existing mobile 0.667 render scale, shadows and 2x MSAA remain.

## Measurement method and baseline

The owner's Ajorata is `track_acf29166cceaaa42`: 16 road pieces and 24 tyre stacks, plus scenery. Each initial comparison samples 45 seconds after 5 seconds of warmup. The probe uses the timed route validator but an unscored practice container; therefore the screen still says Practice. AI has additional CPU cost and is not a substitute for human driving acceptance.

Before optimisation, scale 0.667/shadows on: internal frame median 16.543 ms, p95 20.224, p99 22.359, max 37.363; 7/2673 frames over 25 ms. Simulation composition cost median 7.026 ms per rendered frame, p99 10.693. Lowering scale to 0.5 did not improve the tail meaningfully (p99 22.231). Disabling shadows also did not help (p99 23.292). This supported targeting CPU work first.

The first tyre-only pass reduced simulation cost to 6.020 ms median but did not improve the internal frame tail (p99 22.629). Its overlapping actual-present sample across subsequent stages was much steadier: 5,397 intervals across 90.89 seconds, median 16.831 ms, p99 17.051, three intervals over 25 ms. That sample includes a diagnostic stage restart and different graphics stages; it is not final acceptance.

Final sustained test: 185 seconds including warmup, 1,573 m driven and three completed laps. Median simulation composition cost fell from 7.026 to 4.288 ms (39%); p99 fell from 10.693 to 6.824 ms. Presentation cost fell to 1.047 ms median. These are separate device runs, not controlled CPU-frequency measurements. Internal frame p99 remained 22.499 ms, so internal timing alone does not show the stutter solved.

The overlapping Android actual-present trace during that run contains 7,198 intervals across 121.19 seconds: median 16.832 ms, p95 16.971, p99 17.034, maximum 33.801. Two intervals exceeded 25 ms. A screenshot was taken during that collection; its effect cannot be separated from gameplay.

**Clean repeat, same installed build and graphics:** 7,249 actual-present intervals across 121.99 seconds; median 16.829 ms, p95 16.971, p99 17.044, maximum 18.001; **zero intervals over 25 ms / zero missed refreshes observed**. No screenshot or stage reset during this sample. The phone reports thermal status 0. The measured display cadence is about 59.4 Hz, not mathematically 60.000 Hz. This establishes a smooth bounded Ajorata device run, not a guarantee across longer/hotter sessions, all tracks or other phones. [Clean display trace summary](evidence/ajorata-performance/present-clean.json).

After measurement the diagnostic marker was removed, the app stopped and relaunched normally. Original player files and records were not replaced. Remaining acceptance: owner's human-driven five-lap Ajorata race and longer warmed-device sessions.

Evidence: [baseline](evidence/ajorata-performance/baseline.json), [sustained game timings](evidence/ajorata-performance/sustained-final.json), [display timings](evidence/ajorata-performance/present-final.json), [device screenshot](evidence/ajorata-performance/ajorata-racing.png).

Tests actually run:

- Exact frozen-solver equivalence: 12,000 complete state comparisons pass, repeated after the inactive-solver fast path.
- TestTyresLoad 26, TestDriving 70, TestHandling 77, TestTracks 167, TestHazards 150, TestKerbs 31, TestIce 69, TestSoil 113, TestSuspension 13, TestRouteValidation 55: all pass. TestHazards repeated after the fluid containment filter, also 150 pass.
- TestCars: 95 checks, four failures in the pre-existing `body.get_child_count() > 10` visual assertion for pickup/classic/formula/kart after the preceding mesh-batching pass. All 15 five-lap driving and exact replay cases complete. This pass leaves the failing assertions intact. The dedicated prior batching tests compare retained triangle counts, bounds, materials and wheel behaviour; see MOBILE_FOLLOWUP.md.
- TestKart: its first suite passes 32 checks; its follow-on car suite reports 71 checks / the same four visual-count failures. Kart five-lap replays pass on all three diagnostic circuits.
- Final DeployAndroid -QuickValidation: import, startup, driving 70, catalog 18 and menus 11 pass; install and launch succeed on the attached phone.

Installed APK SHA256: `D82B89B0FF97907B3E525F420656F121DCF8446CAF30513354BBB23F77767264`.

## Commands and reproducibility

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestTyresLoad
# Frozen-reference differential run (also included in full Validate):
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_tyre_equivalence.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile_android_frames.ps1 -Seconds 120
```

The device probe config is `{"track_id":"track_acf29166cceaaa42","seconds":180,"sustained":true}` at the app's `files/mobile_probe.json`, installed through authorized ADB `run-as`. Results are in `files/mobile_probe_results.json`. Remove the marker and relaunch to return to normal play. Local build/test logs are under `build/ajorata-performance/`.

Engine references consulted: [Godot frame pacing settings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-display-window-frame-pacing-android-enable-frame-pacing) and [jitter/stutter guidance](https://docs.godotengine.org/en/4.6/tutorials/rendering/jitter_stutter.html). Swappy/VSync settings remain at their existing defaults; no unmeasured pacing-mode change was applied.

Full `Validate` was already known to stall/fail in stale app-navigation tests (`test_app.gd`), documented in MOBILE_FOLLOWUP.md. This pass runs the relevant physics/replay domains separately and does not claim the entire app integration suite passed. Further device models, thermal conditions and human driving remain acceptance work.
