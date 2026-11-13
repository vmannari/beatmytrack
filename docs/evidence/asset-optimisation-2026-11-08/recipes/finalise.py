import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
EV = ROOT / 'docs/evidence/asset-optimisation-2026-11-08'
OWNED = ['game/rendering/mesh_vertex_packing.gd','game/vehicle/visual_geometry.gd',
 'game/track/native_track_visual.gd','game/track/winter_scenery.gd',
 'game/track/creator_prop_visual.gd','game/track/prop_geometry.gd',
 'game/track/scenery_mesh_lods.gd','game/tests/test_mesh_vertex_packing.gd',
 'game/tests/test_protected_tree_lods.gd','game/tests/test_scenery_mesh_lods.gd','game/tests/test_modular_car_assets.gd']
RUNS = ['packing-unit-complete','packing-integration-complete','protected-tree-complete',
 'cars-verified-gl','cars-verified-mobile','final-prepared-gl','final-prepared-mobile','scenery-complete-gl',
 'scenery-complete-mobile','worlds-native-gl','worlds-final-mobile','existing-scenery',
 'terrain-regression','road-cache','driving','car-wash','garage-wash-simple-final',
 'race-cache-policy','app-published','final-parser-published','published-preflight-complete','texture-keys-native','live-handles-complete','final-lod-policy']+['final-matrix-'+id for id in ['compact','kart','forklift','electric','hovercraft','super_rally']]
FOLDERS = ['cars-gl_compatibility-verified','cars-mobile-verified','cars-gl_compatibility-prepared-final','cars-mobile-prepared-final',
 'scenery-gl_compatibility-complete','scenery-mobile-complete',
 'worlds-gl_compatibility','worlds-mobile-final']

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))

def main():
    receipts = []
    for label in RUNS:
        path = WORK / (label+'-receipt.json')
        assert path.exists(), 'Still pending: '+label
        result = read(path)
        assert result['exit_code']==0, result
        log = (WORK / (label+'.log')).read_text(encoding='utf-8',errors='replace')
        assert 'SCRIPT ERROR:' not in log and 'Parse Error:' not in log, label
        result['result_lines'] = [line for line in log.splitlines() if re.search(r'(checks|scripts|PREPARED_CAR_PIPELINE)',line)][-3:]
        receipts.append(result)
    proofs = []
    for folder in FOLDERS:
        report = read(EV / folder / 'report.json')
        assert report['failures']==0, folder
        proofs.append({'folder':folder,**report})
    summary = {'requirements':['AOP01','AOP02','AOP03','AOP04'],
      'engine':'4.7.2.stable.official.ed1daf0bf','runs':receipts,
      'native_cases':sum(len(item['rows']) for item in proofs),
      'native_pngs':sum(len(list((EV/folder).glob('*.png'))) for folder in FOLDERS),
      'world_buffers':read(EV/'packing-structural.json'),
      'components':read(EV/'component-bytes.json'),
      'sources':{p:digest(ROOT/p) for p in OWNED},
      'main_index_sha256':digest(ROOT/'.git/index'),'device_tested':False}
    summary['known_matrix_attempt']={'checks':8197,'failures':13,'material_storage_aliases':12,'rollback_default_quality_fixture':1,'corrected_fixture_rerun':'Final six-vehicle matrix passes; actual counts in command receipts.'}
    summary['live_project_qualified']=True
    summary['qualified_publication']=read(EV/'published-assets.json')
    assert summary['main_index_sha256']==read(EV/'initial-index.json')['sha256']
    (EV/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    (EV/'commands.json').write_text(json.dumps(receipts,indent=2)+'\n',encoding='utf-8')
    ids=re.findall(r'"([^"]+)"',re.search(r'const IDS: Array\[String\] = \[([^\]]+)\]',(ROOT/'game/vehicle/vehicle_catalog.gd').read_text(encoding='utf-8')).group(1))
    resources=[]
    for directory in ['game/assets/vehicles/modular_car_bases_v1','game/assets/vehicles/modular_kits_v1','game/assets/garage/cars_v1','game/assets/menu/header_car_templates_v1']:
        for p in (ROOT/directory).rglob('*.scn'):
            if any(p.stem==id or p.stem.startswith(id+'_') or id in p.relative_to(ROOT/directory).parts for id in ids):resources.append(p)
    assert len(resources)==551,len(resources)
    resources+=list((ROOT/'game/assets/scenery_lods_v1').glob('*.res'))
    resources+=list((ROOT/'game/assets/garage/previews_v1').glob('*.png'))
    (EV/'generated-assets.json').write_text(json.dumps({p.relative_to(ROOT).as_posix():{'sha256':digest(p),'bytes':p.stat().st_size} for p in resources},indent=2)+'\n',encoding='utf-8')
    all_receipts = [read(p) for p in sorted(WORK.glob('*-receipt.json'))]
    (EV/'all-attempts.json').write_text(json.dumps(all_receipts,indent=2)+'\n',encoding='utf-8')
    start = read(EV/'source-start.json')
    end = {p:digest(ROOT/p) for p in start if (ROOT/p).exists()}
    (EV/'source-end.json').write_text(json.dumps({'hashes':end,'changed':[p for p in start if start[p]!=end.get(p)],'owned':OWNED},indent=2)+'\n',encoding='utf-8')
    recipes = EV/'recipes';recipes.mkdir(exist_ok=True)
    for p in WORK.iterdir():
        if p.suffix in ['.gd','.py']:shutil.copyfile(p,recipes/p.name)
    # Keep dependent inventory helpers local to this evidence packet as well.
    shutil.copyfile(ROOT/'build/asset-review-2026-11-08/metrics.gd',recipes/'metrics.gd')
    with zipfile.ZipFile(EV/'sources-and-logs.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for relative in OWNED:
            archive.write(ROOT/relative,'after/'+relative)
            before=WORK/'before'/relative
            if before.exists():archive.write(before,'before/'+relative)
        for p in WORK.glob('*.log'):archive.write(p,'logs/'+p.name)
        for p in recipes.iterdir():archive.write(p,'recipes/'+p.name)
        for directory in ['prepared-pipeline-verify','prepared-bake','identity-mid','identity-final']:
            for p in (WORK/directory).glob('*'):
                if p.is_file() and p.suffix in ['.log','.json']:archive.write(p,directory+'/'+p.name)
        for base in (WORK/'frozen/game').rglob('*'):
            if base.is_file() and '.godot' not in base.parts and base.suffix in ['.gd','.gdshader','.gdshaderinc','.tres','.json']:
                archive.write(base,'qualified-source/'+base.relative_to(WORK/'frozen').as_posix())
        archive.write(WORK/'frozen/source-hashes.json','qualified-source/source-hashes.json')
    items=[]
    for proof in proofs:
        for row in proof['rows']:
            items.append({'name':proof['folder']+' / '+row['case'],
              'before':proof['folder']+'/'+row['case']+'-before.png',
              'after':proof['folder']+'/'+row['case']+'-after.png',
              'draws':str(row['before_draws'])+' → '+str(row['after_draws']),
              'mean':row['image_metrics']['mean']})
    html='''<!doctype html><meta charset="utf-8"><title>Asset optimisation comparisons</title>
<style>body{font:16px system-ui;background:#172126;color:#e6ede9;margin:24px}select{padding:8px;max-width:100%}#frame{position:relative;width:min(1280px,100%);aspect-ratio:16/9;background:#34434a;overflow:hidden}img{position:absolute;width:100%;height:100%;object-fit:contain}#original{clip-path:inset(0 50% 0 0)}input{width:min(1280px,100%)}p{max-width:1000px}a{color:#c8dea6}</style>
<h1>Asset optimisation comparisons</h1><p>Select a case and drag the divider. The original is on the left; the optimisation is on the right. These are unmodified native screenshots.</p>
<select id="pick"></select><p id="info"></p><div id="frame"><img id="result"><img id="original"></div><input id="divider" type="range" min="0" max="100" value="50" aria-label="Before and after divider">
<p>Near tree and tyre triangle corners remain complete. Distant trees and tyres allow small appearance differences. Mesh-buffer packing preserves road/kerb pixels. Draw counts are renderer observations; no FPS or device result is implied.</p>
<script>const rows=ITEMS;const pick=document.querySelector('#pick');rows.forEach((r,i)=>pick.add(new Option(r.name,i)));function update(){const r=rows[+pick.value];document.querySelector('#result').src=r.after;document.querySelector('#original').src=r.before;document.querySelector('#info').textContent='Draw calls: '+r.draws+' | Mean pixel difference: '+r.mean.toFixed(6)+' / 255';}pick.onchange=update;document.querySelector('#divider').oninput=e=>document.querySelector('#original').style.clipPath='inset(0 '+(100-e.target.value)+'% 0 0)';pick.value=rows.findIndex(r=>r.name.includes('cars-gl_compatibility-final / electric-stock-close'));update();</script>'''
    html=html.replace('cars-gl_compatibility-final / electric-stock-close','cars-gl_compatibility-verified / electric-stock-close')
    (EV/'comparisons.html').write_text(html.replace('ITEMS',json.dumps(items)),encoding='utf-8')
    print(json.dumps({'runs':len(receipts),'native_cases':summary['native_cases'],'pngs':summary['native_pngs'],'sources':len(OWNED)}))
if __name__=='__main__':main()
