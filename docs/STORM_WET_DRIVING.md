# Subtle Storm wet-asphalt driving effect — 2026-10-09

Requirements: V01/V02/V04/V05/Q01; owner requests subtle wet-asphalt driving feedback in the Storm biome. This refines the existing droplet-only treatment in [STORM_TIRE_SPRAY.md](STORM_TIRE_SPRAY.md), preserving the earlier rejection of expanding tire clouds and bright road streaks.

Four tire contacts throw a small backward/outward fan of water beads during ordinary rolling. Rear emission is stronger than front emission; density and launch speed rise smoothly with contact speed. Creeping at or below 2 m/s emits nothing. Each wheel checks actual Storm asphalt independently, including elevated asphalt; grass, sand, other biomes, jumps and rolls suppress new water emission. Existing pause, restart and rewind behavior remains in use. Canonical simulation, wet grip, rules, track identity, camera, road shaders and HUD are unchanged by this task.

The existing filtered bead shader and lazy allocation are reused. Each emitter has 72 particles, a 0.30-second lifetime and 0.065 × 0.12 m beads with maximum alpha 0.42. Four emitters cap allocation at 288 particles, up from 224. Rear/front maximum emission ratios are 0.68/0.44; speed response spans 2–24 m/s. Launch range varies from 1.2–2.8 to 2.2–4.4 m/s, with gravity and no growth curve or shadows. No new bitmap asset, dependency, network call or UI text.

Changed files:

- `game/vehicle/sand_dust.gd`: versioned water presentation, density/launch response and restrained fan parameters.
- `game/tests/test_storm.gd`: rear/front balance, speed-dependent launch and creeping suppression checks added to existing surface/direction/lifecycle/replay coverage.
- `game/tests/capture_storm_wet_driving.gd`: isolated moving presentation capture, frozen spray-on/off comparisons at two speeds and resolutions.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and `docs/evidence/storm-wet-driving-2026-10-09/`: outcomes, source snapshots, logs, screenshots and task-only review patch.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned **4.7.2.stable.official.ed1daf0bf**. Tests used disposable workspace `APPDATA` directories under `build/storm-wet-driving-*`, preserving player files:

| Action / arguments | Actual result |
|---|---|
| `-Action TestStorm` | 94 checks, zero failures; existing five-car exact wet replays, wheel surfaces, elevated road, reverse/outward direction and pause/clear checks retained. |
| `-Action TestScript -ScriptPath res://tests/capture_storm_wet_driving.gd -Graphical` | 25 checks, zero failures; eight saved PNGs, no shader errors. |
| `-Action TestSoil` | 163 checks, zero failures. |
| `-Action TestDesert` | 87 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 388 scripts, zero failures. |
| `-Action Doctor` | Pinned executable/templates found; OnePlus Pad 2 OPD2403 `f0ba474a` attached and authorized. |
| `git diff --check -- game/vehicle/sand_dust.gd game/tests/test_storm.gd` | Passed; existing CRLF conversion notices only. |

Initial sandbox runs stopped on user-log permissions, then Windows certificate-store access. Workspace-isolated saves and approved execution outside the sandbox resolved those environmental failures. The initial sandbox Doctor could not create adb configuration; its approved read-only rerun succeeded. Escalated shell startup also printed an unrelated PowerShell profile execution-policy warning; subsequent commands use `login: false`. These unsuccessful attempts are retained in the evidence logs, not reported as passing tests.

The capture harness moves a presentation state along a real compiled automatic-route Storm straight at 7 and 18 m/s, then freezes particle state for matched images with/without only water droplets. Race timing remains paused; the HUD's paused status is expected. It uses existing gameplay camera framing. Image comparison detects 34/349 changed pixels at 1280×720 and 18/225 at 960×540 for slow/fast driving. Only 0/7/0/0 pixels exceed 0.25 RGB difference; the effect remains localized rather than veiling the road. These counts support visibility in these captures, not device performance or a completed race.

[Desktop driving](evidence/storm-wet-driving-2026-10-09/1280x720-65kmh-spray.png), [compact driving](evidence/storm-wet-driving-2026-10-09/960x540-65kmh-spray.png), [slow rolling](evidence/storm-wet-driving-2026-10-09/1280x720-25kmh-spray.png) and matched without-spray captures were inspected. The short bead wake is visible behind the tires; car and approaching road remain clear.

No Android export, installation or physical-device test was performed. An attached tablet does not establish phone art/performance acceptance. Owner in-motion review, all-car/bridge visual review and mobile frame pacing/thermal acceptance remain. Full Validate and a full physics regression gate were not run; this task changes presentation only. The task-only patch preserves unrelated changes already present in these files and the workspace.
