# Phase 0: specification review and first slice

2026-09-14 G01/R01/R03/R07: owner prefers Original and requests more slip plus strong forward drive while sliding. Original+ is the focused tune; unchanged Original remains selectable. [ORIGINAL_SLIDE.md](ORIGINAL_SLIDE.md) records configuration, bounded power recovery, measured behavior and actual verification.

2026-09-14 G01/R01/R03/R07: owner reopens focused handling iteration with supplied fun-handling notes. Progressive steering, brake rotation and recovery are implemented with an old-physics comparison preset. See [HANDLING_FUN.md](HANDLING_FUN.md) for actual checks, identity changes and pending human/phone acceptance.

2026-09-14 R01/T01-T04/V02/V04/V05: centred biome/rename dialogs, keyboard-aware rename placement, taller rail, transparent header and grey disabled Test. [Checks and captures](EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred editor rail, simplified header/menu, biome and waypoint tools, fixed object paging and independent WIP autosave. [Actual checks and captures](EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: Curvy follow-up removes folded marking tails and cap-directed kerb spikes. [Actual checks and closer captures](KERB_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05: reference layout follow-up: grouped raised rail, green text-only Test, track name, charcoal tiles, road glyphs and Jump in Objects. [Actual checks and captures](EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 G01/R01/V02/V04/V05: traversable water with gradual car submersion and separate long-lived oil / short-lived water tire coatings. [Behavior, actual verification and device limits](SURFACE_RESPONSE.md).

2026-09-14 R01/T01-T04/V02-V05: owner rejects inconsistent editor controls and blockout graphics. [EDITOR_PRESENTATION_REFINEMENT.md](EDITOR_PRESENTATION_REFINEMENT.md) records this presentation/input slice and its uncompleted AAA art target.

2026-09-14 R01/T01-T04/V02/V04/V05: shared road joins, gradual connected widths and road-aligned full-width start line. [Implementation, checks and Curvy/Blind spot captures](ROAD_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05/G01: owner supplied category/asset references, confirmed movable tyres and requested movable light props with future biome-specific palettes. [OBJECT_BROWSER.md](OBJECT_BROWSER.md) records this local slice.

2026-09-14 R01/T01-T04: editor Load now shows all saved tracks immediately; empty search no longer hides the list. [Fix, actual checks and screenshot](EDITOR_LOAD_LIST.md).

2026-09-14 R01/T01-T04: saved tracks and unfinished drafts now have confirmed deletion, including recovery-file cleanup and library/selection refresh. [Actual checks, screenshots and limits](USER_TRACK_DELETION.md).

2026-09-14 V02/V04/V05/R01/T01-T04/G01: owner-authorized scenery, scaling and hazard slice. [CREATOR_HAZARDS.md](CREATOR_HAZARDS.md) records tapered kerbs, solid editable trees, shared bridge style and deterministic jump/oil/water behavior, with actual checks and remaining phone acceptance.

2026-09-14 V02/V04/V05: track-kit-10 gives each kerb run complete equal blocks with white beginnings/endings. Actual screenshot and 138 passing checks: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-9 integrates original painted grass, mipmapped detail, broad colour variation and a broken grass/gravel blend from the new texture direction. See VISUAL_STYLE.md for actual captures/checks and PAINTED_GRASS_PROMPT.md for generation provenance.

2026-09-14 V02/V04/V05: track-kit-8 corrects flat-mesh normals, removes microscopic edge segments causing sand spikes, separates terrain layers and filters sand grain. Actual captures/tests: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-7 fixes kerb spacing along actual edge distance, closes segment seams, procedurally roughens shoulders and omits sand behind kerbs. Actual checks and Silmukka capture: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05 follow-up: corrected grass, branch shapes, decorative stone scale, grey tree footprints and creator roadside shoulders/inner kerbs. Track-kit-6 actual Silmukka screenshot and checks are recorded in VISUAL_STYLE.md.

2026-09-14 V02/V04/V03/R01/V05: reference-led woodland visual revision, shared textured materials, irregular pines, selective outlines and driving-control icons. See [VISUAL_STYLE.md](VISUAL_STYLE.md) for actual evidence and acceptance limits.

2026-09-14 G01: owner requests stronger initial tyre impacts, pushable individual stacks and torque-limited piles. [TYRE_PUSHING.md](TYRE_PUSHING.md) records implementation and actual validation.

2026-09-14 G01/R01/T02-T04: owner requests more resistant tyres and direct loading for continued local editing. Shared-version immutability is recorded for the later publication lifecycle. [TYRE_RESISTANCE_AND_LOADING.md](TYRE_RESISTANCE_AND_LOADING.md) records implementation and actual validation.

2026-09-14 R01/T01-T04/V05/G01: owner requests practical creator refinements and moving tyres. Implemented with compiler-6 / arcade-planar-0.13 and bounded optional v5 fields. [CREATOR_REFINEMENT.md](CREATOR_REFINEMENT.md) records actual commands and outstanding device acceptance.

2026-09-13 R01/T01?T04/V05: owner authorizes direct body/end-dot editing, PC controls and bridge authoring, superseding the ground-only bridge restriction. [CREATOR_CONSTRUCTION.md](CREATOR_CONSTRUCTION.md) records implementation and actual evidence.

2026-09-13 R01/T01–T04/V05 review: owner requests a usability review after accepting the improved editor direction. [CREATOR_USABILITY_REVIEW.md](CREATOR_USABILITY_REVIEW.md) records eight reproduced findings and proposes edit protection, race readiness and connected editing as the next slice. This checkpoint changes review tooling/documentation only; implementation decisions remain outstanding.

2026-09-13 R01/T01–T04/V03/V05: owner wireframe directs compact overlays over the full-screen track, place-and-connect road pieces, local geometry controls, roadside props and visual issue recovery. Implemented in creator-track-v4 with retained free painting and independent lap route. Wireframe untimed practice overrides editor-only five-lap runs; regular races stay five laps. [WIREFRAME_EDITOR.md](WIREFRAME_EDITOR.md) records commands, captures and remaining phone/visual acceptance.

2026-09-13 R01/T02/V03/V05: owner requests full-screen creator and usable detail editing. Dedicated canvas with overlay tools, anchored close zoom and fine brushes implemented; actual commands, checks and unperformed phone acceptance are in [FULLSCREEN_EDITOR.md](FULLSCREEN_EDITOR.md). No physics/camera/content expansion.

2026-09-12 V03/G03/R01/R04/R06/R07: owner requests stronger menu presentation and player motivation. Race invitation, persistent last circuit, explicit PB target and improvement debrief are implemented; see [RACE_PRESENTATION.md](RACE_PRESENTATION.md). No progression or online-service expansion.

2026-09-12 T01–T04 / V05 / R01: owner rejects spline-only editing and selects free-shaped roads, terrain, intersections and obstacles. Independent painting/lap-route authoring and native remixes are implemented in v3; see [FREE_FORM_EDITOR.md](FREE_FORM_EDITOR.md) for actual checks, evidence and phone limitations. Existing handling and five-lap rules are preserved.

2026-09-12 latest owner override: **five laps** for ordinary races and creator test drives, replacing the historical three-lap selection below. Track discovery now uses a visual library, favorites, name/creator search, theme/sort filters and random selection. See [TRACK_LIBRARY.md](TRACK_LIBRARY.md) for V03/R01/R04/R06/R07 coverage, actual validation and phone acceptance still outstanding. Historical diagnostic replay fixtures explicitly retain three laps.

2026-09-12 V03/G03/R01/R06 menu follow-up: owner explicitly selected Hill Climb Racing 2 as navigation reference. Direct race hub and simplified tabs implemented; 86 graphical app checks pass. Full validation has six creator failures during concurrent format work; phone and owner acceptance remain pending. See [HCR2_MENU_REVIEW.md](HCR2_MENU_REVIEW.md) for actual commands, scope and screenshot.

## Current owner authorization: 2026-09-12

The owner now accepts the car's handling and collisions and explicitly asks to advance to menus, several more Slicks circuits, a phone-friendly map creator and shared visual themes. This later request overrides the earlier editor/content restriction for one local slice. Implemented scope is the local Play/Garage/Tracks/Create/Settings/results flow, three more native circuits, bounded local authoring/sharing and Pine/Coast/Desert presentation. The initial creator uses simple draggable handles over a starter loop rather than exposing advanced spline tangents; this is the current phone-usability proposal under the owner's request.

See [MENUS_AND_CREATOR.md](MENUS_AND_CREATOR.md) for changed files, requirements, actual commands/outcomes and screenshots. The history below remains the original inspection/order. It no longer means handling is unapproved. Physical-phone/camera/performance gates and competition-grade timing validation are still pending; backend, store, progression and hosted UGC are not part of this authorization.

## Owner-authorized handling fixture update, 2026-09-11

The later explicit request for `slicks_codex_handoff.zip/CODEX_TASK.md` authorizes four native test circuits inside the handling gate, overriding the one-circuit quantity for these development fixtures only. Inspection preceded implementation: the yard had no native circuit/importer/surfaces/laps/AI. A small `PlaygroundData` subclass, practice lap session and diagnostic driver now provide those foundations; they do not complete the full Phase 5 countdown/PB/competition validator or imply handling approval. Three laps still applies. No store/backend/editor expansion occurred.

Actual commands, source semantics, scale measurements, correction, full replay results, screenshots and manual checks are current in [SLICKS_IMPORT.md](../SLICKS_IMPORT.md). Validation passes 56 driving and 48 track checks plus four offline converter tests. The regular follow-camera calibration is still pending; F4's requested overview is a separate debug view. Android Doctor still fails missing prerequisites; no device test or export occurred.

Reviewed 2026-09-11. The current owner request narrows the active work to proving driving on Windows and a physical Android phone. Phase numbers in that request (0–7) are implementation steps inside the blueprint's P0/P0-V gates; they are not permission to start the blueprint's later P1–P7 product expansion.

## Source review

The extracted `Android_racing_game_blueprint_v2/` is the supplied package. All 71 files listed in its manifest match SHA-256. Reviewed the 22-chapter maintainable master, reading editions, architecture, rendering handoff, agent/first-task instructions, API/schema examples, roadmap, 51 requirements and corresponding backlog, planning/economy records, launch plan, validation reports, reference gallery and HTML prototype. Inspected every supplied PNG and all 16 pages of the UI guide. Opened all nine financial workbook sheets, including assumptions, cohort formulas, cash timing and founder-time treatment. The financial workbook remains byte-identical to the supplied baseline. No prices or commercial forecasts are adopted as gameplay requirements.

The gameplay source and derived 1.15x image were inspected separately at full size. The six menu crops, menu-only board, source board, material reference, asset crops and eleven UI screens have distinct roles. The menu board's chase cameras are explicitly rejected. The HTML interactions and its sample records are illustrative; no online or commerce code belongs in this slice.

## Definitive requirements

- Local-first, Godot standard, typed GDScript and minimal dependencies. Windows is the development platform; physical Android driving is a completion gate.
- One fictional, proportionate car. Compact arcade planar simulation: prompt steering, meaningful throttle/brake, momentum, recoverable slip, countersteering and collision energy loss. No wheel/rigid-body tire solver.
- Handling Resource owns mass, engine/brake force, drag, rolling resistance, speed cap, steering rate/high-speed reduction, lateral and longitudinal grip, front/rear balance, slip threshold, recovery, yaw inertia, assistance, throttle rotation and collision loss. Document units and bounds when implemented.
- One circuit: short straight, fast bend, braking corner, hairpin, chicane and an oversteer opportunity. Aim for 15–20 seconds per lap within the accepted 10–30-second envelope. Exactly three laps in the first slice.
- Standing countdown; time starts at GO. Ordered directed swept gates reject shortcuts and reverse crossings. Keep standing first lap separate from flying-lap PB. Current, previous and best lap, race total, persistent local PB and essentially immediate retry.
- Fixed 120 Hz simulation proposal, quantized input and explicit physics/rules/content identities. Timing derives from ticks plus swept crossing fraction and is stored as integer milliseconds. Rendering does not determine time. Fixed-step floating point is not a claim of cross-device determinism.
- Keyboard and four simultaneous touch inputs. Cancellation/backgrounding releases all input. UI is a view of race state, never the timing authority. Debug telemetry is optional and excluded from release presentation.
- High-oblique follow camera, no horizon, stable yaw, local track coverage. Adjustable projection/height/pitch/look-ahead/smoothing; no dynamic zoom during calibration. World extent becomes baseline / 1.15 for orthographic projection. Car mesh, road geometry and HUD retain scale.
- Mature graphic-novel cel-shaded 3D: matte planes, restrained colours, stepped light and selective contours. Original stand-ins are acceptable for handling; polish follows feel approval. Reference crops are not shipping assets.
- No energy, lives, paid retry or progression block. No backend, account, store, SDK analytics, ads, payments, leagues, upgrades or editor implementation at this gate.

## Differences, risks and decisions

| Item | Evidence and action |
|---|---|
| Three versus four laps | Blueprint first task/default says four; latest owner instruction explicitly says three. Use three in the slice. Preserve original package and record this override in root AGENTS.md. Future lap count remains data-driven. |
| Engine discovery | PATH resolves 4.6.2, but `C:/apps/Godot 4.7.2/` contains the blueprint's 4.7.2 standard engine. Verified `4.7.2.stable.official.ed1daf0bf`; pin the full build and matching 4.7.2.stable templates. Never silently fall back to PATH's older binary. |
| Renderer | Compatibility is a reversible bootstrap baseline for simple 3D. Compare it with Mobile using the same scene on the actual phone before deciding the visual pipeline. |
| Camera angle/extent | The package approves image proportions, not a numeric pitch or physical height. Calibrate a repeatable pose at 1672×941, measure projected car bounds before/after (1.15 ±0.03), then check every heading and wider landscape ratios. |
| Rotation controls | Developer-adjustable rotation experiments can exist, but default and acceptance profile keep world yaw stable. Heading-locked rotation needs an explicit reviewed experiment. |
| Timing/PB | Interpret PB as best valid full race; show a separate flying-lap best. Pause/respawn marks an attempt practice. Restart creates a fresh standing-start attempt. Countdown is deliberately excluded from the warm reset cost. |
| Performance target | Requirements Q01/master give p95 ≤20 ms; visual acceptance suggests ≤16.7 ms. Record both; target ≤16.7 ms for the visual gate without claiming it is measured or silently weakening either. |
| Touch sequencing | Input actions are established in bootstrap, keyboard in the playground, reusable touch sampling next to keyboard before phone evaluation. Final layout/device testing follows the requested Phase 6. No mouse-emulated touch acceptance. |
| Fun cannot be automated | Physics invariants and telemetry can find faults; only driving can approve feel. Stop expansion for a focused handling iteration when the owner finds it unsatisfying. |
| Replay | Use an isolated typed planar core and input capture experiment. Cross-platform equivalence remains unproved until replay corpus tests on Windows and Android. No premature fixed-point framework. |
| Track schema | Starter schema covers geometry, not every future metadata field. Keep authored Resource metadata separate and map to a deliberately versioned export schema later. Do not claim imported Resources are safe user content. |
| Art cost | Workbook assumes 1,000 prelaunch hours and predates the additional P0-V allowance. The 2–4 added person-weeks do not estimate every finished car/track. Preserve the model; measure one car/corner before scaling. |
| Android prerequisites | No configured SDK/ADB, JDK or matching export templates were found in the inspected locations. Bootstrap supplies checks and commands; APK/install/phone acceptance remain open until those exist. |

## Exact repository structure

```text
AGENTS.md                        current project instructions and explicit overrides
README.md                        run/build loop and scope
DEVELOPMENT_STATUS.md            actual progress, tests, decisions and debt
godot-version.txt                exact engine build
Android_racing_game_blueprint_v2/ unchanged authoritative source, outside res://
docs/
  PHASE_0_PLAN.md                this review and implementation order
  ANDROID.md                    setup and physical-phone acceptance
  evidence/                     reviewed screenshots and command results
licenses/                       original asset ledger and engine notices
scripts/dev.ps1                 doctor, validate, run, export, install and launch
game/
  project.godot
  export_presets.cfg
  core/                         composition root and lifecycle
  vehicle/                      canonical planar state/step, separate 3D presenter
  input/                        quantized frame + keyboard/touch adapters
  track/                        metadata, surface/collision/gates, mesh builder
  race/                         RaceSession and immutable run manifest
  timing/                       clock and directed swept-gate evaluation
  camera/                       presentation-only rig and calibration fixture
  ui/                           race HUD, touch views and debug telemetry
  persistence/                  local atomic PB save and replay/telemetry files
  resources/                    authored handling/car/track/camera profiles
  tests/                        headless domain tests and replay fixtures
build/                          ignored APKs, screenshots and logs
.tools/                         ignored document-review tooling
```

Bootstrap creates module directories; implement classes only as needed. `Game` composes modules. `RaceSession` receives quantized input, canonical vehicle state and track data; timing consumes swept movement. UI observes state/signals. Persistence runs outside the simulation step. Map simulation `(x,y)` to world `(x,0,-y)`, with zero heading along simulation +Y/world -Z. Document heading sign before physics code. Share track definitions between visual and collision builders.

Online work later consumes versioned run manifests through adapters, without changing the local step. Replay inputs/snapshots enable ghosts later. Track identity, creator, immutable geometry version, spawn, gates, surfaces, theme and validation metadata belong to authored content data. Upgrade/tuning definitions will be Resources when progression is implemented; no empty backend or upgrade framework now.

## First eight implementation tasks

| # | Work | Requirements | Evidence to finish |
|---|---|---|---|
| 1 | Phase 1 bootstrap: pinned project, input map, module boundaries, Git, build scripts, Android preset and README | G01, R01, Q01 foundations | CLI import, all scripts parse, main-scene startup, graphical Windows capture; explicit Android prerequisite report |
| 2 | Phase 2 playground: flat surface, one original car, typed state + handling Resource, keyboard driving, collision fixtures and rapid parameter reload | G01 | Acceleration/braking, steering reversal, lateral recovery and collision tests; executable playground |
| 3 | Phase 2 instrumentation: toggle telemetry, parameter variants, quantized input log and replay-format spike; reusable simultaneous touch adapter | G01, R01, A02 preparation | HUD values, safe release/cancel, same-input repeatability report and explicit divergence if any |
| 4 | Phase 3 camera: adjustable fixed-yaw rig, calibration pose and matched screenshots | R02, V01 | 1672×941 source/target/engine comparison and projected bounds; no car-only scaling; all-heading visibility |
| 5 | Phase 4 test circuit, shared visual/collision/gate data and versioned metadata | G01, G02, R03 foundations | Hairpin/chicane/braking/fast bends; measured 15–20-second baseline laps; no scenery polish |
| 6 | Phase 5 three-lap session, countdown, swept gates, separate timers, local PB and reset | G02, R03, R04, R06, R07 | Wrong-way/cut/order/high-speed tests, exactly three laps, no countdown time, frame-rate independence, practice invalidation and save recovery |
| 7 | Phase 6 phone: APK, ADB install/launch, four-button layout, safe insets and 20-minute driving session | G01, R01, Q01 | Named physical phone/build, ten consecutive lap times, slide/restart/touch feedback and frame pacing; iterate feel before expanding |
| 8 | Phase 7 initial material pipeline after handling approval; one representative car/corner and renderer comparison | V02, V04 | Matte stepped shading/selected contours, matched engine capture, moving full lap and device profile; no full art/content production |

The first subjective question is whether steering, braking and catching a slide feel immediate and learnable. It is not whether a boot screen looks polished. Full visual P0-V, garage compositions and external test recruitment follow owner handling approval; do not contact testers automatically.

2026-09-12, current handling gate: corrected bridge approach presentation on the authorized fixtures without extending the canonical simulation. Shared ramp geometry, car pitch and skid height passed Windows validation (24 parses, 56 driving + 57 track checks); three AI laps per fixture and exact replays passed. See [RAMP_FIX.md](RAMP_FIX.md) for commands, screenshots and remaining off-route/manual/phone acceptance. No phone test was performed.

2026-09-12 owner feedback authorizes a focused surface/presentation revision of the existing four handling fixtures: low obstacles become speed penalties and the matte terrain kit is improved. This does not advance the handling gate or authorize broader content. Native schema/content v2 and physics 0.6 are tested with 56 driving + 76 track checks, four converter checks and four schema validations. Current commands, screenshots and acceptance limits: [TRACK_SURFACES.md](TRACK_SURFACES.md). No phone test was performed.

2026-09-12: investigated the owner's live stuck ramp state and corrected collision recovery within G01. Native overlaps now permit safe outward movement; swept transitions test the destination layer before commitment. No content or camera expansion. Physics 0.7 passed 56 driving + 94 track checks and full three-lap replays. Evidence and manual restart/acceptance instructions: [RAMP_RECOVERY.md](RAMP_RECOVERY.md). No phone test was performed.

2026-09-12: G01 owner-requested collision rebound tuning is implemented as a shared parameter change (handling-0.9, restitution 0.38). No architecture/content expansion. Validate passed 56 driving + 96 track checks, including visible-separation metrics, energy loss, ramp recovery and full replays. See [DRIVING_PLAYGROUND.md](DRIVING_PLAYGROUND.md#collision-rebound---2026-09-12) for actual commands and remaining feel/phone acceptance; no phone test was performed.

2026-09-12: G01 impact tuning now rotates the car after oblique collisions and increases rebound, per both owner requests. Handling-0.10 / physics 0.8 passed 56 driving + 107 track checks with replay, ramp recovery, bounded energy and powered-reverse safeguards. Existing track/art scope is unchanged. Details and manual/phone acceptance remain in [DRIVING_PLAYGROUND.md](DRIVING_PLAYGROUND.md#impact-rotation-and-stronger-recoil---2026-09-12); no phone test was performed.

## G01 wall-slide iteration - 2026-09-12

Owner requests continued tangential travel and gradual alignment while pushing against a barrier. Implemented within the handling gate using the existing native collision resolver and shared response; no architectural expansion or track format changes. TestTracks passes 115 checks; measured mirrored powered wall starts travel 8.918 m in 3 seconds and align within 0.934 degrees. See docs/DRIVING_PLAYGROUND.md (Sustained wall sliding) for changed files, commands and limitations. Windows owner feel and physical-phone acceptance remain pending.
Final full Validate passed import, 24 parses, startup and 171 checks (56 driving + 115 track). Evidence: docs/evidence/wall-slide-*.txt.

2026-09-12 G01: owner requests less recoil; handling-0.12 tunes restitution to 0.45, preserving wall-slide algorithms. Full Validate passed 171 checks and measured 29% shorter rebound. Commands, changed files, revised owner balance target and evidence are in DRIVING_PLAYGROUND.md (Moderate recoil). Manual feel/phone acceptance remains pending.

2026-09-12 G01: owner-authorized softer recoil and temporary dirty-tire grip loss implemented within the handling gate. Pickup/recovery follow distance, with grass depositing less than dirt/sand and full cleanup after 80 m. Handling-0.13, physics arcade-planar-0.10 and diagnostic schema 3 version the state extension. Validate passed all 189 checks, four three-lap AI runs, exact replay and ramp recovery. See DRIVING_PLAYGROUND.md (Tire contamination and softer recoil) for commands, files, evidence and pending owner/phone acceptance. No track format or content expansion.

2026-09-12 G01 ramp follow-up: live 1WAY inspection led to footprint-aware rail-tip activation and consistent overlap recovery across collision layers (physics arcade-planar-0.11). Scope remains existing handling fixtures; no art/content/schema expansion. Validate passes 207 checks, all four three-lap AI/replays, original ramp recovery and both-end isolated rail tests. Commands, changed files, live evidence and pending owner/phone acceptance: RAMP_RECOVERY.md (Rail-tip activation).

2026-09-12 G01: owner-reported stop/turn/surge reproduced and corrected in native collision handling (physics arcade-planar-0.12). Coplanar-wall overlap now permits tangential motion; rejected velocity cannot accumulate for later release. Validate passed 219 checks and all original ramp/rail/lap/replay safeguards. Actual commands, files, before/after metrics and pending owner/phone acceptance: DRIVING_PLAYGROUND.md (Wall motion and acceleration consistency). No content/schema/art expansion.
## Editor follow-up: 2026-09-12

Owner authorizes sharp bends, per-node widths and built-in object editing (T01–T04 / V05 / R01), explicitly waiving backward compatibility for user tracks. The v2 contract and revised bend rules supersede initial creator limits. See [EDITOR_V2.md](EDITOR_V2.md) for actual commands, passing validation, screenshots and unperformed phone acceptance.

2026-09-12 G02/R03/R01: owner extends native test content to all 194 distinct locally supplied Slicks tracks. Author search uses retained source attribution or flagged deterministic fictional names. See SLICKS_CORPUS.md for actual commands/results, eight unresolved route-planner cases and remaining individual lap/bridge/device checks.

2026-09-12 G02/R03/R01: bulk straight-bridge axis correction fixes YLIKULKU overpass/underpass layering. Actual validation: 793 corpus checks, 163 original track checks, three YLIKULKU AI laps with zero contacts. See SLICKS_CORPUS.md and bridge-axis evidence; mixed-orientation bridges remain a separate limitation.
