"""Compare serial device observations; do not treat existing caches as cold drivers."""
import json
import argparse
from pathlib import Path
from statistics import median

E = Path(__file__).resolve().parent
OLD = E.parent/'tablet-phase-profile-2026-11-07'


def pair(a, b):
    old, new = median(a), median(b)
    return {'before_ms':old,'after_ms':new,'reduction_percent':(1-new/old)*100,
            'before_samples_ms':a,'after_samples_ms':b}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--same-session',action='store_true')
    parser.add_argument('--final',action='store_true')
    args = parser.parse_args()
    old_root = E/'tablet-qualified/control' if args.same_session else OLD
    old = json.loads((old_root/'summary.json').read_text())
    new_root = E/('tablet-final' if args.final else 'tablet-qualified')
    new = json.loads((new_root/'summary.json').read_text())
    result = {'races':{},'menus':{},'startup':{},'checks':new['checks'],
        'limits':'Serial historical-before/current-after observations, two runs per mode, existing app/driver caches retained; no randomized order or cold-driver claim.',
        'before_temperatures_c':old['temperatures_c'],'after_temperatures_c':new['temperatures_c'],
        'after_thermal_statuses':new['thermal_statuses']}
    for fixture,theme in sorted({(r['fixture'],r['theme']) for r in old['races']}):
        value = {}
        for cycle in (0,1):
            a,b = [[r for r in s['races'] if (r['fixture'],r['theme'],r['cycle'])==(fixture,theme,cycle)] for s in (old,new)]
            assert len(a)==len(b)==2
            value[str(cycle)] = pair([r['ready_ms'] for r in a],[r['ready_ms'] for r in b])
            value[str(cycle)]['car'] = pair([r['game_costs']['car_us']/1000 for r in a],[r['game_costs']['car_us']/1000 for r in b])
        result['races'][fixture+'/'+theme] = value
    for page in sorted(old['menus'].keys() & new['menus'].keys()):
        result['menus'][page] = {cycle:pair(old['menus'][page][cycle]['ready_ms'],new['menus'][page][cycle]['ready_ms'])
                                 for cycle in old['menus'][page].keys() & new['menus'][page].keys()}
    for key in ('launch_to_content_ms','app_ready_ms'):
        result['startup'][key] = pair([r[key] for r in old['startup'] if r['run'].startswith('profile-startup')],
                                      [r[key] for r in new['startup'] if r['run'].startswith('profile-startup')])
    result['repeat_car'] = pair([r['game_costs']['car_us']/1000 for r in old['races'] if r['cycle']==1],
                                [r['game_costs']['car_us']/1000 for r in new['races'] if r['cycle']==1])
    result['writers'] = [r['writer'] for r in new['startup']]
    assert all(r['inside_tree'] and r['completed_writes']>0 for r in result['writers'])
    name = 'final-comparison.json' if args.final else ('same-session-comparison.json' if args.same_session else 'tablet-comparison.json')
    (E/name).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__': main()
