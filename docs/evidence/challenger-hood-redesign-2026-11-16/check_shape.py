"""Independent native checks for the replacement hood and its physical openings."""
from pathlib import Path
import json,sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-hood-redesign-2026-11-16';BUILD=ROOT/'build'/OUT.name
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_side_finish import front_z
arguments=sys.argv[sys.argv.index('--')+1:]
label=arguments[0] if arguments else 'candidate'
baseline=json.loads((BUILD/'baseline.json').read_text())
current=json.loads((BUILD/(label+'.json')).read_text())
checks=[];metrics={}
def check(passed,name):checks.append({'name':name,'pass':bool(passed)})
def arrays(mesh):
    return np.asarray(mesh['points']),np.asarray(mesh['normals']),np.asarray(mesh['indices']).reshape(-1,3)[:,::-1]
def surface(mesh):
    points,normals,faces=arrays(mesh)
    return BVHTree.FromPolygons(points.tolist(),faces.tolist(),all_triangles=True)
def nearest(points,reference):
    tree=KDTree(len(reference))
    for index,point in enumerate(reference):tree.insert(point,index)
    tree.balance()
    return max(tree.find(point)[2] for point in points)
front=float(front_z(-1.98))
for tier in ['simple','full']:
    old,new=baseline[tier],current[tier];measure={}
    before=sum(len(mesh['indices'])//3 for mesh in old.values())
    after=sum(len(mesh['indices'])//3 for mesh in new.values())
    check(after<before*1.10,tier+' vehicle triangles stay within the original 10 percent allowance')
    check(after<(50000 if tier=='simple' else 85000),tier+' native exterior leaves room inside the assembled budget')
    measure['native_triangles_before']=before;measure['native_triangles_after']=after
    for name,mesh in new.items():
        points,normals,faces=arrays(mesh)
        check(np.isfinite(points).all() and np.isfinite(normals).all(),tier+' '+name+' finite arrays')
        check(np.max(abs(np.linalg.norm(normals,axis=1)-1))<.003,tier+' '+name+' unit normals')
        if name not in ['hood_paint','hood_dark','body_paint','body_dark','body_red','body_accent','body_metal','body_amber','body_contour']:
            check(mesh==old[name],tier+' '+name+' complete native arrays retained')
    check(new['hood_paint']!=old['hood_paint'] and new['hood_dark']!=old['hood_dark'],tier+' both former hood surfaces replaced')
    paint=surface(new['hood_paint']);dark=surface(new['hood_dark']);body=surface(new['body_paint'])
    open_heights=[];depths=[]
    def inlet_hit(x,y):
        origin=(float(x),float(y),front-.15)
        white,*_=paint.ray_cast(origin,(0,0,1),.40)
        black,*_=dark.ray_cast(origin,(0,0,1),.40)
        if black is None or not .025<black.z-front<.10:return None
        if white is not None and white.z<black.z-.001:return None
        return black.z-front
    for y in np.linspace(.87,1.015,101):
        depth=inlet_hit(0,y)
        if depth is not None:open_heights.append(float(y));depths.append(float(depth))
    check(len(open_heights)>=12,tier+' central inlet opens forward through the paint surround')
    if open_heights:
        centre_y=float(np.mean(open_heights));width_samples=[]
        for x in np.linspace(-.34,.34,137):
            if inlet_hit(x,centre_y) is not None:width_samples.append(float(x))
        opening_width=max(width_samples)-min(width_samples) if width_samples else 0
        opening_height=max(open_heights)-min(open_heights)
        check(.50<opening_width<.62,tier+' inlet has the broad Challenger single-scoop proportion')
        check(.020<opening_height<.045,tier+' inlet has a shallow physical opening')
        check(min(depths)>.025,tier+' recessed intake has more than 25mm physical depth')
        measure['inlet_width_m']=opening_width;measure['inlet_height_m']=opening_height;measure['inlet_depth_m']=float(np.mean(depths))
    for sign in [-1,1]:
        x=sign*.535;z=-1.48
        black,*_=dark.ray_cast((x,2,z),(0,-1,0),2)
        white,*_=paint.ray_cast((x,2,z),(0,-1,0),2)
        banks=[paint.ray_cast((x+offset,2,z),(0,-1,0),2)[0] for offset in [-.115,.115]]
        check(black is not None and all(point is not None for point in banks),tier+f' extractor {sign} has an inset bed and two deck banks')
        if black is not None and all(point is not None for point in banks):
            recess=float(np.mean([point.y for point in banks])-black.y)
            check(.001<recess<.015,tier+f' extractor {sign} is physically recessed')
            check(white is None or white.y<black.y+.0002,tier+f' extractor {sign} opens through the main hood skin')
            obstructing,*_=body.ray_cast((x,2,z),(0,-1,0),2)
            check(obstructing is None or obstructing.y<black.y+.0002,tier+f' extractor {sign} clears adjoining bodywork')
            measure['extractor_'+str(sign)+'_recess_m']=recess
    points,normals,faces=arrays(new['hood_paint'])
    cross=np.cross(points[faces[:,1]]-points[faces[:,0]],points[faces[:,2]]-points[faces[:,0]])
    size=np.linalg.norm(cross,axis=1)
    agreement=np.sum(normals[faces].mean(1)*cross,axis=1)/np.maximum(size,1e-20)
    check(np.count_nonzero((agreement<-.03)&(size>1e-7))==0,tier+' replacement hood normals face with their geometric surfaces')
    old_points,_,_=arrays(old['body_paint']);body_points,_,_=arrays(new['body_paint'])
    old_roof=old_points[old_points[:,1]>1.10];new_roof=body_points[body_points[:,1]>1.10]
    roof_error=max(nearest(old_roof,new_roof),nearest(new_roof,old_roof))*1000
    check(roof_error<.15,tier+' roof and upper pillars retain native positions');measure['roof_error_mm']=roof_error
    old_body=surface(old['body_paint']);errors=[];coverage=True
    for z in np.arange(-1.6,1.96,.06):
        for y in [.45,.60,.72]:
            previous,*_=old_body.ray_cast((2,y,float(z)),(-1,0,0),2)
            actual,*_=body.ray_cast((2,y,float(z)),(-1,0,0),2)
            coverage &= (previous is None)==(actual is None)
            if previous is not None and actual is not None:errors.append(abs(previous.x-actual.x)*1000)
    check(coverage and max(errors)<2,tier+' accepted lower side surface retains coverage and position')
    measure['lower_side_max_error_mm']=max(errors)
    metrics[tier]=measure
result={'checks':len(checks),'failures':sum(not row['pass'] for row in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('CHALLENGER_REPLACEMENT_HOOD',result['checks'],'checks',result['failures'],'failures')
for row in checks:
    if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
