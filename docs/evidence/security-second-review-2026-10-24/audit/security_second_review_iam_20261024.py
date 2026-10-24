"""Read only owned cloud permissions; no credentials or account rows."""
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('review_deploy',ROOT/'.tools/security_deploy_20261024.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
accounts={role:d.service.n[name]+'@'+d.config['project']+'.iam.gserviceaccount.com'
          for role,name in [('api','runtime'),('worker','worker_runtime'),('migrator','migrator'),('operator','operator')]}
accounts['retired']=d.state['old_runtime_account']
members={'serviceAccount:'+account for account in accounts.values()}
policy=json.loads(d.service.call('projects','get-iam-policy',d.config['project'],'--format=json'))
project=[{'role':v['role'],'members':[m for m in v.get('members',[]) if m in members],
          'condition':v.get('condition')} for v in policy.get('bindings',[]) if members.intersection(v.get('members',[]))]
policy=json.loads(d.service.call('storage','buckets','get-iam-policy','gs://'+d.service.n['bucket'],'--format=json'))
bucket=[{'role':v['role'],'members':[m for m in v.get('members',[]) if m in members],
         'condition':v.get('condition')} for v in policy.get('bindings',[]) if members.intersection(v.get('members',[]))]
public=any(set(v.get('members',[])).intersection({'allUsers','allAuthenticatedUsers'}) for v in policy.get('bindings',[]))
sql=d.service.describe('sql',d.service.n['sql'])
result={'accounts':accounts,'project_bindings':project,'bucket_bindings':bucket,
        'bucket_public':public,'database_version':sql['databaseVersion'],
        'sql_authorized_network_count':len(sql['settings'].get('ipConfiguration',{}).get('authorizedNetworks',[])),
        'deletion_protection':sql['settings'].get('deletionProtectionEnabled')}
(ROOT/'docs/evidence/security-second-review-2026-10-24/cloud-iam.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'bucket_public':public,'sql_authorized_network_count':result['sql_authorized_network_count'],
                  'project_role_names':sorted({v['role'] for v in project}), 'deletion_protection':result['deletion_protection']}))
