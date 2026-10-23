"""Record completed commands, proof measurements and the source-only checkpoint."""
import difflib
import hashlib
import json
import shutil
import statistics
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FILES = ['backend/bmt_backend/' + name + '.py' for name in (
    'run_signals', 'app', 'config', 'runs', 'worker_lifecycle')]
FILES += ['game/backend/' + name + '.gd' for name in (
    'backend_client', 'cloud_tracks', 'weekly_rivalry_client', 'challenges_client')]
FILES += ['game/ui/race_complete.gd', 'backend/tests/test_run_confirmation.py', 'game/tests/test_run_confirmation.gd',
          'backend/README.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']
uid = 'game/tests/test_run_confirmation.gd.uid'
if (ROOT / uid).exists():
    FILES.append(uid)
patch = []
for name in FILES:
    current, before = ROOT / name, HERE / 'before' / Path(name).name
    patch.extend(difflib.unified_diff(before.read_text(encoding='utf-8').splitlines(keepends=True) if before.exists() else [],
        current.read_text(encoding='utf-8').splitlines(keepends=True),
        fromfile='a/' + name if before.exists() else '/dev/null', tofile='b/' + name))
(HERE / 'task-only.patch').write_text(''.join(patch), encoding='utf-8')

measured = {}
for variant in ('original', 'final'):
    packets = [json.loads((HERE / (variant + '-http-pair' + str(pair) + '.json')).read_text()) for pair in (1, 2)]
    samples = [sample for packet in packets for sample in packet['samples']]
    measured[variant] = {'samples': len(samples),
        'medians': {key: statistics.median(sample[key] for sample in samples) for key in samples[0]}}
old = measured['original']['medians']['upload_to_confirmation_ms']
new = measured['final']['medians']['upload_to_confirmation_ms']
tests = {file.name: ET.parse(file).getroot().find('testsuite').attrib for file in HERE.glob('*.xml')}

markers = ['RUN_CONFIRMATION_TESTS:', 'RIVALRY_FEEDBACK_TESTS:', 'RIVALRY_TRACK_TIME_TESTS:', 'CHALLENGES:',
           'MISSION_OUTBOX ', 'BACKEND_EXCEPTION_RECOVERY:', 'RIVALRY_GHOST_RETRY:', 'APP_TESTS:', 'SCRIPT_PARSE:',
           'EARNED_COINS_APP:']
directory_stat = HERE.stat()
started = getattr(directory_stat, 'st_birthtime', directory_stat.st_ctime)
# Only replace this helper's generated copies, never the original build logs.
for previous in (HERE / 'native').glob('TestScript-*.log'):
    assert previous.resolve().is_relative_to(HERE.resolve())
    previous.unlink()
native = {}
for file in (ROOT / 'build/logs').glob('TestScript-*/test-script.log'):
    if file.stat().st_mtime < started:
        continue
    content = file.read_text(encoding='utf-8', errors='replace')
    found = [line.strip() for line in content.splitlines() if any(marker in line for marker in markers)
        or ('test_run_confirmation.gd' in line and ('at:' in line or 'error' in line.lower()))]
    if not found:
        continue
    target = HERE / 'native' / (file.parent.name + '.log')
    target.parent.mkdir(exist_ok=True)
    shutil.copyfile(file, target)
    native[str(target.relative_to(HERE))] = found

container = ("wsl -d Ubuntu -- docker run --rm --network container:bmt-backend-test "
    "-v '/mnt/c/Codes/Godot/Beat my track/backend:/task/backend:ro' "
    "-v '/mnt/c/Codes/Godot/Beat my track/.tools/backend-postgres.env:/task/db.env:ro' "
    "-v '/mnt/c/Codes/Godot/Beat my track/docs/evidence/race-confirmation-latency-2026-10-22:/evidence' "
    "-e PYTHONPATH=/task/backend -e PYTHONDONTWRITEBYTECODE=1 -w /task/backend --entrypoint python 303c521ef446 ")
report = {
    'date': '2026-10-22',
    'task': 'Prompt durable race-worker wake-up and bounded foreground result delivery with normal polling recovery',
    'requirements': {
        'RCF01': 'Wake idle competitive workers after committed admissions/retries without shortening idle polling globally.',
        'RCF02': 'Deliver a committed result promptly through a bounded asynchronous authorized wait.',
        'RCF03': 'Consume exact receipts in uploads/Rivalry/challenges/Coins without waiting for existing polling timers.',
        'RCF04': 'Measure actual upload-to-confirmation HTTP against an independent real-checker worker process.',
        'R01': 'Keep the checker, lease/build/owner/account fences, atomic PBs/rewards, durable identities, limits and fallback polling.',
        'Q01': 'Record actual outcomes, original reproduction, corrections, limitations and a task-only review checkpoint.'},
    'changes': {
        'hints': 'SQLAlchemy collects bounded Run changes and publishes only after the outer commit. Rollback/savepoint release cannot announce an uncommitted result. Notifications contain a work bit and at most64 run IDs, never authoritative time/points/currency or credentials. Failures are best-effort and cannot fail an already committed race.',
        'transport': 'One background transport per engine coalesces pending hints and uses PostgreSQL LISTEN/NOTIFY in autocommit outside the job transaction. Its channel is scoped to the current database schema. It borrows at most one connection from the existing bounded pool while publishing/listening, releases it when unused, restores statement timeout/isolation, and invalidates broken connections. Notification statements have a500ms timeout and reconnection backs off. Pools below two connections and custom unpooled engines retain periodic recovery.',
        'worker': 'Idle workers listen; hinted foreground scans release the idle listener slot before claiming work. LISTEN readiness/reconnect wakes an authoritative catch-up scan, avoiding startup races. One-second fallback scans, SKIP LOCKED fairness, pinned builds, leases, retries and bounded drain remain. Busy workers continue the original immediate queue loop.',
        'http': 'Add GET /v1/runs/{run_id}/wait?timeout_ms=0..2000, advertised through run_wait_ms. Each API process permits four waits by default, one per player, configurable with BMT_RUN_WAIT_CAPACITY1..64. Saturation returns a fresh normal status immediately. No request SQL transaction/thread is held while awaiting an event. Reads recheck ownership, account/development restrictions, the original token/family/revocation/consumption/expiry, and query durable Run/competition results. Lost hints are checked at most once a second. Disconnect/timeout/failure releases the subscription; existing endpoints remain available.',
        'client': 'Fresh uploads schedule one coalesced foreground request per client with a five-second transport timeout. Other outbox jobs and frame updates continue. Account clearing cancels the HTTP request; generation/origin/player and exact run/ticket fences discard stale or mismatched replies. Missing older endpoints disable waits; failure/timeouts retain original polling. A completed cache receipt retires the durable upload without another status HTTP request.',
        'views': 'Completion wakes Rivalry/challenge result handling. Rivalry retains its exact-outcome cache path; challenge confirmation can bypass its poll deadline while failures keep backoff. Coins refresh from their existing authoritative reward endpoint immediately, coalescing an in-flight pending read; the original two-second timer remains fallback. Layout, labels, reward amounts/reveal and normal finish-screen ordering are unchanged.',
        'checker': 'No source edits to trajectory_verifier.py, verifier.py or json_data.py, and no changes to the previously consolidated acceptance/PB/wallet transaction.'},
    'measurement': {
        'variants': measured,
        'confirmation_speed_ratio': old/new,
        'confirmation_time_reduction_percent': (1-new/old)*100,
        'design': 'Two alternating original/current pairs; eight unprofiled samples plus one warm-up per variant per pair, sixteen measured races per variant. Fresh migrated PostgreSQL schemas, real loopback HTTP, separate worker processes, warm local objects and native-generated geometry. Arrival phases vary across the original one-second idle cycle. Original uses archived worker idle cadence plus one-second client polling; current uses the same scoring code with wake/wait. No artificial SQL/network latency.',
        'proof': '2130 path samples, real checker, exact12757 ticks and laps2634/2532/2531/2530/2530 asserted for every reply; native invocation forbidden in warmed workers.',
        'limits': 'The HTTP driver is a Python client with a fixture-only identity override, not a measured phone/Godot UI. Actual Godot transport/cache/outbox/receipt-view behavior is tested separately with controlled replies. This does not measure cloud network/object storage, identity-service latency, mobile rendering, high concurrency, tail load or million-DAU capacity. A bounded wait may time out under backlog and resume normal polling.'},
    'validation': {
        'receipts': tests,
        'native_receipts': native,
        'native_receipt_collection': 'Relevant native logs from the task time window; repeated/parser observations are retained without summing duplicate test counts.',
        'summary': 'Focused SQLite11 passed; broader SQLite70 passed/4 PostgreSQL-only skips; PostgreSQL regression33 passed plus focused8; actual Linux signal/drain/recovery4 passed; pinned native/verifier/HTTP10 passed. Native completion/Coins14, Rivalry feedback18/time18, challenges165, outbox11, exception recovery28, ghost retry17, App141, earned-Coins App11 and final parser receipt are recorded in native logs.',
        'original': 'The unchanged idle-wake invariant fails on the archived loop at its0.5s deadline with a5s configured idle wait. Before/after HTTP measurements use that archived loop in independent child processes, not fabricated elapsed times.',
        'corrections': [
            'The initial pool assertion raced the intentional LISTEN-ready catch-up read; synchronize to the actual waiting period and retain the zero-request-transaction assertion.',
            'Real-session tests caught use of the JSON document digest instead of the existing access-token digest. Corrected to security.digest; family revocation, consumed tokens and expiry now pass.',
            'The initial native test transport override omitted its optional key default, then attempted to read the void _save_job return. Both fixture errors were corrected before final native tests.',
            'Foreground hints now release the idle worker listener slot before claiming, preserving pool availability for concurrent driver work.',
            'Helper import/unused-import lint issues were corrected; no invariant or runtime acceptance check was relaxed.'],
        'remaining': ['Matching API/worker/client rollout and owner acceptance',
            'Cloud and physical-device end-to-end latency, load/CPU/memory and connection/HTTP-concurrency calibration',
            'Broadcast wake-up costs across many idle replicas and notification transport failure/queue-pressure validation under representative sustained load'],
        'resource_tradeoff': 'An active listener shares one existing pool slot, and each foreground wait occupies one bounded HTTP slot. Defaults reserve four of the current16 HTTP concurrency slots; saturation recovers through polling. Notification work adds best-effort background SQL; it is not part of atomic acceptance and must be included in production capacity sizing.',
        'boundaries': 'Source changes only; no live API/account/race/publication mutation or deployment, no schema migration, no phone attachment check/device test or APK/export/install. The local test PostgreSQL was initially stopped, started for this task, then stopped after a read-only check found zero other clients. No appearance change or rendered screenshot claim.'},
    'commands': {
        'postgres': container + '/evidence/run_postgres.py tests/test_run_confirmation.py tests/test_worker_lifecycle.py tests/test_race_acceptance_sql.py tests/test_earned_coins.py tests/test_scalability.py::test_optional_ghost_storage_failure_does_not_delay_scoring_or_hold_db_locks tests/test_scalability.py::test_finalization_db_failure_keeps_fenced_job_recoverable tests/test_robustness_fixes.py::test_retry_and_finalize_complete_concurrently_without_deadlock -k "postgres and not sqlite" --junitxml=/evidence/postgres-regression-final.xml',
        'linux_signals': container + '/evidence/run_postgres.py tests/test_worker_lifecycle.py -k real_signals --junitxml=/evidence/linux-signals-final.xml',
        'measure_http': container.replace('-w /task/backend', "-v '/mnt/c/Codes/Godot/Beat my track/docs/evidence/race-acceptance-sql-2026-10-22/native-fixture.json:/task/native-fixture.json:ro' -w /task/backend") + '/evidence/measure_http.py --count 8',
        'sqlite': "$env:PYTHONPATH='backend'; $env:PYTHONUTF8='1'; .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_run_confirmation.py backend/tests/test_worker_lifecycle.py backend/tests/test_race_acceptance_sql.py backend/tests/test_earned_coins.py backend/tests/test_verification_preparation.py backend/tests/test_robustness_fixes.py::test_retry_and_finalize_complete_concurrently_without_deadlock -k 'not postgres and not real_signals' -q --tb=short --junitxml=docs/evidence/race-confirmation-latency-2026-10-22/sqlite-regression-final.xml",
        'original': '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/race-confirmation-latency-2026-10-22/reproduce_original.py',
        'godot': ['powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/' + name + '.gd'
            for name in ('test_run_confirmation', 'test_rivalry_feedback', 'test_rivalry_track_time', 'test_challenges',
                         'test_mission_outbox', 'test_backend_exception_recovery', 'test_rivalry_ghost_retry',
                         'test_earned_coins_app', 'test_app', 'test_script_parse')],
        'native_verifier': "BMT_GODOT_BIN=C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe; BMT_GAME_PROJECT=build/race-verification-2026-10-22/optimised-ea803f8b-5b76-4430-8390-9f1d100c406d/game; .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_lightweight_verifier.py backend/tests/test_hairpin_gate_contract.py -k 'not postgres' -q --tb=short --junitxml=docs/evidence/race-confirmation-latency-2026-10-22/native-verifier-final.xml",
        'assemble': '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/race-confirmation-latency-2026-10-22/finish_evidence.py'},
    'references': [
        {'url': 'https://www.postgresql.org/docs/18/sql-listen.html', 'applied': 'Commit LISTEN before catch-up reads; notifications remain hints around reconnect races.'},
        {'url': 'https://www.postgresql.org/docs/18/sql-notify.html', 'applied': 'Keep notification publication outside acceptance so notification queue failures cannot roll back a race.'},
        {'url': 'https://www.psycopg.org/psycopg3/docs/advanced/async.html#asynchronous-notifications', 'applied': 'Dedicated-use autocommit connection and bounded notifies generator timeout.'}],
    'changed_files': FILES,
    'source_sha256': {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in FILES},
    'unchanged_checker_sha256': {name: hashlib.sha256((ROOT/'backend/bmt_backend'/name).read_bytes()).hexdigest()
        for name in ('trajectory_verifier.py', 'verifier.py', 'json_data.py')},
    'task_patch_sha256': hashlib.sha256((HERE/'task-only.patch').read_bytes()).hexdigest()}
(HERE/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'measurements': measured, 'speed_ratio': old/new, 'tests': {
    name: {key: value.get(key) for key in ('tests', 'failures', 'errors', 'skipped')} for name,value in tests.items()},
    'native': native}, indent=2))
