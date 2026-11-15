from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
d=json.loads(Path('build/challenger-reference-form-2026-11-15/candidate.json').read_text())
import sys
sys.path.insert(0,str(Path.cwd()/'scripts'))
from challenger_side_surface import Curve
line=Curve([-2.26,-1.90,-1.40,-.70,.25,.55,.95,1.30,1.75,2.20],[.755,.765,.792,.810,.822,.840,.904,.930,.930,.897])
for tier in ['full','simple']:
    b=d[tier]['body_paint'];p=np.array(b['points']);n=np.array(b['normals']);f=np.array(b['indices']).reshape(-1,3)
    tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    for z in [-2.13,-2.12,-2.11,-2.10,-2.09]:
        hit,_,i,_=tree.ray_cast((2,float(line(z)),z),(-1,0,0),2)
        q=p[f[i]];cross=-np.cross(q[1]-q[0],q[2]-q[0]);area=np.linalg.norm(cross)
        print(tier,z,'point',hit,'area',area,'geometric',cross/max(area,1e-20),'normals',n[f[i]],'vertices',q)
