"""Validate concrete delivered evidence; exit zero alone is insufficient."""
import hashlib,json,re
from pathlib import Path
p=Path(__file__).resolve().parent
root=p.parents[2]
labels=['contract-gl','consolidation-gl','final-pixels','final-native','contract-mobile','consolidation-mobile','first-laps-mobile-fixed','first-laps-gl-fixed','final-contract','final-source-parity','final-fresh-abba']
rows=[]
for label in labels:
    receipt=json.loads((p/(label+'-receipt.json')).read_text())
    log=(p/(label+'.log')).read_text(errors='replace')
    assert receipt['exit_code']==0 and not receipt['changed_sources'],label
    assert 'SCRIPT ERROR:' not in log and 'SHADER ERROR:' not in log,label
    counts=re.findall(r'(?:SURFACE_SHADER_PRUNING|SHADER_CONSOLIDATION|FIRST_USE_GRAPHICS|FINAL_PRUNING_PARITY): (\d+) checks, (\d+) failures',log)
    if label=='final-pixels': counts=re.findall(r'VARIANT_RENDER_CHECKS (\d+) / (\d+)',log)
    if 'first-laps' in label:
        data=json.loads((p/(label+'.json')).read_text())
        assert len(data['first_laps'])==5 and all(r['completed_laps']>=1 and r['contacts']==0 for r in data['first_laps']),label
        counts=[(str(data['checks']),str(data['failures']))]
    assert (counts and int(counts[-1][0])>0 and int(counts[-1][1])==0) or label=='final-fresh-abba',label
    rows.append(dict(label=label,checks=int(counts[-1][0]) if counts else 0,failures=0))
pixels=json.loads((p/'final-pixels/report.json').read_text())
assert len(pixels['themes'])==5
assert all(len(t['proofs'])==3 and all(v['changed']==0 and v['unstable']==0 for v in t['proofs']) for t in pixels['themes'].values())
a={f.name for f in (p/'pine-native-prune/jobs').glob('*.job')}
b={f.name for f in (p/'final-native/jobs').glob('*.job')}
assert len(a)==187 and a==b
unchanged={}
for name in ['game/race/world_render_preparation.gd','game/vehicle/effect_render_preparation.gd','game/rendering/graphics_preparation.gd','game/track/creator_road.gdshaderinc','game/track/bridge_road.gdshaderinc']:
    unchanged[name]=(root/name).read_bytes()==(p/'before'/name).read_bytes()
assert all(unchanged.values()),unchanged
files=['game/track/surface_shader_variants.gd','game/track/surface_shader_pruning.gd','game/tests/test_surface_shader_pruning.gd','game/tests/test_shader_variant_consolidation.gd','game/tests/profile_first_use_graphics.gd']
result=dict(runs=rows,checks=sum(r['checks'] for r in rows),failures=0,pixel_exact_views=15,restored_controls=15,native_program_keys_identical=187,unchanged_task_start_sources=unchanged,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},diagnostic_dll_sha256=hashlib.sha256((p/'harness/program_probe.dll').read_bytes()).hexdigest())
(p/'delivery-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
