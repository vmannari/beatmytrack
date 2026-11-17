"""Independent physical chord and native perimeter coverage checks."""
from pathlib import Path
import json,sys,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-convex-fenders-2026-11-16';BUILD=ROOT/'build'/OUT.name
label=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'candidate'
before=json.loads((BUILD/'baseline.json').read_text());after=json.loads((BUILD/(label+'.json')).read_text())
outline=np.asarray(json.loads((BUILD/'native/bonnet_contour.json').read_text())['points'])
checks=[];metrics={}
def check(value,name):checks.append({'name':name,'pass':bool(value)})
def tree(row):
 p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 return BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def height(surface,x,z):
 p,*_=surface.ray_cast((float(x),2,float(z)),(0,-1,0),2)
 return None if p is None or p.y<.74 else float(p.y)
def inner(z):
 a=outline;b=np.roll(outline,-1,axis=0)
 selected=(((a[:,2]<=z)&(b[:,2]>=z))|((b[:,2]<=z)&(a[:,2]>=z)))&(abs(b[:,2]-a[:,2])>1e-9)
 ids=np.flatnonzero(selected)
 return max(.60,max((a[ids,0]+(z-a[ids,2])/(b[ids,2]-a[ids,2])*(b[ids,0]-a[ids,0])).tolist(),default=.60))
for tier in ['simple','full']:
 old=tree(before[tier]['body_paint']);new=tree(after[tier]['body_paint'])
 comparisons=[]
 for x in np.arange(.75,.871,.01):
  for z in np.arange(-2.015,-.94,.025):
   for dx,dz in [(0,.025),(0,.05),(.010,0),(.015,.035),(.015,-.035)]:
    stations=[(x-dx,z-dz),(x,z),(x+dx,z+dz)]
    # This is the continuous crown domain: exclude the deliberate hood gap,
    # upright fascia rim and the shoulder boundary from the chord test.
    if any(px<inner(pz)+.004 or pz< -2.06 or pz> -.87 for px,pz in stations):continue
    a=[height(old,*point) for point in stations];b=[height(new,*point) for point in stations]
    belt=lambda z:.767+.038*(z+2.065)/1.205
    if None in a or None in b or any(v<belt(pz)+.004 for v,(_,pz) in zip(b,stations)):continue
    comparisons.append({'x':float(x),'z':float(z),'direction':[dx,dz],
      'before_mm':max(0,(a[0]+a[2])*.5-a[1])*1000,
      'after_mm':max(0,(b[0]+b[2])*.5-b[1])*1000})
 check(len(comparisons)>500,tier+' dense fixed-footprint geometric chord survey')
 worst_old=max(row['before_mm'] for row in comparisons);worst_new=max(row['after_mm'] for row in comparisons)
 check(worst_new<.20,tier+' native crown is convex within 0.20mm packing tolerance')
 check(worst_new<.10*worst_old,tier+' physical dent reduced by more than 90 percent')
 tangent=np.roll(outline[:,[0,2]],-1,axis=0)-np.roll(outline[:,[0,2]],1,axis=0)
 direction=np.c_[tangent[:,1],-tangent[:,0]];direction/=np.linalg.norm(direction,axis=1)[:,None]
 query=outline[:,[0,2]]+direction*.006
 supported=sum(height(new,x,z) is not None for x,z in query)
 check(supported==len(outline),tier+' paint support outside all existing bonnet perimeter stations')
 metrics[tier]={'samples':len(comparisons),'before_maximum_dent_mm':worst_old,'after_maximum_dent_mm':worst_new,
 'perimeter_supported':supported,'perimeter_stations':len(outline),'worst':sorted(comparisons,key=lambda r:r['after_mm'],reverse=True)[:12]}
result={'checks':len(checks),'failures':sum(not row['pass'] for row in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-seams-corners.json')).write_text(json.dumps(result,indent=2))
print('CHALLENGER_CONVEX_CROWN',result['checks'],'checks',result['failures'],'failures')
for row in checks:
 if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
