from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-surface-joins-2026-11-12/assets-final'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
labels=['native-final','joins-final','panels-final','shading-final','geometry-final','fitted-final','wash-final','driving-final','parser-final','modules','physics']
labels += [prefix+'-'+renderer for renderer in ['gl_compatibility','mobile'] for prefix in ['opaque','app','garage']]
commands={name:json.loads((OUT/(name+'-command.json')).read_text()) for name in labels}
assert all(r['exit_code']==0 and r['script_errors']==0 for r in commands.values())
assets={p.name:json.loads(p.read_text()) for p in BUILD.glob('*-command.json')}
assert len(assets)==10 and all(r['exit_code']==0 and r['script_errors']==0 for r in assets.values())
fence=json.loads((BUILD/'source-receipt.json').read_text())
assert fence['before']==fence['after'] and not fence['changed']
for name in ['protected-controls','unrelated-picture-controls']:
    before=json.loads((OUT/(name+'.json')).read_text())
    result={p:{'before':s,'after':sha(ROOT/p),'same':sha(ROOT/p)==s} for p,s in before.items()}
    (OUT/(name+'-result.json')).write_text(json.dumps(result,indent=2))
    if name=='protected-controls':assert all(r['same'] for r in result.values())
for p in BUILD.glob('*'):
    if p.is_file() and p.suffix in ['.json','.log']:shutil.copy2(p,OUT/('assets-'+p.name))
native={p.name:sha(p) for p in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*') if p.suffix in ['.res','.json']}
preparation=json.loads((OUT/'preparation-command.json').read_text())
assert preparation['stable'] and preparation['exit_code']==0
assert all(sha(Path(p))==s for p,s in preparation['after'].items())
joins=json.loads((OUT/'after-joins.json').read_text())
assert joins['checks']==2624 and joins['failures']==0
receipt={'commands':commands,'assets':assets,'stable_asset_inputs':len(fence['before']),'native_resources':native,
         'geometry':json.loads((OUT/'geometry-acceptance.json').read_text()),
         'surface_metrics':{k:max(m[k] for m in joins['metrics']) for k in ['max_normal_jump_degrees','max_geometry_second_difference_m','max_normal_second_difference']},
         'device_tested':False,'backend_requested':False,'main_index_written':False}
(OUT/'final-acceptance.json').write_text(json.dumps(receipt,indent=2))
print('Final audit passed:',len(commands),'checks,',len(assets),'asset commands,',len(fence['before']),'stable inputs')
