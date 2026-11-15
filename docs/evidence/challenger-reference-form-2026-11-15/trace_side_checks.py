"""Survey rendered native triangles, not the converter's vertex formula."""
from pathlib import Path
import sys,json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-reference-form-2026-11-15';BUILD=ROOT/'build/challenger-reference-form-2026-11-15'
args=sys.argv[sys.argv.index('--')+1:];label=args[0]
before=json.loads((BUILD/'baseline.json').read_text());data=json.loads((BUILD/(args[1] if len(args)>1 else 'candidate.json')).read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_side_surface import Curve
# These are the owner's accepted continuous shoulder's authored height controls.
line=Curve([-2.26,-1.90,-1.40,-.70,.25,.55,.95,1.30,1.75,2.20],[.755,.765,.792,.810,.822,.840,.904,.930,.930,.897])
checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def geometry(row):
    p=np.asarray(row['points']);f=np.asarray(row['indices']).reshape(-1,3);n=np.asarray(row['normals'])
    return p,f,n,BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def normal_at(row,skin,y,z):
    p,f,n,_=row
    hit,_,face,_=skin.ray_cast((2,float(y),float(z)),(-1,0,0),2)
    if hit is None or hit.x<.64:return None
    a,b,c=p[f[face]];v0=b-a;v1=c-a;v2=np.asarray(hit)-a
    d00=v0@v0;d01=v0@v1;d11=v1@v1;d20=v2@v0;d21=v2@v1;den=d00*d11-d01*d01
    if abs(den)<1e-20:return None
    u=(d11*d20-d01*d21)/den;v=(d00*d21-d01*d20)/den
    normal=n[f[face]].T@np.array([1-u-v,u,v]);normal/=max(np.linalg.norm(normal),1e-12)
    return np.asarray(hit),normal
for tier in ['full','simple']:
    p,f,n,skin=geometry(data[tier]['body_paint']);old=geometry(before[tier]['body_paint'])
    row={};track_metrics=[]
    for offset in [-.025,0,.025]:
        normals=[];hits=[];locations=[]
        for z in np.linspace(-2.13,1.99,413):
            sample=normal_at((p,f,n,skin),skin,float(line(z)+offset),z)
            if sample is not None:locations.append(z);hits.append(sample[0]);normals.append(sample[1])
        normals=np.asarray(normals);step=np.diff(locations)<.015
        angles=np.degrees(np.arccos(np.clip(np.sum(normals[1:]*normals[:-1],axis=1),-1,1)))[step]
        
        if angles.max()>18:print('STEP_LOCATIONS',tier,offset,np.asarray(locations)[1:][step][angles>18].tolist(),flush=True)
        track_metrics.append({'offset':offset,'hits':len(hits),'p95_normal_step_degrees':float(np.percentile(angles,95)),
            'maximum_normal_step_degrees':float(angles.max()),'over_8_degree_steps':int(np.sum(angles>8))})
        check(len(hits)>=390,tier+' shoulder track has continuous physical support '+str(offset))
        check(np.percentile(angles,95)<5,tier+' shoulder has smooth native longitudinal tangents '+str(offset))
        check(angles.max()<18,tier+' shoulder has no abrupt native normal jumps '+str(offset))
    row['shoulder_tracks']=track_metrics
    a,b,c=p[f[:,0]],p[f[:,1]],p[f[:,2]]
    face=-np.cross(b-a,c-a);area=np.linalg.norm(face,axis=1);face/=np.maximum(area[:,None],1e-12)
    mean=n[f].mean(1);mean/=np.maximum(np.linalg.norm(mean,axis=1,keepdims=True),1e-12)
    inward=int(np.sum((area>.00005)&(np.sum(face*mean,axis=1)<-.05)))
    row['inward_macro_faces']=inward;check(inward==0,tier+' visible-size triangles have outward shading')
    check(np.allclose(p.min(0),old[0].min(0),atol=1e-6) and np.allclose(p.max(0),old[0].max(0),atol=1e-6),tier+' overall factory bounds retained')
    protected=old[0][old[0][:,1]>1.11]
    current={tuple(q) for q in np.round(p,6)}
    lost=sum(tuple(q) not in current for q in np.round(protected,6))
    row['protected_upper_vertices']=len(protected);row['lost_upper_vertices']=lost
    check(lost==0,tier+' original roof and upper pillars stay fixed')
    hood=data[tier]['hood_paint'];original_hood=before[tier]['hood_paint']
    check(all(np.array_equal(hood[k],original_hood[k]) for k in ['points','normals','indices']),tier+' complete native bonnet remains exact')
    # Orthographic side coverage is evaluated by actual triangle intersections.
    different=0;covered=0
    for z in np.linspace(-2.26,2.21,360):
        for y in np.linspace(.27,1.62,120):
            a=old[3].ray_cast((2,float(y),float(z)),(-1,0,0),4)[0]
            b=skin.ray_cast((2,float(y),float(z)),(-1,0,0),4)[0]
            different+=(a is None)!=(b is None);covered+=a is not None
    row['side_silhouette_coverage_changes']=different;row['original_covered_samples']=covered
    check(different<=8,tier+' original side silhouette and wheel openings retained')
    metrics[tier]=row
failed=[c['name'] for c in checks if not c['pass']]
(OUT/(label+'.json')).write_text(json.dumps({'checks':len(checks),'failures':len(failed),'metrics':metrics,'failed':failed},indent=2))
print('CONTINUOUS_SIDE',len(checks),'checks,',len(failed),'failures',json.dumps(metrics),flush=True)
for name in failed:print('FAIL',name,flush=True)
if failed:raise RuntimeError('Native side quality rejected')
