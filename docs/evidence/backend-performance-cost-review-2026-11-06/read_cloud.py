"""Read-only configuration and aggregate Monitoring inspection; no player data."""
import importlib.util
import json
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / '.tools/gcp-staging/config.json').read_text(encoding='utf-8-sig'))
ENV = dict(os.environ, CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=str(ROOT / '.tools/gcp-staging/windows-trust.pem'))
PREFIX = 'bmt-stg-e7a444ab'


def read(args):
    result = subprocess.run([*CONFIG['gcloud'], '--project=' + CONFIG['project'], *args, '--quiet'],
                            capture_output=True, text=True, encoding='utf-8', env=ENV, timeout=50, check=False)
    if result.returncode:
        return {'inspection_error': 'read failed', 'family': args[:3]}
    return json.loads(result.stdout)


def main():
    prior = OUT.parent / 'backend-performance-review-2026-10-24/inspect_cloud.py'
    spec = importlib.util.spec_from_file_location('review_aggregate_reader', prior)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.OUT = OUT
    module.main()
    calls = {
        'api': ['run', 'services', 'describe', PREFIX + '-api', '--region=' + CONFIG['region'], '--format=json'],
        'studio': ['run', 'services', 'describe', PREFIX + '-studio', '--region=' + CONFIG['region'], '--format=json'],
        'worker': ['run', 'worker-pools', 'describe', PREFIX + '-worker', '--region=' + CONFIG['region'], '--format=json'],
        'schedules': ['scheduler', 'jobs', 'list', '--location=' + CONFIG['region'], '--format=json(name,state,schedule,timeZone)'],
        'jobs': ['run', 'jobs', 'list', '--region=' + CONFIG['region'], '--format=json(metadata.name,status.lastExecution)'],
        'repositories': ['artifacts', 'repositories', 'list', '--location=' + CONFIG['region'], '--format=json(name,format,sizeBytes,cleanupPolicies,cleanupPolicyDryRun)'],
    }
    with ThreadPoolExecutor(max_workers=4) as pool:
        raw = dict(pool.map(lambda kv: (kv[0], read(kv[1])), calls.items()))
    allowed = {'BMT_DATABASE_POOL_SIZE', 'BMT_DATABASE_POOL_OVERFLOW', 'BMT_MAX_QUEUED_RUNS',
               'BMT_TELEMETRY_ENABLED', 'BMT_WORLD_RANKING_LAUNCH_WEEK', 'BMT_RETENTION_DAYS',
               'BMT_TEST_DRIVERS_ENABLED', 'BMT_PERSISTENT_VERIFIER', 'BMT_UPLOAD_CONCURRENCY',
               'BMT_OBJECT_PACKING_ENABLED', 'BMT_HTTP_SUCCESS_SAMPLE_PER_MILLE', 'BMT_WORKLOAD_ROLE',
               'BMT_WORKER_POLL_SECONDS', 'BMT_STUDIO_USAGE_BILLING_TABLE', 'BMT_STUDIO_USAGE_BILLING_PROJECT',
               'BMT_STUDIO_USAGE_BILLING_DATASET', 'BMT_STUDIO_USAGE_BILLING_LOCATION'}
    result = {'captured_at_utc': datetime.now(timezone.utc).isoformat()}
    for role in ('api', 'studio', 'worker'):
        data = raw.pop(role)
        template = data.get('spec', {}).get('template', data.get('template', {}))
        runtime = template.get('spec', template)
        container = runtime.get('containers', [{}])[0]
        result[role] = {
            'inspection_error': data.get('inspection_error'),
            'resources': container.get('resources'), 'concurrency': runtime.get('containerConcurrency'),
            'annotations': {k: v for k, v in template.get('metadata', {}).get('annotations', {}).items()
                            if any(s in k.lower() for s in ('scale', 'cpu', 'instance'))},
            'scaling': data.get('scaling', data.get('spec', {}).get('scaling')),
            'service_scaling': {k: v for k, v in data.get('metadata', {}).get('annotations', {}).items()
                                if any(s in k.lower() for s in ('scale', 'cpu', 'instance'))},
            'traffic': data.get('status', {}).get('traffic'), 'image': container.get('image'),
            'flags': {item['name']: item.get('value') for item in container.get('env', []) if item['name'] in allowed},
            'usage_setting_names': [item['name'] for item in container.get('env', []) if 'USAGE' in item['name']],
        }
    result.update(raw)
    (OUT / 'cloud-details.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
