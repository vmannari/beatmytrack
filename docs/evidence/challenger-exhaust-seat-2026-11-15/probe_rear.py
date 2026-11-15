from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
p=Path('build/challenger-exhaust-seat-2026-11-15/baseline.json');d=json.loads(p.read_text())
for tier in ['simple','full']:
 points=[];faces=[];n=0
 for name in ['body_paint','body_accent','body_dark']:
  r=d[tier][name];points.extend(r['points']);faces.extend((np.asarray(r['indices']).reshape(-1,3)+n).tolist());n+=len(r['points'])
 tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
 for x in [-.515,.525]:
  print(tier,x)
  for y in np.arange(.28,.631,.02):
   hit,normal,*_=tree.ray_cast((x,float(y),3),(0,0,-1),1.5)
   print(round(float(y),3),None if hit is None else [round(v,4) for v in hit],None if normal is None else [round(v,3) for v in normal])
