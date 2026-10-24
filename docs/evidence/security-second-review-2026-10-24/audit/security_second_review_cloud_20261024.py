"""Read-only metadata/HTTP checks; never execute jobs or access secret contents."""
import importlib.util
import json
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/evidence/security-second-review-2026-10-24'
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('review_deployment', ROOT/'.tools/security_deploy_20261024.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
result = {'scope':'read-only cloud metadata and ordinary public GETs; no secret contents, SQL, job execution or configuration change', 'targets':{}}
targets = json.loads((d.WORK/'targets.private.json').read_text(encoding='utf-8'))
for name, kind in targets.items():
    if kind not in ('api','worker','job'):
        continue
    value = d.service.describe(kind, name)
    env = d.envmap(value)
    result['targets'][name] = {'image':d.staging.resource_image(value),
        'account':d.runtime(value).get('serviceAccountName'),
        'settings':{k:env.get(k,{}).get('value') for k in (
            'BMT_ENVIRONMENT','BMT_WORKLOAD_ROLE','BMT_STUDIO_LEGACY_KEYS_ENABLED',
            'BMT_TEMPORARY_AD_RESUMES_ENABLED','BMT_DEV_AUTH_ENABLED','BMT_TEST_DRIVERS_ENABLED',
            'BMT_TRUSTED_PROXY_NETWORKS','BMT_OBJECT_PACKING_ENABLED')},
        'administrator_variable_names':[k for k in env if k.startswith(('BMT_ADMIN_','BMT_STUDIO_STAFF_SUBJECTS','BMT_STUDIO_MONITOR_'))]}
    if kind == 'api':
        result['api_traffic'] = value['status']['traffic']
        result['api_url'] = value['status']['url']
    if kind == 'worker':
        result['worker_instances'] = value['metadata']['annotations']['run.googleapis.com/manualInstanceCount']
old = d.state['old_runtime_account']
result['old_service_account_disabled'] = d.service.describe('account',old).get('disabled')
secret = 'bmt-stg-'+d.config['owner'][:8]+'-app-db'
version = json.loads(d.service.call('secrets','versions','describe','1','--secret='+secret,'--format=json'))
result['old_secret_version_state'] = version['state']
result['http'] = d.verify_http(result['api_url'])
api_secret = d.service.n['app_secret']
worker_secret = d.service.n['worker_secret']
admin_secret = d.service.n['admin_secret']
grants = {}
for secret in (api_secret,worker_secret,admin_secret,d.service.n['staff_secret']):
    policy = json.loads(d.service.call('secrets','get-iam-policy',secret,'--format=json'))
    grants[secret] = [{'role':v['role'],'members':v['members']} for v in policy.get('bindings',[])]
result['database_secret_iam'] = grants
(OUT/'cloud-read-only.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'target_count':len(result['targets']),'old_service_account_disabled':result['old_service_account_disabled'],
                  'old_secret_version_state':result['old_secret_version_state'],'http':result['http']}))
