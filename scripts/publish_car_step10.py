"""Install the reviewed five-car source resources; immutable meshes precede recipes."""
import hashlib
import json
import os
import re
import run_car_step10
from run_car_step10 import ROOT,WORK,OUT
import refresh_car_10k_assets as refresh

def main():
    plan=json.loads((OUT/'selected-plan.json').read_text())
    for row in plan['parts'].values():
        assert hashlib.sha256((WORK/'candidates'/row['file']).read_bytes()).hexdigest()==row['sha256']
        assert row['maximum_error']<=0.002
    for label in ('candidate-native','candidate-fork-final','stage'):
        receipt=json.loads((OUT/(label+'-receipt.json')).read_text())
        assert receipt['exit_code']==0 and not receipt['errors'],label
    staged=json.loads((OUT/'staged.json').read_text())
    before=refresh.sources()
    identity=(ROOT/'game/core/build_identity.gd').read_text()
    (OUT/'publication-pre-identity.json').write_text(json.dumps(json.loads(re.search(r'const MODULAR_CAR_SHA256: Dictionary = (.*)',identity)[1]),indent=2)+'\n')
    files={}
    for file,relative in sorted(staged['files'].items(),key=lambda item:item[0].endswith('.json')):
        assert not ('super_rally' in relative or 'challenger' in relative)
        assert relative.startswith(('game/assets/vehicles/car_surface_v1/','game/assets/vehicles/hovercraft_sport_v4/race_','game/assets/vehicles/car_coarse_v1/hovercraft_'))
        target=ROOT/relative;target.parent.mkdir(parents=True,exist_ok=True);original=target.read_bytes() if target.exists() else None
        if original is not None:
            backup=WORK/'before'/relative;backup.parent.mkdir(parents=True,exist_ok=True)
            if backup.exists():assert backup.read_bytes()==original
            else:backup.write_bytes(original)
        data=(WORK/'staged'/file).read_bytes()
        temporary=target.with_name(target.name+'.tmp');temporary.write_bytes(data);os.replace(temporary,target)
        files[relative]={'before':hashlib.sha256(original).hexdigest() if original else None,'after':hashlib.sha256(data).hexdigest()}
    (OUT/'publication.json').write_text(json.dumps({'files':files,'scope':plan['scope'],'excluded':'super_rally','qualified_parts':len(plan['parts']),'input_count':len(before),'meshes_before_manifests':True},indent=2)+'\n')
    print('CAR15_PUBLISHED',len(files),'source resources',flush=True)

if __name__=='__main__':main()
