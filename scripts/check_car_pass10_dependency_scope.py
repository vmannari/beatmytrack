"""C307: prove a concurrent Challenger-only routing addition preserves all five cars."""
import copy,hashlib,json,subprocess
from run_car_pass10 import ROOT,OUT
name='game/vehicle/prepared_asset_dependencies.json'
expected=json.loads((OUT/'apply-start-controls.json').read_text())[name]
digest=lambda b:hashlib.sha256(b).hexdigest()
original=None;origin=None
for spec in ('HEAD:'+name,':'+name):
    value=subprocess.check_output(['git','show',spec],cwd=ROOT)
    normalized=value.replace(b'\r\n',b'\n')
    for raw in (value,normalized,normalized.replace(b'\n',b'\r\n')):
        if digest(raw)==expected:original=json.loads(raw);origin=spec;break
    if original is not None:break
assert original is not None,'The exact application-start routing policy must be recovered before closing'
raw=(ROOT/name).read_bytes();current=json.loads(raw)
ids={'compact','kart','forklift','electric','hovercraft'}
def scoped(data):
    result=copy.deepcopy(data)
    for rule in result['rules']:rule['vehicles']=[car for car in rule['vehicles'] if car in ids]
    return result
assert scoped(original)==scoped(current),'Every rule, ordering, exclusion and five-car membership remains exact'
changes=[]
for before,after in zip(original['rules'],current['rules']):
    if before==after:continue
    assert {k:v for k,v in before.items() if k!='vehicles'}=={k:v for k,v in after.items() if k!='vehicles'}
    assert set(before['vehicles'])<=set(after['vehicles']) and set(after['vehicles'])-set(before['vehicles'])=={'super_rally'}
    changes.append(after['pattern'])
assert set(changes)=={'game/assets/vehicles/compact_plate_v1/*','game/vehicle/compact_plate.gdshader'}
value=dict(before_sha256=expected,after_sha256=digest(raw),recovered_from=origin,all_five_car_routing_rules_exact=True,changed_patterns=changes,only_added_vehicle='super_rally',file_authored_by_this_task=False)
(OUT/'dependency-scope.json').write_text(json.dumps(value,indent=2)+'\n');print('C307_DEPENDENCY_SCOPE Challenger-only additions; complete five-car routing unchanged')
