"""Deploy the exact tested complete image to the existing PC project, retaining data."""
import argparse
import hashlib
import importlib.util
import json
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/full-backend-deploy-2026-10-18'
OUTPUT = ROOT / 'docs/evidence/full-backend-deploy-2026-10-18'
RECEIPT = OUTPUT / 'pc-rollout.json'
r = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}
docker = ['wsl.exe', '-d', 'Ubuntu', '--cd', '/mnt/c/Codes/Godot/Beat my track', '--', 'docker']


def save(): RECEIPT.write_text(json.dumps(r, indent=2) + '\n')


def run(args, **kw):
    result = subprocess.run([*docker, *args], capture_output=True, **kw)
    if result.returncode:
        (WORK / 'pc-last-error.private.log').write_bytes(result.stdout + result.stderr)
        raise RuntimeError('PC command failed; see private PC error log')
    return result.stdout


def inspect(name): return json.loads(run(['inspect', name]))[0]


def program(code, image=None, *, objects=False, readonly=False):
    api = json.loads((WORK / 'bmt-pc-dev-api-1-before.private.json').read_text())
    env = [v for v in api['Config']['Env'] if v.startswith('BMT_')]
    args = ['run', '--rm', '-i', '--network=bmt-pc-dev_default', '--label=bmt.full-pc-release=20261018', '--entrypoint=python']
    for v in env: args += ['-e', v]
    if objects:
        args += ['--mount=type=volume,source=bmt-pc-dev_objects,target=/var/lib/bmt/objects' + (',readonly' if readonly else '')]
    return run([*args, image or r['image'], '-'], input=code.encode('utf-8'))


def prepare():
    cloud = json.loads((OUTPUT / 'rollout.json').read_text())
    r.update(image=cloud['local_tag'], image_id=cloud['candidate_id'], expected_manifest=cloud['expected_manifest'])
    for name in ['api', 'worker', 'db']:
        actual = inspect('bmt-pc-dev-' + name + '-1')
        assert actual['Config']['Labels']['com.docker.compose.project'] == 'bmt-pc-dev'
        before = json.loads((WORK / ('bmt-pc-dev-' + name + '-1-before.private.json')).read_text())
        assert actual['Id'] == before['Id']
    # The source bind is pinned to the tested snapshot, while named volumes and credentials stay intact.
    source = '/mnt/' + WORK.drive[0].lower() + WORK.as_posix()[2:] + '/frozen/backend/bmt_backend'
    override = {'services': {}}
    for name in ['api', 'worker', 'migrate']:
        override['services'][name] = {'image': r['image'], 'volumes': [source + ':/app/bmt_backend:ro']}
    override['services']['api']['healthcheck'] = {
        'test': ['CMD', 'python', '-c', "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/ready',timeout=5).close()"],
        'interval': '5s', 'timeout': '8s', 'retries': 24}
    (WORK / 'pc.override.json').write_text(json.dumps(override, indent=2) + '\n')
    r['prepared'] = True
    save()
    print(json.dumps({'pc_candidate': r['image_id'], 'frozen_source': True, 'existing_volumes_retained': True}))


def compose(*args):
    return run(['compose', '--env-file', '.tools/bmt-pc.env', '-f', 'backend/deploy/compose.pc.yaml',
                '-f', 'build/full-backend-deploy-2026-10-18/pc.override.json', *args])


def backup():
    assert r['prepared'] and not r.get('promoted')
    compose('stop', 'api', 'worker')
    r['writers_paused'] = True
    save()
    destination = WORK / 'pc-backup'
    destination.mkdir(exist_ok=False)
    commands = {
        'database.dump': ['exec', 'bmt-pc-dev-db-1', 'pg_dump', '-U', 'bmt', '-d', 'bmt', '--format=custom', '--no-owner', '--no-privileges'],
    }
    hashes = {}
    for name, args in commands.items():
        with (destination / name).open('xb') as output:
            result = subprocess.run([*docker, *args], stdout=output, stderr=subprocess.PIPE)
        assert result.returncode == 0, result.stderr.decode(errors='replace')
        hashes[name] = hashlib.sha256((destination / name).read_bytes()).hexdigest()
    # The tested image has the bounded immutable-object archive utility.
    code = "from pathlib import Path;from importlib.util import spec_from_file_location,module_from_spec;s=spec_from_file_location('archive','/app/deploy/object_archive.py');m=module_from_spec(s);s.loader.exec_module(m);m.archive(Path('/var/lib/bmt/objects'))"
    payload = program(code, objects=True, readonly=True)
    (destination / 'objects.tar').write_bytes(payload)
    hashes['objects.tar'] = hashlib.sha256(payload).hexdigest()
    (destination / 'SHA256SUMS').write_text(''.join(v + '  ' + k + '\n' for k, v in hashes.items()))
    (destination / 'COMPLETE').write_text('Complete quiesced PC database and object backup\n')
    r['backup'] = hashes
    save()
    print(json.dumps({'pc_backup_complete': True, 'files': list(hashes)}))


def snapshot(name):
    before = r.get('data_before')
    # Preserve every row of every original semantic table. Only worker/runtime leases are volatile.
    code = '''import hashlib,json
from sqlalchemy import inspect,text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url);before=__BEFORE__
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'));i=inspect(c);tables={}
 names=list(before['tables']) if before else sorted(set(i.get_table_names())-{'alembic_version','worker_heartbeats','worker_leases','rate_budgets','request_budgets','readiness_observations'})
 for name in names:
  primary=i.get_pk_constraint(name)['constrained_columns']
  if not primary:continue
  columns=before['tables'][name]['columns'] if before else [x['name'] for x in i.get_columns(name)]
  condition=' WHERE created_at<='+str(before['tables'][name]['max_created_at']) if before and name=='track_versions' else ''
  if before and name=='histogram_snapshots':condition=' WHERE version_id IN (SELECT id FROM track_versions WHERE created_at<='+str(before['tables']['track_versions']['max_created_at'])+')'
  rows=c.execute(text('SELECT '+','.join('"'+v+'"' for v in columns)+' FROM "'+name+'"'+condition+' ORDER BY '+','.join('"'+v+'"' for v in primary)))
  h=hashlib.sha256();count=0
  for row in rows:h.update(json.dumps(list(row),sort_keys=True,separators=(',',':'),default=str).encode()+b'\\n');count+=1
  tables[name]={'columns':columns,'rows':count,'sha256':h.hexdigest()}
  if name=='track_versions':tables[name]['max_created_at']=before['tables'][name]['max_created_at'] if before else c.execute(text('SELECT COALESCE(MAX(created_at),0) FROM track_versions')).scalar()
 result={'tables':tables,'schema':c.execute(text('SELECT version_num FROM alembic_version')).scalar()}
 if before:assert result['tables']==before['tables'],[n for n in tables if tables[n]!=before['tables'][n]]
 print(json.dumps(result))
e.dispose()
'''.replace('__BEFORE__', repr(before))
    result = json.loads(program(code))
    (OUTPUT / ('pc-' + name + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    if before is None: r['data_before'] = result
    else: r['data_preserved'] = True
    save()
    print(json.dumps({'pc_snapshot': name, 'tables': len(result['tables']), 'original_rows_exact': before is not None, 'schema': result['schema']}))


def migrate():
    assert r.get('backup') and r.get('data_before')
    compose('run', '--rm', '--no-deps', '-T', 'migrate')
    snapshot('data-after-migration')
    r['migrated'] = True
    save()


def catalog(apply=False):
    assert r.get('migrated')
    spec = importlib.util.spec_from_file_location('full_release', ROOT / '.tools/full_backend_deploy_20261018.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    code = module.catalog_program(apply)
    code = code.replace('from bmt_backend.gcs_storage import GCSBlobStore', 'from bmt_backend.storage import LocalBlobStore').replace('store=GCSBlobStore(s)', 'store=LocalBlobStore(s.object_dir)')
    result = json.loads(program(code, objects=True, readonly=True).decode().split('LATEST_RESULT=', 1)[1])
    (OUTPUT / ('pc-catalog-' + ('apply' if apply else 'preview') + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    if apply:
        r['catalog_applied'] = True
        save()
        snapshot('data-after-catalog')
        r['catalog_preserved'] = True
        save()
    print(json.dumps(result))


def promote():
    assert r.get('catalog_applied') and r.get('catalog_preserved') and r.get('data_preserved')
    compose('up', '-d', '--no-build', '--no-deps', '--wait', '--wait-timeout', '180', 'api', 'worker')
    r['promoted'] = True
    r['writers_paused'] = False
    save()
    print(json.dumps({'pc_promoted': True, 'same_tested_image': r['image_id']}))


def verify():
    assert r.get('promoted')
    with urllib.request.urlopen('http://127.0.0.1:18181/v1/manifest', timeout=20) as response:
        assert json.load(response) == r['expected_manifest']
    api = json.loads((WORK / 'bmt-pc-dev-api-1-before.private.json').read_text())
    env = dict(v.split('=', 1) for v in api['Config']['Env'])
    headers = {'Authorization': 'Bearer ' + env['BMT_ADMIN_OWNER_KEY']}
    for _ in range(30):
        req = urllib.request.Request('http://127.0.0.1:18181/v1/admin/competition-health', headers=headers)
        with urllib.request.urlopen(req, timeout=20) as response: health = json.load(response)
        if health['status'] == 'ready' and health['available_workers'] >= 1: break
        time.sleep(2)
    assert health['status'] == 'ready', health['status']
    assert health['expected_build'] == {k: v for k, v in r['expected_manifest'].items() if k != 'max_frames'}
    for name in ['api', 'worker']:
        actual = inspect('bmt-pc-dev-' + name + '-1')
        assert actual['Image'] == r['image_id']
        assert actual['Config']['Labels']['com.docker.compose.project'] == 'bmt-pc-dev'
        mount = next(m for m in actual['Mounts'] if m['Destination'] == '/var/lib/bmt/objects')
        assert mount['Name'] == 'bmt-pc-dev_objects'
    def get(path):
        req=urllib.request.Request('http://127.0.0.1:18181'+path,headers=headers)
        with urllib.request.urlopen(req,timeout=20) as response:return json.load(response)
    people=get('/v1/admin/catalogue/players?limit=1')['items']
    support=get('/v1/admin/players/'+people[0]['id']+'/support')
    assert len([p for p in support['grants']['products'] if p['group']=='Customisation kits'])==39
    assert '/v1/admin/players/{player_id}/grants/commands' in get('/openapi.json')['paths']
    for asset in (WORK/'frozen/backend/bmt_backend/admin_ui').iterdir():
        if not asset.is_file():continue
        path='/admin' if asset.name=='index.html' else '/admin/assets/'+asset.name
        with urllib.request.urlopen('http://127.0.0.1:18181'+path,timeout=20) as response:
            assert response.read()==asset.read_bytes(),asset.name
    result = {'ready': True, 'available_workers': health['available_workers'], 'expected_build': health['expected_build'],
              'image_id': r['image_id'], 'data_retained': True, 'player_grants_available':True, 'ui_assets_exact':True}
    (OUTPUT / 'pc-verify-live.json').write_text(json.dumps(result, indent=2) + '\n')
    r['writers_paused'] = False
    r['completed'] = True
    save()
    print(json.dumps(result))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('stage', choices=['prepare', 'backup', 'snapshot', 'migrate', 'preview', 'catalog', 'promote', 'verify'])
    a = p.parse_args()
    {'prepare': prepare, 'backup': backup, 'snapshot': lambda: snapshot('data-before'), 'migrate': migrate,
     'preview': catalog, 'catalog': lambda: catalog(True), 'promote': promote, 'verify': verify}[a.stage]()
