"""Render shipping templates with disposable placeholders; never starts services."""
import json,subprocess
from pathlib import Path
root=Path.cwd();work=root/'build/security-fixes-20261024'
def unix(path):return '/mnt/c/'+str(path)[3:].replace('\\','/')
values={'POSTGRES_PASSWORD':'p'*64,'BMT_DB_PASSWORD':'m'*64,'BMT_MIGRATOR_DB_PASSWORD':'m'*64,
 'BMT_API_DB_PASSWORD':'a'*64,'BMT_WORKER_DB_PASSWORD':'w'*64,'BMT_ADMIN_DB_PASSWORD':'s'*64,
 'BMT_DEV_AUTH_KEY':'d'*64,'BMT_ADMIN_OWNER_KEY':'o'*64,'BMT_ADMIN_ANALYST_KEY':'r'*64,
 'GODOT_SHA256':'f'*64,'BMT_PUBLIC_BASE_URL':'https://fixture.invalid',
 'BMT_S3_ENDPOINT':'https://objects.fixture.invalid','BMT_S3_BUCKET':'fixture',
 'BMT_S3_ACCESS_KEY':'fixture-key','BMT_S3_SECRET_KEY':'fixture-secret'}
env=work/'compose.env';env.write_text(''.join(k+'='+v+'\n' for k,v in values.items()))
reports={}
for kind,files in [('production',['compose.yaml']),('cloud',['compose.yaml','compose.cloud.yaml']),('pc',['compose.pc.yaml'])]:
 args=['wsl.exe','-d','Ubuntu','--','docker','compose','--env-file',unix(env)]
 for name in files:args+=['-f',unix(root/'backend/deploy'/name)]
 result=subprocess.run([*args,'--profile','studio','config','--format','json'],capture_output=True,text=True,check=True)
 data=json.loads(result.stdout)['services'];seen=set()
 for role in ('api','worker','admin'):
  settings=data[role]['environment'];seen.add(settings['BMT_DATABASE_URL'])
  assert settings['BMT_WORKLOAD_ROLE']==role
  if role!='admin':assert 'BMT_ADMIN_OWNER_KEY' not in settings and 'BMT_STUDIO_STAFF_SUBJECTS' not in settings
 assert len(seen)==3
 assert data['migrate']['environment']['BMT_WORKLOAD_ROLE']=='migrator'
 assert 'database_privileges' in ' '.join(data['migrate']['command'])
 assert data['admin']['ports'][0]['host_ip']=='127.0.0.1'
 reports[kind]={'distinct_runtime_urls':3,'worker_admin_credentials':False,'migrator_separate':True,'studio_loopback':True}
(root/'docs/evidence/security-fixes-2026-10-24/compose-render.json').write_text(json.dumps(reports,indent=2)+'\n')
print(json.dumps(reports))
