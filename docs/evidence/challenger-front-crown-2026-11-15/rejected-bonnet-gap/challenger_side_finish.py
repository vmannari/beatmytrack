"""Offline shoulder-aligned topology and a common side surface.

The narrow transverse bend is explicitly sampled by longitudinal edge rows.
Coordinates remain in the current (extended-front) chart until the final common
front-overhang transform; wheels and simulation never enter this operation.
"""
import numpy as np
from challenger_side_surface import ramp,unit
from challenger_surface_quality import SplineSheet


class SideSheet:
    RADIUS=.009
    ROWS=np.array([-.15,-.10,-.065,-.040,-.025,-.014,-.007,-.003,0,.003,.007,.014,.025,.045,.080,.115,.15])
    SIMPLE_ROWS=np.array([-.15,-.075,-.030,-.012,-.006,0,.006,.012,.030,.075,.15])

    def __init__(self,values,crease):
        from mathutils.bvhtree import BVHTree
        self.crease=crease
        p=values[:,:,:3];cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);centre=p.mean(1)
        chosen=(cross[:,0]>1e-11)&(centre[:,0]>.65)
        points=p.reshape(-1,3);faces=np.arange(len(points)).reshape(-1,3)
        tree=BVHTree.FromPolygons(points.tolist(),faces[chosen].tolist(),all_triangles=True)
        samples=[]
        for z in np.arange(-2.24,2.131,.035):
            c=float(crease(z))
            for d in np.arange(-.18,.181,.009):
                hit,normal,*_=tree.ray_cast((2,c+float(d),float(z)),(-1,0,0),2)
                if c+d<1.04 and hit is not None and .69<hit.x<1.02 and normal.x>.20:samples.append([d,z,hit.x])
        samples=np.asarray(samples)
        background=SplineSheet.__new__(SplineSheet)
        background.y_knots=SplineSheet.knots(-.22,.22,8)
        background.z_knots=SplineSheet.knots(-2.28,2.24,16)
        a=background.design(samples[:,0],samples[:,1])
        rhs=samples[:,2]-self.bend(samples[:,0])
        penalty=[]
        for axis,count in [(0,8),(1,16)]:
            for i in range(8):
                for j in range(16):
                    if (i if axis==0 else j)>=count-2:continue
                    row=np.zeros((8,16))
                    if axis==0:row[i:i+3,j]=[1,-2,1]
                    else:row[i,j:j+3]=[1,-2,1]
                    penalty.append(row.ravel())
        penalty=np.asarray(penalty)*.12
        keep=np.ones(len(samples),dtype=bool)
        for iteration in range(4):
            matrix=np.vstack([a[keep],penalty,np.eye(128)*1e-6])
            target=np.r_[rhs[keep],np.zeros(len(penalty)+128)]
            background.coefficients=np.linalg.lstsq(matrix,target,rcond=None)[0]
            keep=abs(a@background.coefficients-rhs)<.012
        self.background=background
        error=abs(a@background.coefficients-rhs)*1000
        self.stats={'method':'measured C2 background plus explicitly sampled longitudinal shoulder fillet',
                    'samples':len(samples),'fit_inliers':int(keep.sum()),'fillet_radius_mm':self.RADIUS*1000,
                    'fit_error_p95_mm':float(np.percentile(error,95)),'fit_error_max_mm':float(error.max())}

    @classmethod
    def bend(cls,d):return -.24*(np.sqrt(np.asarray(d)**2+cls.RADIUS**2)-cls.RADIUS)

    def width(self,y,z):
        d=np.asarray(y)-self.crease(z)
        return self.background(d,z)+self.bend(d)

    def normal(self,p):
        e=.000025;y,z=p[:,1],p[:,2]
        dy=(self.width(y+e,z)-self.width(y-e,z))/(2*e)
        dz=(self.width(y,z+e)-self.width(y,z-e))/(2*e)
        return unit(np.c_[np.sign(p[:,0]),-dy,-dz])

    def weight(self,p):
        x,y,z=abs(p[:,0]),p[:,1],p[:,2];d=y-self.crease(z)
        return (ramp(.68,.74,x)*ramp(-.195,-.15,d)*(1-ramp(.15,.19,d))
                *ramp(-2.26,-2.20,z)*(1-ramp(2.05,2.20,z))
                *(1-ramp(1.04,1.10,y)))

    def apply(self,values):
        from mathutils.bvhtree import BVHTree
        out=np.array(values,copy=True);v=out.reshape(-1,6);p=v[:,:3].copy()
        w=self.weight(p);delta=np.sign(p[:,0])*self.width(p[:,1],p[:,2])-p[:,0]
        w*=1-ramp(.030,.045,abs(delta))
        v[:,0]+=w*delta
        cross=np.cross(out[:,1,:3]-out[:,0,:3],out[:,2,:3]-out[:,0,:3]);length=np.linalg.norm(cross,axis=1)
        centre=out[:,:,:3].mean(1);exterior=cross[:,0]*np.sign(centre[:,0])>0
        # A corner that cannot be projected onto this chart must retain its
        # own surface normal. Unconditional chart normals created false folds
        # along the bonnet return and the formerly excluded nose transition.
        guide=self.normal(v[:,:3]);nw=w*np.repeat(exterior,3)
        previous=v[:,3:].copy();previous[(np.sum(previous*guide,axis=1)<0)&(nw>0)]*=-1
        v[:,3:]=unit(previous*(1-nw[:,None])+guide*nw[:,None])
        faces=np.arange(len(v)).reshape(-1,3)
        tree=BVHTree.FromPolygons(v[:,:3].tolist(),faces[exterior&(length>1e-11)].tolist(),all_triangles=True)
        remove=np.zeros(len(out),dtype=bool)
        # Keep the nose aperture's intentional inward return. Extending the
        # fair chart must not extend generic hidden-side removal into optics.
        for i in np.flatnonzero((~exterior)&(w.reshape(-1,3).mean(1)>.01)&(centre[:,2]>-2.14)):
            sign=float(np.sign(centre[i,0]));hit,*_=tree.ray_cast((sign*2,float(centre[i,1]),float(centre[i,2])),(-sign,0,0),2)
            remove[i]=hit is not None and abs(hit.x-centre[i,0])<.006
        self.stats.update({'maximum_vertex_correction_mm':float(np.max(abs(w*delta)))*1000,'covered_returns_removed':int(remove.sum())})
        return out[(length>1e-11)&~remove]

    def retessellate(self,values,simple,spacing=None,budget=None):
        from mathutils import Vector
        from mathutils.bvhtree import BVHTree
        from mathutils.geometry import delaunay_2d_cdt
        spacing=spacing or (.065 if simple else .045)
        budget=len(values) if budget is None else budget
        masks=[];rebuilt=[];boundaries=0;removed=0
        for sign in [-1,1]:
            p=values[:,:,:3];c=p.mean(1);cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
            full=self.weight(p.reshape(-1,3)).reshape(-1,3).min(1)>.9999
            error=abs(abs(p[:,:,0])-self.width(p[:,:,1],p[:,:,2])).max(1)
            selected=full&(error<.000015)&(c[:,0]*sign>0)&(cross[:,0]*sign>1e-10)
            if not np.any(selected):continue
            removed+=int(selected.sum());masks.append(selected)
            source=p[selected];d=source[:,:,1]-self.crease(source[:,:,2])
            uv,inverse=np.unique(np.round(np.stack([d,source[:,:,2]],axis=-1).reshape(-1,2),8),axis=0,return_inverse=True)
            f=inverse.reshape(-1,3)
            edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
            edges,counts=np.unique(edges,axis=0,return_counts=True);border=edges[counts==1]
            ids=np.unique(border);boundaries+=len(ids);lookup={old:i for i,old in enumerate(ids)}
            constraints=[(lookup[a],lookup[b]) for a,b in border];samples=uv[ids].tolist()
            domain=BVHTree.FromPolygons(np.c_[np.zeros(len(uv)),uv].tolist(),f.tolist(),all_triangles=True)
            def inside(d,z):return domain.ray_cast((1,float(d),float(z)),(-1,0,0),2)[0] is not None
            rows=self.SIMPLE_ROWS if simple else self.ROWS
            for dd in rows:
                previous=None
                for zz in np.arange(uv[:,1].min()+spacing*.5,uv[:,1].max(),spacing):
                    if not inside(dd,zz):previous=None;continue
                    index=len(samples);samples.append([float(dd),float(zz)])
                    if previous is not None and inside(dd,(samples[previous][1]+zz)*.5):constraints.append((previous,index))
                    previous=index
            vertices,_,faces,*_=delaunay_2d_cdt([Vector(q) for q in samples],constraints,[],0,1e-8,False)
            vertices=np.asarray(vertices)
            faces=np.asarray([f for f in faces if inside(*vertices[f].mean(0))],dtype=int)
            z=vertices[:,1];y=self.crease(z)+vertices[:,0]
            q=np.c_[sign*self.width(y,z),y,z]
            a,b=uv[border[:,0]],uv[border[:,1]];delta=b-a
            t=np.clip(np.sum((vertices[:,None,:]-a)*delta,axis=2)/np.maximum(np.sum(delta*delta,axis=1),1e-20),0,1)
            distance=np.linalg.norm(vertices[:,None,:]-a-t[:,:,None]*delta,axis=2);nearest=distance.argmin(1)
            # Keep the exact existing 3D boundary, including wheel-arch cuts.
            old_points=np.empty((len(uv),3));old_points[inverse]=source.reshape(-1,3)
            for i in np.flatnonzero(distance[np.arange(len(q)),nearest]<1e-7):
                edge=border[nearest[i]];amount=t[i,nearest[i]]
                q[i]=old_points[edge[0]]*(1-amount)+old_points[edge[1]]*amount
            reverse=np.cross(q[faces[:,1]]-q[faces[:,0]],q[faces[:,2]]-q[faces[:,0]])[:,0]*sign<0
            faces[reverse]=faces[reverse,::-1]
            normals=self.normal(q)
            rebuilt.append(np.concatenate([q[faces],normals[faces]],axis=2))
        if not masks:return values,{'replaced_triangles':0,'new_triangles':0}
        result=np.concatenate([values[~np.any(masks,axis=0)],*rebuilt])
        print('SIDE_TESSELLATION_BUDGET',simple,spacing,removed,sum(map(len,rebuilt)),boundaries,flush=True)
        if len(result)>budget and spacing<.22:return self.retessellate(values,simple,spacing*1.15,budget)
        assert len(result)<=budget,'Shoulder-aligned topology must fit the current body triangle allocation'
        return result,{'replaced_triangles':removed,'new_triangles':sum(map(len,rebuilt)),
                       'boundary_stations':boundaries,'longitudinal_spacing_m':spacing,'transverse_rows_m':rows.tolist()}


def finish(exports,reference,simple):
    import challenger_clean_panels as panel
    from challenger_exterior_geometry import records
    body=next(o for o in exports if o.name=='body__paint')
    original=records(body)
    field=SideSheet(original,reference.side_crease)
    values=field.apply(original);values,stats=field.retessellate(values,simple,budget=len(original))
    panel._write(body,values)
    return {**field.stats,'tessellation':stats}


def front_z(z):
    z=np.asarray(z)
    return z+.140*(1-ramp(-2.23,-1.68,z))


def inverse_front_z(z):
    z=np.asarray(z);old=z-.14
    for _ in range(12):old+=z-front_z(old)
    return old


def shorten(exports):
    for obj in exports:
        mesh=obj.data
        p=np.asarray([v.co[:] for v in mesh.vertices]);z=-p[:,1];e=.000025
        derivative=(front_z(z+e)-front_z(z-e))/(2*e)
        n=np.asarray([n.vector[:] for n in mesh.corner_normals])
        ids=np.asarray([loop.vertex_index for loop in mesh.loops])
        n[:,1]/=derivative[ids];n=unit(n)
        p[:,1]=-front_z(z)
        mesh.vertices.foreach_set('co',p.ravel());mesh.update()
        mesh.normals_split_custom_set(n.tolist())
