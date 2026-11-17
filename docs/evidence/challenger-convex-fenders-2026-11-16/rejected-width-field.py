"""Offline convex upper-fender field and thickness-preserving displacement."""
import numpy as np
from challenger_side_surface import ramp, unit


class ConvexFender:
    TEMPERATURE = .0015

    def __init__(self, values, planes=None):
        from mathutils.bvhtree import BVHTree
        self.values = np.asarray(values)
        points = self.values[:, :, :3]
        cross = np.cross(points[:, 1] - points[:, 0], points[:, 2] - points[:, 0])
        centre = points.mean(1)
        outside = (cross[:, 0] > 1e-12) & (centre[:, 0] > .55)
        flat = points.reshape(-1, 3)
        faces = np.arange(len(flat)).reshape(-1, 3)
        self.original = BVHTree.FromPolygons(flat.tolist(), faces[outside].tolist(), all_triangles=True)
        if planes is None:
            import bmesh
            selected = outside & (centre[:, 1] > .73) & (centre[:, 2] > -2.12) & (centre[:, 2] < -.70)
            samples = np.unique(np.round(points[selected].reshape(-1, 3), 7), axis=0)
            mesh = bmesh.new()
            for point in samples:
                mesh.verts.new(point)
            bmesh.ops.convex_hull(mesh, input=list(mesh.verts), use_existing_faces=False)
            mesh.normal_update()
            rows = []
            interior = samples.mean(0)
            for face in mesh.faces:
                normal = np.array(face.normal)
                if normal @ (interior - np.array(face.verts[0].co)) > 0:
                    normal = -normal
                if normal[0] > .05:
                    distance = float(np.max(samples @ normal))
                    rows.append([distance / normal[0], -normal[1] / normal[0], -normal[2] / normal[0]])
            mesh.free()
            planes = np.unique(np.round(rows, 7), axis=0)
        self.planes = np.asarray(planes)
        assert len(self.planes) >= 4

    def width(self, y, z):
        y, z = np.broadcast_arrays(y, z)
        planes = self.planes
        bounds = planes[:, 0] + y[..., None]*planes[:, 1] + z[..., None]*planes[:, 2]
        lowest = bounds.min(-1)
        weights = np.exp(-(bounds - lowest[..., None])/self.TEMPERATURE)
        total = weights.sum(-1)
        width = lowest - self.TEMPERATURE*np.log(total/len(planes))
        dy = np.sum(weights*planes[:, 1], axis=-1)/total
        dz = np.sum(weights*planes[:, 2], axis=-1)/total
        return width, dy, dz

    def old_width(self, point):
        from mathutils import Vector
        x, y, z = abs(point[0]), point[1], point[2]
        hit, normal, *_ = self.original.ray_cast((2, float(y), float(z)), (-1, 0, 0), 2)
        if hit is None:
            hit, normal, _, distance = self.original.find_nearest(Vector((float(x), float(y), float(z))))
            if hit is None or distance > .055 or normal.x < .05:
                return None
        if normal.x < .05:
            return None
        dy, dz = -normal.y/normal.x, -normal.z/normal.x
        width = hit.x + dy*(y-hit.y) + dz*(z-hit.z)
        return width, dy, dz

    @staticmethod
    def weight(point, previous):
        x, y, z = abs(point[0]), point[1], point[2]
        distance = abs(x-previous)
        return (ramp(.60, .66, x)*ramp(.73, .78, y)*ramp(-2.105, -2.075, z)
                *(1-ramp(-.82, -.70, z))*(1-ramp(.045, .065, distance)))

    def map(self, points, normals=None, exterior=None):
        points = np.asarray(points)
        moved = points.copy()
        result_normals = None if normals is None else np.asarray(normals).copy()
        maximum = 0.0
        for index, point in enumerate(points):
            x, y, z = point
            if abs(x) <= .60 or y <= .73 or z <= -2.105 or z >= -.70:
                continue
            previous = self.old_width(point)
            if previous is None:
                continue
            weight = float(self.weight(point, previous[0]))
            if weight <= 0:
                continue
            width, dy, dz = self.width(y, z)
            delta = float(width-previous[0])
            sign = np.sign(x)
            moved[index, 0] += sign*weight*delta
            maximum = max(maximum, abs(weight*delta))
            if normals is None:
                continue
            step = .000025
            derivative = []
            for axis in range(3):
                offset = np.zeros(3);offset[axis] = step
                old_plus = previous[0] + previous[1]*offset[1] + previous[2]*offset[2]
                old_minus = previous[0] - previous[1]*offset[1] - previous[2]*offset[2]
                derivative.append(float((self.weight(point+offset, old_plus)-self.weight(point-offset, old_minus))/(2*step)))
            a = 1 + sign*delta*derivative[0]
            b = sign*(weight*(dy-previous[1]) + delta*derivative[1])
            c = sign*(weight*(dz-previous[2]) + delta*derivative[2])
            normal = normals[index]
            transported = unit(np.array([normal[0], a*normal[1]-b*normal[0], a*normal[2]-c*normal[0]]))
            if exterior is not None and exterior[index] and weight > .999:
                transported = unit(np.array([sign, -float(dy), -float(dz)]))
            result_normals[index] = transported
        return moved, result_normals, maximum
