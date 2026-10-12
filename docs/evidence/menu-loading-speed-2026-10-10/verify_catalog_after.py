import importlib.util,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];private=ROOT/'.tools/gcp-staging';e=ROOT/'docs/evidence/menu-loading-speed-2026-10-10'
os.environ['REQUESTS_CA_BUNDLE']=str(private/'windows-trust.pem');os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(private/'windows-trust.pem')
spec=importlib.util.spec_from_file_location('stage',ROOT/'backend/deploy/gcp/staging.py');stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)
c=json.loads((private/'config.json').read_text());s=stage.Staging(c,private/('rendered-'+c['owner']));r=json.loads((e/'deployment.json').read_text())
for kind in ('api','worker'):assert stage.resource_image(s.describe(kind,s.n[kind]))==r['image']
url=json.loads((s.directory/'deployment.json').read_text())['url'];key=s.call('secrets','versions','access','1','--secret='+c['test_drivers_secret'])
sys.path.insert(0,str(ROOT/'backend'));from bmt_backend.test_population_tool import API
api=API(url,key);profile=json.loads((ROOT/'build/cloud-histograms-200-2026-10-06.json').read_text())['profiles'][0]
login=api.call('POST','/auth/development',{'subject':profile['subject'],'display_name':profile['display_name']},operator=True);api.http.headers['Authorization']='Bearer '+login['access_token']
ready=api.http.get(url+'/ready',timeout=30);ready.raise_for_status();assert ready.json()['schema']=='0023_operational_read_indexes'
tracks=api.call('GET','/dev/test-drivers/tracks?vehicle_id=compact',operator=True)['tracks'];checks=[]
for track in tracks:
 path='/track-versions/'+track['version_id']+'/results-comparison?vehicle_id=compact&bins=16'
 packet=api.call('GET',path);assert packet['population_scope']=='all'
 for metric in ('race','best_lap'):
  field=packet[metric];assert field['board_id']==packet['board_id'] and field['metric']==metric
  assert sum(b['count'] for b in field['bins'])==field['population'];assert len(field['bins'])<=16
 pinned=path
 for metric,prefix in [('race','race'),('best_lap','lap')]:
  bins=packet[metric]['bins']
  if bins:pinned+='&'+prefix+'_from_ticks='+str(bins[0]['from_ticks'])+'&'+prefix+'_to_ticks='+str(bins[-1]['to_ticks_exclusive'])
 frame=api.call('GET',pinned)
 for metric in ('race','best_lap'):assert frame[metric]['bins']==packet[metric]['bins']
 checks.append({'track':track['name'],'race_population':packet['race']['population'],'lap_population':packet['best_lap']['population'],'passed':True})
 if track['name'].casefold()=='underpass':
  (e/'live-underpass-deployed.json').write_text(json.dumps({'packet':packet,'comparison_status':200,'track':'Underpass'},indent=2)+'\n')
  private_board=api.call('GET','/dev/test-drivers/track-versions/'+track['version_id']+'/histogram?vehicle_id=compact&bins=16')
  rejected=api.http.get(url+'/v1/boards/'+private_board['board_id']+'/histogram',timeout=30);assert rejected.status_code==404
report={'image':r['image'],'ready':ready.json(),'tracks':checks,'public_private_board_status':404,'races_submitted':0,'player_records_changed':False}
(e/'live-catalog-deployed.json').write_text(json.dumps(report,indent=2)+'\n');print('Live stored comparisons, counts and retained frames pass on '+str(len(checks))+' tracks; private board returns 404.',flush=True)
