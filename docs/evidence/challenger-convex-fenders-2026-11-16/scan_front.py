from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
r=json.loads(Path('build/challenger-convex-fenders-2026-11-16/baseline.json').read_text())['full']['body_paint'];p=np.asarray(r['points']);f=np.asarray(r['indices']).reshape(-1,3)[:,::-1];tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
for z in [-2.075,-2.065,-2.055,-2.045,-2.035,-2.025,-2.01,-1.99,-1.95,-1.9]:
 rows=[]
 for y in np.arange(.68,.821,.0025):
  hit,*_=tree.ray_cast((2,float(y),z),(-1,0,0),2)
  if hit is not None and hit.x>.6:rows.append([round(float(y),4),round(hit.x,4)])
 print(z,rows)
