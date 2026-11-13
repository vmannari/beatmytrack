"""Offline mesh operations for the static driver; numpy only, no runtime code."""
import numpy as np


def subdivide(vertices, faces, levels=1):
    """Split long source triangles before bending, without shrinking their shape."""
    for _ in range(levels):
        edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
        unique, inverse = np.unique(edges, axis=0, return_inverse=True)
        mid = inverse.reshape(3, -1).T + len(vertices)
        a, b, c = faces.T
        ab, bc, ca = mid.T
        faces = np.concatenate([np.c_[a, ab, ca], np.c_[ab, b, bc], np.c_[ca, bc, c], np.c_[ab, bc, ca]])
        vertices = np.concatenate([vertices, vertices[unique].mean(axis=1)])
    return vertices, faces


def normals(vertices, faces):
    face = np.cross(vertices[faces[:, 1]]-vertices[faces[:, 0]], vertices[faces[:, 2]]-vertices[faces[:, 0]])
    result = np.zeros_like(vertices)
    for axis in range(3):
        np.add.at(result, faces[:, axis], face)
    result /= np.maximum(np.linalg.norm(result, axis=1, keepdims=True), 1e-12)
    return result


def union_cloth(parts, step=.006):
    """Union closed garment sections, then reconstruct one continuous surface.

    The original has capped, overlapping sleeve/torso/trouser pieces. Smoothing
    those pieces independently opens cracks. Rasterized winding followed by a
    compact separable filter joins the actual occupied volumes instead.
    """
    all_points = np.concatenate([v for v, _ in parts])
    origin = np.floor((all_points.min(0)-step*4)/step)*step
    shape = np.ceil((all_points.max(0)+step*4-origin)/step).astype(int)+1
    occupied = np.zeros(shape, dtype=bool)
    for vertices, faces in parts:
        crossing = np.zeros(shape, dtype=np.int16)
        local = (vertices-origin)/step
        for tri in local[faces]:
            a, b, c = tri
            determinant = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(determinant) < 1e-10:
                continue
            lo = np.maximum(np.ceil(tri[:, :2].min(0)).astype(int), 0)
            hi = np.minimum(np.floor(tri[:, :2].max(0)).astype(int), shape[:2]-1)
            x, y = np.meshgrid(np.arange(lo[0], hi[0]+1), np.arange(lo[1], hi[1]+1), indexing='ij')
            xx, yy = x+1.37e-4, y+2.71e-4
            u = ((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/determinant
            v = ((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/determinant
            inside = (u >= 0) & (v >= 0) & (u+v <= 1)
            z = np.clip(np.ceil(u*a[2]+v*b[2]+(1-u-v)*c[2]).astype(int), 0, shape[2]-1)
            np.add.at(crossing, (x[inside], y[inside], z[inside]), 1 if determinant > 0 else -1)
        occupied |= np.cumsum(crossing, axis=2) != 0
    field = occupied.astype(np.float32)
    kernel = [(.0625, -2), (.25, -1), (.375, 0), (.25, 1), (.0625, 2)]
    for _ in range(4):
        for axis in range(3):
            field = sum(weight*np.roll(field, offset, axis=axis) for weight, offset in kernel)
    # Six consistent tetrahedra per cube avoid ambiguous marching-cube faces.
    corners = np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]])
    samples = np.stack([field[x:shape[0]-1+x, y:shape[1]-1+y, z:shape[2]-1+z]
                        for x, y, z in corners], axis=-1)
    boundary = (samples.min(-1) < .45) & (samples.max(-1) >= .45)
    bases = np.array(np.nonzero(boundary)).T
    samples = samples[boundary]
    triangles = []
    for tet in [[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6],[0,5,1,6]]:
        value = samples[:, tet]
        for mask in range(1, 15):
            inside = [i for i in range(4) if mask & (1 << i)]
            outside = [i for i in range(4) if i not in inside]
            selected = (np.sum((value >= .45)*(1 << np.arange(4)), axis=1) == mask)
            if not selected.any():
                continue
            p = bases[selected, None, :]+corners[tet][None, :, :]
            v = value[selected]
            def edge(a, b):
                t = (.45-v[:, a])/(v[:, b]-v[:, a])
                return p[:, a]+t[:, None]*(p[:, b]-p[:, a])
            if len(inside) == 1:
                faces = [np.stack([edge(inside[0], j) for j in outside], axis=1)]
            elif len(inside) == 3:
                faces = [np.stack([edge(outside[0], j) for j in inside], axis=1)]
            else:
                a,b = inside; c,d = outside
                ac,ad,bc,bd = edge(a,c),edge(a,d),edge(b,c),edge(b,d)
                faces = [np.stack([ac,ad,bc],axis=1), np.stack([ad,bd,bc],axis=1)]
            outward = p[:, outside].mean(1)-p[:, inside].mean(1)
            for f in faces:
                wrong = np.sum(np.cross(f[:,1]-f[:,0],f[:,2]-f[:,0])*outward,axis=1) < 0
                f[wrong] = f[wrong][:, [0,2,1]]
                triangles.append(f)
    points = np.concatenate(triangles).reshape(-1,3)*step+origin
    vertices, inverse = np.unique(points.round(7), axis=0, return_inverse=True)
    faces = inverse.reshape(-1,3)
    # Relax the voxel sampling only, far below a garment's thickness.
    edges = np.unique(np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1),axis=0)
    count = np.bincount(edges.ravel(),minlength=len(vertices))[:,None]
    for _ in range(6):
        average = np.zeros_like(vertices)
        np.add.at(average, edges[:,0],vertices[edges[:,1]])
        np.add.at(average, edges[:,1],vertices[edges[:,0]])
        vertices = .65*vertices+.35*average/np.maximum(count,1)
    return vertices, faces


def front_seam(vertices, faces, samples, radius=.0015):
    """A narrow sewn/zipper strip fitted to the reconstructed chest surface."""
    tri = vertices[faces]
    a,b,c = tri[:,0],tri[:,1],tri[:,2]
    det = (b[:,1]-c[:,1])*(a[:,0]-c[:,0])+(c[:,0]-b[:,0])*(a[:,1]-c[:,1])
    valid = np.abs(det)>1e-12
    a,b,c,det = a[valid],b[valid],c[valid],det[valid]
    centers=[]
    for x,y in samples:
        u=((b[:,1]-c[:,1])*(x-c[:,0])+(c[:,0]-b[:,0])*(y-c[:,1]))/det
        v=((c[:,1]-a[:,1])*(x-c[:,0])+(a[:,0]-c[:,0])*(y-c[:,1]))/det
        hit=(u>=0)&(v>=0)&(u+v<=1)
        if not hit.any():
            raise ValueError('Tailoring strip missed chest surface')
        z=(u*a[:,2]+v*b[:,2]+(1-u-v)*c[:,2])[hit].min()
        centers.append([x,y,z-radius*.55])
    centers=np.array(centers)
    tangent=np.gradient(centers,axis=0)
    tangent/=np.linalg.norm(tangent,axis=1,keepdims=True)
    right=np.cross(tangent,np.array([0,0,1]))
    right/=np.linalg.norm(right,axis=1,keepdims=True)
    normal=np.cross(right,tangent)
    angle=np.arange(8)*np.pi/4
    p=(centers[:,None,:]+radius*(right[:,None,:]*np.cos(angle)[None,:,None]+
                               normal[:,None,:]*np.sin(angle)[None,:,None])).reshape(-1,3)
    f=[]
    for j in range(len(centers)-1):
        for i in range(8):
            a,b=j*8+i,j*8+(i+1)%8
            f.extend([[a,b,b+8],[a,b+8,a+8]])
    return p,np.array(f)


def two_bone(start, end, length_a, length_b, pole):
    axis = end-start
    distance = np.linalg.norm(axis)
    if distance >= length_a+length_b:
        raise ValueError(f'Unreachable control: {distance} >= {length_a+length_b}')
    axis /= distance
    bend = pole-start
    bend -= axis*np.dot(bend,axis)
    bend /= np.linalg.norm(bend)
    along = (length_a**2-length_b**2+distance**2)/(2*distance)
    return start+along*axis+np.sqrt(length_a**2-along**2)*bend
