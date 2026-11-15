"""Independent packed-mesh proof of valance contact and retained bodywork."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-exhaust-seat-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
before=json.loads((BUILD/'baseline.json').read_text());current=json.loads((BUILD/(label+'.json')).read_text());checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)
def error(a,b):
    tree=KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance();return max(tree.find(p)[2] for p in a)
for tier in ['simple','full']:
    old=before[tier];data=current[tier];measure={};points=[];faces=[]
    for name in ['body_paint','body_accent','body_dark']:
        p,n,f=arrays(data[name]);faces.extend((f+len(points)).tolist());points.extend(p.tolist())
    skin=BVHTree.FromPolygons(points,faces,all_triangles=True)
    for name,row in data.items():
        p,n,f=arrays(row);bp,bn,bf=arrays(old[name])
        check(len(f)==len(bf),tier+' '+name+' triangle count retained')
        check(np.isfinite(p).all() and np.isfinite(n).all(),tier+' '+name+' finite vertices and normals')
        if name not in ['body_chrome','body_rubber']:
            check(row==old[name],tier+' '+name+' native arrays remain exact')
            if label=='candidate':
                a=BUILD/'native'/(tier+'_'+name+'.res');b=BUILD/'before/game/assets/vehicles/challenger_hellcat_v1'/(tier+'_'+name+'.res')
                check(a.read_bytes()==b.read_bytes(),tier+' '+name+' native resource bytes remain exact')
    p,n,f=arrays(data['body_chrome']);bp,bn,bf=arrays(old['body_chrome'])
    mouth=(p[:,2]>2.10)&(p[:,1]<.50);old_mouth=(bp[:,2]>2.10)&(bp[:,1]<.50)
    check(error(p[~mouth],bp[~old_mouth])<.00015 and error(bp[~old_mouth],p[~mouth])<.00015,tier+' non-exhaust chrome retained within packing precision')
    outlet_centres=[];root_depths=[]
    for side in [-1,1]:
        q=p[mouth&(p[:,0]*side>0)];old_q=bp[old_mouth&(bp[:,0]*side>0)]
        centre=(q.min(0)+q.max(0))*.5;outlet_centres.append(centre.tolist())
        check(abs(abs(centre[0])-.525)<.00015,tier+' '+str(side)+' chrome outlet centred at existing lateral anchor')
        check(abs(np.ptp(q[:,0])-.226)<.0002 and abs(np.ptp(q[:,1])-.082)<.0002,tier+' '+str(side)+' oval mouth size retained')
        check(abs(np.ptp(q[:,2])-.074)<.0002,tier+' '+str(side)+' existing tube length retained')
        check(centre[1]-((old_q[:,1].min()+old_q[:,1].max())*.5)>.040,tier+' '+str(side)+' outlet lifted by more than 40 mm')
        support=[]
        for dx in [-.035,0,.035]:
            hit,*_=skin.ray_cast((float(centre[0]+dx),float(centre[1]+.033),3),(0,0,-1),1.2)
            if hit is not None:
                support.append(float(hit.z-q[:,2].min()))
        check(len(support)==3,tier+' '+str(side)+' upper neck has valance support across its width')
        check(len(support)==3 and min(support)>.020,tier+' '+str(side)+' upper neck buried at least 20 mm behind bumper')
        hit,*_=skin.ray_cast((float(centre[0]),float(centre[1]+.033),3),(0,0,-1),1.2)
        projection=float(q[:,2].max()-hit.z) if hit is not None else 100
        check(.040<projection<.050,tier+' '+str(side)+' mouth projects 40-50 mm from valance')
        root_depths.append(support)
        rp,rn,rf=arrays(data['body_rubber']);cavity=rp[rp[:,0]*side>0]
        rc=(cavity.min(0)+cavity.max(0))*.5
        check(abs(rc[0]-centre[0])<.00015 and abs(rc[1]-centre[1])<.00015,tier+' '+str(side)+' dark cavity aligns with the metal outlet')
        check(abs(rc[2]-(q[:,2].min()+.003))<.00015,tier+' '+str(side)+' existing recessed cavity depth retained')
    check(abs(outlet_centres[0][1]-outlet_centres[1][1])<.00015 and abs(outlet_centres[0][2]-outlet_centres[1][2])<.00015,tier+' both exhausts remain level and at the same rearward station')
    measure['outlet_centres']=outlet_centres;measure['upper_neck_burial_metres']=root_depths
    measure['native_triangles']=sum(len(v['indices'])//3 for v in data.values());metrics[tier]=measure
result={'checks':len(checks),'failures':sum(not row['pass'] for row in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('EXHAUST_NATIVE_SEAT',result['checks'],'checks;',result['failures'],'failures')
for row in checks:
    if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
