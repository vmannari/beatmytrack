"""Offline repair of the Challenger leading roll and front-quarter cracks."""
import numpy as np
from challenger_side_surface import Curve, ramp, unit


def cut_height(x):
    return .795-.012*(np.asarray(x)/.78)**6


def tree_for(values):
    from mathutils.bvhtree import BVHTree
    points = values[:, :, :3].reshape(-1, 3)
    return BVHTree.FromPolygons(points.tolist(), np.arange(len(points)).reshape(-1, 3).tolist(), all_triangles=True)


class LeadingRoll:
    REAR = -1.990

    def __init__(self, body, hood, outline):
        from mathutils import Vector
        from mathutils.geometry import convex_hull_2d
        self.body_tree = tree_for(body)
        self.hood_tree = tree_for(hood)
        self.outline = np.asarray(outline)
        samples = []
        for x in np.arange(0, .811, .0025):
            hit, *_ = self.body_tree.ray_cast((float(x), float(cut_height(x)), -3), (0,0,1), 1.05)
            if hit is not None and hit.z < self.rear_z(x)-.001:
                samples.append([float(x), float(hit.z)])
        assert len(samples) > 250, 'The leading edge needs measured frontal support'
        samples = np.asarray(samples)
        # A convex plan envelope bridges source cracks without copying their
        # inward steps into the replacement roll.
        samples = np.concatenate([samples, samples*[-1,1]])
        hull_ids = convex_hull_2d([Vector(row.tolist()) for row in samples])
        hull = samples[hull_ids]
        centre = samples.mean(0)
        lines = []
        for a,b in zip(hull,np.roll(hull,-1,axis=0)):
            edge = b-a
            normal = np.array([edge[1],-edge[0]])
            if normal@(centre-a) > 0:normal *= -1
            if normal[1] < -.01*np.linalg.norm(normal):
                lines.append([float(a[1]-edge[1]/edge[0]*a[0]), float(edge[1]/edge[0])])
        self.front_lines = np.asarray(lines)
        self.maximum_x = float(samples[:,0].max())
        # The final section terminates on the measured side where the cut
        # height meets the accepted upper fender.
        low,high=.70,.82
        for _ in range(30):
            middle=(low+high)*.5
            hit,*_=self.body_tree.ray_cast((middle,2,self.REAR),(0,-1,0),2)
            if hit is not None and hit.y>cut_height(middle):low=middle
            else:high=middle
        self.rear_width=(low+high)*.5
        xs=np.linspace(0,self.rear_width,97)
        zs=np.minimum(self.front_z(xs),self.REAR)
        # Parameterize the whole front-and-corner boundary by arc length.
        front=np.c_[xs,zs]
        front[-1]=[self.rear_width,self.REAR]
        distance=np.r_[0,np.cumsum(np.linalg.norm(np.diff(front,axis=0),axis=1))]
        self.front_x=Curve(distance/distance[-1],front[:,0])
        self.front_at_z=Curve(distance/distance[-1],front[:,1])

    def rear_z(self,x):
        a=self.outline;b=np.roll(a,-1,axis=0)
        crossing=((a[:,0]<=x)&(b[:,0]>=x))|((a[:,0]>=x)&(b[:,0]<=x))
        ids=np.flatnonzero(crossing&(abs(b[:,0]-a[:,0])>1e-9))
        if not len(ids):return self.REAR
        t=(x-a[ids,0])/(b[ids,0]-a[ids,0])
        leading=float(np.min(a[ids,2]+t*(b[ids,2]-a[ids,2])))
        return min(self.REAR,leading+.005)

    def front_z(self,x):
        x=np.asarray(x)
        bounds=self.front_lines[:,0]+x[...,None]*self.front_lines[:,1]
        maximum=bounds.max(-1)
        temperature=.0006
        return maximum+temperature*np.log(np.exp((bounds-maximum[...,None])/temperature).sum(-1))

    def point(self,u,v):
        controls=self.curves(float(u))
        weights=np.array([(1-v)**3,3*v*(1-v)**2,3*v*v*(1-v),v**3])
        point=weights@controls
        hit,*_=self.hood_tree.ray_cast((float(point[0]),2,float(point[2])),(0,-1,0),2)
        if hit is not None:point[1]=min(point[1],float(hit.y)-.0015)
        return point

    def normal(self,u,v):
        u=float(np.clip(u,.00001,.9999));v=float(np.clip(v,.00001,.99999))
        step=.00001
        du=self.point(u+step,v)-self.point(u-step,v)
        dv=self.point(u,v+step)-self.point(u,v-step)
        return unit(np.cross(dv,du))

    def curves(self,u):
        x=float(self.front_x(u));z=float(self.front_at_z(u))
        a=np.array([x,float(cut_height(x)),z])
        rear_x=float(self.rear_width*u)
        rear_z=float(self.rear_z(rear_x))
        hit,normal,*_=self.hood_tree.ray_cast((rear_x,2,rear_z),(0,-1,0),2)
        if hit is not None:
            b=np.array([rear_x,float(hit.y)-.0015,rear_z])
            rear_normal=np.array(normal)
        else:
            hit,normal,*_=self.body_tree.ray_cast((rear_x,2,rear_z),(0,-1,0),2)
            assert hit is not None,'The rear of the roll needs an existing skin'
            b=np.array([rear_x,float(hit.y),rear_z]);rear_normal=np.array(normal)
        if u>.999999:
            a=b.copy()
        step=.0001
        dx=float(self.front_x(min(1,u+step))-self.front_x(max(0,u-step)))
        dz=float(self.front_at_z(min(1,u+step))-self.front_at_z(max(0,u-step)))
        front_normal=unit(np.array([dz,0,-dx]))
        tangent=np.array([dx,0,dz])
        start=unit(np.cross(tangent,front_normal))
        chord=b-a
        finish=unit(chord-np.asarray(rear_normal)*float(np.asarray(rear_normal)@chord))
        if finish@(b-a)<0:finish *= -1
        rise=max(0,float(b[1]-a[1]));span=float(np.linalg.norm(b-a))
        first=a+start*(.55*rise/max(float(start[1]),.1))
        last=b-finish*min(.35*span,.35*rise/max(float(finish[1]),.01))
        return np.asarray([a,first,last,b])

    def rebuild(self,body,simple):
        import challenger_clean_panels as panels
        positive=body[(body[:,:,0].min(1)>=-1e-7)&(body[:,:,0].max(1)>1e-7)]
        axis=body[abs(body[:,:,0]).max(1)<=1e-7]
        kept=[]
        for face in positive:
            rear=np.array([self.rear_z(x) for x in face[:,0]])
            extended=np.c_[face,face[:,1]-cut_height(face[:,0]),face[:,2]-rear]
            kept.extend(piece[:,:6] for piece in panels._subtract_box(extended,[(6,0,2),(7,-2,0)]))
        kept=np.asarray(kept)
        across=np.array([0,.08,.16,.24,.32,.40,.48,.56,.64,.70,.75,.80,.84,.88,.91,.94,.96,.98,1.0])
        if not simple:across=np.unique(np.r_[across,(across[:-1]+across[1:])*.5])
        along=np.array([0,.25,.55,.80,1.0])
        points=np.asarray([[self.point(u,v) for v in along] for u in across])
        normals=np.asarray([[self.normal(u,v) for v in along] for u in across])
        triangles=[]
        for i in range(len(across)-1):
            for j in range(len(along)-1):
                for ids in [[(i,j),(i+1,j),(i+1,j+1)],[(i,j),(i+1,j+1),(i,j+1)]]:
                    face=np.asarray([np.r_[points[a,b],normals[a,b]] for a,b in ids])
                    cross=np.cross(face[1,:3]-face[0,:3],face[2,:3]-face[0,:3])
                    if np.linalg.norm(cross)<1e-11:continue
                    if cross@face[:,3:].mean(0)<0:face=face[::-1]
                    triangles.append(face)
        # Existing cut stations lie on the same sampled leading boundary.
        edge=points[:,0]
        moved=0.0
        for vertex in kept.reshape(-1,6):
            x,y,z=vertex[:3]
            if z>self.rear_z(x)+1e-6 or abs(y-cut_height(x))>.00005:continue
            best=None
            for i,(a,b) in enumerate(zip(edge[:-1],edge[1:])):
                segment=b-a;t=float(np.clip((vertex[:3]-a)@segment/max(segment@segment,1e-20),0,1))
                q=a+t*segment;distance=float(np.linalg.norm(q-vertex[:3]))
                if best is None or distance<best[0]:best=(distance,q,i,t)
            if best[0]<.030:
                moved=max(moved,best[0]);vertex[:3]=best[1]
                vertex[3:]=unit(normals[best[2],0]*(1-best[3])+normals[best[2]+1,0]*best[3])
        right=np.concatenate([kept,np.asarray(triangles)])
        left=right[:,::-1].copy();left[:,:,0]*=-1;left[:,:,3]*=-1
        result=np.concatenate([right,left,axis])
        return result,{'before':len(body),'after':len(result),'leading_triangles':2*len(triangles),'maximum_boundary_refit_metres':moved,'rear_width':self.rear_width}
