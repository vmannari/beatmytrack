import hashlib,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent;FROZEN=WORK/'frozen';EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
expected=load(FROZEN/'source-hashes.json');actual=load(WORK/'live-source-hashes.json')
differences=[]
for field in ['sources','revisions']:
    for id in expected[field]:
        if expected[field][id]!=actual[field].get(id):differences.append([field,id])
(EV/'publication-source-check.json').write_text(json.dumps({'differences':differences,'frozen':expected,'live':actual},indent=2)+'\n')
assert not differences,differences
if '--check' in sys.argv:print('PUBLICATION_SOURCES: exact match for all six vehicles');sys.exit()
for label in ['final-bases','final-garage','final-header','final-pictures','final-assets','verified-scenery','final-lod-policy','final-prepared-gl','final-prepared-mobile']+['final-kits-'+id for id in expected['sources']]+['final-matrix-'+id for id in expected['sources']]:
    receipt=load(WORK/(label+'-receipt.json'));assert receipt['exit_code']==0,(label,receipt)
    log=(WORK/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    assert 'ERROR:' not in log and 'FAIL:' not in log,(label,'error in log')
outputs=[]
for id in expected['sources']:
    outputs+=list((FROZEN/'game/assets/vehicles/modular_car_bases_v1').glob(id+'_*.scn'))
    outputs+=list((FROZEN/'game/assets/vehicles/modular_kits_v1'/id).rglob('*.scn'))
    outputs.append(FROZEN/'game/assets/garage/cars_v1'/(id+'.scn'))
    outputs.append(FROZEN/'game/assets/garage/previews_v1'/(id+'.png'))
outputs+=[FROZEN/'game/assets/menu/header_car_templates_v1/compact.scn',FROZEN/'game/assets/garage/cars_v1/provenance.json',FROZEN/'game/assets/garage/previews_v1/provenance.json']
outputs+=list((FROZEN/'game/assets/scenery_lods_v1').glob('*.res'))
receipt={}
for source in outputs:
    target=ROOT/source.relative_to(FROZEN)
    receipt[source.relative_to(FROZEN).as_posix()]={'before':sha(target) if target.exists() else None,'after':sha(source)}
for source in outputs:
    target=ROOT/source.relative_to(FROZEN);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
(EV/'published-assets.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PUBLISHED_ASSETS',len(outputs),'source maps and revisions match; no source files replaced')
