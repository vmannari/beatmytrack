"""Independent packed-asset checks for the marked nose and bonnet banks."""
from pathlib import Path
import importlib.util
import json,sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-hood-redesign-2026-11-16';BUILD=ROOT/'build'/OUT.name
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_nose_finish as updated
spec=importlib.util.spec_from_file_location('preceding_nose',BUILD/'before/scripts/challenger_nose_finish.py')
preceding=importlib.util.module_from_spec(spec);spec.loader.exec_module(preceding)
label=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'candidate'
old=json.loads((BUILD/'baseline.json').read_text());new=json.loads((BUILD/(label+'.json')).read_text())
outline=json.loads((BUILD/'native/bonnet_contour.json').read_text())['points']
outline=np.asarray(outline);checks=[];metrics={}
def check(value,name):checks.append({'name':name,'pass':bool(value)})
def surface(row):
 p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
 return BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def coverage(tree):
 tangent=np.roll(outline[:,[0,2]],-1,axis=0)-np.roll(outline[:,[0,2]],1,axis=0)
 direction=np.c_[tangent[:,1],-tangent[:,0]];direction/=np.linalg.norm(direction,axis=1)[:,None]
 points=outline[:,[0,2]]+direction*.006
 hits=[tree.ray_cast((float(x),2,float(z)),(0,-1,0),2)[0] for x,z in points]
 return sum(point is not None and point.y>.72 for point in hits),len(hits)
for tier in ['simple','full']:
 p=np.asarray(old[tier]['body_paint']['points']);selected=(abs(p[:,0])>.66)&(abs(p[:,0])<.86)&(p[:,1]>.78)&(p[:,2]<-2.02)&(p[:,2]>-2.11)
 reference=np.unique(p[selected],axis=0);source=reference.copy()
 for _ in range(24):source+=reference-preceding.point_map(source)
 expected=updated.point_map(source)
 actual=np.asarray(new[tier]['body_paint']['points']);tree=KDTree(len(actual))
 for i,point in enumerate(actual):tree.insert(point,i)
 tree.balance();errors=[tree.find(point)[2] for point in expected]
 drop=reference[:,1]-expected[:,1]
 check(len(reference)>30,tier+' substantial native front-corner landmarks')
 check(min(drop)>.003 and max(drop)<=.008001,tier+' both marked corner crowns lowered within eight millimetres')
 check(max(errors)<.00020,tier+' corrected front-corner positions survive native packing')
 check(np.max(abs(expected[:,[0,2]]-reference[:,[0,2]]))<1e-8,tier+' corner width and longitudinal placement retained')
 before=coverage(surface(old[tier]['body_paint']));after=coverage(surface(new[tier]['body_paint']))
 check(after[0]==after[1],tier+' continuous paint bank six millimetres outside every bonnet station')
 metrics[tier]={'landmarks':len(reference),'minimum_drop_mm':float(min(drop)*1000),'maximum_drop_mm':float(max(drop)*1000),'maximum_packing_error_mm':float(max(errors)*1000),'bank_before':before,'bank_after':after}
result={'checks':len(checks),'failures':sum(not row['pass'] for row in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-seams-corners.json')).write_text(json.dumps(result,indent=2))
print('CHALLENGER_SEAMS_CORNERS',result['checks'],'checks',result['failures'],'failures')
for row in checks:
 if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
