"""Independent native geometry, barycentric reflection and exhaust audit."""
from pathlib import Path
import sys,json
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-front-crown-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
baseline=json.loads((BUILD/'baseline.json').read_text());current=json.loads((BUILD/(label+'.json')).read_text())
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def tree(row,side=False):
    p,n,f=arrays(row)
    if side:
        cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]]);area=np.linalg.norm(cross,axis=1)
        f=f[(cross[:,0]>area*.2)&(p[f].mean(1)[:,0]>.60)]
    return p,n,f,BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def norm_at(mesh,y,z):
    p,n,f,bvh=mesh;hit,_,i,_=bvh.ray_cast((2,float(y),float(z)),(-1,0,0),2)
    if hit is None:return None
    face=f[i];a,b,c=p[face];u=b-a;v=c-a;w=np.asarray(hit)-a
    det=(u@u)*(v@v)-(u@v)**2
    if abs(det)<1e-20:return None
    s=((w@u)*(v@v)-(w@v)*(u@v))/det;t=((w@v)*(u@u)-(w@u)*(u@v))/det
    normal=n[face].T@np.array([1-s-t,s,t]);return float(np.arctan2(normal[1],abs(normal[0])))
def tracks(row,start,end):
    mesh=tree(row,True);result={}
    for angle in [15,20,22]:
        target=np.radians(angle);trace=[]
        for z in np.arange(start,end+.0001,.01):
            root=None;previous=None
            for y in np.linspace(.65,1.02,65):
                v=norm_at(mesh,y,z)
                if v is None:previous=None;continue
                if previous is not None and previous[1]<=target<=v:
                    a,b=previous[0],y
                    for _ in range(12):
                        mid=(a+b)*.5;value=norm_at(mesh,mid,z)
                        if value is None:break
                        if value<target:a=mid
                        else:b=mid
                    root=(a+b)*.5;break
                previous=(y,v)
            trace.append([float(z),root])
        d=[abs(trace[i-1][1]-2*trace[i][1]+trace[i+1][1])*1000 for i in range(1,len(trace)-1) if all(trace[j][1] is not None for j in [i-1,i,i+1])]
        valid=np.array([r for r in trace if r[1] is not None]);rms=None
        if len(valid)>10:
            fit=np.polynomial.polynomial.polyfit(valid[:,0]-valid[:,0].mean(),valid[:,1],5);res=valid[:,1]-np.polynomial.polynomial.polyval(valid[:,0]-valid[:,0].mean(),fit);rms=float(np.sqrt(np.mean(res*res))*1000)
        result[str(angle)]={'coverage':len(valid),'samples':len(trace),'second_difference_p95_mm':float(np.percentile(d,95)) if d else None,'detrended_rms_mm':rms,'trace':trace}
    return result
def combined(data,names):
    p=[];f=[]
    for name in names:
        q,n,faces=arrays(data[name]);f.extend((faces+len(p)).tolist());p.extend(q.tolist())
    return BVHTree.FromPolygons(p,f,all_triangles=True)
metrics={}
for tier in ['simple','full']:
    b=baseline[tier];d=current[tier];m={}
    for region,start,end in [('front',-2.02,-1.74),('side',-1.60,1.96)]:
        a=tracks(b['body_paint'],start,end);c=tracks(d['body_paint'],start,end)
        m[region]={'before':a,'after':c,'mean_p95_before_mm':float(np.mean([v['second_difference_p95_mm'] for v in a.values() if v['second_difference_p95_mm'] is not None])),'mean_p95_after_mm':float(np.mean([v['second_difference_p95_mm'] for v in c.values() if v['second_difference_p95_mm'] is not None]))}
    old_top=combined(b,['body_paint','hood_paint']);new_top=combined(d,['body_paint','hood_paint']);drops=[];paired=[]
    for x in [.30,.50,.65,.75]:
        for z in [-2.0,-1.95,-1.90,-1.85,-1.80]:
            bh,*_=old_top.ray_cast((x,2,z),(0,-1,0),2);nh,*_=new_top.ray_cast((x,2,z),(0,-1,0),2)
            if bh is not None and nh is not None:drops.append({'x':x,'z':z,'drop_mm':float((bh.y-nh.y)*1000)})
            t=float(np.clip((z+2.10)/.38,0,1));fade=1-t**3*(10+t*(-15+6*t));original_x=x
            for _ in range(12):
                u=float(np.clip((original_x-.40)/.10,0,1));integral=.10*(2.5*u**4-3*u**5+u**6)+max(original_x-.50,0)
                f=original_x-.10*(original_x-integral)*fade;derivative=1-.10*(1-u**3*(10+u*(-15+6*u)))*fade
                original_x+=(x-f)/derivative
            paired_x=x-.04*(original_x-integral)*fade if label!='baseline' else x
            ph,*_=new_top.ray_cast((float(paired_x),2,z),(0,-1,0),2)
            if bh is not None and ph is not None:paired.append({'old_x':x,'new_x':paired_x,'z':z,'drop_mm':float((bh.y-ph.y)*1000)})
    m['crown_drops']=drops;m['paired_crown_drops']=paired
    skin=combined(d,['body_paint','body_dark','body_accent']);p,n,f=arrays(d['body_chrome']);cavity=arrays(d['body_rubber'])[0];exhaust=[]
    for side in [-1,1]:
        q=p[(p[:,0]*side>.30)&(abs(p[:,0])<.75)&(p[:,1]<.55)&(p[:,2]>1.90)];root=q[q[:,2]<q[:,2].min()+.00015];mouth=q[q[:,2]>q[:,2].max()-.00015];buried=[]
        for v in root:
            hit,*_=skin.ray_cast((float(v[0]),float(v[1]),3),(0,0,-1),1.2);buried.append(None if hit is None else float(hit.z-v[2]))
        centre=(mouth.min(0)+mouth.max(0))*.5;probe,*_=skin.ray_cast((float(centre[0]),float(centre[1]+.033),3),(0,0,-1),1.2)
        cp=cavity[cavity[:,0]*side>0];clearance=[]
        for v in cp:
            hit,*_=skin.ray_cast((float(v[0]),float(v[1]),3),(0,0,-1),1.2)
            if hit is not None:clearance.append(float(v[2]-hit.z))
        exhaust.append({'side':side,'root_vertices':len(root),'buried_root_vertices':sum(v is not None and v>.15 for v in buried),'minimum_root_burial_m':min(v for v in buried if v is not None) if any(v is not None for v in buried) else None,'root_burials':buried,'root_z':float(q[:,2].min()),'mouth_z':float(q[:,2].max()),'mouth_centre':centre.tolist(),'projection_m':None if probe is None else float(q[:,2].max()-probe.z),'minimum_cavity_clearance_m':min(clearance) if clearance else None})
    m['exhaust']=exhaust;metrics[tier]=m
(OUT/(label+'-audit.json')).write_text(json.dumps(metrics,indent=2))
for tier,m in metrics.items():
    print('SURFACE_AUDIT',tier,'front_p95_mm',m['front']['mean_p95_before_mm'],m['front']['mean_p95_after_mm'],'side_p95_mm',m['side']['mean_p95_before_mm'],m['side']['mean_p95_after_mm'],'crown_mean_drop_mm',np.mean([r['drop_mm'] for r in m['crown_drops']]),'exhaust',[(r['buried_root_vertices'],r['root_vertices']) for r in m['exhaust']],flush=True)
