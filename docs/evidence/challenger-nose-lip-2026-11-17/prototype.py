from pathlib import Path
import json,sys,numpy as np
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-nose-lip-2026-11-17'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_front_surface import LeadingRoll,seal_front_cracks,tree_for
base=json.loads((BUILD/'baseline.json').read_text());outline=json.loads((ROOT/'game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json').read_text())['points']
result={};statistics={}
def records(row):
 p=np.asarray(row['points']);n=np.asarray(row['normals']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 return np.concatenate([p[f],n[f]],axis=2)
for tier in ['full','simple']:
 body=records(base[tier]['body_paint']);hood=records(base[tier]['hood_paint'])
 body,cracks=seal_front_cracks(body)
 from challenger_convex_fenders import ConvexFender
 profile_path=BUILD/'converted/full_convex-field.json'
 crown=ConvexFender(np.concatenate([body,hood]),json.loads(profile_path.read_text())) if profile_path.exists() else None
 field=LeadingRoll(body,hood,crown)
 out,stats=field.rebuild(body,tier=='simple')
 stats['cracks']=cracks
 moved,hood_delta=field.map_hood(hood)
 out,micro=seal_front_cracks(out,micro=True);stats["boundary_seating"]=micro
 out,closure=seal_front_cracks(out,close_only=True);stats["boundary_closure"]=closure
 import challenger_clean_panels as panels
 right=panels._positive(out);right=right[abs(right[:,:,0]).max(1)>1e-7]
 _,vid=np.unique(np.round(right.reshape(-1,6),7),axis=0,return_inverse=True)
 _,keep=np.unique(np.sort(vid.reshape(-1,3),axis=1),axis=0,return_index=True)
 out=panels._symmetric(right[np.sort(keep)])
 vertices=out.reshape(-1,6)
 result[tier]={'body_paint':{'points':vertices[:,:3].tolist(),'normals':vertices[:,3:].tolist(),'indices':np.arange(len(vertices)).reshape(-1,3)[:,::-1].ravel().tolist()}}
 moved,hood_delta=field.map_hood(hood);flat=moved.reshape(-1,6)
 result[tier]['hood_paint']={'points':flat[:,:3].tolist(),'normals':flat[:,3:].tolist(),'indices':np.arange(len(flat)).reshape(-1,3)[:,::-1].ravel().tolist()}
 contour=base[tier]['body_contour']
 cp=np.asarray(contour['points']).copy();cn=np.asarray(contour['normals']).copy();tree=tree_for(moved)
 for i,point in enumerate(cp):
  if point[2]>=field.REAR or point[1]<.74:continue
  hit,normal,*_=tree.ray_cast((float(point[0]),2,float(point[2])),(0,-1,0),2)
  if hit is not None:cp[i,1]=hit.y+.0018;cn[i]=np.asarray(normal)*(1 if normal.y>=0 else -1)
 result[tier]['body_contour']={'points':cp.tolist(),'normals':cn.tolist(),'indices':contour['indices']}
 stats['hood_maximum_metres']=hood_delta
 statistics[tier]=stats;print('LEADING_ROLL',tier,stats,flush=True)
(BUILD/'prototype.json').write_text(json.dumps(result,separators=(',',':')))
(BUILD/'prototype-stats.json').write_text(json.dumps(statistics,indent=2))
