"""Offline nose downturn and coordinated upper-fascia taper.

Operate after the overhang correction, on every existing exterior layer. The
projectors translate inward without squeezing their circular cross-sections.
Topology, contour-pair attributes and the rearward shoulder stay intact.
"""
import numpy as np
from challenger_side_surface import ramp, unit


def leading_roll(z):
    return .008 * (1 - ramp(-2.11, -1.93, z))



def point_map(points, corner=True):
    p = np.asarray(points)
    q = p.copy()
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    upper = ramp(.32, .60, y)
    # Zero first and second derivatives where the new bonnet run begins;
    # increasing slope towards the leading edge prevents another lifted tip.
    run = np.maximum((-z - 1.62) / .50, 0)
    q[:, 1] -= .054 * run**3 * upper
    # The old broad crown remained inflated behind the leading roll. Thin the
    # upper sheet locally while keeping the face, lower fascia and rearward
    # shoulder attached. Both end blends have zero first/second derivatives.
    crown = ramp(-2.115, -2.015, z) * (1-ramp(-1.90, -1.68, z))
    q[:, 1] -= .024 * crown * ramp(.60, .85, y)
    # Carry the leading roll through the crown's front fade to the tip.
    if corner:
        q[:, 1] -= leading_roll(z) * ramp(.64, .74, abs(x)) * ramp(.60, .85, y)
    # Integral of the quintic ramp: linear grille compression transitions
    # smoothly to a rigid 45 mm inward shift throughout each lamp assembly.
    a = np.abs(x)
    t = np.clip((a - .40) / .10, 0, 1)
    integral = .10 * (2.5*t**4 - 3*t**5 + t**6) + np.maximum(a - .50, 0)
    inset = .10 * (a - integral)
    taper = (1 - ramp(-2.10, -1.72, z)) * upper
    q[:, 0] -= np.sign(x) * inset * taper
    q[:, 0] -= np.sign(x) * .04*(a-integral) * (1-ramp(-2.10,-1.72,z)) * ramp(.50,.64,y)
    return q


def normal_map(points, normals, corner=True):
    e = .000025
    columns = []
    for axis in range(3):
        d = np.zeros(3)
        d[axis] = e
        columns.append((point_map(points+d,corner)-point_map(points-d,corner))/(2*e))
    a, b, c = columns
    determinant = np.sum(a*np.cross(b, c), axis=1)
    assert determinant.min() > .65, 'Nose chart must preserve orientation and thickness'
    n = np.asarray(normals)
    return unit(n[:, 0, None]*np.cross(b, c)
                + n[:, 1, None]*np.cross(c, a)
                + n[:, 2, None]*np.cross(a, b))


def finish(exports):
    for obj in exports:
        mesh = obj.data
        p = np.asarray([v.co[:] for v in mesh.vertices])[:, [0, 2, 1]] * [1, 1, -1]
        loops = np.asarray([loop.vertex_index for loop in mesh.loops])
        n = np.asarray([corner.vector[:] for corner in mesh.corner_normals])[:, [0, 2, 1]] * [1, 1, -1]
        corner = obj.name in ['body__paint','hood__paint','body__contour','hood__dark']
        q = point_map(p,corner)
        nn = normal_map(p[loops], n,corner)
        mesh.vertices.foreach_set('co', (q[:, [0, 2, 1]] * [1, -1, 1]).ravel())
        mesh.update()
        mesh.normals_split_custom_set((nn[:, [0, 2, 1]] * [1, -1, 1]).tolist())
