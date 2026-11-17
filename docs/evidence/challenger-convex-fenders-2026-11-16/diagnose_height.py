from pathlib import Path
import json,numpy as np,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from challenger_convex_fenders import ConvexFender
b=json.loads((root/'build/challenger-convex-fenders-2026-11-16/baseline.json').read_text())['full']
vs=[]
for name in ['body_paint','hood_paint']:
 r=b[name];p=np.asarray(r['points']);n=np.asarray(r['normals']);f=np.asarray(r['indices']).reshape(-1,3)[:,::-1];vs.append(np.concatenate([p[f],n[f]],axis=2))
field=ConvexFender(np.concatenate(vs));print('affine',field.affine)
for x,z in field.ANCHORS.tolist()+[[.75,-2.05],[.80,-2.0],[.75,-1.8],[.8,-1.7],[.8,-1.3],[.75,-.9]]:
 old=field.old_height([x,.9,z]);new=field.height(x,z);print(x,z,old,new)
r=b['body_paint'];p=np.asarray(r['points']);q,_,_=field.map(p);d=np.linalg.norm(q-p,axis=1);ids=np.argsort(d)[-5:];print([(p[i].tolist(),q[i].tolist(),float(d[i])) for i in ids])
