"""Offline, bounded upper-wing fairing on the existing design chart.

The lower shoulder, bonnet, openings and roof retain their authored geometry.
No runtime smoothing, material changes or subdivision is involved.
"""
import numpy as np
from challenger_side_surface import ramp, unit


class SplineSheet:
    """C2 tensor-product fit to uniformly surveyed exterior geometry."""
    def __init__(self, values):
        from mathutils.bvhtree import BVHTree
        p=values[:,:,:3];cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);centre=p.mean(1)
        outward=(cross[:,0]>1e-10)&(centre[:,0]>.65)&(centre[:,2]<-.68)
        points=p.reshape(-1,3)
        tree=BVHTree.FromPolygons(points.tolist(),np.arange(len(points)).reshape(-1,3)[outward].tolist(),all_triangles=True)
        samples=[]
        for y in np.arange(.754,1.035,.008):
            for z in np.arange(-2.216,-.704,.016):
                hit,normal,*_=tree.ray_cast((2,float(y),float(z)),(-1,0,0),2)
                if hit is not None and .69<hit.x<1.01 and normal.x>.15:samples.append([y,z,hit.x])
        samples=np.asarray(samples)
        self.y_knots=self.knots(.74,1.06,8)
        self.z_knots=self.knots(-2.24,-.68,16)
        a=self.design(samples[:,0],samples[:,1]);rhs=samples[:,2]
        # Penalise control-point second differences to suppress the old local
        # polygon waves without reproducing every triangle as a control point.
        regular=[]
        for axis,count in [(0,8),(1,16)]:
            for i in range(8):
                for j in range(16):
                    if (i if axis==0 else j)>=count-2:continue
                    row=np.zeros((8,16))
                    if axis==0:row[i:i+3,j]=[1,-2,1]
                    else:row[i,j:j+3]=[1,-2,1]
                    regular.append(row.ravel())
        penalty=np.asarray(regular)*.08
        matrix=np.vstack([a,penalty,np.eye(128)*1e-6])
        target=np.r_[rhs,np.zeros(len(penalty)+128)]
        self.coefficients=np.linalg.lstsq(matrix,target,rcond=None)[0]
        error=abs(a@self.coefficients-rhs)*1000
        self.stats={'samples':len(samples),'control_points_yz':[8,16],
                    'sample_error_p95_mm':float(np.percentile(error,95)),
                    'sample_error_max_mm':float(error.max()),'second_difference_penalty':.08}

    @staticmethod
    def knots(low,high,count):
        return np.r_[np.repeat(low,4),np.linspace(low,high,count-2)[1:-1],np.repeat(high,4)]

    @staticmethod
    def basis(values,knots):
        q=np.clip(np.asarray(values).ravel(),knots[0],knots[-1]-1e-12)
        b=((q[:,None]>=knots[:-1])&(q[:,None]<knots[1:])).astype(float)
        for degree in range(1,4):
            n=len(knots)-degree-1;result=np.zeros((len(q),n))
            for i in range(n):
                left=knots[i+degree]-knots[i];right=knots[i+degree+1]-knots[i+1]
                if left>0:result[:,i]+=(q-knots[i])/left*b[:,i]
                if right>0:result[:,i]+=(knots[i+degree+1]-q)/right*b[:,i+1]
            b=result
        return b

    def design(self,y,z):
        a=self.basis(y,self.y_knots);b=self.basis(z,self.z_knots)
        return (a[:,:,None]*b[:,None,:]).reshape(len(a),-1)

    def __call__(self,y,z):
        y,z=np.broadcast_arrays(y,z)
        return np.sum((self.basis(y,self.y_knots)@self.coefficients.reshape(8,16))*self.basis(z,self.z_knots),axis=1).reshape(y.shape)


class UpperWing:
    def __init__(self, reference, values):
        self.reference = reference
        self.sheet = SplineSheet(values)

    def width(self, y, z):
        return self.sheet(y,z)

    def weight(self, p):
        r = self.reference
        x, y, z = abs(p[:, 0]), p[:, 1], p[:, 2]
        c = r.side_crease(np.clip(z, -2.26, -.70))
        return (ramp(.70, .74, x)*ramp(c+.008, c+.030, y)
                *ramp(-2.22, -2.16, z)*(1-ramp(-.78, -.70, z))
                *(1-ramp(1.005, 1.05, y)))

    def normals(self, p):
        e = .000025
        y, z = p[:, 1], p[:, 2]
        dy = (self.width(y+e, z)-self.width(y-e, z))/(2*e)
        dz = (self.width(y, z+e)-self.width(y, z-e))/(2*e)
        return unit(np.c_[np.sign(p[:, 0]), -dy, -dz])

    def apply(self, values):
        values = np.asarray(values).reshape(-1, 3, 6).copy()
        vertices = values.reshape(-1, 6)
        p = vertices[:, :3].copy()
        region = self.weight(p)
        weight = region.copy()
        target = np.sign(p[:, 0])*self.width(p[:, 1], p[:, 2])
        # Do not pull unrelated aperture walls, cowl banks or hidden returns
        # through the body. The physical correction is explicitly bounded.
        delta = target-p[:, 0]
        weight *= 1-ramp(.012, .020, abs(delta))
        vertices[:, 0] += weight*delta
        guide = self.normals(vertices[:, :3])
        # Derive fully faired normals from the surface, never from transferred
        # normals on the opposite side of the source's thin returned skins.
        cross = np.cross(values[:, 1, :3]-values[:, 0, :3], values[:, 2, :3]-values[:, 0, :3])
        length = np.linalg.norm(cross, axis=1)
        centre = values[:, :, :3].mean(1)
        inward = cross[:, 0]*np.sign(centre[:, 0]) < 0
        # A thin returned sheet has a separate smoothing domain. Exterior
        # copies sharing the same position all use this sheet's same tangent,
        # including source triangles at the constrained tessellation border.
        continuous=(~inward)&(cross[:,1]>=-.05*length)
        normal_weight=region*np.repeat(continuous,3)
        previous=vertices[:,3:].copy()
        wrong=(np.sum(previous*guide,axis=1)<0)&(normal_weight>0)
        previous[wrong]*=-1
        vertices[:,3:]=unit(previous*(1-normal_weight[:,None])+guide*normal_weight[:,None])
        # Bonnet gutters also contain an intentional downward-facing return.
        # Its narrow underside is a distinct hard surface, not the wing crown.
        returns=(~continuous)&(~inward)&(region.reshape(-1,3).max(1)>0)
        bad=np.any(np.sum(values[:,:,3:]*unit(cross)[:,None,:],axis=2)<0,axis=1)
        values[returns&bad,:,3:]=unit(cross[returns&bad])[:,None,:]
        # A returned skin can only be removed after an outward-face ray proves
        # that the visible shell still covers it, within the correction budget.
        from mathutils.bvhtree import BVHTree
        outward = (cross[:, 0]*np.sign(centre[:, 0]) > 1e-11) & (length > 1e-11)
        points = values[:, :, :3].reshape(-1, 3)
        tree = BVHTree.FromPolygons(points.tolist(), np.arange(len(points)).reshape(-1,3)[outward].tolist(), all_triangles=True)
        remove = np.zeros(len(values), dtype=bool)
        returned=inward & (region.reshape(-1,3).mean(1)>.01)
        for i in np.flatnonzero(returned):
            sign = float(np.sign(centre[i, 0]))
            hit, *_ = tree.ray_cast((sign*2, float(centre[i,1]), float(centre[i,2])), (-sign,0,0), 2)
            remove[i] = hit is not None and abs(hit.x-centre[i,0]) < .006
        keep = (length > 1e-11) & ~remove
        moved = np.linalg.norm(vertices[:, :3]-p, axis=1)
        assert moved.max() < .0141, 'Local fairing may not exceed its explicit correction budget'
        return values[keep], {
            'method': 'bounded geometric projection and normals from one rounded upper-wing chart',
            'before_triangles': len(values), 'after_triangles': int(keep.sum()),
            'maximum_displacement_mm': float(moved.max()*1000),
            'modified_corners': int(np.sum(moved > 1e-10)),
            'covered_inward_triangles_removed': int(remove.sum()),
            'sheet_fit': self.sheet.stats,
        }


    def retessellate(self, values, simple):
        """Keep the exact patch border and replace irregular interior triangles."""
        from mathutils import Vector
        from mathutils.bvhtree import BVHTree
        from mathutils.geometry import delaunay_2d_cdt
        kept=[]; rebuilt=[]; replaced=0; boundary_count=0
        for sign in [-1, 1]:
            p=values[:,:,:3]; centre=p.mean(1)
            cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
            full=self.weight(p.reshape(-1,3)).reshape(-1,3).min(1)>.9999
            error=abs(abs(p[:,:,0])-self.width(p[:,:,1],p[:,:,2])).max(1)
            chosen=full & (error<.00001) & (cross[:,0]*sign>1e-10) & (centre[:,0]*sign>0)
            selected=p[chosen]
            if not len(selected):continue
            replaced+=len(selected)
            uv,inverse=np.unique(np.round(selected[:,:,1:].reshape(-1,2),8),axis=0,return_inverse=True)
            f=inverse.reshape(-1,3)
            edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
            edges,counts=np.unique(edges,axis=0,return_counts=True)
            border=edges[counts==1]; ids=np.unique(border); boundary_count+=len(ids)
            lookup={old:new for new,old in enumerate(ids)}
            constraints=[(lookup[a],lookup[b]) for a,b in border]
            boundary=uv[ids]
            flat=np.c_[np.zeros(len(uv)),uv]
            domain=BVHTree.FromPolygons(flat.tolist(),f.tolist(),all_triangles=True)
            def inside(y,z):
                return domain.ray_cast((1,float(y),float(z)),(-1,0,0),2)[0] is not None
            points=boundary.tolist()
            dy,dz=(.022,.032) if simple else (.014,.022)
            low,high=uv.min(0),uv.max(0)
            for y in np.arange(low[0]+dy*.5,high[0],dy):
                for z in np.arange(low[1]+dz*.5,high[1],dz):
                    if inside(y,z):points.append([y,z])
            uv_new,_,faces,*_=delaunay_2d_cdt([Vector(q) for q in points],constraints,[],0,1e-8,False)
            uv_new=np.asarray(uv_new)
            faces=np.asarray([face for face in faces if inside(*uv_new[face].mean(0))],dtype=int)
            q=np.c_[sign*self.width(uv_new[:,0],uv_new[:,1]),uv_new]
            # CDT retains input boundary stations. Any intersection station is
            # seated on the original 3D edge, avoiding a crack at the border.
            a,b=uv[border[:,0]],uv[border[:,1]];delta=b-a
            t=np.clip(np.sum((uv_new[:,None,:]-a)*delta,axis=2)/np.maximum(np.sum(delta*delta,axis=1),1e-20),0,1)
            distance=np.linalg.norm(uv_new[:,None,:]-a-t[:,:,None]*delta,axis=2)
            nearest=distance.argmin(1)
            for i in np.flatnonzero(distance[np.arange(len(q)),nearest]<1e-7):
                j=nearest[i];aa,bb=border[j];amount=t[i,j]
                qa=np.r_[sign*self.width(*uv[aa]),uv[aa]]
                qb=np.r_[sign*self.width(*uv[bb]),uv[bb]]
                q[i]=qa*(1-amount)+qb*amount
            normals=self.normals(q)
            triangles=q[faces]
            reverse=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])[:,0]*sign<0
            faces[reverse]=faces[reverse,::-1]
            rebuilt.append(np.concatenate([q[faces],normals[faces]],axis=2))
            kept.append(chosen)
        if not rebuilt:return values,{'replaced_triangles':0,'new_triangles':0}
        result=np.concatenate([values[~np.any(kept,axis=0)],*rebuilt])
        assert len(result)<len(values)+2200, 'Upper-wing tessellation has a fixed local budget'
        return result,{'replaced_triangles':replaced,'new_triangles':sum(len(row) for row in rebuilt),'retained_boundary_stations':boundary_count,'spacing_yz_metres':[dy,dz]}


def finish(exports, reference, simple):
    from challenger_exterior_geometry import records
    import challenger_clean_panels as panel
    body = next(obj for obj in exports if obj.name == 'body__paint')
    original=records(body)
    field=UpperWing(reference,original)
    values, stats = field.apply(original)
    values, stats['tessellation'] = field.retessellate(values, simple)
    panel._write(body, values)
    return stats
