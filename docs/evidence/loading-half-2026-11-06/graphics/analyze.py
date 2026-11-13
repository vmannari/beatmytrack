"""Summarize frozen graphics receipts and inspect unchanged App picture regions."""
from pathlib import Path
import json
import statistics

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
names = ['graphics-native-compat-1','graphics-native-mobile-1',
         'graphics-live-retained-compat-1','graphics-ready-retained-compat-1',
         'graphics-storage-final-1','graphics-app-control-1','graphics-app-seed-1',
         'graphics-app-hit-1','graphics-app-control-2','graphics-app-hit-2']
receipts = {}
timings = {}
for name in names:
    path = OUT.parent/name/'run.json'
    if path.exists(): receipts[name] = json.loads(path.read_text())
    path = OUT.parent/name/'result.json'
    if path.exists() and name.startswith('graphics-app-'):
        result = json.loads(path.read_text())
        timings[name] = {'startup':result['startup'],'first':result['menus'][0],'repeat':result['menus'][1]}

# Reuse the existing stdlib RGBA decoder without its command-line entry point.
source = (ROOT/'docs/evidence/graphics-preparation-2026-11-04/compare_pngs.py').read_text()
decoder = {}
exec(source.split('reference = Path(sys.argv[1])')[0],decoder)
rgba = decoder['rgba']
reference = OUT.parent/'graphics-app-control-2/rivalry.png'
w,h,expected = rgba(reference)
pictures = []
for name in ['graphics-app-seed-1','graphics-app-hit-1','graphics-app-hit-2']:
    aw,ah,actual = rgba(OUT.parent/name/'rivalry.png')
    assert (aw,ah)==(w,h)
    changed = outside_countdown = maximum = 0
    bounds = [w,h,-1,-1]
    for index,(a,b) in enumerate(zip(expected,actual)):
        if a == b: continue
        x,y = (index//4)%w,(index//4)//w
        changed += 1
        maximum = max(maximum,abs(a-b))
        outside_countdown += not (980<=x<1260 and 115<=y<175)
        bounds = [min(bounds[0],x),min(bounds[1],y),max(bounds[2],x),max(bounds[3],y)]
    pictures.append({'name':name,'changed_channels':changed,'max_channel_difference':maximum,
                     'bounds':bounds if changed else None,'outside_week_countdown':outside_countdown})

control = timings['graphics-app-control-2']['first']['settled_ms']
hit = statistics.mean(timings[name]['first']['settled_ms'] for name in ['graphics-app-hit-1','graphics-app-hit-2'])
report = {'receipts':receipts,'timings':timings,'app_pictures':pictures,
          'warm_control_settled_ms':control,'mean_restart_hit_settled_ms':hit,
          'warm_settled_reduction_percent':100*(control-hit)/control,
          'limits':['Only one already-warm control and two hit samples; initial control and seed have different driver warmth.',
                    'App idle Garage picture service still loads CarVisual after the image hit.',
                    'Week countdown uses live time: 4d11h vs4d12h in the compared App captures.',
                    'Desktop native only; no Android/device/owner appearance acceptance claim.']}
(OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['receipts','timings']},indent=2))
