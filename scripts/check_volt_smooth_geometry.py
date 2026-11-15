"""VSR01/02: independent native shape, normal-join and contour invariants."""
from pathlib import Path
import itertools,json,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/volt-reflection-smoothing-2026-11-15'
OUT=ROOT/'docs/evidence/volt-reflection-smoothing-2026-11-15'
data=json.loads((WORK/'proof.json').read_text(encoding='utf-8'))
checks=0;failures=0;rows={};ledger={}
def check(value,label):
    global checks,failures
    checks+=1
    if not value: failures+=1;print('VSR_GEOMETRY_FAIL',label)
def interpolate(row,queries):
    uv=np.array(row['uv']);n=np.array(row['n']);result=np.full((len(queries),3),np.nan)
    for indices in np.array(row['indices']).reshape(-1,3):
        tri=uv[indices];a,b=tri[1]-tri[0],tri[2]-tri[0];d=a[0]*b[1]-a[1]*b[0]
        if abs(d)<1e-15: continue
        q=queries-tri[0];u=(q[:,0]*b[1]-q[:,1]*b[0])/d;v=(a[0]*q[:,1]-a[1]*q[:,0])/d
        take=(u>=-1e-6)&(v>=-1e-6)&(u+v<=1+1e-6)
        result[take]=(1-u[take]-v[take])[:,None]*n[indices[0]]+u[take,None]*n[indices[1]]+v[take,None]*n[indices[2]]
    result/=np.linalg.norm(result,axis=1)[:,None]
    return result
for label,bundle in data['parts'].items():
    before,native,after=(bundle[k] for k in ('before','native','after'))
    check(after['p']==native['p'],label+' exact native positions')
    check(after['indices']==native['indices'],label+' native topology/winding')
    check(after['uv']==native['uv'],label+' native UV coordinates')
    n=np.array(after['n']);t=np.array(after['tangent']).reshape(-1,4)[:,:3]
    check(np.max(abs(np.linalg.norm(n,axis=1)-1))<.0002,label+' unit normals')
    check(np.max(abs(np.sum(n*t,axis=1)))<.0003,label+' orthogonal tangent basis')
    old_n=interpolate(before,np.array(native['uv']))
    new_coverage=interpolate(after,np.array(native['uv']))
    check(np.isfinite(new_coverage).all(),label+' complete native UV comparison coverage')
    for at,p in enumerate(native['p']):
        key=tuple(np.round(np.array(p)*100000).astype(int))
        ledger.setdefault(key,[]).append((label,old_n[at],n[at]))
    rows[label]={'old_uv_queries_without_face':int(np.isnan(old_n).any(axis=1).sum()),'before_triangles':len(before['indices'])//3,'after_triangles':len(after['indices'])//3}
old_angles=[];new_angles=[]
for entries in ledger.values():
    for a,b in itertools.combinations(entries,2):
        if a[0]==b[0]:continue
        if np.isfinite(a[1]).all() and np.isfinite(b[1]).all():old_angles.append(float(np.degrees(np.arccos(np.clip(a[1]@b[1],-1,1)))))
        new_angles.append(float(np.degrees(np.arccos(np.clip(a[2]@b[2],-1,1)))))
check(bool(new_angles),'actual cross-chart matching stations exist')
check(max(new_angles)<.2,'shared paint edges have less than 0.2 degree normal mismatch')
check(max(old_angles)>2,'task-start model rejects the smooth-edge gate')
for row in data['contours']:
    a,b=row['before'],row['after'];label=row['name']
    check(a['indices']==b['indices'],label+' strip topology')
    check(np.array_equal(np.array(a['p'])[:,1:],np.array(b['p'])[:,1:]),label+' exact seam/handle Y/Z path')
    check(np.array_equal(np.array(a['uv'])[:,0],np.array(b['uv'])[:,0]),label+' signed line coverage coordinates')
result={'checks':checks,'failures':failures,'parts':rows,'shared_stations':len(new_angles),'before_comparable_station_pairs':len(old_angles),'before_join_max_degrees':max(old_angles),'after_join_max_degrees':max(new_angles),'before_join_p95_degrees':float(np.percentile(old_angles,95)),'after_join_p95_degrees':float(np.percentile(new_angles,95))}
(OUT/'geometry-proof.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
print('VSR_GEOMETRY',checks,'checks,',failures,'failures; joins',len(new_angles),'maximum',max(old_angles),'->',max(new_angles),'degrees')
sys.exit(bool(failures))
