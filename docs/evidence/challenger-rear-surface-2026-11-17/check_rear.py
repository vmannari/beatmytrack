"""Independent physical surveys of the actual packed rear skins."""
from pathlib import Path
import json,sys,numpy as np
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
build=root/'build'/out.name
stage=sys.argv[-1]
data=json.loads((build/(stage+'.json')).read_text())
base=json.loads((build/'baseline.json').read_text())
checks=[];metrics={}
def check(ok,label):
 checks.append({'passed':bool(ok),'label':label})
def mesh(item):
 p=np.asarray(item['points']);f=np.asarray(item['indices']).reshape(-1,3);n=np.asarray(item['normals'])
 return p,f,n,BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def hit(tree,p,f,n,origin,direction):
 q,_,face,_=tree.ray_cast(origin,direction,3)
 if q is None:return None
 a,b,c=p[f[face]];v=np.asarray(q)-a;u=b-a;w=c-a
 matrix=np.array([[u@u,u@w],[u@w,w@w]])
 try:s,t=np.linalg.solve(matrix,np.array([v@u,v@w]))
 except np.linalg.LinAlgError:return None
 normal=n[f[face][0]]*(1-s-t)+n[f[face][1]]*s+n[f[face][2]]*t
 normal/=max(np.linalg.norm(normal),1e-12)
 return np.asarray(q),normal
for tier in ['simple','full']:
 p,f,n,tree=mesh(data[tier]['body_paint'])
 shelf=[];angles=[];miss=0;inward=[]
 for x in np.linspace(-.725,.725,145):
  ref=hit(tree,p,f,n,(float(x),.72,3),(0,0,-1))
  if ref is None:miss+=1;continue
  for offset in [.025,.032]:
   q=hit(tree,p,f,n,(float(x),1,float(ref[0][2]-offset)),(0,-1,0))
   if q is None:miss+=1;continue
   shelf.append(q[0][1]);angles.append(np.degrees(np.arccos(np.clip(q[1][1],-1,1))))
 for y in [.697,.719,.739]:
  z=[]
  for x in np.linspace(-.725,.725,291):
   q=hit(tree,p,f,n,(float(x),y,3),(0,0,-1))
   z.append(np.nan if q is None else q[0][2])
  z=np.asarray(z)
  for step in [4,10,20]:inward.extend(((z[:-2*step]+z[2*step:])*.5-z[step:-step]).tolist())
 gaps=0;trunk=[]
 for x in np.linspace(.6503,.7297,81):
  for z in np.linspace(1.4931,1.9713,97):
   q=hit(tree,p,f,n,(float(x),2,float(z)),(0,-1,0))
   if q is None:gaps+=1
   else:trunk.append(q[0][1])
 bp,bf,bn,original_skin=mesh(base[tier]['body_paint'])
 protected=p[(p[:,2]<1.35)|((abs(p[:,0])>.84)&(p[:,2]<2))]
 errors=[original_skin.find_nearest(q)[3] for q in protected]
 protected_meshes=[]
 for name in data[tier]:
  if name in ['body_paint','body_contour']:continue
  a=data[tier][name];b=base[tier][name]
  pa,pb=np.asarray(a['points']),np.asarray(b['points'])
  na,nb=np.asarray(a['normals']),np.asarray(b['normals'])
  protected_meshes.append(a['indices']==b['indices'] and pa.shape==pb.shape and np.max(abs(pa-pb))<.00002 and np.max(abs(na-nb))<.0003)
 metrics[tier]={'shelf_samples':len(shelf),'shelf_misses':miss,'shelf_range_mm':float(np.ptp(shelf)*1000),'shelf_normal_max_degrees':float(max(angles)), 'shelf_normal_p95_degrees':float(np.percentile(angles,95)), 'bumper_inward_chord_mm':float(max(inward)*1000),'trunk_samples':81*97,'trunk_gaps':gaps,'protected_body_maximum_mm':float(max(errors)*1000),'other_meshes_within_native_precision':int(sum(protected_meshes)), 'other_mesh_arrays_exact':sum(data[tier][name]==base[tier][name] for name in data[tier] if name not in ['body_paint','body_contour'])}
 check(miss==0,tier+' continuous bumper shelf coverage')
 check(np.ptp(shelf)<.00015,tier+' level transverse shelf within 0.15 mm')
 check(max(angles)<1,tier+' shelf shading follows its physical horizontal surface')
 check(max(inward)<.0002,tier+' bumper chord convexity within 0.2 mm')
 check(gaps==0,tier+' trunk gutters have continuous paint backing')
 check(max(errors)<.00008,tier+' protected front and sides retain native precision')
 check(all(protected_meshes),tier+' other native meshes retain topology and native attribute precision')
 check(np.isfinite(p).all() and np.isfinite(n).all() and np.max(abs(np.linalg.norm(n,axis=1)-1))<.0001,tier+' finite geometry and unit normals')
report={'checks':len(checks),'failures':sum(not c['passed'] for c in checks),'metrics':metrics,'results':checks}
(out/(stage+'-rear.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
if stage!='baseline':assert report['failures']==0
