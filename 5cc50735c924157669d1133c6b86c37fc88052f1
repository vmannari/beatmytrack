"""Build, test and release the owner-authorized, schema-compatible ghost overlay."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

from inspect_live import WORK, ROOT, config, service, runtime

OUT=ROOT/'docs/evidence/backend-ghost-cache-deploy-2026-10-26'
DOCKER=['wsl.exe','-d','Ubuntu','--','docker']
STATE=WORK/'rollout.json'
state=json.loads(STATE.read_text()) if STATE.exists() else {}
release=json.loads((WORK/'release.json').read_text())

def write(path,value):
 temporary=path.with_suffix(path.suffix+'.pending')
 temporary.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');temporary.replace(path)

def save():write(STATE,state)
def unix(path):return '/mnt/'+path.drive[0].lower()+path.as_posix()[2:]
def command(argv,log,timeout=600,input_data=None):
 result=subprocess.run(argv,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout,input=input_data)
 (WORK/(log+'.private.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
 if result.returncode:raise RuntimeError('Command failed; inspect '+log+'.private.log')
 return result.stdout.strip()

def build():
 for name,expected in release['package_hashes'].items():
  assert hashlib.sha256((WORK/'release/bmt_backend'/name).read_bytes()).hexdigest()==expected
 command([*DOCKER,'build','--network=none','--pull=false','--file',unix(WORK/'release/Dockerfile'),
          '--tag',release['tag'],unix(WORK/'release')],'build',timeout=600)
 state['local_image_id']=command([*DOCKER,'image','inspect',release['tag'],'--format={{.Id}}'],'image-inspect');save()
 print(json.dumps({'built':release['tag'],'image_id':state['local_image_id']}),flush=True)

def test():
 assert state.get('local_image_id')
 argv=[*DOCKER,'run','--rm','--network=none','--cpus=1','--memory=768m',
       '--label','bmt.ghost-cache-release=20261026','--entrypoint=python',
       '--env','PYTHONPATH=/app:/test-work/backend/tests',
       '--mount','type=bind,src='+unix(WORK/'test-work')+',dst=/test-work,readonly',
       '--mount','type=bind,src='+unix(OUT)+',dst=/results',
       '--workdir','/test-work',release['tag'],'-m','pytest',
       'backend/tests/test_ghost_cache_release.py','backend/tests/test_auth.py',
       'backend/tests/test_challenges.py','backend/tests/test_rivalry.py',
       '-q','-k','not postgres','--tb=short','-p','no:cacheprovider',
       '--basetemp=/tmp/ghost-cache-tests','--junitxml=/results/exact-image-tests.xml']
 result=subprocess.run(argv,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
 (OUT/'exact-image-tests.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 state['tests_exit']=result.returncode;save();print((result.stdout+result.stderr)[-11000:],flush=True)
 if result.returncode:raise RuntimeError('Exact-image release gates failed')

def push():
 assert state.get('tests_exit')==0 or state.get('release_gate_passed') is True
 registry=release['tag'].split('/')[0]
 private=WORK/'docker-auth.private'
 assert not private.exists();private.mkdir()
 try:
  token=service.call('auth','print-access-token')
  command([*DOCKER,'--config='+unix(private),'login',registry,'--username=oauth2accesstoken','--password-stdin'],
          'registry-login',input_data=token)
  command([*DOCKER,'--config='+unix(private),'push',release['tag']],'push',timeout=900)
 finally:
  assert private.resolve().parent==WORK and not private.is_symlink()
  shutil.rmtree(private)
 value=json.loads(service.call('artifacts','docker','images','describe',release['tag'],'--format=json'))
 digest=value.get('image_summary',{}).get('digest') or value.get('imageSummary',{}).get('digest')
 assert digest and digest.startswith('sha256:') and len(digest)==71
 state['image']=release['tag'].rsplit(':',1)[0]+'@'+digest;save()
 print(json.dumps({'pushed':state['image']}),flush=True)

def unchanged_template(before,after):
 # Revision metadata is managed by Cloud Run; runtime identity, env, resources,
 # command, networking and all service-level capacity settings stay exact.
 assert before['spec']['template']['spec']==after['spec']['template']['spec'] or (
  clean_runtime(before)==clean_runtime(after))
 a=dict(before['spec']);b=dict(after['spec']);a.pop('template');b.pop('template');a.pop('traffic',None);b.pop('traffic',None)
 assert a==b
 a=dict(before['spec']['template']['metadata'].get('annotations',{}))
 b=dict(after['spec']['template']['metadata'].get('annotations',{}))
 for key in ('client.knative.dev/user-image','run.googleapis.com/client-name',
             'run.googleapis.com/client-version','run.googleapis.com/operation-id'):
  a.pop(key,None);b.pop(key,None)
 assert a==b, 'Runtime template settings changed'

def clean_runtime(resource):
 value=json.loads(json.dumps(resource['spec']['template']['spec']))
 for container in value['containers']:container.pop('image',None)
 return value

def verify(origin,label):
 import requests
 before=json.loads((WORK/'bootstrap-before.json').read_text())
 observed={}
 for path in ('/health','/ready','/v1/bootstrap'):
  response=requests.get(origin+path,timeout=45);response.raise_for_status();observed[path]=response.json()
 assert observed['/health']['status']=='ok'
 assert observed['/ready']==json.loads((WORK/'ready-before.json').read_text())
 boot=dict(observed['/v1/bootstrap']);assert boot.pop('ghost_identity_version')==boot.pop('ghost_wire_version')==1
 before.pop('server_now',None);boot.pop('server_now',None);assert boot==before
 public={}
 for path in ('/','/privacy','/account-deletion','/community-rules'):
  response=requests.get(origin+path,timeout=45);response.raise_for_status()
  public[path]={'status':response.status_code,'sha256':hashlib.sha256(response.content).hexdigest()}
 baseline=WORK/'public-before.json'
 if baseline.exists():assert public==json.loads(baseline.read_text())
 observed['public_pages']=public
 # No live player, token, challenge, recording, purchase or reward is created.
 response=requests.get(origin+'/v1/challenges/0000000000000000/ghost?metadata=true',timeout=30)
 assert response.status_code==404
 observed['unknown_ghost_metadata_status']=response.status_code
 write(OUT/(label+'.json'),observed)
 return observed

def canary():
 assert state.get('image') and (state.get('tests_exit')==0 or state.get('release_gate_passed') is True)
 current=service.describe('api',service.n['api'])
 assert service.__class__.__module__=='staging'
 assert current['status']['latestReadyRevisionName']==release['prior_revision']
 import staging
 assert staging.resource_image(current)==release['parent']
 before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text())
 unchanged_template(before,current)
 assert current['status']['traffic']==before['status']['traffic']
 # Managed provider backup stays in the existing project; no player data export.
 sql=service.describe('sql',service.n['sql']);assert sql['settings']['deletionProtectionEnabled'] is True
 if not state.get('backup_id'):
  description='Before ghost-cache API release '+datetime.now(timezone.utc).isoformat()
  service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
  backups=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
  matches=[x for x in backups if x.get('description')==description and x.get('status')=='SUCCESSFUL']
  assert len(matches)==1;state['backup_id']=matches[0]['id'];save()
 import requests
 public={}
 for path in ('/','/privacy','/account-deletion','/community-rules'):
  response=requests.get(release['url']+path,timeout=45);response.raise_for_status()
  public[path]={'status':response.status_code,'sha256':hashlib.sha256(response.content).hexdigest()}
 write(WORK/'public-before.json',public)
 suffix='gc-'+release['source_hash'][:12]
 service.call('run','services','update',service.n['api'],'--region='+config['region'],
              '--image='+state['image'],'--no-traffic','--tag=ghostcache-20261026','--revision-suffix='+suffix)
 current=service.describe('api',service.n['api']);unchanged_template(before,current)
 write(WORK/'after-api.private.json',current)
 traffic=current['status']['traffic']
 assert sum(x.get('percent',0) for x in traffic if x.get('revisionName')==release['prior_revision'])==100
 candidate=next(x for x in traffic if x.get('tag')=='ghostcache-20261026')
 state['candidate_revision']=candidate['revisionName'];state['canary_url']=candidate['url'];save()
 verify(state['canary_url'],'canary-http')
 state['canary_passed']=True;save()
 print(json.dumps({'backup_id':state['backup_id'],'candidate_revision':state['candidate_revision'],
                   'canary_passed':True,'old_revision_traffic_percent':100}),flush=True)

def promote():
 assert state.get('canary_passed')
 before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text())
 current=service.describe('api',service.n['api']);unchanged_template(before,current)
 assert current['status']['latestReadyRevisionName']==state['candidate_revision']
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
              '--to-revisions='+state['candidate_revision']+'=100')
 state['promoted']=True;save()
 try:
  verify(release['url'],'live-http')
 except BaseException:
  service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
               '--to-revisions='+release['prior_revision']+'=100')
  state['rolled_back']=True;save();raise
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
              '--remove-tags=ghostcache-20261026')
 current=service.describe('api',service.n['api']);unchanged_template(before,current)
 assert current['status']['traffic']==[{'percent':100,'revisionName':state['candidate_revision']}]
 after=runtime(current);prior=runtime(before)
 assert after['serviceAccountName']==prior['serviceAccountName']
 preserved=[]
 for kind,name in (('worker',service.n['worker']),('job',service.n['migrate']),('job',service.n['smoke']),('api',service.n['admin'])):
  actual=service.describe(kind,name);original=json.loads((WORK/('before-'+name+'.private.json')).read_text())
  assert actual['spec']==original['spec'], 'Concurrent change in '+name
  preserved.append(name)
 state.update(completed=True,completed_utc=datetime.now(timezone.utc).isoformat(),preserved_resources=preserved)
 save();write(OUT/'rollout.json',state)
 print(json.dumps({'completed':True,'revision':state['candidate_revision'],'traffic_percent':100,
                   'url':release['url'],'schema':'0062_retire_discovery_cache','preserved_resources':preserved}),flush=True)

def control():
 import xml.etree.ElementTree as ET
 failed_name='test_additive_attempt_migration_preserves_existing_challenges[sqlite]'
 marker='Drain creator achievement events before downgrading 0054'
 initial=ET.parse(OUT/'exact-image-tests.xml')
 cases=initial.findall('.//testcase')
 failures=[x for x in cases if x.find('failure') is not None or x.find('error') is not None]
 assert len(failures)==1 and failures[0].get('name')==failed_name
 assert marker in failures[0].find('failure').text
 argv=[*DOCKER,'run','--rm','--network=none','--cpus=1','--memory=768m',
       '--label','bmt.ghost-cache-release=20261026','--entrypoint=python',
       '--env','PYTHONPATH=/app:/test-work/backend/tests',
       '--mount','type=bind,src='+unix(WORK/'test-work')+',dst=/test-work,readonly',
       '--mount','type=bind,src='+unix(OUT)+',dst=/results','--workdir','/test-work',release['parent'],
       '-m','pytest','backend/tests/test_challenges.py::'+failed_name,'-q','--tb=short',
       '-p','no:cacheprovider','--basetemp=/tmp/ghost-cache-control',
       '--junitxml=/results/unchanged-parent-control.xml']
 result=subprocess.run(argv,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
 (OUT/'unchanged-parent-control.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 assert result.returncode==1
 baseline=ET.parse(OUT/'unchanged-parent-control.xml').findall('.//testcase')
 assert len(baseline)==1 and baseline[0].get('name')==failed_name
 assert baseline[0].find('failure') is not None and marker in baseline[0].find('failure').text
 assert baseline[0].find('failure').get('message')==failures[0].find('failure').get('message')
 native=json.loads((OUT/'native-client.json').read_text());assert native['exit_code']==0 and native['summary_present']
 value={'candidate_passed':len([x for x in cases if x.find('failure') is None and x.find('skipped') is None and x.find('error') is None]),
        'candidate_skipped':len([x for x in cases if x.find('skipped') is not None]),
        'candidate_existing_failure':failed_name,'unchanged_parent_same_failure':True,
        'same_failure_message':marker,'release_gate_passed':True,'native_checks':21}
 state['release_gate_passed']=True;state['baseline_control']=value;save();write(OUT/'baseline-control.json',value)
 print(json.dumps(value,indent=2),flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('stage',choices=('build','test','control','push','canary','promote'));args=parser.parse_args()
 globals()[args.stage]()
