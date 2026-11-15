"""Select one reviewed option per source piece near the requested car budget."""
import collections
import hashlib
import json
from run_car_step10 import ROOT,WORK,OUT

BASE={'compact':16213,'kart':20590,'forklift':22502,'electric':15797,'hovercraft':18758}

def main():
    # Keep qualified families as immutable receipts; no rejected proposal enters selection.
    pass
    observations=json.loads((OUT/"survey.json").read_text())
    protected={r["key"] for r in observations if "SteeringAssembly" in r["path"]}
    pool=collections.defaultdict(list)
    for family in ('expanded','targeted','regular','fittings'):
        plan=json.loads((OUT/(family+'-candidate-plan.json')).read_text())
        review=json.loads((OUT/(family+'-geometry-review.json')).read_text())
        for key,row in plan['parts'].items():
            if not review['parts'][key]['accepted'] or not row['stock_instances']:continue
            if any(term in row['name'].lower() for term in ('accent','inlay','stripe','decal','sticker','highlight','shine')):continue
            source=row.get('source_key',key)
            if source in protected:continue
            candidate=dict(row,source_key=source,family=family,review_key=key,
                           maximum_error=max(s['maximum_sampled_deviation_m']*row['maximum_scale'] for s in review['parts'][key]['surfaces']))
            candidate['sha256']=hashlib.sha256((WORK/'candidates'/candidate['file']).read_bytes()).hexdigest()
            pool[source].append(candidate)
    initial=json.loads((OUT/'before.json').read_text())
    counts=dict(BASE)
    selected={};rows=[]
    for car,original in BASE.items():
        desired=round(original*0.10)
        states={0:(0.0,None)}
        for source,choices in pool.items():
            if choices[0]['vehicle']!=car:continue
            next_states=dict(states)
            for candidate in choices:
                saving=int((candidate['before']-candidate['after'])*candidate['stock_instances'])
                if saving<=0:continue
                weight=4 if any(term in candidate['name'].lower() for term in ('body','coachwork','hood','shoulder','skirt','lamp')) else 1
                score=(candidate['maximum_error']+0.00001)*weight*saving
                for prior,(cost,node) in states.items():
                    total=prior+saving
                    if total>desired+8:continue
                    if total not in next_states or cost+score<next_states[total][0]:
                        next_states[total]=(cost+score,(node,candidate))
            states=next_states
        best=min(states,key=lambda saving:(abs(saving-desired),states[saving][0]))
        node=states[best][1]
        while node is not None:
            previous,candidate=node;selected[candidate['source_key']]=candidate;node=previous
        row={'vehicle':car,'restored':original,'before':counts[car],'after':counts[car]-best,'new_saving':best,'total_reduction_percent':100*(1-(counts[car]-best)/original)}
        rows.append(row);print('CAR15_SELECTED',row,flush=True)
    (OUT/'selected-plan.json').write_text(json.dumps({'parts':selected,'rows':rows,'scope':list(BASE),'excluded':'super_rally'},indent=2)+'\n')
    print('CAR15_SELECTION',len(selected),'source meshes')

if __name__=='__main__':main()
