"""Guarded release phases for the explicitly authorized matching deployment."""
import argparse
import json
from datetime import datetime, timezone

import deploy as r

d, s, service = r.d, r.s, r.service
WORK, OUT, ROOT, REGION = r.WORK, r.OUT, r.ROOT, r.REGION
TAG = 'compat-20261107'


def push():
    # Registry publication is reversible preparation; live changes remain gated
    # on all three image suites in migrate().
    assert s.get('tests_main') and s.get('postgresql_rehearsed')
    assert all(s.get('local_' + role) for role in ('main', 'studio', 'preview'))
    lock = ROOT / '.tools/gcp-staging' / ('rendered-' + d.config['owner']) / 'update.lock'
    expected = {'task': TAG, 'source_hash': s['source_hash']}
    if lock.exists():
        assert json.loads(lock.read_text()) == expected, 'Another deployment owns the release lock'
    else:
        with lock.open('x') as stream:
            json.dump(expected, stream)
    for name in s['targets']:
        d.guarded(name)
    registry = d.config['region'] + '-docker.pkg.dev'
    auth = WORK / 'registry-auth.private'
    token = service.call('auth', 'print-access-token')
    d.command(r.DOCKER + ['--config', d.unix(auth), 'login', registry,
                        '--username=oauth2accesstoken', '--password-stdin'], 'push-login', input_data=token)
    for role in ('main', 'studio', 'preview'):
        if s.get('image_' + role):
            continue
        remote = registry + '/' + d.config['project'] + '/' + service.n['repo'] + '/backend:' + TAG + '-' + role + '-' + s['source_hash'][:12]
        d.command(r.DOCKER + ['tag', s['local_' + role], remote], 'tag-' + role)
        d.command(r.DOCKER + ['--config', d.unix(auth), 'push', remote], 'push-' + role, timeout=1800)
        values = json.loads(d.command(r.DOCKER + ['image', 'inspect', remote], 'inspect-pushed-' + role))[0]
        original = json.loads(d.command(r.DOCKER + ['image', 'inspect', s['local_' + role]], 'inspect-tested-' + role))[0]
        assert values['Id'] == original['Id']
        s['image_' + role] = next(item for item in values['RepoDigests'] if item.startswith(registry + '/'))
        d.save()
        print('Pushed exact tested ' + role + ' image', flush=True)


def backup():
    assert s.get('tests_main') and s.get('postgresql_rehearsed')
    d.preflight()
    assert not any(s['preflight']['pending'].values()), 'Allow existing verification work to drain before migration'
    snapshot(False)
    if not s.get('backup_id'):
        description = TAG + ' before schema75 ' + s['source_hash'][:12]
        service.call('sql', 'backups', 'create', '--instance=' + service.n['sql'], '--description=' + description, '--format=json')
        rows = json.loads(service.call('sql', 'backups', 'list', '--instance=' + service.n['sql'], '--format=json'))
        matches = [row for row in rows if row.get('description') == description and row['status'] == 'SUCCESSFUL']
        assert len(matches) == 1
        s['backup_id'] = matches[0]['id']
        d.save()
    d.write(OUT / 'managed-backup.json', {'id': s['backup_id'], 'status': 'SUCCESSFUL', 'player_records_exported': False})
    print('Managed database backup verified', flush=True)


def snapshot(after=True):
    cutoff = s.get('history_cutoff') or int(datetime.now(timezone.utc).timestamp())
    s['history_cutoff'] = cutoff
    d.save()
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
settings=Settings.from_env();engine=make_engine(settings.database_url,settings)
queries={
 'personal_bests':"SELECT board_id,player_id,run_id,time_ticks,achieved_at FROM personal_bests WHERE achieved_at<=:cutoff",
 'lap_personal_bests':"SELECT board_id,player_id,run_id,time_ticks,lap_index,achieved_at FROM lap_personal_bests WHERE achieved_at<=:cutoff",
 'rivalry_bests':"SELECT group_id,player_id,slot,run_id,time_ticks,achieved_at FROM rivalry_bests WHERE achieved_at<=:cutoff",
 'track_versions':"SELECT id,track_id,number,content_hash,manifest,state,created_at,published_at FROM track_versions WHERE created_at<=:cutoff"}
with engine.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 result={name:dict(c.execute(text("SELECT count(*) AS count,md5(coalesce(string_agg(to_jsonb(q)::text,'' ORDER BY to_jsonb(q)::text),'')) AS digest FROM ("+query+") q"),{'cutoff':CUTOFF}).mappings().one()) for name,query in queries.items()}
print('RELEASE_RESULT='+json.dumps(result));engine.dispose()
'''.replace('CUTOFF', str(cutoff))
    value = d.execute('history-' + ('after' if after else 'before'), code, job=service.n['migrate'])
    if after:
        assert value == s['history_before'], 'Historical scores or immutable versions changed; investigate'
        s['history_preserved'] = True
    else:
        s['history_before'] = value
    d.save()
    print('Historical results and immutable versions ' + ('unchanged' if after else 'fingerprinted'), flush=True)


def update(name, role='main', canary=False):
    kind = s['targets'][name]
    allowed = [s['parents'][name], s['image_' + role]]
    if name == service.n['api']:
        allowed += [s['image_main'], s['image_preview']]
    d.guarded(name, allowed)
    interface = {'api': 'services', 'worker': 'worker-pools', 'job': 'jobs'}[kind]
    args = ['run', interface, 'update', name, REGION, '--image=' + s['image_' + role], '--format=json']
    if canary:
        args += ['--no-traffic', '--tag=' + TAG + '-' + role]
    service.call(*args)
    if canary:
        resource = service.describe('api', name)
        route = next(row for row in resource['status']['traffic'] if row.get('tag') == TAG + '-' + role)
        assert route.get('percent', 0) == 0
        s['route_' + role] = route
        d.save()


def migrate():
    assert s.get('backup_id') and s.get('tests_passed')
    if not s.get('rollout_started'):
        s['rollout_started'] = datetime.now(timezone.utc).isoformat()
        d.save()
    update(service.n['migrate'])
    code = '''import json,os
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.cloud_setup import setup
settings=Settings.from_env();assert settings.workload_role=='migrator'
engine=make_engine(settings.database_url,settings)
with engine.connect() as c:
 assert c.scalar(text('SELECT version_num FROM alembic_version')) in ('0073_daily_snapshot_preparation','0074_shader_profile_receipts','0075_receipt_reference_indexes')
setup(engine,os.environ['BMT_STAGING_OWNER'])
with engine.connect() as c:
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid'))}
assert result['schema']=='0075_receipt_reference_indexes' and not result['invalid_indexes']
print('RELEASE_RESULT='+json.dumps(result));engine.dispose()
'''.replace("'0073_daily_snapshot_preparation'", repr(s['schema_before']))
    value = d.execute('live-migration', code, job=service.n['migrate'], timeout=1200)
    assert value['schema'] == d.HEAD
    s['migrated'] = True
    d.save()
    print('Schema75 and workload grants applied', flush=True)


def canaries():
    assert s.get('migrated')
    for role, name in [('main', service.n['api']), ('studio', service.n['admin']), ('preview', service.n['api'])]:
        if not s.get('route_' + role):
            update(name, role, canary=True)
        route = s['route_' + role]
        value = d.verify_admin(route['url']) if role == 'studio' else d.verify_api(route['url'])
        if role != 'studio':
            boot = value['/v1/bootstrap']
            assert boot.get('appearance_contract')
            assert d.http(route['url'], '/v1/manifest').json() == s['manifest']
        d.write(OUT / ('canary-' + role + '.json'), value)
        print('Verified ' + role + ' canary', flush=True)
    s['canaries_passed'] = True
    d.save()


def catalog():
    assert s.get('migrated')
    catalog_job = service.n['api'].removesuffix('-api') + '-catalog'
    assert s['targets'][catalog_job] == 'job'
    update(catalog_job)
    code = '''import json
from bmt_backend.app import create_app
from bmt_backend.catalog_builds import plan_refresh,apply_refresh,check_catalog
a=create_app()
with a.state.session_factory() as session:
 # Native validation can exceed the runtime role's idle transaction deadline.
 # Keep loaded immutable metadata, then release its read transaction before
 # storage/native work. apply_refresh still locks and rechecks every head.
 session.expire_on_commit=False
 class ReleaseRead:
  def get_json(self,key):
   assert not session.new and not session.dirty and not session.deleted
   session.commit()
   return a.state.blobs.get_json(key)
 plan=plan_refresh(session,ReleaseRead(),a.state.verifier)
 inserted=apply_refresh(session,plan)
 session.commit()
 result=check_catalog(session,a.state.verifier.manifest())
 result.update(new_immutable_versions=len(inserted),old_versions_and_scores_modified=False)
print('RELEASE_RESULT='+json.dumps(result))
a.state.verifier.close();a.state.engine.dispose()
'''
    value = d.execute('catalog-build-refresh-operator-v2', code, job=catalog_job, timeout=1200)
    s['catalog_passed'] = value
    d.save()
    print(json.dumps(value), flush=True)


def workers():
    assert s.get('canaries_passed') and s.get('catalog_passed')
    for name, kind in s['targets'].items():
        if kind in ('job', 'worker'):
            update(name)
            print('Updated ' + name, flush=True)
    # Existing readiness probe checks the actual worker heartbeat's native build.
    d.start_targets = None
    code = '''import json,time
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
from bmt_backend.discovery_projection import health
a=create_app()
for attempt in range(120):
 value=competition_health(a);projection=health(a.state.session_factory)
 if value['status']=='ready' and value['available_workers']>=1 and all(row['ready'] for row in projection['partitions']):break
 time.sleep(2)
else:raise RuntimeError('Matching worker and discovery projections are not ready')
print('RELEASE_RESULT='+json.dumps({'status':value['status'],'available_workers':value['available_workers'],'queue_depth':value['queue_depth'],'partitions_ready':sum(row['ready'] for row in projection['partitions']),'expected_build':value['expected_build']}))
a.state.verifier.close();a.state.engine.dispose()
'''
    value = d.execute('matching-worker', code, job=service.n['migrate'], timeout=420)
    s['worker_passed'] = value
    d.save()
    print('Matching worker and projections ready', flush=True)


def promote():
    assert s.get('worker_passed') and s.get('canaries_passed')
    for role, name in [('main', service.n['api']), ('studio', service.n['admin'])]:
        route = s['route_' + role]
        if role == 'studio':
            d.verify_admin(route['url'])
        else:
            d.verify_api(route['url'])
        service.call('run', 'services', 'update-traffic', name, REGION, '--to-revisions=' + route['revisionName'] + '=100', '--format=json')
    service.call('run', 'services', 'update-traffic', service.n['api'], REGION,
                 '--update-tags=website-preview=' + s['route_preview']['revisionName'], '--format=json')
    d.write(OUT / 'live-api.json', d.verify_api(s['url']))
    s['promoted'] = datetime.now(timezone.utc).isoformat()
    d.save()
    print('Backend traffic promoted; existing website preview retained on matching backend', flush=True)


def smoke():
    assert s.get('promoted')
    code = '''import json,os
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.cloud_smoke import check
from bmt_backend.verifier import GodotVerifier
settings=Settings.from_env();fixture=json.loads(Path('/opt/bmt/acceptance/verified_oval.json').read_text())
verifier=GodotVerifier(settings)
try: fixture['expected_manifest']=verifier.validate_track(fixture['document'])
finally: verifier.close()
path=Path('/tmp/release-current-oval.json');path.write_text(json.dumps(fixture))
result=check(settings,os.environ['BMT_STAGING_OWNER'],fixture_path=path)
print('RELEASE_RESULT='+json.dumps(result))
'''
    value = d.execute('live-native-storage-smoke', code, timeout=420)
    assert value['status'] == 'passed' and value['schema'] == d.HEAD and value['canonical_ticks'] == 12757
    s['smoke_passed'] = value
    d.save()
    print(json.dumps(value), flush=True)


def daily():
    assert s.get('promoted') and (WORK / 'daily-drive-state.private.json').exists()
    drive = json.loads((WORK / 'daily-drive-state.private.json').read_text())
    assert len(drive['cars']) == 5 and all(row.get('status') == 'verified' for row in drive['cars'].values())
    before = json.loads((OUT / 'daily-inspection-before.json').read_text())
    code = '''import json
from sqlalchemy import select
from bmt_backend.app import create_app
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.track_models import TrackVersion,now,digest
from bmt_backend.daily_fixed_limits import publish_build_variant,displayed_version
a=create_app()
with a.state.session_factory() as session:
 day=session.get(TrackOfDay,DAY)
 assert now()//86400==DAY and day.lap_limits.get('include_artificial')
 original={key:value for key,value in day.lap_limits.items() if key!='build_variant'}
 assert digest(original)==ORIGINAL
 version=session.get(TrackVersion,VERSION)
 published=publish_build_variant(session,DAY,version,a.state.verifier.manifest(),now(),allow_artificial=True)
 assert digest({key:value for key,value in day.lap_limits.items() if key!='build_variant'})==ORIGINAL
 selection=day.lap_limits['build_variant']['limits']
 result={'day':DAY,'published':published,'displayed_version':displayed_version(day),'original_targets_preserved':True,
  'verified_population':{car:row['population'] for car,row in selection['vehicles'].items()},'limits':{car:row['cutoffs'] for car,row in selection['vehicles'].items()}}
 session.commit()
print('RELEASE_RESULT='+json.dumps(result))
a.state.verifier.close();a.state.engine.dispose()
'''.replace('DAY', str(before['day'])).replace('ORIGINAL', repr(before['limits_digest'])).replace('VERSION', repr(drive['version_id']))
    value = d.execute('daily-build-variant', code, job=service.n['migrate'], timeout=600)
    assert len(value['verified_population']) == 5 and min(value['verified_population'].values()) >= 1
    s['daily_passed'] = value
    d.save()
    d.write(OUT / 'daily-drives.json', {car: {'status': row['status'], 'time_ticks': row['time_ticks']} for car, row in drive['cars'].items()})
    print('Compatible Daily variant published; original targets preserved', flush=True)


def finish():
    assert all(s.get(key) for key in ('promoted', 'smoke_passed', 'catalog_passed', 'worker_passed', 'history_preserved', 'daily_passed', 'authority_passed', 'discovery_passed'))
    final = {}
    for name, kind in s['targets'].items():
        role = 'studio' if name == service.n['admin'] else 'preview' if name == service.n['api'] else 'main'
        if kind == 'api':
            current = d.guarded(name, [s['image_' + role]])
            tags = [row['tag'] for row in current['status']['traffic'] if row.get('tag') in [TAG + '-' + item for item in ('main', 'studio', 'preview')]]
            if tags:
                service.call('run', 'services', 'update-traffic', name, REGION,
                             '--remove-tags=' + ','.join(tags), '--format=json')
        resource = d.guarded(name, [s['image_' + role]])
        d.write(WORK / ('after-' + name + '.private.json'), resource)
        if kind == 'api':
            serving = next(row for row in resource['status']['traffic'] if row.get('percent') == 100)
            assert serving['revisionName'] == s['route_studio' if role == 'studio' else 'route_main']['revisionName']
            if role == 'preview':
                preview = next(row for row in resource['status']['traffic'] if row.get('tag') == 'website-preview')
                assert preview['revisionName'] == s['route_preview']['revisionName']
        if kind == 'worker':
            original = json.loads((WORK / ('before-' + name + '.private.json')).read_text())
            assert resource['metadata']['annotations']['run.googleapis.com/manualInstanceCount'] == original['metadata']['annotations']['run.googleapis.com/manualInstanceCount']
        final[name] = {'kind': kind, 'template_image': s['image_' + role], 'runtime_environment_identity_resources_and_process_preserved': True}
    d.write(OUT / 'final-targets.json', final)
    d.write(OUT / 'final-http.json', d.verify_api(s['url']))
    d.verify_admin(service.describe('api', service.n['admin'])['status']['url'])
    directory = ROOT / '.tools/gcp-staging' / ('rendered-' + d.config['owner'])
    for filename in ('deployment.json', 'image.json', 'test-population.json'):
        path = directory / filename
        if not path.exists():
            continue
        original = json.loads(path.read_text())
        if filename != 'image.json':
            assert original['owner'] == d.config['owner']
        if not (WORK / (filename + '.before.private.json')).exists():
            d.shutil.copyfile(path, WORK / (filename + '.before.private.json'))
        updated = {**original, 'image': s['image_main']}
        if filename in ('deployment.json', 'image.json'):
            updated['source_hash'] = s['source_hash']
        if filename == 'deployment.json':
            updated['schema'] = d.HEAD
        d.write(path, updated)
    lock = directory / 'update.lock'
    assert json.loads(lock.read_text()) == {'task': TAG, 'source_hash': s['source_hash']}
    lock.unlink()
    s['backend_complete'] = datetime.now(timezone.utc).isoformat()
    d.save()
    d.write(OUT / 'rollout.json', {'complete': True, 'schema_before': s['schema_before'], 'schema': d.HEAD,
        'source_hash': s['source_hash'], 'images': {role: s['image_' + role] for role in ('main', 'studio', 'preview')},
        'backup_id': s['backup_id'], 'promoted': s['promoted'], 'completed': s['backend_complete'], 'targets': len(final),
        'historical_results_preserved': True, 'original_daily_targets_preserved': True, 'website_preview_preserved': True})
    print('Backend deployment verified and local release receipts updated', flush=True)


def authority():
    d.authority()


def discovery():
    d.discovery()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['push', 'backup', 'migrate', 'canaries', 'catalog', 'workers', 'promote', 'smoke', 'snapshot', 'daily', 'finish', 'authority', 'discovery'])
    globals()[parser.parse_args().phase]()
