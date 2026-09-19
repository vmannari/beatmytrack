# Knot tyre-pile impact performance — 2026-09-18

Requirements: R01/G01/V03/V05/Q01; owner reports severe stutter after hitting the dense tyre pile on Knot. Attached DN2103 / Android 13 / Mali-G77 MC9, pinned Godot 4.7.2. Knot contains 85 tyre stacks. This pass changes collision-query work, not collision outcomes, physical constants, iteration counts, graphics or camera.

## Reproduction

The debug probe loads the owner's local Knot (`track_1e3936d025fe7c82`), places the car at (-13,-24) heading south, gives it 24 m/s approach velocity, and holds ordinary quantized throttle into the existing pile. The ordinary race HUD is active. A three-second countdown precedes simulation; the probe excludes two seconds of warmup so the initial impact is included. It is unscored and cannot save an AI PB. The track file and tyre count are not changed.

Baseline: 45 seconds of sampling; 27 tyres moving at peak, 10,434 car/tyre contacts. Internal frame median **53.389 ms**, p95 73.056, p99 75.001, maximum 85.285. Of 867 sampled frames, 780 exceeded 25 ms. Simulation work accumulated per rendered frame had median 42.541 ms. This reproduces sustained severe slowdown while pressing against the pile, not merely a track-loading hitch.

## Implementation

- `game/track/native_track.gd`: `_contact` first rejects a completely clear contiguous band of rows with one native packed-array scan. The band includes extra columns, so an empty result conservatively proves the query is clear. Otherwise it rejects individual empty rows before constructing world coordinates. Nonempty rows read material directly by grid index; exact circle/normal/penetration calculations retain their existing order. Out-of-grid cells remain solid on both levels. Queries read current data, so no stale spatial index or cache invalidation contract is introduced.
- `game/vehicle/loose_tyres.gd`: overlap separation skips world queries only when the proposed correction rounds to the exact same stored `Vector2`. Such a query cannot alter the resulting position. Moving corrections, car impulses, friction budgets, all 16 solver iterations and four separation passes remain.
- `game/diagnostics/mobile_race_probe.gd`: adds the opt-in tyre-impact scenario and reports contact count plus peak moving tyres.
- `game/track/native_track_visual.gd`: caches the last presented position/spin for each tyre, avoiding unchanged MultiMesh transform uploads. Creation invalidates the cache; resetting simulation restores original transforms. This also benefits ordinary races with stationary tyres. The owner authorized other reproduced performance fixes during this pass.
- `game/tests/test_creator_refinement.gd`: graphical reset assertion for the presentation cache; CaptureRefinement passes 37 checks, including moving-tyre transforms and restored transforms. Headless TestRefinement passes 32 checks.
- `game/tests/reference_grid_contact.gd`: frozen original grid query and original tyre-solver adapter.
- `game/tests/test_grid_contact_equivalence.gd`: 20,500 exact contact comparisons over varied cell sizes, solids, empty regions, both levels, map edges/outside and in-place grid edits.
- `game/tests/test_pile_contact_equivalence.gd`: 2,400 exact full simulation-state comparisons with 85 touching tyres, varied impacts and a wall, against the original query **and** original tyre solver.
- `scripts/dev.ps1`: adds both differential suites to full validation. Existing frozen-solver differential tests also pass 12,000 full tyre-state comparisons.

The grid-only phone build returned to 16.558 ms internal median (p99 23.091), with simulation cost 7.639 ms per rendered frame. A clean actual-present sample had 1,854 intervals over 31.24 seconds: median 16.829 ms, p99 17.025, maximum 33.707, two missed refreshes.

The subsequent 90-second edge-impact run retained 27 moving tyres at peak and registered 21,352 contacts; median internal frame time was 16.532 ms. The display sample had two misses in 3,688 intervals / 62.10 seconds. However, a harder 36 m/s central impact at (-20,-24) still missed 444 refreshes in 61.49 seconds with the row-only scan. This result prevented acceptance and motivated the whole-band rejection described above. The final query and full-pile differential checks both passed again after that addition. Impact position and speed are configurable in the diagnostic marker.

The native container implementation was reviewed in [Godot's Vector source](https://raw.githubusercontent.com/godotengine/godot/master/core/templates/vector.h); correctness and performance are established by tests against the pinned installed engine, not assumed from upstream source. No persistent index or array-identity shortcut was introduced.

## Commands and checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_grid_contact_equivalence.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_tyre_equivalence.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_pile_contact_equivalence.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile_android_frames.ps1 -Seconds 60 -Output build/knot-impact/present-final
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRefinement
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureRefinement
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile_android_frames.ps1 -Seconds 20 -Output build/knot-impact/present-cache-clean
```

Actual domain runs: TestTracks 167, TestHandling 77, TestHazards 150, TestTyresLoad 26, TestSoil 113, TestIce 69, TestKerbs 31, TestSuspension 13 all pass. These include exact full-lap replay checks. Tyre equivalence and pile equivalence were repeated for the final solver change. Final export's import/startup/driving 70/catalog 18/menu 11 focused checks pass; attached-device install and launch succeed.

The full app suite is not claimed green: stale navigation and model-count integration failures remain documented in the earlier performance reports. Known acceptance limits: one phone and one targeted pile impact cannot establish every impact angle, full-map pile arrangement or thermal condition. Human Knot impact confirmation remains pending until the owner tests the updated build.

## Final attached-phone results

The whole-band query reduced the harder central-impact sample from 444 missed refreshes / 61.49 seconds to **14 / 61.25 seconds** (3,625 intervals, median 16.831 ms, p99 17.046 ms, maximum 33.756 ms). Both samples sustain ordinary throttle against the pile, with 29 moving tyres at peak. This is a large improvement, but not a zero-miss guarantee.

The final build also suppresses unchanged tyre-transform uploads. Its 90-second central-impact run recorded 11,328 contacts, 29 moving tyres at peak, internal median 16.584 ms, p99 23.051 ms, maximum 49.973 ms; 20 of 5,324 frames exceeded 25 ms. Presentation work median fell from 1.095 to 0.998 ms; this small run-to-run difference alone is not a statistically established gain. The first SurfaceFlinger capture includes an 8.08-second loading gap and is retained as contaminated evidence, not a gameplay result. A subsequent clean 21.53-second steady-pile sample has **two missed refreshes / 1,277 intervals**, median 16.831 ms, p99 17.046 ms, maximum 33.621 ms. This clean sample excludes the initial impact; the internal 90-second report includes it. Brief initial-impact spikes and occasional later missed frames remain, so perfectly constant frame rate is not claimed.

Tests: 34,900 exact differential comparisons across grid queries, tyre states and full pile simulation states pass. TestTracks 167 and TestHandling 77 were repeated after the final grid change and pass. Graphical refinement 37 checks pass after the presentation change. Export/install/launch passed on the attached DN2103. Test-only markers were removed and normal play relaunched; player tracks and records were preserved.

Installed APK SHA-256: `2A6E90DA5B34C025660666971E1BEDE3A2FC817AC358419407ED77D055ED888B`.

Evidence: [baseline](evidence/knot-impact/baseline.json), [harder impact before band rejection](evidence/knot-impact/present-center.json), [after band rejection](evidence/knot-impact/present-band.json), [final internal impact run](evidence/knot-impact/cache-final.json), [final clean display sample](evidence/knot-impact/present-cache-clean.json), [contaminated loading sample](evidence/knot-impact/present-cache.json), [phone screenshot after the impact](evidence/knot-impact/device-impact.png). The screenshot's 10,000-lap counter is the diagnostic's unscored protection; ordinary racing remains five laps.
