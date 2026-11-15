"""Qualify unchanged consumed inputs after the retained broad UI fence rejection."""
from pathlib import Path
context=Path(__file__).with_name('refresh_all_prepared.py').read_text().split('\nbefore = sources()')[0]
exec(compile(context,'refresh-context','exec'))
original=json.loads((OUT/'source-before.json').read_text())
current=sources()
changed=sorted(p for p in original.keys()|current.keys() if original.get(p)!=current.get(p))
assert all(p.startswith('game/ui/') for p in changed), changed
(OUT/'reconcile-changes.json').write_text(json.dumps(changed))
engine('dependency-routes','res://../docs/evidence/challenger-reference-repair-2026-11-14/dependency_routes.gd')
routes=json.loads((OUT/'dependency-routes.json').read_text())
assert set(routes)==set(changed) and all(not ids for ids in routes.values()), routes
identity('identity-reconciled')
first=json.loads((OUT/'identity-before.json').read_text())
final=json.loads((OUT/'client-build-identity.json').read_text(encoding='utf-8-sig'))
assert first['modular_car_sha256']==final['modular_car_sha256'], 'Consumed model keys changed'
engine('prepared-final','res://tests/check_prepared_assets.gd')
run('picture-preflight-final',[sys.executable,'scripts/check_garage_previews.py'])
after=sources()
assert current==after, 'Sources changed during reconciliation'
(OUT/'reconciliation.json').write_text(json.dumps({'broad_fence_rejected':True,'unconsumed_ui_changes':routes,
    'all_model_keys_exact':True,'no_asset_metadata_restamped':True,'current_source_count':len(current),
    'current_sources_sha256':hashlib.sha256(json.dumps(current,sort_keys=True).encode()).hexdigest(),
    'stable_during_checks':True},indent=2))
print('RECONCILED: unchanged consumed inputs and model keys; strict prepared and catalogue checks pass')
