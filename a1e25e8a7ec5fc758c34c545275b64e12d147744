# Actual commands

PowerShell; workspace `C:/Codes/Godot/Beat my track`. Backend pytest commands
run from `backend`, after setting:

```powershell
$env:PYTHONPATH='C:\Codes\Godot\Beat my track;C:\Codes\Godot\Beat my track\backend'
```

The first command ran without that assignment and retained its collection error
in `initial.log`. The corrected invocation retained `initial-r2.log`:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_storage.py tests/test_packed_storage.py tests/test_gcs_storage.py tests/test_s3_storage.py tests/test_reward_ranks.py tests/test_test_drivers.py tests/test_population_batch.py tests/test_automatic_test_drivers.py tests/test_non_improving_runs.py -k 'not postgres and not migration_backfills_existing_field and not godot' --basetemp=../build/backend-work-reduction-initial-r2 -q
```

Focused commands used the same selection, with successive base directories
`backend-work-reduction-focused`, `backend-work-reduction-focused-r2`, and final
`backend-work-reduction-focused-final` as fixtures and coverage were completed:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_backend_work_reduction.py -k 'not postgres' -q --basetemp=../build/backend-work-reduction-focused-final
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_backend_work_reduction.py tests/test_earned_coins.py tests/test_cost_http.py -k 'not postgres' -q --basetemp=../build/backend-work-reduction-final-focused
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_race_acceptance_sql.py tests/test_rivalry.py tests/test_rivalry_awards.py tests/test_challenges.py tests/test_challenge_series.py tests/test_scalability_admission.py tests/test_attack_resistance.py -k 'not postgres and not additive_attempt_migration' -q --basetemp=../build/backend-work-reduction-related
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_race_acceptance_sql.py tests/test_attack_resistance.py::test_fresh_queries_coalesce_across_cache_restart -k 'not postgres' -q --basetemp=../build/backend-work-reduction-recheck
```

These native commands ran with the local Windows access required by Godot:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_non_improving_http.py tests/test_population_batch.py::test_batch_generates_real_five_lap_proofs_and_survives_app_restart -q --basetemp=../build/backend-work-reduction-native
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_cost_http.py -q --basetemp=../build/backend-work-reduction-native-cost
```

From the workspace root:

```powershell
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-work-reduction-2026-10-26/baseline_probe.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-work-reduction-2026-10-26/benchmark.py
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/storage.py backend/bmt_backend/packed_storage.py backend/bmt_backend/gcs_storage.py backend/bmt_backend/s3_storage.py backend/bmt_backend/runs.py backend/bmt_backend/test_population_tool.py backend/bmt_backend/test_population_batch.py backend/bmt_backend/economy.py backend/bmt_backend/reward_rank_cache.py backend/bmt_backend/migrations/versions/0070_reward_cache_revisions.py backend/tests/test_backend_work_reduction.py backend/tests/test_race_acceptance_sql.py backend/tools/audit_test_population_batch.py docs/evidence/backend-work-reduction-2026-10-26/benchmark.py docs/evidence/backend-work-reduction-2026-10-26/baseline_probe.py
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-work-reduction-2026-10-26/finalize.py
.tools/backend-secure-venv/Scripts/python.exe -m ruff check docs/evidence/backend-work-reduction-2026-10-26/finalize.py
git diff --check -- backend/bmt_backend/storage.py backend/bmt_backend/packed_storage.py backend/bmt_backend/gcs_storage.py backend/bmt_backend/s3_storage.py backend/bmt_backend/runs.py backend/bmt_backend/rivalry.py backend/bmt_backend/test_population_tool.py backend/bmt_backend/test_population_batch.py backend/bmt_backend/economy.py backend/tests/test_race_acceptance_sql.py backend/tools/audit_test_population_batch.py
```

The baseline probe intentionally returns failure on the three regression cases.
`finalize.py` also runs `git apply --reverse --check` on the scoped checkpoint;
it never applies that patch. PostgreSQL DDL was emitted using
`MigrationContext.configure(create_mock_engine('postgresql://', collector).connect())`
and `Operations.context(context)` around the new migration's upgrade/downgrade.
The twelve emitted statements are retained in `postgres-migration.sql`.
