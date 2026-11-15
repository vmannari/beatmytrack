"""Inspect decoded native triangles independently of the construction chart."""
from pathlib import Path
import sys,json,numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-reference-form-2026-11-15';BUILD=ROOT/'build/challenger-reference-form-2026-11-15'
args=sys.argv[sys.argv.index('--')+1:];label=args[0]
data=json.loads((BUILD/args[1]).read_text());before=json.loads((BUILD/'baseline.json').read_text())
checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def arrays(row):
    p=np.asarray(row['points']);n=np.asarray(row['normals']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
    return p,n,f
def point_error(a,b):
    from mathutils.kdtree import KDTree
    def error(a,b):
        tree=KDTree(len(b))
        for i,p in enumerate(b):tree.insert(p,i)
        tree.balance();return max(tree.find(p)[2] for p in a)
    return max(error(a,b),error(b,a))
def sample(p,n,f,tree,x,z):
    hit,_,i,_=tree.ray_cast((float(x),2,float(z)),(0,-1,0),3)
    if hit is None:return None
    a,b,c=p[f[i]];u=b-a;v=c-a;w=np.asarray(hit)-a
    matrix=np.array([[u@u,u@v],[u@v,v@v]])
    if abs(np.linalg.det(matrix))<1e-20:return None
    s,t=np.linalg.solve(matrix,[w@u,w@v]);nn=n[f[i]].T@np.array([1-s-t,s,t]);nn/=max(np.linalg.norm(nn),1e-12)
    return float(hit.y),nn
def side_normal(p,n,f,tree,y,z):
    hit,_,i,_=tree.ray_cast((2,float(y),float(z)),(-1,0,0),2)
    if hit is None or hit.x<.65:return None
    a,b,c=p[f[i]];u=b-a;v=c-a;w=np.asarray(hit)-a
    matrix=np.array([[u@u,u@v],[u@v,v@v]])
    if abs(np.linalg.det(matrix))<1e-20:return None
    s,t=np.linalg.solve(matrix,[w@u,w@v]);nn=n[f[i]].T@np.array([1-s-t,s,t]);nn/=max(np.linalg.norm(nn),1e-12)
    return nn
for tier in ['full','simple']:
    d=data[tier];b,bn,bf=arrays(d['body_paint']);old,_,_=arrays(before[tier]['body_paint'])
    h,hn,hf=arrays(d['hood_paint']);tree=BVHTree.FromPolygons(h.tolist(),hf.tolist(),all_triangles=True)
    row={}
    span=b[(b[:,2]<-2.15)&(b[:,2]>-2.25)&(b[:,1]>.5)&(b[:,1]<.8)]
    width=float(abs(span[:,0]).max());row['front_half_width']=width
    check(.835<width<.91,tier+' front retains a broad, bounded nose')
    glass=np.asarray(d['window_seal_glass']['points']);oldglass=np.asarray(before[tier]['window_seal_glass']['points'])
    check(point_error(glass,oldglass)<.0000005,tier+' factory glazing outline retained within float storage')
    rear_error=point_error(b[b[:,2]>-.7],old[old[:,2]>-.7]);upper_error=point_error(b[b[:,1]>1.11],old[old[:,1]>1.11])
    row['rear_native_packing_error_mm']=rear_error*1000;row['upper_native_packing_error_mm']=upper_error*1000
    check(rear_error<.0001,tier+' rear body and cabin retain their shape within 0.1 mm native packing')
    check(upper_error<.0001,tier+' roof and upper pillars retain their shape within 0.1 mm native packing')
    grille=np.asarray(d['body_vent_metal']['points']);grille=grille[(grille[:,2]<-2)&(grille[:,1]>.65)&(grille[:,1]<.81)]
    head=np.concatenate([np.asarray(d['head_left_white']['points']),np.asarray(d['head_right_white']['points'])])
    depth=abs(float(np.median(grille[:,2])-np.median(head[:,2])));row['lamp_grille_depth_mm']=depth*1000
    check(depth<.018,tier+' grille and lamps occupy one recessed front plane')
    check(abs(head[:,0].min()+head[:,0].max())<.0001,tier+' four lamps remain centred and symmetric')
    check(head[:,0].max()>.75,tier+' outer lamps reach the rounded corners')
    check(h[:,1].max()<1.025,tier+' bonnet power bulge remains restrained')
    steps=[];coverage=[]
    for x in [0,.30,.55]:
        previous=None;count=0
        for z in np.linspace(-2.13,-.88,251):
            # Intentional vent walls have steep normals; inspect the broad
            # bonnet skin, keeping a physical 12 mm margin around each vent.
            vent=any(abs(x-cx)<w/2+.012 and abs(z-cz)<hh/2+.012 for cx,cz,w,hh in [(0,-1.73,.33,.07),(-.535,-1.558,.176,.110),(.535,-1.558,.176,.110)])
            if vent:previous=None;continue
            value=sample(h,hn,hf,tree,x,z)
            if value is None:previous=None;continue
            count+=1
            if previous is not None:steps.append(np.degrees(np.arccos(np.clip(previous@value[1],-1,1))))
            previous=value[1]
        coverage.append(count)
    row['bonnet_normal_p95_degrees']=float(np.percentile(steps,95));row['bonnet_normal_max_degrees']=float(max(steps))
    row['bonnet_track_coverage']=coverage
    check(min(coverage)>190,tier+' bonnet tracks retain solid support outside vents')
    check(np.percentile(steps,95)<3,tier+' bonnet has continuous broad highlights')
    check(max(steps)<9,tier+' bonnet has no abrupt source-normal folds')
    cross=np.cross(h[hf[:,1]]-h[hf[:,0]],h[hf[:,2]]-h[hf[:,0]])
    length=np.linalg.norm(cross,axis=1)
    substantial=(length>1e-6)&(abs(cross[:,1])>length*.8)
    check(np.all(cross[substantial,1]>0),tier+' bonnet has no inverted major skins')
    a=sample(h,hn,hf,tree,0,-2.13);c=sample(h,hn,hf,tree,0,-1.97)
    drop=c[0]-a[0];row['front_bonnet_drop_mm']=drop*1000
    check(.025<drop<.1,tier+' bonnet rolls down toward the nose')
    body_tree=BVHTree.FromPolygons(b.tolist(),bf.tolist(),all_triangles=True);steps=[];coverage=[]
    for y in [.88,.92]:
        previous=None;count=0
        for z in np.linspace(-1.10,-.76,137):
            nn=side_normal(b,bn,bf,body_tree,y,z)
            if nn is None:previous=None;continue
            count+=1
            if previous is not None:steps.append(np.degrees(np.arccos(np.clip(previous@nn,-1,1))))
            previous=nn
        coverage.append(count)
    row['cowl_track_coverage']=coverage;row['cowl_normal_max_step_degrees']=float(max(steps))
    check(min(coverage)>120,tier+' upper fender has continuous cowl support')
    check(max(steps)<15,tier+' cowl has no abrupt dent highlight')
    metrics[tier]=row
result={'checks':len(checks),'failures':sum(not c['pass'] for c in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'.json')).write_text(json.dumps(result,indent=2))
print('REFERENCE_FORM_QUALITY',result['checks'],result['failures'],json.dumps(metrics),flush=True)
sys.exit(bool(result['failures']))
