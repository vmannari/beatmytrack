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

args = sys.argv[sys.argv.index("--")+1:]
source, labels_file, output = map(Path,args[:3])
output.mkdir(parents=True,exist_ok=True)
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
wheel_centres={name:np.mean([np.array(o.matrix_world@Vector(c)) for c in o.bound_box],axis=0) for name,o in original_wheels.items()}
front_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Ft.' in n]))
rear_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Bk.' in n]))
centre_x=float(np.mean([c[0] for c in wheel_centres.values()]));wheel_z=float(np.mean([c[2] for c in wheel_centres.values()]))
scale=np.array([1.50,2.56/(rear_y-front_y),0.37/0.26099])

def game(points):
    return np.c_[-(points[:,0]-centre_x)*scale[0],(points[:,2]-wheel_z)*scale[2]+0.37,(points[:,1]-front_y)*scale[1]-1.28]

def blender(points): return np.c_[points[:,0],-points[:,2],points[:,1]]
fitted_body=game(body_world)

def smooth(a,b,value):
    t=np.clip((value-a)/(b-a),0,1)
    return t*t*(3-2*t)

def nose(points):
    result=np.array(points,copy=True)
    result[:,2]-=.14*smooth(1.72,2.1171,-result[:,2])
    return result

# Fit the continuous side skin to dense, unmodified exterior samples. Robust
# rejection keeps the original handle recesses and door gaps out of the fit.
side_faces=tri[np.isin(component,[1464,1491,1862,4445])]
side_bvh=BVHTree.FromPolygons(fitted_body.tolist(),side_faces.tolist(),all_triangles=True)
def terms(y,z,degree_y=6,degree_z=2):
    y=(np.asarray(y)-.65)/.35;z=np.asarray(z)/.85
    return np.stack([y**i*z**j for i in range(degree_y+1) for j in range(degree_z+1)],axis=-1)
side_samples=[]
for y in np.linspace(.295,1.01,72):
    for z in np.linspace(-.80,.70,76):
        if .86<y<.95 and .25<z<.50:continue
        for sign in [-1,1]:
            hit=side_bvh.ray_cast((sign*2,float(y),float(z)),(-sign,0,0),2)[0]
            if hit is not None and .65<abs(hit.x)<1.01:side_samples.append([y,z,abs(hit.x)])
samples=np.array(side_samples);design=terms(samples[:,0],samples[:,1]);keep=np.ones(len(samples),dtype=bool)
for iteration in range(5):
    side_coeff=np.linalg.lstsq(design[keep],samples[keep,2],rcond=None)[0]
    keep=abs(design@side_coeff-samples[:,2])<.012
def side_x(y,z):return terms(y,z)@side_coeff

# The fuel door is part of the source's large body component. Remove its
# embossing with a local smooth fit; its visible detail becomes a flat contour.
CAP_Y,CAP_Z=.99,1.31
CAP_RY,CAP_RZ=.095,.125
cap_samples=[]
for y in np.linspace(.79,1.15,48):
    for z in np.linspace(1.08,1.56,64):
        if ((y-CAP_Y)/CAP_RY)**2+((z-CAP_Z)/CAP_RZ)**2<.83**2:continue
        hit=side_bvh.ray_cast((-2,float(y),float(z)),(1,0,0),2)[0]
        if hit is not None and abs(hit.x)>.7:cap_samples.append([y,z,-hit.x])
cap_samples=np.array(cap_samples)
def cap_terms(y,z):
    y=(np.asarray(y)-CAP_Y)/.18;z=(np.asarray(z)-CAP_Z)/.24
    return np.stack([y**i*z**j for i in range(4) for j in range(3)],axis=-1)
cap_coeff=np.linalg.lstsq(cap_terms(cap_samples[:,0],cap_samples[:,1]),cap_samples[:,2],rcond=None)[0]
def cap_x(y,z):return cap_terms(y,z)@cap_coeff

clean_body=fitted_body.copy()
source_nx=np.empty(len(mesh.vertices),dtype=np.float32)
source_normals=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('normal',source_normals)
source_nx=-source_normals.reshape(-1,3)[:,0]
outward=source_nx*np.sign(clean_body[:,0])>.2
side_region=outward&(abs(clean_body[:,0])>.65)&(clean_body[:,1]>.292)&(clean_body[:,1]<1.005)&(clean_body[:,2]>-.80)&(clean_body[:,2]<.68)
def side_weight(y,z):return smooth(.292,.34,y)*(1-smooth(.965,1.005,y))*smooth(-.80,-.73,z)*(1-smooth(.60,.68,z))
weight=side_weight(clean_body[side_region,1],clean_body[side_region,2])
clean_body[side_region,0]=clean_body[side_region,0]*(1-weight)+np.sign(clean_body[side_region,0])*side_x(clean_body[side_region,1],clean_body[side_region,2])*weight
cap_radius=np.sqrt(((clean_body[:,1]-CAP_Y)/CAP_RY)**2+((clean_body[:,2]-CAP_Z)/CAP_RZ)**2)
cap_region=(clean_body[:,0]<-.70)&(cap_radius<1.25)
cap_weight=1-smooth(.95,1.25,cap_radius[cap_region])
clean_body[cap_region,0]=clean_body[cap_region,0]*(1-cap_weight)-cap_x(clean_body[cap_region,1],clean_body[cap_region,2])*cap_weight

def side_surface(y,z,sign):
    hit=side_bvh.ray_cast((sign*2,float(y),float(z)),(-sign,0,0),2)[0]
    fit=side_x(y,z);weight=side_weight(y,z)
    actual=abs(hit.x) if hit is not None else fit
    return actual*(1-weight)+fit*weight

def hood_y(x,z):
    t=np.clip((np.asarray(z)+1.95)/1.20,0,1)
    edge=.83+.135*(1-np.exp(-3*t**1.3))
    rise=(.10-.05*t)*smooth(0,.24,t)*np.exp(-(np.asarray(x)/.34)**4)
    return edge+rise+.011*(1-(np.asarray(x)/.752)**2)

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

# Recover the actual outer top boundary, retaining the hood's concave cowl edge.
# Vent holes are deliberately filled by the new constrained regular lattice.
hood_faces=tri[component==1572];hp=fitted_body[hood_faces]
hn=np.cross(hp[:,1]-hp[:,0],hp[:,2]-hp[:,0]);hn/=np.maximum(np.linalg.norm(hn,axis=1)[:,None],1e-12)
top_faces=hood_faces[hn[:,1]>.3]
hood_bvh=BVHTree.FromPolygons(fitted_body.tolist(),top_faces.tolist(),all_triangles=True)
# Measure the outer footprint by ray intersection. The supplied hood contains
# overlapping/branched edges, so topological boundary loops are not reliable.
hood_points=fitted_body[np.unique(hood_faces)]
low,high=hood_points.min(0),hood_points.max(0)
front=[];rear=[]
for x in np.linspace(low[0]+.001,high[0]-.001,73):
    hits=[]
    for z in np.linspace(low[2],high[2],600):
        hit=hood_bvh.ray_cast((float(x),2,float(z)),(0,-1,0),3)[0]
        if hit is not None:hits.append(np.array(hit))
    if hits:front.append(hits[0]);rear.append(hits[-1])
hood_boundary_3d=np.array(front+rear[::-1])
def signed_area(poly):return np.sum(poly[:,0]*np.roll(poly[:,1],-1)-poly[:,1]*np.roll(poly[:,0],-1))*.5
hood_boundary=simplify_closed(hood_boundary_3d[:,[0,2]],.0007)
if signed_area(hood_boundary)<0:hood_boundary=hood_boundary[::-1]
print('HOOD_BOUNDARY',len(hood_boundary),float(signed_area(hood_boundary)),flush=True)
assert 1.0<abs(signed_area(hood_boundary))<2.5, 'Hood boundary must be the actual full outer skin'

def nearest_boundary(points,boundary):
    a=boundary;b=np.roll(boundary,-1,axis=0);delta=b-a
    rel=points[:,None,:]-a[None,:,:]
    t=np.clip(np.sum(rel*delta,axis=2)/np.maximum(np.sum(delta*delta,axis=1),1e-18),0,1)
    nearest=a[None,:,:]+t[:,:,None]*delta[None,:,:]
    distance=np.linalg.norm(points[:,None,:]-nearest,axis=2);index=distance.argmin(1)
    return distance[np.arange(len(points)),index],index,t[np.arange(len(points)),index]
def lattice(boundary,spacing):
    low,high=boundary.min(0),boundary.max(0);points=[]
    for y in np.arange(low[0]+spacing*.5,high[0],spacing):
        for z in np.arange(low[1]+spacing*.5,high[1],spacing):
            inside=False
            for a,b in zip(boundary,np.roll(boundary,-1,axis=0)):
                if (a[1]>z)!=(b[1]>z) and y<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:inside=not inside
            if inside:points.append([y,z])
    points=np.concatenate([boundary,np.array(points)])
    vertices,_,faces,*_=delaunay_2d_cdt([Vector(p) for p in points],[],[list(range(len(boundary)))],1,1e-6,False)
    return np.array(vertices),faces

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

all_source=list(bpy.data.objects)
for obj in all_source: obj.hide_render=True;obj.hide_set(True)

record={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'source_triangles':len(tri)+sum(len(o.data.polygons)*2 for o in original_wheels.values()),
        'body_source_triangles':len(tri),'source':str(source),'source_wheel_centres':{k:v.tolist() for k,v in wheel_centres.items()},
        'body_scale_xyz':scale.tolist(),'tiers':{},'removed_components':[],'native_materials_only':True}

def new_piece(name, points, faces, mat_indices, mat_names):
    used,faces=np.unique(np.asarray(faces).ravel(),return_inverse=True)
    data=bpy.data.meshes.new(name);data.from_pydata(blender(points[used]).tolist(),[],faces.reshape(-1,3).tolist());data.update()
    for n in mat_names:data.materials.append(materials[ROLE.get(n,'dark')])
    data.polygons.foreach_set('material_index',np.asarray(mat_indices,dtype=np.int32))
    for p in data.polygons:p.use_smooth=True
    obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj)
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
        if glass or roof:
            mod.decimate_type='DISSOLVE';mod.angle_limit=math.radians(2.0);mod.use_dissolve_boundaries=False
        else:
            mod.ratio=target/float(before);mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.set_sharp_from_angle(angle=math.radians(52))
    if reference is not None:
        transfer=obj.modifiers.new('Retain dense surface normals','DATA_TRANSFER');transfer.object=reference
        transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'};transfer.loop_mapping='POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        bpy.data.objects.remove(reference,do_unlink=True)
    # All central panels share the same fitted tangent field, including joins.
    # Normal transfer must not reintroduce the original separate-door shading.
    if obj.name.startswith('body_'):
        values=[]
        for polygon in obj.data.polygons:
            role=obj.data.materials[polygon.material_index].name
            for loop in polygon.loop_indices:
                n=obj.data.corner_normals[loop].vector
                point=obj.data.vertices[obj.data.loops[loop].vertex_index].co
                x,y,z=point.x,point.z,-point.y
                field=None
                if role=='BMT_paint' and abs(x)>.65 and .292<y<1.005 and -.80<z<.68:field=side_x
                elif role=='BMT_paint' and x<-.70 and ((y-CAP_Y)/CAP_RY)**2+((z-CAP_Z)/CAP_RZ)**2<1.25**2:field=cap_x
                if field is not None:
                    e=.0002;dy=(field(y+e,z)-field(y-e,z))/(2*e);dz=(field(y,z+e)-field(y,z-e))/(2*e)
                    g=np.array([np.sign(x),-dy,-dz]);g/=np.linalg.norm(g)
                    weight=side_weight(y,z) if field==side_x else 1-smooth(.95,1.25,math.sqrt(((y-CAP_Y)/CAP_RY)**2+((z-CAP_Z)/CAP_RZ)**2))
                    n=np.array(n)*(1-weight)+np.array([g[0],-g[2],g[1]])*weight;n/=max(np.linalg.norm(n),1e-12)
                values.append(tuple(n))
        obj.data.normals_split_custom_set(values)
    obj.data.calc_loop_triangles();obj.select_set(False)
    return len(obj.data.loop_triangles)

def body_target(key, count, simple):
    explicit={1464:(7800,4600),1491:(3000,1800),1624:(1800,1100),2149:(2000,1200),
              1862:(700,420),4445:(700,420),2790:(900,450)}
    if key in explicit:return explicit[key][1 if simple else 0]
    return min(count,max(40 if simple else 72,int(count*(.018 if simple else .035))))

for simple in [False,True]:
    tier='simple' if simple else 'full';pieces=[];groups={};statistics=[]
    bpy.ops.object.select_all(action='DESELECT')
    for key in np.unique(component):
        mask=component==key;faces=tri[mask];indices=mi[mask];count=len(faces)
        names={mesh.materials[int(i)].name for i in np.unique(indices)}
        pts=co[np.unique(faces)];low,high=pts.min(0),pts.max(0)
        badge=any(n.startswith('SVGMat') for n in names) or int(key) in [415457,417915]
        badge=badge or (names=={'Black Metal'} and low[1]>1.28 and max(abs(low[0]),abs(high[0]))<.16)
        tiny=count<128
        interior=int(key) in [0,732]
        replaced=int(key) in [1572,321860,323444,323460,1862,4445,3632,6269,6720,430273]
        if badge or tiny or interior or replaced:
            if not simple:record['removed_components'].append({'component':int(key),'triangles':count,'reason':'cabin floor' if interior else 'smooth hood / flush detail replacement' if replaced else 'badge geometry' if badge else 'micro grille/hidden detail'})
            continue
        if int(key)==1464:
            centre=fitted_body[faces].mean(1)
            cap=(centre[:,0]<-.70)&(((centre[:,1]-CAP_Y)/CAP_RY)**2+((centre[:,2]-CAP_Z)/CAP_RZ)**2<1.25**2)
            p=clean_body[faces];normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
            # Flatten the original connected skin rather than laying another
            # disc over it. Folded/back-facing cap walls collapse and disappear.
            keep_faces=~cap|(normal[:,0]<-1e-12)
            faces=faces[keep_faces];indices=indices[keep_faces]
        if int(key)==1491:
            # The source combines black seam/liner fragments into the fender.
            # Heavy reduction turns these tiny fragments into visible spikes.
            visible=np.array([mesh.materials[int(i)].name!='Matter Black' for i in indices])
            faces=faces[visible];indices=indices[visible]
        group='hood' if int(key) in [1572,321860,323444,323460] else 'aero' if int(key)==297986 else 'body'
        if names=={'Red Light'}:group='tail_left' if (low[0]+high[0])*0.5>centre_x else 'tail_right'
        if names in [{'White Light'},{'Headlight Glow'}] and high[1]<0:group='head_left' if (low[0]+high[0])*0.5>centre_x else 'head_right'
        material_names=[m.name for m in mesh.materials]
        if int(key)==436063:
            group='head_right';material_names=['Headlight Glow' if m=='Gloss Black' else m for m in material_names]
        points=clean_body if int(key) in [1464,1862,4445,1491] else fitted_body
        if names=={'Basic Glass'}:
            # Seal tiny source panel gaps with an opaque pane overlap, tucked
            # behind the surrounding pillars. No cabin shell or interior ships.
            vertices=np.unique(faces);points=fitted_body.copy();window=points[vertices]
            centre=window.mean(0);delta=window-centre
            normal=np.linalg.svd(delta,full_matrices=False)[2][-1]
            if np.dot(normal,np.array([0,1.05,.25])-centre)<0:normal=-normal
            planar=delta-np.outer(delta@normal,normal)
            points[vertices]=window+planar*(.01 if int(key)==294203 else .02)+normal*.003
        obj=new_piece(group+'_'+str(key),nose(points),faces,indices,material_names)
        after=reduce(obj,body_target(int(key),count,simple));pieces.append(obj)
        groups[obj.name]=group;statistics.append({'component':int(key),'group':group,'before':count,'after':after})
    def add_surface(name,points,faces,role,group):
        points=np.asarray(points)
        clean=[]
        for face in faces:
            p=points[list(face)];normal=np.cross(p[1]-p[0],p[2]-p[0])
            hint=np.array([0,1,0]) if group=='hood' else np.array([np.sign(p[:,0].mean()),0,0])
            clean.append(tuple(reversed(face)) if normal@hint<0 else face)
        faces=clean
        data=bpy.data.meshes.new(name);data.from_pydata(blender(nose(np.asarray(points))),[],faces);data.materials.append(materials[role]);data.update()
        for polygon in data.polygons:polygon.use_smooth=True
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
        plane,triangles=lattice(door_outline,.055 if simple else .040)
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
        ribbon('FlushDoorJoin'+str(sign),door_outline,.020,'paint',mapper,offset=.0010)
        ribbon('DoorContour'+str(sign),door_outline,.0028,'contour',mapper,offset=.0018)
        t=np.linspace(0,2*math.pi,40,endpoint=False)
        handle=np.c_[.905+.014*np.sin(t),.390+.066*np.cos(t)]
        ribbon('HandleContour'+str(sign),handle,.0025,'contour',mapper,offset=.0018)
    fuel=np.c_[CAP_Y+.059*np.sin(t),CAP_Z+.059*np.cos(t)]
    ribbon('FuelContour',fuel,.0025,'contour',lambda p,o:on_skin(p,o,-1),offset=.0018)
    # The perimeter is measured, rather than guessed. Interior samples form a
    # clean lattice and fade smoothly into the exact source fender/cowl junction.
    plane,faces=lattice(hood_boundary,.040 if simple else .028)
    distance,index,amount=nearest_boundary(plane,hood_boundary_3d[:,[0,2]])
    vertices=[]
    for i,(x,z) in enumerate(plane):
        hit=hood_bvh.ray_cast((float(x),2,float(z)),(0,-1,0),3)[0]
        a=hood_boundary_3d[index[i]];b=hood_boundary_3d[(index[i]+1)%len(hood_boundary_3d)]
        original=hit.y if hit is not None else a[1]*(1-amount[i])+b[1]*amount[i]
        blend=smooth(0,.075,distance[i])
        vertices.append([x,original*(1-blend)+hood_y(x,z)*blend,z])
    add_surface('SmoothHood',vertices,faces,'paint','hood')
    hood_skin=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
    for x,z,rx,rz in [(0,-1.73,.165,.027),(-.535,-1.558,.088,.052),(.535,-1.558,.088,.052)]:
        angle=np.linspace(0,2*math.pi,48 if not simple else 32,endpoint=False)
        path=np.c_[x+rx*np.cos(angle),z+rz*np.sin(angle)]
        plane,faces=lattice(path,.012)
        vertices=[]
        for a,b in plane:
            hit=hood_skin.ray_cast((float(a),2,float(b)),(0,-1,0),3)[0]
            vertices.append([a,(hit.y if hit is not None else hood_y(a,b))+.0025,b])
        add_surface('FlushHoodVent'+str(x),vertices,faces,'dark','hood')
    # Source wheels are measured above for fitting. The runtime builds exact
    # round tyres and five-spoke rims, avoiding fragile subpixel source details.
    # A low-cost glazing backing closes small gaps in the source's window/pillar
    # junctions. It contains no seats, dashboard, steering, cabin floor or rig.
    glass_faces=tri[np.array([mesh.materials[int(i)].name=='Basic Glass' for i in mi])]
    window_points=fitted_body[np.unique(glass_faces)]
    window_points=window_points.mean(0)+(window_points-window_points.mean(0))*.985
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
        data=bpy.data.meshes.new(group+'__'+role);data.from_pydata(vertices,[],faces);data.materials.append(materials[role]);data.update()
        for polygon in data.polygons:polygon.use_smooth=True
        data.set_sharp_from_angle(angle=math.radians(52))
        data.normals_split_custom_set(normals)
        obj=bpy.data.objects.new(group+'__'+role,data);bpy.context.scene.collection.objects.link(obj);exports.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.hide_set(True);obj.hide_render=True
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(output/(tier+'.glb')),export_format='GLB',use_selection=True,
        export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,
        export_materials='EXPORT',export_extras=False)
    total=sum(row['after'] for row in statistics)
    record['tiers'][tier]={'triangles':total,'surfaces':len(exports),'parts':statistics}
    print('CHALLENGER_EXPORT',tier,total,len(exports),flush=True)
    for obj in exports:obj.hide_set(True);obj.hide_render=True;obj.name='ARCHIVE_'+tier+'_'+obj.name
for o in original_wheels.values():o.data.calc_loop_triangles()
record['source_triangles']=len(tri)+sum(len(o.data.loop_triangles) for o in original_wheels.values())
record['wheel_geometry']='Native round tyres and five-spoke/custom rims; source wheel centres retained as alignment reference.'
record['opaque_glazing']='Boundary-preserving dissolve, 2% pane overlap and an opaque low-poly glazing backing close source pillar gaps. No cabin contents or rig.'
record['refinement']={'nose_extension_metres':.14,'nose_stretch_starts_z':-1.72,'flush_contour_offset_metres':.0018,'flush_contour_width_metres':.0025,'side_fit_inliers':int(keep.sum()),'side_fit_samples':len(samples),'hood':'regular analytic lattice; flush vent markings','fuel_and_handles':'no protruding source detail meshes','glazing_backing_inset_scale':.985}
(output/'manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('CHALLENGER_PREPARED',output,flush=True)
