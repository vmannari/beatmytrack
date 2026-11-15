"""Preserve original-versus-task-created resource provenance while adding flags."""
import hashlib
import json
import os
from run_car_step10 import ROOT,OUT,WORK
publication=json.loads((OUT/'volt-publication.json').read_text())['files']
staged=json.loads((OUT/'volt-lock-staged.json').read_text())['files']
for name,relative in staged.items():
    target=ROOT/relative;original=target.read_bytes()
    before=publication[relative]['before'] if relative in publication else hashlib.sha256(original).hexdigest()
    if relative not in publication:
        backup=WORK/'before'/relative;backup.parent.mkdir(parents=True,exist_ok=True);assert not backup.exists();backup.write_bytes(original)
    data=(WORK/'volt-protected'/name).read_bytes();temporary=target.with_name(target.name+'.tmp');temporary.write_bytes(data);os.replace(temporary,target)
    publication[relative]={'before':before,'after':hashlib.sha256(data).hexdigest()}
(OUT/'volt-publication.json').write_text(json.dumps(dict(files=publication),indent=2)+'\n')
print('VOLT_PROTECTION_PUBLISHED',len(staged),'resources; original/new provenance retained')
