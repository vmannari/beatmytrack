"""Independent native triangle heights and corner-normal section gates."""
from pathlib import Path
import json
import sys
import numpy as np

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-corner-roll-2026-11-13'
before=json.loads((BUILD/'native-plan-before.json').read_text())
stage='candidate' if '--candidate' in sys.argv else 'final'
after=json.loads((BUILD/('native-plan-candidate.json' if stage=='candidate' else 'native-plan.json')).read_text())
baseline='--baseline' in sys.argv
if baseline:after=before
checks=0;failures=[];heights=[]
def check(ok,label):
    global checks
    checks+=1
    if not ok:failures.append(label)

def top(tri,x,z):
    a=tri[:,0];u=tri[:,1]-a;v=tri[:,2]-a
    den=u[:,0]*v[:,2]-u[:,2]*v[:,0];valid=abs(den)>1e-12
    a,u,v,den=a[valid],u[valid],v[valid],den[valid]
    s=((x-a[:,0])*v[:,2]-(z-a[:,2])*v[:,0])/den
    t=(u[:,0]*(z-a[:,2])-u[:,2]*(x-a[:,0]))/den
    hit=a[:,1]+u[:,1]*s+v[:,1]*t
    selected=(s>=-1e-6)&(t>=-1e-6)&(s+t<=1+1e-6)&(hit>.65)&(hit<1.05)
    return float(hit[selected].max()) if selected.any() else None

for tier in ['simple','full']:
    a=np.asarray(before[tier]['body_paint']).reshape(-1,3,3)
    b=np.asarray(after[tier]['body_paint']).reshape(-1,3,3)
    for side in [-1,1]:
        previous=None
        for z in [-2.0,-2.06,-2.10,-2.13]:
            x=.005052088637516661+side*.81
            old=top(a,x,z);new=top(b,x,z)
            check(old is not None and new is not None,f'{tier}/{side} continuous corner top at {z}')
            if old is None or new is None:continue
            drop=old-new
            check(.005<drop<.040,f'{tier}/{side} gentle 5–40 mm corner downturn at {z}: {drop}')
            if previous is not None:check(new<previous,f'{tier}/{side} outer lip sweeps down towards front')
            previous=new
            heights.append(dict(tier=tier,side=side,z=z,before_y=old,after_y=new,drop_metres=drop))
    # The unchanged bonnet is an independent control on the operation's extent.
    old_hood=np.asarray(before[tier]['hood_paint']);new_hood=np.asarray(after[tier]['hood_paint'])
    check(old_hood.shape==new_hood.shape,f'{tier} bonnet topology retained')
    check(np.max(abs(old_hood-new_hood))<2e-6,f'{tier} bonnet positions retained within native encoding precision')

profiles=json.loads((OUT/'corner-sections.json').read_text())
rolls=[]
for row in profiles:
    samples=row['samples'];a=np.asarray([p['angle'] for p in samples]);y=np.asarray([p['y'] for p in samples])
    check(len(samples)==241,f"{row['stage']}/{row['tier']}/{row['side']}/{row['z']} complete native corner section")
    lower=float(np.median(a[:20]));upper=float(np.median(a[-20:]));contrast=upper-lower
    def first(fraction):
        found=np.flatnonzero(a>=lower+contrast*fraction)
        return float(y[found[0]]) if len(found) else None
    lo,hi=first(.1),first(.9)
    rolls.append(dict(stage=row['stage'],tier=row['tier'],side=row['side'],z=row['z'],
                      contrast_degrees=contrast,transition_metres=hi-lo if hi is not None and lo is not None else None,
                      largest_half_mm_normal_step_degrees=float(np.diff(a).max())))
for tier in ['simple','full']:
    for side in [-1,1]:
        old=next(row for row in rolls if row['stage']=='before' and row['tier']==tier and row['side']==side and row['z']< -2.14)
        new=old if baseline else next(row for row in rolls if row['stage']=='candidate' and row['tier']==tier and row['side']==side and row['z']< -2.14)
        check(new['transition_metres']>=.008,f'{tier}/{side} front corner rolls over at least 8 mm')
        check(new['transition_metres']>2*old['transition_metres'],f'{tier}/{side} corner transition is visibly broader than task start')
        check(new['largest_half_mm_normal_step_degrees']<old['largest_half_mm_normal_step_degrees'],f'{tier}/{side} corner normal change is gentler than task start')
receipt={'checks':checks,'failures':len(failures),'findings':failures,'heights':heights,'normal_sections':rolls}
(OUT/('baseline-corner-check.json' if baseline else 'candidate-corner-check.json' if stage=='candidate' else 'final-corner-check.json')).write_text(json.dumps(receipt,indent=2))
print('NATIVE_CORNERS:',checks,'checks,',len(failures),'failures')
print('height drops mm',min(p['drop_metres'] for p in heights)*1000,max(p['drop_metres'] for p in heights)*1000)
for row in rolls:
    if row['tier']=='simple' and row['side']==1:print(row)
sys.exit(1 if failures else 0)
