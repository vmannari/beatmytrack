"""Publish only the measured native racing contours, with exact source backups."""
import hashlib
import json
import os
from run_car_step10 import ROOT,OUT,WORK
staged=json.loads((OUT/'volt-fix-staged.json').read_text())
receipt=json.loads((OUT/'volt-fix-stage-receipt.json').read_text())
assert receipt['exit_code']==0 and not receipt['errors']
files={}
for name,relative in staged['files'].items():
    assert relative.startswith('game/assets/vehicles/electric_rear_lamp_gaps_v1/')
    target=ROOT/relative;original=target.read_bytes() if target.exists() else None
    backup=WORK/'before'/relative;backup.parent.mkdir(parents=True,exist_ok=True)
    if original is not None and not backup.exists():backup.write_bytes(original)
    after=(WORK/'volt-fixed'/name).read_bytes()
    temporary=target.with_name(target.name+'.tmp');temporary.write_bytes(after);os.replace(temporary,target)
    files[relative]={'before':hashlib.sha256(backup.read_bytes()).hexdigest() if backup.exists() else None,'after':hashlib.sha256(after).hexdigest()}
(OUT/'volt-publication.json').write_text(json.dumps(dict(files=files),indent=2)+'\n')
print('VOLT_CONTOUR_PUBLICATION',len(files),'native racing strips')
