"""One bounded C2 height chart for the front wing tops, with regular topology.

The bonnet supplies the inner height reference. Its vents and geometry stay
intact; physical wing boundaries and the continuous rearward side are retained.
"""
import numpy as np
from challenger_side_surface import ramp,unit
from challenger_surface_quality import SplineSheet


class Crown:
    def __init__(self,body,hood):
        from mathutils.bvhtree import BVHTree
        p=np.concatenate([body[:,:,:3],hood[:,:,:3]])
        cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);area=np.linalg.norm(cross,axis=1)
        up=cross[:,1]>area*.20
        self.tree=BVHTree.FromPolygons(p.reshape(-1,3).tolist(),np.arange(p.size//3).reshape(-1,3)[up].tolist(),all_triangles=True)
        samples=[]
        for z in np.arange(-2.070,-1.695,.015):
            for x in np.arange(.555,.866,.008):
                y=self.old_height(x,z)
                if np.isfinite(y) and .72<y<1.03:samples.append([x,z,y])
        samples=np.asarray(samples);self.x_knots=SplineSheet.knots(.53,.89,12);self.z_knots=SplineSheet.knots(-2.075,-1.68,8)
        a=self.design(samples[:,0],samples[:,1]);penalty=[]
        for axis in [0,1]:
            for i in range(12):
                for j in range(8):
                    if (i if axis==0 else j)>=(10 if axis==0 else 6):continue
                    row=np.zeros((12,8))
                    if axis==0:row[i:i+3,j]=[1,-2,1]
                    else:row[i,j:j+3]=[1,-2,1]
                    penalty.append(row.ravel()*(.25 if axis==0 else 1))
        penalty=np.asarray(penalty)*.08
        self.coefficients=np.linalg.lstsq(np.vstack([a,penalty,np.eye(96)*1e-6]),np.r_[samples[:,2],np.zeros(len(penalty)+96)],rcond=None)[0]
        # Only the upward-facing body domain is rebuilt. Exact existing seams
        # are a C2 fade boundary; no independent movement can open a gutter.
        bp=body[:,:,:3];bc=np.cross(bp[:,1]-bp[:,0],bp[:,2]-bp[:,0]);ba=np.linalg.norm(bc,axis=1)
        c=bp.mean(1);self.selected=(bc[:,1]>ba*.25)&(c[:,2]>-2.08)&(c[:,2]<-1.68)&(abs(c[:,0])>.55)
        surface=bp[self.selected];uv,inv=np.unique(np.round(surface[:,:,[0,2]].reshape(-1,2),7),axis=0,return_inverse=True)
        f=inv.reshape(-1,3);edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
        edges,count=np.unique(edges,axis=0,return_counts=True);border=edges[count==1]
        self.a=uv[border[:,0]];self.b=uv[border[:,1]];self.edge=self.b-self.a
        error=abs(a@self.coefficients-samples[:,2])*1000
        self.stats={'method':'shared bonnet/wing C2 height survey, bounded geometric fairing and boundary-preserving X/Z topology',
                    'samples':len(samples),'height_control_points':[12,8],'fit_p95_mm':float(np.percentile(error,95)),'fit_max_mm':float(error.max())}

    def old_height(self,x,z):
        hit,*_=self.tree.ray_cast((float(x),2,float(z)),(0,-1,0),2)
        return float(hit.y) if hit is not None else np.nan

    def design(self,x,z):
        return (SplineSheet.basis(abs(np.asarray(x)),self.x_knots)[:,:,None]*SplineSheet.basis(z,self.z_knots)[:,None,:]).reshape(-1,96)

    def smooth(self,x,z):return self.design(x,z)@self.coefficients

    def field(self,x,z):
        x,z=np.asarray(x).ravel(),np.asarray(z).ravel();old=np.array([self.old_height(a,b) for a,b in zip(x,z)])
        fitted=self.smooth(x,z);distance=np.empty(len(x));uv=np.c_[x,z]
        for start in range(0,len(x),512):
            q=uv[start:start+512];t=np.clip(np.sum((q[:,None,:]-self.a)*self.edge,axis=2)/np.maximum(np.sum(self.edge*self.edge,axis=1),1e-20),0,1)
            distance[start:start+512]=np.sqrt(np.min(np.sum((q[:,None,:]-self.a-t[:,:,None]*self.edge)**2,axis=2),axis=1))
        valid=np.isfinite(old);old[~valid]=fitted[~valid]
        w=ramp(-2.070,-2.035,z)*(1-ramp(-1.80,-1.70,z))*ramp(.0005,.020,distance)
        w*=1-ramp(.006,.012,abs(fitted-old));w*=valid
        return old+w*(fitted-old),w,old

    def apply(self,body):
        result=body.copy();v=result[self.selected].copy();p=v[:,:,:3].reshape(-1,3)
        height,w,old=self.field(p[:,0],p[:,2]);w*=1-ramp(.001,.006,abs(p[:,1]-old))
        correction=w*(self.smooth(p[:,0],p[:,2])-old);v[:,:,1]+=correction.reshape(-1,3)
        e=.00004
        dx=(self.field(p[:,0]+e,p[:,2])[0]-self.field(p[:,0]-e,p[:,2])[0])/(2*e)
        dz=(self.field(p[:,0],p[:,2]+e)[0]-self.field(p[:,0],p[:,2]-e)[0])/(2*e)
        guide=unit(np.c_[-dx,np.ones(len(dx)),-dz]);n=v[:,:,3:].reshape(-1,3)
        n[:]=unit(n*(1-w[:,None])+guide*w[:,None]);result[self.selected]=v
        self.stats.update({'maximum_vertex_correction_mm':float(abs(correction).max()*1000),'modified_corners':int((abs(correction)>1e-8).sum())})
        return result

    def retessellate(self,values,simple,spacing=None):
        from mathutils import Vector
        from mathutils.bvhtree import BVHTree
        from mathutils.geometry import delaunay_2d_cdt
        spacing=spacing or (.035 if simple else .025);p=values[:,:,:3];c=p.mean(1)
        cross=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);h,w,_=self.field(p[:,:,0].ravel(),p[:,:,2].ravel())
        chosen=(w.reshape(-1,3).min(1)>.999)&(abs(p[:,:,1]-h.reshape(-1,3)).max(1)<.00002)&(cross[:,1]>1e-10)
        if not chosen.any():return values,{'replaced_triangles':0,'new_triangles':0}
        selected=p[chosen];uv,inv=np.unique(np.round(selected[:,:,[0,2]].reshape(-1,2),8),axis=0,return_inverse=True);f=inv.reshape(-1,3)
        edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1);edges,count=np.unique(edges,axis=0,return_counts=True);border=edges[count==1]
        ids=np.unique(border);lookup={v:i for i,v in enumerate(ids)};constraints=[(lookup[a],lookup[b]) for a,b in border];samples=uv[ids].tolist()
        tree=BVHTree.FromPolygons(np.c_[uv[:,0],np.zeros(len(uv)),uv[:,1]].tolist(),f.tolist(),all_triangles=True)
        def inside(x,z):return tree.ray_cast((float(x),1,float(z)),(0,-1,0),2)[0] is not None
        for x in np.arange(uv[:,0].min()+spacing*.5,uv[:,0].max(),spacing):
            for z in np.arange(uv[:,1].min()+spacing*.5,uv[:,1].max(),spacing):
                if inside(x,z):samples.append([float(x),float(z)])
        vertices,_,faces,*_=delaunay_2d_cdt([Vector(q) for q in samples],constraints,[],0,1e-8,False);vertices=np.asarray(vertices)
        faces=np.asarray([face for face in faces if inside(*vertices[face].mean(0))],dtype=int)
        if len(faces)>chosen.sum():
            if spacing<.25:return self.retessellate(values,simple,spacing*1.25)
            return values,{'replaced_triangles':0,'new_triangles':0,'budget_kept':True}
        q=np.c_[vertices[:,0],self.smooth(vertices[:,0],vertices[:,1]),vertices[:,1]]
        old_points=np.empty((len(uv),3));old_points[inv]=selected.reshape(-1,3)
        a,b=uv[border[:,0]],uv[border[:,1]];d=b-a
        t=np.clip(np.sum((vertices[:,None,:]-a)*d,axis=2)/np.maximum(np.sum(d*d,axis=1),1e-20),0,1)
        distance=np.linalg.norm(vertices[:,None,:]-a-t[:,:,None]*d,axis=2);nearest=distance.argmin(1)
        for i in np.flatnonzero(distance[np.arange(len(q)),nearest]<1e-7):
            edge=border[nearest[i]];amount=t[i,nearest[i]];q[i]=old_points[edge[0]]*(1-amount)+old_points[edge[1]]*amount
        e=.00004;dx=(self.smooth(q[:,0]+e,q[:,2])-self.smooth(q[:,0]-e,q[:,2]))/(2*e);dz=(self.smooth(q[:,0],q[:,2]+e)-self.smooth(q[:,0],q[:,2]-e))/(2*e)
        normals=unit(np.c_[-dx,np.ones(len(dx)),-dz]);flip=np.cross(q[faces[:,1]]-q[faces[:,0]],q[faces[:,2]]-q[faces[:,0]])[:,1]<0;faces[flip]=faces[flip,::-1]
        rebuilt=np.concatenate([q[faces],normals[faces]],axis=2);result=np.concatenate([values[~chosen],rebuilt])
        return result,{'replaced_triangles':int(chosen.sum()),'new_triangles':len(faces),'spacing_metres':spacing,'preserved_boundary_stations':len(ids)}


def finish(exports,simple):
    import challenger_clean_panels as panel
    from challenger_exterior_geometry import records
    body=next(obj for obj in exports if obj.name=='body__paint');hood=next(obj for obj in exports if obj.name=='hood__paint')
    values=records(body);field=Crown(values,records(hood));values=field.apply(values)
    values,field.stats['tessellation']=field.retessellate(values,simple)
    # Match the producer's native half-mesh contract after any CDT diagonal
    # crosses the centre plane. Both tiers get one identical right-hand source.
    axis=abs(values[:,:,0])<.000030;values[:,:,0][axis]=0;values[:,:,3][axis]=0
    right=panel._positive(values);left=right[:,::-1,:].copy();left[:,:,0]*=-1;left[:,:,3]*=-1
    values=np.concatenate([right,left])
    panel._write(body,values)
    return field.stats
