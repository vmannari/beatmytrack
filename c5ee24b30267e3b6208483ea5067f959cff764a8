"""Authorized matching backend/client release; private cloud output stays local."""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import secrets
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT / 'docs/evidence/backend-compat-deploy-2026-11-07'
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('release_util', ROOT / 'build/full-backend-deploy-2026-10-26/deploy.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.WORK, d.OUT, d.STATE = WORK, OUT, WORK / 'state.private.json'
d.state = json.loads(d.STATE.read_text()) if d.STATE.exists() else {}
d.HEAD = '0075_receipt_reference_indexes'


class PrivateRunner(d.staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        assert cwd is None
        if 'print-access-token' in argv or 'print-identity-token' in argv:
            value = subprocess.run(argv, input=input_data, capture_output=True, text=True, timeout=60, check=False)
            assert value.returncode == 0, 'Credential refresh failed; no token was logged'
            return value.stdout.strip()
        return d.command(argv, 'cloud-command', input_data=input_data, allow_missing=allow_missing)


d.service = d.staging.Staging(d.config, WORK, PrivateRunner())
s, service = d.state, d.service
REGION = '--region=' + d.config['region']
DOCKER = ['wsl.exe', '-d', 'Ubuntu', '--', 'docker']
LABEL = 'bmt.compat-release=20261107'
FROZEN = WORK / 'frozen'


def inspect():
    assert not s.get('rollout_started')
    service.preflight()
    docker_version = d.command(DOCKER + ['version', '--format', '{{.Server.Version}}'], 'docker-version', timeout=60)
    jobs = json.loads(service.call('run', 'jobs', 'list', REGION, '--format=json'))
    targets = [('api', service.n['api']), ('api', service.n['admin']), ('worker', service.n['worker'])]
    targets += [('job', row['metadata']['name']) for row in jobs
                if row['metadata'].get('labels', {}).get('bmt-owner') == d.config['owner']]
    s['targets'], s['parents'] = {}, {}
    for kind, name in targets:
        resource = service.describe(kind, name)
        d.write(WORK / ('before-' + name + '.private.json'), resource)
        s['targets'][name], s['parents'][name] = kind, d.staging.resource_image(resource)
    api = service.describe('api', service.n['api'])
    s['original_traffic'] = api['status']['traffic']
    s['url'] = api['status']['url']
    serving = next(row for row in s['original_traffic'] if row.get('percent') == 100)
    preview = next(row for row in s['original_traffic'] if row.get('tag') == 'website-preview')
    for role, revision in [('main', serving['revisionName']), ('preview', preview['revisionName'])]:
        resource = json.loads(service.call('run', 'revisions', 'describe', revision, REGION, '--format=json'))
        s[role + '_parent'] = resource['spec']['containers'][0]['image']
    s['studio_parent'] = s['parents'][service.n['admin']]
    s['schema_before'] = d.http(s['url'], '/ready').json()['schema']
    s['manifest_before'] = d.http(s['url'], '/v1/manifest').json()
    sql = service.describe('sql', service.n['sql'])
    assert sql['settings']['deletionProtectionEnabled']
    d.write(WORK / 'sql-before.private.json', sql)
    s['inspected'] = True
    d.save()
    summary = {'targets': s['targets'], 'parents': s['parents'], 'preview_parent': s['preview_parent'],
               'schema_before': s['schema_before'], 'schema_target': d.HEAD, 'docker_version': docker_version,
               'manifest_before': s['manifest_before']}
    d.write(OUT / 'inspection.json', summary)
    print(json.dumps(summary), flush=True)


def freeze():
    assert not FROZEN.exists(), 'Use the existing frozen release after preparation'
    listing = subprocess.run(['git', '-C', str(ROOT), '-c', 'core.quotepath=false', 'ls-files', '-z',
                              '--cached', '--others', '--exclude-standard', '--',
                              'game', 'native', 'scripts', 'backend', 'godot-version.txt', '.gitignore'],
                             capture_output=True, check=True).stdout.decode().split('\0')
    files = {}
    for relative in sorted(set(listing) - {''}):
        source = ROOT / relative
        parts = Path(relative).parts
        if (not source.is_file() or any(part in {'.godot', '__pycache__', '.pytest_cache', '.ruff_cache',
                                                'vendor', 'node_modules'} for part in parts)
                or relative.startswith('game/android/build/') or '.private.' in source.name
                or source.name.startswith('.env')):
            continue
        target = FROZEN / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        files[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
    assert all(hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest for name, digest in files.items()), 'Source changed while freezing'
    stage_spec = importlib.util.spec_from_file_location('release_stage_verifier', FROZEN / 'backend/deploy/stage_verifier.py')
    stage = importlib.util.module_from_spec(stage_spec)
    stage_spec.loader.exec_module(stage)
    stage.stage(FROZEN, FROZEN / 'canonical/game')
    s['source_hashes'] = files
    s['source_hash'] = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    s['frozen_hashes'] = d.hashes(FROZEN)
    d.save()
    d.write(OUT / 'frozen-sources.json', {'source_hash': s['source_hash'], 'files': files, 'schema': d.HEAD})
    # The APK build uses an owned index so its normal source enumerator retains
    # tracked libraries even when matching .gitignore patterns.
    d.command(['git', '-c', 'safe.directory=' + FROZEN.as_posix(), '-C', str(FROZEN), 'init'], 'frozen-git-init')
    pathspec = WORK / 'frozen-paths.private.nul'
    pathspec.write_bytes(b'\0'.join(name.encode() for name in files) + b'\0')
    d.command(['git', '-c', 'safe.directory=' + FROZEN.as_posix(), '-C', str(FROZEN), 'add', '--force',
               '--pathspec-from-file=' + str(pathspec), '--pathspec-file-nul'], 'frozen-git-index')
    print(json.dumps({'frozen_files': len(files), 'source_hash': s['source_hash']}), flush=True)


def device():
    adb = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
    listing = d.command([str(adb), 'devices', '-l'], 'device-list', timeout=40)
    connected = [line.split()[0] for line in listing.splitlines()[1:] if '\tdevice' in line or ' device ' in line]
    result = {'connected_devices': connected, 'target': None}
    for serial in connected:
        model = d.command([str(adb), '-s', serial, 'shell', 'getprop', 'ro.product.model'], 'device-model', timeout=30)
        if model == 'OPD2403':
            assert result['target'] is None, 'More than one matching tablet'
            result['target'] = {'serial': serial, 'model': model}
            text = d.command([str(adb), '-s', serial, 'shell', 'dumpsys', 'package', 'org.circuit01.handlinglab'],
                             'device-package', timeout=30)
            import re
            result['target']['version'] = re.search(r'versionName=(\S+)', text).group(1)
    d.write(OUT / 'device-before.json', result)
    s['device'] = result['target']
    d.save()
    print(json.dumps(result), flush=True)


def build():
    assert s.get('inspected') and s.get('source_hash')
    for relative, digest in s['frozen_hashes'].items():
        if relative.startswith(('backend/', 'canonical/', 'canonical-v2/')):
            assert hashlib.sha256((FROZEN / relative).read_bytes()).hexdigest() == digest, relative
    installer = '''import hashlib,json,shutil
from pathlib import Path
package=Path('/app/bmt_backend');game=Path('/opt/bmt/game')
assert package==Path('/app/bmt_backend') and game==Path('/opt/bmt/game')
ui={'admin_ui','public_ui','privacy_ui'}
kept={p.relative_to(package).as_posix():p.read_bytes() for p in package.rglob('*') if p.is_file() and
      (p.relative_to(package).parts[0] in ui or p.name=='public_website.py')}
shutil.rmtree(package);shutil.copytree('/tmp/release-backend',package)
for name in ui:
 if (package/name).exists():shutil.rmtree(package/name)
for name,value in kept.items():
 target=package/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value)
shutil.rmtree(game);shutil.copytree('/tmp/release-canonical',game)
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0075_receipt_reference_indexes'
a=create_app(Settings(environment='test',database_url='sqlite://'));upgrade(a.state.engine)
a.state.engine.dispose();a.state.verifier.close()
proof={'schema':SCHEMA_HEAD,'source_hashes':{p.relative_to(package).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
       for p in package.rglob('*') if p.is_file() and '__pycache__' not in p.parts},
       'preserved_frontend':{name:hashlib.sha256(value).hexdigest() for name,value in kept.items()}}
Path('/app/compat-release-proof.json').write_text(json.dumps(proof))
'''
    acceptance = '''import json,subprocess,re
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier
p=Path('/opt/bmt/game');v=GodotVerifier(Settings.from_env())
original_close=v.close
def diagnostic_close():
 if v._directory is not None:
  log=Path(v._directory.name)/'engine.log'
  if log.exists():print('NATIVE_DIAGNOSTIC='+log.read_text(errors='replace'),flush=True)
 original_close()
v.close=diagnostic_close
assert subprocess.check_output([v.binary,'--headless','--version'],text=True).strip()==Path('/opt/bmt/godot-version.txt').read_text().strip()
result=subprocess.run([v.binary,'--headless','--path',str(p),'--editor','--import'],capture_output=True,text=True,timeout=180)
assert result.returncode==0 and not re.search(r'SCRIPT ERROR:|(^|\\s)ERROR:|Parse Error:',result.stdout+result.stderr),result.stdout+result.stderr
recorded=json.loads(Path('/opt/bmt/acceptance/load_trajectory.json').read_text())
try:
 checked=v.verify_run(recorded['document'],recorded['replay'],'compact')
except Exception:
 if v._directory is not None:print((Path(v._directory.name)/'engine.log').read_text(errors='replace'))
 raise
assert checked['time_ticks']==recorded['time_ticks']==12757 and len(checked['lap_ticks'])==5
assert checked['manifest']==recorded['expected_manifest']
old=json.loads(Path('/opt/bmt/acceptance/verified_oval.json').read_text())
diagnostic=v.verify_canonical_diagnostic(old['document'],old['replay'],'compact')
assert diagnostic['time_ticks']==12757 and diagnostic['lap_ticks']==[2634,2532,2531,2530,2530]
Path('/app/compat-native-proof.json').write_text(json.dumps({'manifest':v.manifest(),'trajectory_ticks':checked['time_ticks'],
 'diagnostic_ticks':diagnostic['time_ticks'],'import':True}))
v.close()
'''
    (WORK / 'install.py').write_text(installer, encoding='utf-8', newline='\n')
    (WORK / 'accept.py').write_text(acceptance, encoding='utf-8', newline='\n')
    for role in ('main', 'studio', 'preview'):
        if s.get('local_' + role):
            continue
        parent = s[role + '_parent']
        holder = 'bmt-compat-20261107-parent-' + role
        d.command(DOCKER + ['create', '--name', holder, '--label', LABEL, parent], 'parent-create-' + role)
        try:
            lock = WORK / ('requirements-' + role + '.lock')
            d.command(DOCKER + ['cp', holder + ':/app/requirements.lock', d.unix(lock)], 'parent-lock-' + role)
        finally:
            d.command(DOCKER + ['rm', holder], 'parent-remove-' + role)
        assert lock.read_bytes().replace(b'\r\n', b'\n') == (FROZEN / 'backend/requirements.lock').read_bytes().replace(b'\r\n', b'\n'), 'Dependencies changed'
        dockerfile = f'''FROM {parent}
USER root
ENV PYTHONPATH=/app
COPY frozen/backend/bmt_backend /tmp/release-backend
COPY frozen/{s.get('canonical_folder', 'canonical/game')} /tmp/release-canonical
COPY frozen/godot-version.txt /opt/bmt/godot-version.txt
COPY frozen/backend/tests/fixtures/verified_oval.json /opt/bmt/acceptance/verified_oval.json
COPY frozen/backend/tests/fixtures/load_trajectory.json /opt/bmt/acceptance/load_trajectory.json
COPY frozen/backend/deploy/object_archive.py /app/deploy/object_archive.py
COPY install.py /tmp/release-install.py
COPY accept.py /tmp/release-accept.py
RUN chmod -R u+w /opt/bmt && python /tmp/release-install.py && python /tmp/release-accept.py && chmod -R a-w /opt/bmt && chown -R 10001:10001 /tmp/bmt
USER 10001:10001
'''
        path = WORK / ('Dockerfile.' + role)
        path.write_text(dockerfile, encoding='utf-8', newline='\n')
        tag = 'bmt-compat-20261107-' + role + ':' + s['source_hash'][:16]
        d.command(DOCKER + ['build', '--network=none', '--pull=false', '--file', d.unix(path),
                           '--tag', tag, d.unix(WORK)], 'build-' + role, timeout=1200)
        proof = json.loads(d.command(DOCKER + ['run', '--rm', '--network=none', '--entrypoint', 'cat', tag,
                                             '/app/compat-release-proof.json'], 'package-proof-' + role))
        expected = d.hashes(FROZEN / 'backend/bmt_backend')
        def frontend(name):
            return name.split('/')[0] in {'admin_ui', 'public_ui', 'privacy_ui'} or name == 'public_website.py'
        actual = {name: value for name, value in proof['source_hashes'].items() if not frontend(name)}
        expected = {name: value for name, value in expected.items() if not frontend(name)}
        assert actual == expected, 'Candidate package differs from frozen source'
        assert {name: value for name, value in proof['source_hashes'].items() if frontend(name)} == proof['preserved_frontend']
        native = json.loads(d.command(DOCKER + ['run', '--rm', '--network=none', '--entrypoint', 'cat', tag,
                                               '/app/compat-native-proof.json'], 'native-proof-' + role))
        if 'manifest' in s:
            assert native['manifest'] == s['manifest']
        s['manifest'], s['local_' + role] = native['manifest'], tag
        d.save()
        d.write(OUT / ('package-proof-' + role + '.json'), proof)
        d.write(OUT / ('native-proof-' + role + '.json'), native)
        print(json.dumps({'built': role, 'schema': proof['schema'], 'native_trajectory': native['trajectory_ticks'],
                          'package_files': len(proof['source_hashes'])}), flush=True)


def prepare_export():
    source = ROOT / 'build/garage-entry-restore-20261106/run_export.py'
    text = source.read_text(encoding='utf-8')
    text = text.replace("ROOT = Path(__file__).resolve().parent / 'isolated'", "ROOT = Path(__file__).resolve().parent / 'frozen'")
    (WORK / 'export.py').write_text(text, encoding='utf-8')
    template = ROOT / '.tools/admob/android_source.zip'
    target = FROZEN / '.tools/admob/android_source.zip'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(template, target)
    print('Isolated pinned ARM64 exporter prepared', flush=True)


def pull():
    auth = WORK / 'registry-auth.private'
    auth.mkdir(exist_ok=True)
    assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
    registry = d.config['region'] + '-docker.pkg.dev'
    token = service.call('auth', 'print-access-token')
    d.command(DOCKER + ['--config', d.unix(auth), 'login', registry, '--username=oauth2accesstoken',
                       '--password-stdin'], 'registry-login', input_data=token)
    for role in ('main', 'studio', 'preview'):
        d.command(DOCKER + ['--config', d.unix(auth), 'pull', s[role + '_parent']], 'pull-' + role, timeout=600)
        print('Pulled exact ' + role + ' parent', flush=True)


def test_db():
    network, pg = 'bmt-compat-20261107', 'bmt-compat-20261107-pg'
    s['test_network'], s['test_pg'] = network, pg
    pg_env, test_env = WORK / 'pg.private.env', WORK / 'test.private.env'
    if not pg_env.exists():
        password = secrets.token_hex(24)
        pg_env.write_text('POSTGRES_PASSWORD=' + password + '\nPOSTGRES_DB=bmt_daily_standings\n')
        url = 'postgresql+psycopg://postgres:' + password + '@' + pg + '/bmt_daily_standings'
        test_env.write_text('BMT_TEST_DATABASE_URL=' + url + '\nBMT_GCP_SETUP_TEST_DATABASE_URL=' + url +
                           '\nBMT_DAILY_STANDINGS_POSTGRES=1\nBMT_DAILY_STANDINGS_DATABASE_URL=' + url +
                           '\nPYTHONPATH=/app:/test-work/backend/tests\n')
        d.command(DOCKER + ['network', 'create', '--internal', '--label', LABEL, network], 'test-network')
        d.command(DOCKER + ['run', '-d', '--rm', '--name', pg, '--network', network, '--label', LABEL,
                           '--pull=never', '--env-file', d.unix(pg_env), '--tmpfs', '/var/lib/postgresql/data:rw',
                           'postgres:17-bookworm', '-c', 'max_connections=80'], 'test-postgres')
    else:
        meta = json.loads(d.command(DOCKER + ['inspect', pg], 'test-inspect'))[0]
        assert meta['Config']['Labels'].get('bmt.compat-release') == '20261107' and meta['State']['Running']
    for _ in range(40):
        result = subprocess.run(DOCKER + ['exec', pg, 'pg_isready', '-U', 'postgres'], capture_output=True, check=False)
        if result.returncode == 0:
            break
        time.sleep(.25)
    else:
        raise RuntimeError('Owned PostgreSQL fixture unavailable')
    common = DOCKER + ['run', '--rm', '--network', network, '--label', LABEL, '--env-file', d.unix(test_env),
                       '--mount', 'type=bind,src=' + d.unix(FROZEN / 'backend/bmt_backend') + ',dst=/app/bmt_backend,readonly',
                       '--mount', 'type=bind,src=' + d.unix(WORK / 'pg_rehearsal.py') + ',dst=/test.py,readonly',
                       '--entrypoint', 'python', s.get('local_main', s['main_parent']), '/test.py']
    output = d.command(common, 'pg-rehearsal', timeout=300)
    result = json.loads(next(row for row in output.splitlines() if row.startswith('RELEASE_RESULT=')).split('=', 1)[1])
    assert result['all_four_indexes_used'] and result['invalid_concurrent_index_recovered']
    s['postgresql_rehearsed'] = True
    d.save()
    d.write(OUT / 'postgresql-rehearsal.json', result)
    print(json.dumps({key: value for key, value in result.items() if key != 'plan'}), flush=True)


def amend_stage():
    assert not s.get('local_main') and not s.get('rollout_started')
    amended = ['backend/deploy/stage_verifier.py', 'backend/tests/test_verifier_stage.py']
    for name in amended:
        shutil.copyfile(ROOT / name, FROZEN / name)
        value = hashlib.sha256((FROZEN / name).read_bytes()).hexdigest()
        s['source_hashes'][name], s['frozen_hashes'][name] = value, value
    stage_spec = importlib.util.spec_from_file_location('fixed_stage', FROZEN / 'backend/deploy/stage_verifier.py')
    stage = importlib.util.module_from_spec(stage_spec)
    stage_spec.loader.exec_module(stage)
    s['canonical_folder'] = 'canonical-v2/game'
    stage.stage(FROZEN, FROZEN / s['canonical_folder'])
    for name, value in d.hashes(FROZEN / 'canonical-v2').items():
        s['frozen_hashes']['canonical-v2/' + name] = value
    s['source_hash_before_staging_fix'] = s['source_hash']
    s['source_hash'] = hashlib.sha256(json.dumps(s['source_hashes'], sort_keys=True).encode()).hexdigest()
    d.save()
    d.write(OUT / 'staging-amendment.json', {'files': amended, 'source_hash': s['source_hash'],
                                           'before': s['source_hash_before_staging_fix'],
                                           'reason': 'TrackSession statically preloads the numeric layout cache'})
    print('Staged the missing exact layout-cache dependency; native error checks remain enabled', flush=True)


def test_images():
    assert s.get('postgresql_rehearsed') and all(s.get('local_' + role) for role in ('main', 'studio', 'preview'))
    results = WORK / 'test-results.private'
    results.mkdir(exist_ok=True)
    test_env = WORK / 'test-loopback.private.env'
    test_env.write_text((WORK / 'test.private.env').read_text().replace('bmt-compat-20261107-pg/', '127.0.0.1/'))
    password = next(line.split('=', 1)[1] for line in (WORK / 'pg.private.env').read_text().splitlines()
                    if line.startswith('POSTGRES_PASSWORD='))
    mounts = [(FROZEN / 'backend/tests', '/test-work/backend/tests'),
              (FROZEN / 'backend/deploy', '/test-work/backend/deploy'),
              (FROZEN / 'backend/pyproject.toml', '/test-work/backend/pyproject.toml'),
              (FROZEN / 'backend/tests/fixtures', '/app/tests/fixtures'),
              (FROZEN / 'game', '/test-work/game'), (FROZEN / 'scripts', '/test-work/scripts'),
              (FROZEN / 'godot-version.txt', '/test-work/godot-version.txt')]
    common = DOCKER + ['run', '--rm', '--network', 'container:bmt-compat-20261107-pg', '--label', LABEL,
                       '--env-file', d.unix(test_env)]
    for source, target in mounts:
        common += ['--mount', 'type=bind,src=' + d.unix(source) + ',dst=' + target + ',readonly']
    common += ['--mount', 'type=bind,src=' + d.unix(results) + ',dst=/results',
               '--workdir', '/test-work/backend/tests', '--entrypoint', 'python']
    suites = ['test_performance_cost_fixes.py', 'test_profile_statistics.py', 'test_maintenance.py',
              'test_cost_maintenance.py', 'test_worker_lifecycle.py', 'test_run_confirmation.py',
              'test_publication_background_priority.py', 'test_appearance_sync.py',
              'test_publication_worker_privileges.py', 'test_runtime_privileges.py',
              'test_daily_snapshot_preparation.py', 'test_daily_build_variant.py',
              'test_daily_lap_standings.py', 'test_client_quality.py', 'test_shader_profiles.py',
              'test_verifier_stage.py']
    for role in ('main', 'studio', 'preview'):
        if s.get('tests_' + role):
            continue
        try:
            output = d.command(common + [s['local_' + role], '-m', 'pytest', *suites, '-q', '--tb=short',
                       '--show-capture=no', '-p', 'no:cacheprovider', '--junitxml=/results/tests-' + role + '.xml'],
                       'tests-' + role, timeout=1200)
        finally:
            xml = results / ('tests-' + role + '.xml')
            if xml.exists():
                (OUT / xml.name).write_text(xml.read_text().replace(password, '[REDACTED]'), encoding='utf-8')
        (OUT / ('tests-' + role + '.log')).write_text(output.replace(password, '[REDACTED]'), encoding='utf-8')
        s['tests_' + role] = True
        d.save()
        print(role + ': ' + output.splitlines()[-1], flush=True)
    s['tests_passed'] = True
    d.save()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('step', choices=['inspect', 'freeze', 'device', 'build', 'prepare_export', 'pull', 'test_db', 'amend_stage', 'test_images'])
    args = parser.parse_args()
    globals()[args.step]()


if __name__ == '__main__':
    main()
