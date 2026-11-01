"""Reconcile native results and scope for the wheel/fender correction."""
import hashlib
import json
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
OUT = Path(__file__).resolve().parent

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = read(ROOT/'game/assets/vehicles/electric_sport_fenders_v1/manifest.json')
assert len(manifest['meshes']) == 333
sources = {'game/vehicle/'+name: value for name,value in manifest['sources'].items()}
assert all(digest(ROOT/name)==value for name,value in sources.items())
for renderer in ['final-gl-seated','final-mobile-seated']:
    capture = read(OUT/renderer/'captures.json')
    assert capture['failures']==0 and len(capture['captures'])==9
    assert all(capture['sources'][name]==value for name,value in manifest['sources'].items() if name in capture['sources'])
old = read(OUT/'old-mesh-hashes.json')
assert all(digest(ROOT/name)==value for name,value in old.items())
preserved = {}
for name in ['game/resources/cars/electric.tres','game/vehicle/vehicle_simulation.gd',
             'game/vehicle/handling_config.gd','game/vehicle/electric_car_model.gd',
             'game/vehicle/electric_reference_cabin.gd']:
    preserved[name] = digest(ROOT/name)==digest(OUT/'task-base'/name)
assert all(preserved.values())
paths = [*sorted((ROOT/'game/assets/vehicles/electric_sport_fenders_v1').glob('*'))]
paths += [ROOT/f'game/assets/vehicles/racing_simple_v1/electric_shadow_{i}.res' for i in range(5)]
paths += [ROOT/'game/assets/garage/cars_v1/electric.scn', ROOT/'game/assets/garage/previews_v1/provenance.json']
pictures = [*sorted((ROOT/'game/assets/liveries/previews_v2/electric').glob('*.png'))]
pictures += [ROOT/name for name in ['game/assets/garage/previews_v1/electric.png',
             'game/assets/menu/header_cars_v1/electric.png','game/assets/news/vehicles/electric.png']]
assert len(pictures)==52
paths += pictures
inventory = [{'path':p.relative_to(ROOT).as_posix(),'sha256':digest(p),'bytes':p.stat().st_size} for p in paths if p.is_file()]
(OUT/'assets.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
commands = []
for path in sorted(OUT.glob('*.json')):
    data = read(path)
    if isinstance(data,dict) and 'command' in data:
        commands.append({'name':path.stem,**data,'log':path.stem+'.log'})
(OUT/'commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
geometry = read(OUT/'prepared-final-measurements.json')
assert geometry['checks']==96 and geometry['failures']==0
assert sum(bay['blocked_rays'] for model in geometry['models'] for bay in model['wheelhouses'])==120
parity = read(OUT/'retained-final-measurements.json')
assert parity['checks']==104 and parity['failures']==0 and parity['exact_prepared_meshes']==333
app = next(item for item in commands if item['name']=='app-gl')
assert app['exit_code']==0
assert 'ELECTRIC_REAR_APP: 58 checks, 0 failures' in (OUT/'app-gl.log').read_text(encoding='utf-8')
shadows = read(ROOT/'game/assets/vehicles/racing_simple_v1/manifest.json')['cars']['electric']
report = {
    'requirements':{'VWF01':'front wheels inset 4.4 cm per side',
                    'VWF02':'four formed fenders with up to 4.8 cm projection and rolled returns',
                    'VWF03':'opaque complete wheelhouses and seated undertray'},
    'sources':sources,'task_start_exact':preserved,'previous_mesh_paths_preserved':len(old),
    'geometry':geometry,'negative_control':read(OUT/'control-final-measurements.json'),
    'prepared_meshes_exact':333,'retained_checks':[104,0],
    'functional_checks':{'garage_template':[4,0],'preview_identity':[5,0],'racing':[23,0],'actual_app_compatibility':[58,0]},
    'visible_triangles':{'detailed':118616,'simple':37720,'simple_shadows':sum(frame['triangles'] for frame in shadows)},
    'pictures_rebuilt':52,'native_final_views':{'compatibility':9,'desktop_mobile':9},
    'checkpoint':read(OUT/'checkpoint.json'),'commands':'commands.json','assets':'assets.json',
    'retained_findings':['Initial fixture used unsupported PackedVector3Array.all; fixed with explicit iteration.',
                         'Early low-angle view exposed low undertray edge; moved inside bumper and seating/coverage assertions added.',
                         'Old front-stance assertion updated only for the explicitly requested front wheel inset.',
                         'Windows root-certificate warnings and App frame-hitch logs remain.'],
    'limits':['owner appearance acceptance remains','no phone/device query or test','no phone performance claim',
              'other cars may rebuild their editor Garage templates under shared source guard'],
    'operations':{'owner_save_or_live_mutation':False,'backend_change':False,'deployment':False,
                  'apk':False,'owner_process_restart':False,'main_index_write':False}
}
(OUT/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'sources_exact':True,'old_mesh_paths_exact':len(old),'prepared_meshes':333,
                  'asset_paths':len(inventory),'pictures':52,'commands':len(commands)}))
