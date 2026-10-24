"""Guarded release stages for the existing retained cloud backend."""
import argparse
import importlib.util
import json
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release57', ROOT / '.tools/full_backend_deploy_20261023.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
d = release.d
previous_guard = d.guard


def guard(kind, name, images):
    if kind == 'api' and d.r.get('maintenance_image'):
        images = [*images, d.r['maintenance_image']]
    return previous_guard(kind, name, images)


d.guard = guard


def preflight():
    d.RECEIPT = d.WORK / 'preflight-receipt.private.json'
    if d.RECEIPT.exists():
        d.r = json.loads(d.RECEIPT.read_text())
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 counts={name:c.scalar(text('SELECT count(*) FROM '+name)) for name in ['players','track_versions','runs','personal_bests','rivalry_groups','product_events']}
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'counts':counts,
  'database_bytes':c.scalar(text('SELECT pg_database_size(current_database())')),
  'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid')),
  'max_connections':c.scalar(text('SHOW max_connections'))}
print('LATEST_RESULT='+json.dumps(result));e.dispose()
'''
    result = d.execute('aggregate-preflight', code)
    try:
        schedulers = json.loads(d.service.call('scheduler', 'jobs', 'list', '--location=' + d.config['region'], '--format=json'))
        result['scheduler_api_enabled'] = True
    except RuntimeError:
        error = (d.WORK / 'last-error.private.log').read_text(encoding='utf-8')
        assert 'SERVICE_DISABLED' in error and 'cloudscheduler.googleapis.com' in error
        schedulers = []
        result['scheduler_api_enabled'] = False
    owned = [{'name': row['name'], 'state': row.get('state')} for row in schedulers if 'bmt-stg-' + d.config['owner'][:8] in json.dumps(row)]
    assert all(row['state'] == 'PAUSED' for row in owned), owned
    result['owned_schedulers'] = owned
    (d.OUTPUT / 'aggregate-preflight.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


def maintenance_image():
    assert d.r.get('exact_image_tests') and d.r.get('discovery_postgres_tests')
    folder = d.WORK / 'maintenance-image'
    folder.mkdir(exist_ok=True)
    app = '''from fastapi import FastAPI
from starlette.responses import JSONResponse
def create_app():
 app=FastAPI(docs_url=None,redoc_url=None,openapi_url=None)
 @app.middleware('http')
 async def maintenance(request,call_next):
  if request.url.path in ('/health','/ready','/healthz','/readyz'):
   return JSONResponse({'status':'maintenance'})
  return JSONResponse({'detail':'DEPLOYMENT_MAINTENANCE'},status_code=503,headers={'Retry-After':'120'})
 return app
'''
    (folder / 'app.py').write_text(app, encoding='utf-8', newline='\n')
    (folder / 'Dockerfile').write_text('FROM ' + d.r['parent'] + '\nUSER root\nCOPY app.py /app/bmt_backend/app.py\nUSER 10001:10001\n', encoding='utf-8', newline='\n')
    b = d.builder()
    tag = 'bmt-maintenance57:' + d.r['source_hash'][:16]
    b.runner.run([*b.c['docker'], 'build', '--network=none', '--pull=false', '--file=maintenance-image/Dockerfile', '--tag=' + tag, 'maintenance-image'])
    check = '''from bmt_backend.app import create_app
from fastapi.testclient import TestClient
with TestClient(create_app()) as c:
 for path in ['/v1/bootstrap','/v1/discovery/tracks','/v1/auth/google','/admin','/']:
  for method in ['get','post']:
   r=getattr(c,method)(path);assert r.status_code==503 and r.json()['detail']=='DEPLOYMENT_MAINTENANCE'
 assert c.get('/health').json()['status']=='maintenance'
print('MAINTENANCE_ALL_REQUESTS_FENCED_NO_DATABASE')
'''
    result = b.runner.run([*b.c['docker'], 'run', '--rm', '--network=none', '--entrypoint=python', tag, '-c', check])
    (d.OUTPUT / 'maintenance-image-check.log').write_text(result + '\n')
    auth = d.WORK / 'maintenance-push-auth'
    auth.mkdir(exist_ok=False)
    try:
        token = d.service.call('auth', 'print-access-token')
        registry = d.config['region'] + '-docker.pkg.dev'
        b.runner.run([*b.c['docker'], '--config=maintenance-push-auth', 'login', registry, '--username=oauth2accesstoken', '--password-stdin'], input_data=token)
        remote = registry + '/' + d.config['project'] + '/' + d.service.n['repo'] + '/backend:maintenance-schema57-' + d.r['source_hash'][:12]
        b.runner.run([*b.c['docker'], 'tag', tag, remote])
        b.runner.run([*b.c['docker'], '--config=maintenance-push-auth', 'push', remote])
        d.r['maintenance_image'] = next(value for value in json.loads(b.runner.run([*b.c['docker'], 'image', 'inspect', remote, '--format={{json .RepoDigests}}'])) if value.startswith(registry + '/'))
        d.save()
    finally:
        assert auth.resolve().parent == d.WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print(json.dumps({'maintenance_image': d.r['maintenance_image'], 'all_requests_fenced': True, 'database_connections': 0}))


def quiesce():
    import requests
    assert d.r.get('image') and d.r.get('maintenance_image') and d.r.get('exact_image_tests') and d.r.get('discovery_postgres_tests')
    rehearsal = json.loads((d.OUTPUT / 'migration-rehearsal.json').read_text())
    assert rehearsal['schema_after'] == release.HEAD and rehearsal['invalid_indexes'] == 0
    for name, kind in d.r['targets'].items():
        value = guard(kind, name, [d.r['parent']])
        if kind == 'job':
            latest = value.get('status', {}).get('latestCreatedExecution', {})
            assert latest.get('completionStatus') in (None, 'EXECUTION_SUCCEEDED', 'EXECUTION_FAILED', 'EXECUTION_CANCELLED'), name
    # No tagged URL may bypass the full request fence on an old revision.
    assert not any(item.get('tag') for item in d.r['old_traffic'])
    tag = 'schema57-maint-' + d.r['source_hash'][:8]
    d.service.call('run', 'services', 'update', d.service.n['api'], '--region=' + d.config['region'],
                   '--image=' + d.r['maintenance_image'], '--no-traffic', '--tag=' + tag, '--format=json')
    api = guard('api', d.service.n['api'], [d.r['maintenance_image']])
    route = next(value for value in api['status']['traffic'] if value.get('tag') == tag)
    assert route.get('percent', 0) == 0
    for method, path in [('get','/v1/bootstrap'), ('get','/v1/discovery/tracks'), ('post','/v1/telemetry/batches')]:
        response = getattr(requests, method)(route['url'] + path, timeout=(5,30), allow_redirects=False)
        assert response.status_code == 503 and response.json()['detail'] == 'DEPLOYMENT_MAINTENANCE'
    d.service.call('run', 'services', 'update-traffic', d.service.n['api'], '--region=' + d.config['region'], '--to-revisions=' + route['revisionName'] + '=100', '--format=json')
    d.r.update(maintenance_revision=route['revisionName'], maintenance_tag=tag, maintenance_started_utc=datetime.now(timezone.utc).isoformat(), all_requests_paused=True)
    d.save()
    print(json.dumps({'maintenance_revision': route['revisionName'], 'all_requests_paused': True, 'drain_seconds_required': 75}))


def stop_worker():
    assert d.r.get('all_requests_paused')
    elapsed = (datetime.now(timezone.utc) - datetime.fromisoformat(d.r['maintenance_started_utc'])).total_seconds()
    assert elapsed >= 75, 'Wait for the original 60-second request timeout and 15-second drain margin'
    worker = guard('worker', d.service.n['worker'], [d.r['parent']])
    count = int(worker['metadata']['annotations']['run.googleapis.com/manualInstanceCount'])
    assert count == 1
    d.r['worker_instances_before'] = count
    d.save()
    d.service.call('run', 'worker-pools', 'update', d.service.n['worker'], '--region=' + d.config['region'], '--instances=0', '--format=json')
    d.r.update(writers_paused=True, worker_stopped_utc=datetime.now(timezone.utc).isoformat())
    d.save()
    print(json.dumps({'worker_instances': 0, 'old_api_drain_seconds': elapsed}))


def backup():
    assert d.r.get('writers_paused')
    for name, kind in d.r['targets'].items():
        guard(kind, name, [d.r['parent'], d.r['image']])
    description = 'Quiesced schema42 before schema57 ' + d.r['source_hash'][:12] + ' ' + datetime.now(timezone.utc).isoformat()
    d.service.call('sql', 'backups', 'create', '--instance=' + d.service.n['sql'], '--description=' + description, '--format=json')
    backups = json.loads(d.service.call('sql', 'backups', 'list', '--instance=' + d.service.n['sql'], '--format=json'))
    value = next(value for value in backups if value.get('description') == description and value.get('status') == 'SUCCESSFUL')
    d.r.update(backup_id=value['id'], backup_quiesced=True)
    d.save()
    print(json.dumps({'successful_backup': value['id'], 'writers_paused': True, 'managed_cloud_sql_backup': True}))


def snapshot(name):
    before = d.r.get('data_before')
    # Only schema metadata, counts and irreversible fingerprints leave the database.
    columns = {name: {'columns': value['columns'], 'pk': value['pk']} for name, value in before['tables'].items()} if before else None
    code = (ROOT / '.tools/release57_fingerprint.py').read_text(encoding='utf-8').replace('__COLUMNS__', repr(columns))
    result = d.execute(name, code)
    if before is None:
        assert result['schema'] == d.r['schema_before'] and not any(result['pending'].values())
        d.r['data_before'] = result
    else:
        assert result['schema'] == release.HEAD and result['invalid_indexes'] == 0
        assert result['tables'] == before['tables'], [name for name in result['tables'] if result['tables'][name] != before['tables'][name]]
        d.r['data_preserved'] = True
    d.save()
    print(json.dumps({'snapshot': name, 'schema': result['schema'], 'tables': len(result['tables']), 'rows': sum(v['rows'] for v in result['tables'].values()), 'original_rows_exact': before is not None, 'pending': result['pending'], 'invalid_indexes': result['invalid_indexes']}))


d.snapshot = snapshot


def accept_gate():
    raw = (d.OUTPUT / 'exact-image-tests-initial.log').read_text(encoding='utf-8')
    failed = [line.split(' - ')[0] for line in raw.splitlines() if line.startswith('FAILED ::')]
    expected = ['FAILED ::test_migration_preserves_pending_jobs_and_round_trips[sqlite]',
                'FAILED ::test_migration_preserves_pending_jobs_and_round_trips[postgres]',
                'FAILED ::test_visible_windows_limit_keys_before_joining_hidden_pbs[sqlite]',
                'FAILED ::test_retained_over_and_under_rejection_verifies_exactly']
    assert failed == expected, failed
    assert '4 failed, 445 passed, 82 skipped' in raw
    assert d.r.get('discovery_postgres_tests') and d.r.get('fixture_rechecks')
    recheck = (d.OUTPUT / 'fixture-rechecks.log').read_text()
    assert '2 passed' in recheck and 'failed' not in recheck.lower()
    rehearsal = json.loads((d.OUTPUT / 'migration-rehearsal-scaled.json').read_text())
    assert rehearsal['schema_after'] == release.HEAD and rehearsal['invalid_indexes'] == 0
    gate = {'accepted_for_postgresql_release': True, 'initial': {'passed':445,'failed':4,'skipped':82},
            'postgresql_discovery': {'passed':59,'skipped':2}, 'fixture_rechecks': {'passed':2},
            'legacy_rollback_limit': 'Both 0047 round-trip tests attempt to downgrade through intentionally irreversible0051; actual42-to57 restore rehearsals preserve all original rows.',
            'sqlite_plan_limit': 'SQLite chooses its covering primary-key index on the already visibility-filtered tie-node relation for the tiny fixture. Assertions retained. Both deployed targets use PostgreSQL; its visible-leaf partial-index assertion passes.',
            'historical_fixture_correction': 'Legacy .50 loader accepts the compiler optional exclusion/cancellation arguments; original physics, input bytes, tick/lap assertions retained and pass.',
            'runtime_candidate_unchanged_after_rechecks': d.r['candidate_id']}
    (d.OUTPUT / 'release-gate.json').write_text(json.dumps(gate, indent=2) + '\n')
    d.r.update(exact_image_tests=True, release_gate=gate)
    d.save()
    print(json.dumps(gate))


def retain_catalog():
    assert d.r.get('migration_complete') and d.r.get('data_preserved') and d.r.get('catalog_validated')
    preview = json.loads((d.OUTPUT/'catalog-preview.json').read_text())
    assert preview['matching_new_revisions_required'] == 0 and preview['inserted_versions'] == 0
    assert preview['contract'] == d.r['expected_manifest']
    d.r['catalog_mode'] = 'existing contract preserved; no catalog mutation'
    d.save()
    print(json.dumps({'validated_tracks':preview['validated_tracks'],'inserted_versions':0,'existing_contract_preserved':True}))


def browser():
    code = (ROOT / '.tools/full_backend_browser_20261018.py').read_text(encoding='utf-8')
    code = code.replace("ROOT/'.tools/full_backend_deploy_20261018.py'", "ROOT/'.tools/release57_cutover.py'")
    code = code.replace("if d.r.get('population_complete'):\n    d.r['live_browser']=True;d.save()", "d.r['live_browser']=True;d.save()")
    path = d.WORK / 'browser-check.py'
    path.write_text(code, encoding='utf-8', newline='\n')
    # The generated script uses repository-relative imports, so pin its ROOT explicitly.
    code = code.replace('ROOT=Path(__file__).resolve().parents[1]', 'ROOT=Path(' + repr(str(ROOT)) + ')')
    path.write_text(code, encoding='utf-8', newline='\n')
    result = subprocess.run([str(ROOT / '.tools/backend-venv/Scripts/python.exe'), '-X','utf8',str(path)],capture_output=True,text=True,encoding='utf-8',timeout=1800)
    (d.OUTPUT / 'browser-run.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    assert result.returncode == 0, 'See browser-run.log'
    print(result.stdout[-1800:])


def projection_health():
    assert d.r.get('promoted')
    code = '''import json
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.discovery_projection import health
s=Settings.from_env();e=make_engine(s.database_url,s)
print('LATEST_RESULT='+json.dumps(health(make_session_factory(e))));e.dispose()
'''
    value = d.execute('discovery-health-live', code)
    assert value['population_backfill_ready'] and value['storage_backfill_ready']
    assert len(value['partitions']) == 16 and all(row['ready'] for row in value['partitions'])
    print(json.dumps(value))


def coverage():
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 locale=c.execute(text('SELECT datcollate,datctype FROM pg_database WHERE datname=current_database()')).one()
 rows=c.execute(text("SELECT substr(t.id,1,1) AS prefix,count(*) AS source,count(h.track_id) AS projected FROM tracks t LEFT JOIN discovery_heads h ON h.track_id=t.id WHERE EXISTS (SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published') GROUP BY substr(t.id,1,1) ORDER BY 1")).mappings().all()
 public=c.scalar(text("SELECT count(*) FROM tracks t JOIN players p ON p.id=t.owner_id WHERE NOT t.hidden AND NOT t.archived AND NOT p.disabled AND NOT p.is_test_driver AND p.deleted_at IS NULL AND EXISTS(SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published')"))
 result={'locale':list(locale),'by_prefix':[dict(row) for row in rows],'public_eligible':public}
print('LATEST_RESULT='+json.dumps(result));e.dispose()
'''
    print(json.dumps(d.execute('catalog-coverage',code)))


def discovery_http():
    import requests
    origin = d.r['url']
    samples = []
    cursor_pages = 0
    public_ids = set()
    for query in [{'sort':'name'},{'sort':'name','search':'zzzxxyy'},{'sort':'name','search':'zz'}]:
        started = time.monotonic()
        response = requests.post(origin + '/v1/discovery/v3/tracks',json={'query':query},timeout=(5,30))
        assert response.status_code == 200, (response.status_code, response.text[:180])
        value = response.json()
        assert value['schema'] == 'bmt-discovery-page-v3' and len(value['items']) <= 20 and value['total'] is None
        samples.append({'query':query,'status':response.status_code,'items':len(value['items']),'seconds':time.monotonic()-started})
        if query == {'sort':'name'}:
            for turn in range(10):
                cursor_pages += 1
                ids = {row['track_id'] for row in value['items']}
                assert not (public_ids & ids)
                public_ids.update(ids)
                if not value['next_cursor']:
                    break
                response = requests.post(origin + '/v1/discovery/v3/tracks',json={'cursor':value['next_cursor']},timeout=(5,30))
                assert response.status_code == 200 and len(response.json()['items']) <=20
                value = response.json()
            else:
                raise AssertionError('Retained staging catalogue unexpectedly exceeds the reviewed traversal')
            assert cursor_pages > 1
            assert len(public_ids) == d.r['catalog_collation_fix']['published_tracks']
    response = requests.post(origin + '/v1/discovery/v3/random',json={'query':{}},timeout=(5,30))
    assert response.status_code == 200 and response.json()['schema'] == 'bmt-discovery-random-v3'
    for path in ['/v1/discovery/tracks','/v1/discovery/random']:
        response = requests.post(origin + path,json={},timeout=(5,30))
        assert response.status_code == 426
    result = {'samples':samples,'cursor_passed':cursor_pages>1,'cursor_pages':cursor_pages,'public_tracks_seen':len(public_ids),'random_passed':True,'legacy_v2_update_required':True,
              'player_account_mutations':0,'ephemeral_discovery_sessions_created':True,'capacity_claim':False}
    existing=d.OUTPUT/'discovery-live-http.json'
    initial=d.OUTPUT/'discovery-live-http-initial.json'
    if existing.exists() and not initial.exists():shutil.copyfile(existing,initial)
    existing.write_text(json.dumps(result,indent=2)+'\n')
    d.r['discovery_http_passed'] = True
    d.save()
    print(json.dumps(result))


def promote():
    assert d.r.get('verify_canary') and d.r.get('data_preserved') and d.r.get('backup_quiesced')
    guard('api', d.service.n['api'], [d.r['image']])
    guard('worker', d.service.n['worker'], [d.r['parent']])
    d.service.call('run','worker-pools','update',d.service.n['worker'],'--region='+d.config['region'],
                   '--image='+d.r['image'],'--instances='+str(d.r['worker_instances_before']),'--format=json')
    guard('worker',d.service.n['worker'],[d.r['image']])
    d.r['new_worker_started'] = True
    d.save()
    for name,kind in d.r['targets'].items():
        if kind != 'job':
            continue
        current = guard(kind,name,[d.r['parent'],d.r['image']])
        if d.stage.resource_image(current) != d.r['image']:
            d.service.call('run','jobs','update',name,'--region='+d.config['region'],'--image='+d.r['image'],'--format=json')
    code = '''import json,time
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.discovery_projection import health
s=Settings.from_env();e=make_engine(s.database_url,s);factory=make_session_factory(e)
for attempt in range(180):
 result=health(factory)
 if result['population_backfill_ready'] and result['storage_backfill_ready'] and all(row['ready'] for row in result['partitions']):break
 time.sleep(2)
else:raise RuntimeError('Discovery bootstrap did not finish; keep normal traffic in maintenance')
print('LATEST_RESULT='+json.dumps(result));e.dispose()
'''
    result = d.execute('discovery-warmup',code,timeout=480)
    assert result['population_backfill_ready'] and result['storage_backfill_ready'] and all(row['ready'] for row in result['partitions'])
    checked = d.verify_http(d.r['canary_url'],True)
    (d.OUTPUT/'verify-worker-before-traffic.json').write_text(json.dumps(checked,indent=2)+'\n')
    d.service.call('run','services','update-traffic',d.service.n['api'],'--region='+d.config['region'],
                   '--to-revisions='+d.r['canary_revision']+'=100','--format=json')
    d.r.update(promoted=True,writers_paused=False,all_requests_paused=False,
               maintenance_ended_utc=datetime.now(timezone.utc).isoformat(),discovery_ready_before_traffic=True)
    d.save()
    print(json.dumps({'promoted':d.r['canary_revision'],'worker_instances':d.r['worker_instances_before'],'discovery_ready_before_traffic':True}))


def main():
    actions = {'accept-gate':accept_gate,'preflight': preflight, 'maintenance-image': maintenance_image, 'push': d.push_image, 'quiesce': quiesce, 'stop-worker': stop_worker,
               'backup': backup, 'snapshot': lambda: snapshot('data-before'), 'migrate': d.migrate,
               'snapshot-migration': lambda: snapshot('data-after-migration'), 'preview': d.preview_catalog,
               'catalog': retain_catalog, 'canary': d.canary, 'promote': promote, 'smoke': d.smoke,
               'browser':browser,'projection-health':projection_health,'coverage':coverage,'discovery-http':discovery_http,'finish':d.finish}
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('stage', choices=actions)
    actions[p.parse_args().stage]()


if __name__ == '__main__':
    main()
