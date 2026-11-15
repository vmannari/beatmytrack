"""Blender offline conversion of the owner-supplied CC-BY Hellcat.

Run with factory startup and --disable-autoexec. No embedded scripts, Rigacar,
source textures, studio objects or rig are exported. The source is never saved.
"""
import bpy
import bmesh
import hashlib
import json
import math
import numpy as np
from pathlib import Path
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import delaunay_2d_cdt
sys.path.insert(0,str(Path(__file__).resolve().parent))
import challenger_detail_geometry as exterior_detail
import challenger_shell_geometry as shell_geometry
import challenger_clean_panels as clean_panels
import challenger_exterior_geometry as manufactured_exterior
from challenger_panel_geometry import SideSurface, SampledHood, PaneSurface, FenderSurface, PanelJoinFairing
from challenger_reference_geometry import ReferenceBody, nose_distance, nose_inverse, nose_normals, nose_plan_points, nose_plan_normals, nose_corner_field, nose_corner_normals

args = sys.argv[sys.argv.index("--")+1:]
source, labels_file, output = map(Path,args[:3])
output.mkdir(parents=True,exist_ok=True)
cached_source=source.suffix.lower()=='.npz'
source_facts=None
if cached_source:
    source_facts=json.loads(source.with_name('source-facts.json').read_text(encoding='utf-8'))
    cached=np.load(source,allow_pickle=False)
    wheel_data={name:np.asarray(value) for name,value in source_facts['source_wheel_centres'].items()}
    original_front=float(np.mean([c[1] for n,c in wheel_data.items() if '.Ft.' in n]))
    original_centre=float(np.mean([c[0] for c in wheel_data.values()]))
    original_z=float(np.mean([c[2] for c in wheel_data.values()]))
    original_scale=np.asarray(source_facts['body_scale_xyz'])
    game_points=cached['co']
    restored=np.c_[original_centre-game_points[:,0]/original_scale[0],(game_points[:,2]+1.28)/original_scale[1]+original_front,(game_points[:,1]-.37)/original_scale[2]+original_z]
    data=bpy.data.meshes.new('RetainedMeasuredBody')
    data.from_pydata(restored.tolist(),[],cached['tri'].tolist());data.update()
    for index in range(int(cached['mi'].max())+1):data.materials.append(bpy.data.materials.new(source_facts['cached_material_names'].get(str(index),'Unused'+str(index))))
    data.polygons.foreach_set('material_index',cached['mi'].astype(np.int32))
    for polygon in data.polygons:polygon.use_smooth=True
    body=bpy.data.objects.new('Hellcat-Body',data);bpy.context.scene.collection.objects.link(body)
else:
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
    body=bpy.data.objects['Hellcat-Body']
labels=np.load(labels_file)['labels']
mesh=body.data;mesh.calc_loop_triangles()
co=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',co);co=co.reshape(-1,3)
tri=np.empty(len(mesh.loop_triangles)*3,dtype=np.int32);mesh.loop_triangles.foreach_get('vertices',tri);tri=tri.reshape(-1,3)
mi=np.empty(len(mesh.loop_triangles),dtype=np.int32);mesh.loop_triangles.foreach_get('material_index',mi)
component=labels[tri[:,0]]
world=np.array(body.matrix_world,dtype=np.float64)
body_world=co@world[:3,:3].T+world[:3,3]
original_wheels={o.name:o for o in bpy.data.objects if o.name.startswith('Hellcat-Wheel.')}
wheel_centres=wheel_data if cached_source else {name:np.mean([np.array(o.matrix_world@Vector(c)) for c in o.bound_box],axis=0) for name,o in original_wheels.items()}
front_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Ft.' in n]))
rear_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Bk.' in n]))
centre_x=float(np.mean([c[0] for c in wheel_centres.values()]));wheel_z=float(np.mean([c[2] for c in wheel_centres.values()]))
scale=np.array([1.50,2.56/(rear_y-front_y),0.37/0.26099])

def game(points):
    return np.c_[-(points[:,0]-centre_x)*scale[0],(points[:,2]-wheel_z)*scale[2]+0.37,(points[:,1]-front_y)*scale[1]-1.28]

def blender(points): return np.c_[points[:,0],-points[:,2],points[:,1]]
fitted_body=game(body_world)
rear_components=[3150,3156,5779,305156,305161,305248,305253,3271,3276,5906,5911,3467,3472,6102,6107,3451,3456,6086,6091]
rear_fascia_bvh=BVHTree.FromPolygons(fitted_body.tolist(),tri[np.isin(component,rear_components)].tolist(),all_triangles=True)
def rear_terms(x,y):
    x=(np.asarray(x)-.005)/.8;y=(np.asarray(y)-.854)/.1
    return np.stack([x**i*y**j for i in range(5) for j in range(4)],axis=-1)
rear_samples=[]
for x in np.linspace(-.79,.80,81):
    for y in np.linspace(.772,.936,32):
        hit=rear_fascia_bvh.ray_cast((float(x),float(y),3),(0,0,-1),2)[0]
        if hit is not None:rear_samples.append([x,y,hit.z])
rear_samples=np.asarray(rear_samples);rear_design=rear_terms(rear_samples[:,0],rear_samples[:,1]);rear_keep=np.ones(len(rear_samples),dtype=bool)
for iteration in range(4):
    rear_coeff=np.linalg.lstsq(rear_design[rear_keep],rear_samples[rear_keep,2],rcond=None)[0]
    rear_keep=abs(rear_design@rear_coeff-rear_samples[:,2])<.012
assert rear_keep.mean()>.75, 'Rear surface must fit the majority of the measured outer fascia'
print('REAR_SURFACE_FIT',len(rear_samples),int(rear_keep.sum()),float(np.percentile(abs(rear_design@rear_coeff-rear_samples[:,2]),95)),flush=True)
def rear_surface(x,y):
    # Fit the full compound curve, including the tucked upper edge and old lamp
    # openings. A smooth field avoids copying source optical seams into paint.
    return float(rear_terms(x,y)@rear_coeff)+.003

def smooth(a,b,value):
    t=np.clip((value-a)/(b-a),0,1)
    return t*t*(3-2*t)

def nose(points):
    result=np.array(points,copy=True)
    result[:,2]=-nose_distance(-result[:,2],result[:,0])[0]
    return result

# Fit the continuous side skin to dense, unmodified exterior samples. Robust
# rejection keeps the original handle recesses and door gaps out of the fit.
side_faces=tri[np.isin(component,[1464,1491,1862,4445])]
side_bvh=BVHTree.FromPolygons(fitted_body.tolist(),side_faces.tolist(),all_triangles=True)
side_panel=SideSurface(fitted_body,tri,component,side_bvh)
body_centre_x=side_panel.centre_x
side_x=side_panel.width
CAP_Y,CAP_Z=.99,1.31
CAP_RY,CAP_RZ=.095,.125
def cap_x(y,z):return side_x(y,z)-body_centre_x

clean_body=fitted_body.copy()
source_nx=np.empty(len(mesh.vertices),dtype=np.float32)
source_normals=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('normal',source_normals)
source_nx=-source_normals.reshape(-1,3)[:,0]
outward_strength=source_nx*np.sign(clean_body[:,0])
outward=outward_strength>.2
side_region=outward&(abs(clean_body[:,0])>.65)&(clean_body[:,1]>.285)&(clean_body[:,1]<1.105)&(clean_body[:,2]>-1.98)&(clean_body[:,2]<2.18)
def side_weight(y,z):return smooth(.285,.32,y)*(1-smooth(.965,1.025,y))*smooth(-1.98,-1.88,z)*(1-smooth(2.10,2.18,z))
weight=side_weight(clean_body[side_region,1],clean_body[side_region,2])
target=body_centre_x+np.sign(clean_body[side_region,0])*side_x(clean_body[side_region,1],clean_body[side_region,2])
weight*=smooth(.35,.75,outward_strength[side_region])*(abs(target-clean_body[side_region,0])<.030)
clean_body[side_region,0]=clean_body[side_region,0]*(1-weight)+(body_centre_x+np.sign(clean_body[side_region,0])*side_x(clean_body[side_region,1],clean_body[side_region,2]))*weight
cap_radius=np.sqrt(((clean_body[:,1]-CAP_Y)/CAP_RY)**2+((clean_body[:,2]-CAP_Z)/CAP_RZ)**2)
cap_region=(clean_body[:,0]<-.70)&(cap_radius<1.25)
cap_weight=1-smooth(.78,1.10,cap_radius[cap_region])
clean_body[cap_region,0]=clean_body[cap_region,0]*(1-cap_weight)-cap_x(clean_body[cap_region,1],clean_body[cap_region,2])*cap_weight

def side_surface(y,z,sign):
    return abs(body_centre_x+sign*side_x(y,z))

def hood_y(x,z):return hood_panel.height(x,z)

# Inverse of the local nose warp, also used by side normals after reduction.
def unwarp_z(z,x=0):return nose_inverse(np.asarray(z,dtype=float),x)

def side_normal(x,y,warped_z):
    z,stretch=unwarp_z(warped_z,x);e=.0002
    dy=(side_x(y+e,z)-side_x(y-e,z))/(2*e)
    dz=(side_x(y,z+e)-side_x(y,z-e))/(2*e)
    normal=np.stack([np.sign(np.asarray(x)-body_centre_x),-dy,-dz],axis=-1)
    return nose_normals(np.stack([x,y,z],axis=-1),normal)

def hull2(points):
    values=sorted(set(map(tuple,np.round(points,6))))
    def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower=[];upper=[]
    for p in values:
        while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    for p in values[::-1]:
        while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    return np.array(lower[:-1]+upper[:-1])

def simplify_open(points,tolerance):
    if len(points)<3:return points
    a,b=points[0],points[-1];delta=b-a
    t=np.clip(((points-a)@delta)/max(delta@delta,1e-18),0,1)
    distance=np.linalg.norm(points-a-t[:,None]*delta,axis=1);index=int(distance.argmax())
    if distance[index]<tolerance:return points[[0,-1]]
    return np.concatenate([simplify_open(points[:index+1],tolerance)[:-1],simplify_open(points[index:],tolerance)])
def simplify_closed(points,tolerance=.001):
    split=np.linalg.norm(points-points[0],axis=1).argmax()
    return np.concatenate([simplify_open(points[:split+1],tolerance)[:-1],simplify_open(np.concatenate([points[split:],points[:1]]),tolerance)[:-1]])
door_outline=simplify_closed(hull2(fitted_body[labels==1862][:,[1,2]]))

# Retain the original stock hood. A separate measured profile seats fitted kits.
hood_faces=tri[component==1572];hp=fitted_body[hood_faces]
hn=np.cross(hp[:,1]-hp[:,0],hp[:,2]-hp[:,0]);hn/=np.maximum(np.linalg.norm(hn,axis=1)[:,None],1e-12)
top_faces=hood_faces[hn[:,1]>.3]
hood_bvh=BVHTree.FromPolygons(fitted_body.tolist(),top_faces.tolist(),all_triangles=True)
hood_points=fitted_body[np.unique(hood_faces)]
low,high=hood_points.min(0),hood_points.max(0)
hood_panel=SampledHood(hood_bvh,(low,high))
fp=clean_body[tri];fn=np.cross(fp[:,1]-fp[:,0],fp[:,2]-fp[:,0]);fc=fp.mean(1)
fender_mask=np.isin(component,[1464,1491])&(mi==[i for i,m in enumerate(mesh.materials) if m.name=='Car Paint'][0])
fender_mask&=(fn[:,1]>.70*np.linalg.norm(fn,axis=1))&(fc[:,1]>.79)&(fc[:,2]>-1.99)&(fc[:,2]<-.73)&(np.abs(fp[:,:,0]).min(1)>.69)
fender_top_faces=tri[fender_mask]
fender_top_bvh=BVHTree.FromPolygons(clean_body.tolist(),fender_top_faces.tolist(),all_triangles=True)
fender_side_mask=np.isin(component,[1464,1491])&(mi==[i for i,m in enumerate(mesh.materials) if m.name=='Car Paint'][0])&~fender_mask
fender_side_mask&=(fn[:,0]*np.sign(fc[:,0])>.35*np.linalg.norm(fn,axis=1))&(fc[:,1]>.78)&(fc[:,2]>-1.99)&(fc[:,2]<-.73)&(np.abs(fp[:,:,0]).min(1)>.69)
fender_cut=fender_mask|fender_side_mask
front_join_source_indices=set(np.intersect1d(np.unique(tri[fender_cut]),np.unique(tri[~fender_cut&np.isin(component,[1464,1491])])).tolist())
fender_fields={}
for sign in [-1,1]:
    faces=tri[(fender_mask|fender_side_mask)&(np.sign(fc[:,0])==sign)]
    bvh=BVHTree.FromPolygons(clean_body.tolist(),faces.tolist(),all_triangles=True)
    fender_fields[sign]=(FenderSurface(bvh,sign,body_centre_x),bvh,faces)
print('FENDER_FAIRING',{s:f[0].stats for s,f in fender_fields.items()},flush=True)
paint_index=[i for i,m in enumerate(mesh.materials) if m.name=='Car Paint'][0]
join_faces=tri[np.isin(component,[1464,1491,1624,1862,4445])&(mi==paint_index)]
join_fairing=PanelJoinFairing(BVHTree.FromPolygons(clean_body.tolist(),join_faces.tolist(),all_triangles=True),body_centre_x)
hood_edges=np.sort(np.concatenate([top_faces[:,[0,1]],top_faces[:,[1,2]],top_faces[:,[2,0]]]),axis=1)
hood_edge_ids,hood_edge_counts=np.unique(hood_edges,axis=0,return_counts=True)
reference_hood_boundary=fitted_body[np.unique(hood_edge_ids[hood_edge_counts==1])]
reference_body=ReferenceBody(side_panel,reference_hood_boundary)
(output/'reference_profile.json').write_text(json.dumps({'centre_x':body_centre_x,'y':side_panel.a.tolist(),'z':side_panel.b.tolist(),'widths':side_panel.grid.values.tolist()}),encoding='utf-8')
print('PANEL_JOIN_FAIRING',join_fairing.stats,flush=True)
(output/'join_fairing.json').write_text(json.dumps({'centre_x':body_centre_x,'patches':[[*p[:-1],p[-1].tolist()] for p in join_fairing.patches]}),encoding='utf-8')
clean_hood=clean_panels.CleanHood()
(output/'hood_profile.json').write_text(json.dumps(hood_panel.profile(),separators=(',',':')),encoding='utf-8')
(output/'bonnet_contour.json').write_text(json.dumps({'baked':True,'method':'symmetric analytic bonnet boundary','physical_width_metres':.0025,'points':clean_hood.boundary().tolist()},indent=2),encoding='utf-8')
print('SOURCE_PANEL_FIELDS',side_panel.stats,hood_panel.stats,flush=True)
pane_surfaces={}
for key in np.unique(component):
    faces=tri[component==key]
    if {mesh.materials[int(i)].name for i in np.unique(mi[component==key])}!={'Basic Glass'}:continue
    pane_surfaces[int(key)]=PaneSurface(fitted_body[np.unique(faces)])

def nearest_boundary(points,boundary):
    a=boundary;b=np.roll(boundary,-1,axis=0);delta=b-a
    rel=points[:,None,:]-a[None,:,:]
    t=np.clip(np.sum(rel*delta,axis=2)/np.maximum(np.sum(delta*delta,axis=1),1e-18),0,1)
    nearest=a[None,:,:]+t[:,:,None]*delta[None,:,:]
    distance=np.linalg.norm(points[:,None,:]-nearest,axis=2);index=distance.argmin(1)
    return distance[np.arange(len(points)),index],index,t[np.arange(len(points)),index]
def inside_polygon(point,boundary):
    y,z=point;inside=False
    for a,b in zip(boundary,np.roll(boundary,-1,axis=0)):
        if (a[1]>z)!=(b[1]>z) and y<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    return inside

def lattice(boundary,spacing,holes=(),feature_lines=()):
    spacing_a,spacing_b=(spacing,spacing) if np.isscalar(spacing) else spacing
    low,high=boundary.min(0),boundary.max(0);points=[]
    for y in np.arange(low[0]+spacing_a*.5,high[0],spacing_a):
        for z in np.arange(low[1]+spacing_b*.5,high[1],spacing_b):
            if inside_polygon((y,z),boundary) and not any(inside_polygon((y,z),h) for h in holes):points.append([y,z])
    loops=[boundary,*holes];edges=[];offset=0
    for loop in loops:
        edges.extend([(offset+i,offset+(i+1)%len(loop)) for i in range(len(loop))]);offset+=len(loop)
    points=np.concatenate([*loops,np.asarray(points).reshape(-1,2)])
    for line in feature_lines:
        prior=None
        for point in line:
            if not inside_polygon(point,boundary) or any(inside_polygon(point,h) for h in holes):prior=None;continue
            index=len(points);points=np.vstack([points,point])
            if prior is not None and not any(inside_polygon((points[prior]+point)*.5,h) for h in holes):edges.append((prior,index))
            prior=index
    vertices,_,faces,*_=delaunay_2d_cdt([Vector(p) for p in points],edges,[],0,1e-6,False)
    vertices=np.array(vertices)
    faces=[f for f in faces if inside_polygon(vertices[f].mean(0),boundary) and not any(inside_polygon(vertices[f].mean(0),h) for h in holes)]
    return vertices,faces

def build_fender_charts(add,simple):
    for sign,(field,bvh,faces) in fender_fields.items():
        edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
        unique,counts=np.unique(edges,axis=0,return_counts=True);edges=unique[counts==1]
        used=np.unique(edges);lookup={int(v):i for i,v in enumerate(used)}
        angles,zs=field.parameters(clean_body[used]);uv=np.c_[angles,zs]
        samples=uv.tolist();constraints=[(lookup[int(a)],lookup[int(b)]) for a,b in edges]
        for angle in np.arange(uv[:,0].min(),uv[:,0].max(),.065 if simple else .050):
            for z in np.arange(-1.99,-.73,.055 if simple else .040):
                direction=np.array([sign*np.sin(angle),np.cos(angle),0.0]);origin=np.array([field.cx,field.cy,z])+2*direction
                if bvh.ray_cast(origin.tolist(),(-direction).tolist(),2)[0] is not None:samples.append([angle,z])
        samples,_,triangles,*_=delaunay_2d_cdt([Vector(p) for p in samples],constraints,[],0,1e-6,False)
        parameters=np.asarray(samples);vertices=field.point(parameters[:,0],parameters[:,1])
        # Keep the actual outer boundary attached to the untouched neighbouring
        # panels. Interior points follow the fair measured radial surface.
        ea=np.asarray([lookup[int(a)] for a,_ in edges]);eb=np.asarray([lookup[int(b)] for _,b in edges])
        delta=uv[eb]-uv[ea];rel=parameters[:,None,:]-uv[ea][None,:,:]
        t=np.clip(np.sum(rel*delta,axis=2)/np.maximum(np.sum(delta*delta,axis=1),1e-18),0,1)
        distance=np.linalg.norm(rel-t[:,:,None]*delta[None,:,:],axis=2);nearest=distance.argmin(1)
        for i in np.flatnonzero(distance[np.arange(len(parameters)),nearest]<1e-6):
            a,b=edges[nearest[i]];amount=t[i,nearest[i]]
            vertices[i]=clean_body[a]*(1-amount)+clean_body[b]*amount
        def on_source(face):
            angle,z=parameters[list(face)].mean(0)
            direction=np.array([sign*np.sin(angle),np.cos(angle),0.0]);origin=np.array([field.cx,field.cy,z])+2*direction
            return bvh.ray_cast(origin.tolist(),(-direction).tolist(),2)[0] is not None
        triangles=[f for f in triangles if on_source(f)]
        normals=nose_normals(vertices,field.normal(parameters[:,0],parameters[:,1]))
        triangles=[tuple(reversed(f)) if np.cross(vertices[f[1]]-vertices[f[0]],vertices[f[2]]-vertices[f[0]])@normals[list(f)].mean(0)<0 else f for f in triangles]
        add('FairFrontFender'+str(sign),vertices,triangles,'paint','body',orient=False,normal_values=normals)

def source_hood_mesh(samples,constraints,boundary_ids):
    uv,_,faces,*_=delaunay_2d_cdt([Vector(p) for p in samples],constraints,[],0,1e-6,False)
    vertices=[]
    for p in uv:
        hit=hood_bvh.ray_cast((p.x,2,p.y),(0,-1,0),3)[0]
        if hit is None:
            nearest=np.argmin(np.sum((fitted_body[boundary_ids][:,[0,2]]-np.array([p.x,p.y]))**2,axis=1))
            height=fitted_body[boundary_ids[nearest],1]
        else:height=hit.y
        vertices.append([p.x,height,p.y])
    faces=[f for f in faces if hood_bvh.ray_cast((float(np.mean([uv[i].x for i in f])),2,float(np.mean([uv[i].y for i in f]))),(0,-1,0),3)[0] is not None]
    return np.asarray(vertices),faces

ROLE={'Car Paint':'paint','Paint':'accent','Basic Glass':'glass','Mirror':'mirror','Matter Black':'dark',
      'Gloss Black':'accent','Chrome':'chrome','Metal09':'dark','Black Metal':'dark',
      'Red Light':'red','White Light':'white','Headlight Glow':'white','Orange Light':'amber',
      'Cranberry Juice':'red','Material':'dark','Rim':'detail','Composite Rubber':'rubber'}
materials={}
for name,color in {'paint':(.55,.04,.025,1),'accent':(.025,.033,.038,1),'glass':(.025,.045,.057,1),
                   'mirror':(.36,.42,.44,1),'dark':(.016,.021,.025,1),'chrome':(.48,.53,.54,1),
                   'red':(.48,.015,.01,1),'white':(.65,.69,.66,1),'amber':(.65,.22,.01,1),
                   'detail':(.40,.44,.45,1),'rubber':(.014,.018,.02,1),'reverse':(.08,.065,.065,1)}.items():
    m=bpy.data.materials.new('BMT_'+name);m.diffuse_color=color;materials[name]=m
m=bpy.data.materials.new('BMT_contour');m.diffuse_color=(.035,.044,.048,1);materials['contour']=m
for role,color in {'led':(.65,.69,.66,1),'lens_red':(.08,.006,.005,1),'vent_metal':(.045,.052,.057,1)}.items():
    m=bpy.data.materials.new('BMT_'+role);m.diffuse_color=color;materials[role]=m

all_source=list(bpy.data.objects)
for obj in all_source: obj.hide_render=True;obj.hide_set(True)

record={'source_sha256':source_facts['source_sha256'] if cached_source else hashlib.sha256(source.read_bytes()).hexdigest(), 'source_triangles':len(tri)+sum(len(o.data.polygons)*2 for o in original_wheels.values()),
        'body_source_triangles':len(tri),'source':str(source),'source_wheel_centres':{k:v.tolist() for k,v in wheel_centres.items()},
        'body_scale_xyz':scale.tolist(),'tiers':{},'removed_components':[],'native_materials_only':True}

def new_piece(name, points, faces, mat_indices, mat_names):
    used,faces=np.unique(np.asarray(faces).ravel(),return_inverse=True)
    data=bpy.data.meshes.new(name);data.from_pydata(blender(points[used]).tolist(),[],faces.reshape(-1,3).tolist());data.update()
    for n in mat_names:data.materials.append(materials[ROLE.get(n,'dark')])
    data.polygons.foreach_set('material_index',np.asarray(mat_indices,dtype=np.int32))
    for p in data.polygons:p.use_smooth=True
    obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj)
    if name in ['body_1464','body_1491']:
        joined=[i for i,v in enumerate(used) if int(v) in front_join_source_indices]
        if joined:obj['front_join_indices']=joined
    return obj

def reduce(obj, target):
    obj.hide_set(False);obj.hide_render=False;bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    obj.data.calc_loop_triangles();before=len(obj.data.loop_triangles)
    reference=None
    if before>target:
        reference=obj.copy();reference.data=obj.data.copy();bpy.context.scene.collection.objects.link(reference)
        reference.hide_set(True);reference.hide_render=True
        mod=obj.modifiers.new('Offline silhouette reduction','DECIMATE')
        glass=all(obj.data.materials[p.material_index].name=='BMT_glass' for p in obj.data.polygons)
        roof=obj.name.startswith('body_2149')
        factory_hood=obj.name.startswith('hood_')
        hood_top=obj.name.startswith('hood_1572')
        if glass or roof or (factory_hood and not hood_top):
            mod.decimate_type='DISSOLVE';mod.angle_limit=math.radians(2.0);mod.use_dissolve_boundaries=False
            if factory_hood:
                angle=12.0 if simple else 8.0
                mod.angle_limit=math.radians(angle)
        else:
            mod.ratio=target/float(before);mod.use_collapse_triangulate=True
            protected=[]
            if obj.name.split('.')[0] in ['body_1464','body_1491']:
                protected=list(obj.get('front_join_indices',[]))
                if protected:
                    group=obj.vertex_groups.new(name='RetainJoinedFenderBoundary')
                    group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE');group.add(protected,0.0,'REPLACE')
                    mod.vertex_group=group.name;mod.vertex_group_factor=1000
                    protected_points=[tuple(obj.data.vertices[i].co) for i in protected]
        bpy.ops.object.modifier_apply(modifier=mod.name)
        if not (glass or roof or factory_hood) and protected:
            remaining={tuple(v.co) for v in obj.data.vertices}
            retained=sum(p in remaining for p in protected_points)
            print('FRONT_BOUNDARY_CONTROL',obj.name,simple,retained,len(protected_points),flush=True)
            assert retained==len(protected_points),'Reduced neighbours must retain every joined fender boundary vertex'
    obj.data.set_sharp_from_angle(angle=math.radians(52))
    if reference is not None:
        transfer=obj.modifiers.new('Retain dense surface normals','DATA_TRANSFER');transfer.object=reference
        transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'};transfer.loop_mapping='POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        bpy.data.objects.remove(reference,do_unlink=True)
    # All central panels share the same fitted tangent field, including joins.
    # Normal transfer must not reintroduce the original separate-door shading.
    if obj.name.split('.')[0] in ['body_1464','body_1491']:
        coords=np.asarray([v.co[:] for v in obj.data.vertices])
        xs,ys,zs=coords[:,0],coords[:,2],-coords[:,1]
        source_z,_=unwarp_z(zs,xs)
        field_normals=side_normal(xs,ys,zs)[:,[0,2,1]];field_normals[:,1]*=-1
        field_weights=side_weight(ys,source_z)
        caps=np.sqrt(((ys-CAP_Y)/CAP_RY)**2+((source_z-CAP_Z)/CAP_RZ)**2)
        field_weights=np.where(xs<0,np.maximum(field_weights,1-smooth(.78,1.10,caps)),field_weights)
        on_surface=(abs(xs)>.65)&(ys>.285)&(ys<1.105)&(source_z>-1.98)&(source_z<2.18)&(abs(abs(xs-body_centre_x)-side_x(ys,source_z))<.030)
        front_normals=np.zeros_like(field_normals);front_weights=np.zeros(len(coords))
        for sign,(field,_,_) in fender_fields.items():
            selected=(xs*sign>.65)&(ys>.65)&(ys<1.08)&(source_z>-2.03)&(source_z<-.70)
            points=np.c_[xs[selected],ys[selected],source_z[selected]];angle,z=field.parameters(points)
            angle=np.clip(angle,.10,1.40)
            n=nose_normals(points,field.normal(angle,z))
            front_normals[selected]=n[:,[0,2,1]]*np.array([1,-1,1])
            front_weights[selected]=smooth(.65,.72,abs(xs[selected]))*smooth(-2.03,-1.99,z)*(1-smooth(-.78,-.70,z))*smooth(.65,.72,ys[selected])*(1-smooth(1.02,1.08,ys[selected]))
        values=[]
        for polygon in obj.data.polygons:
            paint=obj.data.materials[polygon.material_index].name=='BMT_paint'
            for loop in polygon.loop_indices:
                n=obj.data.corner_normals[loop].vector;vertex=obj.data.loops[loop].vertex_index
                if paint and on_surface[vertex] and n.x*np.sign(xs[vertex])>.05:
                    weight=field_weights[vertex]*smooth(.35,.75,n.x*np.sign(xs[vertex]))
                    n=np.asarray(n)*(1-weight)+field_normals[vertex]*weight;n/=max(np.linalg.norm(n),1e-12)
                if paint and front_weights[vertex]>0:
                    weight=front_weights[vertex]
                    n=np.asarray(n)*(1-weight)+front_normals[vertex]*weight;n/=max(np.linalg.norm(n),1e-12)
                values.append(tuple(n))
        obj.data.normals_split_custom_set(values)
    obj.data.calc_loop_triangles();obj.select_set(False)
    if obj.name.startswith('body_') and all(obj.data.materials[p.material_index].name=='BMT_glass' for p in obj.data.polygons):
        key=int(obj.name.split('_')[1].split('.')[0])
        points=np.asarray([(v.co.x,v.co.z,-v.co.y) for v in obj.data.vertices])
        normals=pane_surfaces[key].normal(points)[:,[0,2,1]];normals[:,1]*=-1
        obj.data.normals_split_custom_set([normals[loop.vertex_index] for loop in obj.data.loops])
    return len(obj.data.loop_triangles)

def body_target(key, count, simple):
    explicit={1464:(6200,3000),1491:(2800,2200),1572:(5000,3000),1624:(2400,1500),2149:(2000,1200),
              1862:(700,420),4445:(700,420),2790:(900,450)}
    if key in explicit:return explicit[key][1 if simple else 0]
    return min(count,max(40 if simple else 72,int(count*(.018 if simple else .035))))

for simple in [False,True]:
    tier='simple' if simple else 'full';pieces=[];groups={};statistics=[]
    bpy.ops.object.select_all(action='DESELECT')
    for key in np.unique(component):
        mask=component==key;faces=tri[mask];indices=mi[mask];count=len(faces)
        keep=~(fender_mask|fender_side_mask)[mask];faces=faces[keep];indices=indices[keep]
        if len(faces)==0:continue
        names={mesh.materials[int(i)].name for i in np.unique(indices)}
        pts=co[np.unique(faces)];low,high=pts.min(0),pts.max(0)
        badge=any(n.startswith('SVGMat') for n in names) or int(key) in [415457,417915]
        badge=badge or (names=={'Black Metal'} and low[1]>1.28 and max(abs(low[0]),abs(high[0]))<.16)
        tiny=count<128
        interior=int(key) in [0,732]
        replaced=int(key) in [1572,1862,4445,3632,6269,6720,430273]
        # Replace the fragile reduced optics/applique/exhaust with clean,
        # manufactured surfaces. Paint and structural bumper openings stay.
        game_points=fitted_body[np.unique(faces)];glo,ghi=game_points.min(0),game_points.max(0)
        front_optic=not ('Car Paint' in names) and max(abs(glo[0]),abs(ghi[0]))>.45 and glo[1]>.60 and ghi[1]<.82 and glo[2]>-2.02 and ghi[2]<-1.73
        replaced=replaced or front_optic or int(key) in rear_components+[325044,352278,325204,352438,429333,429455,429503,429627]
        if badge or tiny or interior or replaced:
            if not simple:record['removed_components'].append({'component':int(key),'triangles':count,'reason':'cabin floor' if interior else 'authored exterior replacement' if replaced else 'badge geometry' if badge else 'micro grille/hidden detail'})
            continue
        if names=={'Basic Glass'}:
            pane=pane_surfaces[int(key)]
            # Export one regular outer skin per pane. Preserve curvature without
            # irregular long reduced triangles or backing/pane intersections.
            source_points=fitted_body[np.unique(faces)]
            local=(source_points-pane.centre)@pane.axes.T
            boundary=simplify_closed(hull2(local[:,:2]),.0005)*1.02
            uv,pane_faces=lattice(boundary,.060 if simple else .045)
            pane_points=pane.points(uv)+pane.axes[-1]*.003
            pane_faces=np.asarray(pane_faces,dtype=np.int32)
            p=pane_points[pane_faces];normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
            reverse=normal@pane.axes[-1]<0
            pane_faces[reverse]=pane_faces[reverse][:,::-1]
            obj=new_piece('body_'+str(key),pane_points,pane_faces,np.zeros(len(pane_faces),dtype=int),['Basic Glass'])
            after=reduce(obj,len(pane_faces));pieces.append(obj);groups[obj.name]='body'
            statistics.append({'component':int(key),'group':'body','before':count,'after':after,'purpose':'single smooth opaque exterior pane'})
            continue
        if int(key)==1572:
            original=fitted_body[faces];normal=np.cross(original[:,1]-original[:,0],original[:,2]-original[:,0])
            outside=normal[:,1]>.3*np.linalg.norm(normal,axis=1)
            faces=faces[outside];indices=indices[outside]
        if int(key)==1464:
            centre=fitted_body[faces].mean(1)
            cap=(centre[:,0]<-.70)&(((centre[:,1]-CAP_Y)/CAP_RY)**2+((centre[:,2]-CAP_Z)/CAP_RZ)**2<1.25**2)
            p=clean_body[faces];normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
            # Flatten the original connected skin rather than laying another
            # disc over it. Folded/back-facing cap walls collapse and disappear.
            keep_faces=~cap|(normal[:,0]<-1e-12)
            faces=faces[keep_faces];indices=indices[keep_faces]
        if int(key) in [1464,1491]:
            original=fitted_body[faces];centres=original.mean(1)
            normals=np.cross(original[:,1]-original[:,0],original[:,2]-original[:,0])
            facing=normals[:,0]*np.sign(centres[:,0])>np.linalg.norm(normals,axis=1)*.35
            overlap=(abs(centres[:,0])>.65)&facing
            for index in np.flatnonzero(overlap):overlap[index]=inside_polygon(centres[index,[1,2]],door_outline)
            faces=faces[~overlap];indices=indices[~overlap]
        if int(key)==1491:
            # The source combines black seam/liner fragments into the fender.
            # Heavy reduction turns these tiny fragments into visible spikes.
            visible=np.array([mesh.materials[int(i)].name!='Matter Black' for i in indices])
            faces=faces[visible];indices=indices[visible]
        group='hood' if int(key) in [1572,321860,323444,323460] else 'aero' if int(key)==297986 else 'body'
        # Source side markers / lower reflectors are static red lenses. Only
        # the authored rear light guides join the brake-light material groups.
        if names in [{'White Light'},{'Headlight Glow'}] and high[1]<0:group='head_left' if (low[0]+high[0])*0.5>centre_x else 'head_right'
        material_names=[m.name for m in mesh.materials]
        if int(key) in [321860,323444,323460]:material_names=['Matter Black' if n=='Gloss Black' else n for n in material_names]
        if int(key)==436063:
            group='head_right';material_names=['Headlight Glow' if m=='Gloss Black' else m for m in material_names]
        points=clean_body if int(key) in [1464,1862,4445,1491] else fitted_body
        obj=new_piece(group+'_'+str(key),nose(points),faces,indices,material_names)
        after=reduce(obj,body_target(int(key),count,simple))
        pieces.append(obj)
        groups[obj.name]=group;statistics.append({'component':int(key),'group':group,'before':count,'after':after})
    def add_surface(name,points,faces,role,group,orient=True,normal_values=None):
        points=np.asarray(points)
        if name in ['GrilleRecess','GrillePerimeter','OpenHoneycombGrille']:
            # The factory centre aperture is y=0.667..0.780. Fit all three
            # authored grille layers together; projector pockets stay separate.
            points=points.copy();points[:,1]=.724+.70*(points[:,1]-.711)
        clean=[]
        for face in faces:
            p=points[list(face)];normal=np.cross(p[1]-p[0],p[2]-p[0])
            hint=np.array([0,1,0]) if group=='hood' else np.array([np.sign(p[:,0].mean()),0,0])
            clean.append(tuple(reversed(face)) if orient and normal@hint<0 else face)
        faces=clean
        data=bpy.data.meshes.new(name);data.from_pydata(blender(nose(np.asarray(points))),[],faces);data.materials.append(materials[role]);data.update()
        for polygon in data.polygons:polygon.use_smooth=True
        data.set_sharp_from_angle(angle=math.radians(48))
        if group=='body' and role=='paint' and normal_values is None:
            points=np.asarray([v.co[:] for v in data.vertices])
            normals=side_normal(points[:,0],points[:,2],-points[:,1])[:,[0,2,1]];normals[:,1]*=-1
            data.normals_split_custom_set([normals[loop.vertex_index] for loop in data.loops])
        if normal_values is not None:
            normals=np.asarray(normal_values)[:,[0,2,1]];normals[:,1]*=-1
            data.normals_split_custom_set([normals[loop.vertex_index] for loop in data.loops])
        if group=='hood' and role=='paint':
            points=np.asarray([v.co[:] for v in data.vertices]);z,stretch=unwarp_z(-points[:,1],points[:,0])
            normals=nose_normals(np.c_[points[:,0],points[:,2],z],hood_panel.normal(points[:,0],z))
            normals/=np.linalg.norm(normals,axis=1,keepdims=True)
            normals=normals[:,[0,2,1]];normals[:,1]*=-1
            data.normals_split_custom_set([normals[loop.vertex_index] for loop in data.loops])
        obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj)
        pieces.append(obj);groups[obj.name]=group;data.calc_loop_triangles()
        statistics.append({'group':group,'detail':name,'after':len(data.loop_triangles)})
    def ribbon(name,path,width,role,mapper,group='body',offset=.001):
        vertices=[];faces=[]
        for i,p in enumerate(path):
            tangent=path[(i+1)%len(path)]-path[(i-1)%len(path)]
            normal=np.array([-tangent[1],tangent[0]]);normal/=max(np.linalg.norm(normal),1e-9)
            for sign in [-1,1]:vertices.append(mapper(p+normal*width*.5*sign,offset))
            a=2*i;b=2*((i+1)%len(path));faces.extend([(a,b,b+1),(a,b+1,a+1)])
        # Flat ribbons have no extruded side walls or doubled coplanar faces.
        add_surface(name,vertices,faces,role,group)
    for sign in [-1,1]:
        # The source shoulder changes faster vertically than longitudinally.
        # Allocate rows across that profile instead of oversampling its length.
        plane,triangles=lattice(door_outline,(.020,.180) if simple else (.015,.100))
        skin=[[sign*side_surface(y,z,sign),y,z] for y,z in plane]
        add_surface('ContinuousDoorSkin'+str(sign),skin,triangles,'paint','body')
    points=[];triangles=[]
    for obj in pieces:
        if obj.name.split('.')[0] in ['body_3650','body_6287','body_3678','body_6315']:continue
        obj.data.calc_loop_triangles();offset=len(points)
        points.extend([(v.co.x,v.co.z,-v.co.y) for v in obj.data.vertices])
        for face in obj.data.loop_triangles:
            if obj.data.materials[face.material_index].name=='BMT_paint':triangles.append([int(i)+offset for i in face.vertices])
    paint_bvh=BVHTree.FromPolygons(points,triangles,all_triangles=True)
    def on_skin(p,offset,sign):
        hit=paint_bvh.ray_cast((sign*2,float(p[0]),float(p[1])),(-sign,0,0),2)[0]
        x=abs(hit.x) if hit is not None else side_surface(p[0],p[1],sign)
        return np.array([sign*(x+offset),p[0],p[1]])
    for sign in [-1,1]:
        mapper=lambda p,offset,s=sign:on_skin(p,offset,s)
        ribbon('FlushDoorJoin'+str(sign),door_outline,.010,'paint',mapper,offset=.0004)
        ribbon('DoorContour'+str(sign),door_outline,.0028,'contour',mapper,offset=.0018)
        t=np.linspace(0,2*math.pi,40,endpoint=False)
        handle=np.c_[.905+.014*np.sin(t),.390+.066*np.cos(t)]
        ribbon('HandleContour'+str(sign),handle,.0025,'contour',mapper,offset=.0018)
    fuel=np.c_[CAP_Y+.059*np.sin(t),CAP_Z+.059*np.cos(t)]
    ribbon('FuelContour',fuel,.0025,'contour',lambda p,o:on_skin(p,o,-1),offset=.0018)
    # Retopologise the original surface with constraints along its actual outer
    # boundary, vent holes and raised shoulder curves. Every new vertex is
    # sampled from the original dense paint, including its concave cowl edge.
    edges=np.sort(np.concatenate([top_faces[:,[0,1]],top_faces[:,[1,2]],top_faces[:,[2,0]]]),axis=1)
    unique,counts=np.unique(edges,axis=0,return_counts=True);boundary_edges=unique[counts==1]
    used=np.unique(boundary_edges);lookup={int(v):i for i,v in enumerate(used)}
    xy=fitted_body[used][:,[0,2]].tolist()
    constraints=[(lookup[int(a)],lookup[int(b)]) for a,b in boundary_edges]
    spacing=.049 if simple else .030
    for x in np.arange(hood_panel.x[0],hood_panel.x[-1]+spacing,spacing):
        for z in np.arange(hood_panel.z[0],hood_panel.z[-1]+spacing,spacing):
            hit=hood_bvh.ray_cast((float(x),2,float(z)),(0,-1,0),3)[0]
            if hit is not None:xy.append([x,z])
    # The rolled outer cowl changes height within a centimetre. Sample this
    # short boundary more closely without spending detail on flat bonnet areas.
    for sign in [-1,1]:
        for x in np.arange(.55,.76,.012):
            for z in np.arange(-.94,-.75,.012):
                if hood_bvh.ray_cast((float(sign*x),2,float(z)),(0,-1,0),3)[0] is not None:xy.append([float(sign*x),float(z)])
    zs=np.arange(-1.94,-.96,.025);xs=np.linspace(.18,.46,113)
    shoulder=[]
    for z in zs:
        heights=hood_panel.height(xs,np.full(len(xs),z))
        shoulder.append(xs[np.argmin(np.gradient(heights,xs))])
    shoulder=np.convolve(np.pad(shoulder,2,mode='edge'),np.ones(5)/5,mode='valid')
    for sign in [-1,1]:
        for offset in [-.025,-.0125,0,.0125,.025]:
            previous=None
            for x,z in zip(shoulder+offset,zs):
                point=[float(sign*x+body_centre_x),float(z)]
                if hood_bvh.ray_cast((point[0],2,point[1]),(0,-1,0),3)[0] is None:previous=None;continue
                index=len(xy);xy.append(point)
                if previous is not None:constraints.append((previous,index))
                previous=index
    hood_vertices,hood_triangles=source_hood_mesh(xy,constraints,used)
    if simple:
        errors=[]
        for face in hood_triangles:
            centre=hood_vertices[list(face)].mean(0)
            hit=hood_bvh.ray_cast((float(centre[0]),2,float(centre[2])),(0,-1,0),3)[0]
            if hit is not None and abs(hit.y-centre[1])>.0015:errors.append((abs(hit.y-centre[1]),[float(centre[0]),float(centre[2])]))
        additions=[p for _,p in sorted(errors,reverse=True)[:200]]
        if additions:hood_vertices,hood_triangles=source_hood_mesh(xy+additions,constraints,used)
        print('HOOD_CURVATURE_REFINEMENT',len(additions),flush=True)
    add_surface('FactoryHoodRetopology',hood_vertices,hood_triangles,'paint','hood')
    build_fender_charts(add_surface,simple)
    exterior_detail.details(add_surface,simple,rear_surface)
    # Source wheels are measured above for fitting. The runtime builds exact
    # round tyres and five-spoke rims, avoiding fragile subpixel source details.
    # A low-cost glazing backing closes small gaps in the source's window/pillar
    # junctions. It contains no seats, dashboard, steering, cabin floor or rig.
    glass_faces=tri[np.array([mesh.materials[int(i)].name=='Basic Glass' for i in mi])]
    window_points=fitted_body[np.unique(glass_faces)]
    window_points=window_points.mean(0)+(window_points-window_points.mean(0))*.93
    bm=bmesh.new()
    for point in blender(window_points):bm.verts.new(point)
    bm.verts.ensure_lookup_table()
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    data=bpy.data.meshes.new('OpaqueGlazingBacking');bm.to_mesh(data);bm.free();data.materials.append(materials['glass'])
    obj=bpy.data.objects.new('OpaqueGlazingBacking',data);bpy.context.scene.collection.objects.link(obj)
    after=reduce(obj,160 if simple else 320);pieces.append(obj);groups[obj.name]='window_seal'
    statistics.append({'group':'window_seal','after':after,'purpose':'opaque glazing backing; no interior contents'})
    # Group per articulation and material. No skinning, constraints or rig ships.
    buckets={}
    for obj in pieces:
        for polygon in obj.data.polygons:
            role=obj.data.materials[polygon.material_index].name.removeprefix('BMT_')
            if groups[obj.name]=='body' and role=='white':role='reverse'
            buckets.setdefault((groups[obj.name],role),[]).append((obj,polygon.index))
    exports=[]
    for (group,role),polygons in buckets.items():
        vertices=[];faces=[];lookup={};normals=[]
        for obj,index in polygons:
            polygon=obj.data.polygons[index];face=[]
            for loop,vi in zip(polygon.loop_indices,polygon.vertices):
                identity=(obj.name,vi)
                if identity not in lookup:lookup[identity]=len(vertices);vertices.append(tuple(obj.data.vertices[vi].co))
                face.append(lookup[identity])
                normals.append(tuple(obj.data.corner_normals[loop].vector))
            faces.append(face)
        if group=='body' and role in ['paint','contour','amber']:
            if '--debug-cache' in args:
                np.savez_compressed(output/(tier+'_'+role+'_unfaired.npz'),vertices=np.asarray(vertices),loops=np.array([v for f in faces for v in f]),counts=np.array([len(f) for f in faces]),normals=np.asarray(normals))
            points=np.asarray(vertices)[:,[0,2,1]]*np.array([1,1,-1])
            source_z,stretch=unwarp_z(points[:,2],points[:,0]);points[:,2]=source_z
            loop_vertices=np.array([v for face in faces for v in face])
            loop_normals=np.asarray(normals)[:,[0,2,1]]*np.array([1,1,-1])
            _,stretch,shear=nose_distance(-points[:,2],points[:,0])
            loop_normals[:,0]+=shear[loop_vertices]*loop_normals[:,2]
            loop_normals[:,2]*=stretch[loop_vertices]
            loop_normals/=np.maximum(np.linalg.norm(loop_normals,axis=1,keepdims=True),1e-12)
            if role=='paint':
                counts=np.array([len(f) for f in faces])
                points,loop_vertices,counts,loop_normals=join_fairing.remesh_corners(points,loop_vertices,counts,loop_normals,simple)
                faces=np.arange(len(points)).reshape(-1,3).tolist()
            vertex_normals=np.zeros_like(points);np.add.at(vertex_normals,loop_vertices,loop_normals)
            vertex_normals/=np.maximum(np.linalg.norm(vertex_normals,axis=1,keepdims=True),1e-12)
            if role=='contour':points-=vertex_normals*.0018
            faired,faired_vertex_normals=join_fairing.apply(points,vertex_normals)
            if role=='contour':faired+=faired_vertex_normals*.0018
            _,faired_normals=join_fairing.apply(points[loop_vertices],loop_normals)
            if '--debug-cache' in args:
                np.savez_compressed(output/(tier+'_'+role+'_reference_input.npz'),points=faired,faces=np.asarray(faces),normals=faired_normals)
            if role=='paint':
                faired,reference_faces,faired_normals=reference_body.mesh(faired,faces,faired_normals)
                faired,reference_faces,faired_normals,strip_stats=shell_geometry.shoulder_strip(reference_body,faired,reference_faces,faired_normals,simple)
                faces=reference_faces.tolist()
                loop_vertices=np.arange(len(faired))
            elif role=='contour':
                faired-=faired_vertex_normals*.0018
                faired,reference_normals=reference_body.apply(faired,faired_vertex_normals,contour=True)
                faired_normals=reference_normals[loop_vertices]
            else:
                # Attached markers keep their original longitudinal size;
                # move their centres with the shell and refit each corner.
                for sign in [-1,1]:
                    ids=np.flatnonzero(faired[:,0]*sign>0)
                    if not len(ids):continue
                    centre_z=float(np.mean(faired[ids,2]));centre_x=float(np.mean(faired[ids,0]))
                    world_z=-nose_distance(-centre_z,centre_x)[0]+faired[ids,2]-centre_z
                    faired[ids,2]=unwarp_z(world_z,faired[ids,0])[0]
                    for i in ids:
                        hit=reference_body.outer.ray_cast((float(sign*2),float(faired[i,1]),float(faired[i,2])),(-sign,0,0),2)[0]
                        if hit is not None:faired[i,0]=hit.x
                faired,reference_normals=reference_body.apply(faired,faired_vertex_normals)
                faired+=reference_normals*.003
                faired_normals=reference_normals[loop_vertices]
            vertices=blender(nose(faired)).tolist()
            faired_normals=nose_normals(faired[loop_vertices],faired_normals)
            faired_normals/=np.maximum(np.linalg.norm(faired_normals,axis=1,keepdims=True),1e-12)
            normals=(faired_normals[:,[0,2,1]]*np.array([1,-1,1])).tolist()
        # One final plan deformation for all joined exterior layers. Keeping it
        # after the side/bonnet fitting prevents the old side-only width blend
        # from leaving a projecting cap or trim at the front corners.
        if not group.startswith('wheel_'):
            world_points=np.asarray(vertices)[:,[0,2,1]]*np.array([1,1,-1])
            world_normals=np.asarray(normals)[:,[0,2,1]]*np.array([1,1,-1])
            loop_ids=np.array([v for face in faces for v in face])
            world_normals=nose_plan_normals(world_points[loop_ids],world_normals)
            world_points=nose_plan_points(world_points)
            world_normals=nose_corner_normals(world_points[loop_ids],world_normals)
            vertices=blender(nose_corner_field(world_points)[0]).tolist()
            normals=(world_normals[:,[0,2,1]]*np.array([1,-1,1])).tolist()
        data=bpy.data.meshes.new(group+'__'+role);data.from_pydata(vertices,[],faces);data.materials.append(materials[role]);data.update()
        for polygon in data.polygons:polygon.use_smooth=True
        data.set_sharp_from_angle(angle=math.radians(52))
        data.normals_split_custom_set(normals)
        obj=bpy.data.objects.new(group+'__'+role,data);bpy.context.scene.collection.objects.link(obj);exports.append(obj)
        if group=='body' and role=='paint':
            shell_stats=shell_geometry.refine(obj,simple)
            print('JOINED_SHELL',tier,shell_stats,flush=True)
    clean_panels.rebuild_hood(exports,clean_hood,lattice,simple)
    clean_stats=clean_panels.finish(exports,simple,clean_hood)
    restored,contour_hood=manufactured_exterior.restore(exports,fitted_body,tri,mi,component,paint_index,simple,rear_surface,hood_panel)
    clean_stats={'factory_shape_restored':True,'manufactured_exterior':restored}
    if not simple:
        factory_hood_outline=contour_hood.boundary().copy()
        (output/'bonnet_contour.json').write_text(json.dumps({'baked':True,'method':'retained factory bonnet boundary','physical_width_metres':.0025,'points':factory_hood_outline.tolist()},indent=2),encoding='utf-8')
    else:contour_hood.outline=factory_hood_outline
    manufactured_exterior.supported_contours(exports,door_outline,contour_hood)
    fitted_contours=len(next(obj for obj in exports if obj.name=='body__contour').data.vertices)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.hide_set(True);obj.hide_render=True
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(output/(tier+'.glb')),export_format='GLB',use_selection=True,
        export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,
        export_materials='EXPORT',export_extras=False)
    total=0
    for obj in exports:
        obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
    statistics.append({'detail':'continuous corner seam replacement','after':total-sum(row.get('after',0) for row in statistics)})
    record['tiers'][tier]={'triangles':total,'surfaces':len(exports),'parts':statistics}
    record['tiers'][tier]['clean_panels']=clean_stats
    record['tiers'][tier]['joined_shell']=shell_stats
    record['tiers'][tier]['shoulder_strips']=strip_stats
    record['tiers'][tier]['fitted_contour_vertices']=fitted_contours
    print('CHALLENGER_EXPORT',tier,total,len(exports),flush=True)
    for obj in exports:obj.hide_set(True);obj.hide_render=True;obj.name='ARCHIVE_'+tier+'_'+obj.name
for o in original_wheels.values():o.data.calc_loop_triangles()
record['source_triangles']=source_facts['source_triangles'] if cached_source else len(tri)+sum(len(o.data.loop_triangles) for o in original_wheels.values())
if cached_source:record['conversion_input']={'kind':'retained measured body geometry','cache_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'facts_sha256':hashlib.sha256(source.with_name('source-facts.json').read_bytes()).hexdigest(),'original_download_unavailable':True}
record['wheel_geometry']='Native round tyres and five-spoke/custom rims; source wheel centres retained as alignment reference.'
record['opaque_glazing']='Single smooth opaque exterior panes, 2% pane overlap and an opaque low-poly backing inset clear of the panes. No cabin contents or rig.'
record['refinement']={'factory_shape_restored':True,'nose_extension_metres':.14,'nose_stretch_starts_z':-1.72,
    'flush_contour_offset_metres':.0018,'flush_contour_width_metres':.0025,
    'side_surface':'original dense factory exterior reduced with retained boundary vertices and original surface normals',
    'fitted_hood_height_reference':hood_panel.stats,'hood':'original factory bonnet and power bulge; native marking fitted to its measured upper boundary',
    'panel_joins':'source paint seams welded within 1.5 mm before reduction; physical panel boundaries protected',
    'contours':'explicit producer-authored ribbon pairs, baked offline into native pixel-coverage attributes',
    'glazing':'single exterior pane skins; one measured tangent field per pane','glazing_backing_inset_scale':.93,
    'exterior_details':'four projectors, recessed honeycomb grille, factory-seated rear applique and light guides, rolled exhaust tips',
    'nose_transform':'existing shared extension, plan taper and outer-lip downturn retained; broad replacement body fields removed'}
(output/'manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('CHALLENGER_PREPARED',output,flush=True)
