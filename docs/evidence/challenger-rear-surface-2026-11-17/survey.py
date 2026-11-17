from pathlib import Path
import json,sys,numpy as np
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[3]
d=json.loads((root/'build/challenger-rear-surface-2026-11-17/baseline.json').read_text())
output={}
for tier in ['full','simple']:
 a=d[tier]['body_paint'];p=np.asarray(a['points']);f=np.asarray(a['indices']).reshape(-1,3)
 tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 rear=[];deck=[]
 for y in np.arange(.35,1.051,.005):
  for x in np.arange(0,.911,.005):
   hit,n,*_=tree.ray_cast((float(x),float(y),3),(0,0,-1),1)
   if hit is not None:rear.append([x,y,*hit,*n])
 for z in np.arange(1.25,2.241,.005):
  for x in np.arange(0,.881,.005):
   hit,n,*_=tree.ray_cast((float(x),2,float(z)),(0,-1,0),1.2)
   if hit is not None:deck.append([x,z,*hit,*n])
 output[tier]={'rear':rear,'deck':deck}
 for y in [.42,.55,.64,.69,.72,.74,.76,.78,.93,.96,.99,1.02]:
  row=[]
  for x in [0,.2,.4,.6,.7,.75,.8,.82,.84,.86,.88]:
   hit,n,*_=tree.ray_cast((x,y,3),(0,0,-1),1)
   row.append([x,None if hit is None else round(hit.z,5),None if n is None else [round(q,2) for q in n]])
  print(tier,y,row)
 print('DECK')
 for z in [1.3,1.4,1.5,1.6,1.8,2,2.08,2.12,2.16,2.20]:
  print(z,[(x,None if (h:=tree.ray_cast((x,2,z),(0,-1,0),1.2)[0]) is None else round(h.y,6)) for x in [0,.3,.5,.6,.65,.7,.72,.74,.76,.78,.8,.82,.84]])
(root/'build/challenger-rear-surface-2026-11-17/survey.json').write_text(json.dumps(output))
