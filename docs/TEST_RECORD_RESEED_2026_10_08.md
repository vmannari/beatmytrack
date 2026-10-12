# Artificial record reset and 100-player reseed — 2026-10-08

The owner requested clearing current track records and generating new times from 100 different artificial players on every current track. The owner explicitly limited the reset to **artificial/test records**. This operation targets the retained development backend, not production.

**Complete:** all **2,800 genuine five-lap races** are verified, and a read-only database audit confirms **2,800 saved personal bests**: the same **100 distinct artificial players on each of all 28 current tracks**. All five public real-player PBs still have the original exact digest. The catalog snapshot remains current. [Verified times CSV](evidence/record-reseed-2026-10-08/verified-times.csv), [final status](evidence/record-reseed-2026-10-08/final-status.json), [full run/PB audit](evidence/record-reseed-2026-10-08/final-audit.json), [final protection check](evidence/record-reseed-2026-10-08/final-protection.json).

## Requirements and scope

| Requirement | Implemented behavior |
|---|---|
| TD01 / B01–B07 | Create 100 persistent artificial identities with different seeded skill, consistency, aggression, surface strengths and other traits. Existing real identities remain unchanged. |
| TD02–TD03 / T01–T04 | Generate genuine compact-car, five-lap input recordings with `profiled-trajectory-5`; use ordinary tickets, uploads and canonical verification. No generated score is inserted directly. |
| TD05 / TD08–TD09 / Q01 | Persist one leased job per player and immutable track version in existing operation-state rows. Recover committed uploads before generating again; retry failures without duplicating verified results. |
| TD06 / B01–B07 | Reset only test-board or artificial-player PBs on the current logical tracks, including their older board versions. Preserve public real-player PBs exactly; retain accounts, raw run history, recordings, maps, ratings and player files. |
| WR03–WR07 | Remove corresponding test rivalry bests. Artificial boards/results remain excluded from public standings, ratings and community eligibility. Existing weekly membership is retained. |
| Q01 | Complete a fresh SQL backup before resetting; guard the owned deployment image and the exact record inventory. Temporary generation workers stop at batch completion and are removed afterward. |

The frozen catalog has **28 current published tracks**, including the community track **Star**. Unlike weekly selection, this batch includes compatible community tracks without applying rating/finisher eligibility thresholds. It pins their current published versions. Tracks published after the snapshot require a separate batch.

The compact is the existing artificial population vehicle. This is 100 players across all 28 tracks, not a separate 100-player population for each of the five vehicles.

## Reset and deployment evidence

Fresh Cloud SQL backup **1791437948170** completed successfully before the reset. The reset cleared **1,253 artificial/test PBs** and preserved **five public real-player PBs** with an identical digest. Old pending test uploads were fenced so they cannot restore the removed records; pending normal-player verification remains available.

The deployment is a minimal overlay over the already deployed physics **0.53**, compiler **22**, rules **v20**, controller **5** image. It adds the Python batch module and two integration hooks. There is no migration in this operation; a read-only parent/overlay comparison proved **all 113 packaged game files byte-identical**. API, worker, migration/smoke and catalog jobs use the same pinned image. Permanent API/worker sizing remains unchanged. [Packaged-game proof](evidence/record-reseed-2026-10-08/packaged-game-proof.json), [frozen module proof](evidence/record-reseed-2026-10-08/frozen-source-proof.json).

Sixteen temporary tasks, in four four-task executions, use the existing runtime identity and ordinary generation/verification path. Each uses one CPU and one database connection, with a three-hour maximum and no automatic task retries. Leased jobs survive task failure; helpers exit when the verified target is reached.

All four generation executions completed successfully, with **16 succeeded tasks, zero failed and zero still running**. The subsequent one-task read-only audit also succeeded. The owned temporary job was then removed; the ordinary retained backend worker remains available. [Execution completion evidence](evidence/record-reseed-2026-10-08/temporary-worker-completion.json).

Evidence: [inventory](evidence/record-reseed-2026-10-08/initial-inventory.json), [successful backup](evidence/record-reseed-2026-10-08/backup.json), [deployment](evidence/record-reseed-2026-10-08/deployment.json), [reset preview](evidence/record-reseed-2026-10-08/reset-preview.json), [reset receipt](evidence/record-reseed-2026-10-08/reset-and-start.json), [real-record protection](evidence/record-reseed-2026-10-08/real-record-protection.json), [bounded temporary workers](evidence/record-reseed-2026-10-08/temporary-workers.json).

## Development API and durable state

The hidden endpoints require the existing private operator key and enabled development authentication/test-driver configuration:

- `GET /v1/dev/test-drivers/batches/preview?vehicle_id=compact` returns the current compatible track snapshot, test-record count, protected public-record count/digest and inventory digest.
- `POST /v1/dev/test-drivers/batches` accepts the [strict request schema](schemas/test-population-batch-request-v1.schema.json). Its inventory digest must match the preview. A changed catalog/record inventory fails with `RECORD_INVENTORY_CHANGED`; a running batch blocks another reset. Repeating the exact completed request returns its existing batch rather than resetting again.
- `GET /v1/dev/test-drivers/batches/{batch_id}` returns verified job counts and distinct verified players per track. Submitted, failed or merely generated recordings do not count as verified results.

This operation uses seed **2026100800**, count **100**, vehicle **compact**, `clear_test_records=true`, and batch **f5d06ae7-deb6-5b71-b750-d2382ad15fe2**. Durable state uses the existing `OperationState` table; each job pins its player, document hash, immutable version, retry attempt, upload key and lease. Local caches are replaceable. Ordinary race/track verification queues retain priority over bulk generation.

## Changed files and actual verification

- `backend/bmt_backend/test_population_batch.py`: guarded reset, persistent batch, leased canonical generation and authoritative progress.
- `backend/bmt_backend/app.py` and `worker.py`: hidden router and idle-worker dispatch.
- `backend/tests/test_population_batch.py`: real-record protection, pending-test fencing, stale inventory/disabled gates, idempotency, exact player/track cardinality, genuine native verification and restart recovery.
- `backend/tools/audit_test_population_batch.py`: read-only comparison of every completed pair against its actual verified five-lap run, pinned test board and personal best, with bounded report entries.
- Request schema, this document, development status/plan and retained evidence describe the new contract and actual operation.

Actual commands used `.tools/backend-venv/Scripts/python.exe` and the backend adapter's pinned Godot **4.7.2 stable ed1daf0bf**. The new batch suite passed **three tests**, including ten real five-lap recordings for two players on five tracks and a new app instance recovering completion without additional uploads. The affected backend suite passed **44 tests**, with **four skipped and 15 deselected**; that total includes the batch tests and must not be added to them.

After strengthening the pending-upload protection assertions, the actual command `-m pytest backend/tests/test_population_batch.py -q -k 'not godot' --tb=short --show-capture=no` passed **two tests**, one deselected. After adding the read-only PB audit, the full `-m pytest backend/tests/test_population_batch.py -q --tb=short --show-capture=no` passed **three tests in 65.42 seconds**, including ten genuinely verified/audited races. Ruff passed for the batch module, tests, audit tool and worker. [Recorded outcomes](evidence/record-reseed-2026-10-08/test-outcomes.json), [final test log](evidence/record-reseed-2026-10-08/final-batch-tests.log).

Operator commands executed the private repository-local `record_reseed.py` actions `inspect`, `backup`, `deploy`, `begin` and `progress`, the frozen overlay builder, and bounded temporary job execution. `reseed_audit.py start` / `collect` audited the live PostgreSQL records and exported all times; `reseed_accelerate.py cleanup` removed the temporary job after every task had succeeded. Credentials stayed in Secret Manager/in memory and private local configuration; evidence contains no credentials. An initial absent-job CLI response was handled correctly before starting helpers; a verification command first looked for Docker on Windows PATH and was corrected to the configured WSL command. No rejected approval was bypassed.

The CSV contains total five-lap race seconds and all five lap splits, derived from the canonical 120 Hz ticks. These are test-population times for the compact; public standings remain real-player-only. Refresh the app's test-data view to fetch the new distribution. [Scoped source checkpoint](evidence/record-reseed-2026-10-08/record-reseed.patch) preserves unrelated working-tree changes.

No visible UI change, Android export/install, phone attachment check, device driving test or full `Validate` was performed. This operation changes development records and scheduling, not vehicle physics. Physical-device presentation, restored-backup exercises and pacing against elite human players remain separate acceptance checks.
