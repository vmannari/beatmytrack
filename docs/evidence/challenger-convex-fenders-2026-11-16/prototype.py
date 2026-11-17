from pathlib import Path
import ast,json,math,sys
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
import numpy as np
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-convex-fenders-2026-11-16'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_convex_fenders import ConvexFender,FenderPatch
source=ast.parse((ROOT/"scripts/prepare_challenger.py").read_text())
functions=[node for node in source.body if isinstance(node,ast.FunctionDef) and node.name in ["inside_polygon","lattice"]]
exec(compile(ast.Module(body=functions,type_ignores=[]),"existing_lattice","exec"))
outline=json.loads((ROOT/"game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json").read_text())["points"]
baseline=json.loads((BUILD/'baseline.json').read_text())
def values(row):
 p=np.asarray(row['points']);n=np.asarray(row['normals']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 return np.concatenate([p[f],n[f]],axis=2)
shared=None
result={};metrics={}
for tier in ['full','simple']:
 body=values(baseline[tier]['body_paint']);hood=values(baseline[tier]['hood_paint'])
 patch=FenderPatch(body,hood,outline,shared)
 shared=patch.field.profile()
 result[tier]={};metrics[tier]={}
 def packet(records):
  flat=records.reshape(-1,6)
  return {'points':flat[:,:3].tolist(),'normals':flat[:,3:].tolist(),'indices':np.arange(len(flat)).reshape(-1,3)[:,::-1].ravel().tolist()}
 trimmed,credit=patch.buried_hood_skirts(hood)
 rebuilt,stats=patch.rebuild(tier=='simple',lattice,credit)
 stats['buried_hood_skirt_triangles_removed']=credit
 result[tier]['body_paint']=packet(rebuilt);metrics[tier]['body_paint']=stats
 for name in ['hood_paint','hood_dark']:
  source=trimmed if name=='hood_paint' else values(baseline[tier][name])
  moved,maximum=patch.transform(source,patch.hood_point,crown=name=='hood_paint')
  result[tier][name]=packet(moved);metrics[tier][name]={'maximum_mm':maximum*1000}
 row=baseline[tier]['body_contour'];points=np.asarray(row['points']);normals=np.asarray(row['normals']);newp=[]
 for point in points:
  if point[1]>patch.belt(point[2]):newp.append(patch.hood_point(point))
  else:newp.append(patch.body_point(point))
 result[tier]['body_contour']={'points':np.asarray(newp).tolist(),'normals':normals.tolist(),'indices':row['indices']}
 print('CONVEX_FENDER',tier,metrics[tier],flush=True)
(BUILD/'prototype.json').write_text(json.dumps(result,separators=(',',':')))
(BUILD/'prototype-field.json').write_text(json.dumps({'profile':shared,'metrics':metrics},indent=2))
