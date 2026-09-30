# Premium race results - 2026-09-30

Requirements: V03 (results/UI), V04 (presentation), R01 (actual timing), Q01 (verification), owner reference requests 1-14.

The results use the actual finished race scene and selected car through a mip-blurred dark gradient. Main summary and visualization containers are transparent. The 94px race time is followed by the actual previous-PB difference and stored PB. A single earned achievement prefers a new PB, then a clean race, first finish, or completion. No percentile is fabricated; verified percentile data is not supplied to this screen.

Track is the default distance-based time comparison with measured sector time/delta labels directly on the larger route. Sectors exposes the existing detailed table; Speed retains sampled speed and touch/drag inspection. Deltas compare the selected lap with this race's fastest valid lap, not historical PB telemetry. Race-average speed is duration-weighted and top speed is the maximum recorded sample, independent of selected lap. Collision count represents recorded collision incidents (sustained contacts are grouped).

Five laps share one horizontal strip. Fastest is gold, collisions use a coral marker, and historical flying-lap PB/near-PB labels appear when applicable (near means within 0.050 s). Selection uses a quiet blue underline. Retry motivation uses the actual race PB deficit; ties and first benchmarks have appropriate text. Continue remains the existing Race Complete transition; its separate rewards/recommendations flow is unchanged.

Changed files: `game/ui/race_results.gd`, `game/ui/lap_route_view.gd`, `game/ui/results_backdrop.gdshader`, `game/tests/test_race_results.gd`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and the dated screenshot directory below. Canonical physics/camera unchanged; no new art assets or dependencies.

Actual commands:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults`
- `$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/premium-results-2026-09-30'`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`
- `C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe devices`: empty device list.

Final headless run: 195 checks, zero failures. Graphical final run: 212 checks, zero failures on pinned Godot 4.7.2 Compatibility. Covers 1280x720, 1920x1080 and 2400x1080 viewport bounds, five visible lap touch targets, mode switching, measured sector colors/times, stable race summary, route touch selection, retry, Continue and launching a shared recommendation. The first headless run exposed an encoding error in empty-data placeholders (fixed). The first capture exposed a pre-existing five-frame assumption while asynchronously loading a recommendation; the test now waits a bounded 600 frames for the actual expected track, retaining the identity assertion. Initial sector-label overlaps were fixed by searching available map space.

Evidence: [default Track](evidence/premium-results-2026-09-30/track-default-1280x720.png), [time comparison](evidence/premium-results-2026-09-30/time-diff-1280x720.png), [wide sector detail](evidence/premium-results-2026-09-30/sectors-2400x1080.png), [speed](evidence/premium-results-2026-09-30/speed-1920x1080.png). Default and wide sector captures visually inspected.

Remaining acceptance: owner visual approval, physical-phone readability/safe-area/performance, and unusual creator-route label layouts. No phone attached, Android export, or physical-device test. This keeps the real overhead finish scene rather than reproducing the reference's scenic rear-view illustration. Recorded telemetry without samples shows unavailable values. No online percentile added.


## Selection stability follow-up

Owner follow-up, 2026-09-30 (V03/V04/R01/Q01): selected/hovered laps must not move the separator or track; new fastest lap PBs must say Personal best; remove selection underlines throughout the shared menu style; mode-button normal icons must use the previous hover position.

Normal, hover, pressed, disabled and focus lap styles now use identical five-pixel padding. Selection is a subtle fill with no border. Shared MenuStyle tabs also use a fill instead of a bottom border. Mode buttons use twelve-pixel padding in every state, matching the previous hover position. Sector columns have fixed widths, and the map fits the route plus all race incidents together, so changing the selected lap cannot change the scale/center. Sector labels also reserve the same incident spaces for every lap. Selecting a telemetry point no longer relocates the sector labels.

The strip and heading use Personal best for a valid flying lap that improves the pre-race record (including the fastest lap); first valid flying records also qualify. Standing starts, practice and equal times do not claim a new record. Switching between Track and Sectors still intentionally allocates space for the detailed table; geometry is invariant across lap selection within each mode.

Additional changed file: `game/ui/menu_style.gd`. Existing results tests now exercise every lap in every mode at 1280x720, 1920x1080 and 2400x1080, with actual hover input. They compare map rectangles, all fitted route coordinates and lap-strip rectangles; check shared incident extents, PB eligibility and identical icon padding. Commands actually run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults`: 391 checks, zero failures.
- `$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/results-stability-2026-09-30'`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`: 408 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus`: 26 checks, zero failures.
- `C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe devices`: empty device list.
- `git diff --check`: passed.

[Fastest lap, no underline](evidence/results-stability-2026-09-30/track-default-1280x720.png) and [another lap, same track placement](evidence/results-stability-2026-09-30/time-diff-1280x720.png). Desktop default screenshot inspected. Owner visual approval and physical-device touch/readability remain; no phone attached, Android export or device test.
