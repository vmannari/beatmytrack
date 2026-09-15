# Development status

2026-09-15 V02/V03/V05/Q01/R01: minimap roads cached separately from the player marker and reduced to thin placed-road lines. Desktop redraw callback ~6 ms to ~0.05 ms; 95 graphical checks pass. [Measurements, capture and device limits](docs/MINIMAP_PERFORMANCE.md).

2026-09-15 V02/V03/V04/V05/G01/R01/R07: reference-shaped HUD, icon menu, raised pedals and blue/concrete bridges; minimap exclusively follows placed road pieces on new creator tracks. 264 focused checks pass. [Evidence, commands and phone acceptance](docs/REFERENCE_HUD.md).

2026-09-15 V02/V03/V04/V05/G01/R01/R07: bridge steel rails and shaded deck fascia refined; racing HUD uses navy/cream/gold Barlow styling with separate lap, timer, actions and compact speed. 412 focused checks pass. [Actual captures, commands and phone limitations](docs/BRIDGE_HUD.md).

2026-09-15 V02/V04/V05: kerb crown/bevel/base shading strengthened for normal gameplay-camera readability; physical height and response unchanged. 195 focused checks pass. [Captures and acceptance limits](docs/KERB_READABILITY.md).

2026-09-15 G01/V02/V04/V05/R01/R03/R07: raised kerbs share 10 cm bevelled geometry with deterministic tyre contact and a small spring/speed response. Physics 0.21, compiler-10, recorder schema 7. [Actual checks, captures and device limits](docs/RAISED_KERBS.md).

2026-09-14 G01/R01/R03/R07: Original+ keeps Original steering with slightly more slide and stronger nose-directed throttle. Unchanged Original remains selectable. Physics 0.20 / handling-0.15-original-slide. [Measured behavior, actual checks and remaining feel/device acceptance](docs/ORIGINAL_SLIDE.md).

2026-09-14 G01/R01/R03/R07: restored Original handling as startup default and exposed a visible handling selector in normal races and creator practice. [Behavior, 201 passing focused checks, screenshot and phone limits](docs/HANDLING_SELECTOR.md).

2026-09-14 G01/R01/R03/R07: focused fun-handling iteration adds progressive steering/front traction, deliberate brake rotation, faster countersteer recovery, tyre scrub audio and Planted/Balanced/Playful/Baseline comparison. Handling-0.14 / physics 0.19. [Actual checks, controls, evidence and remaining human/phone acceptance](docs/HANDLING_FUN.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred biome/rename dialogs, keyboard-aware rename placement, taller rail, transparent header and grey disabled Test. [Checks and captures](docs/EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred editor rail, simplified header/menu, biome and waypoint tools, fixed object paging and independent WIP autosave. [Actual checks and captures](docs/EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: Curvy follow-up removes folded marking tails and cap-directed kerb spikes. [Actual checks and closer captures](docs/KERB_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05: reference layout follow-up: grouped raised rail, green text-only Test, track name, charcoal tiles, road glyphs and Jump in Objects. [Actual checks and captures](docs/EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 G01/R01/V02/V04/V05: traversable water with gradual car submersion and separate long-lived oil / short-lived water tire coatings. [Behavior, actual verification and device limits](docs/SURFACE_RESPONSE.md).

2026-09-14 R01/T01-T04/V02-V05: unified editor controls, two-row asset browser, contextual options, direct object dragging and a mapped oblique planning view with refined prop meshes. [Actual captures, checks and remaining art acceptance](docs/EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 R01/T01-T04/V02/V04/V05: shared road joins, gradual connected widths and road-aligned full-width start line. [Implementation, checks and Curvy/Blind spot captures](docs/ROAD_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05/G01: reference-led object browser, grouped variants, single/line/curve/road-edge placement, movable lightweight props and a central future biome availability hook. [Implementation, tests, screenshots and bounds](docs/OBJECT_BROWSER.md).

2026-09-14 R01/T01-T04: editor Load now shows all saved tracks immediately; empty search no longer hides the list. [Fix, actual checks and screenshot](docs/EDITOR_LOAD_LIST.md).

2026-09-14 R01/T01-T04: saved tracks and unfinished drafts now have confirmed deletion, including recovery-file cleanup and library/selection refresh. [Actual checks, screenshots and limits](docs/USER_TRACK_DELETION.md).

2026-09-14 V02/V04/V05/R01/T01-T04/G01: tapered kerb tips, solid/selectable scenery trees, scalable rock/cliff variants, matching bridge asphalt/guardrails and deterministic ramps/oil/shallow water. Physics 0.16 / compiler-7 / track-kit-11. [Behavior, actual checks, screenshots and limits](docs/CREATOR_HAZARDS.md).

2026-09-14 V02/V04/V05: track-kit-10 gives each kerb run complete equal blocks with white beginnings/endings. Actual screenshot and 138 passing checks: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-9 integrates original painted grass, mipmapped detail, broad colour variation and a broken grass/gravel blend from the new texture direction. See docs/VISUAL_STYLE.md for actual captures/checks and PAINTED_GRASS_PROMPT.md for generation provenance.

2026-09-14 V02/V04/V05: track-kit-8 corrects flat-mesh normals, removes microscopic edge segments causing sand spikes, separates terrain layers and filters sand grain. Actual captures/tests: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-7 fixes kerb spacing along actual edge distance, closes segment seams, procedurally roughens shoulders and omits sand behind kerbs. Actual checks and Silmukka capture: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05 follow-up: corrected grass, branch shapes, decorative stone scale, grey tree footprints and creator roadside shoulders/inner kerbs. Track-kit-6 actual Silmukka screenshot and checks are recorded in docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V03/R01/V05: reference-led woodland visual revision, shared textured materials, irregular pines, selective outlines and driving-control icons. See [docs/VISUAL_STYLE.md](docs/VISUAL_STYLE.md) for actual evidence and acceptance limits.

2026-09-14 G01: tyre contact now supports sustained pushing, stronger impact slowdown and cumulative pile resistance (physics 0.15). [Implementation, measured checks and acceptance limits](docs/TYRE_PUSHING.md).

2026-09-14 tyre/load follow-up: stronger tyre sliding resistance and car impact (physics 0.14), searchable editor Load, same-ID resaving and correct unfinished-draft map previews. [Measured before/after response, checks and future shared-version lock policy](docs/TYRE_RESISTANCE_AND_LOADING.md).

2026-09-14 creator follow-up: solid placed trees/rocks, road-safe terrain painting, free tyre lines and deterministic movable stacks, explicit endpoint connection, variable curve angles, visible Save and recoverable local drafts/racing. [Implementation, tests and acceptance limits](docs/CREATOR_REFINEMENT.md).

2026-09-13 direct construction: body dragging, anchored endpoint dots, desktop pan/zoom/shortcuts and authorable two-level bridges implemented in creator-track-v5. [Behavior, validation and remaining acceptance](docs/CREATOR_CONSTRUCTION.md).

2026-09-13 creator usability review: eight reproducible issues recorded, led by race-route readiness, variable-width connections and invalid-drag persistence. Existing 96 workflow checks pass; new isolated review scenarios reproduce the gaps. No application fixes in this checkpoint. [Findings and proposed order](docs/CREATOR_USABILITY_REVIEW.md).

2026-09-13 wireframe creator revision: full-screen shared 3D scenery, Road/Surface/Objects/Race rail, contextual palettes, place-and-snap road sections, direct radius/lead-in/width handles, roadside barrier/tyre/fence runs, start-obstruction recovery and untimed practice with Edit here. V4 drafts retain free painting and separate lap routing. Ordinary races remain five laps. [Implementation and actual evidence](docs/WIREFRAME_EDITOR.md). Desktop acceptance checks pass; phone reach, safe areas and performance remain untested. Android prerequisites are missing.

2026-09-13 full-screen creator: Create now fills the viewport, with collapsible tool/settings overlays, anchored 16× zoom, crisp adaptive grid and 0.5 m detail brushes. Targeted UI/creator/replay checks pass; physical-phone acceptance remains open. [Full-screen editor evidence](docs/FULLSCREEN_EDITOR.md).

2026-09-12 race presentation: car-led pit scene, first-run invitation, returning-player PB target and precise retry debrief replace the generic dashboard. Five laps, searchable circuits and favorites remain. See [Race presentation](docs/RACE_PRESENTATION.md) for requirements, reviewed screenshots, actual tests and prototype-asset/phone limitations.

2026-09-12 free-form editor: the owner selected free-shaped roads, terrain, intersections and obstacles. Paint/Pan, round/square surface brushes, a separate lap route and native-track Remix replace the spline-only editing model. V3 creator format; five-lap crossing/replay and full regression checks pass. See [Free-form editor](docs/FREE_FORM_EDITOR.md) for commands, screenshots and unperformed phone acceptance.

2026-09-12 track discovery follow-up: visual route cards, a dedicated Tracks tab, persistent favorites, combined name/creator search, theme filtering, natural sorting and filtered random selection replace sequential browsing. The paged metadata index is checked with 5,000 entries and builds no more than six track cards. All ordinary races and creator test drives now use **five laps**, with separate record rules preserving old three-lap partitions. Current evidence, commands and remaining acceptance: [Track library and five laps](docs/TRACK_LIBRARY.md).

2026-09-12 editor follow-up: sharp/smooth corners, 6–20 m per-node widths, touch object stamping/moving/rotation/copy/delete, stable JSON identity and v2-only creator files are implemented. Full validation and 42 graphical editor checks passed. [Editor revision 2](docs/EDITOR_V2.md) records behavior, Slicks research, evidence and remaining phone acceptance.

2026-09-12 menu follow-up: adapted Hill Climb Racing 2's selected-event/Race structure into a direct circuit-and-car race hub with Race/Garage/Create tabs and separate Settings. Graphical integration passed 86 checks; screenshot and commands: [HCR2 menu review](docs/HCR2_MENU_REVIEW.md). Full validation passed driving/original/extra tracks but encountered six creator failures during concurrent creator-format work. No phone test performed; owner menu acceptance remains open.

Updated: 2026-09-12. The owner has **accepted car handling and collisions** and explicitly authorized **local menus, additional Slicks circuits, a phone-friendly creator and shared track themes**. This is the active slice, covering selected P1/P3 local features. Physical-phone handling, camera calibration and performance acceptance remain open; this does not complete all blueprint gates.

## Current slice: menus and track studio

The project now opens a vehicle-led Play menu with Garage, Tracks, Create and Settings. Seven Slicks-derived circuits are selectable, including Pine Loop, Dune Run and Coast Oval. The creator starts from a valid smooth loop: drag/add/remove large handles, move the start, choose Pine/Coast/Desert, asphalt/dirt and 8–14 m road width, undo/redo, pan/pinch/zoom, view native 3D scenery, test drive, save and import/export/share locally. All three themes use the same native cells and art kit in previews and driving. No power/progression sale or racing gate was added.

Production menu races use a separate three-second countdown, five laps, results, immediate retry and recoverable local PBs with a separate flying-lap record. They remain explicitly unverified local times using the current ordered practice checkpoints; competition-grade shortcut validation remains unfinished. Existing developer handling/replay tools remain available through explicit `-Track` launches.

Full implementation details, actual final validation, screenshots and remaining manual acceptance are recorded in [docs/MENUS_AND_CREATOR.md](docs/MENUS_AND_CREATOR.md), [creator format](docs/CREATOR_FORMAT.md), [additional Slicks conversions](docs/MORE_SLICKS.md), [shared themes](docs/TRACK_THEMES.md) and [local records](docs/LOCAL_RECORDS.md). Earlier sections below are historical checkpoints; their requests to approve handling are superseded by the owner's acceptance above.

Android Doctor was rerun: matching templates, SDK/ADB/build-tools and JDK remain missing. Device attachment could not be enumerated; **no physical-phone test or APK export was performed**.

Next acceptance: try the complete create → preview → test drive → return → save/share/import flow; evaluate the new track art and extra circuits. Then complete Android setup and the actual phone usability/thermal session. Online leagues, progression, commerce and hosted publication remain deferred.

## Completed

- Replaced the bootstrap screen with one drivable original compact car and a flat handling yard: braking lane/distance markers, two skid circles, concrete collisions and non-colliding slalom cones.
- Added isolated typed planar simulation, fixed 120 Hz quantized controls, acceleration/braking/delayed reverse, speed-sensitive steering, lateral/longitudinal grip, recoverable slip, mass/yaw inertia, countersteer assistance and throttle rotation.
- Handling parameters live in Resources. Stable/Balanced/Loose presets, F2 live tuning and F6 reload make comparisons quick. Restart restores the same initial state immediately.
- Added a high-oblique fixed-yaw camera, bounded look-ahead, render interpolation, original matte car geometry, steering wheels/brake lamps and a capped skid-trail pool. Initial framing uses baseline / 1.15; full reference calibration is pending.
- Keyboard and simultaneous touch adapters work. Focus/background loss pauses and clears inputs. Added optional speed/longitudinal/lateral/slip/input/yaw/grip/FPS/tick telemetry.
- F3 records up to two minutes of quantized controls with handling/physics metadata and periodic states, then saves a local diagnostic JSON. No backend/analytics.
- Added 56 passing driving/replay/input/lifecycle/tuning/camera checks to the validation wrapper. Exact same-engine replay passed for 2,400 ticks at four render batch sizes; Android remains untested.
- Inspected real Windows driving captures. Guide: `docs/DRIVING_PLAYGROUND.md`; evidence: `docs/evidence/driving-playground.png` and `docs/evidence/driving-tests.txt`.

- Reviewed the full blueprint package, all supplied visual references/UI screens, camera contracts, architecture, roadmap/backlog and nine-sheet financial model. The 71 manifest entries match their supplied SHA-256 hashes. Original package files are preserved unchanged.
- Documented definitive requirements, contradictions, exact repository/module structure and eight ordered tasks in `docs/PHASE_0_PLAN.md`.
- Found and pinned Godot standard `4.7.2.stable.official.ed1daf0bf`. PATH's 4.6.2 engine is deliberately rejected by the wrapper.
- Created `game/project.godot`, minimal runnable composition scene, module directories and keyboard input actions. Configured landscape, Compatibility baseline and 120 Hz physics setting.
- Added Git ignore/attributes/editor conventions, project agent instructions, asset provenance notes and developer README.
- Added `scripts/dev.ps1`: doctor, import/parse/startup validation, Windows run/editor/capture, Android debug export/install/launch/deploy. Export validates first and publishes an APK filename only after success.
- Added an arm64 Android Debug preset, SDK/template guidance and exact future device-test instructions. Android tooling setup and execution remain open.
- Captured and inspected actual Windows startup: `docs/evidence/bootstrap-windows.png`.

## Four-track handling fixtures completed (2026-09-11)

Implemented the explicit Slicks handoff request: `slicks_freeway_test`, `slicks_1way_test`, `slicks_66_test`, `slicks_offroad_test`. Development-only programmatic conversion produces native geometry at 0.25 m/source pixel (9 m reference road, five 1.8 m car widths). Source checkpoint order/start markers, layered crossings, native materials and deterministic surface/collision behavior are preserved or explicitly inferred. OFFROAD alone needed a data-driven post-pair spacing correction, 1 m outward per post. F5/Track selects fixtures; F4/F7 inspect geometry/source overlays; F9 runs diagnostic AI. The yard remains the default.

Actual final validation: import, 23 parses, startup, 56 driving checks and 48 track checks passed; four converter tests passed. Every track completed three laps with zero AI contacts. Complete three-lap JSON replays exactly matched states and lap times in eight-tick batches on Windows. Both bridge levels were traversed on 1WAY, 66 and OFFROAD. Actual graphical overviews were inspected against all four references, plus a moving 1WAY capture. FREEWAY is the recommended first benchmark. Full results, commands, changed modules, widths, known assumptions and remaining manual checks: [SLICKS_IMPORT.md](SLICKS_IMPORT.md). Evidence: `docs/evidence/slicks-*` and `slicks_*`.

This does not complete Phase 5: practice timing starts immediately; no countdown, persistent PB or competition-grade shortcut verification. Bridge height transitions were subsequently corrected with shared ramp geometry; collision remains a planar prototype (see docs/RAMP_FIX.md). Human playtesting, camera calibration and phone acceptance remain pending. Doctor actually failed missing templates/SDK/ADB/build-tools/JDK; attachment could not be enumerated and no physical-phone test or APK export occurred. Physics identity is now arcade-planar-0.5 for surface/layer support; diagnostic manifest schema 2 includes extended state and native content hash. Existing yard handling assertions remain unchanged and pass.

## Previous handling iteration

Inspected owner's speculative Slicks handling analysis and implemented a focused G01 pass: handling-0.7 / arcade-planar-0.4. Faster steering input/yaw response, progressive slip grip, and no preset throttle-induced yaw/grip loss or automatic countersteering. Retained moderate corner scrub and planted grip from prior feedback. Simulation/config/presets/HUD tuning range/tests changed; rationale and intentionally deferred suggestions documented in docs/DRIVING_PLAYGROUND.md. Validate passed import, 17 parses, startup and 56 checks. New tap/trajectory-lag and throttle-pull tests pass; powered slip 10.0 degrees, coasting turn ends at 100.6 from 108 km/h. Inspected scripted Windows capture docs/evidence/driving-momentum.png and updated test evidence. Restart F8/F5 and evaluate steering taps and turn-in/lift/unwind/throttle in Balanced. Original-game equivalence is not verified. Physical Android and owner acceptance remain pending.


## Smaller car and faster turning ? 2026-09-12

G01 / V01 owner feedback: the tracks still did not feel fun; car slightly too big and too slow to turn. Handling-0.8 scales the physical car to 88%: base body 3.74 x 1.584 m, wheelbase 2.244 m, circular collision radius 1.364 m. Shared BODY_SCALE drives car mesh, wheelbase/collision defaults, rear skid axle/spacing and mark width. This is the owner's explicit physical-size adjustment, not the earlier 1.15 camera-calibration operation. Camera, roads and source package remain unchanged. The reference 9 m road now spans about 5.68 body widths rather than five.

Steering angle increases 0.60 -> 0.65 rad, yaw limit 2.2 -> 2.7 rad/s, Balanced lateral grip 50 -> 58 m/s?; Stable/Loose grip 60/50. Quarter-turn radii at initial 43/65/86 km/h improve from 7.87/10.62/14.84 m to 6.38/8.73/12.40 m. Powered corner slip is 13.0 degrees (within the existing 18-degree guard); acceleration/top speed remain 2.13 s to 100 km/h and 165.6 km/h. Single-circle body approximation remains a limitation.

Actual `scripts/dev.ps1 Validate`: first attempt crashed natively during parsing (exit -1073741819); fresh invocation passed all 23 parses, startup, 56 driving checks and 48 track checks. All four diagnostic AI runs completed three laps with zero contacts and replay checks passed. No failed handling invariant was relaxed: the island overlap check now uses the configured physical radius, and the legacy steering comparison explicitly retains its original wheelbase. Graphical FREEWAY launch/capture succeeded and was inspected: docs/evidence/smaller-car.png. Updated driving and track evidence retained. No Android test was performed; human fun/handling acceptance remains open.

Restart the running project from the editor, select FREEWAY with the Track button/F5, then choose 2/Balanced. Try turning into its tight bends and switching left/right; compare available clearance and whether the car turns soon enough without sliding wide. F5 inside the running game selects tracks.

## Next

1. Owner drives Balanced, Stable and Loose on Windows; adjust response and recovery based on a concrete maneuver and preferred preset. This is the immediate feedback request.
2. Phase 3: precise reference-camera fixture/bounds measurement and comparison at 1672×941; evaluate every heading and wider screens.
3. Phase 4/5: owner evaluates the four authorized practice circuits; complete countdown, persistent PB and full race validation separately after handling feedback. Native circuits, ordered practice checkpoints and three laps now exist. No progression/store/backend.
4. Complete Android prerequisites and the actual APK/device loop, including safe areas and real simultaneous touch. Iterate phone feel before final art/content expansion.

## Unresolved decisions

- Physical target phone/model, Android version and USB availability. ADB is not installed/configured here, so no device was enumerated and attachment state is unknown.
- Actual camera projection/pitch/extent: calibrate to the supplied target, not invented camera metres. World yaw stays fixed for acceptance.
- Compatibility versus Mobile: baseline is Compatibility; final choice requires the same visual scene profiled on phone.
- Handling balance and touch layout require driving. No claim that generic drift code will satisfy the intended feel.
- Package p95 targets differ: ≤20 ms in Q01/master, ≤16.7 ms in visual acceptance. Report both, aim for the stricter visual target, and record actual traces.
- Cross-device replay equivalence remains an explicit future test gate.

Resolved override: **three laps**, per the current owner request, replaces the package's original four-lap first task. Package content remains unchanged. PB will mean best valid full race with a separate flying-lap record. Store/economy assumptions stay deferred.

## Technical debt and limitations

- Four practice circuits, checkpoints and three-lap timing now exist; countdown, persistent PB and competition validation remain absent. Handling yard itself has no lap-duration claim. No audio/haptics or final graphic-novel material/outline pipeline; default toon materials and simple geometry are stand-ins.
- Single circular car collision approximation does not match exact front/side body clearance. Cones are deliberately non-colliding. Real phone safe-insets/handedness/layout work remains.
- Diagnostic replay JSON is capped but not compact, not a trusted competition record, and not an atomic progress save. A new save replaces the diagnostic file. R/tuning/profile change discards unsaved recording; pause saves it. Cross-device float equivalence remains unproved.
- Android export preset and install/launch commands are prepared but cannot be end-to-end verified without matching templates, SDK/ADB and JDK. Minimum Android 10/arm64 is a prototype proposal, not a tested device-support claim.
- Godot import prints `Unable to open Android 'build-tools' directory.` because the configured SDK does not exist. Windows import/parse/startup still succeed; Doctor correctly fails Android readiness.
- Release signing/Play submission and production asset notices are later distribution gates. No release build or production asset is claimed.
- The isolated `.tools/review` Python environment was used only to inspect documents/images/workbook and run supplied contract examples. It is ignored and not a runtime dependency.

## Actual validation

Commands ran from `C:\Codes\Godot\Beat my track` with PowerShell `-NoProfile`:

| Command / check | Actual outcome |
|---|---|
| Godot 4.7.2 console `--version` | `4.7.2.stable.official.ed1daf0bf` |
| Package manifest SHA-256 comparison | 71 entries checked; zero mismatches |
| `.tools/review/Scripts/python.exe -X utf8 -m unittest discover -s Android_racing_game_blueprint_v2/technical/tests -v` | 24/24 pass; documentation/schema examples only |
| Initial bootstrap `scripts/dev.ps1 Capture` | Exit 0: one script, bootstrap startup and graphical capture; retained historical evidence |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Expected exit 1: matching Android template, SDK/ADB/build-tools and JDK missing |
| `Validate -GodotPath C:\apps\Godot\Godot_v4.6.2-stable_win64_console.exe` | Expected exit 1: exact engine pin mismatch |
| Temporary malformed GDScript through `Validate` | Expected exit 1: syntax error detected; probe removed afterward; evidence saved |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` after removing the probe | Exit 0: clean import, one script parsed, main-scene startup passed |
| Driving `scripts/dev.ps1 Capture` | Exit 0: import, 17 script parses, `PLAYGROUND_READY`, driving regression checks and graphical capture |
| Godot `--headless --path game --script res://tests/test_driving.gd` | Latest suite: 56 checks, zero failures; includes JSON replay/diagnostic save and scene integration |
| Godot `--path game -- --demo --capture=.../build/driving-demo.png` | Exit 0: rendered 400 physics ticks of scripted acceleration/turn, screenshot inspected; synthetic demo, not human playtest |

The Windows capture reports NVIDIA GeForce RTX 3090 / OpenGL 3.3.0. This is desktop rendering evidence, not a phone performance measurement. The braking test covered 16.35 m versus 31.53 m coasting over 1.33 s from 24 m/s. Power produced -10.0 degrees corner slip versus -4.9 degrees lifting. Same-engine JSON replay had zero final-state divergence for batches of 1/2/4/8 ticks. No APK export, ADB installation, Android launch, physical-phone test or driving-feel approval was performed. Three-lap automated practice-circuit tests are recorded in the newer four-track section above.

## Manual tests needed from owner

Open `game/project.godot` in Godot 4.7.2 and press F5, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
```

Use W/Up throttle, A/D or Left/Right steering, S/Down/Space brake (hold at rest to reverse), R restart. F1 toggles telemetry, F2 tuning, 1/2/3 selects Stable/Balanced/Loose. First drive Balanced at 60–80 km/h, turn toward a circle, lift and countersteer, then repeat with the other presets. Report which preset you prefer and whether response is delayed, too twitchy or difficult to recover. See `docs/DRIVING_PLAYGROUND.md` for the detailed session and recording commands; Android setup remains in `docs/ANDROID.md`.

The first subjective evaluation is immediate steering response and whether deliberate countersteering/throttle changes reliably catch a slide. After the circuit exists, record ten consecutive lap times and whether braking/line choice visibly improve them. Stop expansion and tune handling if that loop is not enjoyable.

## Bridge ramp correction — 2026-09-12

G01/G02/V01/R02: replaced bridge height snaps with spatial ramp meshes, axle-sampled car height/pitch and slope-following skid marks. Validate passed 24 parses, startup, 56 driving checks and 57 track checks. All four tracks completed three AI laps with zero contacts and exact replay; all three bridge tracks retained ground-level underpasses. Actual Windows captures were inspected. Changed files, commands, measured continuity and remaining manual acceptance are recorded in [docs/RAMP_FIX.md](docs/RAMP_FIX.md). No phone test or APK export was performed. Canonical simulation and native track data remain unchanged.

## Soft objects and coherent track materials ? 2026-09-12

G01/G02/R03/V01/V02 owner feedback: vegetation and low obstacles now slow the car rather than colliding; substantial walls, structures, rails and deep water remain blocking. Native schema/content v2, physics arcade-planar-0.6 and refreshed golden fixtures accompany the surface change. The original matte track kit adds clearer surface contours, curb paint, low cover and clean barrier sides. Validate passed 24 parses, startup, 56 driving + 76 track checks; four converter tests and all four native schema validations passed. All tracks completed three zero-contact AI laps with exact replay and continuous ramps. Final Windows screenshots were inspected. Changed files, actual commands, intermediate test/capture limitations and remaining human/phone checks: [docs/TRACK_SURFACES.md](docs/TRACK_SURFACES.md). No physical-phone test or APK export occurred.

## Ramp overlap recovery - 2026-09-12

G01/G02/R03/R01: inspected the owner's stuck 1WAY window (281 contacts), reproduced outward-motion rejection on all three bridge tracks, and fixed existing-overlap escape plus collision checks before layer transitions. Physics is arcade-planar-0.7; native geometry, surfaces and visuals are unchanged. Validate passed 24 parses, startup, 56 driving + 94 track checks. Held reverse fully clears each tested rail with zero contacts; all four three-lap AI runs and exact replays remain unchanged. Live screenshot, before/after logs, changed files, actual commands and limitations: [docs/RAMP_RECOVERY.md](docs/RAMP_RECOVERY.md). The old running instance was preserved; close/relaunch to load the fix. No phone test or APK export occurred.

## Visible collision rebound - 2026-09-12

G01 owner feedback: handling-0.9 increases shared restitution from 0.12 to 0.38. Runtime change is confined to HandlingConfig; rebound regressions were added to test_tracks.gd. In the held-throttle head-on test, separation rises from 0.183 to 1.443 m. Glancing impacts retain tangential movement while losing energy. Validate passed import, 24 parses, startup, 56 driving + 96 track checks; all four AI three-lap runs, exact replays and ramp escape checks pass. Physics algorithm/version and native content remain unchanged. Actual commands, evidence, changed files and remaining manual/phone acceptance: [docs/DRIVING_PLAYGROUND.md](docs/DRIVING_PLAYGROUND.md#collision-rebound---2026-09-12). No phone test or APK export occurred. Close/relaunch to load the new defaults.

## Collision direction and larger bounce - 2026-09-12

G01 owner feedback: handling-0.10 / physics arcade-planar-0.8 adds a bounded, energy-budgeted impact yaw impulse and raises restitution to 0.55. Reverse-speed limiting preserves impact recoil while still capping powered reverse. Angled test hits rotate heading by 9.369 degrees in 0.2 s; powered head-on separation is 3.736 m versus the prior 1.443 m. Validate passed import, 24 parses, startup, 56 driving + 107 track checks, including full lap/replay, ramp escape, energy and reverse-limit tests. Changed files, actual commands, test-fixture correction and remaining manual/phone acceptance: [docs/DRIVING_PLAYGROUND.md](docs/DRIVING_PLAYGROUND.md#impact-rotation-and-stronger-recoil---2026-09-12). No phone test or APK export occurred.

## Sustained wall contact - 2026-09-12

G01: native barriers now preserve checked tangential movement; low-speed rubbing gently aligns the car while hard impacts keep their bounce. Handling-0.11 / arcade-planar-0.9. The mirrored standstill test travels 8.918 m in 3 seconds and aligns within 0.934 degrees without penetration. TestTracks passes 115 checks, including all four three-lap AI/replay and ramp-recovery fixtures. Details and remaining manual acceptance: docs/DRIVING_PLAYGROUND.md, Sustained wall sliding. Phone testing remains unperformed.
Final full Validate passed import, 24 parses, startup and 171 checks (56 driving + 115 track). Evidence: docs/evidence/wall-slide-*.txt.

2026-09-12 G01 recoil moderation: handling-0.12 reduces restitution 0.55 -> 0.45 following owner feedback. Measured rebound distance 3.736 -> 2.658 m; wall alignment, ramp recovery and three-lap AI/replay pass. Full Validate passed import, 24 parses, startup and 171 checks. Changed config/test acceptance, rationale and evidence: docs/DRIVING_PLAYGROUND.md (Moderate recoil). Close/relaunch for manual feel acceptance; no phone test performed.

2026-09-12 G01 tire contamination and softer recoil: handling-0.13 / physics arcade-planar-0.10 reduce restitution to 0.30 (measured separation 1.186 m) and add distance-based grass/dirt tire coating with up to 25% temporary traction loss. A full coating clears over 80 m; waiting does not clean tires. Diagnostic schema 3 appends tire_dirt to canonical snapshots. Full Validate passes import, 24 parses, startup and 189 checks (56 driving + 133 tracks), including three AI laps on all four fixtures, zero contacts, exact replay and ramp recovery. Commands, changed files, contract and limitations: docs/DRIVING_PLAYGROUND.md (Tire contamination and softer recoil); evidence: docs/evidence/tire-dirt-*.txt. Manual feel and phone tests remain pending; close/relaunch to load.

2026-09-12 G01/G02/R03/R01 rail-tip follow-up: inspected the owner's parked 1WAY window (759 contacts) and reproduced late upper-rail activation at ramp ends. Physics arcade-planar-0.11 extends rail detection along the bridge axis by the car footprint and allows decreasing overlap across layer boundaries. Native geometry/presentation and handling-0.13 are unchanged. Full Validate passed import, 24 parses, startup and 207 checks (56 driving + 151 tracks), with all four three-lap AI runs at zero contacts and exact replay. Both-end rail contact/retreat fixtures, original ramp escapes and underpasses pass. Live screenshot, actual commands, test-fixture isolation and remaining manual/phone acceptance: docs/RAMP_RECOVERY.md (Rail-tip activation). Parked instance remains intact; close/relaunch to load. No phone test performed.

2026-09-12 G01 wall-motion consistency: reproduced stationary velocity accumulation and sudden release (up to 35.46 m/s stored). Physics arcade-planar-0.12 groups coplanar wall cells for tangential overlap recovery, fixes corner entry normals and removes rejected slide velocity. Final powered-scrape tests limit tangential acceleration to normal engine acceleration, with at most 0.039 m/s residual tangential velocity while nearly stationary. Full Validate passes import, 24 parses, startup and 219 checks (56 driving + 163 tracks), including every original ramp/rail/lap/replay invariant. Changed files, actual commands, test correction, evidence and pending manual/phone acceptance: docs/DRIVING_PLAYGROUND.md (Wall motion and acceleration consistency). Close/relaunch to evaluate; no phone test performed.

2026-09-12 G02/R03/R01: owner-authorized bulk Slicks corpus adds 187 native tracks (194 total), native manifest discovery and 71 searchable author names. Five blank-author tracks have explicitly fictional attribution. Offline legacy normalization and source/hash provenance remain outside runtime. Commands, evidence and bulk QA limitations: docs/SLICKS_CORPUS.md. No phone test performed.
Final bulk verification: 194 conversions, zero failures; 781 runtime/search checks and 3 Python corpus tests pass; TestApp passes 80 checks. Three automatic spawn corrections and one uniform scale exception are recorded in SLICKS_CORPUS.md.

2026-09-12 G02/R03/R01: corrected YLIKULKU's wrong bridge axis using rail direction for parallel straight bridges. Regenerated 33 affected native tracks; original seven fixtures unchanged. TestCorpus passes 793 checks, YLIKULKU three ordered AI laps with zero contacts, and TestTracks passes 163 lap/replay/ramp checks. Evidence and remaining mixed-bridge/device limitations: docs/SLICKS_CORPUS.md (Bridge-direction correction). No phone test performed.
