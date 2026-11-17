from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
root=Path.cwd();build=root/'build/challenger-hood-redesign-2026-11-16'
a=json.loads((build/'native13.json').read_text());b=json.loads((build/'prototype.json').read_text());result={}
for tier in ['simple','full']:
 result[tier]={}
 for label,data in [('before',a[tier]),('after',b[tier])]:
  points=[];faces=[]
  for name in ['body_paint','hood_paint']:
   row=data[name];pp=np.asarray(row['points']);ff=np.asarray(row['indices']).reshape(-1,3)[:,::-1];faces.extend((ff+len(points)).tolist());points.extend(pp.tolist())
  tree=BVHTree.FromPolygons(points,faces,all_triangles=True);curves={}
  for x in [.70,.74,.77,.80]:
   samples=[]
   for z in np.arange(-2.105,-1.929,.005):
    hit,*_=tree.ray_cast((x,2,float(z)),(0,-1,0),2)
    if hit is not None and hit.y>.75:samples.append([float(z),hit.y])
   changes=np.diff(np.asarray(samples)[:,1]) if len(samples)>1 else []
   curves[str(x)]={'samples':samples,'minimum_rearward_rise_mm':float(min(changes)*1000) if len(changes) else None}
  result[tier][label]=curves
print(json.dumps({t:{l:{x:v['minimum_rearward_rise_mm'] for x,v in curves.items()} for l,curves in m.items()} for t,m in result.items()},indent=2))
(root/'docs/evidence/challenger-hood-redesign-2026-11-16/corner-audit.json').write_text(json.dumps(result,indent=2))
