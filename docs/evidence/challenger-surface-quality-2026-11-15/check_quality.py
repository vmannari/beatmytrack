"""Check final native geometry, shape controls and surface continuity independently."""
from pathlib import Path
import json
import sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/challenger-surface-quality-2026-11-15'
BUILD = ROOT / 'build' / OUT.name
args = sys.argv[sys.argv.index('--')+1:]
label = args[0] if args else 'candidate'
data = json.loads((BUILD / (label+'.json')).read_text())
before = json.loads((BUILD / 'baseline.json').read_text())
checks = []; metrics = {}
def check(value, name):
    checks.append({'pass': bool(value), 'name': name})
def arrays(row):
    return np.asarray(row['points']), np.asarray(row['normals']), np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def point_distance(a,b):
    tree = KDTree(len(b))
    for i, p in enumerate(b): tree.insert(p, i)
    tree.balance()
    return max(tree.find(p)[2] for p in a)
def surface_distance(a,p,f):
    tree=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    return max(tree.find_nearest(point)[3] for point in a)
def survey(row):
    p,n,f = arrays(row)
    tree = BVHTree.FromPolygons(p.tolist(), f.tolist(), all_triangles=True)
    tracks=[]
    for y in [.84,.88,.92]:
        samples=[]
        for z in np.linspace(-2.045,-.90,230):
            hit,geometric,i,_=tree.ray_cast((2,y,float(z)),(-1,0,0),2)
            if hit is None: continue
            # The deliberately downward-facing bonnet gutter is a hard return,
            # not a sample of the continuous exterior crown.
            if geometric.y < -.05: continue
            a,b,c=p[f[i]];u=b-a;v=c-a;w=np.asarray(hit)-a
            s,t=np.linalg.solve([[u@u,u@v],[u@v,v@v]],[w@u,w@v])
            normal=n[f[i]].T@np.array([1-s-t,s,t]);normal/=np.linalg.norm(normal)
            samples.append([hit.x,*normal])
        samples=np.asarray(samples)
        steps=np.degrees(np.arccos(np.clip(np.sum(samples[:-1,1:]*samples[1:,1:],axis=1),-1,1)))
        kinks=abs(np.diff(samples[:,0],n=2))*1000
        tracks.append({'height':y,'coverage':len(samples),'normal_step_max_deg':float(steps.max()),'normal_step_p95_deg':float(np.percentile(steps,95)), 'second_difference_max_mm':float(kinks.max()), 'second_difference_p95_mm':float(np.percentile(kinks,95))})
    return tracks
for tier in ['simple','full']:
    p,n,f = arrays(data[tier]['body_paint']); old,on,of = arrays(before[tier]['body_paint'])
    count=sum(len(row['indices'])//3 for row in data[tier].values())
    old_count=sum(len(row['indices'])//3 for row in before[tier].values())
    check(count<=old_count*1.10,tier+' complete native vehicle stays within ten percent triangle budget')
    check(count<=old_count*1.05,tier+' local retessellation stays below five percent growth')
    check(np.isfinite(p).all() and np.isfinite(n).all(),tier+' all body attributes finite')
    check(np.max(abs(np.linalg.norm(n,axis=1)-1))<.001,tier+' packed normals remain unit length')
    # These source coordinates were not part of the correction, including
    # roof, pillars, rear body, bumper, wheel arches and long lower side.
    protected=lambda a:(a[:,2]>=-.70)|(a[:,1]>=1.05)|(a[:,1]<=.77)|(abs(a[:,0])<=.69)
    a,b=p[protected(p)],old[protected(old)]
    protected_error=max(point_distance(a,b),point_distance(b,a))*1000
    check(protected_error<.12,tier+' protected original body stays within native packing precision')
    error=max(surface_distance(p,old,of),surface_distance(old,p,f))*1000
    check(error<14.15,tier+' body refinement remains bounded to 14.15 mm including native packing')
    for name,row in data[tier].items():
        if name in ['body_paint','body_contour']:continue
        check(row==before[tier][name],tier+' unchanged native surface '+name)
    cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])
    centre=p[f].mean(1)
    chosen=(abs(centre[:,0])>.74)&(centre[:,1]>.85)&(centre[:,1]<.94)&(centre[:,2]>-2.04)&(centre[:,2]<-.90)&(np.linalg.norm(cross,axis=1)>1e-8)
    # Small gutter walls are deliberately sharp and are not broad exterior.
    outward=chosen&(cross[:,0]*np.sign(centre[:,0])>0)
    dots=np.sum(n[f]*cross[:,None,:],axis=2)/np.maximum(np.linalg.norm(cross,axis=1)[:,None],1e-12)
    check(np.min(dots[outward])>-.02,tier+' broad fender normals face outward')
    current,previous=survey(data[tier]['body_paint']),survey(before[tier]['body_paint'])
    check(min(t['coverage'] for t in current)>215,tier+' all independent fender ray tracks remain supported')
    check(max(t['normal_step_max_deg'] for t in current)<2,tier+' broad fender normal tracks have no abrupt folds')
    current_kinks=np.mean([t['second_difference_p95_mm'] for t in current])
    old_kinks=np.mean([t['second_difference_p95_mm'] for t in previous])
    check(current_kinks<old_kinks*.80,tier+' physical fender curvature kinks improve by at least twenty percent')
    check(np.max(abs(p.min(0)-old.min(0)))<.00012 and np.max(abs(p.max(0)-old.max(0)))<.00012,tier+' complete body bounds retain the current design')
    metrics[tier]={'triangles_before':old_count,'triangles_after':count,'maximum_body_vertex_distance_mm':error,'protected_body_error_mm':protected_error,'before_tracks':previous,'after_tracks':current,'outward_corner_min_dot':float(np.min(dots[outward]))}
result={'checks':len(checks),'failures':sum(not c['pass'] for c in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-quality.json')).write_text(json.dumps(result,indent=2))
print('SURFACE_QUALITY',result['checks'],result['failures'],json.dumps(metrics),flush=True)
sys.exit(bool(result['failures']))
