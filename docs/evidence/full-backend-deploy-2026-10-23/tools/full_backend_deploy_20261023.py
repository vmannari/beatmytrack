"""Owner-authorized schema57 complete backend release, with frozen inputs."""
import argparse
import ast
import importlib.util
import inspect as reflection
import json
import shutil
import subprocess
import secrets
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release18', ROOT / '.tools/full_backend_deploy_20261018.py')
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)
d = previous.d
d.WORK = ROOT / 'build/full-backend-deploy-2026-10-23'
d.OUTPUT = ROOT / 'docs/evidence/full-backend-deploy-2026-10-23'
d.CONTEXT = d.WORK / 'image'
d.RECEIPT = d.OUTPUT / 'rollout.json'
d.WORK.mkdir(parents=True, exist_ok=True)
d.OUTPUT.mkdir(parents=True, exist_ok=True)
d.r = json.loads(d.RECEIPT.read_text(encoding='utf-8')) if d.RECEIPT.exists() else {}
HEAD = '0057_discovery_resource_guards'

base_text = (ROOT / '.tools/backend_latest_rollout_20261016.py').read_text(encoding='utf-8')
base_tree = ast.parse(base_text)
for function_name in ('push_image', 'backup', 'finish'):
    node = next(node for node in base_tree.body if isinstance(node, ast.FunctionDef) and node.name == function_name)
    source = ast.get_source_segment(base_text, node)
    source = source.replace('20261016', '20261023').replace('2026-10-16', '2026-10-23')
    exec(source, d.__dict__)


def inspect_live():
    jobs = json.loads(d.service.call('run', 'jobs', 'list', '--region=' + d.config['region'], '--format=json'))
    owned = [item['metadata']['name'] for item in jobs if item['metadata'].get('labels', {}).get('bmt-owner') == d.config['owner']]
    targets = [('api', d.service.n['api']), ('worker', d.service.n['worker'])] + [('job', name) for name in sorted(owned)]
    assert len(owned) == 5, owned
    extras = [('sql', d.service.n['sql']), ('bucket', d.service.n['bucket'])]
    found, parents, summaries = {}, {}, {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        values = list(pool.map(lambda item: (item, d.service.describe(*item)), targets + extras))
    for (kind, name), value in values:
        assert value is not None, name
        (d.WORK / ('before-' + name + '.private.json')).write_text(json.dumps(value), encoding='utf-8')
        if kind in ('api', 'worker', 'job'):
            found[name] = kind
            parents[name] = d.stage.resource_image(value)
            summaries[name] = {'kind': kind, 'image': parents[name]}
        if kind == 'api':
            api = value
        if kind == 'sql':
            assert value['settings']['deletionProtectionEnabled']
    prior = json.loads((d.DIRECTORY / 'deployment.json').read_text())
    assert parents[d.service.n['api']] == prior['image']
    assert all(image == prior['image'] for name, image in parents.items() if name != d.service.n['worker'])
    expected_worker = json.loads((ROOT / 'docs/evidence/rivalry-generation-fix-2026-10-22/report.json').read_text())['release']['target']['deployed_image']
    assert parents[d.service.n['worker']] == expected_worker
    url = api['status']['url']
    assert url == prior['url']
    key = d.u.staff_key(api)
    overview = d.u.fetch(url, '/v1/admin/overview', key).json()
    health = d.u.fetch(url, '/v1/admin/competition-health', key).json()
    bootstrap = d.u.fetch(url, '/v1/bootstrap').json()
    for label, value in [('health-before', health), ('bootstrap-before', bootstrap)]:
        (d.WORK / (label + '.private.json')).write_text(json.dumps(value), encoding='utf-8')
    docker = ['wsl.exe', '-d', 'Ubuntu', '--', 'docker']
    for role in ['api', 'worker', 'db']:
        name = 'bmt-pc-dev-' + role + '-1'
        result = subprocess.run([*docker, 'inspect', name], capture_output=True, check=True)
        value = json.loads(result.stdout)[0]
        assert value['Config']['Labels']['com.docker.compose.project'] == 'bmt-pc-dev'
        (d.WORK / (name + '-before.private.json')).write_text(json.dumps(value), encoding='utf-8')
    d.r.update(parent=prior['image'], target_parents=parents, targets=found, url=url, owner=d.config['owner'],
               schema_before=overview['schema'], schema=HEAD, old_traffic=api['status']['traffic'],
               image_variant='complete-schema57', started_utc=datetime.now(timezone.utc).isoformat())
    d.save()
    result = {'url': url, 'schema_before': overview['schema'], 'schema_target': HEAD,
              'queue_depth': health['queue_depth'], 'health': health['status'], 'available_workers': health['available_workers'],
              'targets': summaries, 'pc_targets_inspected': 3, 'owner_verified': True}
    (d.OUTPUT / 'initial-readonly.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


def freeze():
    previous.freeze()
    check_freeze()


def check_freeze():
    d.r['schema'] = HEAD
    # The latest source must retain the already-deployed generation interruption fix.
    expected = json.loads((ROOT / 'docs/evidence/rivalry-generation-fix-2026-10-22/report.json').read_text())['release']['candidate_manifest']['overlay_files']
    source = d.WORK / 'frozen/backend/bmt_backend'
    checks = {name: d.digest((source / name).read_bytes().replace(b'\r\n', b'\n')) == sha for name, sha in expected.items()}
    # Shared worker/observability modules legitimately include later discovery changes.
    required = ['automatic_test_drivers.py', 'driver_work.py', 'test_driver_generator.py']
    assert all(checks[name] for name in required), checks
    d.r['generation_fix_comparison'] = checks
    d.save()
    print(json.dumps({'schema': HEAD, 'source_hash': d.r['source_hash'], 'generation_fix_retained': True}))


def prepare():
    previous.prepare()
    install = d.CONTEXT / 'install.py'
    install.write_text(install.read_text().replace("SCHEMA_HEAD=='0042_achievements'", 'SCHEMA_HEAD==' + repr(HEAD)), encoding='utf-8', newline='\n')
    d.r['build_files'] = previous.hashes(d.CONTEXT)
    d.save()


def build():
    source = reflection.getsource(previous.build).replace("def build():", "def candidate_build():")
    source = source.replace('20261018', '20261023')
    namespace = {'d': d, 'json': json, 'hashes': previous.hashes}
    exec(source, namespace)
    namespace['candidate_build']()


def native_debug():
    b = d.builder()
    code = '''import json,subprocess,shutil
from pathlib import Path
shutil.copytree('/source','/tmp/native/game');Path('/tmp/native/godot-version.txt').write_text('4.7.2.stable.official.6bc42c6d5')
p=Path('/tmp/input.json');p.write_text(json.dumps({'operation':'manifest'}))
for args in [ ['--editor','--import'], ['--script','res://backend/runner.gd','--','--input=/tmp/input.json','--output=/tmp/output.json'] ]:
 r=subprocess.run(['godot','--headless','--path','/tmp/native/game',*args],capture_output=True,text=True,timeout=180)
 print(r.stdout+r.stderr)
'''
    source = '/mnt/' + d.WORK.drive[0].lower() + d.WORK.as_posix()[2:] + '/image/canonical/game'
    output = b.runner.run([*b.c['docker'], 'run', '--rm', '--network=none', '--entrypoint=python', '--mount=type=bind,source=' + source + ',target=/source,readonly', d.r['parent'], '-c', code])
    (d.OUTPUT / 'native-debug.log').write_text(output, encoding='utf-8')
    print(output[-6000:])


def packaging_fix():
    frozen = d.WORK / 'frozen'
    for suffix in ['.gd', '.gd.uid']:
        source = ROOT / ('game/vehicle/tyre_contacts' + suffix)
        if suffix.endswith('.uid') and not source.exists():
            continue
        for folder in [frozen / 'canonical/game', d.CONTEXT / 'canonical/game']:
            shutil.copyfile(source, folder / source.relative_to(ROOT / 'game'))
    shutil.copyfile(ROOT / 'backend/deploy/stage_verifier.py', frozen / 'backend/deploy/stage_verifier.py')
    d.r['packaging_correction'] = 'Include existing canonical tyre_contacts dependency; game source unchanged.'
    d.r['frozen_files'] = previous.hashes(frozen)
    d.r['source_hash'] = d.digest(json.dumps(d.r['frozen_files'], sort_keys=True).encode())
    d.r['build_files'] = previous.hashes(d.CONTEXT)
    d.save()
    (d.OUTPUT / 'frozen-source.json').write_text(json.dumps({'source_hash': d.r['source_hash'], 'files': d.r['frozen_files'], 'packaging_correction': d.r['packaging_correction']}, indent=2) + '\n')
    print(json.dumps({'packaging_correction': True, 'source_hash': d.r['source_hash']}))


def test_image(discovery_postgres=False, recheck=False):
    b = d.builder()
    docker = b.c['docker']
    suffix = secrets.token_hex(4)
    network, pg = 'bmt-release57-test-' + suffix, 'bmt-release57-pg-' + suffix
    password = secrets.token_urlsafe(24)
    label = 'bmt.release57-owner=' + d.config['owner']
    b.runner.run([*docker, 'network', 'create', '--internal', '--label=' + label, network])
    created = False
    try:
        database = 'bmt_discovery_lab' if discovery_postgres else 'release57'
        b.runner.run([*docker, 'run', '-d', '--rm', '--name=' + pg, '--network=' + network, '--label=' + label,
                      '-e', 'POSTGRES_USER=release57', '-e', 'POSTGRES_DB=' + database, '-e', 'POSTGRES_PASSWORD=' + password, 'postgres:17'])
        created = True
        for _ in range(40):
            try:
                ready = b.runner.run([*docker, 'exec', pg, 'pg_isready', '-U', 'release57'], allow_missing=True)
            except RuntimeError:
                ready = ''
            if ready and 'accepting connections' in ready:
                break
            time.sleep(.3)
        else:
            raise RuntimeError('Owned isolated PostgreSQL did not start')
        frozen = d.WORK / 'frozen'
        gate = d.WORK / 'gate-tests'
        if not gate.exists():
            shutil.copytree(frozen / 'backend/tests', gate, ignore=shutil.ignore_patterns('__pycache__', '.pytest_cache'))
            # Historical tests keep their original rules22 fixture; packaged acceptance uses rules23.
            shutil.copyfile(ROOT / 'backend/tests/fixtures/verified_oval.json', gate / 'fixtures/verified_oval.json')
        linux = lambda path: '/mnt/' + path.drive[0].lower() + path.as_posix()[2:]
        files = ['test_discovery_v3.py', 'test_discovery_projection.py', 'test_discovery_resources.py', 'test_discovery_hardening.py',
                 'test_queue_capacity_slots.py', 'test_telemetry_parallel.py', 'test_telemetry_counter.py', 'test_priority_scaling.py',
                 'test_bounded_leaderboard_ranks.py', 'test_bounded_retention.py', 'test_compact_histograms.py', 'test_histogram_followup.py',
                 'test_rivalry_generation_progress.py', 'test_worker_lifecycle.py', 'test_publication_background_priority.py',
                 'test_attack_resistance.py', 'test_http_boundary.py', 'test_end_to_end.py', 'test_earned_coins.py', 'test_achievements.py',
                 'test_privacy.py', 'test_privacy_postgres.py', 'test_community_safety.py', 'test_lightweight_verifier.py', 'test_verifier.py']
        files = [name for name in files if (gate / name).exists()]
        if discovery_postgres:
            files = ['test_discovery_v3.py', 'test_discovery_projection.py', 'test_discovery_resources.py', 'test_discovery_hardening.py']
        elif recheck:
            files = ['test_verifier.py', 'test_bounded_leaderboard_ranks.py']
            for name in files:
                shutil.copyfile(ROOT / 'backend/tests' / name, gate / name)
        else:
            d.r['final_test_files'] = files
        d.save()
        endpoint = 'postgresql+psycopg://release57:' + password + '@127.0.0.1:5432/' + database
        command = [*docker, 'run', '--rm', '--network=container:' + pg, '--label=' + label, '--entrypoint=python',
                   '--mount=type=bind,source=' + linux(frozen) + ',target=/test-work,readonly',
                   '--mount=type=bind,source=' + linux(gate) + ',target=/test-work/backend/tests,readonly',
                   '--mount=type=bind,source=' + linux(gate / 'fixtures') + ',target=/app/tests/fixtures,readonly',
                   '-e', 'PYTHONPATH=/app:/test-work:/test-work/backend/tests',
                   '-e', 'BMT_TEST_DATABASE_URL=' + endpoint,
                   *(['-e', 'BMT_DISCOVERY_TEST_DATABASE_URL=' + endpoint] if discovery_postgres else []),
                   d.r['local_tag'], '-m', 'pytest', *['/test-work/backend/tests/' + name for name in files], '-q', '--tb=short',
                   '--show-capture=no', '--durations=12', '-c', '/app/pyproject.toml', '-o', 'cache_dir=/tmp/release57-pytest']
        if discovery_postgres:
            command += ['-k', 'postgres']
        elif recheck:
            command += ['-k', '(test_retained_over_and_under_rejection_verifies_exactly or test_visible_windows_limit_keys_before_joining_hidden_pbs) and not sqlite']
        log_name = 'fixture-rechecks' if recheck else 'discovery-postgres' if discovery_postgres else 'exact-image-tests'
        try:
            output = b.runner.run(command)
        except RuntimeError:
            output = (d.WORK / 'last-error.private.log').read_text(encoding='utf-8')
            (d.OUTPUT / (log_name + '-initial.log')).write_text(output.replace(password, '[REDACTED]'), encoding='utf-8')
            raise
        (d.OUTPUT / (log_name + '.log')).write_text(output.replace(password, '[REDACTED]') + '\n', encoding='utf-8')
        d.r['fixture_rechecks' if recheck else 'discovery_postgres_tests' if discovery_postgres else 'exact_image_tests'] = True
        d.save()
        print(output[-3500:])
    finally:
        if created:
            labels = json.loads(b.runner.run([*docker, 'inspect', pg, '--format={{json .Config.Labels}}']))
            assert labels.get('bmt.release57-owner') == d.config['owner']
            b.runner.run([*docker, 'stop', pg])
        labels = json.loads(b.runner.run([*docker, 'network', 'inspect', network, '--format={{json .Labels}}']))
        assert labels.get('bmt.release57-owner') == d.config['owner']
        b.runner.run([*docker, 'network', 'rm', network])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['inspect', 'extract', 'freeze', 'check-freeze', 'prepare', 'build', 'progress', 'native-debug', 'packaging-fix', 'test', 'test-discovery-postgres', 'recheck'])
    args = parser.parse_args()
    {'inspect': inspect_live, 'extract': d.extract_parent, 'freeze': freeze, 'check-freeze': check_freeze, 'prepare': prepare,
     'build': build, 'progress': d.progress, 'native-debug': native_debug, 'packaging-fix': packaging_fix,
     'test': test_image, 'test-discovery-postgres': lambda: test_image(True), 'recheck': lambda: test_image(recheck=True)}[args.stage]()


if __name__ == '__main__':
    main()
