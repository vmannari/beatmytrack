"""Retain factory proportions and fair the owner-marked sides as one chart."""
import math
import numpy as np
import challenger_clean_panels as panel
class FactoryHood(panel.CleanHood):
    """Use the measured factory crown in the final-coordinate bonnet chart."""
    def __init__(self,source):
        super().__init__();self.source=source
        self.stats={'method':'measured factory bonnet crown with retained clean apertures'}

    def height(self,x,z):
        from challenger_reference_geometry import nose_plan_scale,nose_inverse,nose_corner_field,NOSE_PLAN_CENTRE
        x,z=np.broadcast_arrays(abs(x),z);zpre=np.array(z,copy=True)
        for _ in range(8):
            points=np.c_[x.ravel(),np.ones(x.size),zpre.ravel()]
            shifted=nose_corner_field(points)[0][:,2].reshape(z.shape)
            zpre=z-(shifted-zpre)
        scale,_=nose_plan_scale(zpre)
        original_x=NOSE_PLAN_CENTRE+(x-NOSE_PLAN_CENTRE)/scale
        original_z=nose_inverse(zpre,original_x)[0]
        y=self.source.height(original_x,original_z)
        return nose_corner_field(np.c_[x.ravel(),y.ravel(),zpre.ravel()])[0][:,1].reshape(x.shape)

    def normal(self,x,z):
        from challenger_reference_geometry import nose_plan_scale,nose_inverse,nose_corner_field,nose_corner_normals,nose_plan_points,nose_plan_normals,nose_normals,nose_distance,NOSE_PLAN_CENTRE
        x,z=np.broadcast_arrays(x,z);sign=np.where(x<0,-1,1);xp=abs(x);zpre=np.array(z,copy=True)
        for _ in range(8):
            points=np.c_[xp.ravel(),np.ones(x.size),zpre.ravel()]
            shifted=nose_corner_field(points)[0][:,2].reshape(z.shape)
            zpre=z-(shifted-zpre)
        scale,_=nose_plan_scale(zpre)
        ox=NOSE_PLAN_CENTRE+(xp-NOSE_PLAN_CENTRE)/scale;oz=nose_inverse(zpre,ox)[0]
        p=np.c_[ox.ravel(),self.source.height(ox,oz).ravel(),oz.ravel()]
        n=self.source.normal(ox,oz).reshape(-1,3);n=nose_normals(p,n)
        p[:,2]=-nose_distance(-p[:,2],p[:,0])[0]
        n=nose_plan_normals(p,n);p=nose_plan_points(p);n=nose_corner_normals(p,n)
        n[:,0]*=sign.ravel();return n.reshape(x.shape+(3,))


def finish_hood_symmetry(exports):
    """Remove duplicate centre returns and slivers below native precision."""
    for obj in exports:
        if not obj.name.startswith('hood__'):continue
        values=records(obj)
        axis=abs(values[:,:,0])<.000030
        values[:,:,0][axis]=0;values[:,:,3][axis]=0
        positive=panel._positive(values);kept=[];seen=set()
        for face in positive:
            if np.max(abs(face[:,0]))<1e-9:
                key=tuple(sorted(tuple(p) for p in np.round(face[:,:3],7)))
                if key in seen:continue
                seen.add(key)
            kept.append(face)
        kept=np.asarray(kept);reflected=kept[:,::-1,:].copy()
        reflected[:,:,0]*=-1;reflected[:,:,3]*=-1
        panel._write(obj,np.concatenate([kept,reflected]))


def normalise(n):
    return n/np.maximum(np.linalg.norm(n,axis=-1,keepdims=True),1e-12)


def records(obj):
    p,f,n=panel._read(obj)
    return np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)


def seat_rear(exports,surface):
    """Use the measured factory tail plane rather than moving the body to trim."""
    for obj in exports:
        group,role=obj.name.split('__')
        offsets={'dark':.002,'accent':.004,'lens_red':.006,'reverse':.011,'red':.010}
        if group=='body' and role in offsets:offset=offsets[role]
        elif group.startswith('tail_'):offset=.012
        else:continue
        v=records(obj).reshape(-1,6)
        sel=(v[:,2]>1.9)&(v[:,1]>.750)&(v[:,1]<.960)&(abs(v[:,0])<.84)
        for p in v[sel]:
            x,y=p[:2];e=.0001
            p[2]=surface(x,y)+offset
            p[3:]=normalise(np.array([-(surface(x+e,y)-surface(x-e,y))/(2*e),-(surface(x,y+e)-surface(x,y-e))/(2*e),1]))
        # Boolean advanced indexing returns a copy; write the edited rows back.
        ids=np.flatnonzero(sel)
        for i in ids:
            x,y=v[i,:2];e=.0001
            v[i,2]=surface(x,y)+offset
            v[i,3:]=normalise(np.array([-(surface(x+e,y)-surface(x-e,y))/(2*e),-(surface(x,y+e)-surface(x,y-e))/(2*e),1]))
        panel._write(obj,v.reshape(-1,3,6))

def reduced_source(obj,points,faces,target):
    import bpy
    used,inverse=np.unique(np.asarray(faces),return_inverse=True)
    p=panel.world(np.asarray(points)[used]);f=inverse.reshape(-1,3);source_count=len(f)
    mesh=bpy.data.meshes.new(obj.name+'Factory')
    mesh.from_pydata((p[:,[0,2,1]]*np.array([1,-1,1])).tolist(),[],f.tolist())
    for material in obj.data.materials:mesh.materials.append(material)
    mesh.update();obj.data=mesh
    for face in mesh.polygons:face.use_smooth=True
    mesh.set_sharp_from_angle(angle=math.radians(48))
    normals=[tuple(n.vector) for n in mesh.corner_normals]
    mesh.normals_split_custom_set(normals)
    source=obj.copy();source.data=mesh.copy();bpy.context.scene.collection.objects.link(source)
    source.hide_render=True;source.hide_set(True)
    original_edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
    original_unique,original_counts=np.unique(original_edges,axis=0,return_counts=True)
    original_boundary=np.unique(original_unique[original_counts==1])
    original_boundary_points=[mesh.vertices[int(i)].co.copy() for i in original_boundary]
    if obj.name=='body__paint':
        import bmesh
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0015)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bm.to_mesh(mesh);bm.free();mesh.update()
        f=np.asarray([face.vertices[:] for face in mesh.polygons],dtype=int)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Original exterior reduction','DECIMATE')
    modifier.ratio=min(1,target/max(len(mesh.polygons),1));modifier.use_collapse_triangulate=True
    edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
    unique,counts=np.unique(edges,axis=0,return_counts=True);protected=np.unique(unique[counts==1]).tolist()
    # A welded join becomes an interior edge. Keep its original factory
    # stations protected too, rather than considering only remaining borders.
    from mathutils.kdtree import KDTree
    lookup=KDTree(len(mesh.vertices))
    for vertex in mesh.vertices:lookup.insert(vertex.co,vertex.index)
    lookup.balance()
    for point in original_boundary_points:
        _,index,distance=lookup.find(point)
        assert distance<.0016,'Factory boundary welding must stay within 1.5 mm'
        protected.append(index)
    protected=sorted(set(protected));protected_points=[tuple(mesh.vertices[i].co) for i in protected]
    if protected:
        group=obj.vertex_groups.new(name='KeepFactoryPanelBoundaries')
        group.add(list(range(len(mesh.vertices))),1.0,'REPLACE');group.add(protected,0.0,'REPLACE')
        modifier.vertex_group=group.name;modifier.vertex_group_factor=1000
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    remaining={tuple(vertex.co) for vertex in obj.data.vertices}
    assert all(point in remaining for point in protected_points),'Original factory panel-edge stations must survive reduction'
    transfer=obj.modifiers.new('Retain original exterior shading','DATA_TRANSFER')
    transfer.object=source;transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'}
    transfer.loop_mapping='POLYINTERP_NEAREST'
    bpy.ops.object.datalayout_transfer(modifier=transfer.name);bpy.ops.object.modifier_apply(modifier=transfer.name)
    # Near the factory's thin returned seams, nearest-face transfer can take
    # a normal from the opposite skin. Keep the retained source shading in
    # the actual triangle's outward hemisphere without moving any vertices.
    obj.data.update();corrected=[];normal_fixes=0
    for face in obj.data.polygons:
        for loop in face.loop_indices:
            normal=obj.data.corner_normals[loop].vector.copy()
            if normal.dot(face.normal)<0:normal=-normal;normal_fixes+=1
            corrected.append(tuple(normal))
    obj.data.normals_split_custom_set(corrected)
    from mathutils.bvhtree import BVHTree
    reference=BVHTree.FromObject(source,bpy.context.evaluated_depsgraph_get())
    errors=np.array([reference.find_nearest(vertex.co)[3] for vertex in obj.data.vertices])
    fidelity={'maximum_error_mm':float(errors.max())*1000,'p95_error_mm':float(np.percentile(errors,95))*1000,'mean_error_mm':float(errors.mean())*1000}
    bpy.data.objects.remove(source,do_unlink=True)
    panel.mirror_object(obj)
    return {'source_triangles':source_count,'target_triangles':target,'result_triangles':len(obj.data.polygons),
            'method':'original dense vertices and outward source normals; no replacement body field','source_fidelity':fidelity,'protected_boundary_vertices':len(protected),'normal_orientation_repairs':normal_fixes}


class NativeHoodGuide:
    def __init__(self,obj,fallback,outline=None):
        from mathutils.bvhtree import BVHTree
        p,f,_=panel._read(obj);self.skin=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
        self.fallback=fallback
        self.outline=self.outer_loop(p,f) if outline is None else np.asarray(outline)

    @staticmethod
    def outer_loop(p,f):
        # Survey the complete projected factory footprint. Following a mesh
        # boundary instead can turn into the thin returned cowl edge, where
        # the source contains coincident normal splits and small open seams.
        # This bonnet is monotone across X; vent holes stay inside its outer
        # front/rear envelope and cannot become an outer marking.
        edges=np.concatenate([p[f[:,[0,1]]],p[f[:,[1,2]]],p[f[:,[2,0]]]])
        delta=edges[:,1]-edges[:,0];valid=abs(delta[:,0])>1e-9
        edges=edges[valid];delta=delta[valid]
        xmin=p[:,0].min();xmax=p[:,0].max()
        xs=np.unique(np.r_[np.linspace(xmin+1e-6,xmax-1e-6,361),p[:,0]])
        xs=xs[(xs>xmin+1e-7)&(xs<xmax-1e-7)]
        front=[];rear=[]
        for x in xs:
            t=(x-edges[:,0,0])/delta[:,0];use=(t>=-1e-8)&(t<=1+1e-8)
            hits=edges[use,0]+delta[use]*t[use,None]
            assert len(hits),'Factory bonnet footprint must have continuous width'
            front.append(hits[np.argmin(hits[:,2])]);rear.append(hits[np.argmax(hits[:,2])])
        loop=np.r_[front,rear[::-1]]
        area=np.sum(loop[:,0]*np.roll(loop[:,2],-1)-np.roll(loop[:,0],-1)*loop[:,2])
        if area<0:loop=loop[::-1]
        # Native contour pairing requires longitudinal stations farther apart
        # than the physical 2.5 mm ribbon width. The reduced source edge can
        # contain sub-millimetre bevel stations with identical plan positions.
        keep=np.linalg.norm(np.roll(loop[:,[0,2]],-1,axis=0)-loop[:,[0,2]],axis=1)>.0001
        loop=loop[keep];segments=np.roll(loop,-1,axis=0)-loop
        lengths=np.linalg.norm(segments[:,[0,2]],axis=1);stations=np.r_[0,np.cumsum(lengths)]
        distance=np.linspace(0,stations[-1],max(24,math.ceil(stations[-1]/.010)),endpoint=False)
        index=np.clip(np.searchsorted(stations,distance,side='right')-1,0,len(loop)-1)
        loop=loop[index]+segments[index]*((distance-stations[index])/lengths[index])[:,None]
        return loop

    def boundary(self):return self.outline

    def height(self,x,z):
        x,z=np.broadcast_arrays(x,z);result=[]
        for a,b in zip(x.ravel(),z.ravel()):
            hit,*_=self.skin.ray_cast((float(a),2,float(b)),(0,-1,0),3)
            result.append(float(hit.y) if hit is not None else float(self.fallback.height(np.array(a),np.array(b))))
        return np.asarray(result).reshape(x.shape)

    def supported_height(self,x,z):
        x,z=np.broadcast_arrays(x,z);result=[]
        for a,b in zip(x.ravel(),z.ravel()):
            hit,*_=self.skin.ray_cast((float(a),2,float(b)),(0,-1,0),3)
            assert hit is not None,'Bonnet marking must stay over the original skin: '+str((a,b))
            result.append(float(hit.y))
        return np.asarray(result).reshape(x.shape)

    def normal(self,x,z):
        x,z=np.broadcast_arrays(x,z);result=[]
        for a,b in zip(x.ravel(),z.ravel()):
            hit,n,*_=self.skin.ray_cast((float(a),2,float(b)),(0,-1,0),3)
            result.append(tuple(n) if hit is not None else (0,1,0))
        return np.asarray(result).reshape(x.shape+(3,))


def restore(exports,points,triangles,materials,components,paint_index,simple,rear_surface,source_hood,lattice):
    body=next(o for o in exports if o.name=='body__paint');hood=next(o for o in exports if o.name=='hood__paint')
    body_ids=[1464,1491,1624,1862,4445,2149,3650,3678,6287,6315]
    body_faces=triangles[(materials==paint_index)&np.isin(components,body_ids)]
    hood_faces=triangles[(materials==paint_index)&(components==1572)]
    stats={'factory_body':reduced_source(body,points,body_faces,14700 if simple else 22000),
           'factory_hood':reduced_source(hood,points,hood_faces,2400 if simple else 4500)}
    from challenger_side_surface import SharedSide
    world=panel.world(points)
    side=SharedSide(world,body_faces,world,hood_faces)
    faired,side_stats=side.apply(records(body))
    panel._write(body,faired)
    stats['factory_body']['stage']='before owner-requested side fairing'
    stats['continuous_side']={**side.stats,**side_stats}
    fallback=FactoryHood(source_hood);guide=NativeHoodGuide(hood,fallback)
    # Keep the dark vent beds and vanes seated below the original bonnet.
    old_hood=panel.CleanHood()
    for obj in exports:
        if not obj.name.startswith('hood__') or obj==hood:continue
        v=records(obj).reshape(-1,6)
        previous=old_hood.height(v[:,0],v[:,2]);actual=guide.height(v[:,0],v[:,2])
        v[:,1]+=actual-previous
        panel._write(obj,v.reshape(-1,3,6))
    finish_hood_symmetry(exports)
    seat_rear(exports,rear_surface)
    from challenger_reference_form import rebuild
    stats['reference_form'],guide,reference_field=rebuild(exports,lattice,simple,side)
    guide.reference_field=reference_field
    # Original side markers follow the actual retained body instead of a
    # procedural width estimate.
    from mathutils.bvhtree import BVHTree
    p,f,_=panel._read(body);skin=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    for obj in exports:
        if obj.name not in ['body__amber','body__red']:continue
        v=records(obj).reshape(-1,6)
        for point in v:
            if abs(point[0])<.70 or (obj.name=='body__red' and point[2]<1.6):continue
            sign=math.copysign(1,point[0]);hit,n,*_=skin.ray_cast((sign*2,float(point[1]),float(point[2])),(-sign,0,0),4)
            if hit is not None:point[0]=hit.x+sign*.003;point[3:]=n
        panel._write(obj,v.reshape(-1,3,6))
    return stats,guide




def supported_contours(exports,outline,hood):
    from mathutils.bvhtree import BVHTree
    paint=next(o for o in exports if o.name=='body__paint')
    contour=next(o for o in exports if o.name=='body__contour')
    p,f,_=panel._read(paint);bvh=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    records=[];pair_by_position={};next_pair=0
    def pair_key(point):return tuple(float(v) for v in np.asarray(np.round(point,7),dtype=np.float32))
    def append_ribbon(rows):
        nonlocal next_pair
        for row in rows:
            for side,point in zip([-1,1],row):
                key=pair_key(point[:3])
                if key in pair_by_position:
                    assert pair_by_position[key]==(next_pair,side),'Factory contour stations must stay distinct'
                pair_by_position[key]=(next_pair,side)
            next_pair+=1
        for i,a in enumerate(rows):
            b=rows[(i+1)%len(rows)]
            records.extend([[a[0],b[0],b[1]],[a[0],b[1],a[1]]])
    def ribbon(path,width,sign):
        segments=np.roll(path,-1,axis=0)-path
        lengths=np.linalg.norm(segments,axis=1)
        keep=lengths>1e-8;path=path[keep]
        segments=np.roll(path,-1,axis=0)-path;lengths=np.linalg.norm(segments,axis=1)
        stations=np.r_[0,np.cumsum(lengths)]
        distance=np.linspace(0,stations[-1],max(12,math.ceil(stations[-1]/.008)),endpoint=False)
        index=np.clip(np.searchsorted(stations,distance,side='right')-1,0,len(path)-1)
        path=path[index]+segments[index]*((distance-stations[index])/lengths[index])[:,None]
        rows=[]
        for i,point in enumerate(path):
            tangent=path[(i+1)%len(path)]-path[i-1]
            across=np.array([-tangent[1],tangent[0]])/max(np.linalg.norm(tangent),1e-12)
            hit,normal,*_=bvh.ray_cast((sign*2,float(point[0]),float(point[1])),(-sign,0,0),4)
            if hit is None:
                # The factory mesh retains physical panel gutters. Seat their
                # narrow dark marking on the nearest adjacent paint edge.
                for radius in [.001,.002,.004,.008,.016,.024]:
                    for angle in np.linspace(0,2*math.pi,16,endpoint=False):
                        nearby=(sign*2,float(point[0]+radius*math.cos(angle)),float(point[1]+radius*math.sin(angle)))
                        nearest,near_normal,*_=bvh.ray_cast(nearby,(-sign,0,0),4)
                        if nearest is not None and nearest.x*sign>.6:
                            hit,normal=nearest,near_normal;break
                    if hit is not None:break
                assert hit is not None,'Factory panel gutter must have paint within 24 mm: '+str(point)
            assert hit is not None and hit.x*sign>.6,'Contour must seat on its own side'
            slope=np.clip(-np.asarray(normal)[1:]/max(abs(normal.x),.2)*sign,-1.5,1.5)
            row=[]
            for s in [-1,1]:
                delta=across*width*.5*s;y,z=point+delta
                row.append([hit.x+float(slope@delta)+sign*.0018,y,z,sign,0,0])
            rows.append(row)
        append_ribbon(rows)
    for sign in [-1,1]:
        ribbon(panel.rounded_door(outline),.0025,sign)
        t=np.linspace(0,2*math.pi,64,endpoint=False)
        ribbon(np.c_[.905+.014*np.sin(t),.390+.066*np.cos(t)],.0025,sign)
    ribbon(np.c_[.99+.059*np.sin(t),1.31+.059*np.cos(t)],.0025,-1)
    boundary=hood.boundary()
    tangent=np.roll(boundary,-1,axis=0)-boundary
    tangent[:,1]=0;tangent=normalise(tangent)
    outward=np.c_[tangent[:,2],np.zeros(len(tangent)),-tangent[:,0]]
    previous=np.roll(outward,1,axis=0)
    # A miter keeps both ribbon edges at their exact perpendicular inset,
    # including the tight changes of direction around the original cowl.
    across=(outward+previous)/np.maximum(1+np.sum(outward*previous,axis=1),.01)[:,None]
    rows=[]
    for side in [-1,1]:
        q=boundary-across*(.0025+side*.00125)
        q[:,1]=hood.supported_height(q[:,0],q[:,2])+.0018
        rows.append(q)
    paired=[]
    for i in range(len(boundary)):
        q=np.array([rows[0][i],rows[1][i]])
        paired.append(np.c_[q,hood.normal(q[:,0],q[:,2])])
    append_ribbon(paired)
    panel._write(contour,records)
    # Export exact producer-known pairs. The native baker converts these two
    # integer UV channels into coverage attributes without topology guessing.
    mesh=contour.data
    uv=mesh.uv_layers.new(name='ContourPair');block=mesh.uv_layers.new(name='ContourPairBlock')
    for loop in mesh.loops:
        p=mesh.vertices[loop.vertex_index].co
        key=tuple([p.x,p.z,-p.y]);identity,side=pair_by_position[key]
        uv.data[loop.index].uv=(side*(identity%1024+1),0)
        block.data[loop.index].uv=(identity//1024,0)
