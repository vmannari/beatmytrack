"""Reference-guided Challenger character line and fuller front-quarter section.

The supplied photograph guides the intentional shoulder break. These stations
are authored model-space proportions, not measurements recovered from a single
perspective photograph. Existing seams and the retained bonnet remain separate.
"""
import numpy as np

NOSE_INPUT=np.array([1.72,1.80,1.88,1.96,2.04,2.1171])
NOSE_OUTPUT=np.array([1.72,1.90,2.080,2.145,2.205,2.2571])
NOSE_TANGENT=np.array([1.0,2.25,1.20,.80,.70,.65])
NOSE_PLAN_CENTRE=.005052088637516661


def _blend_gradient(start,end,value):
    t=np.clip((value-start)/(end-start),0,1)
    return t**3*(10+t*(-15+6*t)),30*t*t*(1-t)**2/(end-start)


def nose_corner_field(points):
    """A shallow downturned outer lip with a rounder front-corner return.

    Operates after the common plan taper. The bonnet and fitted-bonnet domain
    are inside the 700 mm onset; the central front edge is held in place.
    """
    x,y,z=np.asarray(points).T
    w,wx=_blend_gradient(.70,.85,abs(x-NOSE_PLAN_CENTRE))
    wx*=np.sign(x-NOSE_PLAN_CENTRE)
    down,down_d=_blend_gradient(1.82,2.18,-z)
    back,back_d=_blend_gradient(2.00,2.22,-z)
    height,height_y=_blend_gradient(.52,.72,y)
    cap,cap_y=_blend_gradient(.55,.72,y)
    q=np.array(points,copy=True)
    q[:,1]-=.018*w*down*height
    q[:,2]+=.016*w*back*cap
    jac=np.broadcast_to(np.eye(3),(len(q),3,3)).copy()
    jac[:,1,0]=-.018*wx*down*height
    jac[:,1,1]-=.018*w*down*height_y
    jac[:,1,2]=.018*w*down_d*height
    jac[:,2,0]=.016*wx*back*cap
    jac[:,2,1]=.016*w*back*cap_y
    jac[:,2,2]-=.016*w*back_d*cap
    return q,jac


def nose_corner_normals(points,normals):
    _,jac=nose_corner_field(points)
    result=np.array(normals,copy=True)
    active=np.any(jac!=np.eye(3),axis=(1,2))
    values=np.linalg.solve(np.swapaxes(jac[active],-1,-2),result[active])
    values/=np.maximum(np.linalg.norm(values,axis=1,keepdims=True),1e-12)
    result[active]=values
    return result


def nose_plan_scale(z):
    """Continue the wing's plan curve through the previously swollen corners.

    Apply to every joined exterior part after the longitudinal nose map. Both
    quintic blends have zero first/second derivatives at their endpoints.
    Wheel geometry and axle/contact locations are outside this operation.
    """
    depth=-np.asarray(z)
    scale=np.ones_like(depth,dtype=float);derivative=np.zeros_like(depth,dtype=float)
    for start,end,amount in [(1.53,1.73,.040),(1.65,2.22,.035)]:
        t=np.clip((depth-start)/(end-start),0,1)
        scale-=amount*t**3*(10+t*(-15+6*t))
        derivative+=amount*30*t*t*(1-t)**2/(end-start)
    return scale,derivative


def nose_plan_points(points):
    result=np.array(points,copy=True)
    scale,_=nose_plan_scale(result[:,2])
    result[:,0]=NOSE_PLAN_CENTRE+(result[:,0]-NOSE_PLAN_CENTRE)*scale
    return result


def nose_plan_normals(points,normals):
    scale,derivative=nose_plan_scale(points[:,2])
    result=np.array(normals,copy=True)
    result[:,0]/=scale
    result[:,2]-=derivative*(points[:,0]-NOSE_PLAN_CENTRE)*result[:,0]
    return result/np.maximum(np.linalg.norm(result,axis=1,keepdims=True),1e-12)


def nose_distance(distance,x):
    d,x=np.broadcast_arrays(distance,x)
    i=np.clip(np.searchsorted(NOSE_INPUT,d)-1,0,len(NOSE_INPUT)-2)
    length=NOSE_INPUT[i+1]-NOSE_INPUT[i];t=np.clip((d-NOSE_INPUT[i])/length,0,1)
    a,b=NOSE_OUTPUT[i],NOSE_OUTPUT[i+1];m,n=NOSE_TANGENT[i],NOSE_TANGENT[i+1]
    base=(2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*length*m+(-2*t**3+3*t*t)*b+(t**3-t*t)*length*n
    derivative=(6*t*t-6*t)*a/length+(3*t*t-4*t+1)*m+(-6*t*t+6*t)*b/length+(3*t*t-2*t)*n
    before=d<=NOSE_INPUT[0];after=d>=NOSE_INPUT[-1]
    base=np.where(before,d,np.where(after,NOSE_OUTPUT[-1]+(d-NOSE_INPUT[-1])*NOSE_TANGENT[-1],base))
    derivative=np.where(before,1,np.where(after,NOSE_TANGENT[-1],derivative))
    u=np.clip((abs(x)-.35)/.35,0,1);amount=.55*u**3*(10+u*(-15+6*u))
    dx=.55*30*u*u*(1-u)**2/.35*np.sign(x)
    span=NOSE_OUTPUT[-1]-NOSE_INPUT[0];s=np.clip((base-NOSE_INPUT[0])/span,0,1)
    active=~before&~after
    value=base+np.where(active,amount*span*s*(1-s),0)
    dz=derivative*np.where(active,1+amount*(1-2*s),1)
    shear=-np.where(active,dx*span*s*(1-s),0)
    return value,dz,shear


def nose_inverse(z,x):
    z,x=np.broadcast_arrays(z,x);low=np.full_like(z,1.72);high=np.full_like(z,2.1171)
    for _ in range(36):
        mid=(low+high)*.5;value=nose_distance(mid,x)[0]
        low=np.where(value< -z,mid,low);high=np.where(value>=-z,mid,high)
    distance=(low+high)*.5
    distance=np.where(-z<=1.72,-z,np.where(-z>=2.2571,2.1171+(-z-2.2571)/.65,distance))
    return -distance,nose_distance(distance,x)[1]


def nose_normals(points,normals):
    _,stretch,shear=nose_distance(-points[:,2],points[:,0])
    n=np.array(normals,copy=True);n[:,0]-=shear*n[:,2]/stretch;n[:,2]/=stretch
    return n/np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)


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
        # Keep the long body crease crisp, then roll its front termination
        # over a broader radius instead of ending in a knife-edged corner.
        front_roll=ramp(1.80,2.08,-z)
        fillet=self.FILLET+.012*front_roll
        sharp=xc+(above+below)*.5*d+(above-below)*.5*(np.sqrt(d*d+fillet**2)-self.FILLET)
        band=ramp(-.12,-.055,d)*(1-ramp(.055,.125,d))
        # The reference has a near-vertical outer nose wall below the crease,
        # rather than the old early inward turn below the front wing.
        # Let the rounded tangent continue below the corner before returning
        # to the upright wall. The original 12 mm wall blend would truncate
        # the broader fillet and leave a tight ridge at its lower edge.
        nose_band=nose*ramp(.34,.49,y)*(1-ramp(-.012-.028*front_roll,-.018*front_roll,d))
        wall_width=xc+.055*d
        target=base*(1-band)+sharp*band
        return target*(1-nose_band)+wall_width*nose_band

    def apply(self,points,normals,contour=False):
        canonical,shared=np.unique(np.round(points,6),axis=0,return_inverse=True)
        points=canonical[shared]
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
        # Keep frontal returns and the top lip in their own tangent domain.
        # Use a common normal at coincident positions so component boundaries
        # cannot receive different geometric displacements.
        common=np.zeros((int(shared.max())+1,3));np.add.at(common,shared,normals)
        common/=np.maximum(np.linalg.norm(common,axis=1,keepdims=True),1e-12)
        eligible*=ramp(.15,.55,common[shared,0]*sign)
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

    def mesh(self,points,faces,normals):
        """Insert shared, crease-aligned rows; never shade across a broad roll."""
        from mathutils.bvhtree import BVHTree
        self.outer=BVHTree.FromPolygons(points.tolist(),np.asarray(faces).tolist(),all_triangles=True)
        output=[];start=0;original=[]
        for face in faces:
            count=len(face);p=points[face];n=normals[start:start+count];start+=count
            original.extend([np.c_[p[[0,i,i+1]],n[[0,i,i+1]]] for i in range(1,count-1)])
        for triangle in original:
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
                            if da<=1e-10:lower.append(a)
                            if da>=-1e-10:upper.append(a)
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
