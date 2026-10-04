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


## Single record holder correction

2026-09-30, V03/R01/Q01: the earlier implementation compared each lap with the pre-race record and incorrectly labeled multiple improvements (or every flying lap in a first race). Only the fastest valid flying lap now qualifies for Personal best, provided it improves the old record or establishes the first one. Equal winning times choose the first occurrence. Superseded laps retain their normal delta; the old secondary LAP PB branch is removed. The strip and selected-lap heading share this rule. Near-PB hints apply only to laps at or slower than an existing record.

Changed files: `game/ui/race_results.gd`, `game/tests/test_race_results.gd`, this document and the two status documents. Regression fixture `[20,19,17,18,17]` exercises no previous record, several improvements over 21 s, matching 17 s and an unbeaten 16 s record; checks every strip label and selected heading, plus exactly one or zero PBs as applicable.

Actual command: `$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/single-lap-pb-2026-09-30'`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`. Result: 493 checks, zero failures, pinned Godot 4.7.2. `git diff --check` passed. `adb devices` returned no devices; no Android export/device test. Existing layout stability tests pass. [Isolated multi-improvement/tie fixture screenshot](evidence/single-lap-pb-2026-09-30/single-lap-pb-regression.png) inspected; this fixture intentionally has no route/telemetry. Owner acceptance remains.


## Lap-strip visual cleanup

2026-09-30 V03/V04/Q01: owner requests white text on all non-fastest laps, no collision markers in lap times, and a clearer selected background. `game/ui/race_results.gd` now retains white/gold text across normal, hover, pressed, focus and disabled states; only fastest is gold. The strip no longer checks collision events or draws collision markers. Selected fill opacity increases from 22% to 85%; unselected hover/focus is 30%, keeping actual selection distinct. Padding and border-free geometry stay fixed. Map incident markers and race incident statistics remain available.

Actual verification: `$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/lap-strip-2026-09-30'`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`: 493 checks, zero failures on pinned Godot 4.7.2, including lap hover/selection geometry and single PB checks. [Updated strip screenshot](evidence/lap-strip-2026-09-30/track-default-1280x720.png) inspected. `adb devices`: empty device list. No phone attached, Android export or device test; owner visual/device acceptance remains. Changed files: results UI, this document, both status documents and screenshot evidence.

## Translucent selected lap — 2026-10-03

V03/V04/Q01: owner requests a subtler selected-lap background matching the results style. `game/ui/race_results.gd` now uses the shared navy PANEL colour at 48% opacity instead of the old 85% blue fill, with the existing 5-unit corner radius and a 2-unit yellow top rule at 70% opacity. All selection interaction states share the treatment. Fixed padding, lap sizing and the border-free bottom remain intact.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor`; `git diff --check -- game/ui/race_results.gd`. CaptureResults saved all nine analysis-mode captures across 1280x720, 1920x1080 and 2400x1080 and emitted no selection/layout failures. The broader suite FAILED later on its existing local-recommendation expectation (`Race Complete recommends real local tracks`) and an out-of-bounds card index at test_race_results.gd:313; a full pass is not claimed. The recommendation path is outside this visual change. Doctor passed with pinned Godot 4.7.2/templates and DN2103 attached. Scoped whitespace check passed.

[Inspected selected-lap desktop screenshot](evidence/selected-lap-2026-10-03/speed-1920x1080.png). Other sizes/modes and a reviewable UI-only patch are retained in the same directory. Changed files: results UI, this document, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and dated evidence. Existing capture files were restored after copying this run into its own evidence directory. No Android export/install or physical-device test was performed. Owner visual/readability and phone touch acceptance remain; no mixed-workspace commit.

## Rivalry uses normal results first — 2026-10-04

WR08 / R01 / T01–T04 / GH01 / V03 / Q01: completed Weekly Rivalry races now use this same results screen, including all-time PB comparison, lap analysis and personal-ghost saving. Continue opens weekly verified position/points feedback; asynchronous verification leaves the summary open. Free Race continues to the existing RaceComplete screen. No results presentation changes were needed.

Actual integration: 29 native checks, zero failures, four desktop/compact captures; normal Free Race HTTP, app 96 and parser 277 pass. DN2103 attached; no device test or Android export/install. Files, exact commands, evidence and remaining acceptance: [Weekly Rivalry follow-up](WEEKLY_RIVALRY.md#normal-results-first--2026-10-04).
