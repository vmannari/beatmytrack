from pathlib import Path
import sys,json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_form import ReferenceForm
from challenger_side_surface import Curve
from challenger_surface_quality import UpperWing
source=json.loads((ROOT/'game/assets/vehicles/challenger_hellcat_v1/source.json').read_text())
side=source['tiers']['simple']['clean_panels']['manufactured_exterior']['continuous_side']
r=ReferenceForm.__new__(ReferenceForm);r.side_crease=Curve(side['crease_z'],side['crease_y']);r.wing_width=Curve(side['z'],side['widths']);r.base=Curve([-2.30,-2.22,-2.10,-1.80,-1.35,-.95,-.72],[.805,.853,.898,.934,.964,.971,.982])
field=UpperWing(r)
data=json.loads((ROOT/'build/challenger-surface-quality-2026-11-15/baseline.json').read_text())
row=data['simple']['body_paint'];p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
for y in [.80,.84,.88,.92,.95]:
    result=[]
    for z in [-2.18,-2.14,-2.10,-2.05,-2.,-1.9,-1.8,-1.7,-1.55,-1.3,-1.1,-.9,-.8]:
        hit,n,i,_=tree.ray_cast((2,y,z),(-1,0,0),2)
        if hit is None:continue
        result.append([z,round(hit.x,4),round(float(field.width(y,z)-hit.x)*1000,2),round(float(field.weight(np.asarray([hit]))[0]),3),tuple(round(v,2) for v in n)])
    print(y,result)
