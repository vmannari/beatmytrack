"""Manufactured, symmetric fascia and bonnet guides for offline conversion.

Applied after reduction. The final paint and glass use reflected topology,
while fuel markings keep their intentional left-side placement.
"""
import math
import numpy as np
from challenger_reference_geometry import (curve, nose_distance,
    nose_plan_points, nose_plan_normals, nose_normals,
    nose_corner_field, nose_corner_normals)


def ramp(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t**3*(10+t*(-15+6*t))


def world(points,normals=None):
    p=np.array(points,copy=True)
    if normals is not None:n=nose_normals(p,normals)
    p[:,2]=-nose_distance(-p[:,2],p[:,0])[0]
    if normals is not None:n=nose_plan_normals(p,n)
    p=nose_plan_points(p)
    if normals is not None:n=nose_corner_normals(p,n)
    p=nose_corner_field(p)[0]
    return p if normals is None else (p,n)


class CleanHood:
    def __init__(self):
        self.x=np.linspace(-.80,.80,129)
        self.z=np.linspace(-1.975,-.765,113)
        self.stats={'method':'symmetric bounded bonnet; one C2 power bulge and clean curved edges'}

    @staticmethod
    def width(v):return .735+.020*np.clip(v,0,1)+.045*np.sin(np.pi*np.clip(v,0,1))

    @staticmethod
    def front(u):return -2.165+.025*u*u

    @staticmethod
    def rear(u):return -.990+.225*u*u

    def uv(self,x,z):
        x,z=np.broadcast_arrays(x,z)
        v=np.clip((z+2.165)/1.175,0,1)
        for _ in range(10):
            u=x/self.width(v)
            v=np.clip((z-self.front(u))/(self.rear(u)-self.front(u)),0,1)
        return x/self.width(v),v

    def points(self,u,v):
        u,v=np.broadcast_arrays(u,v)
        x=u*self.width(v);z=self.front(u)*(1-v)+self.rear(u)*v
        return np.stack([x,self.height(x,z),z],axis=-1)

    def height(self,x,z):
        u,v=self.uv(x,z);u=np.clip(u,-1.08,1.08)
        front=.855-.020*u*u;rear=1.005-.030*u*u
        crown=.070*ramp(0,.30,v)*(1-ramp(.50,1,v))*np.maximum(0,1-u*u)**3
        return front*(1-v)+rear*v+crown

    def normal(self,x,z):
        x,z=np.broadcast_arrays(x,z);e=.00005
        dx=(self.height(x+e,z)-self.height(x-e,z))/(2*e)
        dz=(self.height(x,z+e)-self.height(x,z-e))/(2*e)
        n=np.stack([-dx,np.ones_like(dx),-dz],axis=-1)
        return n/np.linalg.norm(n,axis=-1,keepdims=True)

    def boundary(self):
        ru,rv=.020,.015;corners=[]
        for cu,cv,start in [(1-ru,1-rv,0),(-1+ru,1-rv,90),(-1+ru,rv,180),(1-ru,rv,270)]:
            for a in np.linspace(start,start+90,9):
                theta=math.radians(a);corners.append([cu+ru*math.cos(theta),cv+rv*math.sin(theta)])
        loop=[]
        for a,b in zip(corners,np.roll(corners,-1,axis=0)):
            a=np.asarray(a);b=np.asarray(b)
            count=max(1,math.ceil(np.linalg.norm((b-a)*np.array([.75,1.2]))/.015))
            for t in np.linspace(0,1,count,endpoint=False):loop.append(a+(b-a)*t)
        uv=np.asarray(loop)
        return self.points(uv[:,0],uv[:,1])

    def contains(self,x,z):
        u,v=self.uv(x,z)
        return (abs(u)<=1.00001)&(z>=self.front(u)-1e-7)&(z<=self.rear(u)+1e-7)

    def profile(self):
        x,z=np.meshgrid(self.x,self.z,indexing='ij')
        mapped=world(np.c_[x.ravel(),np.zeros(x.size),z.ravel()])
        heights=self.height(mapped[:,0],mapped[:,2]).reshape(x.shape)
        return {'schema':'challenger-hood-profile-1','x':self.x.tolist(),'z':self.z.tolist(),
                'heights':np.round(heights,7).tolist()}


def rear_surface(x,y):
    x,y=np.broadcast_arrays(x,y)
    width=curve(y,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84])
    reach=2.205+.006*(1-((y-.63)/.4)**2)-1.78
    return 1.78+reach*np.maximum(.0001,1-(abs(x)/width)**8)**.125


def rounded_door(path):
    """Circular corner returns; retain the long straight bottom edge."""
    result=[]
    for i,b in enumerate(path):
        a,c=path[i-1],path[(i+1)%len(path)]
        va=a-b;vc=c-b;la=np.linalg.norm(va);lc=np.linalg.norm(vc)
        va/=la;vc/=lc;angle=math.acos(np.clip(va@vc,-1,1))
        if angle>math.radians(175):result.append(b);continue
        radius=.045 if b[0]<.52 else .018
        distance=min(radius/max(math.tan(angle/2),1e-6),la*.35,lc*.35)
        actual=distance*math.tan(angle/2)
        center=b+(va+vc)/np.linalg.norm(va+vc)*actual/max(math.sin(angle/2),1e-6)
        p=b+va*distance;q=b+vc*distance
        aa=math.atan2(*(p-center)[::-1]);bb=math.atan2(*(q-center)[::-1])
        delta=(bb-aa+math.pi)%(2*math.pi)-math.pi
        for t in np.linspace(0,1,max(3,math.ceil(abs(delta)*actual/.006))):
            theta=aa+delta*t;result.append(center+actual*np.array([math.cos(theta),math.sin(theta)]))
    return np.asarray(result)


def _read(obj):
    mesh=obj.data;mesh.calc_loop_triangles()
    p=np.asarray([v.co[:] for v in mesh.vertices])[:,[0,2,1]]*np.array([1,1,-1])
    faces=np.asarray([t.vertices[:] for t in mesh.loop_triangles])
    ns=np.asarray([mesh.corner_normals[i].vector[:] for t in mesh.loop_triangles for i in t.loops])
    return p,faces,ns[:,[0,2,1]]*np.array([1,1,-1])


def _write(obj,records):
    import bpy
    records=np.asarray(records).reshape(-1,3,6)
    cross=np.cross(records[:,1,:3]-records[:,0,:3],records[:,2,:3]-records[:,0,:3])
    records=records[np.linalg.norm(cross,axis=1)>1e-11]
    values=records.reshape(-1,6);values[:,3:]/=np.maximum(np.linalg.norm(values[:,3:],axis=1,keepdims=True),1e-12)
    packed=np.round(values,7);unique,indices=np.unique(packed,axis=0,return_inverse=True)
    assert np.isfinite(unique).all(),f'Nonfinite corrected mesh: {obj.name}'
    faces=indices.reshape(-1,3)
    cross=np.cross(unique[faces[:,1],:3]-unique[faces[:,0],:3],unique[faces[:,2],:3]-unique[faces[:,0],:3])
    faces=faces[np.linalg.norm(cross,axis=1)>1e-11]
    data=bpy.data.meshes.new(obj.name+'Clean')
    data.from_pydata((unique[:,:3][:,[0,2,1]]*np.array([1,-1,1])).tolist(),[],faces.tolist())
    data.validate(clean_customdata=False)
    for material in obj.data.materials:data.materials.append(material)
    data.update()
    for polygon in data.polygons:polygon.use_smooth=True
    normals=unique[:,3:][:,[0,2,1]]*np.array([1,-1,1])
    data.normals_split_custom_set([normals[l.vertex_index] for l in data.loops])
    obj.data=data


def _positive(triangles):
    output=[]
    for tri in triangles:
        polygon=[]
        for i,a in enumerate(tri):
            b=tri[(i+1)%3]
            if a[0]>=-1e-8:polygon.append(a.copy())
            if (a[0]<0 and b[0]>0) or (a[0]>0 and b[0]<0):
                p=a+(b-a)*(-a[0]/(b[0]-a[0]));p[0]=0;polygon.append(p)
        for i in range(1,len(polygon)-1):output.append(np.asarray([polygon[0],polygon[i],polygon[i+1]]))
    return np.asarray(output).reshape(-1,3,6)


def _symmetric(records):
    right=_positive(records)
    axis=abs(right[:,:,0])<1e-7
    right[:,:,0][axis]=0;right[:,:,3][axis]=0
    left=right[:,::-1,:].copy();left[:,:,0]*=-1;left[:,:,3]*=-1
    return np.concatenate([right,left])


def _paint_edges(p,faces,front,upper):
    from mathutils.bvhtree import BVHTree
    bvh=BVHTree.FromPolygons(p.tolist(),faces.tolist(),all_triangles=True)
    xs=np.linspace(0,.78,157);edge=[]
    ys=np.linspace(.709,.89 if upper else .53,321) if front else np.linspace(.854,1.02 if upper else .69,321)
    for x in xs:
        found=None
        for y in ys:
            hit,*_=bvh.ray_cast((float(x),float(y),-3 if front else 3),(0,0,1 if front else -1),1.05)
            if hit is not None and (hit.z< -2.07 if front else hit.z>2.03):found=float(y);break
        edge.append(np.nan if found is None else found)
    edge=np.asarray(edge);valid=np.flatnonzero(np.isfinite(edge))
    assert len(valid)>len(xs)*.70,'Fascia aperture edge must be measured before correcting it'
    edge=np.interp(xs,xs[valid],edge[valid])
    return xs,edge


def _corner(x,onset=.715,radius=.045):
    d=np.clip(abs(x)-onset,0,radius)
    return radius-np.sqrt(np.maximum(0,radius*radius-d*d))


def correct_paint(obj,hood):
    p,f,n=_read(obj);original=p.copy();x,y,z=p.T
    vertex_n=np.zeros_like(p);np.add.at(vertex_n,f.reshape(-1),n)
    vertex_n/=np.maximum(np.linalg.norm(vertex_n,axis=1,keepdims=True),1e-12)
    edges={}
    for name,front,upper in [('front_lower',True,False),('front_upper',True,True),('rear_lower',False,False)]:
        edges[name]=_paint_edges(p,f,front,upper)
    # Correct the aperture outline by a common column displacement. Thickness
    # and neighbouring triangles move together; no stacked cover strip is added.
    for name,(xs,values) in edges.items():
        old=np.interp(abs(x),xs,values)
        if name=='front_lower':target=.616+.004*(x/.78)**6+_corner(x)
        elif name=='front_upper':target=.804-.010*(x/.78)**6-_corner(x)
        else:target=.762+_corner(x,.755,.055)
        weight=(1-ramp(.012,.060,abs(y-old)))*(1-ramp(.74,.81,abs(x)))
        weight*=ramp(2.02,2.11,-z) if name.startswith('front') else ramp(1.99,2.08,z)
        p[:,1]+=(target-old)*weight
    x,y,z=p.T
    front=ramp(2.035,2.11,-z)*ramp(.27,.32,y)*(1-ramp(.78,.805,y))
    lower=.616+.004*(x/.78)**6+_corner(x);upper=.804-.010*(x/.78)**6-_corner(x)
    in_grille=(y>lower+.001)&(y<upper-.001)&(abs(x)<.76)
    front*=~in_grille
    target=-2.218+.022*(x/.80)**2+.010*((y-.60)/.30)**2
    p[:,2]+=(target-z)*front
    # A single lower-side profile removes the triangular door-corner dent.
    x,y,z=p.T;sign=np.sign(x)
    door=ramp(-2.10,-1.94,z)*(1-ramp(1.73,2.02,z))*ramp(.27,.29,y)*(1-ramp(.78,.88,y))*ramp(.62,.72,abs(x))
    width=curve(y,[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925])-.007*z
    p[:,0]+=(sign*width-x)*door
    # Rear fascia has a true even transverse curve instead of transferred
    # normals from unrelated corner patches. Keep hidden aperture returns back.
    x,y,z=p.T
    rear=ramp(1.68,1.95,z)*ramp(.27,.33,y)*(1-ramp(.95,1.04,y))
    in_rear=(y>.773)&(y<.935)&(abs(x)<.77)
    rear*=~in_rear
    rear_width=curve(y,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84])
    rear_reach=2.205+.006*(1-((y-.63)/.4)**2)-1.78
    gauge=(abs(x/rear_width)**8+np.maximum(0,(z-1.78)/rear_reach)**8)**.125
    factor=1/np.maximum(gauge,1e-8)
    p[:,0]+=(x*factor-x)*rear
    p[:,2]+=(1.78+(z-1.78)*factor-z)*rear
    # A shared top guide carries the new bonnet tangent across the fenders
    # and the short nose bridge, rather than retaining the old folded patches.
    hy=hood.height(p[:,0],p[:,2])
    top=ramp(.78,.84,p[:,1])*(1-ramp(1.05,1.10,p[:,1]))*(1-ramp(-.86,-.74,p[:,2]))*(1-ramp(.90,.96,abs(p[:,0])))
    p[:,1]+=(hy-p[:,1])*top
    under=hood.contains(p[:,0],p[:,2])&(p[:,1]<1.07)&(abs(p[:,1]-hy)<.12)
    p[under,1]=np.minimum(p[under,1],hy[under]-.003)
    # Assign tangents from those same guides, after all positional corrections.
    ids=f.reshape(-1);points=p[ids];weights_front=front[ids];weights_rear=rear[ids];weights_door=door[ids]
    xx,yy,zz=points.T
    nf=np.c_[.044*xx/.80**2,.020*(yy-.60)/.30**2,-np.ones(len(xx))];nf/=np.linalg.norm(nf,axis=1,keepdims=True)
    e=.00005
    ww=curve(yy,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84])
    wy=(curve(yy+e,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84])-curve(yy-e,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84]))/(2*e)
    reach=2.205+.006*(1-((yy-.63)/.4)**2)-1.78
    ly=-.012*(yy-.63)/.4**2
    nr=np.c_[xx**7/ww**8,-(xx/ww)**8*wy/ww-np.maximum(0,(zz-1.78)/reach)**8*ly/reach,np.maximum(0,zz-1.78)**7/reach**8]
    nr/=np.maximum(np.linalg.norm(nr,axis=1,keepdims=True),1e-12)
    dy=(curve(yy+e,[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925])-curve(yy-e,[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925]))/(2*e)
    nd=np.c_[np.sign(xx),-dy,np.full(len(xx),.007)];nd/=np.linalg.norm(nd,axis=1,keepdims=True)
    for guide,w in [(nf,weights_front),(nr,weights_rear),(nd,weights_door)]:n=n*(1-w[:,None])+guide*w[:,None]
    top_normal=hood.normal(p[:,0],p[:,2])
    n=n*(1-top[ids,None])+top_normal[ids]*top[ids,None]
    n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
    records=np.c_[p[ids],n].reshape(-1,3,6)
    _write(obj,_symmetric(records))
    return {'max_guide_displacement_metres':float(np.max(np.linalg.norm(p-original,axis=1))),
            'front_aperture_samples':len(edges['front_lower'][0]),'reflected_paint_topology':True}


def hood_mesh(obj,hood,lattice,simple,vent_paths):
    boundary=hood.boundary()[:,[0,2]]
    xy,faces=lattice(boundary,.035 if simple else .024,holes=vent_paths)
    points=np.c_[xy[:,0],hood.height(xy[:,0],xy[:,1]),xy[:,1]]
    p=points;n=hood.normal(xy[:,0],xy[:,1])
    f=np.asarray(faces)
    orient=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])@np.array([0,1,0])
    f[orient<0]=f[orient<0][:,::-1]
    _write(obj,_symmetric(np.c_[p[f].reshape(-1,3),n[f].reshape(-1,3)].reshape(-1,3,6)))


def rebuild_hood(exports,hood,lattice,simple):
    import challenger_detail_geometry as detail
    paint=next(o for o in exports if o.name=='hood__paint')
    dark=next(o for o in exports if o.name=='hood__dark')
    paths=detail.vent_paths()
    hood_mesh(paint,hood,lattice,simple,paths)
    p,f,n=_read(paint)
    records={'paint':[np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)],'dark':[]}
    def emit(name,vertices,faces,role,group):
        p=np.asarray(vertices);f=np.asarray(faces)
        if not len(f):return
        normal=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])
        reverse=normal[:,1]<0;f[reverse]=f[reverse][:,::-1];normal[reverse]*=-1
        normal/=np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-12)
        points=p[f].reshape(-1,3);ns=np.repeat(normal,3,axis=0)
        records['paint' if role=='paint' else 'dark'].append(np.c_[points,ns].reshape(-1,3,6))
    detail.vents(emit,paths,hood.height)
    boundary=hood.boundary();normal=hood.normal(boundary[:,0],boundary[:,2])
    outer=boundary
    for i in range(len(outer)):
        j=(i+1)%len(outer)
        a,b=outer[i],outer[j];c=b-[0,.008,0];d=a-[0,.008,0]
        for ids in [(0,1,2),(0,2,3)]:
            records['paint'].append(np.c_[np.asarray([a,b,c,d])[list(ids)],np.asarray([normal[i],normal[j],normal[j],normal[i]])[list(ids)]][None])
    _write(paint,np.concatenate(records['paint']))
    _write(dark,np.concatenate(records['dark']))


def seat_rear_details(obj):
    group,role=obj.name.split('__')
    offsets={'dark':.001,'accent':.002,'lens_red':.004,'reverse':.0085,'red':.006}
    if group.startswith('tail_'):offset=.008
    elif group=='body' and role in offsets:offset=offsets[role]
    else:return
    low,high=(.45,.65) if group=='body' and role=='red' else (.75,.96)
    p,f,n=_read(obj)
    triangles=np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)
    refined=[]
    for triangle in triangles:
        if triangle[:,2].min()<1.99 or triangle[:,1].max()<low or triangle[:,1].min()>high:
            refined.append(triangle);continue
        polygons=[triangle]
        for x in np.arange(-.84,.85,.040):
            pieces=[]
            for polygon in polygons:
                if polygon[:,0].min()>=x-1e-9 or polygon[:,0].max()<=x+1e-9:
                    pieces.append(polygon);continue
                left=[];right=[]
                for i,v in enumerate(polygon):
                    q=polygon[(i+1)%len(polygon)];da=v[0]-x;db=q[0]-x
                    if da<=0:left.append(v)
                    if da>=0:right.append(v)
                    if da*db<0:
                        r=v+(q-v)*(da/(da-db));r[0]=x;left.append(r);right.append(r)
                for piece in [left,right]:
                    if len(piece)>=3:pieces.append(np.asarray(piece))
            polygons=pieces
        for polygon in polygons:
            for i in range(1,len(polygon)-1):refined.append(polygon[[0,i,i+1]])
    values=np.asarray(refined).reshape(-1,6);p=values[:,:3].copy();n=values[:,3:].copy();f=np.arange(len(p)).reshape(-1,3)
    sel=(p[:,2]>1.99)&(p[:,1]>low)&(p[:,1]<high)&(abs(p[:,0])<.85)
    p[sel,2]=rear_surface(p[sel,0],p[sel,1])+offset
    ids=f.reshape(-1);chosen=sel[ids];x,y=p[ids,0],p[ids,1]
    e=.00005
    dx=(rear_surface(x+e,y)-rear_surface(x-e,y))/(2*e)
    dy=(rear_surface(x,y+e)-rear_surface(x,y-e))/(2*e)
    guide=np.c_[-dx,-dy,np.ones(len(x))];guide/=np.linalg.norm(guide,axis=1,keepdims=True)
    n[chosen]=guide[chosen]
    _write(obj,np.c_[p[ids],n].reshape(-1,3,6))


def rebuild_contours(exports,outline,hood):
    from mathutils.bvhtree import BVHTree
    paint=next(o for o in exports if o.name=='body__paint')
    contour=next(o for o in exports if o.name=='body__contour')
    p,f,_=_read(paint);bvh=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    records=[]
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
            assert hit is not None and hit.x*sign>.6,'Contour must seat on its own side'
            slope=np.clip(-np.asarray(normal)[1:]/max(abs(normal.x),.2)*sign,-1.5,1.5)
            row=[]
            for s in [-1,1]:
                delta=across*width*.5*s;y,z=point+delta
                row.append([hit.x+float(slope@delta)+sign*.0018,y,z,sign,0,0])
            rows.append(row)
        for i,a in enumerate(rows):
            b=rows[(i+1)%len(rows)]
            records.extend([[a[0],b[0],b[1]],[a[0],b[1],a[1]]])
    for sign in [-1,1]:
        ribbon(rounded_door(outline),.0025,sign)
        t=np.linspace(0,2*math.pi,64,endpoint=False)
        ribbon(np.c_[.905+.014*np.sin(t),.390+.066*np.cos(t)],.0025,sign)
    ribbon(np.c_[.99+.059*np.sin(t),1.31+.059*np.cos(t)],.0025,-1)
    boundary=hood.boundary()
    tangent=np.roll(boundary,-1,axis=0)-np.roll(boundary,1,axis=0)
    across=np.c_[tangent[:,2],np.zeros(len(tangent)),-tangent[:,0]]
    across/=np.linalg.norm(across,axis=1,keepdims=True)
    rows=[]
    for side in [-1,1]:
        q=boundary-across*(.0025+side*.00125)
        q[:,1]=hood.height(q[:,0],q[:,2])+.0018
        rows.append(q)
    for i in range(len(boundary)):
        j=(i+1)%len(boundary)
        q=np.array([rows[0][i],rows[1][i],rows[0][j],rows[1][j]])
        for ids in [(0,3,1),(0,2,3)]:
            p=q[list(ids)];records.append(np.c_[p,hood.normal(p[:,0],p[:,2])])
    _write(contour,records)


def mirror_object(obj):
    p,f,n=_read(obj)
    _write(obj,_symmetric(np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)))


def _subtract(triangle,polygon,axes):
    """Subtract a convex chart cell, retaining interpolated neighbouring skin."""
    polygon=np.asarray(polygon)
    area=np.sum(polygon[:,0]*np.roll(polygon[:,1],-1)-polygon[:,1]*np.roll(polygon[:,0],-1))
    if area<0:polygon=polygon[::-1]
    inside=np.asarray(triangle);outside=[]
    for a,b in zip(polygon,np.roll(polygon,-1,axis=0)):
        keep=[];reject=[];edge=b-a
        for i,p in enumerate(inside):
            q=inside[(i+1)%len(inside)]
            pp=p[list(axes)]-a;qq=q[list(axes)]-a
            dp=edge[0]*pp[1]-edge[1]*pp[0];dq=edge[0]*qq[1]-edge[1]*qq[0]
            (keep if dp>=-1e-10 else reject).append(p)
            if (dp<0 and dq>0) or (dp>0 and dq<0):
                v=p+(q-p)*(dp/(dp-dq));keep.append(v);reject.append(v)
        for i in range(1,len(reject)-1):outside.append(np.asarray([reject[0],reject[i],reject[i+1]]))
        inside=np.asarray(keep)
        if len(inside)<3:break
    if len(inside)<3:return [triangle]
    projected=inside[:,list(axes)]
    overlap=abs(np.sum(projected[:,0]*np.roll(projected[:,1],-1)-projected[:,1]*np.roll(projected[:,0],-1)))
    return outside if overlap>1e-12 else [triangle]


def _subtract_box(triangle,bounds):
    inside=np.asarray(triangle);outside=[]
    for axis,lower,upper in bounds:
        for bound,sign in [(lower,1),(upper,-1)]:
            keep=[];reject=[]
            for i,p in enumerate(inside):
                q=inside[(i+1)%len(inside)];a=(p[axis]-bound)*sign;b=(q[axis]-bound)*sign
                (keep if a>=-1e-10 else reject).append(p)
                if a*b<0:
                    v=p+(q-p)*(a/(a-b));keep.append(v);reject.append(v)
            for i in range(1,len(reject)-1):outside.append(np.array([reject[0],reject[i],reject[i+1]]))
            inside=np.asarray(keep)
            if len(inside)<3:return [triangle]
    area=sum(np.linalg.norm(np.cross(inside[i,:3]-inside[0,:3],inside[i+1,:3]-inside[0,:3])) for i in range(1,len(inside)-1))
    return outside if area>1e-11 else [triangle]


def nose_bridge(obj,hood):
    """One regular top skin closes the old bonnet cut at the grille corners."""
    p,f,n=_read(obj);records=np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)
    def lower(x):return .804-.010*(x/.78)**6-_corner(x)
    kept=[]
    for tri in records:
        ext=np.c_[tri,tri[:,1]-lower(tri[:,0])]
        for piece in _subtract_box(ext,[(0,-.84,.84),(2,-2.28,-2.075),(6,0,1)]):
            on=abs(piece[:,6])<1e-8
            piece[on,1]=lower(piece[on,0])
            kept.append(piece[:,:6])
    xs=np.linspace(-.84,.84,85);vs=np.linspace(0,1,9)
    points=[];normals=[]
    for v in vs:
        front=-2.255+.065*(xs/.84)**8
        z=(front+.012)*(1-v)-2.075*v
        y=hood.height(xs,z)-.003*hood.contains(xs,z)
        points.extend(np.c_[xs,y,z]);normals.extend(hood.normal(xs,z))
    points=np.asarray(points);normals=np.asarray(normals)
    for j in range(len(vs)-1):
        for i in range(len(xs)-1):
            a=j*len(xs)+i;b=a+1;c=b+len(xs);d=a+len(xs)
            for ids in [(a,c,b),(a,d,c)]:kept.append(np.c_[points[list(ids)],normals[list(ids)]])
    front=-2.255+.065*(xs/.84)**8
    crown=hood.height(xs,front+.012)
    lip=[];lip_ns=[]
    for theta in np.linspace(0,math.pi/2,9):
        z=front+.012*(1-math.cos(theta));y=lower(xs)+(crown-lower(xs))*math.sin(theta)
        lip.append(np.c_[xs,y,z])
        normal=hood.normal(xs,z)*math.sin(theta)+np.c_[np.zeros(len(xs)),np.zeros(len(xs)),-np.ones(len(xs))]*math.cos(theta)
        lip_ns.append(normal/np.linalg.norm(normal,axis=1,keepdims=True))
    for j in range(len(lip)-1):
        for i in range(len(xs)-1):
            for ids in [[(j,i),(j,i+1),(j+1,i+1)],[(j,i),(j+1,i+1),(j+1,i)]]:
                face=np.array([np.r_[lip[a][b],lip_ns[a][b]] for a,b in ids])
                if np.cross(face[1,:3]-face[0,:3],face[2,:3]-face[0,:3])@face[:,3:].mean(0)<0:face=face[::-1]
                kept.append(face)
    # Closed side returns join the rolled bridge to the wing corners.
    for sign in [-1,1]:
        x=sign*.84;zs=np.linspace(-2.190,-2.075,13)
        ys=hood.height(np.full(len(zs),x),zs)
        for i in range(len(zs)-1):
            points=np.array([[x,ys[i],zs[i]],[x,ys[i+1],zs[i+1]],
                             [x,lower(x),zs[i+1]],[x,lower(x),zs[i]]])
            for ids in [(0,1,2),(0,2,3)]:
                q=points[list(ids)]
                t=np.clip((q[:,1]-lower(x))/(hood.height(q[:,0],q[:,2])-lower(x)),0,1)
                u=np.clip((q[:,2]+2.190)/.115,0,1)
                normal=np.c_[sign*(1-t),t,-.6*(1-u)*(1-t)]
                normal/=np.linalg.norm(normal,axis=1,keepdims=True)
                face=np.c_[q,normal]
                if np.cross(face[1,:3]-face[0,:3],face[2,:3]-face[0,:3])@face[:,3:].mean(0)<0:face=face[::-1]
                kept.append(face)
    _write(obj,_symmetric(np.asarray(kept)))


def regular_door(obj):
    """Regular sheet above the measured sill; preserve its existing outline."""
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    from mathutils.bvhtree import BVHTree
    p,f,n=_read(obj);tri=np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6)
    bvh=BVHTree.FromPolygons(p.tolist(),f.tolist(),all_triangles=True)
    top,z0,z1=.720,-.740,.700
    columns=np.linspace(z0,z1,73);floor=[]
    for z in columns:
        found=None
        for y in np.linspace(.270,.420,301):
            hit,*_=bvh.ray_cast((2,float(y),float(z)),(-1,0,0),4)
            if hit is not None and hit.x>.6:found=float(y)+.0025;break
        assert found is not None,f'Measured sill missing at {z}'
        floor.append(found)
    def bottom(z):return np.interp(z,columns,floor)
    rect=np.array([[0,z0],[1,z0],[1,z1],[0,z1]])
    kept=[];border=[]
    for face in tri:
        vv=(face[:,1]-bottom(face[:,2]))/(top-bottom(face[:,2]))
        if face[:,0].min()<.64 or face[:,3].mean()<.1 or vv.max()<0 or vv.min()>1 or face[:,2].max()<z0 or face[:,2].min()>z1:
            kept.append(face);continue
        extended=np.c_[face,vv]
        pieces=_subtract(extended,rect,(6,2))
        for piece in pieces:
            for v in piece:
                if min(abs(v[6]),abs(v[6]-1))<1e-7 and z0-1e-8<=v[2]<=z1+1e-8:
                    v[1]=bottom(v[2])+v[6]*(top-bottom(v[2]))
                if -1e-8<=v[6]<=1+1e-8 and z0-1e-8<=v[2]<=z1+1e-8 and min(abs(v[6]),abs(v[6]-1),abs(v[2]-z0),abs(v[2]-z1))<1e-7:border.append(v[[6,2]])
            kept.append(piece[:,:6])
    border=np.unique(np.round(np.vstack([border,rect]),8),axis=0);c=rect.mean(0)
    border=border[np.argsort(np.arctan2((border[:,1]-c[1])/(z1-z0),border[:,0]-c[0]))]
    samples=border.tolist();edges=[(i,(i+1)%len(border)) for i in range(len(border))]
    for v in [.025,.05,.08,.12,.18,.27,.38,.52,.68,.84,.95]:
        previous=None
        for z in np.linspace(z0,z1,25):
            k=len(samples);samples.append([v,z])
            if previous is not None:edges.append((previous,k))
            previous=k
    uv,_,faces,*_=delaunay_2d_cdt([Vector(v) for v in samples],edges,[],0,1e-8,False)
    points=[];normals=[]
    for v,z in uv:
        y=float(bottom(z)+v*(top-bottom(z)))
        hit,old_normal,hit_face,*_=bvh.ray_cast((2,y,float(z)),(-1,0,0),4)
        assert hit is not None and hit.x>.6,f'Door chart must preserve coverage: {y}, {z}'
        a,b,c=p[f[hit_face]]
        matrix=np.c_[b-a,c-a]
        weights=np.linalg.lstsq(matrix,np.asarray(hit)-a,rcond=None)[0]
        old_normal=np.array([1-weights.sum(),*weights])@n.reshape(-1,3,3)[hit_face]
        blend=ramp(0,.08,v)*(1-ramp(.84,1,v))*ramp(z0,-.67,z)*(1-ramp(.63,z1,z))
        width=float(curve(np.array(y),[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925]))-.007*z
        points.append([hit.x+(width-hit.x)*blend,y,z]);e=.00005
        dy=float((curve(np.array(y+e),[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925])-curve(np.array(y-e),[.27,.30,.34,.42,.54,.65,.74,.80],[.724,.726,.757,.840,.888,.913,.922,.925]))/(2*e))
        normal=np.array([1,-dy,.007]);normal/=np.linalg.norm(normal)
        normal=np.asarray(old_normal)*(1-blend)+normal*blend
        normals.append(normal/np.linalg.norm(normal))
    points=np.asarray(points);normals=np.asarray(normals)
    for face in faces:
        ids=np.array(face)
        if np.cross(points[ids[1]]-points[ids[0]],points[ids[2]]-points[ids[0]])@normals[ids].mean(0)<0:ids=ids[::-1]
        kept.append(np.c_[points[ids],normals[ids]])
    _write(obj,_symmetric(np.asarray(kept)))


def final_fascia(obj):
    """Keep a regular rear face and lock the grille edge after reduction."""
    p,f,n=_read(obj)
    # A quad-reduced edge can drift several millimetres from a curved guide.
    # Refit only the exposed lower aperture boundary, retaining its topology.
    from collections import Counter
    positions,lookup=np.unique(np.round(p,6),axis=0,return_inverse=True)
    edges=Counter(tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in lookup[f] for i in range(3))
    boundary=set(v for edge,count in edges.items() if count==1 for v in edge)
    selected=np.array([v in boundary for v in lookup])&(p[:,2]<-2.17)&(p[:,1]>.590)&(p[:,1]<.645)&(abs(p[:,0])<.715)
    p[selected,1]=.616+.004*(p[selected,0]/.78)**6
    triangles=np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6);trimmed=[];kept=[]
    for triangle in triangles:
        lower=.616+.004*(triangle[:,0]/.78)**6
        extended=np.c_[triangle,triangle[:,1]-lower]
        for piece in _subtract_box(extended,[(0,-.715,.715),(2,-2.29,-2.17),(6,0,.045)]):
            on=abs(piece[:,6])<1e-8
            piece[on,1]=.616+.004*(piece[on,0]/.78)**6
            trimmed.append(piece[:,:6])
    _write(obj,_symmetric(np.asarray(trimmed)))


def rear_loft(obj):
    """One closed transverse loft joins both rear quarters to the rear face."""
    p,f,n=_read(obj);records=np.c_[p[f].reshape(-1,3),n].reshape(-1,3,6);kept=[]
    def width(y):return curve(y,[.28,.35,.45,.65,.82,.98,1.05],[.76,.79,.86,.90,.90,.86,.84])
    def side(y,z):
        reach=2.205+.006*(1-((y-.63)/.4)**2)-1.78
        return width(y)*np.maximum(.0001,1-np.maximum(0,(z-1.78)/reach)**8)**.125
    def normal(x,y,z):
        e=.00005;dx=(rear_surface(x+e,y)-rear_surface(x-e,y))/(2*e)
        dy=(rear_surface(x,y+e)-rear_surface(x,y-e))/(2*e)
        if z<1.90:
            dxdy=(side(y+e,z)-side(y-e,z))/(2*e)
            dxdz=(side(y,z+e)-side(y,z-e))/(2*e)
            v=np.array([1,-dxdy,-dxdz])
        else:v=np.array([-dx,-dy,1])
        return v/max(np.linalg.norm(v),1e-12)
    for face in records:
        for piece in _subtract_box(face,[(0,0,1.2),(1,.45,.762),(2,1.75,2.3)]):
            for v in piece:
                if v[0]<0 or v[2]<1.75-1e-8:continue
                if min(abs(v[1]-.45),abs(v[1]-.762))<1e-8:
                    w=width(v[1]);reach=2.205+.006*(1-((v[1]-.63)/.4)**2)-1.78
                    gauge=(abs(v[0]/w)**8+max(0,(v[2]-1.78)/reach)**8)**.125
                    if gauge>.1:v[0]/=gauge;v[2]=1.78+(v[2]-1.78)/gauge
                    v[3:]=normal(*v[:3])
                if abs(v[2]-1.75)<1e-8 and .45-1e-8<=v[1]<=.762+1e-8:
                    v[0]=width(v[1]);v[3:]=normal(*v[:3])
            kept.append(piece)
    ys=np.array([.45,.46,.48,.50,.54,.58,.62,.66,.70,.735,.762])
    rows=[];normals=[]
    for y in ys:
        zs=np.linspace(1.75,2.16,23);xs=side(y,zs)
        back=np.linspace(xs[-1],0,29)[1:]
        x=np.r_[xs,back];z=np.r_[zs,rear_surface(back,y)]
        row=np.c_[x,np.full(len(x),y),z]
        rows.append(row);normals.append(np.array([normal(*p) for p in row]))
    rows=np.asarray(rows);normals=np.asarray(normals)
    for j in range(len(ys)-1):
        for i in range(rows.shape[1]-1):
            for ids in [[(j,i),(j,i+1),(j+1,i+1)],[(j,i),(j+1,i+1),(j+1,i)]]:
                face=np.array([np.r_[rows[a,b],normals[a,b]] for a,b in ids])
                if np.cross(face[1,:3]-face[0,:3],face[2,:3]-face[0,:3])@face[:,3:].mean(0)<0:face=face[::-1]
                kept.append(face)
    _write(obj,_symmetric(np.asarray(kept)))


def remove_planar_fragments(obj,simple):
    """Dissolve clipping fragments; retain the door's shading sample rows."""
    import bpy,bmesh
    reference=obj.copy();reference.data=obj.data.copy()
    bpy.context.scene.collection.objects.link(reference);reference.hide_set(True);reference.hide_render=True
    before=len(obj.data.polygons)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0000001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.0000002)
    levels=np.array([.300,.310,.320,.335,.350,.370,.400,.450,.500,.550,.600,.650,.700])
    for edge in bm.edges:
        a,b=edge.verts
        if (abs(a.co.x)>.64 and abs(b.co.x)>.64 and -.95< -a.co.y<1.10 and -.95< -b.co.y<1.10
                and abs(a.co.z-b.co.z)<1e-6 and np.min(abs(levels-a.co.z))<1e-6):edge.seam=True
    bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.01),verts=list(bm.verts),edges=list(bm.edges),
                             use_dissolve_boundaries=False,delimit={'SEAM','SHARP','MATERIAL'})
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bm.to_mesh(obj.data);bm.free()
    reference.data=obj.data.copy()
    target=10400 if simple else 17300
    if len(obj.data.polygons)>target:
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        reduction=obj.modifiers.new('Compact fitted skins','DECIMATE')
        reduction.ratio=target/len(obj.data.polygons)
        reduction.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=reduction.name)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    transfer=obj.modifiers.new('Retain clean guide normals','DATA_TRANSFER');transfer.object=reference
    transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'};transfer.loop_mapping='POLYINTERP_NEAREST'
    bpy.ops.object.datalayout_transfer(modifier=transfer.name);bpy.ops.object.modifier_apply(modifier=transfer.name)
    bpy.data.objects.remove(reference,do_unlink=True)
    mirror_object(obj)
    return {'before':before,'after':len(obj.data.polygons)}


def finish(exports,simple,hood):
    paint=next(o for o in exports if o.name=='body__paint')
    stats=correct_paint(paint,hood)
    nose_bridge(paint,hood)
    stats['before_door']=len(paint.data.polygons)
    regular_door(paint)
    stats['after_door']=len(paint.data.polygons)
    stats['bonnet_seat']='continuous wider bonnet with integral lower edge return'
    stats['planar_fragments']=remove_planar_fragments(paint,simple)
    final_fascia(paint)
    rear_loft(paint)
    for obj in exports:
        seat_rear_details(obj)
        group,role=obj.name.split('__')
        if obj==paint or role=='contour' or group in ['head_left','head_right','tail_left','tail_right']:continue
        mirror_object(obj)
    # The separately articulated lamps use matching reflected geometry.
    for right,left in [('head_right','head_left'),('tail_right','tail_left')]:
        sources=[o for o in exports if o.name.startswith(right+'__')]
        for src in sources:
            dst=next(o for o in exports if o.name==left+'__'+src.name.split('__')[1])
            p,f,n=_read(src);p[:,0]*=-1;n[:,0]*=-1
            _write(dst,np.c_[p[f[:,::-1]].reshape(-1,3),n.reshape(-1,3,3)[:,::-1].reshape(-1,3)].reshape(-1,3,6))
    return stats
