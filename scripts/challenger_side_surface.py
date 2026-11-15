"""One longitudinal chart for the Challenger's owner-marked outer side.

The factory bonnet, roof, pillars, openings and Y/Z silhouette are retained.
Only the side's width and its manufactured shoulder tangents are faired.
"""
import numpy as np


def unit(values):
    return values/np.maximum(np.linalg.norm(values,axis=-1,keepdims=True),1e-12)


def ramp(a,b,value):
    t=np.clip((value-a)/(b-a),0,1)
    return t**3*(10+t*(-15+6*t))


class Curve:
    """Natural cubic interpolation, with continuous first/second derivatives."""
    def __init__(self,x,y):
        self.x=np.asarray(x,dtype=float);self.y=np.asarray(y,dtype=float)
        h=np.diff(self.x);matrix=np.eye(len(x));rhs=np.zeros(len(x))
        for i in range(1,len(x)-1):
            matrix[i,i-1:i+2]=[h[i-1],2*(h[i-1]+h[i]),h[i]]
            rhs[i]=6*((self.y[i+1]-self.y[i])/h[i]-(self.y[i]-self.y[i-1])/h[i-1])
        self.second=np.linalg.solve(matrix,rhs)

    def __call__(self,value):
        q=np.asarray(value)
        i=np.clip(np.searchsorted(self.x,q)-1,0,len(self.x)-2)
        h=self.x[i+1]-self.x[i];a=(self.x[i+1]-q)/h;b=(q-self.x[i])/h
        return a*self.y[i]+b*self.y[i+1]+((a**3-a)*self.second[i]+(b**3-b)*self.second[i+1])*h*h/6


class SharedSide:
    Z=np.array([-2.18,-2.08,-1.78,-1.48,-1.10,-.50,.20,.60,1.0,1.35,1.75,2.0,2.14])
    CREASE_Z=[-2.26,-1.90,-1.40,-.70,.25,.55,.95,1.30,1.75,2.20]
    CREASE_Y=[.755,.765,.792,.810,.822,.840,.904,.930,.930,.897]

    def __init__(self,points,faces,hood_points=None,hood_faces=None):
        from mathutils.bvhtree import BVHTree
        self.crease=Curve(self.CREASE_Z,self.CREASE_Y)
        tree=BVHTree.FromPolygons(np.asarray(points).tolist(),np.asarray(faces).tolist(),all_triangles=True)
        self.hood_edge=None
        if hood_points is not None:
            hp=np.asarray(hood_points)[np.unique(hood_faces)]
            hp=hp[hp[:,0]>.40]
            zs=np.linspace(hp[:,2].min(),hp[:,2].max(),17);heights=[]
            for z in zs:
                band=hp[abs(hp[:,2]-z)<.035]
                if not len(band):band=hp[np.argsort(abs(hp[:,2]-z))[:40]]
                edge=band[band[:,0]>np.quantile(band[:,0],.95)]
                heights.append(float(np.max(edge[:,1])))
            self.hood_edge=Curve(zs,heights);self.hood_range=(zs[0],zs[-1])
        def ray(y,z):
            hit,*_=tree.ray_cast((2,float(y),float(z)),(-1,0,0),2)
            return float(hit.x) if hit is not None and .62<hit.x<.98 else np.nan
        widths=[];upper=[];floor_x=[];floor_y=[]
        for z in self.Z:
            c=float(self.crease(z));peak=[]
            for zz in np.linspace(max(-2.25,z-.035),min(2.19,z+.035),5):
                cc=float(self.crease(zz))
                peak.extend(ray(cc+d,zz) for d in np.linspace(-.14,.008,16))
            valid=np.asarray(peak);valid=valid[np.isfinite(valid)]
            assert len(valid),'Every shoulder station must be measured from the factory side: '+str(z)
            w=float(np.percentile(valid,90));widths.append(w)
            floor=[(float(y),ray(y,z)) for y in np.linspace(.29,.53,49)]
            floor=[(y,x) for y,x in floor if np.isfinite(x)]
            floor_y.append(floor[0][0] if floor else np.nan)
            floor_x.append(floor[0][1] if floor else np.nan)
            kk=[]
            for d in [.07,.10,.13]:
                x=ray(c+d,z)
                if np.isfinite(x):kk.append((w-.42*d-x)/(d*d))
            upper.append(float(np.clip(np.median(kk) if kk else 2,.01,10)))
        # A short regular control list describes broad panels, without copying
        # every source seam, recessed handle, fold or triangle into the chart.
        self.width_curve=Curve(self.Z,widths)
        known=np.isfinite(floor_x)
        floor_x=np.interp(self.Z,self.Z[known],np.asarray(floor_x)[known])
        floor_y=np.interp(self.Z,self.Z[known],np.asarray(floor_y)[known])
        self.floor_x=Curve(self.Z,floor_x);self.floor_y=Curve(self.Z,floor_y)
        self.k_curve=Curve(self.Z,np.log(upper))
        self.stats={'method':'one C2 longitudinal shoulder and regular crowned side section',
            'z':self.Z.tolist(),'widths':widths,'lower_section':'one cubic from measured sill to shoulder',
            'upper_quadratic':upper,'crease_z':self.CREASE_Z,'crease_y':self.CREASE_Y,
            'floor_widths':floor_x.tolist(),'floor_heights':floor_y.tolist(),
            'shoulder_radius_metres':.004}

    def width(self,y,z):
        y,z=np.broadcast_arrays(y,z);d=y-self.crease(z)
        radius=.004;s=np.sqrt(d*d+radius*radius)
        above=(s+d)*.5;below=(s-d)*.5;at_zero=radius*.5
        height=np.maximum(.2,self.crease(z)-self.floor_y(z))
        bend=(self.width_curve(z)-self.floor_x(z)-.06*height)/height**3
        return (self.width_curve(z)-.18*d-.24*(s-radius)
            -bend*(below**3-at_zero**3)
            -np.exp(self.k_curve(z))*(above**2-at_zero**2))

    def weights(self,p):
        d=p[:,1]-self.crease(p[:,2])
        w=ramp(.63,.74,abs(p[:,0]))*ramp(.27,.32,p[:,1])*(1-ramp(.10,.17,d))
        w*=1-(1-ramp(-2.20,-2.10,p[:,2]))*(1-ramp(.50,.66,p[:,1]))
        w*=1-ramp(.75,1.0,p[:,2])*ramp(.99,1.04,p[:,1])
        if self.hood_edge is not None:
            z0,z1=self.hood_range
            in_hood=ramp(z0-.04,z0+.01,p[:,2])*(1-ramp(z1-.02,z1+.04,p[:,2]))
            edge=self.hood_edge(p[:,2])
            w*=1-in_hood*ramp(edge-.07,edge-.01,p[:,1])
        return w

    def map(self,p):
        p=np.asarray(p);q=p.copy();w=self.weights(p)
        q[:,0]+=w*(np.sign(p[:,0])*self.width(p[:,1],p[:,2])-p[:,0])
        return q

    def normals(self,p,n):
        # Transform retained normals through the same map at transition rings.
        # Where the exterior is fully on the chart it has one exact tangent,
        # independent of component identity and old hidden return normals.
        e=.000025;partials=[]
        for axis in range(3):
            delta=np.zeros(3);delta[axis]=e
            partials.append((self.map(p+delta)[:,0]-self.map(p-delta)[:,0])/(2*e))
        a,b,c=partials;amount=self.weights(p)
        dy=(self.width(p[:,1]+e,p[:,2])-self.width(p[:,1]-e,p[:,2]))/(2*e)
        dz=(self.width(p[:,1],p[:,2]+e)-self.width(p[:,1],p[:,2]-e))/(2*e)
        chart=unit(np.c_[np.sign(p[:,0]),-dy,-dz])
        safe=np.where(abs(a)>.0001,a,np.where(a<0,-.0001,.0001))
        transformed=unit(np.c_[n[:,0]/safe,n[:,1]-b*n[:,0]/safe,n[:,2]-c*n[:,0]/safe])
        choose=amount>.9999
        transformed[choose]=chart[choose]
        transformed[amount<1e-10]=n[amount<1e-10]
        return unit(transformed)

    def apply(self,values):
        values=np.asarray(values).reshape(-1,3,6);v=values.reshape(-1,6)
        q=self.map(v[:,:3]);n=self.normals(v[:,:3],v[:,3:])
        out=np.c_[q,n].reshape(-1,3,6)
        cross=np.cross(out[:,1,:3]-out[:,0,:3],out[:,2,:3]-out[:,0,:3])
        side=np.sign(out[:,:,0].mean(1));full=self.weights(v[:,:3]).reshape(-1,3).min(1)>.9999
        # Source returns projected onto the outer sheet have no exposed role.
        # Retain only its outward-facing triangles in that complete chart.
        keep=(~full)|(cross[:,0]*side>1e-11)
        keep&=np.linalg.norm(cross,axis=1)>1e-11
        # Transition-ring returns retain their factory topology. Orient their
        # transformed corner shading in the actual new triangle hemisphere.
        direction=unit(cross)
        changed=self.weights(v[:,:3]).reshape(-1,3).max(1)>1e-10
        inward=(np.sum(out[:,:,3:]*direction[:,None,:],axis=2)<0)&changed[:,None]
        out[:,:,3:][inward]*=-1
        return out[keep],{'before_triangles':len(values),'after_triangles':int(keep.sum()),
            'return_normal_orientation_repairs':int(np.sum(inward[keep])),
            'maximum_displacement_mm':float(np.linalg.norm(q-v[:,:3],axis=1).max())*1000,
            'p95_displacement_mm':float(np.percentile(np.linalg.norm(q-v[:,:3],axis=1),95))*1000}
