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

## Owner recurrence captured and material preparation fix, later 2026-10-13

Requirements RH05–RH07 / Q01 / V05 / G01 / R01: preserve the reported live event, attribute its first-use trigger, move material preparation before the countdown, and retain exact cosmetics/artwork/canonical state.

The owner's running PC process was **16784**, started at **21:15:16 Helsinki time**, using the actual project (not a diagnostic script). Its capture `race-1791915345-16784-800038329277.json` records a **4,255.792 ms frame** at tick **342** / **2.850 s driving** on the published pine track, Compact, Compatibility/RTX 3090. The preceding render-signal interval was **4,228.334 ms**. Game physics totaled **18.229 ms**, presentation **1.216 ms**, condition saving **0 ms**, recovery **4.314 ms**, and cloud local IO **0.068 ms**. No diagnostic transport/writer or editor worker was active. The live game was left running and was not restarted or modified through remote control.

The last ordinary frame, tick **326**, was the **first** frame with `weathering_installed=true`; all preceding retained frames were false. Its binding work took **0.751 ms**, and the subsequent draw stalled. Thus the actual event follows the first switch from the clean car materials to the dirt/snow finish materials. Compatibility compilation counters were zero; they do not provide a GPU/driver stack or identify the compiler operation themselves.

A separate frozen scene isolates this switch with no physics, inputs, condition saves or active driving effects. First dirty-material use took **170.831 ms** (**168.904 ms** between render signals); repeated use took **8.322 ms**. After rendering those same materials during preparation, first dirty use took **8.358 ms**, with exact cosmetic snapshot preservation. An independent grass-particle activation took **20.484 ms**, while first dirty use in that process still took **175.688 ms** and repeated dirty use **8.324 ms**. These observations strongly implicate first-use vehicle-finish shader/driver compilation; they are not a claim that the owner's 4.2-second delay was reproduced at the same magnitude or that every intermittent native stall has one cause. Driver cache and concurrent host activity affect timings.

Compatibility requires actual rendering of a material in the camera frustum while loading to avoid first-use shader stutters; merely preloading its resource is insufficient. The implementation follows [Godot's documented Compatibility preparation approach](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The normal app race-start path now temporarily binds the actual weathering materials with the **unchanged** cosmetic values under the existing loading cover, waits for an actual render using the existing bounded wait, then restores the exact clean/livery bindings and renders them before releasing the cover. Countdown/physics remain disabled throughout. Already-dirty cars use their existing finish. Cancellation, focus loss and reset restore safely. A suspended renderer retains the existing timeout behavior; it is never falsely marked as having completed a material draw. New local captures record `weathering_prepared` and active grass/mud/dust/smoke masks to distinguish subsequent first-use effects.

Additional changed files:

- `game/vehicle/vehicle_weathering.gd`: cancellable preparation binding, without fabricating dirt or altering wash volumes.
- `game/core/app.gd`: covered draw/restore before starting; bounded draw helper returns whether a render occurred.
- `game/core/game.gd` / `game/diagnostics/race_hitch_monitor.gd`: actual-draw marker and active-emitter context.
- `game/backend/client_quality.gd`: treat a cancelled partial node with missing race properties as non-racing, fixing a null-to-bool error exposed by the existing loading test.
- `game/tests/profile_weathering_first_use.gd` (+ UID), `game/tests/test_weathering_preparation.gd` (+ UID), `game/tests/test_over_under_loading.gd`: isolated first-use probe, exact pixels/condition/bindings/state for five cars plus a patterned/stickered Compact, and actual draw/full countdown/cancellation checks.

Actual additional commands, through the pinned `scripts/dev.ps1` entry point:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_weathering_first_use.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_weathering_first_use.gd -Graphical -TestArgument '--warm'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_weathering_first_use.gd -Graphical -TestArgument '--particles'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_weathering_preparation.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_weathering_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_client_quality.gd
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action Import
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action Doctor
```

Final checks: preparation **72 Compatibility + 72 Mobile/Vulkan**, loading **20 headless + 21 graphical**, car wash **1,383**, client quality **57**, app **99**, hitch capture **36**, full parse **645**, import and task diff/patch checks pass. Every before/after framebuffer is byte-exact once original materials have settled, including the patterned/stickered car; paired screenshots are saved and inspected. Canonical state and the full **360-tick countdown** remain exact. No shader/artwork, geometry, driving/scoring contract or dust/snow budget was changed.

Retained initial issues: partial-node observer bool conversion error fixed; one loading teardown assertion failed during a parallel run and passed unchanged on isolated/final headless and graphical reruns; temporary fixture diagnostic inserted in the wrong scope caused a parse error and was removed; a concurrently changed audio-extension configuration referenced its new DLL before the DLL existed, then succeeded after the other work finished; early Vulkan decorated-car comparison differed by **56 pixels at at most one channel unit** while its original material was still in first-use specialization. The strict pixel assertion was retained, and the fixture now lets the original shader settle before taking its baseline; final comparisons are exact. Unrelated editor, vehicle-customisation, telemetry-schema and audio-extension revisions were preserved and excluded from this checkpoint.

Live JSON, isolated probe JSON, command logs, paired pixels, original snapshots and a **task-only** review patch/hash manifest are under `docs/evidence/race-hitch-recurrence-2026-10-13/`. The patch uses a checkpoint base containing concurrent changes and excludes those changes from the fix. Restart the PC game to load this fix; the already-running instance uses its loaded scripts. Doctor still found attached DN2103, but no physical-phone race/preparation test, APK export/install, full Validate or backend deployment was performed for this follow-up. Remaining acceptance is the owner's repeated clean-car race starts after restart, then physical-device confirmation; compilation can still take time under the loading cover, and other first-use effects remain observable rather than claimed solved.

## Desert recurrence after material preparation, later 2026-10-13

Requirements RH08–RH10 / Q01 / G01 / R01: preserve the new live event, distinguish it from first car-material activation, and add evidence for still-unidentified native/render work. **The early-race freeze is not generally fixed.** The previous preparation pass addresses a first-use material path; this recurrence shows it is insufficient to explain/eliminate every stall.

The owner reports **normal driving**. The actual running PC process **35568**, started at **22:03:47 Helsinki time**, captured Speedy/Desert/Compact/Compatibility/RTX 3090 in `race-1791918253-35568-766400013488.json`. The main event is **1,099.773 ms** at tick **544**, **4.533 s of driving**, with **1,087.339 ms** between render signals. Game physics was **8.872 ms**, presentation **1.489 ms**, condition saving **0 ms**, and the recorded recovery/cloud IO was **0 ms**. No editor worker or telemetry writer was active in that event.

`weathering_prepared=true` and `weathering_installed=true` throughout the retained preceding **523 ms**, as was the four-wheel dust active mask **15**. Thus this capture does not support blaming the first car-finish swap or first recorded dust activation. It also contains a separate **164.545 ms** countdown interval with only **6.656 ms** in the render boundary; the two events should not be conflated. The immutable cached Speedy document has 16 pieces, three jump objects and **no bridges**. Draw calls rise from 301 to 302 around the large event, but the old capture cannot identify which object/effect/pipeline did that. Compatibility compilation counters remain zero, so a shader/driver wait or scheduling explanation remains unconfirmed without a native stack/GPU trace.

The logger now records every car particle group's allocation and active-wheel mask, jump/roll/heading state, and a bounded mesh/material inventory. At **5 Hz**, immediately before rendering, it samples camera-frustum candidates, first candidate appearances, viewport size, MSAA/render scale and projection. This describes possible draw resources rather than asserting actual GPU visibility: shadow passes, occlusion and native work remain outside that observation. The inventory is capped at **128 items**, four material roles per mesh; truncation is explicit. Shader source hashes and StandardMaterial feature roles distinguish candidates without dumping source code, player inputs, positions or cosmetic snapshots. The inventory captures the initial world; dynamically allocated emitters remain covered by their group counters.

Local diagnostic **schema 2** serializes repeated render contexts once in a table, with per-frame indices and explicit dropped-context counts. Up to **64** contexts fit the existing eight-event/eight-file/**2 MiB per file** limits. The full eight-event actual-frame stress check verifies the existing byte cap and preserves the live sampled frames. A disposable 12-second Desert probe completed **1,440 ticks / 117.81 m**; observer processing averaged **151.47 µs/frame**, and sampled render-context work was **0.103–0.115 ms** in retained startup samples. It had a 2.790-second startup render stall, but did not reproduce the live Speedy event during driving. These shared-host observations are not a phone performance/overhead acceptance test or a controlled speedup claim.

Two read-only PC capture helpers were prepared:

- `scripts/capture-race-hitch-threads.ps1`: cumulative per-thread/process CPU time and thread wait state at roughly four samples/second, with exact PID/start-time fences, a 256-thread/sample bound and a 120-second maximum. It watches for newly captured slow events, including replacement in a full eight-event buffer, and preserves the related JSON. It pauses/restarts no game and stops when its selected process exits.
- `scripts/capture-race-hitch-trace.ps1`: Windows Performance Recorder CPU/GPU memory-mode capture, a unique owned recording name, a time limit and stop/cancel handling restricted to that recording. It records no heap, network traffic or file-content profile and uploads nothing. Raw native traces, if available, belong under ignored `build/`, not published evidence. Usage follows [Microsoft's WPR command-line documentation](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-command-line-options).

The real WPR attempt **failed before recording**: `0xc5585011`, “Failed to enable the policy to profile system performance.” Sandbox escalation was permitted; this was a Windows profiling-policy/privilege failure, **not** an automatic approval-review rejection. No ETL or native stack was obtained. WPR status was subsequently confirmed **not recording**. The earlier attempt also exposed PowerShell treating native stderr as terminating; the helper now preserves native output/exit status and handles cleanup explicitly.

The reported process exited before the fallback attach. Its replacement process **33296** was independently verified as the actual project game. The thread helper collected **83 valid samples / 32–33 threads** over **24.585 s**, then stopped when that process exited, with **no new captured stall**. This validates basic thread collection and process-exit cleanup; it does not explain the earlier freeze, retrospectively recover its native stack, or constitute a passing recurrence test. Native CPU/GPU profiling still needs an administrator/policy-enabled Windows session for the prepared WPR helper. No user game process was terminated or restarted by this task.

Additional changed files are the monitor, its regression test, the two PC helpers, and `game/tests/probe_hitch_scene_start.gd` (+ UID), which isolated a separate race-construction failure with diagnostics disabled. Concurrent mesh-chunking work assigned the empty name of an unparented source to its first chunk. `game/track/spatial_mesh_chunks.gd` now supplies `MeshInstance3D` only when that source is unnamed; existing names, triangles, normals, UVs, pigments, materials, transforms, shadows and budgets remain unchanged. This construction error arose during subsequent shared-workspace edits and is **not** claimed to have caused the earlier recorded Desert stall. The checkpoint includes only this two-line correction to the concurrently introduced chunker.

Actual follow-up commands:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_race_start.gd -Graphical -TestArgument '--themes=desert'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_hitch_scene_start.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_hitch_scene_start.gd -Graphical -TestArgument '--uncached'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_spatial_mesh_chunks.gd
scripts/dev.ps1 -Action Import
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action Doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/capture-race-hitch-trace.ps1 -GameProcessId 35568 -Seconds 60
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/capture-race-hitch-threads.ps1 -GameProcessId 33296 -Seconds 60
wpr.exe -status
```

Final actual validation: hitch tests **42 headless / 42 Compatibility / 42 Mobile-Vulkan**, exact mesh-chunk signature **34**, full parse **671**, pinned import and helper PowerShell AST checks pass. Actual injectable one-second and save stalls, foreground/pause suppression, every added emission context, bounded inventory/deduplication/byte cap and unchanged canonical state remain checked. Initial graphic missed-save assertions, a concurrently added terrain class missing from Godot's class cache, and the unrelated empty-name construction failure are retained; import restored class discovery, the naming bug was fixed, and the original assertions were kept. No visual/gameplay change was made for this Desert follow-up, so no new art screenshots were required.

Evidence/checkpoint is under `docs/evidence/desert-hitch-recurrence-2026-10-13/`: preserved live JSON, cached public track document, source snapshots, actual command outcomes, sampled thread data and a scoped review patch/hash manifest. Doctor found attached DN2103; **no phone logger/performance test, APK export/install, full Validate or backend deployment** was performed. Restart into updated source to obtain the expanded automatic capture; the original reported sessions have exited. Remaining acceptance: another actual recurrence with the new context (and preferably a successful native CPU/GPU trace) to identify the responsible resource/call/wait, then an attributable fix validated on PC and phone.
