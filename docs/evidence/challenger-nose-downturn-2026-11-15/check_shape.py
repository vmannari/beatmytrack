"""Independent checks of the packed nose profile, optics and protected body."""
from pathlib import Path
import json, sys
import numpy as np
from mathutils.kdtree import KDTree

ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-nose-downturn-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
old=json.loads((BUILD/'baseline.json').read_text());new=json.loads((BUILD/(label+'.json')).read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_side_surface import Curve
crease=Curve([-2.26,-1.90,-1.40,-.70,.25,.55,.95,1.30,1.75,2.20],[.755,.765,.792,.810,.822,.840,.904,.930,.930,.897])
checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def distances(a,b):
    tree=KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance()
    return np.asarray([tree.find(p)[2] for p in a])
def profile(row):
    p,_,f=arrays(row);tri=p[f];result=[]
    for z in np.arange(-2.075,-1.699,.025):
        selected=tri[(tri[:,:,2].min(1)<=z)&(tri[:,:,2].max(1)>=z)]
        samples=[]
        for a,b in [(0,1),(1,2),(2,0)]:
            pa,pb=selected[:,a],selected[:,b];den=pb[:,2]-pa[:,2]
            valid=(abs(den)>1e-12)&((pa[:,2]-z)*(pb[:,2]-z)<=0)
            q=pa[valid]+((z-pa[valid,2])/den[valid])[:,None]*(pb[valid]-pa[valid])
            samples.extend(q[(abs(q[:,0])>.58)&(abs(q[:,0])<.98)&(q[:,1]>.65)].tolist())
        result.append([float(z),max(p[1] for p in samples) if samples else None])
    return result
for tier in ['simple','full']:
    data=new[tier];before=old[tier];m={}
    count=sum(len(r['indices'])//3 for r in data.values());old_count=sum(len(r['indices'])//3 for r in before.values())
    check(count==old_count,tier+' native triangle count is unchanged');m['native_triangles']=count
    for name,row in data.items():
        p,n,f=arrays(row);bp,bn,bf=arrays(before[name])
        check(len(f)==len(bf),tier+' '+name+' keeps its triangle allocation')
        check(np.isfinite(p).all() and np.isfinite(n).all(),tier+' '+name+' finite geometry and normals')
        check(np.max(abs(np.linalg.norm(n,axis=1)-1))<.003,tier+' '+name+' unit native normals')
        protected=(p[:,2]>=-1.619)|(p[:,1]<=.249)
        other=(bp[:,2]>=-1.619)|(bp[:,1]<=.249)
        if protected.any() and other.any():
            error=max(distances(p[protected],bp[other]).max(),distances(bp[other],p[protected]).max())
            check(error<.00015,tier+' '+name+' protected rearward body and lower lip retained')
        check(abs(p[:,2].min()-bp[:,2].min())<.00015 and abs(p[:,2].max()-bp[:,2].max())<.00015,tier+' '+name+' longitudinal extent retained')
    bprof=profile(before['body_paint']);prof=profile(data['body_paint'])
    m['before_profile']=bprof;m['profile']=prof
    trace=np.asarray([r for r in prof if r[1] is not None]);back=trace[trace[:,0]>-1.78,1].mean();tip=trace[trace[:,0]<-2.04,1].mean()
    check(len(trace)>=14,tier+' complete outer-wing tip profile coverage')
    check(back-tip>.045,tier+' outer-wing tip falls at least 45 mm below its rearward run')
    check(np.diff(trace[trace[:,0]<-1.85,1]).min()>-.0004,tier+' outer-wing tip never turns upward towards the front')
    drop=np.asarray(bprof)[:,1]-np.asarray(prof)[:,1]
    check(drop[0]>.040,tier+' leading outer-wing silhouette is lowered more than 40 mm')
    m['tip_drop_mm']=float(drop[0]*1000)
    for side in ['left','right']:
        p,_,_=arrays(data['head_'+side+'_white']);bp,_,_=arrays(before['head_'+side+'_white'])
        side_metrics=[]
        for outer in [False,True]:
            b=bp[(abs(bp[:,0])>.65)==outer];a=p[(abs(p[:,0])>.61)==outer]
            inset=abs(b[:,0].mean())-abs(a[:,0].mean());diameter=np.ptp(a[:,0]);old_diameter=np.ptp(b[:,0])
            check(.040<inset<.047,tier+' '+side+(' outer' if outer else ' inner')+' projector moves inward 40-47 mm')
            check(abs(diameter-old_diameter)<.0008,tier+' '+side+(' outer' if outer else ' inner')+' projector diameter retained')
            side_metrics.append({'inset_mm':float(inset*1000),'diameter_mm':float(diameter*1000)})
        m[side+'_lamps']=side_metrics
    p,_,_=arrays(data['body_vent_metal']);bp,_,_=arrays(before['body_vent_metal'])
    upper=p[(p[:,1]>.60)&(p[:,2]<-1.95)];bupper=bp[(bp[:,1]>.60)&(bp[:,2]<-1.95)]
    width=np.ptp(upper[:,0]);old_width=np.ptp(bupper[:,0]);m['grille_width_mm']=float(width*1000);m['before_grille_width_mm']=float(old_width*1000)
    check(.080<old_width-width<.100,tier+' upper grille narrows by 80-100 mm')
    p,n,f=arrays(data['body_paint']);centre=p[f].mean(1);cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]]);area=np.linalg.norm(cross,axis=1)
    shoulder=(centre[:,2]>-1.60)&(centre[:,2]<2)&(abs(centre[:,0])>.70)&(abs(centre[:,1]-crease(centre[:,2]))<.12)&(cross[:,0]*np.sign(centre[:,0])>area*.25)&(area>1e-8)
    dots=np.sum(n[f]*cross[:,None,:],axis=2)/np.maximum(area[:,None],1e-20)
    check(dots[shoulder].min()>.2,tier+' retained shoulder normals remain outward')
    # Cofactor normal transport must agree with the physical deformed skin.
    nose=(centre[:,2]<-1.72)&(centre[:,1]>.6)&(centre[:,1]<1.03)&(area>1e-7)
    bp,bn,bf=arrays(before['body_paint']);bc=bp[bf].mean(1);bx=np.cross(bp[bf[:,1]]-bp[bf[:,0]],bp[bf[:,2]]-bp[bf[:,0]]);ba=np.linalg.norm(bx,axis=1)
    bd=np.sum(bn[bf]*bx[:,None,:],axis=2)/np.maximum(ba[:,None],1e-20);base=(bc[:,2]<-1.72)&(bc[:,1]>.6)&(bc[:,1]<1.03)&(ba>1e-7)
    check(int((dots[nose].mean(1)<0).sum())<=int((bd[base].mean(1)<0).sum()),tier+' nose does not add reversed smooth-normal faces')
    m['nose_negative_mean_normal_faces']=int((dots[nose].mean(1)<0).sum());metrics[tier]=m
receipt={'checks':len(checks),'failures':sum(not r['pass'] for r in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(receipt,indent=2))
print('NOSE_NATIVE_SHAPE',receipt['checks'],'checks;',receipt['failures'],'failures')
for row in checks:
    if not row['pass']:print('FAIL',row['name'])
if receipt['failures']:raise SystemExit(1)
