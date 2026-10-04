# Race loading screen — 2026-10-04

Owner request: “add loading screen for the races when loading the track”. Requirements: R01 (race navigation), V03/V04 (shared menu presentation and readable layout), V05 (device acceptance), Q01 (actual verification and evidence).

Race now opens a full-screen loading view with the actual track title, its route outline, selected vehicle, biome and five-lap/untimed-practice label. Existing original discovery biome artwork, Barlow fonts, navy panels and yellow accents are reused. No new art, dependencies or asset licensing assumptions were introduced.

The overlay is laid out and drawn before synchronous track/world construction. Online Free Race ticket preparation and Weekly Rivalry tickets, track download/compilation and ghost preparation are covered. Its activity bar is indeterminate; stage labels describe actual work and do not invent percentage progress. No artificial minimum wait is imposed.

The prepared game has processing disabled until its first rendered frame. Initial camera/HUD presentation runs with zero presentation delta; simulation, race timer, recorded inputs and all 360 countdown ticks remain untouched. The overlay then disappears and the normal countdown begins. Untimed editor practice uses the same world-loading screen without adding a countdown. Restarting an already loaded race does not rebuild its track and retains its existing restart flow.

Preparation consumes input and rejects repeated launches. Existing navigation/account/vehicle/selection fences remain. Navigation removes stale overlays; instance IDs make later asynchronous cleanup safe after the overlay has been freed. Ticket failure restores the existing offline-race choice, and rivalry failures restore the rivalry view.

Changed files:

- `game/ui/race_loading.gd` and `.uid`: loading presentation and input blocker.
- `game/core/app.gd`: loading lifecycle, preparation/render fences, frozen scene construction, rivalry preparation and awaited creator launch.
- `game/tests/test_race_loading.gd` and `.uid`: isolated real transition, frozen countdown, duplicate start, interrupted navigation, practice, ticket failure and graphical layout/capture checks.
- `game/tests/test_app.gd`: wait for asynchronous library/practice launch completion.
- `game/tests/capture_cars.gd`, `capture_premium_menus.gd`, `review_creator_usability.gd`, `test_construction.gd`, `test_control_layout.gd`, `test_creator_refinement.gd`, `test_hazards.gd`, `test_race_results.gd`, and `game/diagnostics/mobile_race_probe.gd`: await their existing direct launch calls.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and the evidence directory below.

Actual commands and outcomes (all `scripts/dev.ps1` commands use `powershell -NoProfile -ExecutionPolicy Bypass -File`; engine is pinned to `4.7.2.stable.official.ed1daf0bf`):

| Command | Actual outcome |
| --- | --- |
| `scripts/dev.ps1 CheckScript -ScriptPath res://ui/race_loading.gd` | Passed after sandbox log access was resolved with execution approval. |
| `scripts/dev.ps1 Import` | Passed; generated both new script UIDs. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | Final: 291 scripts, zero failures. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_race_loading.gd` | 20 checks, zero failures. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_race_loading.gd -Graphical` | Final: 81 checks, zero failures; actual transition and all five biomes at 1280×720, 960×540 and 1600×720 captured. |
| `scripts/dev.ps1 TestApp` | 97 checks, zero failures. |
| `scripts/dev.ps1 TestConstruction` | 104 checks, zero failures. |
| `scripts/dev.ps1 TestMenus` | 48 checks, zero failures. |
| `scripts/dev.ps1 BackendTestLifecycle` | Final isolated canonical HTTP cloud-race and track-lifecycle suites: 2 passed. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_http.py -k test_weekly_rivalry_through_native_app -q` with repository `backend` on `PYTHONPATH` and the pinned `GODOT_BIN` | Real native Weekly Rivalry ticket/download/ghost/race/results integration: 1 passed, 4 deselected. Disposable backend only. |
| `scripts/dev.ps1 TestResults` | Failed at the existing local-track recommendation fixture, before its later rating/card actions. This fixture still expects three local recommendations although current Race recommendations use published backend tracks. No assertions or production admission rules were weakened. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_cloud_tracks.gd` without its HTTP harness | Failed: the required replay fixture/API environment was absent. The correct `BackendTestLifecycle` harness above was then used. |
| `scripts/dev.ps1 Doctor` | DN2103 physical phone and emulator-5554 attached; pinned templates found. No race-loading-specific device test was performed. |
| `git diff --check -- <changed source files>` | Passed. |

Initial attempts are not counted as passes. App tests first exposed old synchronous expectations; their launch waits were updated. Graphical interruption then exposed a freed typed overlay argument; cleanup now uses instance IDs. The first countdown assertion sampled after normal physics had already resumed; the final assertion samples the overlay's tree-exit boundary and verifies exactly 360 ticks there. The first correctly configured cloud HTTP run reported an unrelated menu comparison assertion; the subsequent correctly configured run passed both suites. Concurrent menu/emulator work was retained.

Evidence: [actual loading transition](evidence/race-loading-2026-10-04/race-transition-1280x720.png), [compact Desert loading](evidence/race-loading-2026-10-04/loading-desert-960x540.png), plus all other biome/size captures in `docs/evidence/race-loading-2026-10-04/`. Desktop/compact captures were visually inspected. Verification logs and the scoped source checkpoint are saved alongside them; the checkpoint excludes unrelated concurrent edits and is reverse-apply checked rather than committing the mixed workspace.

Remaining acceptance: owner visual/transition acceptance, physical-phone loading and safe-area checks, sustained device performance, and fixing the historical Results recommendation fixture independently. Track visual construction remains synchronous; the loading artwork remains visible during this work, while its animation can pause during a main-thread build. Editor draft validation/compilation before entering the shared race launcher is unchanged. Diagnostic direct `--track`/`--demo` playground launches remain outside the menu loading flow. No Android export/install, phone/emulator gameplay, backend deployment/restart or full physics/replay regression was performed by this task; canonical physics and rules were not changed.
