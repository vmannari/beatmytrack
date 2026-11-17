from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
root=Path.cwd();build=root/'build/challenger-convex-fenders-2026-11-16';out=root/'docs/evidence'/build.name
data=json.loads((build/'baseline.json').read_text());result={}
for tier in ['simple','full']:
 row=data[tier]['body_paint'];p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 top={};sides={}
 for x in [.60,.65,.70,.75,.80,.85,.88]:
  points=[]
  for z in np.arange(-2.10,-.749,.025):
   hit,normal,*_=tree.ray_cast((x,2,float(z)),(0,-1,0),2)
   if hit is not None and hit.y>.70:points.append([round(float(z),4),hit.y])
  top[str(x)]=points
 for z in [-2.08,-2.04,-2.0,-1.95,-1.85,-1.7,-1.5,-1.3,-1.1,-.9,-.8]:
  points=[]
  for y in np.arange(.75,1.005,.01):
   hit,normal,*_=tree.ray_cast((2,float(y),z),(-1,0,0),2)
   if hit is not None and hit.x>.6:points.append([round(float(y),3),hit.x])
  sides[str(z)]=points
 result[tier]={'top':top,'sides':sides}
 print(tier,{x:[[round(z,3),round(y,4)] for z,y in points[::4]] for x,points in top.items() if x in ['0.7','0.8','0.85']})
(out/'baseline-survey.json').write_text(json.dumps(result,indent=2))
