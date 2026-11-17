from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
b=json.loads(Path('build/challenger-nose-lip-2026-11-17/baseline.json').read_text())
for tier in ['simple','full']:
 row=b[tier]['body_paint'];p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1];v=p[f];n=np.asarray(row['normals']);tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 print(tier,'remove upper',( (v[:,:,2].min(1)<-1.99)&(v[:,:,1].max(1)>.799-.010*(abs(v[:,:,0]).max(1)/.78)**6)).sum())
 for x in np.arange(0,.821,.04):
  y=.800-.010*(x/.78)**6
  hit,normal,*_=tree.ray_cast((float(x),float(y),-3),(0,0,1),1.2)
  h,*_=tree.ray_cast((float(x),2,-1.99),(0,-1,0),2)
  print(round(x,2),'cut',round(y,5), None if hit is None else list(hit),'back',None if h is None else list(h),flush=True)
