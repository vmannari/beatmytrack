from pathlib import Path
import hashlib, importlib.util, json, re

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def log(name):
    data=(OUT/(name+'.log')).read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
def catalog(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.OPTIONS

def main():
    patterns={'construction':r'FORKLIFT_KIT_CONSTRUCTION: (\d+) checks, (\d+) failures',
        'options':r'FORKLIFT_KITS: (\d+) checks, (\d+) failures',
        'original':r'FORKLIFT_ORIGINAL_CABIN: (\d+) checks, (\d+) failures',
        'retained-decks':r'FORKLIFT_COVER_DECKS: (\d+) checks, (\d+) failures',
        'prepared':r'MODULAR_CAR_ASSETS: (\d+) checks, (\d+) failures',
        'garage-gl':r'FORKLIFT_GARAGE: (\d+) checks, (\d+) failures',
        'garage-mobile':r'FORKLIFT_GARAGE: (\d+) checks, (\d+) failures'}
    checks={}
    for name,pattern in patterns.items():
        text=log(name)
        assert not any(marker in text for marker in ['SCRIPT ERROR','FAIL:','ERROR:']),name
        match=re.search(pattern,text)
        assert match and int(match[2])==0,name
        checks[name]={'checks':int(match[1]),'failures':int(match[2])}
    for name in ['bake-bases','bake-kits','bake-garage','capture','detail','before-capture']:
        assert not any(m in log(name) for m in ['SCRIPT ERROR','FAIL:','ERROR:']),name
    assert 'MODULAR_KIT_BAKE_COUNT 104' in log('bake-kits')
    assert 'FORKLIFT_KIT_REVIEW: 28 captures' in log('detail')
    assert 'FORKLIFT_KIT_REVIEW: 56 captures' in log('capture')
    before=(OUT/'before/game/vehicle/forklift_kits.gd').read_text()
    current=(ROOT/'game/vehicle/forklift_kits.gd').read_text()
    assert before[:before.index('static func _hood(')]==current[:current.index('static func _cover_louvres(')]
    assert before[before.index('static func _curve('):]==current[current.index('static func _curve('):]
    before=(OUT/'before/game/vehicle/forklift_kit_surface.gd').read_text()
    current=(ROOT/'game/vehicle/forklift_kit_surface.gd').read_text()
    assert before[:before.index('static func _lid_height(')]==current[:current.index('static func _lid_height(')]
    assert before[before.index('static func wheel_face('):]==current[current.index('static func wheel_face('):]
    a=catalog(ROOT/'scripts/update_forklift_cabin_catalog.py','current_catalog')
    b=catalog(OUT/'before/scripts/update_forklift_cabin_catalog.py','before_catalog')
    for category in a:
        assert [r[0] for r in a[category]]==[r[0] for r in b[category]]
        assert a[category][0]==b[category][0]
        if category in ['body','rims']: assert a[category]==b[category]
    old=(OUT/'before/game/vehicle/vehicle_customisation.gd').read_text()
    new=(ROOT/'game/vehicle/vehicle_customisation.gd').read_text()
    assert old[:old.index('const FORKLIFT_LABELS:')]==new[:new.index('const FORKLIFT_LABELS:')]
    assert old[old.index('const HOVER_LABELS:'):]==new[new.index('const HOVER_LABELS:'):]
    for name in ['game/vehicle/forklift_model.gd','backend/bmt_backend/vehicle_appearance_catalog.json']:
        assert (ROOT/name).read_bytes()==(OUT/'before'/name).read_bytes(),name
    images={}
    for folder,count in [('before-native',56),('native',56),('detail',28),('garage-gl',56),('garage-mobile',56)]:
        paths=list((OUT/folder).glob('*.png'))
        assert len(paths)==count,(folder,len(paths))
        images[folder]={p.name:sha(p) for p in paths}
    assets=list((ROOT/'game/assets/vehicles/modular_kits_v1/forklift').rglob('*.scn'))
    assert len(assets)==104
    assets+=list((ROOT/'game/assets/vehicles/modular_car_bases_v1').glob('forklift_*.scn'))
    assets+=[ROOT/'game/assets/garage/cars_v1/forklift.scn']
    assert len(assets)==109
    paths=['game/vehicle/forklift_kits.gd','game/vehicle/forklift_kit_surface.gd',
        'game/vehicle/forklift_model.gd','game/vehicle/vehicle_customisation.gd',
        'scripts/update_forklift_cabin_catalog.py','game/tests/test_forklift_cover_decks.gd',
        'game/tests/capture_forklift_kit_refinement.gd','scripts/run_forklift_cover_guard.ps1']
    construction=json.loads((OUT/'construction.json').read_text())
    report={'date':'2026-11-03','checks':checks,'native_captures':252,'images':images,
        'maximum_triangles':{c:max(v['triangles'] for k,v in construction['assemblies'].items() if k.startswith(c+'/')) for c in ['hood','aero','body','rims']},
        'sources':{p:sha(ROOT/p) for p in paths},
        'assets':{p.relative_to(ROOT).as_posix():sha(p) for p in assets},
        'cabin_and_wheel_builders_byte_exact':True,'default_roof_buffers_exact':True,
        'factory_model_and_backend_catalogue_byte_exact':True,'all_item_ids_preserved':True,
        'initial_findings':['Two guard buffers slightly beyond unchanged depth envelope; moved inward',
            'First visual pass fin strips/flute contrast corrected; original images retained'],
        'limits':['Reload and owner appearance acceptance remain','No phone/device test or performance claim',
            'No owner-save/process change, live/backend mutation, deployment or main-index write']}
    checkpoint=OUT/'checkpoint.json'
    if checkpoint.exists(): report['checkpoint']=json.loads(checkpoint.read_text())
    (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Verified all logs, 252 native views, 109 prepared assets and preserved cabin/wheel/ID boundaries')

if __name__=='__main__': main()
