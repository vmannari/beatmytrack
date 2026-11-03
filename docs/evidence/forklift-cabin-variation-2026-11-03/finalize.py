from pathlib import Path
import hashlib, importlib.util, json, re, shutil

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

def preserve_raw():
    folder=OUT/'raw-cabin'
    folder.mkdir(exist_ok=True)
    for source in (OUT/'native').glob('body-*.png'):
        target=folder/source.name
        assert not target.exists(),target
        shutil.copy2(source,target)
    assert len(list(folder.glob('*.png')))==14
    print('Preserved fourteen exploratory source renders')

def main():
    patterns={'construction':r'FORKLIFT_KIT_CONSTRUCTION: (\d+) checks, (\d+) failures',
        'options':r'FORKLIFT_KITS: (\d+) checks, (\d+) failures',
        'original':r'FORKLIFT_ORIGINAL_CABIN: (\d+) checks, (\d+) failures',
        'prepared':r'MODULAR_CAR_ASSETS: (\d+) checks, (\d+) failures',
        'garage-gl':r'FORKLIFT_GARAGE: (\d+) checks, (\d+) failures',
        'garage-mobile':r'FORKLIFT_GARAGE: (\d+) checks, (\d+) failures'}
    results={}
    for name,pattern in patterns.items():
        text=log(name)
        assert not any(marker in text for marker in ['SCRIPT ERROR','FAIL:','ERROR:']),name
        match=re.search(pattern,text)
        assert match and int(match[2])==0,name
        results[name]={'checks':int(match[1]),'failures':int(match[2])}
    for name in ['bake-bases','bake-kits','bake-garage','views']:
        text=log(name)
        assert not any(marker in text for marker in ['SCRIPT ERROR','FAIL:','ERROR:']),name
    assert 'MODULAR_KIT_BAKE_COUNT 104' in log('bake-kits')
    assert 'FORKLIFT_CABIN_VIEWS: 42 captures' in log('views')
    source=(ROOT/'game/vehicle/forklift_kits.gd').read_text()
    before=(OUT/'before/game/vehicle/forklift_kits.gd').read_text()
    assert source[:source.index('static func _curve(')]==before[:before.index('static func _portal(')]
    assert source[source.index('static func _wheels('):]==before[before.index('static func _wheels('):]
    a=catalog(ROOT/'scripts/update_forklift_cabin_catalog.py','current_catalog')
    b=catalog(OUT/'before/scripts/update_forklift_cabin_catalog.py','before_catalog')
    for category in a:
        assert [r[0] for r in a[category]]==[r[0] for r in b[category]]
        if category!='body': assert a[category]==b[category]
    old=(OUT/'before/game/vehicle/vehicle_customisation.gd').read_text()
    new=(ROOT/'game/vehicle/vehicle_customisation.gd').read_text()
    assert old[:old.index('const FORKLIFT_LABELS:')]==new[:new.index('const FORKLIFT_LABELS:')]
    assert old[old.index('const HOVER_LABELS:'):]==new[new.index('const HOVER_LABELS:'):]
    backend=ROOT/'backend/bmt_backend/vehicle_appearance_catalog.json'
    assert backend.read_bytes()==(OUT/'before/backend/bmt_backend/vehicle_appearance_catalog.json').read_bytes()
    assert backend.read_bytes()==(ROOT/'docs/evidence/forklift-kit-refinement-2026-11-02/before/backend/bmt_backend/vehicle_appearance_catalog.json').read_bytes()
    images={}
    for folder,pattern,expected in [('native','body-*.png',14),('front','*.png',14),('side','*.png',14),('garage-gl','*.png',56),('garage-mobile','*.png',56)]:
        paths=list((OUT/folder).glob(pattern))
        assert len(paths)==expected,(folder,len(paths))
        images[folder]={p.name:sha(p) for p in paths}
    assets=list((ROOT/'game/assets/vehicles/modular_kits_v1/forklift').rglob('*.scn'))
    assert len(assets)==104
    assets+=list((ROOT/'game/assets/vehicles/modular_car_bases_v1').glob('forklift_*.scn'))
    assets+=[ROOT/'game/assets/garage/cars_v1/forklift.scn']
    assert len(assets)==109
    paths=['game/vehicle/forklift_kits.gd','game/vehicle/forklift_kit_surface.gd',
        'game/vehicle/forklift_model.gd','game/vehicle/vehicle_customisation.gd',
        'scripts/update_forklift_cabin_catalog.py','game/tests/test_forklift_kit_construction.gd',
        'game/tests/capture_forklift_cabin_variation.gd','scripts/run_forklift_cabin_variation.ps1']
    result={'date':'2026-11-03','checks':results,'final_native_captures':154,
        'images':images,'assets':{p.relative_to(ROOT).as_posix():sha(p) for p in assets},
        'sources':{p:sha(ROOT/p) for p in paths},'server_catalogue_byte_exact':True,
        'other_kit_builders_exact':True,'all_item_ids_preserved':True,
        'initial_failure':'Four heavy-frame portal edge-fold failures; increase bend radius, no gate relaxed',
        'limits':['Reload and owner appearance acceptance remain','No physical device test or performance claim',
            'No owner-save/process change, backend/live access, deployment or main-index write']}
    checkpoint=OUT/'checkpoint.json'
    if checkpoint.exists(): result['checkpoint']=json.loads(checkpoint.read_text())
    (OUT/'report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('Validated 154 final native captures, 109 prepared assets, all logs and preserved source/ID boundaries')

if __name__=='__main__':
    import sys
    preserve_raw() if '--preserve-raw' in sys.argv else main()
