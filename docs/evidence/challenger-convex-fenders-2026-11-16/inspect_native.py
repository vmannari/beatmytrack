import json,numpy as np
from pathlib import Path
from mathutils.kdtree import KDTree
B=Path('build/challenger-convex-fenders-2026-11-16')
a=json.loads((B/'baseline.json').read_text());b=json.loads((B/'candidate.json').read_text())
for tier in ['simple','full']:
 old=np.asarray(a[tier]['hood_paint']['points']);p=np.asarray(b[tier]['hood_paint']['points']);n=np.asarray(b[tier]['hood_paint']['normals']);f=np.asarray(b[tier]['hood_paint']['indices']).reshape(-1,3)[:,::-1]
 tree=KDTree(len(p))
 for i,v in enumerate(p):tree.insert(v,i)
 tree.balance();rows=[]
 for v in old[abs(old[:,0])<.4]:
  q,i,d=tree.find(v);rows.append((d*1000,v.tolist(),p[i].tolist(),((p[i]-v)*1000).tolist()))
 print('CENTRE',tier,sorted(rows,reverse=True)[:4],flush=True)
 cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]]);size=np.linalg.norm(cross,axis=1);agreement=np.sum(n[f].mean(1)*cross,axis=1)/np.maximum(size,1e-20)
 bad=np.flatnonzero((agreement<-.03)&(size>1e-7))
 print('BAD_HOOD_NORMALS',tier,len(bad),flush=True)
 for i in bad[:8]:print(float(agreement[i]),p[f[i]].tolist(),n[f[i]].tolist(),flush=True)
