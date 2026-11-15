"""Independent native bonnet-height and protected-geometry acceptance."""
from pathlib import Path
import json,sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-low-hood-2026-11-15';BUILD=ROOT/'build'/OUT.name
args=sys.argv[sys.argv.index('--')+1:];label=args[0] if args else 'candidate'
old=json.loads((BUILD/'baseline.json').read_text());new=json.loads((BUILD/(label+'.json')).read_text())
checks=[];metrics={}
def check(value,name):checks.append({'name':name,'pass':bool(value)})
def arrays(row):return np.asarray(row['points']),np.asarray(row['normals']),np.asarray(row['indices']).reshape(-1,3)[:,::-1]
def tree(row):
    p,n,f=arrays(row)
    return BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
def height(bvh,x,z):
    p,*_=bvh.ray_cast((float(x),2,float(z)),(0,-1,0),2)
    return None if p is None else p.y
def nearest(a,b):
    k=KDTree(len(b))
    for i,p in enumerate(b):k.insert(p,i)
    k.balance();return max(k.find(p)[2] for p in a)
outline_before=np.asarray(json.loads((BUILD/'before/game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json').read_text())['points'])
outline_after=np.asarray(json.loads((BUILD/'native/bonnet_contour.json').read_text())['points']) if label!='baseline' else outline_before.copy()
check(outline_before.shape==outline_after.shape,'bonnet boundary sampling retained')
check(np.max(abs(outline_before[:,[0,2]]-outline_after[:,[0,2]]))<.00015,'bonnet projected panel footprint retained within native precision')
rear=-.990+.225*(abs(outline_before[:,0])/.755)**2
cowl=abs(outline_before[:,2]-rear)<.018
check(cowl.sum()>50 and np.max(abs(outline_before[cowl,1]-outline_after[cowl,1]))<.0002,'actual rear bonnet/cowl boundary retained within 0.2mm')
for tier in ['simple','full']:
    a,b=old[tier],new[tier];m={}
    before=sum(len(v['indices'])//3 for v in a.values());after=sum(len(v['indices'])//3 for v in b.values())
    check(after<=before*1.01,tier+' total triangles increase by less than 1 percent')
    check(after<= (50000 if tier=='simple' else 85000),tier+' original raw triangle budget')
    m['raw_triangles_before']=before;m['raw_triangles_after']=after
    for name,row in b.items():
        p,n,f=arrays(row)
        check(np.isfinite(p).all() and np.isfinite(n).all(),tier+' '+name+' finite arrays')
        check(np.max(abs(np.linalg.norm(n,axis=1)-1))<.003,tier+' '+name+' unit normals')
        if name=='body_amber':
            bp,bn,bf=arrays(a[name])
            check(np.array_equal(f,bf) and np.max(abs(p-bp))<.00015,tier+' amber markers retain placement within native packing precision')
        elif name not in ['body_paint','body_contour','body_accent','body_dark','body_red','body_metal','hood_paint','hood_dark']:
            check(row==a[name],tier+' '+name+' complete native arrays retained')
    pa,na,fa=arrays(a['body_paint']);pb,nb,fb=arrays(b['body_paint'])
    ra=pa[pa[:,1]>1.10];rb=pb[pb[:,1]>1.10]
    err=max(nearest(ra,rb),nearest(rb,ra))*1000
    check(err<.15,tier+' roof and upper pillars within native packing precision');m['roof_error_mm']=err
    check(abs(pa[:,2].min()-pb[:,2].min())<.0002 and abs(pa[:,2].max()-pb[:,2].max())<.0002,tier+' front/rear longitudinal extent retained')
    ta,tb=tree(a['body_paint']),tree(b['body_paint']);errors=[];missing=0
    for z in np.arange(-1.55,1.961,.06):
        for y in [.45,.58,.66,.72]:
            ah,*_=ta.ray_cast((2,y,float(z)),(-1,0,0),2);bh,*_=tb.ray_cast((2,y,float(z)),(-1,0,0),2)
            if ah is not None and bh is not None:errors.append(abs(ah.x-bh.x)*1000)
            elif (ah is None)!=(bh is None):missing+=1
    check(missing==0,tier+' lower side coverage retained')
    check(max(errors)<2,tier+' lower side width within 2mm');m['lower_side_error_mm']=max(errors)
    ha,hb=tree(a['hood_paint']),tree(b['hood_paint']);deck=[];centre=[]
    for z in [-1.65,-1.50,-1.35,-1.20]:
        for x in [-.65,-.52,.52,.65]:
            ay,by=height(ha,x,z),height(hb,x,z)
            check(ay is not None and by is not None,tier+f' deck station {x}/{z} covered')
            if ay is not None and by is not None:deck.append((ay-by)*1000)
        ay,by=height(ha,0,z),height(hb,0,z)
        check(ay is not None and by is not None,tier+f' intake station {z} covered')
        if ay is not None and by is not None:centre.append(abs(ay-by)*1000)
    check(len(deck)==16 and min(deck)>44 and max(deck)<54,tier+' main deck lowered 44-54mm at every survey station')
    check(len(centre)==4 and max(centre)<1.5,tier+' central intake height retained within 1.5mm')
    m['deck_drop_mm']=deck;m['centre_max_change_mm']=max(centre)
    # Verify the intended feature is isolated: the centre stays proud of the
    # lowered deck, without a raised outer edge or a separate broad plateau.
    for z in [-1.5,-1.35]:
        ys=[height(hb,x,z) for x in np.linspace(0,.65,27)]
        m['transverse_'+str(z)]=ys
        check(all(y is not None for y in ys),tier+f' transverse profile {z} covered')
        if all(y is not None for y in ys):
            check(max(np.diff(ys))<.001,tier+f' transverse profile {z} descends continuously from intake')
            check(.078<ys[0]-ys[-1]<.110,tier+f' intake stands 78-110mm above outer deck at {z}')
    hp,hn,hf=arrays(b['hood_paint']);cross=np.cross(hp[hf[:,1]]-hp[hf[:,0]],hp[hf[:,2]]-hp[hf[:,0]])
    check(np.min(cross[:,1])>=-1e-10 and np.count_nonzero(cross[:,1]>1e-10)>len(cross)*.75,tier+' bonnet winding is upward or vertical at its intentional perimeter return')
    check(np.min(hn[:,1])>.50,tier+' bonnet normals retain an upward-facing smooth domain')
    # The complete exhaust fitting occupies the unchanged lower/rear region.
    before=pa[(pa[:,2]>1.93)&(pa[:,1]>.29)&(pa[:,1]<.45)]
    after=pb[(pb[:,2]>1.93)&(pb[:,1]>.29)&(pb[:,1]<.45)]
    e=max(nearest(before,after),nearest(after,before))*1000
    check(e<.15,tier+' seated exhaust-zone geometry retained within native precision');m['exhaust_zone_error_mm']=e
    metrics[tier]=m
result={'checks':len(checks),'failures':sum(not c['pass'] for c in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('LOW_HOOD_NATIVE',result['checks'],'checks;',result['failures'],'failures')
for c in checks:
    if not c['pass']:print('FAIL',c['name'])
if result['failures']:raise SystemExit(1)
