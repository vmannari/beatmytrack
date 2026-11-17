"""Offline reference-led bonnet, wing and front-face refinement.

This final-coordinate chart is shared by the paint and all optical/trim layers.
The roof, rear body, wheel mounting points and chassis stay fixed.
"""
import numpy as np
from challenger_side_surface import Curve,ramp,unit


def front_scale(z):
    return 1+.095*(1-ramp(-2.22,-1.55,np.asarray(z)))


class ReferenceForm:
    def __init__(self,hood_points,hood_normals,body_points,body_faces,side):
        from mathutils.bvhtree import BVHTree
        p=np.asarray(hood_points);n=np.asarray(hood_normals)
        top=p[n[:,1]>.4]
        # Highest copy at each X/Z station excludes the thin underside return.
        order=np.argsort(top[:,1]);top=top[order]
        _,ids=np.unique(top[:,[0,2]][::-1],axis=0,return_index=True)
        top=top[::-1][ids]
        # Small regular survey avoids a runtime/scipy dependency in Blender.
        self.old_x=np.linspace(-.86,.86,87);self.old_z=np.linspace(-2.30,-.70,161)
        self.old_grid=np.empty((len(self.old_x),len(self.old_z)))
        for i,x in enumerate(self.old_x):
            for j,z in enumerate(self.old_z):
                distance=(top[:,0]-x)**2+(top[:,2]-z)**2
                ids=np.argpartition(distance,min(5,len(distance)-1))[:6]
                weight=1/np.maximum(distance[ids],1e-10)
                self.old_grid[i,j]=np.sum(top[ids,1]*weight)/weight.sum()
        zs=np.linspace(-2.14,-.80,21);xs=[];ys=[]
        for z in zs:
            band=p[abs(p[:,2]-z)<.04];edge=band[abs(band[:,0])>np.quantile(abs(band[:,0]),.95)]
            xs.append(float(np.max(abs(edge[:,0]))));ys.append(float(np.max(edge[:,1])))
        self.edge_x=Curve(zs,xs);self.edge_y=Curve(zs,ys)
        self.base=Curve([-2.30,-2.22,-2.10,-1.80,-1.35,-.95,-.72],[.805,.853,.898,.934,.964,.971,.982])
        self.crease=Curve([-2.30,-2.15,-1.9,-1.4,-.7],[.811,.818,.821,.826,.832])
        # Survey the original fascia depth once; every layer keeps its recess.
        tree=BVHTree.FromPolygons(np.asarray(body_points).tolist(),np.asarray(body_faces).tolist(),all_triangles=True)
        xx=np.linspace(0,.80,25);zz=[]
        for x in xx:
            hit,*_=tree.ray_cast((float(x),.565,-3),(0,0,1),2)
            zz.append(float(hit.z) if hit is not None else -2.245+.08*(x/.8)**2)
        # Rays beyond the fascia hit the longitudinal wing. Continue the
        # corner tangent instead of treating that rearward hit as a face.
        zz[-2]=zz[-3]+(zz[-3]-zz[-4]);zz[-1]=zz[-2]+(zz[-2]-zz[-3])
        self.old_front=Curve(xx,zz)
        self.side_crease=side.crease
        self.wing_width=side.width_curve
        self.stats={'method':'shared reference bonnet crown, upper wing and rounded front plane',
                    'front_width_factor':1.095,'survey_x':xx.tolist(),'survey_front_z':zz,
                    'maximum_power_bulge_metres':.042,'main_deck_lowering_metres':.050,
                    'optical_carrier_radius_metres':.063}

    def old_height(self,x,z):
        x,z=np.broadcast_arrays(x,z)
        a=np.clip((x-self.old_x[0])/(self.old_x[1]-self.old_x[0]),0,len(self.old_x)-1.00001)
        b=np.clip((z-self.old_z[0])/(self.old_z[1]-self.old_z[0]),0,len(self.old_z)-1.00001)
        i=a.astype(int);j=b.astype(int);a-=i;b-=j
        g=self.old_grid
        return (1-a)*(1-b)*g[i,j]+a*(1-b)*g[i+1,j]+(1-a)*b*g[i,j+1]+a*b*g[i+1,j+1]

    def height(self,x,z):
        x,z=np.broadcast_arrays(x,z)
        centre=np.exp(-(abs(x)/.37)**6)
        dome=.042*centre*ramp(-2.08,-1.72,z)*(1-ramp(-1.05,-.78,z))
        # Lower the main bonnet deck and its shared wing banks. The central
        # intake keeps its accepted height; only that narrow piece stays proud.
        # C2 end blends retain the leading roll and windscreen/cowl attachment.
        rear_seat=-.990+.225*(abs(x)/.755)**2-.020
        deck_drop=.050*ramp(-2.20,-1.88,z)*(1-ramp(-1.22,rear_seat,z))
        return self.base(z)+.012*(1-(x/.84)**2)+dome-deck_drop*(1-centre)

    def hood_normal(self,x,z):
        e=.00002
        dx=(self.height(x+e,z)-self.height(x-e,z))/(2*e)
        dz=(self.height(x,z+e)-self.height(x,z-e))/(2*e)
        return unit(np.c_[-dx,np.ones(np.size(x)),-dz])

    def map(self,p,kind):
        p=np.asarray(p);q=p.copy();x=abs(p[:,0]);y=p[:,1];z=p[:,2]
        if kind.startswith('hood_'):
            old=self.old_height(p[:,0],z)
            offset=np.zeros(len(p)) if kind=='hood_paint' else y-old
            q[:,1]=self.height(p[:,0],z)+offset
        elif kind=='body_paint':
            # One displacement across the bonnet seam avoids independently
            # pulling its two banks apart. The lower side keeps its fair chart.
            shoulder=self.side_crease(np.clip(z,-2.26,-.70))
            w=ramp(shoulder+.012,shoulder+.080,y)*(1-ramp(.90,1.03,x))*(1-ramp(-.86,-.70,z))
            ez=np.clip(z,-2.25,-.76)
            old_edge=self.edge_y(ez)+.015*(1-(x/np.maximum(self.edge_x(ez),.60))**2)
            q[:,1]+=w*(self.height(p[:,0],z)-old_edge)
            # A single manufactured section joins the sharp shoulder to the
            # new bonnet. This replaces the factory cowl's retained dent and
            # its independent upper-wing normal patches.
            zz=np.clip(z,-2.08,-.70);c=self.side_crease(zz)
            v=np.clip((zz+2.17)/1.40,0,1)
            hx=(.730+.025*v+.008*np.sin(np.pi*v))/front_scale(zz)
            edge_height=self.height(hx,zz);h=np.maximum(edge_height-c,.065)
            peak=self.wing_width(zz);d=q[:,1]-c
            bend=(peak-.42*h-hx)/(h*h)
            target=peak-.42*d-bend*d*d
            wing=ramp(.65,.72,x)*ramp(-2.17,-2.08,z)*(1-ramp(-.85,-.70,z))
            wing*=ramp(c+.008,c+.035,q[:,1])*(1-ramp(edge_height+.015,edge_height+.065,q[:,1]))
            q[:,0]+=wing*(np.sign(p[:,0])*target-q[:,0])
        else:
            # Thin raised engine plate and ribs sit on the new central crown.
            plate=(x<.36)&(z> -1.55)&(z<-.83)&(y>.94)
            if kind in ['body_red','body_accent','body_metal','body_dark']:
                q[plate,1]=self.height(p[plate,0],z[plate])+np.clip(y[plate]-self.old_height(p[plate,0],z[plate]),.002,.022)
        # Lift the front lamp band with its surrounding paint; leave lower lip.
        if not kind.startswith('hood_'):
            q[:,1]+=.034*(1-ramp(-2.16,-1.76,z))*ramp(.52,.66,y)*(1-ramp(.79,.85,y))
        # Undo the excessive final nose squeeze without a sudden width flare.
        q[:,0]*=front_scale(z)
        # Flatten the swept front, retaining each grille/lamp layer's depth.
        frontal=(1-ramp(-2.13,-1.96,z))*(1-ramp(.825,.90,y))
        old=self.old_front(np.clip(x,0,.8))
        target=-2.247+.033*(np.clip(abs(q[:,0])/.86,0,1.15)**4)
        if not kind.startswith('hood_'):q[:,2]+=frontal*(target-old)
        return q

    def apply(self,values,kind):
        values=np.asarray(values).reshape(-1,3,6);v=values.reshape(-1,6)
        p=v[:,:3];q=self.map(p,kind);e=.000025;columns=[]
        for axis in range(3):
            d=np.zeros(3);d[axis]=e
            columns.append((self.map(p+d,kind)-self.map(p-d,kind))/(2*e))
        a,b,c=columns;n=v[:,3:]
        nn=unit(n[:,0,None]*np.cross(b,c)+n[:,1,None]*np.cross(c,a)+n[:,2,None]*np.cross(a,b))
        if kind=='hood_paint':
            top=np.ones(len(p),dtype=bool);nn[top]=self.hood_normal(p[top,0],p[top,2])
            nn[top,0]/=front_scale(p[top,2]);nn[top]=unit(nn[top])
        out=np.c_[q,nn].reshape(-1,3,6)
        cross=np.cross(out[:,1,:3]-out[:,0,:3],out[:,2,:3]-out[:,0,:3]);length=np.linalg.norm(cross,axis=1)
        keep=length>1e-11;geometric=unit(cross)
        if kind=='hood_paint':keep&=cross[:,1]>1e-11
        if kind=='body_paint':
            # The original nose has a second thin returned skin. Fairing can
            # put its back-facing triangles just outside the visible sheet.
            # Remove only returns proven to have outward paint within 5 mm.
            from mathutils.bvhtree import BVHTree
            centre=out[:,:,:3].mean(1);sign=np.sign(centre[:,0])
            outward=(cross[:,0]*sign>1e-10)&keep
            points=out[:,:,:3].reshape(-1,3);faces=np.arange(len(points)).reshape(-1,3)
            tree=BVHTree.FromPolygons(points.tolist(),faces[outward].tolist(),all_triangles=True)
            returns=(centre[:,2]>-2.20)&(centre[:,2]<-1.80)&(centre[:,1]>.55)&(centre[:,1]<.88)&(abs(centre[:,0])>.70)&(cross[:,0]*sign<0)
            removed=0
            for i in np.flatnonzero(returns):
                hit,*_=tree.ray_cast((float(sign[i]*2),float(centre[i,1]),float(centre[i,2])),(-float(sign[i]),0,0),2)
                if hit is not None and hit.x*sign[i]>.65 and abs(hit.x-centre[i,0])<.005:
                    keep[i]=False;removed+=1
            self.stats['covered_nose_return_triangles_removed']=removed
        flip=np.sum(out[:,:,3:]*geometric[:,None,:],axis=2)<0
        out[:,:,3:][flip]*=-1
        return out[keep]


def rebuild(exports,lattice,simple,side):
    import challenger_clean_panels as panel
    from challenger_exterior_geometry import records,NativeHoodGuide
    hood=next(o for o in exports if o.name=='hood__paint');body=next(o for o in exports if o.name=='body__paint')
    hp,hf,hn=panel._read(hood);bp,bf,_=panel._read(body)
    # Corner normals align with indexed triangle corners, not unique vertices.
    field=ReferenceForm(hp[hf].reshape(-1,3),hn,bp,bf,side)
    optics=manufactured_optics()
    for obj in exports:
        kind=obj.name.replace('__','_')
        if kind=='body_contour' or kind.startswith('hood_'):continue
        values=field.apply(records(obj),kind)
        values=replace_optics(values,kind,optics)
        panel._write(obj,values)
    class FinishedHood(panel.CleanHood):
        def width(self,v):return .730+.025*np.asarray(v)+.008*np.sin(np.pi*np.asarray(v))
        def front(self,u):return -2.170+.020*np.asarray(u)**4
        def rear(self,u):return -.990+.225*np.asarray(u)**2
        def height(self,x,z):return field.height(np.asarray(x)/front_scale(z),z)
        def normal(self,x,z):
            e=.00002;x,z=np.broadcast_arrays(x,z)
            return unit(np.c_[-(self.height(x+e,z)-self.height(x-e,z))/(2*e),np.ones(x.size),-(self.height(x,z+e)-self.height(x,z-e))/(2*e)])
    final=FinishedHood()
    from challenger_hood_geometry import rebuild as rebuild_hood, strip_legacy_trim
    hood_profile = rebuild_hood(exports, final, lattice, simple)
    removed_trim = 0
    for obj in exports:
        kind = obj.name.replace('__', '_')
        if kind not in ['body_red', 'body_accent', 'body_metal', 'body_dark']:
            continue
        original = records(obj)
        trimmed = strip_legacy_trim(original, kind, final)
        removed_trim += len(original) - len(trimmed)
        panel._write(obj, trimmed)
    field.stats['hood_design'] = {**hood_profile.stats, 'removed_legacy_trim_triangles': removed_trim}
    from challenger_surface_quality import finish
    field.stats['surface_quality'] = finish(exports, field, simple)
    from challenger_side_finish import finish as finish_side
    field.stats['side_finish'] = finish_side(exports, field, simple)
    # Cut centre-crossing detail triangles before GLTF packing, so the native
    # mirror operation preserves exactly the producer's triangle count.
    for obj in exports:
        kind=obj.name.replace('__','_')
        if kind not in ['body_paint','body_dark','body_chrome','body_led','body_mirror','body_vent_metal','hood_paint','hood_dark']:continue
        values=records(obj);axis=abs(values[:,:,0])<.000030
        values[:,:,0][axis]=0;values[:,:,3][axis]=0
        right=panel._positive(values);kept=[];seen=set()
        for face in right:
            if np.max(abs(face[:,0]))<1e-9:
                key=tuple(sorted(tuple(p) for p in np.round(face[:,:3],7)))
                if key in seen:continue
                seen.add(key)
            kept.append(face)
        right=np.asarray(kept);left=right[:,::-1,:].copy();left[:,:,0]*=-1;left[:,:,3]*=-1
        panel._write(obj,np.concatenate([right,left]))
    return field.stats,NativeHoodGuide(hood,hood_profile,outline=hood_profile.boundary()),hood_profile


def replace_optics(values,kind,optics):
    if kind.startswith('head_'):return optics[kind]
    if kind=='body_paint':
        import challenger_clean_panels as panel
        import challenger_detail_geometry as detail
        aperture=detail.rounded(0,.736,1.638,.194,.061,12)
        kept=[]
        for face in values:
            if face[:,2].min()<-1.96 and face[:,1].max()>.63 and face[:,1].min()<.84:
                kept.extend(panel._subtract(face,aperture,(0,1)))
            else:kept.append(face)
        values=np.asarray(kept)
    if kind in ['body_dark','body_chrome','body_led','body_mirror','body_vent_metal']:
        centre=values[:,:,:3].mean(1)
        remove=(centre[:,2]<-1.96)&(centre[:,1]>.60)&(centre[:,1]<.86)
        values=values[~remove]
    if kind in optics:values=np.concatenate([values,optics[kind]])
    return values


def manufactured_optics():
    """One rounded carrier and one near-upright plane for all four lamps."""
    import challenger_detail_geometry as detail
    result={}
    def face_z(x):return -2.238+.020*(abs(np.asarray(x))/.84)**6
    def emit(kind,p,f,n=None):
        p=np.asarray(p);f=np.asarray(f,dtype=int)
        cross=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])
        if n is None:ns=np.repeat(unit(cross),3,axis=0)
        else:ns=np.asarray(n)[f].reshape(-1,3)
        result.setdefault(kind,[]).append(np.c_[p[f].reshape(-1,3),ns].reshape(-1,3,6))
    path=detail.rounded(0,.736,1.654,.202,.063,12)
    p,f=detail.disk(path,lambda x,y:float(face_z(x)+.006),spacing=.05)
    emit('body_dark',p,f)
    surround=[]
    for width,height,radius,depth in [(1.695,.248,.087,-.021),(1.675,.228,.078,-.022),(1.654,.210,.069,-.016),(1.638,.194,.061,-.007)]:
        path=detail.rounded(0,.736,width,height,radius,12)
        surround.append(np.c_[path[:,0],path[:,1],face_z(path[:,0])+depth])
    p,f=detail.ring(surround)
    emit('body_paint',p,[tuple(reversed(t)) for t in f])
    theta=np.linspace(0,2*np.pi,48,endpoint=False)
    for sign in [-1,1]:
        for cx in [sign*.568,sign*.737]:
            def turned(kind,profile):
                loops=[np.c_[cx+r*np.cos(theta),.736+r*np.sin(theta),np.full(len(theta),float(face_z(cx))+depth)] for r,depth in profile]
                p,f=detail.ring(loops);emit(kind,p,[tuple(reversed(t)) for t in f])
            turned('body_dark',[(.067,.006),(.067,-.002),(.060,-.005),(.052,.004),(.002,.012)])
            turned('body_chrome',[(.060,-.005),(.061,-.007),(.057,-.009),(.053,-.006)])
            turned('body_led',[(.053,-.007),(.053,-.009),(.050,-.009),(.050,-.006)])
            turned('body_mirror',[(.048,-.003),(.041,.003),(.028,.009),(.024,.006)])
            turned('head_left_white' if sign<0 else 'head_right_white',[(.026,.005),(.018,.002),(.002,.001)])
    # A narrow satin rim defines the central rounded grille independently of
    # the surrounding lamp carrier. The lower opening receives actual cells.
    loops=[]
    for width,height,radius,depth in [(1.002,.145,.032,-.001),(.984,.127,.025,-.003)]:
        path=detail.rounded(0,.736,width,height,radius,10)
        loops.append(np.c_[path[:,0],path[:,1],face_z(path[:,0])+depth])
    p,f=detail.ring(loops);emit('body_dark',p,[tuple(reversed(t)) for t in f])
    for cy,width,height,radius,depth in [(.736,.969,.119,.023,-.001),(.424,1.23,.115,.035,.082)]:
        path=detail.rounded(0,cy,width,height,radius,8)
        p,f=detail.disk(path,lambda x,y:float(face_z(x)+depth+.012),spacing=.06);emit('body_dark',p,f)
        cell=.021;row=0
        def inside(x,y):
            dx=max(abs(x)-(width/2-radius),0);dy=max(abs(y-cy)-(height/2-radius),0)
            return dx*dx+dy*dy<radius*radius and abs(x)<width/2 and abs(y-cy)<height/2
        for y in np.arange(cy-height/2+cell*.7,cy+height/2,cell*1.5):
            for x in np.arange(-width/2+cell,width/2-cell,cell*np.sqrt(3))+(row%2)*cell*np.sqrt(3)/2:
                t=np.arange(6)*np.pi/3+np.pi/6
                outer=np.c_[x+cell*.94*np.cos(t),y+cell*.94*np.sin(t)]
                if not all(inside(a,b) for a,b in outer):continue
                inner=np.c_[x+cell*.78*np.cos(t),y+cell*.78*np.sin(t)]
                p,f=detail.ring([np.c_[outer,face_z(outer[:,0])+depth],np.c_[inner,face_z(inner[:,0])+depth+.001]])
                emit('body_vent_metal',p,[tuple(reversed(t)) for t in f])
            row+=1
    return {k:np.concatenate(v) for k,v in result.items()}
