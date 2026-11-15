"""Acceptance of real native surface flow, reduced crown and buried exhaust roots."""
from pathlib import Path
import sys,json
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-front-crown-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
old=json.loads((BUILD/'baseline.json').read_text());data=json.loads((BUILD/(label+'.json')).read_text());audit=json.loads((OUT/(label+'-audit.json')).read_text())
checks=[];measure={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def nearest(a,b):
    tree=KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance();return max(tree.find(p)[2] for p in a)
def bvh(row):
    p,n,f=arrays(row);return BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
for tier in ['simple','full']:
    a=audit[tier];m={};p,n,f=arrays(data[tier]['body_paint']);bp,bn,bf=arrays(old[tier]['body_paint'])
    for name,row in data[tier].items():
        pp,nn,ff=arrays(row)
        check(np.isfinite(pp).all() and np.isfinite(nn).all(),tier+' '+name+' finite native arrays')
        check(np.max(abs(np.linalg.norm(nn,axis=1)-1))<.003,tier+' '+name+' native normals remain unit length')
        if name in ['window_seal_glass','body_glass','aero_accent','tail_left_red','tail_right_red','body_lens_red','body_red','body_reverse']:
            check(row==old[tier][name],tier+' '+name+' complete native arrays retained')
    roof=p[p[:,1]>1.10];broof=bp[bp[:,1]>1.10];e=max(nearest(roof,broof),nearest(broof,roof))*1000
    check(e<.15,tier+' roof and upper pillars stay within native packing precision');m['roof_max_error_mm']=e
    check(abs(p[:,2].min()-bp[:,2].min())<.0002 and abs(p[:,2].max()-bp[:,2].max())<.0002,tier+' existing front shortening and overall longitudinal extent retained')
    side_old=bvh(old[tier]['body_paint']);side_new=bvh(data[tier]['body_paint']);errors=[];missing=0
    for z in np.arange(-1.6,1.961,.04):
        for y in [.58,.66,.74,.82,.90]:
            oh,*_=side_old.ray_cast((2,y,float(z)),(-1,0,0),2);nh,*_=side_new.ray_cast((2,y,float(z)),(-1,0,0),2)
            if oh is not None and nh is not None:errors.append(abs(oh.x-nh.x)*1000)
            elif (oh is None)!=(nh is None):missing+=1
    check(missing==0,tier+' protected side silhouette coverage retained')
    check(max(errors)<2.0,tier+' protected side width differs by less than 2 mm');m['side_max_width_error_mm']=max(errors)
    drops=[r['drop_mm'] for r in a['paired_crown_drops']];check(np.mean(drops)>15,tier+' marked crown physically lowered by more than 15 mm on average')
    check(max(drops)<35 and min(drops)>5,tier+' front crown reduction remains bounded across all survey stations');m['mean_crown_drop_mm']=float(np.mean(drops))
    before_rms=[v['detrended_rms_mm'] for v in a['front']['before'].values()];after_rms=[v['detrended_rms_mm'] for v in a['front']['after'].values()]
    check(np.mean(after_rms)<np.mean(before_rms)*.60,tier+' front reflected-contour residual falls at least 40 percent')
    check(max(after_rms)<.60,tier+' every front contour detrended RMS remains below 0.60 mm')
    for angle,v in a['front']['after'].items():check(v['coverage']>=a['front']['before'][angle]['coverage']-1,tier+' front '+angle+' degree contour retains coverage')
    check(a['side']['mean_p95_after_mm']<=a['side']['mean_p95_before_mm']*1.10+.020,tier+' established side reflection smoothness retained within packing/sampling allowance')
    m['front_rms_before_mm']=float(np.mean(before_rms));m['front_rms_after_mm']=float(np.mean(after_rms));m['side_p95_before_mm']=a['side']['mean_p95_before_mm'];m['side_p95_after_mm']=a['side']['mean_p95_after_mm']
    cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]]);area=np.linalg.norm(cross,axis=1);c=p[f].mean(1);dots=np.sum(n[f]*cross[:,None,:],axis=2)/np.maximum(area[:,None],1e-20)
    band=(abs(c[:,0])>.65)&(c[:,1]>.70)&(c[:,1]<1.02)&(c[:,2]<-1.68)&(cross[:,0]*np.sign(c[:,0])>area*.25)&(area>1e-7)
    bcross=np.cross(bp[bf[:,1]]-bp[bf[:,0]],bp[bf[:,2]]-bp[bf[:,0]]);ba=np.linalg.norm(bcross,axis=1);bc=bp[bf].mean(1);bd=np.sum(bn[bf]*bcross[:,None,:],axis=2)/np.maximum(ba[:,None],1e-20)
    bband=(abs(bc[:,0])>.65)&(bc[:,1]>.70)&(bc[:,1]<1.02)&(bc[:,2]<-1.68)&(bcross[:,0]*np.sign(bc[:,0])>ba*.25)&(ba>1e-7)
    check(int((dots[band].mean(1)<0).sum())<=int((bd[bband].mean(1)<0).sum()),tier+' no additional front faces have reversed mean shading normals')
    for exhaust in a['exhaust']:
        side=str(exhaust['side']);check(exhaust['root_vertices']>20 and exhaust['buried_root_vertices']==exhaust['root_vertices'],tier+' '+side+' complete inboard neck lies behind the bumper')
        check(exhaust['minimum_root_burial_m']>.15,tier+' '+side+' complete root loop buried more than 150 mm')
        check(.020<exhaust['projection_m']<.030,tier+' '+side+' mouth has a controlled 20-30 mm projection')
        check(exhaust['minimum_cavity_clearance_m'] is not None and exhaust['minimum_cavity_clearance_m']>.003,tier+' '+side+' dark bore lies ahead of obstructing bumper skin')
    for name in ['head_left_white','head_right_white']:
        hp,_,_=arrays(data[tier][name]);op,_,_=arrays(old[tier][name]);shift=abs(op[:,0]).mean()-abs(hp[:,0]).mean()
        check(.017<shift<.019,tier+' '+name+' moves inward 17-19 mm without changing its design')
    measure[tier]=m
result={'checks':len(checks),'failures':sum(not r['pass'] for r in checks),'assertions':checks,'metrics':measure}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('FRONT_CROWN_NATIVE',result['checks'],'checks;',result['failures'],'failures')
for row in checks:
    if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
