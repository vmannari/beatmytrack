from pathlib import Path
import json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-nose-lip-2026-11-17';OUT=ROOT/'docs/evidence'/BUILD.name
data=json.loads((BUILD/'baseline.json').read_text());result={}
for tier in ['simple','full']:
 trees={};records={}
 for name in ['body_paint','hood_paint','body_dark']:
  r=data[tier][name];p=np.asarray(r['points']);f=np.asarray(r['indices']).reshape(-1,3)[:,::-1];records[name]=(p,f)
  trees[name]=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 sections=[]
 for x in [0,.2,.4,.6,.7,.75,.80]:
  front=[]
  for y in np.arange(.75,.851,.001):
   h,n,*_=trees['body_paint'].ray_cast((float(x),float(y),-3),(0,0,1),1.1)
   if h is not None:front.append([float(y),float(h.z),float(n.z)])
  top=[]
  for z in np.arange(-2.11,-1.949,.005):
   hits=[t.ray_cast((float(x),2,float(z)),(0,-1,0),2)[0] for k,t in trees.items() if k!='body_dark']
   ys=[h.y for h in hits if h is not None and h.y>.74]
   top.append([float(z),max(ys) if ys else None])
  sections.append({'x':x,'front':front,'top':top})
 p,f=records['body_paint'];unique,ids=np.unique(np.round(p,6),axis=0,return_inverse=True);f=ids[f]
 edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1);edge,count=np.unique(edges,axis=0,return_counts=True);bound=edge[count==1];points=unique[bound];middle=points.mean(1)
 choose=(middle[:,0]>.6)&(middle[:,2]<-1.75)&(middle[:,1]>.53)&(middle[:,1]<.86)
 points=points[choose];length=np.linalg.norm(points[:,1]-points[:,0],axis=1);order=np.argsort(-length)
 result[tier]={'sections':sections,'boundary_edges':points[order].tolist()}
 print(tier,'BOUNDARIES',len(points),flush=True)
 for s in sections:
  print('FRONT_TOP',s['x'],s['front'][:3],s['front'][-3:],flush=True)
 print('LONG_BOUNDARIES',points[order[:12]].tolist(),flush=True)
(OUT/'baseline-nose-survey.json').write_text(json.dumps(result,indent=2))
