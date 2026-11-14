"""Offline fairing and reduction of the joined Challenger painted shell.

Work on the complete material batch, after all fitted-panel transformations.
Coincident panel boundaries share vertices and one geometric tangent field.
Openings, returns and sharp character edges remain constrained during reduction.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree
from challenger_reference_geometry import ReferenceBody, curve


def shoulder_strip(reference, points, faces, normals, simple):
    """Replace the patched character-line band by one chart on each side.

    Clip complete old triangles, keeping their crossings as constrained edge
    stations. The regular replacement follows the same reference crease and
    its analytic transverse section, rather than independent component fits.
    The narrow lower margin stays above the wheel apertures.
    """
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    from mathutils.bvhtree import BVHTree
    triangles = np.c_[points, normals].reshape(-1, 3, 6)
    lower, upper, start, end = -.020, .055, -1.60, 2.075
    stats = []
    original_outer = BVHTree.FromPolygons(points.tolist(), np.asarray(faces).tolist(), all_triangles=True)

    def width(y, z, sign):
        y, z = np.broadcast_arrays(y, z)
        d = y-reference.crease(z)
        value = np.zeros_like(y)
        for offset, weight in [(-.10, 1/16), (-.05, 4/16), (0, 6/16), (.05, 4/16), (.10, 1/16)]:
            value += weight*reference.width(reference.crease(z+offset)+d, z+offset)
        blend = _ramp(start, start+.15, z)*(1-_ramp(end-.15, end, z))
        flat_value, flat_y, flat_z, flat_blend = [a.reshape(-1) for a in [value, y, z, blend]]
        for i in np.flatnonzero(flat_blend < 1):
            hit, *_ = original_outer.ray_cast((reference.cx+sign*2, float(flat_y[i]), float(flat_z[i])), (-sign, 0, 0), 4)
            if hit is not None and sign*(hit.x-reference.cx) > .60:
                old = sign*(hit.x-reference.cx)
                flat_value[i] = old+(flat_value[i]-old)*flat_blend[i]
        return value

    def sample(d, z, sign):
        y = reference.crease(z)+d
        x = reference.cx+sign*width(y, z, sign)
        p = np.stack([x, y, z], axis=-1)
        e = .000025
        dy = (width(y+e, z, sign)-width(y-e, z, sign))/(2*e)
        dz = (width(y, z+e, sign)-width(y, z-e, sign))/(2*e)
        n = np.stack([np.full_like(y, sign), -dy, -dz], axis=-1)
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-12)
        return p, n

    for sign in [-1, 1]:
        remaining = []
        boundary = []
        removed = 0
        for triangle in triangles:
            z = triangle[:, 2]
            d = triangle[:, 1]-reference.crease(z)
            if (np.min((triangle[:, 0]-reference.cx)*sign) < .64
                    or np.mean(triangle[:, 3])*sign < .15
                    or d.min() > upper or d.max() < lower
                    or z.min() > end or z.max() < start):
                remaining.append(triangle)
                continue
            polygon = np.c_[triangle, d, z]
            for axis, value, greater in [(6, lower, True), (6, upper, False),
                                         (7, start, True), (7, end, False)]:
                inside, outside = [], []
                for i, a in enumerate(polygon):
                    b = polygon[(i+1) % len(polygon)]
                    da, db = a[axis]-value, b[axis]-value
                    ain, bin = (da >= 0, db >= 0) if greater else (da <= 0, db <= 0)
                    (inside if ain else outside).append(a)
                    if ain != bin:
                        v = a+(b-a)*(da/(da-db))
                        v[:3], v[3:6] = sample(np.array(v[6]), np.array(v[7]), sign)
                        inside.append(v)
                        outside.append(v)
                for i in range(1, len(outside)-1):
                    remaining.append(np.asarray([outside[0][:6], outside[i][:6], outside[i+1][:6]]))
                polygon = np.asarray(inside)
                if len(polygon) < 3:
                    break
            if len(polygon) >= 3:
                removed += 1
                for p in polygon:
                    if min(abs(p[6]-lower), abs(p[6]-upper), abs(p[7]-start), abs(p[7]-end)) < 1e-7:
                        boundary.append(p[6:8])
        boundary.extend([[lower, start], [upper, start], [upper, end], [lower, end]])
        boundary = np.unique(np.round(boundary, 9), axis=0)
        centre = np.array([(lower+upper)*.5, (start+end)*.5])
        boundary = boundary[np.argsort(np.arctan2((boundary[:, 1]-centre[1])/(end-start),
                                                  (boundary[:, 0]-centre[0])/(upper-lower)))]
        samples = boundary.tolist()
        constraints = [(i, (i+1) % len(boundary)) for i in range(len(boundary))]
        for d in [-.012, -.006, -.003, -.0015, -.00075, 0, .00075, .0015, .003, .006, .012, .025, .040]:
            previous = None
            for z in np.linspace(start, end, 64 if simple else 96):
                index = len(samples)
                samples.append([d, float(z)])
                if previous is not None:
                    constraints.append((previous, index))
                previous = index
        uv, _, new_faces, *_ = delaunay_2d_cdt([Vector(p) for p in samples], constraints, [], 0, 1e-8, False)
        uv = np.asarray(uv)
        p, n = sample(uv[:, 0], uv[:, 1], sign)
        for face in new_faces:
            ids = np.asarray(face)
            if np.cross(p[ids[1]]-p[ids[0]], p[ids[2]]-p[ids[0]])@n[ids].mean(0) < 0:
                ids = ids[::-1]
            remaining.append(np.c_[p[ids], n[ids]])
        stats.append({'side': sign, 'replaced_triangles': removed,
                      'new_triangles': len(new_faces), 'boundary_stations': len(boundary)})
        triangles = np.asarray(remaining)
    values = triangles.reshape(-1, 6)
    return values[:, :3], np.arange(len(values)).reshape(-1, 3), values[:, 3:], stats


def fit_contours(paint, contour):
    """Seat the flush markings on the final reduced shell, not an older patch."""
    from mathutils.bvhtree import BVHTree
    paint.data.calc_loop_triangles()
    bvh = BVHTree.FromPolygons([v.co[:] for v in paint.data.vertices],
                              [tuple(t.vertices) for t in paint.data.loop_triangles], all_triangles=True)
    fitted = 0
    for vertex in contour.data.vertices:
        p = vertex.co
        sign = 1 if p.x > 0 else -1
        hit, normal, *_ = bvh.ray_cast((sign*2, p.y, p.z), (-sign, 0, 0), 4)
        if hit is not None and sign*hit.x > .60 and abs(hit.x-p.x) < .025:
            p.x = hit.x+sign*.0018
            fitted += 1
    contour.data.update()
    return fitted


def _ramp(a, b, value):
    t = np.clip((value-a)/(b-a), 0, 1)
    return t*t*t*(10+t*(-15+6*t))


def refine(obj, simple):
    mesh = obj.data
    mesh.calc_loop_triangles()
    before = len(mesh.loop_triangles)
    # Retain the authored curvature field: the reduced source has small hidden
    # returns whose face normals are unsuitable as exterior paint tangents.
    reference = obj.copy()
    reference.data = mesh.copy()
    bpy.context.scene.collection.objects.link(reference)
    reference.hide_set(True)
    reference.hide_render = True
    coordinates = np.asarray([mesh.vertices[loop.vertex_index].co[:] for loop in mesh.loops])
    authored = np.asarray([n.vector[:] for n in mesh.corner_normals])
    records, mapping = np.unique(np.round(np.c_[coordinates, authored], 7), axis=0, return_inverse=True)
    tree = KDTree(len(records))
    for index, point in enumerate(records[:, :3]):
        tree.insert(point, index)
    tree.balance()
    filtered = records[:, 3:].copy()
    cosine = math.cos(math.radians(18))
    for index, row in enumerate(records):
        px, pz, py = row[:3]
        if py >= 1.04:
            continue
        crease = float(curve(np.array(-pz), ReferenceBody.Z, ReferenceBody.Y))
        if -1.60 <= -pz <= 2.075 and -.02001 <= py-crease <= .05501:
            continue
        weight = float(_ramp(.30, .40, py)*(1-_ramp(1.07, 1.15, py)))
        weight *= max(float(_ramp(.62, .76, abs(px))), float(_ramp(1.90, 2.02, pz)))
        if weight < 1e-6:
            continue
        neighbours = tree.find_range(row[:3], .045)
        ids = np.asarray([item[1] for item in neighbours])
        distances = np.asarray([item[2] for item in neighbours])
        dot = records[ids, 3:]@row[3:]
        weights = (1-distances/.045)**2*np.clip((dot-cosine)/(1-cosine), 0, 1)**2
        normal = np.sum(records[ids, 3:]*weights[:, None], axis=0)
        normal /= max(np.linalg.norm(normal), 1e-12)
        normal = row[3:]*(1-weight)+normal*weight
        filtered[index] = normal/max(np.linalg.norm(normal), 1e-12)
    reference.data.normals_split_custom_set(filtered[mapping].tolist())
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000002)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.0000001)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    positions = np.asarray([v.co[:] for v in bm.verts])
    # Blender axes here are x, -longitudinal, height.
    x, z, y = positions[:, 0], -positions[:, 1], positions[:, 2]
    amount = _ramp(.30, .40, y)*(1-_ramp(1.07, 1.15, y))
    amount *= np.maximum(_ramp(.62, .76, abs(x)), 1-_ramp(-2.02, -1.90, z))
    amount *= _ramp(-1.70, -1.60, z)
    constrained = set()
    for edge in bm.edges:
        if not edge.is_manifold or edge.calc_face_angle(0) > math.radians(38):
            constrained.update(v.index for v in edge.verts)
    crease = curve(z, ReferenceBody.Z, ReferenceBody.Y)
    analytic = (z >= -1.60001)&(z <= 2.07501)&(y-crease >= -.02001)&(y-crease <= .05501)
    detail = analytic&((abs(y-crease) <= .00301)|(abs(y-crease+.020) < .00001)|
                       (abs(y-crease-.055) < .00001)|(z < -1.59999)|(z > 2.07499))
    constrained.update(np.flatnonzero(detail).tolist())
    constrained.update(np.flatnonzero(y >= 1.04).tolist())
    for axis in range(3):
        constrained.update(np.flatnonzero((positions[:, axis] == positions[:, axis].min())|
                                          (positions[:, axis] == positions[:, axis].max())).tolist())
    amount[list(constrained)] = 0
    amount[analytic] = 0
    edges = np.asarray([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    a = np.r_[edges[:, 0], edges[:, 1]]
    b = np.r_[edges[:, 1], edges[:, 0]]
    degree = np.bincount(a, minlength=len(positions))
    normals = np.asarray([v.normal[:] for v in bm.verts])
    original = positions.copy()
    # Paired Taubin steps suppress small waves without a one-way shrink. Only
    # the normal component moves: irregular old triangle spacing cannot slide
    # the arch outlines, seams or fittings along the panel.
    for _ in range(4):
        for step in [.45, -.47]:
            mean = np.zeros_like(positions)
            np.add.at(mean, a, positions[b])
            mean /= np.maximum(degree[:, None], 1)
            distance = np.sum((mean-positions)*normals, axis=1)
            positions += normals*(distance*amount*step)[:, None]
            delta = positions-original
            length = np.linalg.norm(delta, axis=1)
            positions = original+delta*np.minimum(1, .001/np.maximum(length, 1e-12))[:, None]
    for vertex, point in zip(bm.verts, positions):
        vertex.co = point
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(52))
    mesh.update()
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    group = obj.vertex_groups.new(name='PreserveShellBoundaries')
    group.add(list(range(len(mesh.vertices))), 1.0, 'REPLACE')
    if constrained:
        group.add(sorted(constrained), 0.0, 'REPLACE')
    reduction = obj.modifiers.new('Joined shell reduction', 'DECIMATE')
    reduction.ratio = .60 if simple else .63
    reduction.use_collapse_triangulate = True
    reduction.vertex_group = group.name
    reduction.vertex_group_factor = 1000
    bpy.ops.object.modifier_apply(modifier=reduction.name)
    transfer = obj.modifiers.new('Joined shell tangents', 'DATA_TRANSFER')
    transfer.object = reference
    transfer.use_loop_data = True
    transfer.data_types_loops = {'CUSTOM_NORMAL'}
    transfer.loop_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.datalayout_transfer(modifier=transfer.name)
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    bpy.data.objects.remove(reference, do_unlink=True)
    obj.data.calc_loop_triangles()
    obj.select_set(False)
    return {'before_triangles': before, 'after_triangles': len(obj.data.loop_triangles),
            'welded_vertices': len(original), 'constrained_vertices': len(constrained),
            'maximum_fairing_metres': float(np.max(np.linalg.norm(positions-original, axis=1)))}
