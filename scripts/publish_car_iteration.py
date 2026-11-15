"""CI01-CI02: install the reviewed Forklift frame recipes, meshes first."""
import hashlib
import json
import os
from pathlib import Path
import re
import run_car_iteration
from run_car_iteration import ROOT, WORK, OUT, run
import refresh_car_10k_assets as refresh


def main():
    refresh.prior.IDS=('forklift',)
    before=refresh.sources()
    if run('recipes-qualified','res://tests/stage_car_iteration_recipes.gd','--headless'):
        raise RuntimeError('Recipe staging failed')
    assert refresh.sources()==before, 'Consumed inputs changed during staging'
    plan=json.loads((OUT/'candidate-plan.json').read_text())
    review=json.loads((OUT/'geometry-review.json').read_text())
    assert all(key.startswith('forklift_') and review['parts'][key]['accepted'] for key in plan['parts'])
    receipt=json.loads((OUT/'final-candidate-gl-receipt.json').read_text())
    assert receipt['exit_code']==0 and not receipt['errors']
    changes=json.loads((OUT/'staged-recipes.json').read_text())['changes']
    for change in changes:
        deviation=max(s['maximum_sampled_deviation_m'] for s in review['parts'][change['candidate']]['surfaces'])
        assert deviation*change['maximum_scale']<=0.002, change
    identity=(ROOT/'game/core/build_identity.gd').read_text()
    keys=json.loads(re.search(r'const MODULAR_CAR_SHA256: Dictionary = (.*)',identity)[1])
    (OUT/'initial-car-keys.json').write_text(json.dumps(keys,indent=2)+'\n')
    staged=list((WORK/'recipes').glob('*'))
    destination=ROOT/'game/assets/vehicles/car_detail_v1'
    files={}
    for source in sorted(staged,key=lambda p:p.suffix=='.json'):
        assert source.name.startswith('forklift_') and source.suffix in ('.res','.json')
        target=destination/source.name
        original=target.read_bytes() if target.exists() else None
        if original is not None:
            backup=WORK/'before'/target.relative_to(ROOT)
            backup.parent.mkdir(parents=True,exist_ok=True)
            if backup.exists(): assert backup.read_bytes()==original, 'Preserve task-start source '+str(backup)
            else: backup.write_bytes(original)
        data=source.read_bytes()
        temporary=target.with_name(target.name+'.tmp');temporary.write_bytes(data);os.replace(temporary,target)
        files[target.relative_to(ROOT).as_posix()]={'before':hashlib.sha256(original).hexdigest() if original else None,'after':hashlib.sha256(data).hexdigest()}
    (OUT/'publication.json').write_text(json.dumps({'files':files,'input_count':len(before),'producer_inputs_unchanged':True,'qualified_parts':len(plan['parts']),'changes':len(changes),'scope':'Forklift only; existing runtime and frame protection retained'},indent=2)+'\n')
    print('ITERATION_PUBLISHED',len(files),'Forklift resources')


if __name__=='__main__': main()
