from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[3]
d=json.loads((root/'build/challenger-rear-surface-2026-11-17/candidate.json').read_text())
for tier in ['full','simple']:
 a=d[tier]['body_paint'];p=np.asarray(a['points']);f=np.asarray(a['indices']).reshape(-1,3)
 tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 worst=(-1,None)
 xs=np.linspace(-.725,.725,291)
 for y in [.697,.719,.739]:
  hits=[tree.ray_cast((float(x),y,3),(0,0,-1),3) for x in xs]
  z=np.array([h[0].z for h in hits])
  for step in [4,10,20]:
   error=(z[:-2*step]+z[2*step:])*.5-z[step:-step]
   i=int(error.argmax())+step
   if error.max()>worst[0]:worst=(float(error.max()),(float(xs[i]),y,step,p[f[hits[i][2]]].tolist()))
 print(tier,worst)
