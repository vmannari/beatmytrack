# Race results - reference implementation (2026-09-21)

## Stacked incident legend and connected laurels - 2026-09-23

R01/V03/V05/Q01: collision and off-track labels now stack vertically. Route fitting reserves a left gutter using measured legend width plus stroke clearance, so arbitrary route geometry cannot cross the legend. Miniature previews retain their existing framing. PB title and yellow time are centered; original vector leaves start/end at exact points on the cubic laurel stem, replacing disconnected approximate ellipse placement.

Changed: `game/ui/lap_route_view.gd`, `game/ui/results_icons.gd`, `game/ui/race_results.gd`, `game/tests/test_race_results.gd`, status/plan/docs and refreshed evidence. Commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults` passed 168 checks; `TestResults` through the same entry point passed 154 checks. Added explicit full-stroke/legend-gutter regression. `git diff --check` passed for changed text. [Desktop screenshot](evidence/race-results/sectors-1280x720.png) inspected; three-size captures refreshed. No phone test/export performed. Owner visual review and physical-device acceptance remain.

2026-09-23 R01/V03/V05/Q01: Results back button uses an original thin yellow left arrow at the far left edge, with centered RESULTS text, matching the supplied action reference. Changed race_complete.gd and results_icons.gd; CaptureResults via scripts/dev.ps1 passed 163 checks and refreshed three-size evidence. Desktop screenshot inspected; no phone test/export.

## Race Complete navigation placement - 2026-09-23

R01/V03/V05/Q01: top-right Results replaced with an original outline home icon wired to Main Menu, with a Main menu tooltip. Bottom-left now reads `< RESULTS` and returns to preserved lap analysis. Tracks gains an original outline circuit icon, centered beside its label; its library/editor routing is unchanged.

Changed `game/ui/race_complete.gd`, `game/ui/results_icons.gd`, this document, status/plan and refreshed evidence. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults` passed 163 checks, including Results/Home/Tracks navigation and three-size layout. First capture exposed centered native icon/text overlap; replaced with a centered icon-label group and reran successfully. [Final screenshot](evidence/race-results/race-complete-1280x720.png) inspected. `git diff --check` passed for changed text. No phone test/export performed; owner visual and physical-device acceptance remain.

## Earned-only reward reveal - 2026-09-23

R01/V03/V05/Q01: owner requested earned-only rows and sequential rewarding presentation. `game/ui/race_complete.gd` now omits every ineligible/pending row, removes redundant eligibility subtitles, and adds coin marks. Empty eligible sets show a quiet no-rewards message. The existing provisional/no-wallet status remains accurate.

Page-bound tween starts after 0.18 s; each row fades/slides 16 logical pixels over 0.24-0.30 s, flashes a gold border that settles over 0.48 s, and counts the running total over 0.36 s. A 0.12 s pause separates rows. Navigation never waits for the animation; removing the page cancels its bound tween. Reopening replays presentation only, without writes or additional rewards.

Changed: `game/ui/race_complete.gd`, `game/tests/test_race_results.gd`, this document, DEVELOPMENT_STATUS.md, PHASE_0_PLAN.md and refreshed evidence. Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults` passed **163 checks**; same entry point `TestResults` passed **149 checks**. Tests cover earned-only count, initial hidden state/zero total, first-row-only reveal and final sum/visibility, alongside existing three-size and navigation checks. `git diff --check` passed for changed text files.

[First-row reveal](evidence/race-results/reward-reveal-first.png) and [completed reveal](evidence/race-results/race-complete-1280x720.png) captured; completed desktop layout inspected. Rewards remain provisional, without a persisted wallet. No phone test/export performed. Remaining: owner animation feel and physical-device touch/performance acceptance.

## Race Complete page and provisional rewards - 2026-09-23

R01/V03/V05/Q01; owner supplied Race Complete reference and reward schedule, then removed consistency and defined clean as no collisions/off-track excursions. Continue now opens `RaceComplete`: rewards left, actual race/best flying-lap times right, three real local track recommendations below, Main Menu / Tracks / Race [selected track] actions. Results button preserves analysis selection. Empty catalogs disable the race action; deleted recommendations are rejected on resolution. Existing editor return remains available.

Reward amounts: completed 50; first track 50; new race PB 100; new flying-lap PB 100; race and lap percentile tiers each top 50%=50, 25%=100, 10%=200, 1%=500; clean 200; challenge attempted 50; challenge beaten 100. Consistency is omitted. First recorded times establish baselines; PB preview requires beating an existing millisecond-quantized record. Clean requires a finished normal race, zero collision count and no recorded incident in complete lap telemetry; missing telemetry cannot establish clean.

Percentile rule: only a higher reward tier than the historical best rewarded tier qualifies, independently for race and lap. Improvement inside a tier, regression, and repetition award zero. Crossing several tiers qualifies only for the highest new tier amount (not the sum). Unit checks cover those boundaries. A future authoritative ledger must retain the best rewarded tier per player/track/pinned rules/metric and deduplicate awards; no percentile source or ledger exists in this local slice.

Scope/limits: this is explicitly a provisional reward breakdown, not a persisted currency balance. No wallet, reward writes or backend added. First-track history is unavailable across existing car/rules record keys, so its 50 is listed but not counted. Challenge state and global comparison distributions are unavailable; show honest pending states, never fabricated percentiles, histograms or rank-gap numbers. Amounts are editable in `RaceRewardPreview`. Only known completion/PB/clean eligibility contributes to the displayed total. Global reward services, cross-car visit history and challenge integration remain future work.

Changed: new `game/ui/race_complete.gd`, `game/ui/race_reward_preview.gd` and UIDs; `game/ui/results_icons.gd` (original coin/timer/flag vector icons); `game/core/app.gd` (capture pre-save PBs, completion facts and navigation); `game/tests/test_race_results.gd`; this document/status/plan and evidence. No canonical physics, replay, record schema or player files changed.

Actual commands via pinned Godot 4.7.2:
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults`: 144 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`: 157 checks, zero failures; three sizes, preserved Results return, recommendation selection and launch, five-lap target, Tracks and Home exits.
- `git -c core.safecrlf=false diff --check -- game/core/app.gd game/ui/race_complete.gd game/ui/race_reward_preview.gd game/ui/results_icons.gd game/tests/test_race_results.gd`: passed.

Initial expanded page check exposed 18 logical pixels of vertical overflow; reduced inherited card spacing and fixed recommendation content spacing. Final page fits 1280x720, 1920x1080 and 2400x1080. [1280 capture](evidence/race-results/race-complete-1280x720.png) inspected; [1920](evidence/race-results/race-complete-1920x1080.png), [2400](evidence/race-results/race-complete-2400x1080.png). Fixture times are real AI laps; local recommendation names are disposable test documents. No phone test, Android export or deployment performed. Owner visual review and physical-phone scrolling/touch/safe-area acceptance remain.

## Results detail follow-up - 2026-09-23

R01/V03/V05/Q01: owner-requested PB laurel decoration, equal 124-unit analysis buttons with original vector icons, sector table, KPI gauge/bars/trophy icons and two vertical separators, and lap times increased from 24 to 28. Table rows use the same sector boundaries and palette as the map, update with lap selection, and compare against the fastest valid lap in the current race (not historical PB telemetry). Missing telemetry/comparison is shown as a dash; other analysis modes hide the table. Continue flow remains intact.

Changed: `game/ui/race_results.gd`, new `game/ui/results_icons.gd` and UID, `game/tests/test_race_results.gd`, status/plan documents and refreshed race-results screenshots. Icons are original code-authored SVG artwork; no external image assets or runtime services.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` passed; `CaptureResults` passed **138 checks**, including three viewport sizes and navigation; `TestResults` passed **127 checks**. Tests verify sector values/deltas, visibility by mode and equal button widths. `git diff --check` passed. [Final desktop screenshot](evidence/race-results/sectors-1280x720.png) visually inspected: laurels, table, icons and separators visible. No physical-device test or Android export performed. Remaining acceptance: owner visual review and phone touch/safe-area checks. Historical PB sector telemetry remains unavailable.

## Results layout and Continue placeholder - 2026-09-23

Requirements R01/V03/V05/Q01; owner requests 1-10. This supersedes the recommendation strip and four-action navigation described below. Results now has only Race Again and Continue. Continue opens a separate placeholder with recommendations and rewards sections, Back to Results (retains analysis selection) and Choose Track (existing local library; editor return retained). No rewards or recommendations are fabricated or awarded.

The shorter total-time panel has one right-side PERSONAL BEST label and time, both yellow. Five lap rows share the recovered vertical space, with centered contents; longer lists retain scrolling. Analysis has more padding and height, ordered Sectors / Time diff / Speed, with Sectors initially selected. Existing route inspection, lap selection and measured statistics remain.

Changed files: `game/ui/race_results.gd`, `game/core/app.gd`, `game/tests/test_race_results.gd`, `game/tests/test_app.gd`, this document, DEVELOPMENT_STATUS.md, PHASE_0_PLAN.md and the race-results evidence captures. Existing unrelated working-tree edits retained.

Actual commands (pinned Godot via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`): `TestResults` passed 120 checks; `CaptureResults` passed 131 checks across 1280x720, 1920x1080 and 2400x1080; `TestMenus` passed 22 checks. Initial focused run failed an old map-relative lap visibility bound and a test string encoding error; corrected to assert enclosure by the actual scroll viewport and an explicit Unicode escape. No invariant was relaxed. `git diff --check` passed with existing line-ending warnings. The broader TestApp suite was not rerun (previous unrelated navigation failure documented below).

Desktop screenshots: [Results](evidence/race-results/sectors-1280x720.png), [next-page placeholder](evidence/race-results/next-race-placeholder.png). Visual inspection completed. No physical-device test, Android export or deployment performed; phone touch/safe-area acceptance and owner visual acceptance remain. Recommendations and reward listing are deliberately placeholders pending the next page design. Canonical physics is unchanged.

## Result eligibility and summary simplification — 2026-09-22

Requirement IDs: R01/R03/V03/V05/Q01. Pausing a production race no longer converts it into an unranked practice attempt. Shortcut history no longer invalidates completed-lap telemetry or prevents an otherwise completed race from updating its local record. Ordered checkpoint rules still require missed road gates to be recovered before the race can finish. Genuine editor practice remains unranked.

The `TOTAL RACE TIME` card now contains only the race total and `YOUR BEST`; result-status and comparison explanations beneath them were removed.

Changed files: `game/core/game.gd`, `game/core/app.gd`, `game/race/lap_telemetry.gd`, `game/ui/race_results.gd`, `game/tests/test_race_results.gd`, refreshed Results captures, and status documentation.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults` (**120 checks, zero failures**); `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults` (**130 checks, zero failures**); `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus` (**22 checks, zero failures**). The refreshed [1280 x 720 capture](evidence/race-results/speed-1280x720.png) was inspected at original resolution and shows the simplified card without stray spacing or explanatory copy. The first focused run exposed a test setup that attempted to toggle pause after marking the race finished; the fixture was corrected to exercise pause during an active race, after which the final suites passed.

No phone test, export or deployment was performed. Physical-device readability remains an acceptance check. Existing unrelated workspace changes were retained.

Owner request: landscape results screen following the supplied reference. Requirement mapping: R01/R03 (race flow and timing), V02/V03/V05 (presentation and mobile layout), Q01 (verification); task-specific RR01 summary/laps, RR02 telemetry map, RR03 recommendations, RR04 navigation, RR05 responsive layout.

## Sector leader clearance — 2026-09-22

Requirement IDs: V03/V05/Q01, RR02/RR05. Sector leader lines now terminate at the nearest edge of their allocated label rectangle instead of continuing beneath the two text rows. The existing track/incident/tooltip avoidance remains unchanged, and a geometry regression check covers labels approached from every side and diagonally.

Owner follow-up: the incident legend is now an explicit exclusion zone for sector-label placement, preventing Sector 3 from overlapping it on route shapes that reach the upper-left map area. The legend wording is shortened from “All tyres off track” to “Off track.” Tests measure the rendered legend width instead of relying on the former text length.

Changed files: `game/ui/lap_route_view.gd`, `game/tests/test_race_results.gd`, the three sector evidence captures, and status documentation.

Actual commands after the follow-up: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults` (**116 checks, zero failures**); `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults` (**126 checks, zero failures**). An earlier run corrected a boundary-test assumption about right/bottom-edge inclusion. `git diff --check` was clean apart from existing line-ending warnings. The refreshed [1280 x 720 sector capture](evidence/race-results/sectors-1280x720.png) was inspected at original resolution; leader lines and sector labels do not overlap each other or the legend. The capture suite also refreshed 1920 x 1080 and 2400 x 1080 evidence. No phone test or export was performed; physical-device safe-area and readability acceptance remain.

## Incident markers — 2026-09-22

Requirement IDs: R01/R03/V03/V05/Q01, RR02. Results now show red collision crosses and amber all-tyres-off-track diamonds for the selected lap in all three map modes. The map fits incident positions and includes a legend.

Changed files: `game/race/lap_telemetry.gd` records incidents independently of speed-sample decimation; `game/core/game.gd` calls the observer; `game/ui/lap_route_view.gd` draws markers; `game/tests/test_race_results.gd` tests wheel contacts, grouping, lap ownership, bridges and airborne exclusion. Status and phase documents updated.

All four wheel centres must leave native road materials and kerbs. Probes use vehicle dimensions and the current bridge layer. Authored dirt road counts as track, consistently with route validation. Airborne wheels do not begin an excursion. Each full departure gets one marker until rejoining. Sustained collisions are grouped until 0.25 seconds without collision. Markers use the resolved car centre at onset. Canonical physics and replay contracts are unchanged.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults` (**104 checks, zero failures**); the same entry point with `CaptureResults` (**114 checks, zero failures**); `git diff --check` (no whitespace errors, existing line-ending conversion warnings).

[Desktop marker screenshot](evidence/race-results/incident-markers-1280x720.png) uses explicit incident display fixtures over the real AI result; it does not claim those incidents happened in that AI run. Three-size desktop captures also pass. Owner visual acceptance and phone play/touch/performance checks remain. No phone test, export or deployment was performed. Events belong only to the current attempt, without historical storage. Existing unrelated workspace changes were retained.

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
## Delta-coloured sectors and end lines — 2026-09-23

Requirement IDs: R01/R03/V03/V05/Q01, RR02/RR05. In Sectors mode, each complete route sector now uses its measured time difference against the corresponding sector of the fastest valid lap: green is faster, grey is equal within 0.5 ms and orange is slower. The sector identifier in the table uses the same colour as its route segment. A contrasting transverse line is drawn at every sector end, including the final start/finish boundary, so adjacent equal-colour sectors remain visually distinct. The footer explains the colour meaning.

Changed files: `game/ui/lap_route_view.gd`, `game/ui/race_results.gd`, `game/tests/test_race_results.gd`, the three sector evidence captures, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. Existing unrelated workspace edits were retained.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestResults` passed **185 checks, zero failures**; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureResults` passed **204 checks, zero failures** and refreshed 1280 x 720, 1920 x 1080 and 2400 x 1080 captures. The final [1280 x 720 Sectors capture](evidence/race-results/sectors-1280x720.png) was inspected at original resolution: route/table colours agree and all three end lines are visible. No Android export or physical-device test was performed. Remaining acceptance: owner visual review and phone readability/safe-area check. Canonical simulation and timing are unchanged.
