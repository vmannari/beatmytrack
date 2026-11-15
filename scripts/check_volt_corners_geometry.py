"""Independent VRC01 proof of unchanged doors and restored native corners."""
import json,sys
from pathlib import Path
import numpy as np
from check_car_step10_geometry import distance,topology
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/volt-rear-corners-2026-11-15'
OUT=ROOT/'docs/evidence/volt-rear-corners-2026-11-15'
data=json.loads((WORK/'proof.json').read_text())
results={};checks=0;failures=0
def check(value,label,row):
    global checks,failures
    checks+=1;row[label]=bool(value)
    if not value:failures+=1;print('VOLT_CORNER_GEOMETRY_FAIL',label,flush=True)
for label,bundle in data.items():
    arrays={key:(np.array(value['vertices']),np.array(value['indices'],dtype=int).reshape(-1,3)) for key,value in bundle.items()}
    old,oi=arrays['current'];new,ni=arrays['after'];native,ri=arrays['native'];row={}
    before_door={record for p,record in zip(old,bundle['current']['encoded']) if p[2]<1.15}
    check(before_door.issubset(set(bundle['after']['encoded'])),'original_door_encoded_vertices_retained',row)
    new_samples=np.concatenate((new[np.unique(ni)],new[ni].mean(axis=1)))
    old_samples=np.concatenate((old[np.unique(oi)],old[oi].mean(axis=1)))
    before_error=distance(old_samples[old_samples[:,2]<1.15],new[ni]);after_error=distance(new_samples[new_samples[:,2]<1.15],old[oi])
    row['door_sampled_error_m']=max(before_error,after_error)
    check(row['door_sampled_error_m']<0.000001,'rendered_door_geometry_unchanged',row)
    corner=new_samples[new_samples[:,2]>1.425]
    row['corner_native_error_m']=distance(corner,native[ri])
    row['old_corner_native_error_m']=distance(old_samples[old_samples[:,2]>1.425],native[ri])
    check(row['corner_native_error_m']<0.000001,'rear_geometry_returns_to_native_surface',row)
    check(row['old_corner_native_error_m']>0.0001,'original_reduced_corner_rejects_native_gate',row)
    far=np.flatnonzero(new[:,2]>1.425)
    maximum=0.0
    for i in far:
        nearest=np.argmin(np.linalg.norm(native-new[i],axis=1))
        maximum=max(maximum,float(np.linalg.norm(np.array(bundle['after']['fields']['normals'][i])-bundle['native']['fields']['normals'][nearest])))
    row['native_vertex_normal_maximum_error']=maximum
    check(maximum<0.0002,'native_rear_normals_retained',row)
    # Both meshes use the same world surface; test geometric edge topology,
    # including all join subdivisions, rather than relying on vertex IDs.
    pool=np.concatenate((old,new));a=topology(old,oi,pool);b=topology(new,ni,pool)
    row['before_topology']=a;row['after_topology']=b
    check(a['components']==b['components'] and a['boundary_components']==b['boundary_components'],'continuous_surface_topology',row)
    check(b['nonmanifold_edges']<=a['nonmanifold_edges'],'no_new_nonmanifold_edges',row)
    row['triangles_before']=len(oi);row['triangles_after']=len(ni)
    results[label]=row
(OUT/'geometry-proof.json').write_text(json.dumps(dict(checks=checks,failures=failures,parts=results),indent=2)+'\n',encoding='utf-8')
print('VOLT_CORNER_GEOMETRY',checks,'checks,',failures,'failures',flush=True)
sys.exit(bool(failures))
