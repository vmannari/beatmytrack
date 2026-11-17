import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
w=Path(__file__).resolve().parents[1]/'build/car-pass12-2026-11-16'
g=json.loads((w/'proof-geometry.json').read_text())
key=next(k for k in g if k.startswith('compact_') and 'regular28lift0.0012' in k)
s=g[key]['surfaces'][0]
old=[Vector(p) for p in s['before']];new=[Vector(p) for p in s['after']]
of=[s['before_indices'][a:a+3] for a in range(0,len(s['before_indices']),3)];nf=[s['after_indices'][a:a+3] for a in range(0,len(s['after_indices']),3)]
for p,f,q,t,label in [(old,of,new,nf,'forward'),(new,nf,old,of,'reverse')]:
 tree=BVHTree.FromPolygons(q,t,all_triangles=True);samples=p+[sum((p[i] for i in tri),Vector())/3 for tri in f];hit,point=max(((tree.find_nearest(p),p) for p in samples),key=lambda row:row[0][3]);print('CP2_WORST',label,hit[3],list(point),list(hit[0]),[list(q[i]) for i in t[hit[2]]])
