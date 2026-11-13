import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
EV=ROOT/'docs/evidence/asset-review-2026-11-08'
inputs={'cars':'cars/cars.json','catalogue':'catalogue/catalogue.json','worlds_gl':'worlds-gl/worlds.json','worlds_mobile':'worlds-mobile/worlds.json','candidates_gl':'candidates-gl-accepted/candidates.json','candidates_mobile':'candidates-mobile-accepted/candidates.json','exact_positions':'exact-positions.json'}
expected={'cars':48,'catalogue':580,'worlds_gl':30,'worlds_mobile':30,'candidates_gl':52,'candidates_mobile':52,'exact_positions':22}
checks={}
for label,rel in inputs.items():
    data=json.loads((EV/rel).read_text())
    assert data['failures']==0 and data['checks']==expected[label],(label,data['checks'],data['failures'])
    checks[label]={'checks':data['checks'],'failures':data['failures']}
summary={'requirements':['AOR01','AOR02','AOR03','AOR04'],'checks':checks,'total_checks':sum(x['checks'] for x in checks.values()),'total_failures':0,'car_catalogue_ids':6,'distinct_car_chassis':5,'live_car_cases':24,'stored_car_resource_inspections':6,'prop_biome_combinations':290,'complete_world_cases':10,'native_world_views':30,'normal_quality_or_physics_changes':False,'production_runtime_or_asset_changes':False,'device_query_or_test_performed':False,'apk_or_deployment_performed':False,'owner_save_or_process_changed':False,'backend_request_performed':False,'fps_gain_claimed':False}
for renderer in ['gl','mobile']:
    data=json.loads((EV/('candidates-'+renderer+'-accepted')/'candidates.json').read_text())
    for row in data['rows']:
        if row.get('type')=='index_attribute_check':assert row['positions_exact']
        if 'case' in row:assert row['restoration_metrics']['max']==0.0
    summary['native_'+renderer]=[{key:row[key] for key in ['case','view','original_primitives','candidate_primitives','original_unique_raw_buffers','candidate_unique_raw_buffers','image_metrics']} for row in data['rows'] if 'case' in row]
guards=json.loads((EV/'cache-guards.json').read_text())['rows']
summary['prepared_car_source_guard_misses']=[row['vehicle'] for row in guards if row['type']=='car_base' and not row['runtime_sources_match']]
summary['scenery_plan_signature_misses']=[{'kind':row['kind'],'theme':row['theme']} for row in guards if row['type']=='scenery_plan' and not row['accepted_plan']]
initial=json.loads((EV/'initial-index.json').read_text())['sha256']
summary['main_index_unchanged']=hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest()==initial
assert summary['main_index_unchanged']
(EV/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
for p in WORK.glob('*'):
    if p.is_file() and (p.suffix=='.log' or p.name.endswith('-receipt.json')):
        target=EV/'commands'/p.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
    elif p.is_file() and p.suffix in ['.gd','.py','.ps1']:
        target=EV/'recipes'/p.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
manifest={p.relative_to(EV).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in EV.rglob('*') if p.is_file() and p.name not in ['task.patch','checkpoint-receipt.json','artifact-manifest.json']}
(EV/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:value for key,value in summary.items() if not key.startswith('native_')},indent=2))
