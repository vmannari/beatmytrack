from pathlib import Path
import gzip,hashlib,json,shutil,subprocess
EVIDENCE=Path(__file__).resolve().parent
context=(EVIDENCE/'refresh_all_prepared.py').read_text().split('\nbefore = sources()')[0]
exec(compile(context,'refresh-context','exec'))
current=sources();reconciled=json.loads((OUT/'reconciliation.json').read_text())
payload=json.dumps(current,sort_keys=True).encode()
qualified=json.loads(gzip.decompress((EVIDENCE/'prepared-refresh/inputs.json.gz').read_bytes()))
late=sorted(n for n in qualified.keys()|current.keys() if qualified.get(n)!=current.get(n))
assert all(n in reconciled['unconsumed_ui_changes'] and not reconciled['unconsumed_ui_changes'][n] for n in late), late
(EVIDENCE/'late-ui-fence.json').write_text(json.dumps({'changed_after_reconciliation':late,'all_previously_verified_routes_empty':True,'model_consumed_inputs_unchanged':True,'claim':'Model scope only; broad UI snapshot stability is not claimed.'},indent=2))
destination=EVIDENCE/'prepared-refresh';destination.mkdir(exist_ok=True)
for p in OUT.iterdir():
    if p.name.endswith('-command.json') or p.suffix=='.log' or p.name in ['identity-before.json','client-build-identity.json','reconciliation.json','dependency-routes.json']:
        shutil.copy2(p,destination/p.name)
(destination/'current-inputs.json.gz').write_bytes(gzip.compress(payload,mtime=0))
rejection=json.loads((OUT/'source-receipt.json').read_text())
(destination/'broad-fence-rejection.json').write_text(json.dumps({'changed':rejection['changed'],'qualified':False,'reason':'Broad UI snapshot changed; see exact unchanged consumed-key reconciliation.'},indent=2))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
publication=json.loads((EVIDENCE/'native-publication.json').read_text())
start=json.loads((EVIDENCE/'task-start.json').read_text())
prepared=json.loads((EVIDENCE/'preparation-command.json').read_text())
producer=json.loads((EVIDENCE/'native-final-command.json').read_text())
pin=json.loads((EVIDENCE/'input-pins'/(producer['source_pin_sha256']+'.json')).read_text())
controls={'live_native_exact':all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items()),
    'conversion_inputs_exact':all(sha(Path(name))==digest for name,digest in prepared['after'].items()),
    'baker_exact_to_qualified_input':sha(ROOT/'game/tests/bake_challenger_hellcat.gd')==pin['game/tests/bake_challenger_hellcat.gd'],
    'car_configurations':{name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/resources/cars/')},
    'unchanged_model_source':sha(ROOT/'game/vehicle/super_rally_model.gd')==start['game/vehicle/super_rally_model.gd']}
assert controls['live_native_exact'] and controls['conversion_inputs_exact'] and controls['baker_exact_to_qualified_input'] and controls['unchanged_model_source'] and all(controls['car_configurations'].values())
(EVIDENCE/'final-controls.json').write_text(json.dumps(controls,indent=2))
# Keep native comparisons, not duplicate private render drafts.
for stage in ['before','prepared']:
    for method in ['gl_compatibility','mobile']:
        for tier in (['simple'] if stage=='before' else ['simple','full']):
            source=ROOT/('build/challenger-panel-corrections-2026-11-14/views-'+stage)/method/tier
            dest=EVIDENCE/stage/method/tier;dest.mkdir(parents=True,exist_ok=True)
            for p in source.glob('*.png'):shutil.copy2(p,dest/p.name)
for method in ['gl_compatibility','mobile']:
    source=ROOT/'build/challenger-panel-corrections-2026-11-14/app'/method
    dest=EVIDENCE/'app'/method;dest.mkdir(parents=True,exist_ok=True)
    for p in source.glob('*.png'):shutil.copy2(p,dest/p.name)
subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(EVIDENCE/'compare.ps1')],check=True,cwd=ROOT)
print('EVIDENCE: exact native/configuration/conversion controls, refresh receipts and native render comparisons saved')
