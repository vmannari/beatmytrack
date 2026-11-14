"""Renderer-triangle coverage, shape controls and measured reflection fairness.

The early profile diagnostic compares against the old unsmoothed width field.
This check measures the requested fairing itself, without requiring that old
field's small waves to survive. Existing nose/shoulder/bonnet gates run separately.
"""
from pathlib import Path
import json, sys
import numpy as np

OUT=Path(__file__).resolve().parent
scope={'__file__':str(OUT/'check_shell.py')}
exec((OUT/'check_shell.py').read_text().split('stages=')[0],scope)
BUILD=scope['BUILD'];reference=scope['reference'];section=scope['section']
data={s:json.loads((BUILD/('native-plan-'+s+'.json')).read_text()) for s in ['before','candidate']}
checks=0;findings=[];rows=[]
def check(ok,label):
    global checks
    checks+=1
    if not ok:findings.append(label)

for tier in ['simple','full']:
    old=np.asarray(data['before'][tier]['body_paint']).reshape(-1,3,3)
    new=np.asarray(data['candidate'][tier]['body_paint']).reshape(-1,3,3)
    check(len(new)<len(old),tier+' painted shell has fewer triangles')
    for extreme in [np.min,np.max]:
        check(np.max(abs(extreme(old,axis=(0,1))-extreme(new,axis=(0,1))))<.00001,tier+' exterior extents unchanged')
    roof=np.unique(np.round(old.reshape(-1,3)[old.reshape(-1,3)[:,1]>=1.04],6),axis=0)
    candidate_roof=np.unique(np.round(new.reshape(-1,3)[new.reshape(-1,3)[:,1]>=1.03999],6),axis=0)
    # Quantised native positions can straddle one micron rounding boundaries.
    missing=0
    for start in range(0,len(roof),128):
        delta=np.linalg.norm(roof[start:start+128,None,:]-candidate_roof[None,:,:],axis=-1)
        missing+=int(np.count_nonzero(delta.min(1)>.000003))
    check(missing==0,f'{tier}: all original roof/upper-pillar vertices retained ({missing} missing)')
    check(data['before'][tier]['hood_paint']==data['candidate'][tier]['hood_paint'],tier+' bonnet positions and topology exact')
    for sign in [-1,1]:
        for offset in [-.010,.012,.035]:
            zs=np.linspace(-1.35,1.70,306)
            ys=reference.crease(zs)+offset
            samples={}
            for stage in ['before','candidate']:
                tri=np.asarray(data[stage][tier]['body_paint']).reshape(-1,3,3)
                ns=np.asarray(data[stage][tier]['body_paint_normals']).reshape(-1,3,3)
                samples[stage]=[section(tri,ns,float(y),float(z),sign) for y,z in zip(ys,zs)]
                missing=sum(p is None for p in samples[stage])
                check(missing==0,f'{tier}/{sign}/{offset}/{stage}: complete native shoulder coverage')
            if any(p is None for s in samples.values() for p in s):continue
            a,b=samples['before'],samples['candidate']
            displacement=np.asarray([q[0]-p[0] for p,q in zip(a,b)])
            check(float(np.max(abs(displacement)))<.010,f'{tier}/{sign}/{offset}: fairing stays within 10 mm of previous shell')
            row={'tier':tier,'side':sign,'offset':offset,'max_displacement_mm':float(np.max(abs(displacement))*1000)}
            for stage in ['before','candidate']:
                normals=np.asarray([p[1] for p in samples[stage]])
                row[stage+'_normal_jitter']=float(np.mean(np.diff(normals,n=2,axis=0)**2))
            rows.append(row)
before=sum(r['before_normal_jitter'] for r in rows)
after=sum(r['candidate_normal_jitter'] for r in rows)
check(after<before*.80,'aggregate native reflection-normal jitter falls by at least 20%')
receipt={'checks':checks,'failures':len(findings),'findings':findings,'sections':rows,
         'normal_jitter_reduction_fraction':1-after/before if before else None}
(OUT/'native-acceptance.json').write_text(json.dumps(receipt,indent=2))
print('NATIVE_ACCEPTANCE:',checks,'checks,',len(findings),'failures; normal jitter reduction',receipt['normal_jitter_reduction_fraction'])
print('\n'.join(findings))
sys.exit(1 if findings else 0)
