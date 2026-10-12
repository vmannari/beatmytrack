"""Owner-authorized, frozen nine-file Studio overlay; no migration or data writes."""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / '.tools/gcp-staging'
CONTEXT = ROOT / 'build/backend-studio-deploy-2026-10-11/image'
OUTPUT = ROOT / 'docs/evidence/backend-studio-deploy-2026-10-11'
OUTPUT.mkdir(parents=True, exist_ok=True)
CONTEXT.parent.mkdir(parents=True, exist_ok=True)
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(PRIVATE / 'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE'] = str(PRIVATE / 'windows-trust.pem')
spec = importlib.util.spec_from_file_location('studio_stage', ROOT / 'backend/deploy/gcp/staging.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)
config = json.loads((PRIVATE / 'config.json').read_text())
assert config['project'] == 'beat-my-track' and config['retain_data'] is True
DIRECTORY = PRIVATE / ('rendered-' + config['owner'])


class PrivateRunner(stage.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        result = subprocess.run(argv, input=input_data, capture_output=True, text=True,
                                cwd=cwd, timeout=1800, check=False)
        if result.returncode:
            if allow_missing and any(s in result.stderr.lower() for s in ('not_found', 'not found', 'does not exist', '404')):
                return None
            (CONTEXT.parent / 'last-error.private.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            raise RuntimeError('Cloud/container operation failed; private diagnostic retained')
        return result.stdout.strip()


service = stage.Staging(config, DIRECTORY, PrivateRunner())
RECEIPT = OUTPUT / 'rollout.json'
receipt = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}
COPIED = ['admin.py', 'studio.py', 'admin_ui/app.js', 'admin_ui/index.html',
          'admin_ui/style.css', 'admin_ui/studio.js', 'admin_ui/support.js', 'admin_ui/commerce.js']


def save():
    RECEIPT.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')


def task_targets():
    return [('api', service.n['api']), ('worker', service.n['worker']),
            ('job', service.n['migrate']), ('job', service.n['smoke']),
            ('job', 'bmt-stg-' + config['owner'][:8] + '-catalog')]


def container(resource):
    node = resource
    for _ in range(10):
        if 'containers' in node:
            assert len(node['containers']) == 1
            return node['containers'][0]
        node = node.get('template') or node.get('spec')
    raise RuntimeError('Container missing')


def env(resource):
    return {v['name']: v for v in container(resource).get('env', [])}


def staff_key(resource, role='OWNER'):
    binding = env(resource)['BMT_ADMIN_' + role + '_KEY']
    if 'value' in binding:
        return binding['value']
    source = binding['valueFrom']['secretKeyRef']
    return service.call('secrets', 'versions', 'access', source['key'], '--secret=' + source['name']).strip()


def read_staff(resource):
    # Preserve live access configuration: staging currently has an owner key only.
    if 'BMT_ADMIN_ANALYST_KEY' in env(resource):
        return 'analyst', staff_key(resource, 'ANALYST')
    return 'owner', staff_key(resource)


def fetch(origin, path, key=None):
    headers = {'Authorization': 'Bearer ' + key} if key else {}
    response = requests.get(origin + path, headers=headers, timeout=(5, 45), allow_redirects=False)
    if response.status_code != 200:
        raise RuntimeError('Read-only HTTP check failed: ' + path.split('?')[0] + ' status ' + str(response.status_code))
    return response


def normalized_template(resource):
    node = copy.deepcopy(resource['spec']['template'])
    container(node)['image'] = 'NORMALIZED_IMAGE'
    # Generated revision identifiers/CLI metadata are not runtime configuration.
    for item in (node, node.get('spec', {})):
        meta = item.get('metadata', {})
        meta.pop('name', None)
        meta.get('labels', {}).pop('client.knative.dev/nonce', None)
        for key in ('run.googleapis.com/client-name', 'run.googleapis.com/client-version', 'run.googleapis.com/operation-id'):
            meta.get('annotations', {}).pop(key, None)
    return node


def guard_target(kind, name, allowed):
    current = service.describe(kind, name)
    assert current and stage.resource_image(current) in allowed, 'Unexpected live image/owner for ' + name
    before = json.loads((CONTEXT.parent / ('before-' + name + '.private.json')).read_text())
    assert normalized_template(before) == normalized_template(current), 'Runtime configuration changed for ' + name
    original_labels = dict(before.get('metadata', {}).get('labels', {}))
    current_labels = dict(current.get('metadata', {}).get('labels', {}))
    for values in (original_labels, current_labels):
        values.pop('run.googleapis.com/lastUpdatedTime', None)
    assert original_labels == current_labels, 'Resource labels changed'
    return current


def builder():
    settings = copy.deepcopy(config)
    if '--cd' in settings['docker']:
        settings['docker'][settings['docker'].index('--cd') + 1] = '/mnt/' + CONTEXT.drive[0].lower() + CONTEXT.as_posix()[2:]
    return stage.Staging(settings, DIRECTORY, PrivateRunner())


def files_hash(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file()}


def verify_http(origin):
    resource = service.describe('api', service.n['api'])
    key = staff_key(resource)
    staff_role, analyst = read_staff(resource)
    ready = fetch(origin, '/ready').json()
    assert ready['status'] == 'ready'
    overview = fetch(origin, '/v1/admin/overview', key).json()
    assert overview['schema'] == receipt['schema']
    capabilities = fetch(origin, '/v1/admin/studio/capabilities', analyst).json()
    assert capabilities['schema'] == 'bmt-studio-capabilities-v1'
    items = []
    for offset in range(0, overview['players'], 100):
        value = fetch(origin, '/v1/admin/entities/players?limit=100&offset=' + str(offset), analyst).json()
        assert value['total'] == overview['players']
        items.extend(value['items'])
    assert len(items) == overview['players'] and len({p['id'] for p in items}) == len(items)
    assert all(type(p.get('is_test_driver')) is bool for p in items)
    classes = {'real': sum(not p['is_test_driver'] for p in items),
               'artificial': sum(p['is_test_driver'] for p in items)}
    assert sum(classes.values()) == overview['players']
    for artificial in (False, True):
        examples = [p for p in items if p['is_test_driver'] is artificial]
        if examples:
            support = fetch(origin, '/v1/admin/players/' + examples[0]['id'] + '/support', analyst).json()
            assert support['player']['is_test_driver'] is artificial
    assets = {}
    for name in COPIED:
        if not name.startswith('admin_ui/'):
            continue
        filename = name.split('/')[-1]
        path = '/admin' if filename == 'index.html' else '/admin/assets/' + filename
        raw = fetch(origin, path).content
        expected = (CONTEXT / 'source' / name).read_bytes()
        assert raw == expected, 'Deployed asset mismatch ' + filename
        assets[filename] = hashlib.sha256(raw).hexdigest()
    runs = fetch(origin, '/v1/admin/entities/races?state=verified&limit=1', analyst).json()['items']
    race_check = None
    if runs:
        response = fetch(origin, '/v1/admin/studio/races/' + runs[0]['id'] + '?download=true', analyst)
        value = response.json()
        assert value['schema'] == 'bmt-studio-race-evidence-v1'
        assert type(value['player']['is_test_driver']) is bool
        assert value['timing']['accepted'] and value['run']['status'] == 'verified'
        assert value['contract']['version_id']
        assert response.headers['cache-control'] == 'no-store' and 'attachment' in response.headers['content-disposition']
        from bmt_backend.track_models import digest
        checksum = value.pop('checksum')
        assert checksum == digest(value)
        race_check = {'loaded': True, 'checksum': True, 'accepted_pinned_timing': True,
                      'player_flag': True, 'redacted_attachment': True}
    return {'observed_at': datetime.now(timezone.utc).isoformat(), 'origin': origin,
            'read_only': True, 'staff_role': staff_role, 'schema': overview['schema'], 'players_including_all': len(items),
            'classes': classes, 'assets': assets, 'capabilities': True, 'race_evidence': race_check,
            'ready': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['inspect', 'prepare', 'build', 'backup', 'canary',
                        'verify-canary', 'promote', 'resources', 'smoke', 'verify-live', 'rollback', 'finish'])
    action = parser.parse_args().action
    if action == 'inspect':
        old = json.loads((DIRECTORY / 'deployment.json').read_text())
        resources = task_targets() + [('sql', service.n['sql']), ('bucket', service.n['bucket']), ('repo', service.n['repo'])]
        with ThreadPoolExecutor(max_workers=4) as pool:
            values = list(pool.map(lambda item: (item, service.describe(*item)), resources))
        found = {}
        for (kind, name), value in values:
            if value is None and name.endswith('-catalog'):
                continue
            assert value
            (CONTEXT.parent / ('before-' + name + '.private.json')).write_text(json.dumps(value), encoding='utf-8')
            if kind in ('api', 'worker', 'job'):
                assert stage.resource_image(value) == old['image'], 'Retained parent differs from live resource'
                found[name] = kind
            if kind == 'sql':
                assert value['settings']['deletionProtectionEnabled']
            if kind == 'api':
                assert env(value)['BMT_ENVIRONMENT']['value'] == 'development'
                assert env(value)['BMT_DEV_AUTH_ENABLED']['value'] == 'true'
                api_resource = value
        origin = api_resource['status']['url']
        assert origin == old['url']
        key = staff_key(api_resource)
        overview = fetch(origin, '/v1/admin/overview', key).json()
        receipt.update(parent=old['image'], url=origin, owner=config['owner'], targets=found,
                       schema=overview['schema'], initial_players=overview['players'],
                       started_utc=datetime.now(timezone.utc).isoformat(),
                       old_traffic=api_resource['status']['traffic'])
        save()
        print(json.dumps({'live_parent': receipt['parent'], 'targets': list(found),
                          'schema': receipt['schema'], 'players': receipt['initial_players'], 'owner_verified': True}))
    elif action == 'prepare':
        assert receipt.get('parent') and not CONTEXT.exists()
        CONTEXT.mkdir()
        for name in COPIED:
            source = ROOT / 'backend/bmt_backend' / name
            target = CONTEXT / 'source' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        baseline = ROOT / 'build/backend-studio-2026-10-11/before/admin.py'
        assert baseline.exists()
        (CONTEXT / 'baseline.json').write_text(json.dumps({'admin.py': hashlib.sha256(
            baseline.read_bytes().replace(b'\r\n', b'\n')).hexdigest()}))
        patch = r'''import hashlib,json,shutil
from pathlib import Path
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts and '.godot' not in p.parts}
backend=Path('/app/bmt_backend');game=Path('/opt/bmt');source=Path('/tmp/studio-source')
original_game=hashes(game);original_backend=hashes(backend)
for name,expected in json.loads(Path('/tmp/studio-baseline.json').read_text()).items():
 assert hashlib.sha256((backend/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==expected,('Unexpected live source',name)
for p in source.rglob('*'):
 if p.is_file():
  target=backend/p.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
p=backend/'app.py';s=p.read_text();assert 'studio.router' not in s
needle='    from .verifier import GodotVerifier\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    from . import studio\n')
needle='    app.include_router(admin_support.router)\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    app.include_router(studio.router)\n');p.write_text(s)
for name in ('admin.py','studio.py','app.py'):compile((backend/name).read_text(),name,'exec')
import sys;sys.path.insert(0,'/app')
import bmt_backend.app,bmt_backend.studio
from bmt_backend.migrate import SCHEMA_HEAD
final_backend=hashes(backend);changed=sorted(k for k in final_backend if original_backend.get(k)!=final_backend[k])
expected=sorted(['app.py']+[str(p.relative_to(source)) for p in source.rglob('*') if p.is_file()])
assert changed==expected,(changed,expected)
assert original_game==hashes(game)
assert all(v==final_backend[k] for k,v in original_backend.items() if k not in changed)
Path('/app/studio-overlay-proof.json').write_text(json.dumps({'changed_files':changed,'canonical_unchanged':True,'canonical_files':len(original_game),'game_hashes':original_game,'schema':SCHEMA_HEAD,'backend_unchanged_files':len(original_backend)-len([k for k in changed if k in original_backend])}))
print('STUDIO_NINE_FILE_OVERLAY_VALID')
'''
        (CONTEXT / 'patch.py').write_text(patch, encoding='utf-8')
        (CONTEXT / 'Dockerfile').write_text('FROM ' + receipt['parent'] + '\nUSER root\nCOPY source /tmp/studio-source\nCOPY baseline.json /tmp/studio-baseline.json\nCOPY patch.py /tmp/studio-patch.py\nRUN python /tmp/studio-patch.py\nUSER 10001:10001\n')
        receipt['frozen_files'] = files_hash(CONTEXT)
        receipt['source_hash'] = hashlib.sha256(json.dumps(receipt['frozen_files'], sort_keys=True).encode()).hexdigest()
        save()
        print(json.dumps({'prepared': True, 'copied_files': len(COPIED), 'surgical_app_registration': True, 'migration': False}))
    elif action == 'build':
        assert receipt['frozen_files'] == files_hash(CONTEXT)
        registry = config['region'] + '-docker.pkg.dev'
        tag = registry + '/' + config['project'] + '/' + service.n['repo'] + '/backend:studio-' + receipt['source_hash'][:24]
        build = builder()
        auth = CONTEXT / 'docker-private'
        auth.mkdir(exist_ok=False)
        try:
            token = service.call('auth', 'print-access-token')
            build.runner.run([*build.c['docker'], '--config=docker-private', 'login', registry,
                              '--username=oauth2accesstoken', '--password-stdin'], input_data=token, cwd=CONTEXT)
            result = build.runner.run([*build.c['docker'], '--config=docker-private', 'build',
                                     '--platform=linux/amd64', '--file=Dockerfile', '--tag=' + tag, '.'], cwd=CONTEXT)
            (CONTEXT.parent / 'build.private.log').write_text(result, encoding='utf-8')
            proof = json.loads(build.runner.run([*build.c['docker'], 'run', '--rm', '--entrypoint=cat',
                                                tag, '/app/studio-overlay-proof.json'], cwd=CONTEXT))
            assert proof['canonical_unchanged'] and proof['schema'] == receipt['schema'] and len(proof['changed_files']) == 9
            (OUTPUT / 'packaged-proof.json').write_text(json.dumps(proof, indent=2) + '\n')
            build.runner.run([*build.c['docker'], '--config=docker-private', 'push', tag], cwd=CONTEXT)
            images = json.loads(build.runner.run([*build.c['docker'], 'image', 'inspect', tag,
                                                  '--format={{json .RepoDigests}}'], cwd=CONTEXT))
            receipt['image'] = next(v for v in images if v.startswith(registry + '/'))
            receipt['local_tag'] = tag
            save()
        finally:
            assert auth.resolve().parent == CONTEXT.resolve() and CONTEXT.resolve().is_relative_to(ROOT.resolve())
            assert not auth.is_symlink() and all(not p.is_symlink() for p in auth.rglob('*'))
            shutil.rmtree(auth)
        print(json.dumps({'image': receipt['image'], 'changed_files': 9, 'canonical_unchanged': True, 'schema': receipt['schema']}))
    elif action == 'backup':
        assert receipt.get('image') and receipt.get('exact_image_tests')
        for name, kind in receipt['targets'].items():
            guard_target(kind, name, [receipt['parent']])
        description = 'Before Studio update ' + datetime.now(timezone.utc).isoformat()
        service.call('sql', 'backups', 'create', '--instance=' + service.n['sql'], '--description=' + description, '--format=json')
        values = json.loads(service.call('sql', 'backups', 'list', '--instance=' + service.n['sql'], '--format=json'))
        value = next(v for v in values if v.get('description') == description and v.get('status') == 'SUCCESSFUL')
        receipt['backup_id'] = value['id']; save()
        print(json.dumps({'successful_backup': value['id']}))
    elif action == 'canary':
        assert receipt.get('backup_id') and receipt.get('image')
        tag = 'studio-' + receipt['source_hash'][:10]
        existing = guard_target('api', service.n['api'], [receipt['parent'], receipt['image']])
        if stage.resource_image(existing) == receipt['parent']:
            service.call('run', 'services', 'update', service.n['api'], '--region=' + config['region'],
                         '--image=' + receipt['image'], '--no-traffic', '--tag=' + tag, '--format=json')
        else:
            assert any(v.get('tag') == tag for v in existing['status']['traffic']), 'Unknown partial canary'
        current = guard_target('api', service.n['api'], [receipt['image']])
        routes = current['status']['traffic']
        old = {(v['revisionName'], v.get('percent', 0)) for v in receipt['old_traffic'] if v.get('percent', 0)}
        new = {(v['revisionName'], v.get('percent', 0)) for v in routes if v.get('percent', 0)}
        assert old == new
        route = next(v for v in routes if v.get('tag') == tag)
        assert route.get('percent', 0) == 0
        receipt.update(canary_revision=route['revisionName'], canary_url=route['url'], canary_tag=tag)
        save(); print(json.dumps({'canary': receipt['canary_revision'], 'normal_traffic_unchanged': True}))
    elif action in ('verify-canary', 'verify-live'):
        origin = receipt['canary_url'] if action == 'verify-canary' else receipt['url']
        result = verify_http(origin)
        (OUTPUT / (action + '.json')).write_text(json.dumps(result, indent=2) + '\n')
        receipt[action.replace('-', '_')] = True; save()
        print(json.dumps({k: v for k, v in result.items() if k != 'assets'}))
    elif action == 'promote':
        assert receipt.get('verify_canary')
        guard_target('api', service.n['api'], [receipt['image']])
        service.call('run', 'services', 'update-traffic', service.n['api'], '--region=' + config['region'],
                     '--to-revisions=' + receipt['canary_revision'] + '=100', '--format=json')
        current = guard_target('api', service.n['api'], [receipt['image']])
        assert any(v.get('revisionName') == receipt['canary_revision'] and v.get('percent') == 100 for v in current['status']['traffic'])
        receipt['promoted'] = True; save(); print('Studio API revision promoted to 100%')
    elif action == 'resources':
        assert receipt.get('promoted')
        for name, kind in receipt['targets'].items():
            if kind == 'api':
                continue
            existing = guard_target(kind, name, [receipt['parent'], receipt['image']])
            group = 'worker-pools' if kind == 'worker' else 'jobs'
            if stage.resource_image(existing) == receipt['parent']:
                service.call('run', group, 'update', name, '--region=' + config['region'], '--image=' + receipt['image'], '--format=json')
            guard_target(kind, name, [receipt['image']])
            if name not in receipt.setdefault('resources_updated', []):
                receipt['resources_updated'].append(name)
            save()
            print('Preserved configuration; updated image: ' + name, flush=True)
        old = json.loads((DIRECTORY / 'deployment.json').read_text())
        assert old['image'] == receipt['parent']
        stage.write_json(DIRECTORY / ('deployment-before-studio-' + str(receipt['backup_id']) + '.json'), old)
        stage.write_json(DIRECTORY / 'deployment.json', {**old, 'image': receipt['image']})
        population = DIRECTORY / 'test-population.json'
        if population.exists():
            value = json.loads(population.read_text()); stage.write_json(population, {**value, 'image': receipt['image']})
        receipt['deployed'] = True; save()
    elif action == 'smoke':
        assert receipt.get('deployed')
        for name, kind in receipt['targets'].items():
            guard_target(kind, name, [receipt['image']])
        service.call('run', 'jobs', 'execute', service.n['smoke'], '--region=' + config['region'], '--wait')
        receipt['native_storage_schema_smoke'] = True; save()
        health = fetch(receipt['url'], '/v1/admin/competition-health', staff_key(service.describe('api', service.n['api']))).json()
        assert health['status'] == 'ready' and health['available_workers'] >= 1
        receipt['worker_status'] = health['status']; save()
        print(json.dumps({'native_storage_schema_smoke': True, 'worker_status': health['status'],
                          'available_workers': health['available_workers']}))
    elif action == 'rollback':
        assert receipt.get('parent') and receipt.get('old_traffic')
        api = service.describe('api', service.n['api'])
        assert stage.resource_image(api) in (receipt['parent'], receipt.get('image'))
        traffic = ','.join(v['revisionName'] + '=' + str(v['percent'])
                           for v in receipt['old_traffic'] if v.get('percent', 0))
        service.call('run', 'services', 'update-traffic', service.n['api'], '--region=' + config['region'],
                     '--to-revisions=' + traffic, '--format=json')
        service.call('run', 'services', 'update', service.n['api'], '--region=' + config['region'],
                     '--image=' + receipt['parent'], '--no-traffic', '--format=json')
        for name, kind in receipt['targets'].items():
            if kind == 'api':
                continue
            resource = service.describe(kind, name)
            if stage.resource_image(resource) == receipt.get('image'):
                group = 'worker-pools' if kind == 'worker' else 'jobs'
                service.call('run', group, 'update', name, '--region=' + config['region'],
                             '--image=' + receipt['parent'], '--format=json')
        if receipt.get('canary_tag'):
            service.call('run', 'services', 'update-traffic', service.n['api'], '--region=' + config['region'],
                         '--remove-tags=' + receipt['canary_tag'], '--format=json')
        old = json.loads((DIRECTORY / 'deployment.json').read_text())
        if old['image'] == receipt.get('image'):
            stage.write_json(DIRECTORY / 'deployment.json', {**old, 'image': receipt['parent']})
        receipt['rolled_back'] = True; receipt['deployed'] = False; save()
        print('Original API traffic and parent image restored; no database rollback was needed')
    elif action == 'finish':
        assert receipt.get('verify_live') and receipt.get('native_storage_schema_smoke')
        service.call('run', 'services', 'update-traffic', service.n['api'], '--region=' + config['region'],
                     '--remove-tags=' + receipt['canary_tag'], '--format=json')
        for name, kind in receipt['targets'].items():
            guard_target(kind, name, [receipt['image']])
        current = service.describe('api', service.n['api'])
        assert any(v.get('revisionName') == receipt['canary_revision'] and v.get('percent') == 100 for v in current['status']['traffic'])
        assert not any(v.get('tag') == receipt['canary_tag'] for v in current['status']['traffic'])
        receipt['completed'] = True; receipt['temporary_canary_tag_removed'] = True
        receipt['completed_utc'] = datetime.now(timezone.utc).isoformat(); save()
        print(json.dumps({'completed': True, 'revision': receipt['canary_revision'], 'url': receipt['url']}))


if __name__ == '__main__':
    import sys
    sys.path.insert(0, str(ROOT / 'backend'))
    main()
