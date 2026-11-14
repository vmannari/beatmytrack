"""Measured exterior fields. Preserve factory profiles without global polynomials."""
import numpy as np


def cubic_weights(t):
    return np.stack([-.5*t+t*t-.5*t*t*t,
                     1-2.5*t*t+1.5*t*t*t,
                     .5*t+2*t*t-1.5*t*t*t,
                     -.5*t*t+.5*t*t*t],axis=-1)


class SurfaceGrid:
    def __init__(self,a,b,values):
        self.a=np.asarray(a);self.b=np.asarray(b);self.values=np.asarray(values)

    def at(self,a,b):
        a,b=np.broadcast_arrays(a,b)
        u=np.clip((a-self.a[0])/(self.a[1]-self.a[0]),0,len(self.a)-1)
        v=np.clip((b-self.b[0])/(self.b[1]-self.b[0]),0,len(self.b)-1)
        i=np.floor(u).astype(int);j=np.floor(v).astype(int)
        wa=cubic_weights(u-i);wb=cubic_weights(v-j)
        ii=np.clip(i[...,None]+np.arange(-1,3),0,len(self.a)-1)
        jj=np.clip(j[...,None]+np.arange(-1,3),0,len(self.b)-1)
        samples=self.values[ii[..., :,None],jj[...,None,:]]
        return np.sum(samples*wa[..., :,None]*wb[...,None,:],axis=(-2,-1))


def fill_rows(values,axis):
    data=values if axis==1 else values.T
    valid_rows=[]
    for i,row in enumerate(data):
        known=np.flatnonzero(np.isfinite(row))
        if len(known)<2:continue
        missing=np.flatnonzero(~np.isfinite(row))
        row[missing]=np.interp(missing,known,row[known]);valid_rows.append(i)
    for i in range(len(data)):
        if i not in valid_rows:
            closest=min(valid_rows,key=lambda j:abs(i-j));data[i]=data[closest]
    return data if axis==1 else data.T


class SideSurface:
    def __init__(self,points,triangles,components,bvh):
        self.a=np.linspace(.285,1.105,83)
        self.b=np.linspace(-1.98,2.18,209)
        door=points[np.unique(triangles[components==1862])]
        opposite=points[np.unique(triangles[components==4445])]
        self.centre_x=float((door[:,0].mean()+opposite[:,0].mean())*.5)
        values=np.full((len(self.a),len(self.b)),np.nan)
        hits=0
        # Ignore the original physical door gutters as well as the handle
        # pockets. Fill across the car's length, retaining the vertical crown
        # and shoulder profile instead of fitting one high-degree polynomial.
        outline=_hull(door[:,[1,2]])
        for i,y in enumerate(self.a):
            for j,z in enumerate(self.b):
                if .855<y<.954 and .225<z<.545:continue
                if y<.972 and _edge_distance(np.array([y,z]),outline)<.021:continue
                widths=[]
                for sign in [-1,1]:
                    if sign<0 and ((y-.99)/.105)**2+((z-1.31)/.145)**2<1.3**2:continue
                    hit=bvh.ray_cast((sign*2,float(y),float(z)),(-sign,0,0),2)[0]
                    if hit is not None and .64<abs(hit.x)<1.01:widths.append(sign*(hit.x-self.centre_x))
                if widths:values[i,j]=np.mean(widths);hits+=1
        valid=np.isfinite(values)
        values=fill_rows(values,1)
        # A 40 mm longitudinal fairing removes small local waviness while
        # preserving the transverse factory folds and the arch silhouette.
        kernel=np.array([1,4,6,4,1],dtype=float)/16
        padded=np.pad(values,((0,0),(2,2)),mode='edge')
        values=sum(kernel[k]*padded[:,k:k+len(self.b)] for k in range(5))
        yy,zz=np.meshgrid(self.a,self.b,indexing='ij')
        # A filled row alone leaves derivative changes around the old handle
        # pocket. Fair its surrounding sheet as one local patch, then blend
        # through a wider ring so the flush contour has no recessed shading.
        def patch_terms(y,z):
            y=(y-.90)/.12;z=(z-.39)/.25
            return np.stack([y**i*z**j for i in range(7) for j in range(3)],axis=-1)
        ring=valid&(yy>.79)&(yy<1.015)&(zz>.14)&(zz<.63)
        design=patch_terms(yy[ring],zz[ring]);targets=values[ring]
        accepted=np.ones(len(targets),dtype=bool)
        for _ in range(4):
            coefficients=np.linalg.lstsq(design[accepted],targets[accepted],rcond=None)[0]
            accepted=abs(design@coefficients-targets)<.004
        def blend(a,b,value):
            t=np.clip((value-a)/(b-a),0,1);return t*t*(3-2*t)
        amount=blend(.79,.855,yy)*(1-blend(.954,1.015,yy))*blend(.14,.225,zz)*(1-blend(.545,.63,zz))
        values=values*(1-amount)+(patch_terms(yy,zz)@coefficients)*amount
        self.grid=SurfaceGrid(self.a,self.b,values)
        self.stats={'measured_grid_points':hits,'total_grid_points':int(valid.size),'centre_x':self.centre_x,
                    'method':'source transverse profiles; longitudinal and local handle fairing; cubic field, common panel normals'}

    def width(self,y,z):return self.grid.at(y,z)


class SampledHood:
    def __init__(self,bvh,bounds):
        low,high=bounds
        self.x=np.linspace(low[0],high[0],129)
        self.z=np.linspace(low[2],high[2],113)
        values=np.full((len(self.x),len(self.z)),np.nan)
        normals=np.full(values.shape+(3,),np.nan)
        for i,x in enumerate(self.x):
            for j,z in enumerate(self.z):
                hit,normal,*_=bvh.ray_cast((float(x),2,float(z)),(0,-1,0),3)
                if hit is not None:
                    r=abs(x-(low[0]+high[0])*.5)
                    vent=(r<.20 and -1.79<z<-1.675) or (.425<r<.655 and -1.66<z<-1.47)
                    if not vent:
                        values[i,j]=hit.y
                        normals[i,j]=normal if normal.y>0 else -normal
        measured=np.isfinite(values)
        # Interpolate only source vent holes and the outside bounding rectangle.
        # Measured factory heights, including the flat central plateau and its
        # tapered shoulders, are retained instead of replacing them by a dome.
        along_x=fill_rows(values.copy(),0)
        along_z=fill_rows(values.copy(),1)
        filled=np.where(measured,values,(along_x+along_z)*.5)
        for _ in range(300):
            padded=np.pad(filled,1,mode='edge')
            mean=(padded[:-2,1:-1]+padded[2:,1:-1]+padded[1:-1,:-2]+padded[1:-1,2:])*.25
            updated=np.where(measured,values,mean)
            delta=np.max(abs(updated-filled));filled=updated
            if delta<1e-7:break
        self.grid=SurfaceGrid(self.x,self.z,filled)
        # Sample the source tangents themselves. Differentiating extrapolated
        # heights at the concave cowl/bounding rectangle creates false creases.
        # A narrow fairing of the dense source normals retains factory folds
        # while removing transfer/interpolation spikes on reduced triangles.
        self.normal_grids=[]
        for axis in range(3):
            field=fill_rows(normals[:,:,axis].copy(),1)
            for _ in range(2):
                padded=np.pad(field,((1,1),(1,1)),mode='edge')
                field=sum(weight*padded[a:a+len(self.x),b:b+len(self.z)] for a,b,weight in
                          [(0,0,1/16),(0,1,2/16),(0,2,1/16),(1,0,2/16),(1,1,4/16),(1,2,2/16),(2,0,1/16),(2,1,2/16),(2,2,1/16)])
            self.normal_grids.append(SurfaceGrid(self.x,self.z,field))
        self.stats={'measured_grid_points':int(measured.sum()),'total_grid_points':int(measured.size),
                    'method':'measured source hood; masked vent interpolation; cubic sampling'}

    def height(self,x,z):return self.grid.at(x,z)

    def normal(self,x,z):
        value=np.stack([grid.at(x,z) for grid in self.normal_grids],axis=-1)
        return value/np.linalg.norm(value,axis=-1,keepdims=True)

    def profile(self):
        return {'schema':'challenger-hood-profile-1','x':self.x.tolist(),'z':self.z.tolist(),
                'heights':np.round(self.grid.values,7).tolist()}


class PaneSurface:
    """One smooth tangent field per measured pane, with no nearest-pane seams."""
    def __init__(self,points):
        self.centre=points.mean(0)
        _,_,axes=np.linalg.svd(points-self.centre,full_matrices=False)
        if axes[-1]@(self.centre-np.array([0,.8,.25]))<0:axes[-1]*=-1
        self.axes=axes
        local=(points-self.centre)@axes.T
        u,v=local[:,0],local[:,1]
        design=np.stack([np.ones(len(u)),u,v,u*u,u*v,v*v],axis=-1)
        self.coefficients=np.linalg.lstsq(design,local[:,2],rcond=None)[0]

    def points(self,uv):
        u,v=uv[:,0],uv[:,1];c=self.coefficients
        height=c[0]+c[1]*u+c[2]*v+c[3]*u*u+c[4]*u*v+c[5]*v*v
        return self.centre+np.c_[u,v,height]@self.axes

    def normal(self,points):
        local=(points-self.centre)@self.axes.T
        u,v=local[:,0],local[:,1];c=self.coefficients
        normals=np.stack([-(c[1]+2*c[3]*u+c[4]*v),-(c[2]+c[4]*u+2*c[5]*v),np.ones(len(u))],axis=-1)@self.axes
        return normals/np.linalg.norm(normals,axis=-1,keepdims=True)


class FenderSurface:
    """One fair radial chart across both the top and outside of a front wing."""
    def __init__(self,bvh,sign,centre_x):
        self.sign=sign;self.cx=centre_x+sign*.65;self.cy=.70
        samples=[]
        for angle in np.linspace(.10,1.40,43):
            direction=np.array([sign*np.sin(angle),np.cos(angle),0.0])
            for z in np.linspace(-1.99,-.73,57):
                origin=np.array([self.cx,self.cy,z])+direction*2
                hit=bvh.ray_cast(origin.tolist(),(-direction).tolist(),2)[0]
                if hit is not None:samples.append([angle,z,np.dot(np.array(hit)-np.array([self.cx,self.cy,z]),direction)])
        samples=np.asarray(samples);u=(samples[:,0]-.75)/.70;v=(samples[:,1]+1.36)/.63
        design=np.polynomial.chebyshev.chebvander2d(u,v,[4,4]).reshape(len(u),-1)
        valid=np.ones(len(samples),dtype=bool)
        for _ in range(5):
            c=np.linalg.lstsq(design[valid],samples[valid,2],rcond=None)[0]
            valid=abs(design@c-samples[:,2])<.012
        assert valid.mean()>.75,'Fender fairing must retain the measured majority'
        self.coefficients=c.reshape(5,5)
        self.stats={'measured_points':len(samples),'accepted_points':int(valid.sum()),'accepted_max_error_metres':float(np.max(abs(design[valid]@c-samples[valid,2])))}

    def parameters(self,points):
        return np.arctan2((points[...,0]-self.cx)*self.sign,points[...,1]-self.cy),points[...,2]

    def radius(self,angle,z):
        return np.polynomial.chebyshev.chebval2d((angle-.75)/.70,(z+1.36)/.63,self.coefficients)

    def point(self,angle,z):
        radius=self.radius(angle,z)
        return np.stack([self.cx+self.sign*radius*np.sin(angle),self.cy+radius*np.cos(angle),z],axis=-1)

    def normal(self,angle,z):
        u=(angle-.75)/.70;v=(z+1.36)/.63;r=self.radius(angle,z)
        da=np.polynomial.chebyshev.chebval2d(u,v,np.polynomial.chebyshev.chebder(self.coefficients,axis=0))/.70
        dz=np.polynomial.chebyshev.chebval2d(u,v,np.polynomial.chebyshev.chebder(self.coefficients,axis=1))/.63
        ta=np.stack([self.sign*(da*np.sin(angle)+r*np.cos(angle)),da*np.cos(angle)-r*np.sin(angle),np.zeros_like(angle)],axis=-1)
        tz=np.stack([self.sign*dz*np.sin(angle),dz*np.cos(angle),np.ones_like(angle)],axis=-1)
        n=np.cross(tz,ta)*self.sign
        return n/np.linalg.norm(n,axis=-1,keepdims=True)


def _hull(points):
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


def _edge_distance(point,outline):
    delta=np.roll(outline,-1,axis=0)-outline
    t=np.clip(np.sum((point-outline)*delta,axis=1)/np.maximum(np.sum(delta*delta,axis=1),1e-18),0,1)
    return np.min(np.linalg.norm(point-outline-t[:,None]*delta,axis=1))


class PanelJoinFairing:
    """Fair complete painted joins in one chart, after component reduction.

    Each local radial chart includes both sides of the source component seam.
    Geometry and its analytic tangents use the same measured fit. The broad
    zero-slope blend rings end outside the owner's marked reflection defects.
    """
    def __init__(self,bvh,centre_x):
        self.centre_x=centre_x;self.cx=.35;self.cy=.40
        self.patches=[];self.stats=[]
        specifications=[
            ('front-corner',(.53,.66,1.06,1.22),(-1.98,-1.89,-1.49,-1.34)),
            ('front-door-join',(.55,.68,1.25,1.42),(-.98,-.80,-.48,-.30)),
            ('rear-shoulder',(.44,.55,1.00,1.19),(.32,.58,1.65,1.89)),
            ('rear-corner',(.57,.71,1.35,1.53),(1.71,1.90,2.075,2.15))]
        for name,ar,zr in specifications:
            samples=[]
            for angle in np.linspace(ar[0],ar[-1],45):
                direction=np.array([-np.sin(angle),np.cos(angle),0.])
                for z in np.linspace(zr[0],min(zr[-1],2.215),67):
                    origin=np.array([centre_x-self.cx,self.cy,z])
                    hit,normal,*_=bvh.ray_cast((origin+direction*2).tolist(),(-direction).tolist(),2)
                    if hit is not None and np.dot(np.asarray(normal),direction)>.15:
                        radius=np.dot(np.asarray(hit)-origin,direction)
                        if .30<radius<1.10:samples.append([angle,z,radius])
            samples=np.asarray(samples)
            ac=(ar[0]+ar[-1])*.5;asc=(ar[-1]-ar[0])*.5
            zc=(zr[0]+zr[-1])*.5;zsc=(zr[-1]-zr[0])*.5
            u=(samples[:,0]-ac)/asc;v=(samples[:,1]-zc)/zsc
            degree=[3,3] if name=='front-corner' else [4,5]
            design=np.polynomial.chebyshev.chebvander2d(u,v,degree).reshape(len(u),-1)
            weights=np.ones(len(u))
            for _ in range(8):
                c=np.linalg.lstsq(design*weights[:,None],samples[:,2]*weights,rcond=None)[0]
                error=abs(design@c-samples[:,2]);weights=np.sqrt(np.minimum(1,.008/np.maximum(error,1e-9)))
            self.patches.append((ar,zr,ac,asc,zc,zsc,c.reshape(degree[0]+1,degree[1]+1)))
            self.stats.append({'name':name,'samples':len(u),'median_error_mm':float(np.median(error)*1000),
                               'p95_error_mm':float(np.percentile(error,95)*1000)})

    @staticmethod
    def ramp(a,b,x):
        t=np.clip((x-a)/(b-a),0,1)
        return t*t*t*(10+t*(-15+6*t))

    def parameters(self,points):
        sign=np.sign(points[:,0]-self.centre_x)
        dx=abs(points[:,0]-self.centre_x)-self.cx;dy=points[:,1]-self.cy
        return sign,np.arctan2(dx,dy),np.hypot(dx,dy),points[:,2]

    def fit(self,angle,z):
        radius=np.zeros_like(angle);coverage=np.zeros_like(angle)
        for ar,zr,ac,asc,zc,zsc,c in self.patches:
            w=self.ramp(ar[0],ar[1],angle)*(1-self.ramp(ar[2],ar[3],angle))
            w*=self.ramp(zr[0],zr[1],z)*(1-self.ramp(zr[2],zr[3],z))
            r=np.polynomial.chebyshev.chebval2d(np.clip((angle-ac)/asc,-1,1),np.clip((z-zc)/zsc,-1,1),c)
            radius=radius*(1-w)+r*w;coverage=coverage*(1-w)+w
        return radius/np.maximum(coverage,1e-12),coverage

    def apply(self,points,normals):
        sign,angle,radius,z=self.parameters(points)
        target,amount=self.fit(angle,z)
        amount*=1-self.ramp(.08,.15,abs(target-radius))
        result=points.copy();r=radius*(1-amount)+target*amount
        result[:,0]=self.centre_x+sign*(self.cx+r*np.sin(angle))
        result[:,1]=self.cy+r*np.cos(angle)
        e=.0001
        ra=(self.fit(angle+e,z)[0]-self.fit(angle-e,z)[0])/(2*e)
        rz=(self.fit(angle,z+e)[0]-self.fit(angle,z-e)[0])/(2*e)
        ta=np.stack([sign*(ra*np.sin(angle)+target*np.cos(angle)),ra*np.cos(angle)-target*np.sin(angle),np.zeros_like(angle)],axis=-1)
        tz=np.stack([sign*rz*np.sin(angle),rz*np.cos(angle),np.ones_like(angle)],axis=-1)
        n=np.cross(tz,ta)*sign[:,None];n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
        n=normals*(1-amount[:,None])+n*amount[:,None]
        n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
        return result,n

    def remesh_corners(self,points,loops,counts,normals,simple):
        """Replace folded corner seams with a single bounded regular skin.

        Clip the old triangles at the chart boundary, retaining every crossing
        as a constrained edge station. Thus the new sheet joins its neighbours
        exactly, while old component gutters inside the patch are bridged.
        """
        from mathutils import Vector
        from mathutils.geometry import delaunay_2d_cdt, tessellate_polygon
        faces=[];start=0
        for count in counts:
            count=int(count)
            polygon=[Vector(p) for p in points[loops[start:start+count]]]
            lookup={tuple(p):i for i,p in enumerate(polygon)}
            triangles=[[0,1,2]] if count==3 else [[int(p) if isinstance(p,int) else lookup[tuple(p)] for p in f] for f in tessellate_polygon([polygon])]
            for triangle in triangles:
                idx=start+np.array(triangle)
                p=points[loops[idx]];normal=np.cross(p[1]-p[0],p[2]-p[0]);length=np.linalg.norm(normal)
                if length<1e-12:continue
                n=normals[idx].copy();n[np.linalg.norm(n,axis=1)<1e-9]=normal/length
                faces.append(np.c_[p,n])
            start+=int(count)
        for sign in [-1,1]:
            for bounds in [(.69,1.00,-1.88,-1.50),(.55,.93,.82,1.62),(.73,1.32,1.92,2.075)]:
                amin,amax,zmin,zmax=bounds
                remaining=[];boundary=[]
                for face in faces:
                    if np.any(face[:,0]*sign<.65):remaining.append(face);continue
                    _,a,r,z=self.parameters(face[:,:3]);target,_=self.fit(a,z)
                    if a.max()<amin or a.min()>amax or z.max()<zmin or z.min()>zmax or np.max(abs(r-target))>.16:
                        remaining.append(face);continue
                    # Coordinates, normals and chart coordinates interpolate
                    # together at each clipping plane.
                    polygon=np.c_[face,a,z]
                    for axis,value,keep_greater in [(6,amin,True),(6,amax,False),(7,zmin,True),(7,zmax,False)]:
                        inside=[];outside=[]
                        for i,p in enumerate(polygon):
                            q=polygon[(i+1)%len(polygon)]
                            pin=(p[axis]>=value) if keep_greater else (p[axis]<=value)
                            qin=(q[axis]>=value) if keep_greater else (q[axis]<=value)
                            (inside if pin else outside).append(p)
                            if pin!=qin:
                                t=(value-p[axis])/(q[axis]-p[axis]);v=p+(q-p)*t
                                radius,_=self.fit(np.array([v[6]]),np.array([v[7]]))
                                v[0]=self.centre_x+sign*(self.cx+radius[0]*np.sin(v[6]))
                                v[1]=self.cy+radius[0]*np.cos(v[6])
                                inside.append(v);outside.append(v)
                        for i in range(1,len(outside)-1):remaining.append(np.array([outside[0][:6],outside[i][:6],outside[i+1][:6]]))
                        polygon=np.asarray(inside)
                        if len(polygon)<3:break
                    if len(polygon)>=3:
                        for p in polygon:
                            if min(abs(p[6]-amin),abs(p[6]-amax),abs(p[7]-zmin),abs(p[7]-zmax))<1e-7:boundary.append(p[6:8])
                # Keep actual crossings on all four edges. Independent source
                # seams inside the rectangle deliberately impose no boundary.
                boundary.extend([[amin,zmin],[amax,zmin],[amax,zmax],[amin,zmax]])
                boundary=np.unique(np.round(boundary,9),axis=0)
                centre=np.array([(amin+amax)*.5,(zmin+zmax)*.5])
                boundary=boundary[np.argsort(np.arctan2((boundary[:,1]-centre[1])/(zmax-zmin),(boundary[:,0]-centre[0])/(amax-amin)))]
                samples=boundary.tolist();constraints=[(i,(i+1)%len(boundary)) for i in range(len(boundary))]
                angular_step=(.022 if simple else .016) if zmin<0 else (.040 if simple else .030) if zmin<1 else (.026 if simple else .019)
                length_step=(.020 if simple else .017) if zmin<0 else (.050 if simple else .035) if zmin<1 else (.030 if simple else .022)
                for a in np.arange(amin+angular_step,amax,angular_step):
                    for z in np.arange(zmin+length_step,zmax,length_step):samples.append([a,z])
                uv,_,triangles,*_=delaunay_2d_cdt([Vector(p) for p in samples],constraints,[],0,1e-8,False)
                uv=np.asarray(uv);r,_=self.fit(uv[:,0],uv[:,1])
                p=np.c_[self.centre_x+sign*(self.cx+r*np.sin(uv[:,0])),self.cy+r*np.cos(uv[:,0]),uv[:,1]]
                n=np.c_[sign*np.sin(uv[:,0]),np.cos(uv[:,0]),np.zeros(len(p))]
                p,n=self.apply(p,n)
                for triangle in triangles:
                    f=np.array(triangle)
                    if np.cross(p[f[1]]-p[f[0]],p[f[2]]-p[f[0]])@n[f].mean(0)<0:f=f[::-1]
                    remaining.append(np.c_[p[f],n[f]])
                faces=remaining
        values=np.concatenate(faces)
        return values[:,:3],np.arange(len(values)),np.full(len(faces),3),values[:,3:]
