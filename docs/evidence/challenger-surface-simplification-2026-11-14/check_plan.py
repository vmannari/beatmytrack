"""Native plan sections reject the front flare independently of the taper code."""
from pathlib import Path
import json
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
before = '--before' in sys.argv
data = json.loads((ROOT / ('build/challenger-surface-simplification-2026-11-14/native-plan'+('-before' if before else '-candidate' if '--candidate' in sys.argv else '')+'.json')).read_text())
checks = 0
failures = []
metrics = []
def check(ok, label):
    global checks
    checks += 1
    if not ok: failures.append(label)

for tier, parts in data.items():
    tri = np.concatenate([np.asarray(parts[role]).reshape(-1,3,3) for role in ['body_paint','hood_paint']])
    for side in [-1,1]:
        widths = []
        depths = np.linspace(1.50,2.15,326)
        for depth in depths:
            # Include vertices exactly on a section plane as well as crossing
            # edges, so an authored mesh row cannot hide its outermost point.
            sections = tri[np.abs(tri[:,:,2]+depth)<1e-7].tolist()
            for ia,ib in [(0,1),(1,2),(2,0)]:
                a,b = tri[:,ia],tri[:,ib]
                selected = (a[:,2]+depth)*(b[:,2]+depth)<0
                a,b = a[selected],b[selected]
                q = a+(b-a)*((-depth-a[:,2])/(b[:,2]-a[:,2]))[:,None]
                sections.extend(q[(q[:,1]>.35)&(q[:,1]<1.05)].tolist())
            sections = np.asarray(sections)
            check(len(sections)>0,f'{tier}/{side} continuous nose section {depth}')
            widths.append(float(np.max(side*(sections[:,0]-.005052088637516661))))
        widths = np.asarray(widths)
        outward = widths-np.minimum.accumulate(widths)
        for depth, amount in zip(depths,outward):
            check(amount<.002,f'{tier}/{side} no forward flare at {depth}: {amount} m')
        for amount in np.diff(widths):
            check(amount<.00075,f'{tier}/{side} no abrupt outward step: {amount} m')
        check(widths[0]-widths[-1]>.025,f'{tier}/{side} nose continues inward from front wing')
        metrics.append({'tier':tier,'side':side,'maximum_forward_flare_metres':float(outward.max()),
                        'largest_outward_step_metres':float(np.diff(widths).max()),
                        'wing_to_corner_taper_metres':float(widths[0]-widths[-1]),
                        'depths':depths.tolist(),'half_widths':widths.tolist()})
receipt={'checks':checks,'failures':len(failures),'findings':failures,'metrics':metrics}
(OUT/('before-plan-check.json' if before else 'candidate-plan-check.json' if '--candidate' in sys.argv else 'after-plan-check.json')).write_text(json.dumps(receipt,indent=2))
print('CHALLENGER_PLAN:',checks,'checks,',len(failures),'failures')
print(json.dumps([{k:v for k,v in row.items() if k not in ['depths','half_widths']} for row in metrics]))
sys.exit(1 if failures else 0)
