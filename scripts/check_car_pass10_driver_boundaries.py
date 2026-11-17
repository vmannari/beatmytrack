"""C302: retain topology and exact steering boundary segments for index-only options."""
import collections,json
import numpy as np
from run_car_pass10 import OUT,WORK
from check_car_pass10_geometry import topology
data=json.loads((WORK/'driver-candidates.json').read_text())
review=json.loads((OUT/'driver-geometry-review.json').read_text())
def boundary(pose,indices):
    p=[tuple(round(x,6) for x in p) for p in pose];counts=collections.Counter()
    for i in range(0,len(indices),3):
        a,b,c=[p[j] for j in indices[i:i+3]]
        for one,two in [(a,b),(b,c),(c,a)]:
            if one!=two:counts[tuple(sorted((one,two)))]+=1
    return sorted(k for k,v in counts.items() if v==1)
receipts=[]
for option,row in zip(data['options'],review):
    top=True;failures=[];checks=0
    for number,surface in enumerate(data['geometry']):
        vertices=np.array(surface['poses'][0]);old=np.array(surface['indices']).reshape(-1,3);new=np.array(option['indices'][number]).reshape(-1,3)
        a=topology(vertices,old,vertices);b=topology(vertices,new,vertices)
        top=top and all(a[k]==b[k] for k in ['components','euler','boundary_components','nonmanifold_edges'])
        poses=list(surface['poses'])
        for direction in range(2):
            chain=[np.array(poses[0])]+[np.array(p) for p in poses[1+direction*5:6+direction*5]]
            poses.extend(((a+b)/2).tolist() for a,b in zip(chain,chain[1:]))
        for pose in poses:
            checks+=1
            if boundary(pose,surface['indices'])!=boundary(pose,option['indices'][number]):failures.append([number,checks])
    row['base_topology_exact']=top;row['all_steering_boundary_segments_exact']=not failures
    row['accepted']=row['accepted'] and top and not failures
    receipts.append(dict(file=option['file'],checks=checks,failures=failures,topology_exact=top))
(OUT/'driver-boundary-options.json').write_text(json.dumps(receipts,indent=2)+'\n')
(OUT/'driver-geometry-review.json').write_text(json.dumps(review,indent=2)+'\n')
print('CP3_DRIVER_TOPOLOGY',[(r['file'],r['accepted']) for r in review])
