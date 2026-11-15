"""Independent native reflection-contour and proportion measurements."""
from pathlib import Path
import sys,json
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-side-proportion-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
baseline=json.loads((BUILD/'baseline.json').read_text());data=json.loads((BUILD/(label+'.json')).read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_side_surface import Curve
crease=Curve([-2.26,-1.90,-1.40,-.70,.25,.55,.95,1.30,1.75,2.20],[.755,.765,.792,.810,.822,.840,.904,.930,.930,.897])
def front(z):
    t=np.clip((np.asarray(z)+2.23)/.55,0,1)
    return np.asarray(z)+.14*(1-t**3*(10+t*(-15+6*t)))
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def native_tree(row):
    p,n,f=arrays(row);cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])
    visible=(cross[:,0]>1e-11)&(p[f].mean(1)[:,0]>.65)
    return p,n,f,BVHTree.FromPolygons(p.tolist(),f[visible].tolist(),all_triangles=True),f[visible]
def section_angle(mesh,y,z):
    p,n,f,tree,visible=mesh
    hit,geometric,i,_=tree.ray_cast((2,float(y),float(z)),(-1,0,0),2)
    if hit is None:return None
    face=visible[i];a,b,c=p[face];u=b-a;v=c-a;w=np.asarray(hit)-a
    gram=np.array([[u@u,u@v],[u@v,v@v]])
    if abs(np.linalg.det(gram))<1e-20:return None
    s,t=np.linalg.solve(gram,[w@u,w@v]);normal=n[face].T@np.array([1-s-t,s,t])
    return float(np.arctan2(normal[1],abs(normal[0])))
def reflection_tracks(row,shortened):
    mesh=native_tree(row);tracks={}
    for angle in [15,20,22]:
        target=np.radians(angle);trace=[]
        for old_z in np.arange(-1.83,1.961,.01):
            z=float(front(old_z)) if shortened else float(old_z);c=float(crease(old_z))
            previous=None;root=None
            for d in np.linspace(-.060,.100,41):
                value=section_angle(mesh,c+d,z)
                if value is None:previous=None;continue
                if previous is not None and previous[1]<=target<=value:
                    low,high=previous[0],d
                    for _ in range(11):
                        mid=(low+high)*.5;value_mid=section_angle(mesh,c+mid,z)
                        if value_mid is None:break
                        if value_mid<target:low=mid
                        else:high=mid
                    root=(low+high)*.5;break
                previous=(d,value)
            trace.append([float(old_z),None if root is None else float(root)])
        kinks=[]
        for i in range(1,len(trace)-1):
            if all(trace[j][1] is not None for j in [i-1,i,i+1]):kinks.append(abs(trace[i-1][1]-2*trace[i][1]+trace[i+1][1])*1000)
        tracks[str(angle)]={'coverage':sum(p[1] is not None for p in trace),'samples':len(trace),'second_difference_p95_mm':float(np.percentile(kinks,95)), 'second_difference_max_mm':float(max(kinks)),'trace':trace}
    return tracks
checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def distance(a,b):
    tree=KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance();return max(tree.find(p)[2] for p in a)
for tier in ['simple','full']:
    before=reflection_tracks(baseline[tier]['body_paint'],False)
    after=reflection_tracks(data[tier]['body_paint'],label!='baseline')
    p,n,f=arrays(data[tier]['body_paint']);old,on,of=arrays(baseline[tier]['body_paint'])
    old_total=sum(len(v['indices'])//3 for v in baseline[tier].values());total=sum(len(v['indices'])//3 for v in data[tier].values())
    check(total<=old_total,tier+' total native geometry does not increase')
    lead=float(old[:,2].min()-p[:,2].min())
    check(abs(lead+.14)<.0002,tier+' front body is shortened by 140 mm')
    roof=p[p[:,1]>1.10];old_roof=old[old[:,1]>1.10]
    roof_error=max(distance(roof,old_roof),distance(old_roof,roof))*1000
    check(roof_error<.12,tier+' roof and upper pillars stay within native packing precision')
    cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]]);centre=p[f].mean(1);length=np.linalg.norm(cross,axis=1)
    old_z=centre[:,2]-.14
    for _ in range(12):old_z+=centre[:,2]-front(old_z)
    band=(abs(centre[:,0])>.70)&(abs(centre[:,1]-crease(old_z))<.12)&(centre[:,2]>-1.83)&(centre[:,2]<2.0)
    band&=(cross[:,0]*np.sign(centre[:,0])>length*.25)&(length>1e-8)
    alignment=np.sum(n[f]*cross[:,None,:],axis=2)/np.maximum(length[:,None],1e-20)
    check(alignment[band].min()>.2,tier+' every sampled shoulder corner normal remains in its outward face hemisphere')
    for name,row in data[tier].items():
        if name in ['body_paint','body_contour']:continue
        q,nn,ff=arrays(row);op,_,_=arrays(baseline[tier][name]);target=op.copy();target[:,2]=front(target[:,2])
        if name=='body_amber':
            # The existing producer seats these attached markers on the final
            # body. Their X coordinates must follow the new skin, while their
            # authored Y/Z shape and the 3 mm surface offset remain controlled.
            yz=q.copy();old_yz=target.copy();yz[:,0]=0;old_yz[:,0]=0
            err=max(distance(yz,old_yz),distance(old_yz,yz))*1000
            skin=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True);gaps=[]
            for point in q:
                sign=float(np.sign(point[0]));hit,*_=skin.ray_cast((sign*2,float(point[1]),float(point[2])),(-sign,0,0),2)
                if hit is not None:gaps.append((point[0]-hit.x)*sign)
            check(err<.15 and len(ff)==len(arrays(baseline[tier][name])[2]),tier+' side marker Y/Z profile and triangle count retained')
            check(len(gaps)==len(q) and max(abs(np.asarray(gaps)-.003))<.0025,tier+' side markers follow the actual body with a controlled 3 mm seat')
            continue
        err=max(distance(q,target),distance(target,q))*1000
        check(err<.15,tier+' common overhang map retains '+name)
    old_p95=np.mean([r['second_difference_p95_mm'] for r in before.values()]);new_p95=np.mean([r['second_difference_p95_mm'] for r in after.values()])
    check(min(r['coverage']/r['samples'] for r in after.values())>.95,tier+' reflected contour tracks remain supported')
    check(new_p95<old_p95*.50,tier+' shoulder reflection-contour ripple improves by at least fifty percent')
    metrics[tier]={'native_triangles_before':old_total,'native_triangles_after':total,'nose_shortening_mm':-lead*1000,'roof_error_mm':roof_error,'reflection_before':before,'reflection_after':after,'mean_p95_before_mm':old_p95,'mean_p95_after_mm':new_p95}
result={'checks':len(checks),'failures':sum(not c['pass'] for c in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('SIDE_PROPORTION',result['checks'],result['failures'],json.dumps({t:{k:v for k,v in m.items() if not k.startswith('reflection_')} for t,m in metrics.items()}),flush=True)
sys.exit(bool(result['failures']))
