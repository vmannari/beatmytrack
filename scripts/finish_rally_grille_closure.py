"""RGC03: qualify the Rally consumer while retaining the shared WIP rejection."""
import json
import run_rally_grille_closure
from run_rally_grille_closure import OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact',)
original=json.loads((OUT/'shared-wip-refresh-inputs.json').read_text())
before={p:h for p,h in original.items() if refresh.prior.consumed(p)}
after=refresh.sources()
changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
(OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
(OUT/'refresh-fence.json').write_text(json.dumps({'inputs':len(before),'changed':changed,'scope':'Rally only; shared Challenger WIP rejection retained separately'},indent=2)+'\n')
assert not changed,changed
refresh.identity('identity-after')
refresh.checked('prepared-preflight','res://tests/check_rally_grille_closure_prepared.gd','--headless')
print('RGC_SCOPED_READY',len(before),'stable Rally inputs')
