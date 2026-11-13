import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
FROZEN=WORK/'frozen'
FW=FROZEN/'build/garage-simple-models-2026-11-07'
EV=ROOT/'docs/evidence/garage-simple-models-2026-11-07'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,data):path.write_bytes((json.dumps(data,indent=2,ensure_ascii=False)+'\n').encode())
results={}
for folder,labels in [(WORK,['entry','cache','wash-simple-final','wash-standard-final','translations','accepted-live']),
                      (FW,['accepted-gl','accepted-mobile'])]:
    for label in labels:
        receipt=read(folder/(label+'-receipt.json'));assert receipt['exit_code']==0,label
        matches=re.findall(r'(\d+) checks, (\d+) failures',(folder/(label+'.log')).read_text(encoding='utf-8'))
        checks,failures=map(int,matches[-1]);assert failures==0,label
        results[label]={'checks':checks,'failures':failures}
pipeline=FW/'frozen-assets-final'
assert read(FW/'frozen-assets-final-receipt.json')['exit_code']==0
source=read(pipeline/'source-receipt.json');assert not source['changed']
assert all(digest(FROZEN/rel)==value for rel,value in source['after'].items())
freeze=read(WORK/'freeze-receipt.json')
generated={'game/core/build_identity.gd','game/assets/garage/previews_v1/provenance.json','game/project.godot'}
assert all(digest(FROZEN/rel)==value for rel,value in freeze['source_sha256'].items() if rel not in generated)
live_changes=[rel for rel,value in freeze['source_sha256'].items() if rel not in generated and (ROOT/rel).is_file() and digest(ROOT/rel)!=value]
summary={'requirements':['GSM01','GSM02','GSM03','GSM04'],'checks':results,
         'frozen_assets':{'resources':468,'checks':1925,'failures':0,'pictures':5,'source_hashes':157,'changed_inputs':source['changed']},
         'live_source_changes_after_seal':live_changes,'frozen_artifacts_adopted_into_live_project':False,
         'reason_not_adopted':'Concurrent sources and generated assets are preserved; no frozen output overwrites them.',
         'device_test_performed':False,'apk_exported':False,'owner_data_used':False,'backend_request_performed':False}
reports={label:read(EV/label/'report.json') for label in ['accepted-gl','accepted-mobile','accepted-live']}
summary['native_cases']={k:len(v['rows']) for k,v in reports.items() if k!='accepted-live'}
write(EV/'summary.json',summary)
for folder in ['commands','frozen-commands','asset-validation','recipes','frozen-inputs']:(EV/folder).mkdir(exist_ok=True)
for folder,target in [(WORK,EV/'commands'),(FW,EV/'frozen-commands')]:
    for path in folder.iterdir():
        if path.is_file() and (path.suffix=='.log' or path.name.endswith('-receipt.json')):shutil.copyfile(path,target/path.name)
for path in pipeline.iterdir():
    if path.is_file():shutil.copyfile(path,EV/'asset-validation'/path.name)
shutil.copyfile(WORK/'freeze-receipt.json',EV/'freeze-receipt.json')
for name in ['run.py','freeze.py','seal.py','repair_assets.py','localize.py','finalize.py']:
    shutil.copyfile(WORK/name,EV/'recipes'/name)
inputs=set(source['after'])|set(live_changes)
for name in ['car_showroom','garage_page','garage_preloader','garage_preview_cache','garage_thumbnail_studio','garage_cleanliness','settings_page']:
    inputs.add('game/ui/'+name+'.gd')
for rel in sorted(inputs):
    if not (FROZEN/rel).is_file():continue
    target=EV/'frozen-inputs'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(FROZEN/rel,target)
write(EV/'frozen-inputs-manifest.json',{rel:digest(FROZEN/rel) for rel in sorted(inputs) if (FROZEN/rel).is_file()})

# The current Garage page also contains another task's deletion. Form this
# task's baseline by removing only our quality routing from the latest file.
rel='game/ui/garage_page.gd';text=(ROOT/rel).read_text(encoding='utf-8')
for token,count in [('\tshowroom.simple_model = bool(records.settings.get("reduced_car_models",false))\n',2),
                    ('\t\tmodel.simple_model = bool(records.settings.get("reduced_car_models",false))\n',1),
                    ('\t\tmodel.apply_model_quality(bool(records.settings.get("reduced_car_models",false)))\n',1),
                    ('\tshowroom.apply_model_quality(bool(records.settings.get("reduced_car_models",false)))\n',1)]:
    assert text.count(token)==count,(token,text.count(token));text=text.replace(token,'')
token='\t_replace_showroom_car()\n\t_show_section("cars")\n\t_update_cards()\n\t_refresh_thumbnails()\n'
assert text.count(token)==1;text=text.replace(token,token.removesuffix('\t_refresh_thumbnails()\n'))
target=WORK/'task-baseline'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(text.encode())

runtime=['game/ui/'+name+'.gd' for name in ['car_showroom','garage_page','garage_preloader','garage_preview_cache','garage_thumbnail_studio','garage_cleanliness','settings_page']]
tests=['game/tests/'+name+'.gd' for name in ['test_garage_simple_models','test_garage_simple_cache','test_garage_wash_surfaces','test_reduced_car_translations']]
catalogues=[str(path.relative_to(ROOT)).replace('\\','/') for path in (ROOT/'game/localization').glob('*.po')]+['game/localization/messages.pot']
write(EV/'owned-paths.json',runtime+tests+catalogues)
changes=[]
for rel in runtime+tests+catalogues:
    baseline=WORK/'task-baseline'/rel
    if not baseline.exists():baseline=EV/'before'/rel
    changes.append({'path':rel,'before_sha256':digest(baseline) if baseline.exists() else None,'after_sha256':digest(ROOT/rel)})
write(EV/'changes.json',changes)

validation=['| Check | Actual result |','|---|---|']
for label,title in [('accepted-live','Latest integrated App / all-five Garage controls'),('accepted-gl','Frozen native Compatibility'),('accepted-mobile','Frozen desktop Mobile'),('cache','Cache quality isolation / specialized renderer'),('wash-simple-final','Reduced washing / underside / missed panels'),('wash-standard-final','Standard washing retained'),('translations','Project-loaded description translations'),('entry','Driving baseline / pinned entry point')]:
    item=results[label];validation.append(f"| {title} | {item['checks']} checks / {item['failures']} failures |")
validation.append('| Frozen prepared assets / photograph provenance | 468 resources; 1925/0; five pictures / 157 source hashes |')
asset_text=('The frozen library passes all 468-resource / 1,925 checks and five-picture / 157-source provenance checks with zero source changes during or after baking. '
            'The final native qualification uses that library. Matching live files were not substituted: later concurrent project, workshop, build and other source changes remain in the working tree. '
            'Frozen binaries and photograph provenance therefore stay separate, and this task provides a source-only review patch rather than claiming the entire live workspace is export-ready. '
            'A later integrated live-source App check passes all '+str(results['accepted-live']['checks'])+' checks. Exact qualified source versions are retained in `frozen-inputs/`; the complete isolated copy remains under `build/garage-simple-models-2026-11-07/frozen/`.')
report=ROOT/'docs/GARAGE_SIMPLE_MODELS_2026_11_07.md';text=report.read_text(encoding='utf-8')
text=text.replace('{{VALIDATION}}','\n'.join(validation)).replace('{{ASSETS}}',asset_text)
report.write_bytes(text.encode())
print(json.dumps({'checks':results,'frozen_asset_checks':1925,'native_images':80,'concurrent_live_sources_preserved':len(live_changes)},indent=2))
