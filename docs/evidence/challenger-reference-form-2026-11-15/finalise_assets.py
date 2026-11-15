"""Close the current Challenger scope after rebuilding the stale shared header."""
from pathlib import Path
script=Path(__file__).with_name('guarded_assets.py')
exec(compile(script.read_text(encoding='utf-8-sig').split('\nbefore = sources()')[0],str(script),'exec'))
before=sources()
accepted=json.loads((OUT/'source-receipt.json').read_text())
assert accepted['before']==accepted['after'],'Original source fence must have passed'
changed=sorted(p for p in accepted['after'].keys()|before.keys() if accepted['after'].get(p)!=before.get(p))
(OUT/'changed-now.json').write_text(json.dumps(changed))
engine('dependency-routes','res://../docs/evidence/challenger-reference-form-2026-11-15/dependency_routes.gd')
routes=json.loads((OUT/'dependency-routes.json').read_text())
assert set(routes)==set(changed) and all('super_rally' not in ids for ids in routes.values()),'A consumed Challenger input changed'
original_keys=json.loads((OUT/'client-build-identity.json').read_text(encoding='utf-8-sig'))['modular_car_sha256']
identity('identity-final')
final=json.loads((OUT/'client-build-identity.json').read_text(encoding='utf-8-sig'))
assert final['modular_car_sha256']['super_rally']==original_keys['super_rally'],'Challenger model key changed during shared-header refresh'
engine('prepared-scoped-final','res://tests/check_prepared_assets.gd',['--exclude-vehicle='+id for id in ('compact','kart','forklift','electric','hovercraft')])
run('picture-scoped-final',[sys.executable,'scripts/check_garage_previews.py','--vehicles=super_rally'])
run('workshop-final',[sys.executable,'scripts/check_garage_workshop.py'])
after=sources();assert before==after,'Sources changed during final scope checks'
full_receipt=json.loads((Path(__file__).parent/'prepared-complete-current-command.json').read_text())
full_summary=[line for line in (Path(__file__).parent/'prepared-complete-current.log').read_text().splitlines() if line.startswith('PREPARED_ASSETS')]
(OUT/'final-scope.json').write_text(json.dumps({'stable_inputs':len(after),'source_fence_exact':True,
    'model_keys_exact':True,'full_preflight':{'exit_code':full_receipt['exit_code'],'summary':full_summary},
    'other_vehicle_input_changes':routes,'no_asset_metadata_restamped':True,
    'source_map_sha256':hashlib.sha256(json.dumps(after,sort_keys=True).encode()).hexdigest()},indent=2))
print('CHALLENGER_SCOPE_FINAL stable sources, current model keys, prepared assets, picture and workshop pass')
