from pathlib import Path
import json,sys,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-convex-fenders-2026-11-16'
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_clean_panels as panels
from challenger_reference_form import front_scale
from challenger_side_finish import front_z
from challenger_nose_finish import point_map
base=json.loads((BUILD/'baseline.json').read_text());candidate=json.loads((BUILD/'candidate.json').read_text());out={};trees={}
for tier in ['simple','full']:
 row=candidate[tier]['hood_paint'];p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 trees[tier]=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
 row=base[tier]['body_contour'];p=np.asarray(row['points']);new=p.copy()
 for i,point in enumerate(p):
  if point[1]>.80 and point[2]<-.74:
   hit,*_=trees[tier].ray_cast((float(point[0]),2,float(point[2])),(0,-1,0),2)
   if hit is not None:new[i,1]=hit.y+.0018
 out[tier]=new.tolist()
(BUILD/'trial-contours.json').write_text(json.dumps(out,separators=(',',':')))
profile=json.loads((BUILD/'native/hood_profile.json').read_text());px,pz=np.meshgrid(profile['x'],profile['z'],indexing='ij')
# Recover the existing attachment-domain plan coordinates.
attachment=panels.world(np.c_[px.ravel(),np.zeros(px.size),pz.ravel()])
attachment[:,1]=np.asarray(profile['heights']).ravel();attachment[:,0]*=front_scale(attachment[:,2]);attachment[:,2]=front_z(attachment[:,2])
final=point_map(attachment);heights=np.asarray(profile['heights']).ravel();offset=np.zeros_like(attachment);offset[:,1]=.0001
derivative=(point_map(attachment+offset)[:,1]-point_map(attachment-offset)[:,1])/.0002
for i,point in enumerate(final):
 if abs(point[0])>.50 and -2.11<point[2]<-.70:
  hit,*_=trees['full'].ray_cast((float(point[0]),2,float(point[2])),(0,-1,0),2)
  if hit is not None:heights[i]+=(hit.y-point[1])/derivative[i]
profile['heights']=np.round(heights.reshape(px.shape),7).tolist()
(BUILD/'trial-profile.json').write_text(json.dumps(profile,separators=(',',':')))
print('TRIAL_SURFACE_SEATING_COMPLETE')
