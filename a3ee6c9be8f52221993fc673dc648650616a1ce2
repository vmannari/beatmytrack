# Daily limits overlap selected-track preparation — 2026-11-05

Implemented the requested independent loading stages. A Daily race tap now begins its fresh limits read before waiting for the selected-track CPU worker. The same read survives metadata download/hydration and the handoff into the compiled start path. The race still requires both complete CPU preparation and validated limits before installation, and the full existing graphics preparation before enabling the countdown.

## Requirements and implementation

- **DLO01 — overlap independent work.** `game/race/daily_start_preparation.gd` holds one attempt-local receipt on the existing loading cover. Its static read uses the existing authenticated/public backend transport. It holds a plain response while geometry is incomplete. No request is made merely because the player browses an event; the race tap starts it. The existing single CPU worker remains responsible for track preparation.
- **DLO02 — preserve exact validation.** `game/core/features/race.gd` joins the stages through the existing `_load_daily_limits` boundary. The original engine, tick rate, vehicle, track schema/content hash, compiler, rules, physics/config, day, version, population and cutoff checks remain. Manifest validation happens against the hydrated track. The fallback hydration path also retains its original source entry, allowing the same full source pin to remain valid across handoff.
- **DLO03 — scope, expiry and ownership.** The receipt pins account/origin, backend client and session generation, navigation/screen, selected object, car, track identity/version/source hashes and compiled content hash. When available it also pins the visible Daily page's day/end time/source identity. Mutable request dictionaries are copied before suspending. Monotonic expiry includes time spent waiting for the response and subsequent CPU/graphics preparation; it never extends the visible event's existing deadline. The loading-current checks reject expired or changed attempts during installation and graphics staging. Closing the cover clears its response. The read owns only a weak receipt reference, so a delayed response after App destruction cannot retain or publish that attempt.
- **DLO04 — retained behavior and measured proof.** Daily still installs ten laps, canonical tick zero and all 360 countdown ticks. Retry uses a fresh limits request through the same validation boundary. Ordinary and Rivalry ticket ordering is unchanged. No geometry, materials, shaders, camera, reflection, quality setting, physics or backend contract was changed.

An authenticated coalesced read can finish through the existing backend transport after its cover closes; its attempt-local receipt is already invalidated. This does not cancel another consumer's shared HTTP request. Responses are not retained across starts or retries.

## Verification

`test_daily_loading_overlap.gd` exercises the actual App/race controller and production limits validation with controlled backend responses and an independently held CPU readiness stage. It checks both completion orders, public/authenticated routes, one read per attempt, navigation/account/session/car/selection/version/source/content changes, Daily page day/source changes, request failure, incompatible manifests, expiration during the read/CPU/installation, a late response during a newer start, metadata hydration and complete owner teardown.

`test_daily_loading_worker.gd` additionally uses the real selected-event worker on the Star spline document. It verifies that the limits request starts while that worker is unfinished, then installs the exact hydrated selected object with fresh ten-lap limits and the complete start clock. The normal selected-event, Daily metadata, early-prepared event and Daily App integration fixtures remain retained checks.

The timing fixture substitutes only the archived task-start race controller for its control. It loads each controller before the timer, interleaves old/new starts on the same App, uses a controlled 300 ms CPU stage and 200 ms limits response, and records the time at which both requirements have joined as well as full entry time. Both arms install an actual Daily Game. These are deterministic scheduling observations on desktop with artificial delays, not measurements of live service latency, phone loading or the earlier cold graphics bottleneck.

| Controlled stage join | Serialized controller | Overlapped controller |
| --- | ---: | ---: |
| Pair 1 | 524.263 ms | 309.104 ms |
| Pair 2 | 513.435 ms | 313.522 ms |
| Median of two | 518.849 ms | 311.313 ms |

This removes about 208 ms from the controlled join, consistent with overlapping the 200 ms response. Full entry rows are retained but the first control also pays initial Game resource loading, so no aggregate cold-entry speedup is inferred from them.

Eight accepted final-runtime runs total **301 checks / 0 failures**: focused headless **98/0**, focused native Compatibility **98/0**, real selected worker **7/0**, retained Daily App **17/0**, metadata **6/0**, early-prepared event **7/0**, selected events **58/0**, and timing/integration **10/0**. They have unchanged sources during each run, both final runtime hashes, and no engine warnings/script/resource errors apart from the certificate-store environment error. The archived-controller negative control is separate: **8 checks / 1 expected failure**, specifically that the limits request has not started while CPU preparation is blocked. That original regression assertion is retained.

## Reproduction and evidence

The runner pins Godot `4.7.2.stable.official.ed1daf0bf`, writes a private empty backend configuration, uses task-owned APPDATA and Dummy audio, records the exact command/process/status and before/after source hashes, and bounds only its own process tree. Backend responses/authentication in these tests are explicit local adapters. Native checks use the default desktop Compatibility renderer; headless runs do not certify native appearance.

Use new labels when repeating:

```powershell
python docs/evidence/daily-loading-overlap-2026-11-05/run_check.py final-focused-headless-v3 res://tests/test_daily_loading_overlap.gd --headless --timeout 180
python docs/evidence/daily-loading-overlap-2026-11-05/run_check.py final-focused-native-v2 res://tests/test_daily_loading_overlap.gd --timeout 300
python docs/evidence/daily-loading-overlap-2026-11-05/run_check.py before-focused-control-v2 res://tests/test_daily_loading_overlap.gd --headless --control
python docs/evidence/daily-loading-overlap-2026-11-05/run_check.py final-timing-v3 res://tests/test_daily_loading_overlap.gd --headless --timing --timeout 180
python docs/evidence/daily-loading-overlap-2026-11-05/run_check.py final-worker-v2 res://tests/test_daily_loading_worker.gd --headless --timeout 120
python docs/evidence/daily-loading-overlap-2026-11-05/run_final_checks.py
python docs/evidence/daily-loading-overlap-2026-11-05/summarize.py
python docs/evidence/daily-loading-overlap-2026-11-05/checkpoint.py
```

The [evidence directory](evidence/daily-loading-overlap-2026-11-05/) retains all attempts, the archived controller, raw logs/receipts and [derived results](evidence/daily-loading-overlap-2026-11-05/summary.json). Initial findings are retained: the first missing-metadata lookup emitted errors despite passing assertions; explicit `has_meta` fixes it. The first App-coroutine read retained its receipt on owner destruction; the weak static transport read fixes it, with the original teardown assertion retained. The initial native fixture's six-second polling deadline expired during graphics preparation; its failed assertions remain recorded. The test polling allowance is now 60 seconds; the production 45-second loading deadline is unchanged. A reserved `Node.owner` name in the new worker fixture was renamed. The first timing harness used SceneTree timers and produced inconsistent wall-time delays; its numbers are excluded. A second timing attempt included the first candidate controller load, and is also excluded from the matched comparison. The final harness uses monotonic wall deadlines and loads both controllers before timing. No readiness or visual invariant was weakened. A scoped termination attempt made after that native process had already completed returned `Access denied`; no successful termination or owner-process action occurred.

All engine attempts retain the Windows certificate-store environment error. This task changes two runtime files, adds two diagnostic fixtures and evidence/report/tracker files. Its source checkpoint is limited to these changes and checked forward/reverse without writing the main index. Concurrent startup, scenery retention, graphics and prepared-asset work is preserved.

Reload and owner/device acceptance remain. No physical-device query/test, APK/export, owner-save/process change, real authentication, live/backend request or mutation, deployment or main-index write was performed. Any end-to-end benefit depends on how much real CPU work and service wait are available to overlap; this implementation does not remove first-use graphics compilation.
