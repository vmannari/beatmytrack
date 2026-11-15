from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-continuous-side-2026-11-15'
data=json.loads((BUILD/'baseline.json').read_text())['full']['body_paint']
p=np.asarray(data['points']);f=np.asarray(data['indices']).reshape(-1,3)
tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
rows=[]
for z in np.linspace(-2.18,2.14,19):
    samples=[]
    for y in np.linspace(.32,1.12,161):
        hit,n,*_=tree.ray_cast((2,float(y),float(z)),(-1,0,0),2)
        if hit is not None and hit.x>.65:samples.append([y,hit.x,-n.x,-n.y,-n.z])
    a=np.asarray(samples);peak=a[np.argmax(a[:,1])] if len(a) else []
    rows.append({'z':float(z),'peak':list(peak),'samples':samples})
    print('SECTION',round(z,3),'peak',np.round(peak,4).tolist(),flush=True)
(BUILD/'sections.json').write_text(json.dumps(rows))
