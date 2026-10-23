"""Apply the owner's explicit approval of both catalog and deletion proposals.

Uses the already tested frozen image; does not package concurrent workspace code.
"""
import argparse
import importlib.util
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('approved_deploy', ROOT / '.tools/backend_latest_rollout_20261016.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
prior = json.loads((d.OUTPUT / 'rollout.json').read_text())
assert prior['completed'] and prior['image_variant'] == 'existing-contract'
d.WORK = ROOT / 'build/backend-approved-followup-2026-10-16'
d.OUTPUT = ROOT / 'docs/evidence/backend-approved-followup-2026-10-16'
d.WORK.mkdir(parents=True, exist_ok=True)
d.OUTPUT.mkdir(parents=True, exist_ok=True)
d.RECEIPT = d.OUTPUT / 'rollout.json'
d.r = json.loads(d.RECEIPT.read_text()) if d.RECEIPT.exists() else {
    'source_hash': prior['source_hash'], 'schema': prior['schema'],
    'image': prior['latest_prepared_image'],
    'expected_manifest': prior['latest_prepared_manifest'],
    'previous_completed_rollout': 'backend-latest-deploy-2026-10-16/rollout.json',
    'approval': {'user_message': 'approve both', 'scope': [
        'Append the 27 matching compiler27 / physics0.59 official published revisions, retaining originals and scores',
        'Grant storage.objects.delete to the existing runtime only under bmt/v1/, excluding bmt-erasure-v1/'],
        'received': True},
}

def inspect():
    d.inspect_live()
    assert d.r['parent'] == prior['image'], 'Live image changed since the completed deployment'
    assert d.r['schema_before'] == d.r['schema'] == '0036_community_safety'
    initial = json.loads((d.OUTPUT / 'initial-readonly.json').read_text())
    assert initial['health'] == 'ready' and initial['queue_depth'] == 0
    assert initial['expected_build'] == {k:v for k,v in prior['existing_contract_manifest'].items() if k != 'max_frames'}
    assert initial['available_workers'] == 1
    lock = d.DIRECTORY / 'update.lock'
    if lock.exists():
        value = json.loads(lock.read_text())
        assert value.get('task') == 'latest-backend-ui-20261016' and value.get('source_hash') == d.r['source_hash']
    else:
        with lock.open('x') as handle:
            json.dump({'task': 'latest-backend-ui-20261016', 'source_hash': d.r['source_hash'],
                'scope': 'explicitly approved catalog and deletion follow-up'}, handle)
    d.save()

def schema_verified():
    assert d.r.get('writers_paused') and d.r.get('data_before')
    assert d.r['data_before']['schema'] == d.r['schema']
    d.r['migration_complete'] = True
    d.r['migration_action'] = 'No migration; schema36 already deployed and freshly verified'
    d.save()
    print(json.dumps({'schema_unchanged': d.r['schema']}))

def heads_before():
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
with e.connect() as c:
 c.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
 rows=c.execute(text("SELECT DISTINCT ON (v.track_id) v.id,v.track_id,v.number,v.content_hash FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE t.official=true AND t.hidden=false AND t.archived=false AND v.state='published' ORDER BY v.track_id,v.number DESC")).mappings().all()
 assert len(rows)==27
 print('LATEST_RESULT='+json.dumps({'heads':[dict(row) for row in rows]}))
e.dispose()
'''
    result = d.execute('catalog-heads-before', code)
    print(json.dumps({'original_official_heads_recorded': len(result['heads'])}))

def permission_probe():
    assert d.r['object_delete_permission'] == 'scoped ordinary-prefix custom role'
    code = '''import json,secrets,time
from bmt_backend.config import Settings
from bmt_backend.gcs_storage import GCSBlobStore
s=GCSBlobStore(Settings.from_env());nonce=secrets.token_hex(24)
try:
 digest=s.put_json({'deployment_check':'approved-object-deletion','nonce':nonce})
 assert s.get_json(digest)['nonce']==nonce
 for attempt in range(18):
  try:s.delete(digest);break
  except OSError:
   if attempt==17:raise
   time.sleep(5)
 status,_=s._request('GET',s._key(digest),query={'fields':'name'})
 assert status==404
 # ifGenerationMatch=0 cannot delete an existing journal object, even if IAM is broader than expected.
 status,_=s._request('DELETE','bmt-erasure-v1/deployment-deny-check-'+nonce,query={'ifGenerationMatch':'0'})
 assert status in (403,404),status
 print('LATEST_RESULT='+json.dumps({'runtime_ordinary_marker_create_read_delete':True,'marker_absent_after_delete':True,'missing_journal_marker_response':status,'journal_probe_wrote_no_data':True,'journal_exclusion_source':'verified IAM prefix condition; a missing-object response alone does not prove denial','real_player_objects_deleted':0}))
finally:s.close()
'''
    result = d.execute('runtime-delete-probe', code)
    d.r['runtime_delete_verified'] = True
    d.save()
    print(json.dumps(result))

def probe_diagnostic():
    name = 'bmt-stg-e7a444ab-smoke-24n42'
    logs = json.loads(d.service.call('logging', 'read',
        'resource.type="cloud_run_job" AND labels."run.googleapis.com/execution_name"="'+name+'"',
        '--limit=80', '--order=asc', '--format=json'))
    messages = '\n'.join(row.get('textPayload', '') for row in logs)
    (d.WORK / 'permission-probe-initial.private.log').write_text(messages, encoding='utf-8')
    print(messages[-4500:])

def approved_catalog_program():
    heads = json.loads((d.OUTPUT / 'catalog-heads-before.json').read_text())['heads']
    expected = {(h['id'], h['track_id'], h['number'], h['content_hash']) for h in heads}
    program = d.catalog_program(True)
    anchor = '  assert 1<=len(heads)<=100'
    assert program.count(anchor) == 1
    program = program.replace(anchor, '  assert len(heads)==27\n  assert {(h["id"],h["track_id"],h["number"],h["content_hash"]) for h in heads}=='+repr(expected))
    compile(program, 'approved-catalog-program', 'exec')
    return program

def check_program():
    import base64, gzip
    program = approved_catalog_program()
    bound = len(base64.b64encode(gzip.compress(program.encode()))) + 100
    assert bound < 7400
    print(json.dumps({'catalog_program_compiles': True, 'fenced_heads': 27, 'compressed_payload_bound': bound}))

def catalog():
    assert d.r['approval']['received'] and d.r.get('writers_paused')
    preview = json.loads((d.OUTPUT / 'catalog-preview.json').read_text())
    assert preview['validated_tracks'] == 27 and preview['matching_new_revisions_required'] == 27
    program = approved_catalog_program()
    result = d.execute('catalog-apply', program)
    assert result['inserted_versions'] == 27
    d.r['catalog_applied'] = True
    d.save()
    d.snapshot('data-after-catalog')
    print(json.dumps({k:v for k,v in result.items() if k != 'contract'}))

def browser():
    spec = importlib.util.spec_from_file_location('approved_live_browser', ROOT / '.tools/backend_latest_live_browser_20261016.py')
    # The original read-only script imports its deployment module by file path.
    # Execute its body with that one import replaced by this already configured module.
    source = Path(spec.origin).read_text()
    start = source.index('spec = importlib.util.spec_from_file_location(')
    stop = source.index('assert deployment.r.get("verify_live")', start)
    source = source[:start] + 'deployment = approved_deployment\n' + source[stop:]
    exec(compile(source, str(spec.origin), 'exec'), {'__file__': spec.origin, 'approved_deployment': d})

def catalog_http():
    from urllib.parse import urlencode
    from hashlib import sha256
    old = json.loads((d.OUTPUT / 'catalog-heads-before.json').read_text())['heads']
    original = {row['track_id']: row for row in old}
    route = '/v1/tracks?limit=20'
    items, pages = [], []
    while route:
        value = d.u.fetch(d.r['url'], route).json()
        pages.append(len(value['items']))
        items.extend(value['items'])
        cursor = value.get('next_cursor')
        route = '/v1/tracks?' + urlencode({'limit': 20, 'cursor': cursor}) if cursor else None
        assert len(pages) <= 5
    selected = [row for row in items if row['track_id'] in original]
    assert len(selected) == 27 and len({row['track_id'] for row in selected}) == 27
    def check(row):
        old = original[row['track_id']]
        assert row['version'] == old['number'] + 1 and row['content_hash'] == old['content_hash']
        detail = d.u.fetch(d.r['url'], '/v1/track-versions/' + row['version_id']).json()
        previous = d.u.fetch(d.r['url'], '/v1/track-versions/' + old['id']).json()
        assert previous['content_hash'] == detail['content_hash'] == old['content_hash']
        manifest = detail['manifest']
        assert manifest['compiler_version'] == 'creator-compiler-27' and manifest['physics_version'] == 'arcade-planar-0.59'
        assert manifest['laps'] == 5 and manifest['tick_rate'] == 120
        content = d.u.fetch(d.r['url'], '/v1/track-versions/' + row['version_id'] + '/document').content
        assert sha256(content).hexdigest() == old['content_hash']
        return {'track_id': row['track_id'], 'previous_version_id': old['id'],
            'new_version_id': row['version_id'], 'version': row['version'],
            'document_hash_preserved': True, 'previous_link_available': True,
            'new_manifest_matches': True}
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(check, selected))
    result = {'read_only': True, 'pages': pages, 'official_tracks_verified': len(rows), 'tracks': rows}
    (d.OUTPUT / 'catalog-live-http.json').write_text(json.dumps(result, indent=2) + '\n')
    d.r['catalog_live_http_verified'] = True
    d.save()
    print(json.dumps({'official_tracks_verified': len(rows), 'pages': pages, 'old_links_documents_preserved': True}))

def finish():
    assert d.r.get('runtime_delete_verified') and d.r.get('catalog_live_http_verified')
    assert d.r.get('catalog_applied')
    d.finish()

actions = {'inspect': inspect, 'backup': d.backup, 'preview': d.preview_catalog, 'heads': heads_before, 'check-program': check_program,
    'grant-delete': d.grant_object_delete, 'maintenance': d.maintenance,
    'permission-probe': permission_probe,
    'probe-diagnostic': probe_diagnostic,
    'snapshot': lambda: d.snapshot('data-before'), 'schema': schema_verified,
    'catalog': catalog, 'canary': d.canary, 'verify-canary': d.verify_existing_canary,
    'promote': d.promote, 'smoke': d.smoke, 'browser': browser, 'catalog-http': catalog_http, 'finish': finish}
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=actions)
    args = parser.parse_args()
    actions[args.action]()
