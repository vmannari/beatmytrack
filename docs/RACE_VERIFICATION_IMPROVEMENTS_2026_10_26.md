# Race verification improvements — 2026-10-26

The request is stronger race-result verification without higher computation. **VRI01** closes a sample-spacing speed loophole; **VRI02** uses the recorded start for gate crossings; **VRI03/Q01/R01** retain the single-pass checker and measure it against the exact original source. The trajectory-only acceptance policy remains in effect.

## Changes

`backend/bmt_backend/trajectory_verifier.py` is the only production file changed.

- The existing 5 cm movement allowance for a six-tick interval now scales with elapsed ticks. Previously a one-tick interval received the entire allowance too, so adding samples could increase the permitted speed. The ordinary 20 Hz limit is unchanged, including its 10% car-speed allowance. Short intervals now have the same speed allowance per unit time.
- The first gate's signed distance now comes from the first validated recorded position. Previously it came from the nominal server start, although subsequent interpolation used the recorded position. A tolerated start offset could therefore invent a first-gate crossing.
- Six squared movement limits and the numeric type tuple are prepared once per check. The loop uses a lookup instead of recalculating a square and constructing type tuples for every position. The first-gate projection is moved, rather than duplicated.

Both compact four-field paths and legacy eight-field proofs use these changes. Five ordinary laps, one creator lap, finite/map-bounded positions, monotonic time, the six-tick maximum gap, ordered gates, layer checks, finish timing, rewind duration/receipts, optional ghosts and incident reporting remain. No physics, client code, wire schema, geometry preparation, cache identity, economy, database migration or deployment changes are needed for this patch.

The new `backend/tests/test_trajectory_integrity.py` covers both proof representations, creator/ordinary starts, legitimate tolerated offsets, the speed loophole at intervals of one through five ticks, valid movement at every interval and the unchanged six-tick speed boundary. `backend/tools/benchmark_trajectory_comparison.py` compares a trusted local source snapshot with the current checker using identical paths and prepared geometry.

## Results

The new regression file against the exact original checker produced **14 failures / 17 passes**. The same assertions pass after the fix. Existing assertions and tolerances were not weakened.

The final focused suite produced **68 passed**, including the real pinned-engine five-lap and creator recordings, HTTP publication/submission/idempotent retries, optional ghost handling, rewind timing, queue priority, geometry caching/build fences, strict JSON bounds and the existing hairpin test. The original five-lap timing remains **12,757 ticks**, with lap ticks **[2634, 2532, 2531, 2530, 2530]**.

| Local matched benchmark | Samples | Before wall/check | After wall/check | Before CPU/check | After CPU/check |
|---|---:|---:|---:|---:|---:|
| Actual recorded five-lap path | 2,130 | 1.260201 ms | 1.023794 ms | 1.250000 ms | 1.093750 ms |
| Same path with stationary holds, 28.38 minutes | 34,065 | 19.469120 ms | 15.782000 ms | 18.750000 ms | 15.625000 ms |

These are medians of 25 batches per implementation, alternating execution order. The regular case uses 100 checks per batch; the long case uses five. Both implementations receive the same decoded data and return identical results. Assertions run outside timed batches. CPU time uses `process_time_ns`; Windows timer granularity is visible in the CPU figures. Wall time fell approximately **19%** in both cases; measured CPU time fell **12.5% / 16.7%**. These local measurements establish no observed cost increase for the measured workloads, rather than a universal server latency guarantee.

Static native track preparation is outside the timed region. A failing engine stub guards subsequent acceptance; the measured checks and the prepared-geometry adapter made **zero engine calls**. The long path is a synthetic stationary expansion of the real recording, not a claimed 28-minute device drive. Space remains constant apart from existing lap output, with seven cached squared bounds; work remains one pass over samples and gate crossings.

## Actual commands

Commands below ran from the repository root unless the backend directory is specified. Full outputs and the exact original source are under `docs/evidence/race-verification-improvements-2026-10-26/`.

1. From `backend`: `../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_trajectory_integrity.py -q --basetemp=../build/verification-improvements-tests-before` — **14 failed, 17 passed** before the production edit. An earlier root-directory invocation could not import `bmt_backend`; its log is retained.
2. From `backend`: `../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_trajectory_integrity.py tests/test_hairpin_gate_contract.py -q --basetemp=../build/verification-improvements-tests-unit` — **32 passed**.
3. `.tools/backend-secure-venv/Scripts/python.exe backend/deploy/stage_verifier.py --repo . --destination build/verification-improvements-game` — **89 canonical inputs staged** in a separate project.
4. Pinned `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path build/verification-improvements-game --import --quit --log-file build/verification-improvements-import.log` — import passed. Only the staged project's logging configuration was adjusted during setup; shipping project settings were untouched.
5. From `backend`, with `BMT_GAME_PROJECT` set to the absolute staged project: `../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_lightweight_verifier.py tests/test_verification_preparation.py tests/test_trajectory_integrity.py tests/test_hairpin_gate_contract.py -q --basetemp=../build/verification-improvements-tests-native` — **68 passed**, with existing Starlette/SQLAlchemy warnings. The native run used approved access outside the sandbox because Windows certificate-store reads and Godot log writes were blocked inside it.
6. `.tools/backend-secure-venv/Scripts/python.exe backend/tools/benchmark_trajectory_comparison.py --baseline docs/evidence/race-verification-improvements-2026-10-26/trajectory_verifier.before.py.txt --godot "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe" --project build/verification-improvements-game --fixture backend/tests/fixtures/verified_oval.json --proof build/verification-improvements-tests-native/lightweight-proof0/proof.json --output docs/evidence/race-verification-improvements-2026-10-26/benchmark-final.json` — both paths accepted identically, zero engine calls and the measurements above. Copies of the exact proof and fixture are retained alongside the report for reproduction.
7. `.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/trajectory_verifier.py backend/tests/test_trajectory_integrity.py backend/tools/benchmark_trajectory_comparison.py` — passed. `git diff --check -- backend/bmt_backend/trajectory_verifier.py` — passed.

Setup failures are preserved: an unimported staged project caused two fixture errors; after import the sandbox still caused two native infrastructure failures. A direct diagnostic identified blocked Godot log writes and Windows certificate-store reads. The approved native run passed without relaxing the verifier's fail-closed diagnostics. One benchmark attempt also hit the sandbox-created temporary directory's access controls; the successful run used the proof from the successful native tests. The initial benchmark harness lint findings were corrected before final measurement.

## Review and remaining acceptance

The task-only `checkpoint.patch` and `report.json` record changed files, hashes, commands and results. Concurrent work is excluded. No Git commit or merge was made.

The checker continues to establish a plausible timestamped trajectory, rather than proving exact steering, collision or traction physics. The measurements cover one actual circuit and a long stationary expansion; wider live-car/track and sustained cloud measurements remain acceptance work. A matching backend rollout is needed to activate the change online and requires separate authorization. No live backend mutation or deployment occurred. No device attachment check or physical-device test was performed; no APK was built and no owner process was restarted.
