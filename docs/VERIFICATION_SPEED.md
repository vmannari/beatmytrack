# Lightweight race verification — 2026-10-09

The owner explicitly prioritizes low server computation and fast results over catching every handling/collision manipulation. This authorizes sparse movement plausibility checks for ordinary completed races. Requirement IDs: task-local **VF01** (lightweight proof), **VF02** (player priority/background yielding), **VF03** (compatible fallback and durable evidence), **VF04** (prompt result polling), plus **B05/B07/Q01/R01/WR07–WR08/CH09**. This supersedes exact replay execution as the only permitted competitive validation method. The live game simulation, pinned track/car contracts, five laps, normal results first, best-only scoring, resume receipts and public/artificial population isolation remain.

## Measured result

Five repeated warm verifications of the same original 12,757-tick, five-lap oval on the pinned Windows engine, including ghost capture:

| Path | Median wall time | Median engine CPU time |
|---|---:|---:|
| Before this task, full replay | 1.7022 s | 1.6563 s |
| Optimized full replay fallback | 1.0609 s | 1.0156 s |
| Sparse movement proof | 0.1397 s | 0.0781 s |

The fast path is about **12.2× faster** and uses **95.3% less engine CPU** in this fixture. Both Python and engine CPU/RSS samples are retained in [benchmark evidence](evidence/verification-speed-2026-10-09/optimized-benchmark.json); [original measurements](evidence/verification-speed-2026-10-09/baseline-benchmark.json) use the captured before-task runner. The frozen Linux development image independently accepts both paths with the same manifest and lap ticks; its lightweight call measured **0.1249 s**. These are local fixture measurements, not promised cloud end-to-end or worst-case performance. Track compilation, queue pickup, storage/network latency and UI polling remain outside that warm engine cost.

Initial instrumentation identified approximately 0.43–0.51 s of ghost water-depth sampling on a dry track and 1.0–1.13 s of physics work. The optimized immutable track uses conservative occupancy tiles, dry-water exclusion, preserved route candidate/tie order, empty kerb-region exclusion and prefiltered prop/hazard lists. Positive/uncertain regions use the original arithmetic. Canonical simulation and mutable editor tracks are unchanged.

## Runtime contract and deliberate limits

The app records `bmt-race-proof-v1` samples at 20 Hz and forces lap-end samples: tick, position, heading, velocity, elevation layer and jump height. It sends this evidence only after the backend advertises `lightweight_race_proofs`; existing clients/outboxes remain compatible. Evidence is included in the durable recording/hash and survives app restart, packed transport and its legacy-wire fallback. The encoder restores integer tick/layer types after Godot JSON parsing.

The server validates bounded finite data and unchanged quantized inputs, pins the actual immutable track/car, checks the standing start, movement/velocity consistency, broad speed/acceleration limits, input-count duration and **every ordered track gate**, requiring all five laps and a finish at the exact input count. It derives race/lap ticks from the checked sample timeline, rather than accepting a claimed `time_ms` or PB. The fixture retains lap ticks `[2634,2532,2531,2530,2530]` and ghosts. Between forced boundaries, checking a chord instead of all intermediate 120 Hz states may miss fine trajectory detail; fractional finish interpolation can differ by roughly one sample interval. This is the owner-approved accuracy tradeoff.

The proof does **not** establish that all motion follows the submitted pedals/steering or reproduce exact tire forces, kerb losses and collisions. A deliberately fabricated but plausible trajectory can evade these checks. Uncertain/implausible proofs fall back to full replay rather than rejecting a legal race; missing proof, older clients, creator validation and rewind races use full replay. Invalid input/envelope/receipt/build checks still fail closed. Detailed anti-cheat accuracy is intentionally outside this faster policy.

Player jobs precede artificial-driver jobs while preserving fairness among actual players. Long development driver generation checks for compatible ready player work every 250 ms, terminates only its own generator process and leaves the unfinished artificial attempt resumable without spending a retry or inventing a result. Banked/daily resume behavior and artificial/public isolation are unchanged. Initial result polling can run at one second for ten seconds, then returns to existing longer intervals/backoff; a pending cache no longer masks completed results for three seconds.

## Changed files

- Engine boundary: `game/backend/{runner,verification_track,lightweight_verifier,race_proof}.gd`; standalone packaging in `backend/deploy/stage_verifier.py`.
- App recording/durable uploads/polling: `game/core/{game,app}.gd`, `game/backend/{cloud_tracks,backend_client,weekly_rivalry_client,challenges_client}.gd`.
- Backend acceptance/queue/polling: `backend/bmt_backend/{verifier,replay_wire,app,worker,background_work,automatic_test_drivers,test_population_batch,runs,rivalry,challenges,observability}.py`.
- Contracts: `backend/schemas/{race-proof-v1,packed-input-v1}.schema.json`; no database migration or rules/physics/handling version change.
- Diagnostics/tests: `backend/tools/benchmark_verification.py`, `backend/tests/{test_lightweight_verifier,test_cloud_client}.py`, `game/tests/{test_lightweight_verifier,test_backend_scalability,test_cloud_tracks}.gd`.
- Owner override/status: `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this report and `docs/evidence/verification-speed-2026-10-09`.

## Actual commands and outcomes

All engine commands use the exact `godot-version.txt` build through `scripts/dev.ps1` or existing real-engine pytest adapters. Windows certificate-store access required normal execution after the initial sandbox import failed; no certificate/trust configuration was changed.

| Actual command/workflow | Outcome |
|---|---|
| `dev.ps1 Import`; `CheckScript` for the two new verifier scripts | Import/parser passed after normal certificate access; initial sandbox certificate error retained. |
| `dev.ps1 TestScript -ScriptPath res://tests/test_lightweight_verifier.gd -TestArgument @('--fixture=…/verified_oval.json','--proof-output=…/proof.json')` | **17,436 checks, zero failures**: every canonical fixture state exact, five laps/light proof, invalid movement fallback, water shore/tile/exterior collision equivalence and route tie order. Initial CLI argument/PowerShell policy errors corrected. |
| `pytest backend/tests/test_lightweight_verifier.py backend/tests/test_persistent_verifier.py backend/tests/test_verifier.py -q` | **78 passed**: real replay, launch, rewind, invalid/truncated/trailing inputs, persistent engine/recycle/recovery, bounded caches and maximum replay. |
| `pytest` lightweight/auth/scalability/lifecycle/population/automatic-driver/challenge files `-k 'not postgres'` | **93 passed, 7 skipped, 34 deselected**. |
| Owned disposable PostgreSQL wrapper over lightweight/scalability/lifecycle/population/challenges | **91 passed, 7 skipped**; only its own container removed after ownership check. Initial default localhost PostgreSQL was unavailable: **63 passed, 6 skipped, 17 connection errors**; no tests were relabeled as passed. |
| Final `pytest backend/tests/test_lightweight_verifier.py -q` | **9 passed**, including packed proof shape, poll budgets, actual authenticated HTTP/worker/idempotency/ghost storage and human preemption. Initial test-environment configuration error corrected without relaxing the gate. |
| `pytest backend/tests/test_cloud_client.py::test_cloud_library_against_http -q` | Final pass; **49 native checks**, exact completed-ticket upload and observed `movement-proof-v1`. The old fixture checked an earlier done upload before asynchronous save; it now waits for this race's save. The obsolete `RANK` expectation now checks the existing actual `POSITION`/`TOP` display. Both initial failures are retained in work logs. The separate durable lifecycle HTTP test passed on the initial run. |
| `dev.ps1 TestScript …test_backend_scalability.gd`; `TestApp`; `TestRewind`; weekly-rivalry/challenges scripts | **17 / 99 / 61 / 1109 / 84 checks**, zero failures. Initial proof dictionary int/float equality fixture corrected by asserting normalized wire evidence. |
| Benchmark tool on before/optimized standalone projects, five repeats each | Timings/engine CPU/RSS and invariant checks saved as JSON. |
| Frozen development-image operator `prepare`, `build`, `test` | Task-only 15-file overlay; all unrelated 110 original packaged game files exact. Linux canonical and sparse five-lap checks pass with networking disabled. |
| `dev.ps1 ExportAndroid` | Broad validation stopped at **two storm spray-render assertions** (`front spray stays quieter…`, `water fan travels farther…`); earlier replay/checkpoint/editor gates passed. These assertions were not changed or claimed green. |
| `dev.ps1 ExportAndroid -QuickValidation` | Focused startup/driving72/catalog21/menus48 passed and matching-template APK exported. |
| `dev.ps1 Doctor` | Tablet `f0ba474a` **offline**; no install, device run or physical-device acceptance. |
| Ruff on new Python modules/tool/test | Passed. |

## Deployment and acceptance

The tested task-only image is prepared and pushed for the existing **development** API/worker and related acceptance jobs, with an explicit environment/ownership/image guard. Fresh SQL backup **1791562942686** succeeded. Image digest **280effff11c02dcebb08d0334db8e0c3d012091004ed72f2acdf02979f2cc2ef** passed Linux checks. No database migration or player-record rewrite is needed; resource settings and production remain outside this update. The [receipt](evidence/verification-speed-2026-10-09/development-rollout.json) records preparation, build, push and backup.

Automatic approval review rejected the attempted `image_operator.py deploy` command **before execution**: replacing a shared cloud API/worker is a consequential mutation and optimization authorization did not explicitly authorize this exact remote deployment. Explicit owner approval was requested. The remote API/worker have not been replaced and remote post-deployment smoke has not run. The prepared image/backup/local Linux checks remain available; deployment awaits that approval.

The APK at `build/android/circuit01-debug.apk` is **241,155,846 bytes**, SHA256 **84D361FD882CC0F28E7D58EBA7DF8CA2C3FA1E372BE80258441AE98B2066863C**. Android clients need this update to send proofs. After approved server rollout, older installed versions will benefit from faster full replay and queue priority, while their ordinary races continue through the fallback. The attached tablet remains offline, so installation and on-device completion latency remain outstanding. Also outstanding: representative live tracks/cars/bridges/hazards and fallback-rate/queue-latency monitoring under sustained cloud load. No visual layout/art change or new UI label was made; no UI screenshot is required for this server/transport slice.
