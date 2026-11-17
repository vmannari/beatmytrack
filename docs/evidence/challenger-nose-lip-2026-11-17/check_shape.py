"""Independent native checks for the replacement hood and its physical openings."""
from pathlib import Path
import json,sys
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-nose-lip-2026-11-17';BUILD=ROOT/'build'/OUT.name
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
        if name not in ['hood_paint','hood_dark','body_paint','body_contour']:
            check(mesh==old[name],tier+' '+name+' complete native arrays retained')
    check(new['hood_paint']!=old['hood_paint'],tier+' outer hood follows the repaired fender perimeter')
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
        for y in [.45,.60]:
            previous,*_=old_body.ray_cast((2,y,float(z)),(-1,0,0),2)
            actual,*_=body.ray_cast((2,y,float(z)),(-1,0,0),2)
            coverage &= (previous is None)==(actual is None)
            if previous is not None and actual is not None:errors.append(abs(previous.x-actual.x)*1000)
    check(coverage and max(errors)<2,tier+' accepted lower side surface retains coverage and position')
    measure['lower_side_max_error_mm']=max(errors)
    old_hood_points = np.asarray(old['hood_paint']['points'])
    centre_before = old_hood_points[(abs(old_hood_points[:,0]) < .40) & (old_hood_points[:,2] >= -1.95)]
    centre_after = points[(abs(points[:,0]) < .40) & (points[:,2] >= -1.95)]
    # glTF's default 16-bit attribute compression changes its bin widths when
    # the outer fringe lowers the hood AABB. Keep a 2um excess-error gate,
    # account only for the two independently measured quantization cells.
    centre_tree = KDTree(len(centre_after))
    for index,point in enumerate(centre_after):centre_tree.insert(point,index)
    centre_tree.balance()
    cell = (np.ptp(old_hood_points,axis=0)+np.ptp(points,axis=0))/65535
    errors = []
    raw_errors = []
    for point in centre_before:
        q,index,distance = centre_tree.find(point)
        raw_errors.append(distance*1000)
        errors.append(np.linalg.norm(np.maximum(abs(centre_after[index]-point)-cell,0))*1000)
    check(max(errors)<.002,tier+' intake and deck behind the repaired leading strip stay within the measured packing cells plus two micrometres')
    conversion=json.loads((BUILD/'converted/manifest.json').read_text())
    check(conversion['tiers'][tier]['convex_fenders']['protected_centre_source_error_metres']==0,tier+' source centre intake and deck positions remain exactly unchanged')
    measure['centre_hood_raw_packing_error_mm']=max(raw_errors)
    measure['centre_hood_excess_error_mm']=max(errors)
    measure['centre_packing_cells_mm']=(cell*1000).tolist()
    rear_old = old_points[old_points[:,2] > -.65]
    rear_new = body_points[body_points[:,2] > -.65]
    rear_error = max(nearest(rear_old,rear_new),nearest(rear_new,rear_old))*1000
    check(rear_error < .002,tier+' accepted rear body geometry retained')
    measure['rear_body_error_mm'] = rear_error
    # Coincident shoulder stations belong to one continuous paint surface.
    # Check their packed normals independently of the producing field.
    body_p,body_n,_ = arrays(new['body_paint'])
    belt = .767+.038*(body_p[:,2]+2.065)/1.205
    selected = (abs(body_p[:,1]-belt)<.00001)&(body_p[:,0]>.75)&(body_p[:,2]>-2.0)&(body_p[:,2]<-.93)&(body_n[:,0]>.1)&(body_n[:,1]>.1)
    groups = {}
    for point,normal in zip(body_p[selected],body_n[selected]):
        groups.setdefault(tuple(np.round(point,6)),[]).append(normal)
    shared = [np.asarray(rows) for rows in groups.values() if len(rows)>1]
    maximum_angle = 0.0
    for rows in shared:
        rows = rows/np.linalg.norm(rows,axis=1)[:,None]
        maximum_angle = max(maximum_angle,float(np.degrees(np.arccos(np.clip((rows@rows.T).min(),-1,1)))))
    check(len(groups)>20,tier+' substantial shared native shoulder normal stations, including welded vertices')
    check(maximum_angle<1.0,tier+' crown and shoulder packed normals join within one degree')
    measure['shared_shoulder_normal_stations']=len(groups)
    measure['split_shoulder_normal_stations']=len(shared)
    measure['maximum_shoulder_normal_gap_degrees']=maximum_angle
    metrics[tier]=measure
result={'checks':len(checks),'failures':sum(not row['pass'] for row in checks),'assertions':checks,'metrics':metrics}
(OUT/(label+'-shape.json')).write_text(json.dumps(result,indent=2))
print('CHALLENGER_REPLACEMENT_HOOD',result['checks'],'checks',result['failures'],'failures')
for row in checks:
    if not row['pass']:print('FAIL',row['name'])
if result['failures']:raise SystemExit(1)
