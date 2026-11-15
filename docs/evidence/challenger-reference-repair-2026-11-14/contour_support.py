from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
d=json.loads(Path('build/challenger-reference-repair-2026-11-14/decoded-restoration-final.json').read_text())
outline=json.loads(Path('build/challenger-reference-repair-2026-11-14/native/bonnet_contour.json').read_text())
path=np.asarray(outline['points'])[:,[0,2]];delta=np.roll(path,-1,axis=0)-path
for tier in ['full','simple']:
    h=d[tier]['hood_paint'];tree=BVHTree.FromPolygons(h['points'],np.asarray(h['indices']).reshape(-1,3).tolist(),all_triangles=True)
    p=np.asarray(d[tier]['body_contour']['points']);p=p[(p[:,2]<-.74)&(p[:,1]>.80)]
    missing=[];badfit=[]
    for point in p:
        hit,*_=tree.ray_cast((float(point[0]),float(point[1]+.03),float(point[2])),(0,-1,0),1)
        if hit is None:missing.append(point)
        rel=point[[0,2]]-path;t=np.clip(np.sum(rel*delta,axis=1)/np.maximum(np.sum(delta*delta,axis=1),1e-12),0,1)
        distance=np.min(np.linalg.norm(rel-delta*t[:,None],axis=1))
        if not .001<=distance<=.0045:badfit.append((point,distance*1000))
    print(tier,'missing',len(missing),'bad fit',len(badfit),flush=True)
    print('missing examples',np.round(np.asarray(missing[:8]),5).tolist(),flush=True)
    print('fit examples',[(np.round(p,5).tolist(),round(d,3)) for p,d in badfit[:8]],flush=True)
