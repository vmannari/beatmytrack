"""Five bounded, honestly driven development recordings; ordinary HTTP verification."""
import json
import os
import time
from pathlib import Path

from bmt_backend.config import Settings
from bmt_backend.test_driver_generator import controller_engine, generate
from bmt_backend.test_population_tool import API, atomic_save, recording
from bmt_backend.contracts import build_contract
from bmt_backend.track_models import digest

root = Path('/release')
target = json.loads((root / 'daily-target.json').read_text())
path = root / 'daily-drive-state.private.json'
state = json.loads(path.read_text()) if path.exists() else {'version_id': target['head_version_id'], 'cars': {}}
assert state['version_id'] == target['head_version_id'] and target['include_artificial']
api = API(os.environ['RELEASE_API'], os.environ['BMT_DEV_AUTH_KEY'])
settings = Settings(environment='test', godot_bin='/usr/local/bin/godot', game_project='/opt/bmt/game', object_dir='/release/drive-cache/objects')
fleet = api.call('POST', '/dev/test-drivers/fleets', {'seed': 202611071, 'count': 1, 'skill_min': 0.8, 'skill_max': 0.8}, operator=True)
profile = fleet['profiles'][0]
manifest = api.call('GET', '/manifest')
with controller_engine(settings) as verifier:
    assert build_contract(verifier.manifest()) == build_contract(manifest)
for car in sorted(manifest['vehicles']):
    job = state['cars'].setdefault(car, {'id': digest(['compat-20261107-daily', state['version_id'], car]),
             'version_id': state['version_id'], 'content_hash': target['content_hash'], 'attempt': 0})
    atomic_save(path, state)
    if not job.get('run_id'):
        recovered = api.call('GET', '/dev/test-drivers/uploads/' + job['id'] + '-upload', subject=profile['subject'], operator=True)
        assert not recovered.get('retired'), 'Keep journal; upload history needs review'
        if recovered.get('run'):
            job['run_id'] = recovered['run']['run_id']
        else:
            prepared = root / ('pregenerated-' + car + '.json')
            if prepared.exists():
                candidate = json.loads(prepared.read_text())
                assert candidate['content_hash'] == target['content_hash'] and candidate['vehicle_id'] == car
                assert build_contract(candidate['result']['manifest']) == build_contract(manifest)
                assert digest(api.call('GET', '/track-versions/' + state['version_id'] + '/document')) == candidate['content_hash']
                cache = path.parent / (path.stem + '-recordings')
                cache.mkdir(exist_ok=True)
                atomic_save(cache / (job['id'] + '.json'), candidate['result'])
            deadline = time.monotonic() + 600
            def bounded(*args, **kwargs):
                return generate(*args, **kwargs, deadline=deadline)
            result = recording(api, {'vehicle_id': car, 'pace_scales': {}, 'manifest': manifest}, job, profile, settings, path, generator=bounded)
            # recording() can persist a planning dictionary; retain this release journal.
            atomic_save(path, state)
            if not job.get('ticket'):
                job['ticket'] = api.call('POST', '/run-tickets', {'version_id': state['version_id'], 'vehicle_id': car, 'test_population': True}, profile['subject'], job['id'] + '-ticket')
                atomic_save(path, state)
            run = api.call('POST', '/runs', {'ticket_id': job['ticket']['ticket_id'], 'replay': result['replay']}, profile['subject'], job['id'] + '-upload')
            job['run_id'] = run['run_id']
        atomic_save(path, state)
    deadline = time.monotonic() + 600
    while True:
        run = api.call('GET', '/runs/' + job['run_id'], subject=profile['subject'])
        if run['status'] not in ('queued', 'verifying'):
            break
        assert time.monotonic() < deadline, 'Verification deadline reached; durable journal retained'
        time.sleep(2)
    assert run['status'] == 'verified', (car, run.get('failure_code'), run['status'])
    job.update(status=run['status'], time_ticks=run['time_ticks'])
    atomic_save(path, state)
    print(json.dumps({'car': car, 'status': run['status'], 'time_ticks': run['time_ticks']}), flush=True)
api.http.close()
