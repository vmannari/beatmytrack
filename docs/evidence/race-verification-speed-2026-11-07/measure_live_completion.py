"""Privately supply the existing dev binding for one controlled timing sample."""
import importlib.util,json,subprocess
from pathlib import Path
WORK=Path(__file__).resolve().parent;ROOT=WORK.parents[1]
spec=importlib.util.spec_from_file_location('previous_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.d.WORK=WORK
resource=r.service.describe('api',r.service.n['api'])
binding=next(v for v in r.d.runtime(resource)['containers'][0]['env'] if v['name']=='BMT_DEV_AUTH_KEY')
if 'value' in binding:key=binding['value']
else:
 ref=binding['valueFrom']['secretKeyRef']
 value=subprocess.run([*r.d.config['gcloud'],'--project='+r.d.config['project'],'secrets','versions','access',ref.get('key','latest'),'--secret='+ref['name'],'--quiet'],capture_output=True,text=True,timeout=60,check=True)
 key=value.stdout.strip()
assert key and '\n' not in key and '\r' not in key
env=WORK/'operator.private.env'
env.write_text('BMT_DEV_AUTH_KEY='+key+'\nRELEASE_API='+r.s['url']+'\n')
try:
 command=r.DOCKER+['run','--rm','--pull=never','--cpus=1','--memory=512m','--label','bmt.race-speed=20261107','--env-file',r.d.unix(env),
   '--mount','type=bind,src='+r.d.unix(WORK)+',dst=/release',
   '--mount','type=bind,src='+r.d.unix(ROOT/'build/backend-compat-deploy-20261107')+',dst=/previous,readonly',
   '--mount','type=bind,src='+r.d.unix(ROOT/'.tools/gcp-staging/windows-trust.pem')+',dst=/trust.pem,readonly',
   '--env','REQUESTS_CA_BUNDLE=/trust.pem','--entrypoint','python',r.s['image_main'],'/release/live_completion_client.py']
 print(r.d.command(command,'controlled-live-completion',timeout=120),flush=True)
finally:env.unlink(missing_ok=True)
