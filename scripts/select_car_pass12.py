"""CP201-CP202: select one qualified candidate per current mesh, within 10-15%."""
import collections
import hashlib
import json
from run_car_pass12 import ROOT, OUT, WORK

families = ['edges', 'remesh', 'lod', 'contacts', 'planar', 'hardware', 'wheels',
            'fittings', 'uniform', 'radial', 'body', 'kart-body', 'field-paint']
observations = json.loads((OUT/'survey.json').read_text())
latest = json.loads((OUT/'candidate-plan.json').read_text())
blocked = set(latest['blocked_keys'])
blocked.update(row['key'] for row in observations if row['mode']=='stock' and not row['permitted'])
baseline = {row['vehicle']:row['inventory']['triangles'] for row in json.loads((OUT/'before.json').read_text())['rows'] if row['mode']=='stock'}
pool = collections.defaultdict(list)
for family in families:
    plan = json.loads((OUT/(family+'-candidate-plan.json')).read_text())
    review = json.loads((OUT/(family+'-geometry-review.json')).read_text())
    for key, row in plan['parts'].items():
        source = row.get('source_key', key)
        if row['vehicle']=='electric' and row['name'] in ['ReferenceHood','ReferenceRearDeck'] and family!='field-paint':
            continue
        if source in blocked or not row['stock_instances'] or not review['parts'][key]['accepted']:
            continue
        candidate = dict(row, source_key=source, family=family, review_key=key,
                         maximum_error=max(s['maximum_sampled_deviation_m']*row['maximum_scale'] for s in review['parts'][key]['surfaces']))
        candidate['sha256'] = hashlib.sha256((WORK/'candidates'/candidate['file']).read_bytes()).hexdigest()
        pool[source].append(candidate)

driver = next(row for row in json.loads((OUT/'driver-geometry-review.json').read_text())
              if row['file']=='driver_0.96.res' and row['accepted'])
driver['source_path'] = 'game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res'
driver['sha256'] = hashlib.sha256((WORK/'candidates'/driver['file']).read_bytes()).hexdigest()
selected = {}
rows = []
for car, before in baseline.items():
    extra = driver['before']-driver['after'] if car=='kart' else 0
    desired = round(before*.12)-extra
    states = {0:(0.0,None)}
    for source, choices in pool.items():
        if choices[0]['vehicle']!=car:
            continue
        next_states = dict(states)
        for candidate in choices:
            saving = (candidate['before']-candidate['after'])*candidate['stock_instances']
            if saving<=0:
                continue
            weight = 8 if any(term in candidate['name'].lower() for term in ['hood','deck','roof','cabin','body','lamp']) else 1
            score = (candidate['maximum_error']+.00001)*weight*saving
            for old, (cost,node) in states.items():
                total = old+saving
                if total>desired+8:
                    continue
                if total not in next_states or cost+score<next_states[total][0]:
                    next_states[total] = (cost+score,(node,candidate))
        states = next_states
    best = min(states, key=lambda saving:(abs(saving-desired),states[saving][0]))
    node = states[best][1]
    while node is not None:
        node,candidate = node
        selected[candidate['source_key']] = candidate
    saving = best+extra
    result = dict(vehicle=car,before=before,after=before-saving,saving=saving,reduction_percent=100*saving/before)
    assert .10*before<=saving<=.15*before, result
    rows.append(result)
    print('CP2_SELECTION',result,flush=True)
(OUT/'selected-plan.json').write_text(json.dumps(dict(parts=selected,rows=rows,driver=driver,
    blocked_keys=sorted(blocked),before=baseline,excluded='super_rally'),indent=2)+'\n')
print('CP2_SELECTED',len(selected),'qualified static sources plus one index-only driver source')
