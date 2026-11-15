"""Authored exterior manufacturing details for the offline Challenger conversion.

Coordinates are metres in the fitted car frame, before the common nose warp.
No textures, branding, cabin contents or source scripts are used.
"""
import math
import numpy as np


def rounded(cx, cy, width, height, radius, steps=6):
    points = []
    for x, y, start in [(1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)]:
        for angle in np.linspace(start, start+90, steps, endpoint=False):
            a = math.radians(angle)
            points.append([cx+x*(width/2-radius)+radius*math.cos(a),
                           cy+y*(height/2-radius)+radius*math.sin(a)])
    return np.asarray(points)


def ring(loops):
    vertices = np.concatenate(loops)
    count = len(loops[0]); faces = []
    for j in range(len(loops)-1):
        for i in range(count):
            a=j*count+i; b=j*count+(i+1)%count
            faces.extend([(a,b,b+count),(a,b+count,a+count)])
    return vertices, faces


def disk(path, z_at, rear=False, spacing=.025):
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    def inside(x,y):
        result=False
        for a,b in zip(path,np.roll(path,-1,axis=0)):
            if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
        return result
    # Regular surface samples preserve the transverse curve. A fan with only
    # corner samples wrongly pulled the wide applique back toward its ends.
    boundary=[]
    for a,b in zip(path,np.roll(path,-1,axis=0)):
        for t in np.linspace(0,1,max(1,math.ceil(np.linalg.norm(b-a)/spacing)),endpoint=False):boundary.append(a*(1-t)+b*t)
    points=list(boundary);low,high=path.min(0),path.max(0)
    for x in np.arange(low[0]+spacing*.5,high[0],spacing):
        for y in np.arange(low[1]+spacing*.5,high[1],spacing):
            if inside(x,y):points.append([x,y])
    xy,_,faces,*_=delaunay_2d_cdt([Vector(p) for p in points],[],[list(range(len(boundary)))],1,1e-6,False)
    vertices=[[p.x,p.y,z_at(p.x,p.y)] for p in xy]
    # All 2D paths are anticlockwise; a front-facing disk looks down -Z.
    if not rear: faces = [tuple(reversed(f)) for f in faces]
    return vertices, faces


def details(add, simple, rear_surface):
    """Use one material bucket per role; do not create runtime detail nodes."""
    count = 48 if simple else 64
    theta = np.arange(count)*2*math.pi/count
    def emit(name, vertices, faces, role, group='body'):
        add(name, vertices, faces, role, group, orient=False)

    # One restrained curved carrier keeps the optical face almost upright;
    # the previous 130 mm centre/corner sweep pinched the side of the nose.
    carrier=rounded(0,.709,1.628,.184,.035,8)
    def carrier_z(x):
        t=np.clip((abs(x)-.49)/.05,0,1);t=t*t*(3-2*t)
        return (-2.046+.104*(abs(x)/.8)**2+.018)*(1-t)+(-1.946+.035*(abs(x)/.8)**2+.010)*t
    v,f=disk(carrier,lambda x,y:carrier_z(x),spacing=.060 if simple else .045)
    emit('FrontOpticCarrier',v,f,'dark')
    emit('LowerIntakeBacking',[[-.78,.33,-1.880],[.78,.33,-1.880],[.78,.52,-1.880],[-.78,.52,-1.880]],[(2,1,0),(3,2,0)],'dark')

    # Four projector optics: a turned bezel, recessed dark reflector, lens and
    # a restrained light guide. The two white buckets remain the night lenses.
    for side in [-1,1]:
        group = 'head_left' if side<0 else 'head_right'
        for index,cx in enumerate([side*.575,side*.730]):
            cy=.709; cz=-1.946+.035*(abs(cx)/.8)**2
            def lathe(name,profile,role):
                loops=[np.c_[cx+r*np.cos(theta),cy+r*np.sin(theta),np.full(count,cz+depth)] for r,depth in profile]
                v,f=ring(loops)
                # With an anticlockwise ring, inward-going profiles face -Z.
                emit(name+str(side)+str(index),v,[tuple(reversed(t)) for t in f],role)
            lathe('ProjectorHousing',[(.069,.025),(.069,-.001),(.064,-.005),(.054,-.005),(.051,.010)],'dark')
            lathe('MachinedOpticRim',[(.061,-.006),(.062,-.009),(.059,-.011),(.055,-.010),(.054,-.006)],'chrome')
            lathe('DaylightGuide',[(.054,-.007),(.054,-.010),(.051,-.010),(.051,-.007)],'led')
            lathe('ProjectorReflector',[(.049,-.004),(.043,.009),(.029,.016),(.024,.014)],'mirror')
            # The complete lens geometry belongs to the existing night API.
            rings=[]
            for r,depth in [(.026,.009),(.018,.006),(.002,.005)]:
                rings.append(np.c_[cx+r*np.cos(theta),cy+r*np.sin(theta),np.full(count,cz+depth)])
            v,f=ring(rings);emit('ProjectorLens'+str(side)+str(index),v,[tuple(reversed(t)) for t in f],'white',group)

    # Recessed satin-black upper grille, with open cells and actual depth.
    # It is kept inside the bumper opening, clear of the fender corners.
    grille=rounded(0,.711,1.01,.144,.025,8)
    grille_z=lambda x:-2.046+.104*(abs(x)/.8)**2
    v,f=disk(grille,lambda x,y:grille_z(x)+.018)
    emit('GrilleRecess',v,f,'dark')
    outer=rounded(0,.711,1.025,.158,.030,8)
    inner=rounded(0,.711,1.003,.137,.022,8)
    v,f=ring([np.array([[x,y,grille_z(x)] for x,y in outer]),np.array([[x,y,grille_z(x)-.002] for x,y in inner])])
    emit('GrillePerimeter',v,[tuple(reversed(t)) for t in f],'vent_metal')
    vertices=[];faces=[]
    columns=19 if simple else 25
    pitch=.0507 if simple else .038
    rx=.0307 if simple else .023
    for row in range(3):
        for column in range(columns):
            x=(column-(columns-1)/2)*pitch+(row%2)*pitch*.5; y=.671+row*.034
            if abs(x)>.470:continue
            a=np.arange(6)*math.pi/3
            outer=np.c_[x+rx*np.cos(a),y+.020*np.sin(a)]
            inner=np.c_[x+(rx-.0025)*np.cos(a),y+.0175*np.sin(a)]
            v,f=ring([np.array([[x,y,grille_z(x)-.003] for x,y in outer]),np.array([[x,y,grille_z(x)-.003] for x,y in inner]),np.array([[x,y,grille_z(x)+.009] for x,y in inner])])
            offset=len(vertices);vertices.extend(v);faces.extend([tuple(offset+i for i in reversed(t)) for t in f])
    emit('OpenHoneycombGrille',vertices,faces,'vent_metal')

    # Continuous rear applique with rounded returns; clean twin perimeter
    # light guides sit ahead of a smoked lens rather than polygonal red slabs.
    rear_z=rear_surface
    outer=rounded(.005,.854,1.620,.184,.055,8)
    inner=rounded(.005,.854,1.600,.166,.045,8)
    v,f=disk(inner,lambda x,y:rear_z(x,y)+.001,True)
    emit('SmokedRearApplique',v,f,'dark')
    v,f=ring([np.array([[x,y,rear_z(x,y)-.003] for x,y in outer]),np.array([[x,y,rear_z(x,y)+.003] for x,y in inner])])
    emit('RearAppliqueReturn',v,f,'accent')
    for side in [-1,1]:
        cx=side*.475+.005;cy=.862
        outer=rounded(cx,cy,.535,.073,.022,10)
        v,f=disk(outer,lambda x,y:rear_z(x,y)+.004,True)
        emit('SmokedTailLens'+str(side),v,f,'lens_red')
        inner=rounded(cx,cy,.519,.057,.015,10)
        v,f=ring([np.array([[x,y,rear_z(x,y)+.007] for x,y in outer]),np.array([[x,y,rear_z(x,y)+.008] for x,y in inner])])
        emit('TailLightGuide'+str(side),v,f,'red','tail_left' if side<0 else 'tail_right')
        path=rounded(cx+side*.125,cy,.055,.022,.007,6)
        v,f=disk(path,lambda x,y:rear_z(x,y)+.0085,True)
        emit('ReverseChamber'+str(side),v,f,'reverse')

    # Rolled oval exhaust tips, black inside; no thin intersecting source tubes.
    for side in [-1,1]:
        cx=side*.520+.005;cy=.351
        loops=[]
        for rx,ry,z in [(.111,.039,2.145),(.113,.041,2.207),(.110,.039,2.219),(.103,.032,2.219),(.101,.030,2.145)]:
            loops.append(np.c_[cx+rx*np.cos(theta),cy+ry*np.sin(theta),np.full(count,z)])
        v,f=ring(loops);emit('RolledExhaustTip'+str(side),v,f,'chrome')
        path=np.c_[cx+.102*np.cos(theta),cy+.031*np.sin(theta)]
        v,f=disk(path,lambda x,y:2.148,True);emit('ExhaustCavity'+str(side),v,f,'rubber')


def vent_paths():
    # Stock Hellcat proportions, with softly rounded ends. These are holes in
    # the new skin, not raised scoops or black faces on top of the paint.
    return [rounded(0,-1.73,.33,.070,.020,8),
            rounded(-.535,-1.558,.176,.110,.025,8),
            rounded(.535,-1.558,.176,.110,.025,8)]


def vents(add, paths, height):
    for index,path in enumerate(paths):
        centre=path.mean(0)
        inner=centre+(path-centre)*np.array([.93,.85])
        outer=np.array([[x,height(x,z),z] for x,z in path])
        lower=np.array([[x,height(x,z)-.007,z] for x,z in inner])
        v,f=ring([outer,lower]);add('RecessedVentPaintReturn'+str(index),v,f,'paint','hood')
        vertices=lower.tolist()+[[centre[0],height(*centre)-.008,centre[1]]]
        faces=[(len(path),i,(i+1)%len(path)) for i in range(len(path))]
        add('RecessedVentBed'+str(index),vertices,faces,'dark','hood')
        width=np.ptp(inner[:,0])*.89
        zmin,zmax=inner[:,1].min(),inner[:,1].max()
        for slat,z in enumerate(np.linspace(zmin+.012,zmax-.012,3 if index==0 else 4)):
            x=centre[0]
            points=[[x-width/2,height(x-width/2,z)-.003,z-.0025],
                    [x+width/2,height(x+width/2,z)-.003,z-.0025],
                    [x+width/2,height(x+width/2,z)-.004,z+.0025],
                    [x-width/2,height(x-width/2,z)-.004,z+.0025]]
            add('VentVane'+str(index)+'_'+str(slat),points,[(0,1,2),(0,2,3)],'vent_metal','hood')
