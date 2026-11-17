"""CP204: resource-first publication, with exact backups and no shared-index write."""
import hashlib
import json
import os
from run_car_pass12 import ROOT, OUT, WORK

stage=json.loads((OUT/'staged.json').read_text())
selection=json.loads((OUT/'selected-plan.json').read_text())
review=json.loads((OUT/'geometry-review.json').read_text())
assert set(review['parts'])==set(selection['parts']) and review['rejected']==0
assert all(.10<=r['reduction_percent']/100<=.15 for r in selection['rows'])
assert all(r['maximum_centroid_normal_field_error_degrees']<1 for r in json.loads((OUT/'paint-normal-fields.json').read_text()))
assert not json.loads((OUT/'driver-boundaries.json').read_text())['failures']
digest=lambda b:hashlib.sha256(b).hexdigest()
index=digest((ROOT/'.git/index').read_bytes())
bindings={}
for staged,name in sorted(stage['files'].items(),key=lambda item:item[1].endswith('.json')):
    path=(ROOT/name).resolve()
    assert path.is_relative_to((ROOT/'game/assets/vehicles').resolve()),name
    assert 'super_rally' not in name and 'challenger' not in name,name
    data=(WORK/'staged'/staged).read_bytes()
    before=path.read_bytes() if path.exists() else None
    if before is not None:
        backup=WORK/'before'/name
        backup.parent.mkdir(parents=True,exist_ok=True)
        assert not backup.exists(),name
        backup.write_bytes(before)
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.pass12-tmp')
    assert not temporary.exists(),temporary
    temporary.write_bytes(data)
    os.replace(temporary,path)
    assert path.read_bytes()==data
    bindings[name]=dict(before=digest(before) if before is not None else None,after=digest(data))
(OUT/'publication.json').write_text(json.dumps(dict(files=bindings,selected_plan_sha256=digest((OUT/'selected-plan.json').read_bytes()),
    shared_index_unchanged_during_publication=digest((ROOT/'.git/index').read_bytes())==index),indent=2)+'\n')
print('CP2_PUBLICATION',len(bindings),'exact authored resources; Challenger excluded')
