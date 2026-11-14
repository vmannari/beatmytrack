"""Reference-guided Challenger character line and fuller front-quarter section.

The supplied photograph guides the intentional shoulder break. These stations
are authored model-space proportions, not measurements recovered from a single
perspective photograph. Existing seams and the retained bonnet remain separate.
"""
import numpy as np


def ramp(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*t*(10+t*(-15+6*t))


def curve(z,keys,values):
    keys=np.asarray(keys);values=np.asarray(values)
    slopes=np.diff(values)/np.diff(keys)
    tangents=np.r_[slopes[0],(slopes[:-1]+slopes[1:])*.5,slopes[-1]]
    tangents[1:-1]=np.where(slopes[:-1]*slopes[1:]<=0,0,tangents[1:-1])
    i=np.clip(np.searchsorted(keys,z)-1,0,len(keys)-2)
    length=keys[i+1]-keys[i];t=np.clip((z-keys[i])/length,0,1)
    return (2*t**3-3*t*t+1)*values[i]+(t**3-2*t*t+t)*length*tangents[i]+(-2*t**3+3*t*t)*values[i+1]+(t**3-t*t)*length*tangents[i+1]


class ReferenceBody:
    Z=[-2.117,-1.98,-1.75,-1.50,-1.0,-.60,0,.45,.70,.95,1.30,1.70,2.0,2.18]
    Y=[.745,.775,.798,.815,.825,.832,.833,.842,.865,.900,.925,.930,.900,.850]
    FILLET=.0015

    def __init__(self,side,hood):
        self.side=side;self.cx=side.centre_x
        self.outer=None
        self.hood=np.asarray(hood)[::3]
        self.hood_z=np.linspace(np.min(hood[:,2]),np.max(hood[:,2]),81)
        joins=[]
        for z in self.hood_z:
            selected=hood[abs(hood[:,2]-z)<.018]
            if not len(selected):selected=hood[np.argsort(abs(hood[:,2]-z))[:20]]
            width=np.max(abs(selected[:,0]-self.cx))
            joins.append([width,np.max(selected[abs(selected[:,0]-self.cx)>width-.006,1])])
        joins=np.asarray(joins)
        self.hood_x=joins[:,0];self.hood_y=joins[:,1]

    def crease(self,z):return curve(z,self.Z,self.Y)

    def nose_amount(self,z):return ramp(-2.117,-2.075,z)*(1-ramp(-1.72,-1.50,z))

    def width(self,y,z):
        base=self.side.width(y,z);yc=self.crease(z)
        nose=self.nose_amount(z)
        wall=curve(z,[-2.117,-2.06,-1.95,-1.80,-1.55],[.825,.865,.895,.915,.920])
        xc=self.side.width(yc,z)+.006
        xc=xc*(1-nose)+wall*nose
        below=np.clip((xc-self.side.width(yc-.070,z))/.070,-.12,.20)
        below=below*(1-nose)+.055*nose
        above=np.clip((self.side.width(yc+.075,z)-xc)/.075,-2.5,-.50)
        hx=np.interp(z,self.hood_z,self.hood_x);hy=np.interp(z,self.hood_z,self.hood_y)
        on_hood=ramp(self.hood_z[0]-.01,self.hood_z[0]+.03,z)*(1-ramp(self.hood_z[-1]-.04,self.hood_z[-1],z))
        attach_slope=np.clip((hx-xc)/np.maximum(hy-yc,.025),-4.5,-.5)
        above=above*(1-on_hood)+attach_slope*on_hood
        d=y-yc
        sharp=xc+(above+below)*.5*d+(above-below)*.5*(np.sqrt(d*d+self.FILLET**2)-self.FILLET)
        band=ramp(-.12,-.055,d)*(1-ramp(.055,.125,d))
        # The reference has a near-vertical outer nose wall below the crease,
        # rather than the old early inward turn below the front wing.
        nose_band=nose*ramp(.34,.49,y)*(1-ramp(-.012,0,d))
        wall_width=xc+.055*d
        target=base*(1-band)+sharp*band
        return target*(1-nose_band)+wall_width*nose_band

    def apply(self,points,normals,contour=False):
        y,z=points[:,1],points[:,2];sign=np.sign(points[:,0]-self.cx)
        base=self.side.width(y,z)
        yc=self.crease(z);d=y-yc
        band=ramp(-.12,-.055,d)*(1-ramp(.055,.125,d))
        nose=self.nose_amount(z)*ramp(.34,.49,y)*(1-ramp(.015,.080,d))
        original_width=abs(points[:,0]-self.cx)
        outer_width=original_width.copy()
        if self.outer is not None:
            for i in np.flatnonzero(np.maximum(band,nose)>1e-8):
                hit=self.outer.ray_cast((float(self.cx+sign[i]*2),float(y[i]),float(z[i])),(-float(sign[i]),0,0),2)[0]
                if hit is not None:outer_width[i]=abs(hit.x-self.cx)
        # Preserve the thickness of the original skin and its inner returns.
        # Projecting both layers onto one coordinate creates intersecting paint
        # around the hood attachment even when their normals look smooth.
        eligible=(1-ramp(.035,.10,outer_width-original_width))*ramp(.43,.64,outer_width)
        amount=np.maximum(band,nose)*eligible
        # Width already contains the zero-slope blend ring; apply the field
        # itself to the outer skin and retain inner returns away from it.
        q=points.copy();target=self.width(y,z)
        w=amount
        selected=np.flatnonzero(w>1e-8)
        for start in range(0,len(selected),256):
            ids=selected[start:start+256]
            outer_points=points[ids].copy();outer_points[:,0]=self.cx+sign[ids]*outer_width[ids]
            distance=np.sqrt(np.min(np.sum((outer_points[:,None,:]-self.hood[None,:,:])**2,axis=-1),axis=1))
            w[ids]*=ramp(.007,.032,distance)
        q[:,0]=points[:,0]+sign*(target-outer_width)*w
        e=.000025
        dy=(self.width(y+e,z)-self.width(y-e,z))/(2*e)
        dz=(self.width(y,z+e)-self.width(y,z-e))/(2*e)
        n=np.stack([sign,-dy,-dz],axis=-1)
        n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
        n=normals*(1-w[:,None])+n*w[:,None]
        n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
        if contour:q+=n*.0018
        return q,n

    def nose_mesh(self,triangles):
        """One upright painted side closes the old wrapping lamp/wing gutter."""
        from mathutils import Vector
        from mathutils.geometry import delaunay_2d_cdt
        qmin,qmax,zmin,zmax=-.24,.01,-2.075,-1.70
        for sign in [-1,1]:
            remaining=[];boundary=[];boundary_points=[]
            for face in triangles:
                q=face[:,1]-self.crease(face[:,2]);z=face[:,2]
                if np.mean(face[:,0]-self.cx)*sign<.64 or np.min((face[:,0]-self.cx)*sign)<.50 or q.max()<qmin or q.min()>qmax or z.max()<zmin or z.min()>zmax:
                    remaining.append(face);continue
                polygon=np.c_[face,q,z]
                for axis,value,greater in [(6,qmin,True),(6,qmax,False),(7,zmin,True),(7,zmax,False)]:
                    inside=[];outside=[]
                    for i,a in enumerate(polygon):
                        b=polygon[(i+1)%len(polygon)]
                        ain=(a[axis]>=value) if greater else (a[axis]<=value)
                        bin=(b[axis]>=value) if greater else (b[axis]<=value)
                        (inside if ain else outside).append(a)
                        if ain!=bin:
                            v=a+(b-a)*((value-a[axis])/(b[axis]-a[axis]));v[1]=self.crease(v[7])+v[6]
                            inside.append(v);outside.append(v)
                    for i in range(1,len(outside)-1):remaining.append(np.array([outside[0][:6],outside[i][:6],outside[i+1][:6]]))
                    polygon=np.asarray(inside)
                    if len(polygon)<3:break
                if len(polygon)>=3:
                    for v in polygon:
                        if min(abs(v[6]-qmin),abs(v[6]-qmax),abs(v[7]-zmin),abs(v[7]-zmax))<1e-8:
                            boundary.append(v[6:8]);boundary_points.append(v.copy())
            boundary.extend([[qmin,zmin],[qmax,zmin],[qmax,zmax],[qmin,zmax]])
            boundary=np.unique(np.round(boundary,9),axis=0);centre=np.array([(qmin+qmax)*.5,(zmin+zmax)*.5])
            boundary=boundary[np.argsort(np.arctan2((boundary[:,1]-centre[1])/(zmax-zmin),(boundary[:,0]-centre[0])/(qmax-qmin)))]
            uv=boundary.tolist();edges=[(i,(i+1)%len(uv)) for i in range(len(uv))]
            for q in [-.21,-.16,-.11,-.065,-.025,-.009,0,.006]:
                for z in np.arange(zmin+.025,zmax,.025):uv.append([q,z])
            uv,_,faces,*_=delaunay_2d_cdt([Vector(v) for v in uv],edges,[],0,1e-8,False)
            uv=np.asarray(uv);y=self.crease(uv[:,1])+uv[:,0]
            x=self.side.width(y,uv[:,1]).copy()
            for i in range(len(x)):
                hit=self.outer.ray_cast((float(self.cx+sign*2),float(y[i]),float(uv[i,1])),(-sign,0,0),2)[0]
                if hit is not None:x[i]=abs(hit.x-self.cx)
            p=np.c_[self.cx+sign*x,y,uv[:,1]];n=np.tile([sign,0,0],(len(p),1))
            if boundary_points:
                inherited=np.asarray(boundary_points)
                distances=np.linalg.norm(uv[:,None,:]-inherited[None,:,6:8],axis=-1)
                for i in np.flatnonzero(np.min(distances,axis=1)<1e-6):
                    candidates=np.flatnonzero(distances[i]<1e-6)
                    chosen=candidates[np.argmax((inherited[candidates,0]-self.cx)*sign)]
                    p[i]=inherited[chosen,:3];n[i]=inherited[chosen,3:6]
            for face in faces:
                ids=np.asarray(face)
                if np.cross(p[ids[1]]-p[ids[0]],p[ids[2]]-p[ids[0]])[0]*sign<0:ids=ids[::-1]
                remaining.append(np.c_[p[ids],n[ids]])
            triangles=remaining
        return triangles

    def mesh(self,points,faces,normals):
        """Insert shared, crease-aligned rows; never shade across a broad roll."""
        from mathutils.bvhtree import BVHTree
        self.outer=BVHTree.FromPolygons(points.tolist(),np.asarray(faces).tolist(),all_triangles=True)
        output=[];start=0;original=[]
        for face in faces:
            count=len(face);p=points[face];n=normals[start:start+count];start+=count
            original.extend([np.c_[p[[0,i,i+1]],n[[0,i,i+1]]] for i in range(1,count-1)])
        for triangle in self.nose_mesh(original):
                z=triangle[:,2];d=triangle[:,1]-self.crease(z)
                if np.min(abs(triangle[:,0]-self.cx))<.64 or z.max()<-2.10 or z.min()>2.12 or d.min()>.006 or d.max()<-.006:
                    output.append(triangle);continue
                polygons=[triangle]
                for offset in [-.003,0,.003]:
                    pieces=[]
                    for polygon in polygons:
                        distances=polygon[:,1]-self.crease(polygon[:,2])-offset
                        if distances.min()>=-1e-10 or distances.max()<=1e-10:pieces.append(polygon);continue
                        lower=[];upper=[]
                        for i,a in enumerate(polygon):
                            b=polygon[(i+1)%len(polygon)];da=distances[i];db=distances[(i+1)%len(polygon)]
                            (lower if da<=0 else upper).append(a)
                            if (da<0 and db>0) or (da>0 and db<0):
                                v=a+(b-a)*(da/(da-db));v[1]=self.crease(v[2])+offset
                                lower.append(v);upper.append(v)
                        for piece in [lower,upper]:
                            if len(piece)>=3:pieces.append(np.asarray(piece))
                    polygons=pieces
                for polygon in polygons:
                    for i in range(1,len(polygon)-1):output.append(polygon[[0,i,i+1]])
        values=np.concatenate(output)
        q,n=self.apply(values[:,:3],values[:,3:])
        return q,np.arange(len(q)).reshape(-1,3),n
