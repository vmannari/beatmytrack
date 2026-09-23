# In-game feature profiling — 2026-09-22

Requirements: R01/R03/R07/G01/V03/V05/Q01. Owner requested physical-phone feature costs, explicitly including the timing and speed observations used by Results. This task adds opt-in diagnostic instrumentation and measurements, without a production quality or handling change.

## Method and interpretation

Physical DN2103 / Android 13 / Mali-G77 MC9, pinned Godot 4.7.2 Compatibility renderer, installed debug APK identified in `evidence/performance-2026-09-22/apk-hash.txt`. Normal 3D scale is 0.667; the resolution experiment uses 0.50 with identical camera framing and full-resolution HUD. USB power and battery snapshots are recorded. Each stage restarts the race, warms for five seconds and measures twenty seconds. The normal baseline is repeated at the end. The probe drives with AI and exercises held touch events, the actual racing HUD and timed route validation. Attempts are unscored and cannot create personal bests.

Timers accumulate CPU microseconds across all physics ticks between rendered frames. Reported feature means are **CPU milliseconds per rendered frame**, not GPU timings. `sim` includes simulation plus collision-feedback/rumble preparation; `rules` is route progress, shortcut detection and lap timing; `telemetry` is the separate Results recorder. `car` includes interpolation, car/bridge/suspension presentation and tyre-audio updates. `props` updates moving track props; `hud` updates HUD values/session labels. `present` is a parent total containing car, props, camera and HUD; do not add it again. Weather's timer covers its advance/update work, not deferred CanvasItem drawing. HUD hiding suppresses rendering while retaining value updates. Whole-frame changes include rendering, scheduling and engine work; they are not an isolated GPU measurement or additive costs.

Physics and rules remain enabled in every comparison. Diagnostic-only switches suppress telemetry observations, particles, trail sampling/rendering, HUD rendering, weather updating/rendering, or shadows one at a time. The `half_scale` report label means absolute 0.50 3D scale, not half the normal scale. Normal play restores all features and the original render scale.

The old profiler included trails and particles inside `rules` and omitted weather from its presentation timer. New reports declare `timing_schema: 2`; old and new rule buckets are not directly comparable.

## Measured frame time

Median / p95 milliseconds. Lower is better; 60 FPS requires about 16.67 ms. Comparisons below use the opening baseline, with the closing baseline checking drift.

| Feature disabled / setting | Ajorata | Storm |
|---|---:|---:|
| Normal opening baseline | 19.672 / 23.733 | 24.146 / 26.439 |
| Results telemetry recording off | 19.637 / 23.364 | 24.059 / 26.755 |
| Shadows off | 16.773 / 30.235 | 18.075 / 20.865 |
| Tyre particles off | 19.792 / 23.182 | 24.159 / 26.322 |
| Tyre trails off | 19.599 / 23.286 | 23.916 / 25.963 |
| HUD hidden, value updates retained | 18.977 / 22.644 | 23.569 / 25.888 |
| Weather off | 19.720 / 23.543 (no weather here) | 16.740 / 20.248 |
| 3D scale 0.667 → 0.50 | 16.826 / 20.100 | 18.540 / 21.023 |
| Normal closing baseline | 19.774 / 23.587 | 24.200 / 26.551 |

Largest observed median reductions: Storm weather 7.406 ms; shadows 2.899 ms on Ajorata and 6.071 ms on Storm; reduced 3D resolution 2.846 / 5.606 ms. HUD hiding saved 0.695 / 0.577 ms. Telemetry saved only 0.035 / 0.087 ms; particles showed no gain, and trails only 0.073 / 0.230 ms in these workloads. These are whole-frame differences, not additive feature budgets. No setting achieved sustained 60 FPS across its slow frames; the Ajorata shadows-off p95 actually worsened.

## Instrumented CPU cost

Opening-baseline **mean milliseconds per rendered frame**. This includes multiple 120 Hz ticks where applicable; parent totals and engine monitor values are deliberately not added to these rows.

| Work | Ajorata | Storm |
|---|---:|---:|
| Simulation, collisions and rumble preparation | 3.413 | 1.242 |
| Route tracking, shortcut validation and lap clock | 1.787 | 2.097 |
| Car/bridge/suspension presentation and tyre audio | 0.937 | 0.905 |
| Weather CPU advance/update, excluding deferred drawing | — | 0.827 |
| Tyre particles CPU sampling | 0.296 | 0.290 |
| Tyre trail CPU sampling | 0.187 | 0.196 |
| HUD values/session updates, excluding deferred drawing | 0.172 | 0.172 |
| Results time/speed/position telemetry | 0.032 | 0.039 |
| Moving props | 0.068 | 0.018 |
| Follow camera | 0.067 | 0.065 |
| Diagnostic AI driver (not manual gameplay) | 0.166 | 0.226 |

Ajorata recorded 51 collisions, versus zero on Storm, so their simulation costs describe different workloads. Storm route validation is a larger recurring CPU expense than the new Results recorder. The telemetry recorder is approximately 0.16% of baseline frame time on both tracks.

## Interpretation and next optimization targets

1. **Storm presentation.** The complete weather ablation saved 7.4 ms while its timed CPU advance averaged 0.83 ms. This indicates substantial work outside that update, consistent with deferred rendering/compositing; it is not a direct GPU-time measurement. Code inspection identifies a full-viewport screen copy, full-resolution procedural wet-glass shader, six local lens shaders and redrawn rain/trails. Their individual costs have not been separated.
2. **Shadows / 3D rendering.** Shadows and reduced 3D resolution both materially improve median frame time. Shadow coverage/casters and pixel shading deserve targeted GPU experiments. The two improvements overlap; adding their savings would be misleading.
3. **Route validation and collision-heavy simulation.** Their directly timed costs are much larger than Results recording. Any optimization must preserve canonical physics, shortcut decisions and exact replay behavior.
4. **HUD.** There is a smaller measurable rendering benefit from hiding it. Its CPU value updates alone do not explain the complete HUD cost.

The measurements do not justify cutting Results telemetry or reducing particle density on these two workloads. No such production changes were made.

The closing baselines differ from the opening medians by only 0.102 / 0.054 ms, supporting the large observed effects despite warming. Battery temperature was 30.6°C initially, 35.8°C after Ajorata and 39.2°C after Storm; these are battery readings, not GPU junction temperatures. The collector's `battery-before.txt` was overwritten at the start of the Storm-only recovery run and therefore records the pre-Storm state. This is not a thermal-soak test.

## Results telemetry implementation

`LapTelemetry.observe` is called at 120 Hz but normally records a sample every six ticks (20 Hz). Samples contain time, position, speed and route progress. At a lap boundary it appends a completed-lap record; the active lap is bounded to 2,048 samples and decimated if necessary. Route validation/lap timing is independent of this recorder. `RaceResultData.build` prepares route geometry and copies completed laps only when the Results panel is created. Speed statistics, sector interpolation and graph colouring are Results work, not recurring driving work.

## Reproduction and verification

Actual commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestPerformance
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1
```

The fresh export passed import/startup, 74 driving, 18 catalog and 22 menu checks. Results: 94 checks, zero failures. Performance: nine impact-glass and 13 performance/equivalence checks, zero failures. The existing two-instance ObjectDB leak warning remains in the driving check. No full physics/replay regression was run because this task does not change canonical physics.

The initial PowerShell collector wrapped `ConvertFrom-Json` output in an extra array, so it only saved the first stage even while the phone correctly completed subsequent stages. The collector was corrected; all nine Ajorata reports were recovered directly from the phone before stopping that collector process. Storm then ran with `-StormOnly -SkipInstall` using the same installed APK. Raw reports and logs are retained under [the evidence directory](evidence/performance-2026-09-22/).

Changed implementation files: `game/core/game.gd` (separate opt-in timers and guarded diagnostic telemetry bypass), `game/diagnostics/mobile_race_probe.gd` (feature stages, means, schema and restoration), `scripts/profile-features-phone.ps1` (device runner and cleanup). Status/plan and this report document outcomes. Existing unrelated dirty-worktree edits were retained.

All eighteen stages completed. The diagnostic marker/results and temporary device configuration were removed, and the normal app was cold-launched successfully. Player tracks and records were retained. The installed APK retains ordinary rendering settings; instrumentation is inactive without the explicit debug marker. The [task-only review patch](evidence/performance-2026-09-22/profiling-changes.patch) excludes pre-existing implementation edits; it is supplied instead of committing unrelated shared-workspace changes.

The [Storm phone capture](evidence/performance-2026-09-22/storm-baseline.png) was visually inspected and shows the actual baseline driving scene. It was captured during the closing baseline and may perturb that stage's outliers; opening baselines are used for feature deltas. Neither track completed a lap within the short stages, so lap-boundary telemetry spikes remain unmeasured.

Final checks: both raw reports contain all nine stages; device `run-as ... ls files` confirms the diagnostic marker/results are absent. `git diff --check` passes for the modified tracked files. The task patch passes `git apply --reverse --check --ignore-space-change` (the workspace uses mixed Windows line endings; the first check without that whitespace option rejected the patch).

## Limits and remaining acceptance

Short diagnostic AI routes are not complete owner-driven races, a thermal soak or worst-case sustained dust/smoke. Ajorata's AI encounters obstacles and completes no lap; its lap-boundary telemetry spike is not measured by that run. Baselines and feature stages are sequential, weather lightning is presentation-random, and collision/particle trajectories can vary slightly with render scheduling. Small differences around a tenth of a millisecond should not be ranked as established improvements. Means of separately instrumented CPU sections do not account for every engine callback or deferred renderer operation. Direct GPU attribution, road-material versus scenery cost, long thermal sessions, maximum-effect loads and other devices remain unmeasured. No production art/UI change was made, so no visual acceptance screenshot is claimed.
