# Race results - reference implementation (2026-09-21)

Owner request: landscape results screen following the supplied reference. Requirement mapping: R01/R03 (race flow and timing), V02/V03/V05 (presentation and mobile layout), Q01 (verification); task-specific RR01 summary/laps, RR02 telemetry map, RR03 recommendations, RR04 navigation, RR05 responsive layout.

## Implemented

- Compact header, fixed-width summary/lap column, expanding map panel, three local recommendation slots and bottom navigation. Navy translucent panels, thin borders, existing Barlow fonts and yellow selection/primary action. The existing race scene remains behind a darkened mip-blurred screen shader. Android display safe-area insets are applied.
- Actual completed race time, stored PB and signed gap against the previous PB. First finish, invalid/practice and storage-failure feedback remain explicit. Five selectable rows distinguish standing start, fastest valid lap and invalid laps. All five rows fit at the requested sizes; additional laps can scroll.
- Presentation-only telemetry observes the simulation after each canonical step. It starts at 20 Hz, retains exact lap boundary times and decimates long laps at 2,048 samples. Sample fields include lap index, race timestamp, lap elapsed seconds, world X/Z and planar position, normalized progress, speed in m/s and validity. No physics, rules, replay or record-key changes.
- Completed read-model boundary separates the UI from the vehicle controller. Route geometry is sampled once from the actual compiled track, aligned with the placed start line and fitted with preserved aspect ratio. Custom Control drawing renders crisp centreline segments and previews; no map textures or promotional images are generated.
- Speed colour, cumulative time difference against the fastest valid lap and automatic equal-distance sectors. Sector boundaries are an injectable normalized array for future editor definitions. Stops/reversing retain elapsed time with a monotonic progress domain. Touch, drag and mouse inspection select the closest recorded world position and show speed/elapsed time. Average speed is time-weighted; top speed is the sampled maximum.
- Replaceable recommendation provider returns real local track entries, geometry, category, lap count, estimate and reason. It excludes the current track and invalid creator documents. It uses length proximity and different-biome metadata; remote category identifiers are reserved without fabricating friends or popularity. Estimates currently use route length / 22 m/s, clearly marked approximate. All ordinary recommendations use the established five-lap rule.
- Tracks returns to the library; Race Again resets the same race and telemetry; Next Race resolves and starts the selected track with the current vehicle/handling selection. Missing/deleted tracks produce a notice. Lap analysis emits a lap-index navigation signal and opens an explanatory placeholder destination.

## Changed files

- `game/race/lap_telemetry.gd`, `race_result_data.gd`: observations, interpolation, sectors, completed read model and statistics.
- `game/ui/race_results.gd`, `lap_route_view.gd`, `race_recommendations.gd`, `results_backdrop.gdshader`: screen, vector visualization, provider and background.
- `game/core/game.gd`: recorder lifecycle and observation call only. Pre-existing camera/dust/handling edits are excluded from this checkpoint.
- `game/core/app.gd`: result data, recommendations, full-screen layout and Next Race integration.
- `game/tests/test_race_results.gd`: isolated real AI race, interaction/layout/integration tests and captures.
- `game/tests/test_app.gd`: result assertions updated for the requested Tracks label and signed PB wording; unrelated navigation assertions remain intact.
- `scripts/dev.ps1`: `TestResults` and `CaptureResults` entry points. Companion Godot UID files, evidence and status documents are included.

## Actual commands and outcomes

Commands run from the repository root with the pinned Godot 4.7.2 build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://ui/race_recommendations.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp
git diff --check
```

- Import passed after correcting initial PowerShell text encoding/line-ending errors; the intermediate CheckScript exposed that issue.
- Focused headless results run: 92 checks, 0 failures before the final two actual-time/record assertions were added.
- Final graphical results run: **103 checks, 0 failures**, including those final assertions and nine saved images. Earlier runs identified/fixed clipped lap rows, the Next Race subtitle layout and a test comparison that needed the established integer-millisecond record quantization.
- Quick validation: import/startup, 74 driving checks, 18 catalog checks and 22 menu checks passed. The driving suite reports its existing four-object exit leak warning. This command does not run full regression.
- Broad `TestApp` failed before reaching results: `Play exposes creator navigation`, followed by null-control access at lines 112 and 59. Its obsolete navigation expectation is unrelated to this results change and was not weakened. The hung test process was stopped. Results navigation is independently exercised by the focused suite.
- Final whitespace check is clean. No export, deployment or physical-phone test was performed. Full physics regression was not run because canonical physics is unchanged.

## Visual evidence

These are actual Godot Compatibility renderer captures. Crescent Run is an isolated generated creator-document fixture driven for five laps by the existing AI and simulation; shown timings/telemetry are observed data, not the reference's example numbers. The background is the actual test race scene. Recommendation names belong to disposable local test documents; no owner track files or records are altered.

| Size | Speed / tooltip | Time difference | Sectors |
| --- | --- | --- | --- |
| 1280 x 720 | [Speed](evidence/race-results/speed-1280x720.png) | [Time diff](evidence/race-results/time-diff-1280x720.png) | [Sectors](evidence/race-results/sectors-1280x720.png) |
| 1920 x 1080 | [Speed](evidence/race-results/speed-1920x1080.png) | [Time diff](evidence/race-results/time-diff-1920x1080.png) | [Sectors](evidence/race-results/sectors-1920x1080.png) |
| 2400 x 1080 | [Speed](evidence/race-results/speed-2400x1080.png) | [Time diff](evidence/race-results/time-diff-2400x1080.png) | [Sectors](evidence/race-results/sectors-2400x1080.png) |

## Remaining acceptance and deliberate limits

Owner visual acceptance and actual Android touch, cutout/safe-area and blur/frame-cost checks remain. The map is intentionally a clean procedural route outline, not the reference's aerial asphalt/scenery image. Wide screens give extra space to the map while preserving track aspect ratio and a 402-logical-unit lap column.

Telemetry lives only for the completed attempt; historical/PB telemetry storage and comparison are not implemented. Comparison interpolation is progress-based, not a detailed racing-line alignment algorithm. Invalid-lap elapsed sectors exclude timing penalties; the displayed lap/race totals retain penalties. Sampled peak speed may miss peaks between observations. Future throttle/brake/steering/events can extend the sample dictionary without coupling UI to the controller.

With fewer than three other valid local tracks, only available suggestions are shown; with none, Next Race is disabled with an explicit empty message. Online friends/trending/rivals and the full detailed-analysis page remain future work as requested. User imagery, generated art, services and runtime dependencies were not added.
