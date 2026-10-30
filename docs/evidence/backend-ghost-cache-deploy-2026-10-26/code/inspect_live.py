"""Read-only inspection for the owner-requested ghost-cache backend rollout."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'backend/deploy/gcp'))
import staging

config = json.loads((ROOT / '.tools/gcp-staging/config.json').read_text(encoding='utf-8-sig'))
assert config['project'] == 'beat-my-track' and config['retain_data'] is True
trust = ROOT / '.tools/gcp-staging/windows-trust.pem'
if trust.exists():
    os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(trust)
    os.environ['REQUESTS_CA_BUNDLE'] = str(trust)

class Runner(staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        result = subprocess.run(argv, input=input_data, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', cwd=cwd, timeout=180)
        if result.returncode:
            if allow_missing and any(x in result.stderr for x in ('NOT_FOUND','not found','does not exist')):
                return None
            (WORK / 'last-error.private.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            raise RuntimeError('Read-only cloud command failed; inspect private diagnostic')
        return result.stdout.strip()

service = staging.Staging(config, WORK, Runner())

def runtime(value):
    for _ in range(10):
        if isinstance(value, dict) and value.get('containers'):
            return value
        value = value.get('template') or value.get('spec') if isinstance(value, dict) else None
    raise RuntimeError('Unexpected resource template')

def inspect_one(target):
    kind, name = target
    value = service.describe(kind, name)
    assert value is not None
    (WORK / ('before-' + name + '.private.json')).write_text(json.dumps(value, indent=2), encoding='utf-8')
    node = runtime(value)
    safe_names = ('BMT_WORKLOAD_ROLE', 'BMT_OBJECT_PACKING_ENABLED', 'BMT_RETENTION_DAYS',
                  'BMT_COST_ARCHIVE_DAYS', 'BMT_HTTP_SUCCESS_SAMPLE_PER_MILLE',
                  'BMT_TRANSPORT_PROFILE', 'BMT_STUDIO_ANALYSIS_MODE')
    env = {x['name']: x.get('value', '<secret-reference>') for x in node['containers'][0].get('env', [])}
    return {'kind':kind, 'name':name, 'image':staging.resource_image(value),
            'revision':value.get('status', {}).get('latestReadyRevisionName'),
            'url':value.get('status', {}).get('url'),
            'service_account':node.get('serviceAccount') or node.get('serviceAccountName'),
            'settings':{k:env[k] for k in safe_names if k in env},
            'conditions':value.get('status', {}).get('conditions', []),
            'traffic':value.get('status', {}).get('traffic', [])}

if __name__ == '__main__':
    targets=[('api',service.n['api']), ('worker',service.n['worker']),
             ('job',service.n['migrate']), ('job',service.n['smoke']), ('api',service.n['admin'])]
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        values=list(pool.map(inspect_one,targets))
    (WORK/'inspection.json').write_text(json.dumps(values,indent=2),encoding='utf-8')
    print(json.dumps(values,indent=2))
    import requests
    origin=values[0]['url']
    for path in ('/health','/ready','/v1/bootstrap'):
        response=requests.get(origin+path,timeout=30)
        response.raise_for_status()
        value=response.json()
        (WORK/(path.rsplit('/',1)[-1]+'-before.json')).write_text(json.dumps(value,indent=2),encoding='utf-8')
        print(path,json.dumps(value if path != '/v1/bootstrap' else
              {k:v for k,v in value.items() if 'ghost' in k or 'record' in k or k in ('schema_version','capabilities','transport_profile')}))
