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

OUT=ROOT/'docs/evidence/backend-reuse-fixes-2026-10-26'
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
       '--label','bmt.backend-reuse-release=20261026','--entrypoint=python',
       '--env','PYTHONPATH=/app:/test-work/backend/tests',
       '--mount','type=bind,src='+unix(WORK/'test-work')+',dst=/test-work,readonly',
       '--mount','type=bind,src='+unix(OUT)+',dst=/results',
       '--workdir','/test-work',release['tag'],'-m','pytest',
       'backend/tests/test_ghost_cache_release.py','backend/tests/test_auth.py',
       'backend/tests/test_backend_reuse.py',
       'backend/tests/test_challenges.py','backend/tests/test_rivalry.py',
       '-q','-k','not postgres and not additive_attempt_migration','--tb=short','-p','no:cacheprovider',
       '--basetemp=/tmp/ghost-cache-tests','--junitxml=/results/exact-image-tests.xml']
 result=subprocess.run(argv,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
 (OUT/'exact-image-tests.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 state['tests_exit']=result.returncode;save();print((result.stdout+result.stderr)[-11000:],flush=True)
 if result.returncode:raise RuntimeError('Exact-image release gates failed')

def push():
 assert state.get('tests_exit')==0
 assert json.loads((OUT/'postgres-gate.json').read_text())['exit_code']==0
 assert json.loads((OUT/'postgres-gate.json').read_text())['owned_fixture_removed'] is True
 assert json.loads((OUT/'native-completion.json').read_text())['no_reward_or_wallet_followup_requests'] is True
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
 boot=dict(observed['/v1/bootstrap'])
 for capability in release['new_capabilities']:assert boot.pop(capability)==1
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

def verify_previews(origin,label):
 import requests
 path=origin+'/v1/discovery/v3/tracks'
 cold=requests.post(path,json={'query':{'sort':'name'},'preview_cache':True,'known_previews':[]},timeout=45)
 cold.raise_for_status();first=cold.json();assert first['items']
 assert all('points' in item and 'preview_hash' in item for item in first['items'])
 hints=list({item['preview_hash'] for item in first['items']})
 body={'cursor':first['page_cursor'],'preview_cache':True,'known_previews':hints}
 response=requests.post(path,json=body,timeout=45);response.raise_for_status();warm=response.json()
 assert [item['version_id'] for item in warm['items']]==[item['version_id'] for item in first['items']]
 assert all('points' not in item for item in warm['items'])
 body['known_previews']=[]
 fallback=requests.post(path,json=body,timeout=45);fallback.raise_for_status()
 assert all('points' in item for item in fallback.json()['items'])
 protected=requests.get(origin+'/v1/runs/00000000-0000-0000-0000-000000000000?completion=true',timeout=30)
 assert protected.status_code==401
 proof={'items':len(first['items']),'warm_outlines_omitted':True,'missing_cache_fallback':True,
        'same_track_identities':True,'private_completion_unauthenticated_status':protected.status_code,
        'cold_compressed_content_length':cold.headers.get('content-length'),
        'warm_compressed_content_length':response.headers.get('content-length'),
        'live_player_records_created':False,'calls':'Three public discovery queries and one unauthenticated status request. Normal temporary discovery cursors may be created.'}
 write(OUT/(label+'-previews.json'),proof)

def canary():
 assert state.get('image') and state.get('tests_exit')==0
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
  description='Before backend reuse API release '+datetime.now(timezone.utc).isoformat()
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
 suffix='rr-'+release['source_hash'][:12]
 service.call('run','services','update',service.n['api'],'--region='+config['region'],
              '--image='+state['image'],'--no-traffic','--tag=reuse-20261026','--revision-suffix='+suffix)
 current=service.describe('api',service.n['api']);unchanged_template(before,current)
 write(WORK/'after-api.private.json',current)
 traffic=current['status']['traffic']
 assert sum(x.get('percent',0) for x in traffic if x.get('revisionName')==release['prior_revision'])==100
 candidate=next(x for x in traffic if x.get('tag')=='reuse-20261026')
 state['candidate_revision']=candidate['revisionName'];state['canary_url']=candidate['url'];save()
 verify(state['canary_url'],'canary-http')
 verify_previews(state['canary_url'],'canary-http')
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
  verify_previews(release['url'],'live-http')
 except BaseException:
  service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
               '--to-revisions='+release['prior_revision']+'=100')
  state['rolled_back']=True;save();raise
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
              '--remove-tags=reuse-20261026')
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


if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('stage',choices=('build','test','push','canary','promote'));args=parser.parse_args()
 globals()[args.stage]()
