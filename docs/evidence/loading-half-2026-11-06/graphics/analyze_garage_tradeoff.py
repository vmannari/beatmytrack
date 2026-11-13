"""Summarize the same-source journey and retain raw stage/visual comparisons."""
import argparse
import json
from pathlib import Path
import statistics

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    raw = json.loads((OUT/(args.label+'-summary.json')).read_text())
    arms = []
    for entry in raw:
        result = entry['result']
        rows = [row for row in result['menus'] if row['cycle'] == 0]
        rivalry = next(row for row in rows if row['page'] == 'rivalry')
        garage = next(row for row in rows if row['page'] == 'garage')
        phases = [event for event in entry['events'] if event['kind'] == 'GARAGE_TRADEOFF_PHASE']
        phase = {event['phase']:event for event in phases}
        native = [event for event in entry['events'] if event['kind'] == 'GARAGE_TRADEOFF_NATIVE']
        preloader = [event for event in entry['events'] if event['kind'] == 'GARAGE_TRADEOFF_PRELOADER']
        # The elapsed boundary includes the unchanged automated captures/gaps.
        # The sum counts each first-entry wait once, with Rivalry's equal settle fence.
        row = {'name':entry['name'],'live_podium':entry['live_podium'],
               'seed':entry['name'].endswith('-seed'),
               'checks':result['checks'],'failures':result['failures'],
               'startup_ms':result['startup']['engine_to_menu_ms'],
               'rivalry_ms':rivalry['settled_ms'],
               'rivalry_native':rivalry['native_podiums'],
               'picture_hits':rivalry['picture_hits'],
               'garage_ms':garage['ready_ms'],
               'garage_dispatch_ms':garage['dispatch_ms'],
               'garage_first_draw_ms':garage['first_draw_ms'],
               'journey_engine_to_garage_ready_ms':garage['engine_to_ready_ms'],
               'journey_first_menu_to_garage_ready_ms':garage['engine_to_ready_ms']-result['startup']['engine_to_menu_ms'],
               'first_entry_wait_sum_ms':sum(item.get('settled_ms',item['ready_ms']) for item in rows),
               'startup_and_entry_wait_sum_ms':result['startup']['engine_to_menu_ms']+sum(item.get('settled_ms',item['ready_ms']) for item in rows),
               'first_entries':{item['page']:item.get('settled_ms',item['ready_ms']) for item in rows},
               'garage_before':garage['tradeoff_before'],
               'phases':phases,'preloader':preloader,
               'native_draw_count':len(native),
               'native_draw_sum_ms':sum(event['draw_ms'] for event in native),
               'native_draw_max_ms':max([event['draw_ms'] for event in native],default=0),
               'feature_load_ms':result['feature_load_ms']}
        for label,start,end in [
            ('opening_to_entry_drawn_ms','opening','entry_drawn'),
            ('resource_wait_ms','entry_drawn','resources_ready'),
            ('showroom_setup_ms','resources_ready','showroom_built'),
            ('proxy_setup_ms','showroom_built','native_queue_ready'),
            ('native_warm_ms','native_queue_ready','native_warm_complete'),
            ('full_settle_ms','full_settle_begin','full_settle_3'),
            ('live_opening_ms','opening','live_ready')]:
            if start in phase and end in phase:
                row[label] = phase[end]['engine_ms']-phase[start]['engine_ms']
        arms.append(row)
    groups = {}
    numeric = ['startup_ms','rivalry_ms','garage_ms','garage_dispatch_ms','garage_first_draw_ms',
               'journey_engine_to_garage_ready_ms','journey_first_menu_to_garage_ready_ms',
               'first_entry_wait_sum_ms','startup_and_entry_wait_sum_ms','opening_to_entry_drawn_ms',
               'resource_wait_ms','showroom_setup_ms','proxy_setup_ms','native_warm_ms',
               'full_settle_ms','live_opening_ms','native_draw_count','native_draw_sum_ms','native_draw_max_ms']
    for label,live in [('live',True),('cached',False)]:
        selected = [arm for arm in arms if arm['live_podium'] == live and not arm['seed']]
        groups[label] = {'samples':len(selected), 'means':{key:statistics.mean(arm[key] for arm in selected) for key in numeric if all(key in arm for arm in selected)}}
    deltas = {key:{'cached_minus_live_ms':groups['cached']['means'][key]-groups['live']['means'][key],
                   'reduction_percent':100*(groups['live']['means'][key]-groups['cached']['means'][key])/groups['live']['means'][key]}
              for key in numeric if key in groups['live']['means'] and key in groups['cached']['means'] and groups['live']['means'][key]}
    decoder = {}
    source = (ROOT/'docs/evidence/graphics-preparation-2026-11-04/compare_pngs.py').read_text()
    exec(source.split('reference = Path(sys.argv[1])')[0],decoder)
    rgba = decoder['rgba']
    pictures = []
    for page in ['rivalry','garage']:
        reference = OUT.parent/(args.label+'-live-a')/(page+'.png')
        width,height,expected = rgba(reference)
        for arm in ['cached-a','cached-b','live-b']:
            path = OUT.parent/(args.label+'-'+arm)/(page+'.png')
            aw,ah,actual = rgba(path)
            assert (aw,ah)==(width,height)
            changed = outside_countdown = maximum = 0
            bounds = [width,height,-1,-1]
            for index,(a,b) in enumerate(zip(expected,actual)):
                if a == b: continue
                x,y = (index//4)%width,(index//4)//width
                changed += 1
                maximum = max(maximum,abs(a-b))
                outside_countdown += not (980<=x<1260 and 115<=y<175)
                bounds = [min(bounds[0],x),min(bounds[1],y),max(bounds[2],x),max(bounds[3],y)]
            pictures.append({'page':page,'reference':str(reference),'path':str(path),
                             'changed_channels':changed,'max_channel_difference':maximum,
                             'bounds':bounds if changed else None,'outside_week_countdown':outside_countdown})
    output = {'arms':arms,'groups':groups,'deltas':deltas,'pictures':pictures,
              'limits':['Two live and two cached samples, one shared private profile, serial desktop Compatibility, instrumented sources.',
                        'Seed excluded; both modes share warmed driver caches and identical source files.',
                        'Engine-to-Garage elapsed includes identical screenshot and navigation gaps; wait sum excludes them.',
                        'Native logging has overhead; phase comparisons are attribution evidence, not an uninstrumented benchmark.',
                        'No device, network, owner save, deployment, appearance or memory improvement claim.']}
    target = OUT/(args.label+'-analysis.json')
    target.write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'groups':groups,'deltas':deltas,'pictures':pictures,'output':str(target)},indent=2))


if __name__ == '__main__': main()
