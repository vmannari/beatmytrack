"""Assemble source-only review evidence from completed runs, without services."""
import difflib
import hashlib
import json
import statistics
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FILES = ['backend/bmt_backend/' + name + '.py' for name in (
    'worker', 'economy', 'rivalry', 'challenges', 'achievements', 'studio_finance', 'race_acceptance')]
FILES += ['backend/tests/test_race_acceptance_sql.py']
FILES += ['DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']
patch = []
for name in FILES:
    current = ROOT / name
    before = HERE / 'before' / current.name
    patch.extend(difflib.unified_diff(before.read_text(encoding='utf-8').splitlines(keepends=True) if before.exists() else [],
        current.read_text(encoding='utf-8').splitlines(keepends=True),
        fromfile='a/' + name if before.exists() else '/dev/null', tofile='b/' + name))
(HERE / 'task-only.patch').write_text(''.join(patch), encoding='utf-8')

medians = {}
for label in ('original', 'final'):
    packets = [json.loads((HERE / (label + '-pg-pair' + str(pair) + '.json')).read_text()) for pair in (1, 2)]
    samples = [sample for packet in packets for sample in packet['samples']]
    medians[label] = {key: statistics.median(sample[key] for sample in samples) for key in samples[0]}
old, new = medians['original'], medians['final']
tests = {file.name: ET.parse(file).getroot().find('testsuite').attrib for file in HERE.glob('*.xml')}

container = ("wsl -d Ubuntu -- docker run --rm --network container:bmt-backend-test "
    "-v '/mnt/c/Codes/Godot/Beat my track/backend:/task/backend:ro' "
    "-v '/mnt/c/Codes/Godot/Beat my track/.tools/backend-postgres.env:/task/db.env:ro' "
    "-v '/mnt/c/Codes/Godot/Beat my track/docs/evidence/race-acceptance-sql-2026-10-22:/evidence' "
    "-e PYTHONPATH=/task/backend -e PYTHONDONTWRITEBYTECODE=1 -w /task/backend --entrypoint python 303c521ef446 ")
report = {
    'date': '2026-10-22',
    'task': 'Consolidate database work within one accepted race while keeping the checker and atomic scoring/rewards',
    'requirements': {
        'RSQL01': 'Reduce repeated claim/finalization SQL without batching separate races or adding eventual consistency.',
        'RSQL02': 'Bound shared acceptance reads and reward milestone reads independently of total account/board population.',
        'RSQL03': 'Measure original/current real-checker worker jobs on local isolated PostgreSQL schemas.',
        'RSQL04': 'Exercise same-player parallel workers, retries, late rollback, account restriction, reward caps and competition rules.',
        'R01': 'Keep checker/build/content/timing policy, Player-to-Run locks, leases and durable idempotent receipts.',
        'Q01': 'Record commands, actual outcomes, original failures, source fingerprints, review patch and acceptance limits.'},
    'changes': {
        'claim': 'Fetch Run/Board/TrackVersion/Player in the existing single-row SKIP LOCKED claim. Reuse the pinned-filter expression. Claim still locks only Run; account eligibility is reread under the finalization Player lock.',
        'acceptance': 'One transaction-local indexed join loads Board/TrackVersion/Track, optional competition bindings, receipt/wallet and prior race/lap tick scalars. Each join is one-to-one; no population/history result set is loaded. Missing bindings/receipt are explicitly retained. References live only through this race transaction, not in a shared cache.',
        'previous_bests': 'Capture scalar PB times before marking Run verified, retaining pre-trigger lap minima and precise PB reward/competition semantics.',
        'milestones': 'Read at most six exact primary-key scopes in one query. Reuse mutations locally and allow normal ORM flushes to group pending changes. Once a permanent track marker exists, omit the historical-run existence query; historical runs without markers retain the original first-track eligibility check.',
        'wallet': 'Reuse the already locked Player and wallet fact. The original finalization SELECT emits PostgreSQL FOR NO KEY UPDATE, which serializes ordinary Player-locking wallet writers. Standalone economy/purchase/import callers retain locked_wallet and its original lock/read path.',
        'ledger': 'Insert the original opening and earned ledger identities in one two-row ON CONFLICT DO NOTHING statement. Preserve existing opening balances/revisions and historical entries. Wallet, milestones, CoinReward, PBs, achievements, competition outcomes and captured news still share one commit. The transaction-local receipt is updated so a repeated writer call cannot mint twice.',
        'checker': 'No edits to trajectory_verifier.py, verifier.py or json_data.py. No validation, timing, geometry, resource or acceptance check is removed. No native simulation was added to warm acceptance.'},
    'measurement': {
        'medians': medians,
        'worker_latency_reduction_percent': (1-new['worker_ms']/old['worker_ms'])*100,
        'worker_speed_ratio': old['worker_ms']/new['worker_ms'],
        'sql_statement_reduction_percent': (1-new['sql_statements']/old['sql_statements'])*100,
        'finalization_latency_reduction_percent': (1-new['finalization_ms']/old['finalization_ms'])*100,
        'design': 'Two alternating original/current process pairs, each using a freshly migrated disposable PostgreSQL schema and 40 unprofiled warm samples after two warm-up races: 80 samples per variant. PostgreSQL tests finished before these measurements. No injected round-trip delay.',
        'fixture': '2130 trajectory samples, pinned native-generated geometry from Godot4.7.2, real Python checker, exact12757 ticks and laps2634/2532/2531/2530/2530. Every timed job asserts its verified result, reward receipt and exact wallet balance. Native invocation is forbidden during measured acceptance.',
        'scope': 'Complete process_one claim through commit, warm local object files and SQLite-free PostgreSQL; steady tied repeat races on the player-owned published track. First/new PB/competition paths are correctness-tested separately, not timed here.',
        'limits': 'Excludes upload, HTTP, cloud object/network latency, optional ghost artifacts, production queue/poll waiting, cold content churn and sustained concurrent capacity. SQL counts are driver-issued statements; implicit transactions and trigger-internal work are not counted. The shared Windows/WSL host is variable. This is not a million-DAU capacity or a halved database-CPU claim.',
        'initial_observations': 'Before final ledger batching, baseline-pg.json and consolidated-pg.json showed47 to27 statements. Final claims use the alternating *-pg-pair files only.'},
    'validation': {
        'receipts': tests,
        'postgres': 'postgres-regression.xml:100 passed/2 failed. All accepted-race/reward/achievement/competition/PB/concurrency cases passed; the two failures stop at unrelated telemetry migration0051 downgrade guards. postgres-focused-final.xml:11 passed, including all eight new PG cases plus challenge daily/goal and actual retry-lock concurrency.',
        'sqlite': 'sqlite-regression-final.xml:39 passed/4 skipped; excludes the independently reproduced old reward-rank downgrade fixture. sqlite-final.xml:9 passed/3 PostgreSQL-only skips. Preparation/lifecycle41 passed; real native/checker/HTTP10 passed.',
        'original': 'original-reproduction.xml: unchanged query-budget assertion fails49>30 on the saved original worker. Three existing challenge/lap/reward migration tests also fail on original sources because migration0051 refuses downgrade; no assertions or rollback protection were weakened.',
        'initial_corrections': ['The first original-source probe needed its unchanged appearance and achievement catalog JSON files next to archived modules; those files were copied and the probe rerun.',
            'Ruff corrected helper import formatting before final checks.',
            'A new wallet-cap test conditional assertion was corrected before execution.',
            'The evidence source hasher was corrected to skip generated __pycache__ directories.',
            'One shell-only XML summary command had a PowerShell quoting error; the file-based evidence assembler replaces it.'],
        'lint': 'Ruff passes all changed runtime/test files and evidence helpers; scoped git diff --check passes.',
        'remaining': ['Matching backend/worker rollout and owner acceptance',
            'Representative cloud mixed-track/new-PB/competition concurrent load and peak memory/lock contention',
            'Separate repair of historical downgrade fixtures around the newer telemetry rollback policy'],
        'boundaries': 'No live deployment/account/race/publication mutation. Only unique test schemas were created/dropped. Existing local test PostgreSQL was already running and remains running. No phone attachment check/device test, UI change/capture, APK/export/install, protocol or schema migration.'},
    'commands': {
        'seed': "$env:PYTHONPATH='backend'; $env:PYTHONUTF8='1'; & .tools/backend-secure-venv/Scripts/python.exe docs/evidence/race-acceptance-sql-2026-10-22/measure_acceptance.py --seed",
        'postgres_regression': container + '/evidence/run_postgres.py',
        'postgres_focused': container + '/evidence/run_postgres.py tests/test_race_acceptance_sql.py tests/test_challenge_discovery.py::test_verified_rewards_are_visible_once_and_limited_per_day tests/test_challenge_discovery.py::test_goal_requires_a_real_rival_and_is_credited_atomically tests/test_robustness_fixes.py::test_retry_and_finalize_complete_concurrently_without_deadlock -k postgres --junitxml=/evidence/postgres-focused-final.xml',
        'benchmarks': container + '/evidence/run_benchmarks.py',
        'sqlite_regression': ".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_earned_coins.py backend/tests/test_achievements.py backend/tests/test_reward_ranks.py -k 'not postgres and not migration_backfills_existing_field' -q --tb=short --junitxml=docs/evidence/race-acceptance-sql-2026-10-22/sqlite-regression-final.xml",
        'sqlite_final': '.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_race_acceptance_sql.py backend/tests/test_challenge_discovery.py::test_verified_rewards_are_visible_once_and_limited_per_day backend/tests/test_challenge_discovery.py::test_goal_requires_a_real_rival_and_is_credited_atomically backend/tests/test_robustness_fixes.py::test_retry_and_finalize_complete_concurrently_without_deadlock backend/tests/test_studio_platform.py::test_existing_wallet_opening_balance_is_not_earnings -k "not postgres" -q --tb=short --junitxml=docs/evidence/race-acceptance-sql-2026-10-22/sqlite-final.xml',
        'preparation_lifecycle': '.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_verification_preparation.py backend/tests/test_worker_lifecycle.py -k "not postgres and not real_signals" -q --tb=short --junitxml=docs/evidence/race-acceptance-sql-2026-10-22/preparation-lifecycle.xml',
        'native': "$env:BMT_GODOT_BIN='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'; $env:BMT_GAME_PROJECT='C:/Codes/Godot/Beat my track/build/race-verification-2026-10-22/optimised-ea803f8b-5b76-4430-8390-9f1d100c406d/game'; .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_lightweight_verifier.py backend/tests/test_hairpin_gate_contract.py -k 'not postgres' -q --tb=short --junitxml=docs/evidence/race-acceptance-sql-2026-10-22/native-final.xml",
        'original': '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/race-acceptance-sql-2026-10-22/reproduce_original.py',
        'assemble': '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/race-acceptance-sql-2026-10-22/finish_evidence.py'},
    'changed_files': FILES,
    'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES},
    'unchanged_checker_sha256': {name: hashlib.sha256((ROOT / 'backend/bmt_backend' / name).read_bytes()).hexdigest()
        for name in ('trajectory_verifier.py', 'verifier.py', 'json_data.py')},
    'original_source_sha256': {file.name: hashlib.sha256(file.read_bytes()).hexdigest()
        for file in (HERE / 'before').glob('*') if file.is_file()},
    'task_patch_sha256': hashlib.sha256((HERE / 'task-only.patch').read_bytes()).hexdigest()}
(HERE / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'medians': medians, 'latency_reduction_percent': report['measurement']['worker_latency_reduction_percent'],
    'tests': {name: {key: value.get(key) for key in ('tests', 'failures', 'errors', 'skipped')} for name, value in tests.items()}}, indent=2))
