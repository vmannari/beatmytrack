import argparse,hashlib,importlib.util,json,os,subprocess
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[2]
private=ROOT/'.tools/gcp-staging'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(private/'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE']=str(private/'windows-trust.pem')
spec=importlib.util.spec_from_file_location('stage',ROOT/'backend/deploy/gcp/staging.py');stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)
config=json.loads((private/'config.json').read_text());assert config['retain_data'] and config['project']=='beat-my-track'
s=stage.Staging(config,private/('rendered-'+config['owner']))
e=ROOT/'docs/evidence/menu-loading-speed-2026-10-10';proof=json.loads((e/'server-image-proof.json').read_text())
rp=e/'deployment.json';r=json.loads(rp.read_text()) if rp.exists() else {'owner':config['owner'],'parent':proof['parent'],'authorized':True,'started':datetime.now(timezone.utc).isoformat()}
def save():stage.write_json(rp,r)
def guard():
 for kind in ('api','worker'):assert stage.resource_image(s.describe(kind,s.n[kind])) in (r['parent'],r.get('image')), 'Live image changed'
def configuration_hash(resource):
 found=[]
 def visit(value):
  if isinstance(value,dict):
   if 'containers' in value:
    found.extend({k:c[k] for k in ('env','resources','command','args','volumeMounts') if k in c} for c in value['containers'])
   for key,item in value.items():
    if key not in ('status','metadata'):visit(item)
  elif isinstance(value,list):
   for item in value:visit(item)
 visit(resource)
 return hashlib.sha256(json.dumps(found,sort_keys=True).encode()).hexdigest()
def update(kind,name):
 command={'api':'services','worker':'worker-pools','job':'jobs'}[kind]
 resource=s.describe(kind,name);assert stage.resource_image(resource) in (r['parent'],r['image']);before=configuration_hash(resource)
 if stage.resource_image(resource)!=r['image']:s.call('run',command,'update',name,'--region='+config['region'],'--image='+r['image'])
 after=s.describe(kind,name);assert stage.resource_image(after)==r['image'];assert configuration_hash(after)==before,'Container configuration changed';r[name+'_configuration_hash']=before;r[name]=True;save();print('Updated '+name,flush=True)
p=argparse.ArgumentParser();p.add_argument('action',choices=['proof','timings','worker','diagnose','audit','status','backup','publish','migrate','warm','deploy','smoke']);action=p.parse_args().action
if action=='proof':
 filter='resource.type="cloud_run_job" AND resource.labels.job_name="'+s.n['smoke']+'" AND timestamp>="'+r['started']+'" AND jsonPayload.status="passed"'
 entries=json.loads(s.call('logging','read',filter,'--limit=1','--order=desc','--format=json'));assert entries
 result=entries[0]['jsonPayload'];assert result['schema']=='0023_operational_read_indexes' and result['player_writes']==0
 states={}
 for kind in ('api','worker'):
  resource=s.describe(kind,s.n[kind]);assert stage.resource_image(resource)==r['image'];states[kind]={'image':r['image'],'conditions':resource.get('status',{}).get('conditions',[])}
 stage.write_json(e/'final-deployment-proof.json',{'smoke':result,'services':states,'backup':r['backup_id']});print(json.dumps(result))
if action=='timings':
 api=s.describe('api',s.n['api']);revision=api.get('status',{}).get('latestReadyRevisionName')
 filter='resource.type="cloud_run_revision" AND resource.labels.service_name="'+s.n['api']+'" AND resource.labels.revision_name="'+revision+'" AND jsonPayload.event="http_request" AND (jsonPayload.route="/health" OR jsonPayload.route="/bootstrap" OR jsonPayload.route="/track-versions/{version_id}/results-comparison" OR jsonPayload.route="/track-versions/{version_id}/leaderboard")'
 entries=json.loads(s.call('logging','read',filter,'--limit=120','--order=desc','--format=json'))
 rows=[{k:x.get('jsonPayload',{}).get(k) for k in ('route','status','duration_ms')} for x in entries];stage.write_json(e/'server-request-timings.json',{'revision':revision,'requests':rows})
 import statistics
 for route in sorted({x['route'] for x in rows if x['route']}):
  values=[x['duration_ms'] for x in rows if x['route']==route and x['status']==200 and isinstance(x['duration_ms'],(int,float))]
  if values:print(json.dumps({'route':route,'samples':len(values),'median_ms':statistics.median(values),'max_ms':max(values)}))
if action=='worker':
 guard();assert r.get('migrated');update('worker',s.n['worker'])
if action=='diagnose':
 rows=json.loads(s.call('run','jobs','executions','list','--job='+s.n['migrate'],'--region='+config['region'],'--limit=3','--format=json'))
 print(json.dumps([{'name':x.get('metadata',{}).get('name'),'status':x.get('status',{}).get('conditions')} for x in rows],indent=2))
 filter='resource.type="cloud_run_job" AND resource.labels.job_name="'+s.n['migrate']+'" AND timestamp>="'+r['started']+'"'
 logs=json.loads(s.call('logging','read',filter,'--limit=20','--order=desc','--format=json'))
 stage.write_json(ROOT/'build/menu-speed/deployment/job-diagnostics.json',logs)
 print(json.dumps([x.get('textPayload',x.get('jsonPayload',{})) for x in logs],indent=2))
if action=='audit':
 filter='resource.type="cloud_run_job" AND resource.labels.job_name="'+s.n['migrate']+'" AND (textPayload:"HISTOGRAM_WARMED" OR textPayload:"HISTOGRAM_PENDING")'
 entries=json.loads(s.call('logging','read',filter,'--limit=3','--order=desc','--format=json'))
 messages=[{'timestamp':x.get('timestamp'),'message':x.get('textPayload')} for x in entries];stage.write_json(e/'warmup-log.json',messages);print(json.dumps(messages))
if action=='status':
 rows=json.loads(s.call('sql','backups','list','--instance='+s.n['sql'],'--format=json'));print(json.dumps([{'id':b['id'],'status':b['status']} for b in rows[:3]]))
if action=='backup':
 guard();assert s.describe('sql',s.n['sql'])['settings']['deletionProtectionEnabled']
 description='Before approved stored-histogram rollout '+datetime.now(timezone.utc).isoformat()
 s.call('sql','backups','create','--instance='+s.n['sql'],'--description='+description)
 backups=json.loads(s.call('sql','backups','list','--instance='+s.n['sql'],'--format=json'))
 backup=next(b for b in backups if b.get('description')==description and b['status']=='SUCCESSFUL');r['backup_id']=backup['id'];save();print('Successful backup '+str(backup['id']),flush=True)
elif action=='publish':
 guard();assert r.get('backup_id')
 actual=json.loads(s.runner.run([*config['docker'],'image','inspect',proof['local_image']]))[0];assert actual['Id']==proof['image_id']
 registry=config['region']+'-docker.pkg.dev';tag=registry+'/'+config['project']+'/'+s.n['repo']+'/backend:menu-read-'+proof['image_id'].split(':')[1][:20]
 token=s.call('auth','print-access-token')
 # Use a temporary WSL Docker configuration; the access token never enters logs.
 temp='/tmp/bmt-menu-read-'+config['owner'][:8]
 s.runner.run([*config['docker'],'--config='+temp,'login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token)
 try:
  s.runner.run([*config['docker'],'tag',proof['local_image'],tag]);s.runner.run([*config['docker'],'--config='+temp,'push',tag])
 finally:
  subprocess.run([*config['docker'][:-1],'python3','-c',"from pathlib import Path;p=Path("+repr(temp)+")/'config.json';p.unlink(missing_ok=True)"],capture_output=True,check=True)
 data=json.loads(s.call('artifacts','docker','images','describe',tag,'--format=json'));summary=data.get('image_summary',data.get('imageSummary',{}));r['image']=tag.rsplit(':',1)[0]+'@'+summary['digest'];save();print('Published '+r['image'],flush=True)
elif action=='migrate':
 guard();assert r.get('backup_id');update('job',s.n['migrate']);s.call('run','jobs','execute',s.n['migrate'],'--region='+config['region'],'--wait');r['migrated']=True;save();print('Migration succeeded',flush=True)
elif action=='warm':
 assert r.get('migrated')
 code="import time;from sqlalchemy import select,func;from bmt_backend.app import create_app;from bmt_backend.histogram_snapshots import refresh_one;from bmt_backend.track_models import HistogramSnapshot,TrackVersion;a=create_app();count=0\nwhile count<2000 and refresh_one(a):count+=1\nstarted=time.monotonic();pending=1;last=-30\nwhile pending and time.monotonic()-started<780:\n with a.state.session_factory() as db:pending=db.scalar(select(func.count()).select_from(HistogramSnapshot).join(TrackVersion,TrackVersion.id==HistogramSnapshot.version_id).where(TrackVersion.state=='published',(HistogramSnapshot.generation=='')|HistogramSnapshot.invalidated))\n if time.monotonic()-started-last>=30:print('HISTOGRAM_PENDING',pending,flush=True);last=time.monotonic()-started\n if pending:time.sleep(2)\nassert pending==0,pending\nprint('HISTOGRAM_WARMED',count,flush=True);a.state.engine.dispose();a.state.verifier.close()"
 s.call('run','jobs','execute',s.n['migrate'],'--region='+config['region'],'--wait','--task-timeout=900s','--args=^~^-c~'+code)
 r['warmed']=True;save();print('Initial histogram snapshots ready',flush=True)
elif action=='deploy':
 guard();assert r.get('warmed');update('worker',s.n['worker']);update('api',s.n['api'])
 for name in [s.n['smoke'],'bmt-stg-'+config['owner'][:8]+'-catalog']:update('job',name)
 old=json.loads((s.directory/'deployment.json').read_text());stage.write_json(e/'deployment-before.json',old);stage.write_json(s.directory/'deployment.json',{**old,'image':r['image']})
 pp=s.directory/'test-population.json'
 if pp.exists():stage.write_json(pp,{**json.loads(pp.read_text()),'image':r['image']})
 r['deployed']=True;save();print('Development API and worker deployed',flush=True)
elif action=='smoke':
 assert r.get('deployed');guard();output=s.call('run','jobs','execute',s.n['smoke'],'--region='+config['region'],'--wait');(ROOT/'build/menu-speed/deployment/smoke.log').write_text(output);r['smoke_passed']=True;save();print('Native/storage/schema smoke passed',flush=True)
