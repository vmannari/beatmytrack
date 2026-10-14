# Intermittent early-race freeze investigation, 2026-10-13

Requirements: RH01 investigate the reported first-5–10-second freeze; RH02 automatically capture subsequent stalls; RH03 bound diagnostic cost/storage and preserve local privacy; RH04 retain canonical racing and persistence; Q01/V05/G01/R01. This extends [the September investigation](RACE_START_HITCH.md). The owner's exact intermittent one-second driving freeze is **not confirmed fixed**. No speculative gameplay, artwork, camera, dust, scoring or persistence change was made.

## Findings

The old profiler only instantiated Game, omitted preferences/normal cosmetic saves, reported seven partial script sections and stopped after a fixed wall-time window. It did not observe the account/recovery/outbox nodes in the actual application. A cold render stall could consume the window and make its minimum-live-tick assertion fail.

The first current Compatibility run reproduced a 4,499.149 ms startup frame at tick 0 and a 280.913 ms frame at tick 162. Recorded script sections accounted for only a small part of the latter. This run failed the diagnostic's old 1,000-tick minimum (786 ticks), and is retained as an observation, not a passing performance test.

Instrumentation now measures actual wall-clock intervals, the entire Game physics/presentation callbacks, surrounding process callbacks, render-signal boundaries, first-use effect context and synchronous save/recovery/cloud IO. The updated profiler waits for 1,440 actual driving ticks with a bounded wall deadline, and writes preferences only to disposable build storage.

Six current Compatibility runs completed 12 actual driving seconds each: moving/stationary/moving pine, then moving desert/winter/storm on starter geometry. The two pine moving runs each drove 118.90 m; stationary drove 0 m. Desert drove 117.81 m, winter/storm 118.90 m. No one-second stall during driving was established in these six runs. Captures do establish render-boundary stalls:

| Capture | Frame interval | Previous render boundary | Current process callbacks | Tick |
| --- | ---: | ---: | ---: | ---: |
| Pine first start | 270.814 ms | 266.866 ms | 0.703 ms | 0 |
| Desert first start | 245.673 ms | 241.843 ms | 0.675 ms | 0 |
| Winter start | 170.498 ms | 156.538 ms | 0.671 ms | 0 |
| Storm first start | 1,831.120 ms | 1,812.465 ms | 1.493 ms | 0 |
| Storm at scene wall time 5.582 s | 137.832 ms | 128.554 ms | 1.347 ms | 104 |

Tick 104 is only 0.867 s of driving after countdown/startup. For that event Game physics totaled 6.705 ms, presentation 1.290 ms, condition save 0 ms; no lightning occurred. Weathering was already installed in preceding frames, so that capture does not establish its initial material swap as the trigger. Compatibility pipeline counters were all zero and do not establish or exclude shader compilation.

First-use rendering/shader/driver work is a plausible lead, not a proven root cause. These wall measurements cannot separate shader compilation, GPU/driver waits or OS scheduling. Other workspace/GPU activity was present; these are diagnostic observations, not isolated benchmarks or phone FPS measurements.

The five-second periodic car-condition save remains synchronous and is now separately timed. Thirty actual-record-copy saves measured guest 23,383 B: median 8.897 ms / max 13.100 ms; largest existing signed-in profile 38,916 B: median 6.562 ms / max 10.272 ms. Original files were read only. This does not reproduce a one-second save freeze, or rule out occasional antivirus/storage latency on another device. Recovery scans and cloud journal IO are also possible intermittent sources and are now identifiable in a capture.

## Automatic capture and recovery of evidence

Every newly created Game installs `race_hitch_monitor.gd`, including guests and practice. No marker, login, service capability or network connection is needed. It observes countdown and active driving, suppresses paused/background/focus-resume intervals, and never changes simulation state, inputs or clocks.

PC files are written to:

```text
%APPDATA%\Circuit01Lab\diagnostics\race_hitches\race-*.json
```

Restart into the updated source/build before reproducing. The currently installed phone APK has **not** been updated by this task. A later Android build uses `user://diagnostics/race_hitches` inside the app's private files directory. After a recurrence, retain the newest JSON files; the console also emits `RACE_HITCH` with the filename and tick. No user-facing diagnostic controls/text were added.

Each event contains the slow frame and up to 64 previous/16 following frames: real elapsed interval, wall/race time, countdown, physics/presentation and individual stage durations, engine/pipeline monitors, render-boundary duration, speed/route/layer, weathering binding, emitter allocations, trail cursor, snow bursts/lightning, save count, proof/history sizes, recovery callback time, cloud local IO and transport/worker state. Header records exact track hash, car, engine/renderer/adapter, OS/model and contract/art versions. Per-frame biome/hash keeps in-place track changes identifiable. No credentials, account/ticket IDs, raw inputs/trajectory or cosmetic snapshots enter the log. Logs remain local and are never enqueued as telemetry.

Monotonic timestamps are necessary because Godot can cap/smooth `delta` during a real stall. Nested stage timings overlap and must not be summed. A sampled interval includes the previous render and current physics/process work; adjacent frames resolve first-use changes. `draw_boundary_ms` is wall time between render signals, **not GPU execution time**. Engine monitors can lag or be unavailable in release. API semantics: [Node processing/delta](https://docs.godotengine.org/en/stable/classes/class_node.html), [Performance monitors](https://docs.godotengine.org/en/stable/classes/class_performance.html).

Storage is bounded to the eight worst events per scene and eight completed files, each capped at 2 MiB, plus a temporary during atomic replacement. A low-priority worker serializes/flushes detached snapshots; live callbacks never wait for the writer or serialize JSON. Normal frames stay in a bounded memory ring. The observer itself averaged 73–86 microseconds/frame in these PC profiles, excluding added Game timing calls; this is not a whole-feature overhead comparison or phone cost measurement. Teardown joins the worker and preserves remaining evidence. Recovery/cloud changes are timing counters only.

The logger captures **recovered** freezes. A permanent main-thread deadlock or process/power loss before capture completes still needs an external stack trace/device diagnostic. If an event has little script time but a long render boundary, investigate that exact effect/renderer with engine verbosity or an OS/driver trace. If `condition` or recovery/cloud IO dominates, investigate that call and storage path using its measured duration.

## Changed files and actual validation

- `game/diagnostics/race_hitch_monitor.gd` (+ UID): automatic bounded observer/worker.
- `game/core/game.gd`: observational callback wrappers, weathering/condition durations and monitor installation.
- `game/backend/resume_recovery.gd`: synchronous callback timing excluding network waits.
- `game/backend/cloud_tracks.gd`: local read/write timing counters.
- `game/tests/profile_race_start.gd`: full-duration cold/repeated/biome probe with disposable preferences.
- `game/tests/test_race_hitch_monitor.gd` (+ UID): real injected one-second late callback and delayed condition save, external-work attribution, surrounding evidence, pause/focus suppression, independent worker, worst-event/file bounds and canonical-state observation.
- `game/tests/profile_condition_save.gd` (+ UID): read-only-source disposable guest/largest-account save measurements.
- This report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and scoped evidence/checkpoint.

Actual entry-point commands (PowerShell `-NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` throughout):

```powershell
scripts/dev.ps1 -Action ProfileRaceStart
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_race_start.gd -Graphical -TestArgument '--themes=desert,winter,storm'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_condition_save.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_resume_recovery_budget.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_client_quality.gd
scripts/dev.ps1 -Action TestDriving
scripts/dev.ps1 -Action TestTracks
scripts/dev.ps1 -Action TestRewind
scripts/dev.ps1 -Action TestRecords
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action Import
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action Doctor
git diff --check -- game/core/game.gd game/backend/cloud_tracks.gd game/backend/resume_recovery.gd game/tests/profile_race_start.gd
```

Final results: hitch tests **36 headless + 36 Compatibility + 36 Mobile/Vulkan**, recovery budget **248**, exception recovery **28**, client quality **46**, driving **72**, tracks/replay **167**, rewind **61**, records **54**, app **99**, parse **618 scripts**, import and diff check all pass. Deliberately injected callback captures were approximately 1,106–1,109 ms; delayed saves approximately 186–191 ms and correctly attributed.

Initial attempts retained in evidence: sandbox denial writing Godot's usual external user log (rerun with authorized elevation); old wall-duration profiler's insufficient-live-ticks failure; diagnostic output directory needed `globalize_path`; a fixture had no prehistory after clearing it; Vulkan produced an extra real renderer stall after the injected save, requiring selection of the intended event rather than assuming the last event was it; helper variable-shadow parse error corrected. Assertions and canonical invariants were retained.

Evidence is under `docs/evidence/race-hitch-2026-10-13/`: raw command logs, real profile JSON, injected-save captures, pre-task source snapshots and `task-only.patch` with hashes. The checkpoint compares runtime edits against those snapshots so existing unrelated workspace changes are excluded. No broad full-Validate, Android export/install, production deployment or live account/backend write was performed. Doctor found attached DN2103, but **no physical-phone logger/reproduction/performance test was performed**. No visible UI/art change required screenshots. Remaining acceptance: capture the owner's exact recurrence, identify its resource/call/driver cause, then validate an attributable fix and observer overhead on PC and the physical phone.

