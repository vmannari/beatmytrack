# Avoid repeated backend race work — 2026-10-26

The owner requested implementation of the four opportunities identified after
non-improving race verification was skipped. Completion and clean-race rewards,
competitive scores, immutable uploads and retry recovery retain their rules.

## Requirements and implementation

| ID | Requirement | Result and files |
| --- | --- | --- |
| BWR01 | Encode and hash a submitted replay once | `storage.PreparedJSON` creates immutable canonical bytes and SHA256 together. `runs.submit`, pinning, packed intake/fallback, Local, GCS and S3 pass that same prepared value. Ordinary dictionaries remain accepted by the storage API. |
| BWR02 | Avoid recomputing unchanged Rivalry standings | `rivalry.accept_verified` reuses its before snapshot for tied, slower and skipped results. An actual improvement still flushes the score and calculates the after snapshot. Other achievement consumers retain their own existing snapshots. |
| BWR03 | Enable the existing skip for artificial repeat races | `test_population_tool` negotiates capability version 1 and adds the generator's five lap ticks only to a newly generated compact recording, before freezing its upload cache. Existing cached bodies stay exact. Both scheduler and batch worker treat `skipped` as successful completion; batch views and the audit keep verified/skipped counts distinct and require a verified PB source. |
| BWR04 | Avoid repeated percentile checks when eligibility cannot improve | `reward_rank_cache` stores up to 8,192 checks per engine/process in memory. A hit requires identical database board revisions, the same player/board/metric, an equal or slower candidate, and an already earned tier at least as high as the checked result. Existing maximum-tier bypass remains. |
| R01 | Preserve authoritative rewards, population changes and recovery | Misses use the exact Fenwick rank query. The cache reads counters and revisions together, publishes only after the outer transaction commits, and discards rollback checks. Nested checks are never published. Cache resets/evictions/worker restarts just cause recalculation. |
| Q01 | Demonstrate reduced work and retained behavior | Focused regressions, existing backend suites, native Godot/HTTP tests, task-start negative controls and a retained-source local benchmark are recorded below. |

Reward revisions are read in the existing milestone query, rather than adding a
database round trip or a persisted cache record. Migration
`0070_reward_cache_revisions` fills invalidation gaps for deletion/visibility
changes and moving a PB between boards or players. It adds three triggers and
their PostgreSQL functions; no table, API role grant or rank-counter write on an
ordinary non-improving race is added. Rare visibility/reclassification/move
operations also invalidate the relevant board revisions. Busy boards with
continuously changing PBs can have low cache hit rates; their exact rank queries
remain necessary.

Storage retains canonical ordering, finite JSON and 8 MiB limits, conditional
publication, pinning, atomic local writes, compression, durable packed intake
and corruption checks on stored reads or duplicate publication. A mutable
source dictionary cannot change an already prepared object's bytes or digest.
The HTTP body/idempotency hash and retained content addresses are unchanged.

Changed runtime files: `backend/bmt_backend/storage.py`, `packed_storage.py`,
`gcs_storage.py`, `s3_storage.py`, `runs.py`, `rivalry.py`,
`test_population_tool.py`, `test_population_batch.py`, `economy.py`, new
`reward_rank_cache.py` and migration `0070_reward_cache_revisions.py`; diagnostic
consumer `backend/tools/audit_test_population_batch.py`. Tests are in
`backend/tests/test_backend_work_reduction.py`. The existing acceptance SQL test
now counts the same single milestone read when expressed as a join; its query
budget, no-history, no-ledger and reward assertions remain.

## Actual validation

Commands use `.tools/backend-secure-venv/Scripts/python.exe`; pytest runs from
`backend` with `PYTHONPATH` containing the workspace and backend directory.
Each run uses a fresh `build/backend-work-reduction-*` base directory. Exact
commands and complete outputs are retained in the evidence directory.

- Focused final suite: **33 passed**, 23 PostgreSQL parameters deselected.
  It covers one replay encoding through pinning/packed/fallback and HTTP retry,
  unchanged/improved Rivalry snapshots, frozen driver recordings, successful
  bot skip/batch/audit, cache size, candidate/tier changes, both PB metrics,
  correction/deletion/visibility changes, old/new board moves, rollback and
  savepoint safety, same-snapshot generation, and migration round trip.
  An additional end-to-end case grows the leaderboard and awards higher race
  and lap tiers on an unchanged, slower-than-PB race.
- Storage, ranks, artificial drivers and existing skip regressions:
  **100 passed, 3 skipped**, 39 deselected. Existing historical reward-rank
  downgrade and native tests were excluded from this run.
- Related competition, acceptance, admission and attack suites:
  initial **89 passed, 4 skipped, 2 failed**, 81 deselected. The acceptance
  failure expected `FROM coin_milestones` rather than the new single joined
  query; its assertion now recognizes the joined read. A discovery cursor
  coalescing assertion also failed once and passed unchanged on recheck.
  Acceptance plus that unchanged discovery test: **7 passed, 2 skipped**.
- Earned-coin tests and the then-current 32 focused tests: **44 passed,
  1 skipped**. A native HTTP test in that invocation failed in the restricted
  process when starting the engine; it was rerun with the local native access
  used by this repository and **passed**.
- Native Godot/HTTP: **2 passed** — authenticated non-improving upload and
  explicit reuse; a real ten-race, five-lap artificial-driver batch and restart.
  Separate packed storage/download/decoder HTTP integration: **1 passed**.
  These are local desktop-engine tests against disposable backend databases.
- Task-start Rivalry, generator and uncached percentile functions were loaded
  only into an isolated test process. The selected new regressions produce
  **3 expected failures, 1 pass**: redundant standings calculation, missing
  newly generated hint, and repeated rank reads. Worktree sources stay intact.
- PostgreSQL migration upgrade/downgrade emitted **12 DDL statements** through
  SQLAlchemy's mock PostgreSQL dialect. This checks the emitted branch, not live
  PostgreSQL behavior. SQLite executes the complete migration and round trip.
- Changed implementation and test files pass Ruff. `rivalry.py` retains two
  task-start lint findings (unused `func` and a nested condition) outside its
  one-line change; they are not hidden or rewritten.

Initial collection failed because `backend.tools` needed the workspace on
`PYTHONPATH`; the rerun supplies it. The first focused fixture omitted a
scheduler `due` field and counted an unrelated achievement standings call;
both fixtures were corrected without disabling any behavior. Original logs
are retained. PostgreSQL connection/concurrency acceptance remains outstanding;
the previously configured local PostgreSQL test service was unavailable.

## Measured benefit

`benchmark.py` runs 21 alternating batches with the retained original storage
module and current module, using the same 92,963-byte / 2,130-sample proof.
The actual digest + pinned + deduplicated Local publication path keeps its
integrity reads; pin SQL is omitted equally from both sides. Median elapsed
time is **13.924 ms → 9.169 ms, 34.2% lower**, saving about **4.75 ms** per
submission in this local case. This is more conservative than the earlier
serialization-only estimate because unchanged IO and integrity work remain.

For 20 drivers and five tracks, actual standings computation without SQL is
**0.287 ms → 0.143 ms, 50.1% lower**. The unchanged score writer also avoids
two SELECTs. Eligible reward-cache hits remove both rank SELECTs with no
persisted cache write. Bot repeats meeting the existing skip conditions avoid
queue admission and trajectory verification; driving/generation still occurs.
These are component measurements and conditional query savings, not a measured
production latency or hosting-bill reduction.

## Review and acceptance

`docs/evidence/backend-work-reduction-2026-10-26/report.json` records source
hashes, logs and the task-only `checkpoint.patch`. The patch excludes concurrent
histogram changes in `runs.py`; earlier non-improving verification and other
shared work are preserved. No staging, commit or merge was performed.

Apply migration **0070** with the corresponding backend rollout before using
the reward cache. No deployment or live database mutation was performed. Live
PostgreSQL concurrency and production cache-hit/cost measurements remain.
No device attachment check/test, APK, purchase, owner save mutation or owner
process restart was performed. No visible UI changes require captures.
