"""Offline shared front roll for the Challenger bonnet and fascia."""
import numpy as np
from challenger_side_surface import ramp, unit

def cut_height(x):
    return 0.795 - 0.012 * (np.asarray(x) / 0.78) ** 6

def tree_for(values):
    from mathutils.bvhtree import BVHTree
    points = values[:, :, :3].reshape(-1, 3)
    return BVHTree.FromPolygons(points.tolist(), np.arange(len(points)).reshape(-1, 3).tolist(), all_triangles=True)

class LeadingRoll:
    """Shared convex leading roll constrained by the retained fender surface."""
    REAR = -1.95

    def __init__(self, body, hood, crown=None):
        from mathutils import Vector
        from mathutils.geometry import convex_hull_2d
        self.body_tree = tree_for(body)
        self.hood_tree = tree_for(hood)
        self.back_tree = tree_for(np.concatenate([body, hood]))
        centre = self.old_height(0, self.REAR)[0]
        (low, high) = (0.72, 0.83)
        for _ in range(30):
            x = (low + high) * 0.5
            if self.old_height(x, self.REAR)[0] > cut_height(x):
                low = x
            else:
                high = x
        self.rear_width = (low + high) * 0.5
        from challenger_convex_fenders import ConvexFender
        self.crown = crown if crown is not None else ConvexFender(np.concatenate([body, hood]))
        p = body[:, :, :3]
        cross = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
        cross[cross[:, 1] < 0] *= -1
        belt = 0.767 + 0.038 * (p[:, :, 2] + 2.065) / 1.205
        selected = (p[:, :, 0].min(1) > 0.6) & (p[:, :, 0].mean(1) > 0.74) & (p[:, :, 0].max(1) < 0.89) & (body[:, :, 4].min(1) > 0.25) & (p[:, :, 1].min(1) > 0.74) & (p[:, :, 2].min(1) > -2.065 - 5e-05) & (p[:, :, 2].max(1) < -0.86) & (p[:, :, 1] >= belt - 5e-05).all(1) & (cross[:, 1] > 0.05 * np.linalg.norm(cross, axis=1))
        for index in np.flatnonzero(selected):
            centroid = p[index].mean(0)
            (hit, *_) = self.body_tree.ray_cast((float(centroid[0]), 2, float(centroid[2])), (0, -1, 0), 2)
            selected[index] = hit is not None and abs(hit.y - centroid[1]) < 3e-05
        n = cross[selected]
        slopes = -n[:, [0, 2]] / n[:, 1, None]
        samples = p[selected].reshape(-1, 3)
        offsets = np.max(samples[:, 1, None] - samples[:, [0, 2]] @ slopes.T, axis=0)
        self.crown_planes = np.c_[offsets, slopes]
        self.height_centre = centre
        samples = []
        for x in np.arange(0, self.rear_width, 0.0025):
            (hit, *_) = self.body_tree.ray_cast((float(x), float(cut_height(x)), -3), (0, 0, 1), 1.05)
            if hit is not None and hit.z < self.REAR:
                samples.append([float(x), float(hit.z)])
        samples.append([self.rear_width, self.REAR])
        samples = np.asarray(samples)
        samples = np.concatenate([samples, samples * [-1, 1]])
        hull = samples[convex_hull_2d([Vector(row.tolist()) for row in samples])]
        interior = samples.mean(0)
        lines = []
        for (a, b) in zip(hull, np.roll(hull, -1, axis=0)):
            edge = b - a
            normal = np.array([edge[1], -edge[0]])
            if normal @ (interior - a) > 0:
                normal *= -1
            if normal[1] < -0.01 * np.linalg.norm(normal):
                lines.append([a[1] - edge[1] / edge[0] * a[0], edge[1] / edge[0]])
        self.front_lines = np.asarray(lines)
        (sample_x, sample_z) = np.meshgrid(np.linspace(0, 0.65, 14), np.linspace(self.front_z(0), self.REAR, 13))
        delta = self.front_z(0) - self.REAR
        bend = (0.795 - centre - 0.12 * delta) / (delta * delta)
        distance = sample_z - self.REAR
        sample_y = centre + 0.12 * distance + bend * distance * distance - 0.02 * (sample_x / 0.8) ** 2
        offsets = np.max(sample_y.ravel()[:, None] - sample_x.ravel()[:, None] * self.crown_planes[:, 1] - sample_z.ravel()[:, None] * self.crown_planes[:, 2], axis=0)
        self.crown_planes[:, 0] = np.maximum(self.crown_planes[:, 0], offsets)

    def old_height(self, x, z, hood_only=False):
        tree = self.hood_tree if hood_only else self.back_tree
        (hit, normal, *_) = tree.ray_cast((float(x), 2, float(z)), (0, -1, 0), 2)
        if hit is None:
            return None
        return (float(hit.y), np.asarray(normal))

    def front_z(self, x):
        lines = self.front_lines[:, 0] + abs(x) * self.front_lines[:, 1]
        maximum = float(lines.max())
        temperature = 0.0005
        return maximum + temperature * np.log(np.exp((lines - maximum) / temperature).sum()) - 0.0005

    def height(self, x, z, body=False):
        front = self.front_z(0)
        delta = front - self.REAR
        slope = 0.12
        bend = (0.795 - self.height_centre - slope * delta) / (delta * delta)
        distance = z - self.REAR
        nose = self.height_centre + slope * distance + bend * distance * distance - 0.02 * (x / 0.8) ** 2
        if body:
            nose -= 0.0015
        fender = float(np.min(self.crown_planes[:, 0] + abs(x) * self.crown_planes[:, 1] + z * self.crown_planes[:, 2]))
        temperature = 0.0004
        lowest = min(nose, fender)
        y = lowest - temperature * np.log(np.exp((lowest - nose) / temperature) + np.exp((lowest - fender) / temperature))
        amount = float(ramp(-1.985, self.REAR, z) * (1 - ramp(0.5, 0.69, abs(x))))
        if amount > 0:
            previous = self.old_height(abs(x), z)
            if previous is not None:
                target = previous[0] - (0.0015 if body else 0)
                y = y * (1 - amount) + target * amount
        return float(y)

    def normal(self, x, z, body=False):
        if abs(x) >= 0.7:
            (_, dx, dz) = self.crown.height(abs(x), z)
            return unit(np.array([-np.sign(x) * float(dx), 1, -float(dz)]))
        step = 2e-05
        dx = (self.height(x + step, z, body) - self.height(x - step, z, body)) / (2 * step)
        dz = (self.height(x, z + step, body) - self.height(x, z - step, body)) / (2 * step)
        return unit(np.array([-dx, 1, -dz]))

    def point(self, x, v, body=False):
        z = self.front_z(x) + (self.REAR - self.front_z(x)) * (1.95 * v * v - 0.95 * v * v * v)
        y = self.height(x, z, body)
        return np.array([x, y, z])

    def map_hood(self, values):
        """Fit the leading bonnet while retaining its original intake and vents."""
        out = values.copy()
        maximum = 0.0
        for face in out:
            for vertex in face:
                (x, y, z) = vertex[:3]
                if z >= self.REAR or abs(x) >= self.rear_width:
                    continue
                previous = self.old_height(x, z, hood_only=True)
                if previous is None:
                    previous = self.old_height(x - np.sign(x) * 2e-06, z + 2e-06, hood_only=True)
                if previous is None:
                    continue
                delta = self.height(x, z) - previous[0]
                vertex[1] += delta
                maximum = max(maximum, abs(delta))
                if vertex[4] > 0.25:
                    weight = float(1 - ramp(-1.985, self.REAR, z))
                    vertex[3:] = unit(vertex[3:] * (1 - weight) + self.normal(x, z) * weight)
        from challenger_convex_fenders import convex_diagonals
        candidate = (np.max(abs(out[:, :, 0]), axis=1) < 0.65) & (out[:, :, 2].max(1) < -1.985) & (out[:, :, 4].min(1) > 0.25)
        active = []
        for index in np.flatnonzero(candidate):
            if max((abs(v[1] - self.height(v[0], v[2])) for v in out[index])) < 5e-05:
                active.append(index)
        if active:
            (packets, inverse) = np.unique(out[active].reshape(-1, 6), axis=0, return_inverse=True)
            faces = convex_diagonals(packets[:, :3], inverse.reshape(-1, 3))
            out[active] = packets[faces]
        from challenger_convex_fenders import convex_diagonals
        selected = (abs(out[:, :, 0]).max(1) < 0.65) & (out[:, :, 2].max(1) < -1.985) & (out[:, :, 4].min(1) > 0.25)
        for index in np.flatnonzero(selected):
            selected[index] = all((abs(v[1] - self.height(v[0], v[2])) < 2.5e-05 for v in out[index]))
        (packets, inverse) = np.unique(out[selected].reshape(-1, 6), axis=0, return_inverse=True)
        out[selected] = packets[convex_diagonals(packets[:, :3], inverse.reshape(-1, 3))]
        points = out[:, :, :3]
        cross = np.cross(points[:, 1] - points[:, 0], points[:, 2] - points[:, 0])
        size = np.linalg.norm(cross, axis=1)
        opposite = np.sum(out[:, :, 3:].mean(1) * cross, axis=1) < 0
        returned = (abs(cross[:, 1]) < 0.1 * size) & opposite & (size > 1e-11)
        out[returned, :, 3:] = unit(cross[returned])[:, None, :]
        return (out, maximum)

    def edge_height(self, x):
        return min(float(cut_height(x)), self.height(float(x), self.front_z(float(x)), body=True))

    def rebuild(self, body, simple):
        """Rebuild the upper nose and match its retained boundary stations."""
        import challenger_clean_panels as panels
        positive = body[(body[:, :, 0].min(1) >= -1e-07) & (body[:, :, 0].max(1) > 1e-07)]
        axis = body[abs(body[:, :, 0]).max(1) <= 1e-07]
        kept = []
        for face in positive:
            extended = np.c_[face, face[:, 1] - np.array([self.edge_height(x) for x in face[:, 0]])]
            kept.extend((piece[:, :6] for piece in panels._subtract_box(extended, [(6, 0, 2), (2, -3, self.REAR), (0, 0, self.rear_width)])))
        kept = np.asarray(kept)
        hidden = []
        for face in kept:
            points = face[:, :3]
            covered = points[:, 2].min() > -2.04 and points[:, 2].max() < -1.9 and (points[:, 1].min() > 0.73)
            if covered:
                for point in np.concatenate([points, points.mean(0)[None, :]]):
                    support = self.old_height(point[0], point[2], hood_only=True)
                    if support is None or support[0] < point[1] + 0.003:
                        covered = False
                        break
            hidden.append(covered)
        removed_hidden = int(np.sum(hidden))
        kept = kept[~np.asarray(hidden)]
        across = np.array([0, 0.35, 0.68, 0.81, 0.9, 0.935, 0.96, 0.98, 1.0]) * self.rear_width
        if not simple:
            across = np.unique(np.r_[across, (across[:-1] + across[1:]) * 0.5])
        along = np.array([0, 0.25, 0.55, 0.8])
        points = np.array([[self.point(x, v, body=True) for v in along] for x in across])
        normals = np.array([[self.normal(float(x), float(p[2]), body=True) for p in row] for (x, row) in zip(across, points)])
        triangles = []
        for i in range(len(across) - 1):
            for j in range(len(along) - 1):
                for ids in [[(i, j), (i + 1, j), (i + 1, j + 1)], [(i, j), (i + 1, j + 1), (i, j + 1)]]:
                    face = np.asarray([np.r_[points[a, b], normals[a, b]] for (a, b) in ids])
                    cross = np.cross(face[1, :3] - face[0, :3], face[2, :3] - face[0, :3])
                    if np.linalg.norm(cross) < 1e-11:
                        continue
                    if cross[1] < 0:
                        face = face[::-1]
                    triangles.append(face)
        rear_x = list(across)
        for (x, y, z) in kept[:, :, :3].reshape(-1, 3):
            if abs(z - self.REAR) < 1e-07 and 0.7 < x < self.rear_width:
                support = self.old_height(x, z)
                if support is not None and abs(y - support[0]) < 5e-05:
                    rear_x.append(x)
        rear_x = np.unique(np.round(rear_x, 7))
        back = []
        for x in rear_x:
            point = self.point(float(x), 1, body=True)
            back.append(np.r_[point, self.normal(float(x), self.REAR, body=True)])
        back = np.asarray(back)
        forward = np.c_[points[:, -1], normals[:, -1]]
        (i, j) = (0, 0)
        while i < len(forward) - 1 or j < len(back) - 1:
            advance = j == len(back) - 1 or (i < len(forward) - 1 and across[i + 1] < rear_x[j + 1])
            if advance:
                face = np.array([forward[i], forward[i + 1], back[j]])
                i += 1
            else:
                face = np.array([forward[i], back[j + 1], back[j]])
                j += 1
            cross = np.cross(face[1, :3] - face[0, :3], face[2, :3] - face[0, :3])
            if np.linalg.norm(cross) > 1e-11:
                triangles.append(face if cross[1] > 0 else face[::-1])
        from challenger_convex_fenders import convex_diagonals
        (packets, inverse) = np.unique(np.asarray(triangles).reshape(-1, 6), axis=0, return_inverse=True)
        faces = convex_diagonals(packets[:, :3], inverse.reshape(-1, 3))
        triangles = packets[faces]
        edge = points[:, 0]
        maximum = 0.0
        for vertex in kept.reshape(-1, 6):
            (x, y, z) = vertex[:3]
            if x > self.rear_width + 1e-07 or z > self.REAR + 1e-07 or abs(y - self.edge_height(x)) > 5e-05:
                continue
            best = None
            for (i, (a, b)) in enumerate(zip(edge[:-1], edge[1:])):
                segment = b - a
                t = float(np.clip((vertex[:3] - a) @ segment / max(segment @ segment, 1e-20), 0, 1))
                q = a + t * segment
                distance = float(np.linalg.norm(q - vertex[:3]))
                if best is None or distance < best[0]:
                    best = (distance, q, i, t)
            if best[0] < 0.025:
                maximum = max(maximum, best[0])
                vertex[:3] = best[1]
                vertex[3:] = unit(normals[best[2], 0] * (1 - best[3]) + normals[best[2] + 1, 0] * best[3])
        original_grid = np.asarray(triangles)
        triangles = split_boundary_edges(original_grid, kept)
        kept = split_boundary_edges(kept, original_grid)
        right = np.concatenate([kept, triangles])
        left = right[:, ::-1].copy()
        left[:, :, 0] *= -1
        left[:, :, 3] *= -1
        result = np.concatenate([right, left, axis])
        return (result, {'before': len(body), 'after': len(result), 'leading_triangles': 2 * len(triangles), 'maximum_boundary_refit_metres': maximum, 'buried_body_triangles_removed': 2 * removed_hidden, 'rear_width': self.rear_width})

def split_boundary_edges(values, additions):
    """Make newly closed strips conform to the adjoining triangle edges."""
    points = np.unique(np.round(additions[:, :, :3].reshape(-1, 3), 7), axis=0)
    (lower, upper) = (points.min(0), points.max(0))
    output = []
    for face in values:
        if np.any(face[:, :3].max(0) < lower) or np.any(face[:, :3].min(0) > upper):
            output.append(face)
            continue
        polygon = []
        divided = []
        for edge in range(3):
            (a, b) = (face[edge], face[(edge + 1) % 3])
            delta = b[:3] - a[:3]
            fraction = (points - a[:3]) @ delta / max(delta @ delta, 1e-20)
            distance = np.linalg.norm(points - a[:3] - fraction[:, None] * delta, axis=1)
            endpoints = (np.linalg.norm(points - a[:3], axis=1) > 1e-06) & (np.linalg.norm(points - b[:3], axis=1) > 1e-06)
            selected = np.flatnonzero((fraction > 1e-06) & (fraction < 1 - 1e-06) & (distance < 5e-07) & endpoints)
            polygon.append(a)
            if len(selected):
                divided.append(edge)
            for index in selected[np.argsort(fraction[selected])]:
                normal = unit(a[3:] * (1 - fraction[index]) + b[3:] * fraction[index])
                polygon.append(np.r_[points[index], normal])
        if not divided:
            output.append(face)
            continue
        polygon = np.asarray(polygon)
        if len(divided) == 1:
            pivot = face[(divided[0] + 2) % 3]
            start = int(np.argmin(np.linalg.norm(polygon[:, :3] - pivot[:3], axis=1)))
            polygon = np.roll(polygon, -start, axis=0)
            output.extend((np.array([polygon[0], polygon[i], polygon[i + 1]]) for i in range(1, len(polygon) - 1)))
        else:
            from mathutils import Vector
            from mathutils.geometry import delaunay_2d_cdt
            cross = np.cross(face[1, :3] - face[0, :3], face[2, :3] - face[0, :3])
            axes = [axis for axis in range(3) if axis != int(np.argmax(abs(cross)))]
            projected = polygon[:, axes] - polygon[0, axes]
            edges = [(i, (i + 1) % len(polygon)) for i in range(len(polygon))]
            (vertices, _, triangles, *_) = delaunay_2d_cdt([Vector(p) for p in projected], edges, [], 0, 1e-09)
            distance = np.linalg.norm(np.asarray(vertices)[:, None, :] - projected[None, :, :], axis=2)
            assert distance.min(1).max() < 1e-07
            indices = distance.argmin(1)
            for triangle in triangles:
                packet = polygon[indices[list(triangle)]]
                direction = np.cross(packet[1, :3] - packet[0, :3], packet[2, :3] - packet[0, :3])
                output.append(packet if direction @ cross > 0 else packet[::-1])
    return np.asarray(output)

def seal_front_cracks(values, micro=False, close_only=False):
    """Seat exterior boundary stations and close small front-quarter cracks."""
    from mathutils.kdtree import KDTree
    out = values.copy()
    points = out[:, :, :3]
    (unique, inverse) = np.unique(np.round(points.reshape(-1, 3), 6), axis=0, return_inverse=True)
    faces = inverse.reshape(-1, 3)
    edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
    (boundary, count) = np.unique(edges, axis=0, return_counts=True)
    boundary = boundary[count == 1]
    ids = np.unique(boundary)
    p = unique[ids]
    chosen = (p[:, 0] > 0.76) & (p[:, 2] > -2.085) & (p[:, 2] < -1.55) & (p[:, 1] > 0.54) & (p[:, 1] < (0.795 if micro else 0.763 + 0.038 * (p[:, 2] + 2.065) / 1.205))
    ids = ids[chosen]
    normal = np.zeros_like(unique)
    np.add.at(normal, inverse, out[:, :, 3:].reshape(-1, 3))
    normal = unit(normal)
    tree = KDTree(len(ids))
    for (i, index) in enumerate(ids):
        tree.insert(unique[index], i)
    tree.balance()
    assigned = set()
    moves = {}
    radius = 0.0 if close_only else 5e-05 if micro else 0.0045
    for index in ids:
        if index in assigned:
            continue
        nearby = tree.find_range(unique[index], radius)
        group = [int(ids[i]) for (_, i, _) in nearby if int(ids[i]) not in assigned and normal[int(ids[i])] @ normal[index] > 0.94]
        if len(group) < 2:
            continue
        q = unique[group].mean(0)
        guide = unit(normal[group].sum(0))
        for item in group:
            moves[item] = (q, guide)
            assigned.add(item)
    maximum = 0.0
    for (vertex, index) in zip(out.reshape(-1, 6), inverse):
        if index not in moves:
            continue
        (q, guide) = moves[index]
        maximum = max(maximum, float(np.linalg.norm(q - vertex[:3])))
        vertex[:3] = q
        if vertex[3:] @ guide > 0.94:
            vertex[3:] = guide
    points = out[:, :, :3]
    (unique, inverse) = np.unique(np.round(points.reshape(-1, 3), 6), axis=0, return_inverse=True)
    faces = inverse.reshape(-1, 3)
    edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
    (all_edges, first, count) = np.unique(edges, axis=0, return_index=True, return_counts=True)
    boundary = all_edges[count == 1]
    owners = np.tile(np.arange(len(faces)), 3)[first[count == 1]]
    pair = unique[boundary]
    delta = pair[:, 1] - pair[:, 0]
    length = np.linalg.norm(delta, axis=1)
    normal = np.zeros_like(unique)
    np.add.at(normal, inverse, out[:, :, 3:].reshape(-1, 3))
    normal = unit(normal)
    edge_normals = unit(normal[boundary].mean(1))
    moves2 = {}
    for index in np.unique(boundary):
        (x, y, z) = unique[index]
        if not (x > 0.76 and -2.085 < z < -1.55 and (0.54 < y < (0.795 if micro else 0.769 + 0.038 * (z + 2.065) / 1.205))):
            continue
        t = np.sum((unique[index] - pair[:, 0]) * delta, axis=1) / np.maximum(length * length, 1e-20)
        q = pair[:, 0] + np.clip(t, 0, 1)[:, None] * delta
        distance = np.linalg.norm(q - unique[index], axis=1)
        same_face = np.any(faces[owners] == index, axis=1)
        valid = (distance < radius) & (distance > 1e-06) & (t > 0.02) & (t < 0.98) & (length > 0.012) & ~same_face & (edge_normals @ normal[index] > 0.94)
        if not valid.any():
            continue
        candidates = np.flatnonzero(valid)
        best = candidates[np.argmin(distance[candidates])]
        guide = unit(normal[boundary[best, 0]] * (1 - t[best]) + normal[boundary[best, 1]] * t[best])
        moves2[index] = (q[best], guide)
    for (vertex, index) in zip(out.reshape(-1, 6), inverse):
        if index in moves2:
            (q, guide) = moves2[index]
            maximum = max(maximum, float(np.linalg.norm(q - vertex[:3])))
            vertex[:3] = q
            if vertex[3:] @ guide > 0.94:
                vertex[3:] = guide
    right = out[(out[:, :, 0].min(1) >= -1e-07) & (out[:, :, 0].max(1) > 1e-07)]
    axis = out[abs(out[:, :, 0]).max(1) <= 1e-07]
    left = right[:, ::-1].copy()
    left[:, :, 0] *= -1
    left[:, :, 3] *= -1
    out = np.concatenate([right, left, axis])
    cross = np.cross(out[:, 1, :3] - out[:, 0, :3], out[:, 2, :3] - out[:, 0, :3])
    out = out[np.linalg.norm(cross, axis=1) > 1e-11]
    (positions, inverse) = np.unique(np.round(out[:, :, :3].reshape(-1, 3), 6), axis=0, return_inverse=True)
    faces = inverse.reshape(-1, 3)
    edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
    (edges, counts) = np.unique(edges, axis=0, return_counts=True)
    boundary = edges[counts == 1]
    neighbours = {}
    for (a, b) in boundary:
        neighbours.setdefault(int(a), set()).add(int(b))
        neighbours.setdefault(int(b), set()).add(int(a))
    guides = np.zeros_like(positions)
    np.add.at(guides, inverse, out[:, :, 3:].reshape(-1, 3))
    guides = unit(guides)
    patches = []
    for (a, b) in boundary:
        for c in neighbours[int(a)] & neighbours[int(b)]:
            if not a < b < c:
                continue
            ids = [a, b, c]
            triangle = positions[ids]
            (x, y, z) = triangle.mean(0)
            if not (abs(x) > 0.76 and 0.54 < y < 0.795 and (-2.085 < z < -1.55)):
                continue
            if np.linalg.norm(triangle - np.roll(triangle, 1, axis=0), axis=1).max() > 0.012:
                continue
            normals = guides[ids]
            cross = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            face = np.c_[triangle, normals]
            if cross @ normals.mean(0) < 0:
                face = face[::-1]
            patches.append(face)
    if patches:
        out = np.concatenate([out, np.asarray(patches)])
    (positions, inverse) = np.unique(np.round(out[:, :, :3].reshape(-1, 3), 6), axis=0, return_inverse=True)
    faces = inverse.reshape(-1, 3)
    edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
    (edges, counts) = np.unique(edges, axis=0, return_counts=True)
    boundary = edges[counts == 1]
    guides = np.zeros_like(positions)
    np.add.at(guides, inverse, out[:, :, 3:].reshape(-1, 3))
    guides = unit(guides)
    pairs = positions[boundary]
    delta = pairs[:, 1] - pairs[:, 0]
    length2 = np.sum(delta * delta, axis=1)
    surface = tree_for(out)
    bridges = []
    for index in np.unique(boundary):
        point = positions[index]
        (x, y, z) = point
        if not (x > 0.76 and 0.54 < y < 0.795 and (-2.085 < z < -1.55)):
            continue
        t = np.sum((point - pairs[:, 0]) * delta, axis=1) / np.maximum(length2, 1e-20)
        projected = pairs[:, 0] + np.clip(t, 0, 1)[:, None] * delta
        distance = np.linalg.norm(projected - point, axis=1)
        valid = (distance > 1e-06) & (distance < (0.0045 if close_only else radius)) & (t > 0.02) & (t < 0.98) & (np.min(pairs[:, :, 0], axis=1) > 0.76) & (np.min(guides[boundary] @ guides[index], axis=1) > 0.94)
        for edge in np.flatnonzero(valid):
            ids = [index, *boundary[edge]]
            triangle = positions[ids].copy()
            normals = guides[ids].copy()
            span = 0.01 / max(float(np.sqrt(length2[edge])), 1e-10)
            ends = np.clip([t[edge] - span, t[edge] + span], 0, 1)
            triangle[1:] = pairs[edge, 0] + ends[:, None] * delta[edge]
            normals[1:] = unit(guides[boundary[edge, 0]] * (1 - ends[:, None]) + guides[boundary[edge, 1]] * ends[:, None])
            centre = triangle.mean(0)
            (hit, *_) = surface.ray_cast((2, float(centre[1]), float(centre[2])), (-1, 0, 0), 2)
            if hit is not None and hit.x > 0.75:
                continue
            cross = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            if np.linalg.norm(cross) < 1e-11:
                continue
            packet = np.c_[triangle, normals]
            if cross @ normals.mean(0) < 0:
                packet = packet[::-1]
            mirror = packet[::-1].copy()
            mirror[:, [0, 3]] *= -1
            bridges.extend([packet, mirror])
            surface = tree_for(np.concatenate([out, np.asarray(bridges)]))
    if bridges:
        out = np.concatenate([out, np.asarray(bridges)])
    strips = []
    if close_only:
        (positions, inverse) = np.unique(np.round(out[:, :, :3].reshape(-1, 3), 7), axis=0, return_inverse=True)
        faces = inverse.reshape(-1, 3)
        edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
        (edges, counts) = np.unique(edges, axis=0, return_counts=True)
        boundary = edges[counts == 1]
        guides = np.zeros_like(positions)
        np.add.at(guides, inverse, out[:, :, 3:].reshape(-1, 3))
        guides = unit(guides)
        pairs = positions[boundary]
        centres = pairs.mean(1)
        chosen = (pairs[:, :, 0].min(1) > 0.76) & (centres[:, 1] > 0.74) & (centres[:, 1] < 0.795) & (centres[:, 2] > -2.02) & (centres[:, 2] < -1.9)
        boundary = boundary[chosen]
        pairs = pairs[chosen]
        surface = tree_for(out)
        for (i, a) in enumerate(pairs):
            direction = a[1, 1:] - a[0, 1:]
            length = np.linalg.norm(direction)
            if length < 1e-05:
                continue
            direction /= length
            for j in range(i + 1, len(pairs)):
                b = pairs[j]
                other = b[1, 1:] - b[0, 1:]
                if abs(other @ direction) < 0.98 * np.linalg.norm(other):
                    continue
                projection = (b[:, 1:] - a[0, 1:]) @ direction
                (low, high) = (max(0, float(projection.min())), min(length, float(projection.max())))
                if high - low < 0.0001 or abs(projection[1] - projection[0]) < 1e-08:
                    continue
                t = np.array([low, high]) / length
                u = (np.array([low, high]) - projection[0]) / (projection[1] - projection[0])
                first = a[0] + t[:, None] * (a[1] - a[0])
                second = b[0] + u[:, None] * (b[1] - b[0])
                separation = np.linalg.norm(first - second, axis=1)
                if separation.max() > 0.0045 or separation.max() < 1e-06:
                    continue
                n1 = unit(guides[boundary[i, 0]] * (1 - t[:, None]) + guides[boundary[i, 1]] * t[:, None])
                n2 = unit(guides[boundary[j, 0]] * (1 - u[:, None]) + guides[boundary[j, 1]] * u[:, None])
                if np.min(np.sum(n1 * n2, axis=1)) < 0.94:
                    continue
                quad = np.c_[np.r_[first, second], np.r_[n1, n2]]
                import challenger_clean_panels as panels
                existing = np.concatenate([out, np.asarray(strips)]) if strips else out
                low_bound = quad[:, :3].min(0)
                high_bound = quad[:, :3].max(0)
                eligible = (existing[:, :, 0].min(1) > 0.75) & (existing[:, :, 1].max(1) >= low_bound[1]) & (existing[:, :, 1].min(1) <= high_bound[1]) & (existing[:, :, 2].max(1) >= low_bound[2]) & (existing[:, :, 2].min(1) <= high_bound[2])
                covering = existing[eligible]
                for ids in [[0, 1, 3], [0, 3, 2]]:
                    pieces = [quad[ids]]
                    for cover in covering:
                        pieces = [piece for face in pieces for piece in panels._subtract(face, cover[:, [1, 2]], [1, 2])]
                        if not pieces:
                            break
                    for face in pieces:
                        cross = np.cross(face[1, :3] - face[0, :3], face[2, :3] - face[0, :3])
                        if np.linalg.norm(cross) < 1e-11:
                            continue
                        face[:, 3:] = unit(face[:, 3:])
                        if cross @ face[:, 3:].mean(0) < 0:
                            face = face[::-1]
                        mirror = face[::-1].copy()
                        mirror[:, [0, 3]] *= -1
                        strips.extend([face, mirror])
        if strips:
            strips = np.asarray(strips)
            out = np.concatenate([split_boundary_edges(out, strips), strips])
    return (out, {'welded_stations': 2 * len(moves), 'edge_seated_stations': 2 * len(moves2), 'maximum_refit_metres': maximum, 'before_triangles': len(values), 'after_triangles': len(out), 'closed_triangular_holes': len(patches), 'bridged_boundary_triangles': len(bridges), 'closed_boundary_strip_triangles': len(strips)})

def refine(exports, simple, crown):
    import challenger_clean_panels as panels
    by_name = {obj.name: obj for obj in exports}

    def records(name):
        (points, faces, normals) = panels._read(by_name[name])
        return np.concatenate([points[faces], normals.reshape(-1, 3, 3)], axis=2)
    original_body = records('body__paint')
    original_hood = records('hood__paint')
    (sealed_body, crack_statistics) = seal_front_cracks(original_body)
    field = LeadingRoll(sealed_body, original_hood, crown)
    (body, statistics) = field.rebuild(sealed_body, simple)
    (hood, maximum_hood_move) = field.map_hood(original_hood)
    (body, micro_statistics) = seal_front_cracks(body, micro=True)
    statistics['boundary_seating'] = micro_statistics
    (body, closure_statistics) = seal_front_cracks(body, close_only=True)
    statistics['boundary_closure'] = closure_statistics
    right = panels._positive(body)
    right = right[abs(right[:, :, 0]).max(1) > 1e-07]
    (_, vertex_ids) = np.unique(np.round(right.reshape(-1, 6), 7), axis=0, return_inverse=True)
    (_, retained) = np.unique(np.sort(vertex_ids.reshape(-1, 3), axis=1), axis=0, return_index=True)
    statistics['duplicate_faces_removed'] = 2 * (len(right) - len(retained))
    body = panels._symmetric(right[np.sort(retained)])
    panels._write(by_name['body__paint'], body)
    panels._write(by_name['hood__paint'], hood)
    statistics['before'] = len(original_body)
    statistics['after'] = len(body)
    statistics['cracks'] = crack_statistics
    statistics['hood_maximum_move_metres'] = maximum_hood_move
    contour = by_name['body__contour'].data
    points = np.asarray([v.co[:] for v in contour.vertices])[:, [0, 2, 1]] * [1, 1, -1]
    loops = np.asarray([loop.vertex_index for loop in contour.loops])
    normals = np.asarray([n.vector[:] for n in contour.corner_normals])[:, [0, 2, 1]] * [1, 1, -1]
    hood_tree = tree_for(hood)
    guides = {}
    for (index, point) in enumerate(points):
        if point[2] >= field.REAR or point[1] < 0.74:
            continue
        (hit, normal, *_) = hood_tree.ray_cast((float(point[0]), 2, float(point[2])), (0, -1, 0), 2)
        if hit is None:
            continue
        points[index, 1] = hit.y + 0.0018
        guide = np.array(normal)
        guides[index] = guide if guide[1] >= 0 else -guide
    for (index, vertex) in enumerate(loops):
        if vertex in guides:
            normals[index] = guides[vertex]
    contour.vertices.foreach_set('co', (points[:, [0, 2, 1]] * [1, -1, 1]).ravel())
    contour.update()
    contour.normals_split_custom_set((normals[:, [0, 2, 1]] * [1, -1, 1]).tolist())
    statistics['contour_stations_seated'] = len(guides)
    return (field, statistics)
