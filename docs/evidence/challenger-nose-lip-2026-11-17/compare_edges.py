from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
b=json.loads(Path('build/challenger-nose-lip-2026-11-17/baseline.json').read_text())['simple']
trees={}
for name in ['body_paint','hood_paint']:
 p=np.asarray(b[name]['points']);f=np.asarray(b[name]['indices']).reshape(-1,3)[:,::-1];trees[name]=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
for z in [-2.035,-2.025,-2.01,-1.99,-1.97,-1.95,-1.92,-1.90]:
 print('Z',z,flush=True)
 for x in [.0,.5,.60,.64,.66,.67,.675,.68,.69,.70,.72,.75]:
  h=[]
  for tree in trees.values():
   hit,*_=tree.ray_cast((x,2,z),(0,-1,0),2);h.append(None if hit is None else round(hit.y,5))
  print(x,h,end=' | ')
 print('',flush=True)
