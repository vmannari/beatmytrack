from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-convex-fenders-2026-11-16';OUT=ROOT/'docs/evidence'/BUILD.name
results={}
for label in ['baseline','prototype']:
 data=json.loads((BUILD/(label+'.json')).read_text());results[label]={}
 for tier in ['simple','full']:
  points=[];faces=[]
  for name in ['body_paint','hood_paint']:
   row=data[tier][name];p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
   faces.extend((f+len(points)).tolist());points.extend(p.tolist())
  tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
  def h(x,z):
   hit,*_=tree.ray_cast((float(x),2,float(z)),(0,-1,0),2)
   return None if hit is None or hit.y<.74 else float(hit.y)
  rows=[]
  for x in np.arange(.70,.861,.02):
   for z in np.arange(-2.055,-.89,.025):
    for dx,dz in [(0,.025),(0,.050),(0,.100),(.015,0),(.025,0),(.015,.035),(.015,-.035)]:
     values=[h(x-dx,z-dz),h(x,z),h(x+dx,z+dz)]
     if None not in values:rows.append({'x':float(x),'z':float(z),'direction':[dx,dz],'dent_mm':max(0,(values[0]+values[2])*.5-values[1])*1000})
  rows.sort(key=lambda row:row['dent_mm'],reverse=True)
  results[label][tier]={'samples':len(rows),'maximum_dent_mm':rows[0]['dent_mm'],'p95_dent_mm':float(np.percentile([r['dent_mm'] for r in rows],95)),'worst':rows[:12]}
  print(label,tier,'samples',len(rows),'max_mm',rows[0]['dent_mm'],'worst',rows[0])
(OUT/'convexity-development.json').write_text(json.dumps(results,indent=2))
