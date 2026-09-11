# Phase 0: specification review and first slice

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
