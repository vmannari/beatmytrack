"""C306: fence native publication and retain every unrelated reduction row."""
import hashlib,json
from run_car_pass10 import ROOT,OUT,WORK
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
pub=json.loads((OUT/'publication.json').read_text());files=pub['files'];rows=0;unchanged=0;added=0;manifests=0
for name,record in files.items():
    path=ROOT/name;assert digest(path)==record['after'],name
    assert not any(t in name for t in ('challenger','super_rally'))
    if path.suffix!='.json':continue
    manifests+=1;after=json.loads(path.read_text());backup=WORK/'before'/name
    before=json.loads(backup.read_text()) if backup.exists() else {'parts':{}}
    if '/car_detail_v1/' in name:
        assert before==after,'Unchanged driver retains its exact complete detail recipe'
        continue
    assert before.get('context',after['context'])==after['context']
    assert before.get('schema',after['schema'])==after['schema']
    assert set(before['parts'])<=set(after['parts'])
    for key,row in after['parts'].items():
        if row==before['parts'].get(key):unchanged+=1;continue
        resource='game/assets/vehicles/car_surface_v1/'+row['mesh']
        assert resource in files and '_pass10_' in row['mesh'],(name,key)
        assert set(row)=={'source','mesh','result'}
        if key in before['parts']:assert before['parts'][key]['source']==row['source']
        else:added+=1
        rows+=1
prior=json.loads((ROOT/'docs/evidence/car-pass12-2026-11-16/publication.json').read_text())
protected=[n for n in prior['files'] if n not in files]
assert all(digest(ROOT/n)==prior['files'][n]['after'] for n in protected)
driver='game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res'
assert driver not in files and digest(ROOT/driver)==prior['files'][driver]['after']
value=dict(authored_files=len(files),manifests=manifests,changed_rows=rows,new_rows=added,unrelated_rows_retained=unchanged,preceding_resources_outside_publication_exact=len(protected),driver_native_byte_exact=True,Challenger_excluded=True)
(OUT/'authored-integrity.json').write_text(json.dumps(value,indent=2)+'\n');print('C306_INTEGRITY',value)
