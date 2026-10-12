"""Measure existing development menu reads; never issue races or deploy."""
import importlib.util
import json
import os
from pathlib import Path
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
private = ROOT / '.tools/gcp-staging'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(private / 'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE'] = str(private / 'windows-trust.pem')
spec = importlib.util.spec_from_file_location('staging', ROOT / 'backend/deploy/gcp/staging.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)
config = json.loads((private / 'config.json').read_text())
assert config['retain_data'] and config['test_drivers_enabled'] and config['project'] == 'beat-my-track'
service = stage.Staging(config, private / ('rendered-' + config['owner']))
receipt = json.loads((service.directory / 'deployment.json').read_text())
live = service.describe('api', service.n['api'])
image = stage.resource_image(live)
key = service.call('secrets', 'versions', 'access', '1', '--secret=' + config['test_drivers_secret'])
sys.path.insert(0, str(ROOT / 'backend'))
from bmt_backend.test_population_tool import API
api = API(receipt['url'], key)
plan = json.loads((ROOT / 'build/cloud-histograms-200-2026-10-06.json').read_text())
profile = plan['profiles'][0]
login = api.call('POST', '/auth/development', {'subject': profile['subject'], 'display_name': profile['display_name']}, operator=True)
api.http.headers['Authorization'] = 'Bearer ' + login['access_token']
catalog = api.call('GET', '/dev/test-drivers/tracks?vehicle_id=compact', operator=True)
tracks = sorted(catalog['tracks'], key=lambda row: (row['name'].casefold() != 'underpass', row['name']))[:3]
report = {'image': image, 'player_records_changed': False, 'races_submitted': 0, 'deployment': True,
          'diagnostic_session': 'existing development driver', 'measurements': []}
for path in ('/health', '/v1/bootstrap'):
    samples = []
    for _ in range(5):
        started = time.perf_counter_ns()
        response = api.http.get(api.url + path, timeout=30)
        response.raise_for_status()
        samples.append((time.perf_counter_ns()-started)/1e6)
    item = {'endpoint':path,'samples_ms':samples,'median_ms':statistics.median(samples),'max_ms':max(samples)}
    report['measurements'].append(item)
    print(json.dumps(item),flush=True)
ready = api.http.get(api.url + '/ready', timeout=30)
report['ready_status'] = ready.status_code
if ready.ok:
    # Retain only public readiness fields, never credentials or DB URLs.
    report['ready'] = {k: v for k, v in ready.json().items() if k in ('schema', 'status', 'migration_revision', 'database_revision')}
for track in tracks:
    for endpoint in ('results-comparison?vehicle_id=compact&bins=16', 'leaderboard?vehicle_id=compact'):
        samples = []
        for _ in range(5):
            started = time.perf_counter_ns()
            response = api.http.get(api.url + '/v1/track-versions/' + track['version_id'] + '/' + endpoint, timeout=30)
            duration = (time.perf_counter_ns() - started) / 1e6
            response.raise_for_status()
            packet = response.json()
            samples.append(duration)
        item = {'track': track['name'], 'endpoint': endpoint.split('?')[0], 'samples_ms': samples,
                'median_ms': statistics.median(samples), 'max_ms': max(samples), 'response_bytes': len(response.content),
                'race_population': packet.get('race', {}).get('population'),
                'lap_population': packet.get('best_lap', {}).get('population')}
        report['measurements'].append(item)
        print(json.dumps(item), flush=True)
destination = ROOT / 'docs/evidence/menu-loading-speed-2026-10-10/live-latency-after.json'
destination.write_text(json.dumps(report, indent=2) + '\n')
print('Read-only HTTP benchmark complete; no races or deployments.', flush=True)
