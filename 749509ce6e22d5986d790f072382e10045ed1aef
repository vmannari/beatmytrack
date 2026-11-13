"""Task-only authored delta, original controls, binary and picture receipts."""
from pathlib import Path
import difflib,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
initial=json.loads((OUT/'start-sources.json').read_text(encoding='utf-8'))
changed=['scripts/prepare_challenger.py','scripts/challenger_detail_geometry.py',
 'game/tests/bake_challenger_hellcat.gd','game/vehicle/super_rally_model.gd',
 'game/tests/test_challenger_hellcat.gd','game/legal/challenger_hellcat_notices.txt']

delta=[]
for f in changed:
    delta.append(f'diff --git a/{f} b/{f}\n')
    base=OUT/'before'/f
    if not base.exists():delta.append('new file mode 100644\n')
    before=base.read_text(encoding='utf-8').splitlines(True) if base.exists() else []
    after=(ROOT/f).read_text(encoding='utf-8').splitlines(True)
    for line in difflib.unified_diff(before,after,fromfile='a/'+f if base.exists() else '/dev/null',tofile='b/'+f):
        delta.append(line if line.endswith('\n') else line+'\n\\ No newline at end of file\n')
patch=OUT/'source-only.patch';patch.write_text(''.join(delta),encoding='utf-8',newline='\n')
result=subprocess.run(['git','apply','--check','--reverse','--whitespace=nowarn',str(patch.relative_to(ROOT))],cwd=ROOT,capture_output=True,text=True)
assert result.returncode==0,result.stderr
controls={f:{'before':h,'after':sha(ROOT/f)} for f,h in initial.items() if f not in changed and not f.startswith('game/assets/vehicles/') and f!='game/vehicle/car_visual.gd'}
assert all(v['before']==v['after'] for v in controls.values())
original=Path(r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend')
assert sha(original)=='c7fbceda48afce09df28700ee27b8946a8d288f7d7f064771af4df48c40fc567'
assets={p.relative_to(ROOT).as_posix():{'sha256':sha(p),'bytes':p.stat().st_size} for p in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*') if p.suffix in ['.res','.json']}
(OUT/'source-receipt.json').write_text(json.dumps({'authored_sources':{f:sha(ROOT/f) for f in changed},'unchanged_controls':controls,'original_blend_exact':True,'preserved_concurrent_car_visual':{'before':initial['game/vehicle/car_visual.gd'],'after':sha(ROOT/'game/vehicle/car_visual.gd'),'scope':'Kart steering fields/presentation added before the coherent bake; excluded from authored patch and exact controls'},'preserved_concurrent_asset_sources':json.loads((OUT/'prior-bake-shared-source-differences.json').read_text(encoding='utf-8')),'native_assets':assets,'source_only_patch':{'sha256':sha(patch),'files':len(changed),'reverse_check':0,'excludes':'Generated resources, build metadata, documentation, evidence and unrelated concurrent work.'}},indent=2),encoding='utf-8')
print('CHALLENGER_QUALITY_CHECKPOINT:',len(changed),'sources;',len(controls),'exact controls;',len(assets),'native resources; original blend exact; reverse check passes')
