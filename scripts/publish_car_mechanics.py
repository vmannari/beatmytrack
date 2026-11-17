"""CME05: publish reviewed native files with exact pre-task backups."""
import hashlib
import json
import os
import sys
from run_car_mechanics import ROOT, OUT, WORK

digest=lambda data:hashlib.sha256(data).hexdigest()
distance='--distance' in sys.argv
stage=json.loads((OUT/('distance-staged.json' if distance else 'staged.json')).read_text())
if distance:
    review=json.loads((OUT/'distance-review.json').read_text())
    assert review and all(row['accepted'] for row in review.values())
else:
    review=json.loads((OUT/'geometry-review.json').read_text())
    plan=json.loads((OUT/'selected-plan.json').read_text())
    assert not review['rejected'] and set(review['parts'])==set(plan['parts'])
    assert plan['driver']['exact_corner_checks']==22
    assert plan['driver']['before']==plan['driver']['after']
publication_path=OUT/'publication.json'
publication=json.loads(publication_path.read_text()) if publication_path.exists() else dict(files={})
index=digest((ROOT/'.git/index').read_bytes())
for staged,name in sorted(stage['files'].items(),key=lambda item:item[1].endswith('.json')):
    target=(ROOT/name).resolve()
    assert target.is_relative_to((ROOT/'game/assets/vehicles').resolve())
    assert 'super_rally' not in name and 'challenger' not in name and 'electric' not in name
    after=(WORK/'staged'/staged).read_bytes()
    before=target.read_bytes() if target.exists() else None
    if name in publication['files']:
        if publication['files'][name]['after']==digest(after):continue
        assert '--revise' in sys.argv
        assert digest(before)==publication['files'][name]['after']
        original=publication['files'][name]['before']
        publication['files'].pop(name)
        before=None if original is None else (WORK/'before'/name).read_bytes()
    if before is not None:
        backup=WORK/'before'/name;backup.parent.mkdir(parents=True,exist_ok=True)
        if backup.exists():assert backup.read_bytes()==before
        else:backup.write_bytes(before)
    target.parent.mkdir(parents=True,exist_ok=True)
    temporary=target.with_name(target.name+'.mechanics-tmp')
    assert not temporary.exists();temporary.write_bytes(after);os.replace(temporary,target)
    assert target.read_bytes()==after
    publication['files'][name]=dict(before=digest(before) if before is not None else None,after=digest(after))
assert digest((ROOT/'.git/index').read_bytes())==index
publication['main_index_unchanged_during_publication']=True
publication_path.write_text(json.dumps(publication,indent=2)+'\n')
print('MECHANICS_PUBLISHED',len(publication['files']),'native source files')
