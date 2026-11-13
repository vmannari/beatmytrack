"""Compare pinned fitted-car construction and reuse within the final device build."""
import json
from pathlib import Path
from statistics import median

E = Path(__file__).resolve().parent
F = E/'tablet-final'
parts = {'version':1,'aero':'biwing','body':'wide','hood':'scoop','rims':'turbine'}
values = [json.loads((F/(name+'.json')).read_text()) for name in ['fit-cold-a','fit-reuse-a','fit-reuse-b','fit-cold-b']]
rows = []
for value in values:
    report = value['report']
    assert not report['failures'] and not report['dropped_events']
    for row in report['rows']:
        if row['kind']!='race': continue
        config = row['configuration']
        assert config['vehicle']=='compact' and config['simple'] and config['parts']==parts
        if config['forced_car_miss']: assert config['car_cache_hits']==0 and row['game_costs']['car_yields']>0
        elif row['cycle']==1: assert config['car_cache_hits']>0 and row['game_costs']['car_yields']==0
        rows.append({'run':report['run'],**row})

def comparison(cold,reuse,key):
    a,b = [key(r) for r in cold],[key(r) for r in reuse]
    return {'construction_ms':median(a),'reuse_ms':median(b),'reduction_percent':100*(1-median(b)/median(a)),
            'construction_samples_ms':a,'reuse_samples_ms':b}

races = {}
for fixture,theme in sorted({(r['fixture'],r['theme']) for r in rows}):
    item = {}
    for cycle in (0,1):
        matched = [r for r in rows if (r['fixture'],r['theme'],r['cycle'])==(fixture,theme,cycle)]
        a = [r for r in matched if r['configuration']['forced_car_miss']]
        b = [r for r in matched if not r['configuration']['forced_car_miss']]
        assert len(a)==len(b)==2
        item[str(cycle)] = comparison(a,b,lambda r:r['ready_ms'])
    races[fixture+'/'+theme] = item
warm = [r for r in rows if r['cycle']==1]
a,b = [[r for r in warm if r['configuration']['forced_car_miss']==forced] for forced in (True,False)]
result = {'checks':sum(v['report']['checks'] for v in values),'failures':0,'configuration':parts,
    'repeat_car':comparison(a,b,lambda r:r['game_costs']['car_us']/1000),'races':races,
    'temperatures_c':[v['after']['battery_temperature_c']for v in values],
    'thermal_statuses':[v['after']['thermal_status']for v in values],
    'order':['construct','reuse','reuse','construct'],
    'scope':'Final-build private fitted Compact, Simple=true. Construction control clears only the process rest-template cache before each entry; it retains the unchanged procedural builder. This is not the owner\'s selected stock Kart or an old-APK overall comparison.'}
(E/'fixed-fit-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
