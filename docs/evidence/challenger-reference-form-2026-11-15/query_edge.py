from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
d=json.loads(Path('build/challenger-reference-form-2026-11-15/candidate-form.json').read_text())
for tier in ['full','simple']:
    h=d[tier]['hood_paint'];p=np.array(h['points']);f=np.array(h['indices']).reshape(-1,3)
    tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    for point in [(-.73800240318835,-1.6164900652480874),(-.7379266229328617,-1.615833030520844)]:
        x,z=point;hit=tree.ray_cast((x,2,z),(0,-1,0),3)[0]
        a=p[f[:,0]][:,[0,2]];b=p[f[:,1]][:,[0,2]]-a;c=p[f[:,2]][:,[0,2]]-a;v=np.array(point)-a
        det=b[:,0]*c[:,1]-b[:,1]*c[:,0];valid=abs(det)>1e-16
        s=np.full(len(f),-100.);t=s.copy()
        s[valid]=(v[valid,0]*c[valid,1]-v[valid,1]*c[valid,0])/det[valid]
        t[valid]=(b[valid,0]*v[valid,1]-b[valid,1]*v[valid,0])/det[valid]
        ids=np.flatnonzero((s>=-1e-8)&(t>=-1e-8)&(s+t<=1+1e-8))
        nearest=tree.find_nearest((x,.95,z))
        print(tier,point,'ray',hit,'direct',ids.tolist(),'nearest',nearest)
