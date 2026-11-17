from pathlib import Path
import json,numpy as np,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from challenger_convex_fenders import ConvexFender
b=json.loads((root/'build/challenger-convex-fenders-2026-11-16/baseline.json').read_text())['full']['body_paint'];p=np.asarray(b['points']);n=np.asarray(b['normals']);f=np.asarray(b['indices']).reshape(-1,3)[:,::-1]
v=np.concatenate([p[f],n[f]],axis=2);field=ConvexFender(v)
cross=np.cross(v[:,1,:3]-v[:,0,:3],v[:,2,:3]-v[:,0,:3]);c=v[:,:,:3].mean(1);sel=(cross[:,0]>1e-12)&(c[:,0]>.55)&(c[:,1]>.73)&(c[:,2]>-2.12)&(c[:,2]<-.70)
s=v[sel,:,:3].reshape(-1,3);bounds=field.planes[:,0]+s[:,1,None]*field.planes[:,1]+s[:,2,None]*field.planes[:,2]
print('hull violations',np.min(bounds-s[:,0,None]),'range',s.min(0),s.max(0))
for point in [[.75,.82,-2.05],[.80,.86,-1.7],[.80,.9,-1.3],[.76,.97,-.8]]:
 print(point,'old',field.old_width(point),'new',field.width(point[1],point[2]))
q,_,_=field.map(p);d=np.linalg.norm(q-p,axis=1);ids=np.argsort(d)[-8:];print('worst',[(p[i].tolist(),q[i].tolist(),float(d[i])) for i in ids])
