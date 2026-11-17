"""Offline Challenger Demon bonnet with an open leading scoop and extractors."""
import numpy as np

from challenger_clean_panels import CleanHood
from challenger_side_surface import Curve, ramp, unit


class ChallengerHood(CleanHood):
    INLET_Z = -1.98
    SCOOP_REAR_Z = -1.02
    SCOOP_RISE = .060

    def __init__(self, panel_seat):
        super().__init__()
        self.panel_seat = panel_seat
        self.deck = Curve(
            [-2.30, -2.22, -2.17, -2.05, -1.88, -1.55, -1.15, -.99, -.72],
            [.805, .853, .870, .880, .883, .907, .937, .973, .982],
        )
        self.stats = {
            'design': '2018 Challenger SRT Demon single Air-Grabber scoop',
            'leading_scoop_rise_metres': self.SCOOP_RISE,
            'inlet_width_metres': .590,
            'inlet_height_metres': .036,
            'inlet_depth_metres': .075,
            'extractors': 2,
        }

    def width(self, v):
        return self.panel_seat.width(v)

    def front(self, u):
        return self.panel_seat.front(u)

    def rear(self, u):
        return self.panel_seat.rear(u)

    def deck_height(self, x, z):
        x, z = np.broadcast_arrays(x, z)
        u, v = self.uv(x, z)
        edge_distance = np.minimum.reduce([
            self.width(v) - abs(x), z - self.front(u), self.rear(u) - z,
        ])
        interior = ramp(.018, .100, edge_distance)
        deck = self.deck(z) + .006 * (1 - np.minimum(abs(u), 1) ** 2)
        return self.panel_seat.height(x, z) * (1 - interior) + deck * interior

    def scoop_width(self, z):
        return .380 - .090 * ramp(self.INLET_Z, self.SCOOP_REAR_Z, z)

    def roof_height(self, x, z):
        x, z = np.broadcast_arrays(x, z)
        across = abs(x) / self.scoop_width(z)
        inner_shoulder = .76 - .30 * ramp(-1.75, -1.15, z)
        shoulder = 1 - ramp(inner_shoulder, 1, across)
        leading_height = self.deck_height(0, self.INLET_Z) + self.SCOOP_RISE
        rear_height = self.deck_height(0, self.SCOOP_REAR_Z)
        rail = leading_height + (rear_height - leading_height) * ramp(self.INLET_Z, self.SCOOP_REAR_Z, z)
        rise = np.maximum(rail - self.deck_height(0, z), 0)
        rear_blend = 1 - ramp(-1.055, self.SCOOP_REAR_Z, z)
        return self.deck_height(x, z) + rise * shoulder * rear_blend

    def height(self, x, z):
        x, z = np.broadcast_arrays(x, z)
        raised = ((z >= self.INLET_Z) & (z <= self.SCOOP_REAR_Z)
                  & (abs(x) <= self.scoop_width(z)))
        return np.where(raised, self.roof_height(x, z), self.deck_height(x, z))

    def attachment_height(self, x, z):
        from challenger_reference_form import front_scale
        return self.height(np.asarray(x) * front_scale(z), z)

    @staticmethod
    def surface_normal(height, x, z):
        x, z = np.broadcast_arrays(x, z)
        step = .00002
        dx = (height(x + step, z) - height(x - step, z)) / (2 * step)
        dz = (height(x, z + step) - height(x, z - step)) / (2 * step)
        return unit(np.stack([-dx, np.ones_like(dx), -dz], axis=-1))

    def normal(self, x, z):
        return self.surface_normal(self.height, x, z)


def strip_legacy_trim(values, kind, panel_seat):
    """Remove the old exposed engine plate and its raised central trim."""
    if kind not in ['body_red', 'body_accent', 'body_metal', 'body_dark']:
        return values
    centre = values[:, :, :3].mean(axis=1)
    x, y, z = centre.T
    raised_plate = ((abs(x) < .36) & (z > -1.58) & (z < -.83) & (y > .91))
    if kind == 'body_dark':
        raised_plate &= panel_seat.contains(x, z)
        raised_plate &= y > panel_seat.height(x, z) - .025
    return values[~raised_plate]


def rebuild(exports, panel_seat, lattice, simple):
    import challenger_clean_panels as panels
    import challenger_detail_geometry as detail

    hood = ChallengerHood(panel_seat)
    records = {'paint': [], 'dark': []}

    def emit(vertices, faces, role, normals=None, facing=None):
        vertices = np.asarray(vertices, dtype=float)
        faces = np.asarray(faces, dtype=int)
        if not len(faces):
            return
        cross = np.cross(vertices[faces[:, 1]] - vertices[faces[:, 0]],
                         vertices[faces[:, 2]] - vertices[faces[:, 0]])
        if normals is not None:
            normals = np.asarray(normals)
            guide = normals[faces].mean(axis=1)
        elif facing is not None:
            guide = np.broadcast_to(facing, cross.shape)
        else:
            guide = cross
        reverse = np.sum(cross * guide, axis=1) < 0
        faces[reverse] = faces[reverse, ::-1]
        cross[reverse] *= -1
        corner_normals = (normals[faces] if normals is not None
                          else np.repeat(unit(cross)[:, None, :], 3, axis=1))
        values = np.concatenate([vertices[faces], corner_normals], axis=2)
        valid = np.linalg.norm(cross, axis=1) > 1e-12
        records[role].append(values[valid])

    across = np.array([-1, -.97, -.92, -.86, -.80, -.76, -.60, -.40, -.20,
                      0, .20, .40, .60, .76, .80, .86, .92, .97, 1])
    along = np.linspace(hood.INLET_Z, hood.SCOOP_REAR_Z, 25 if simple else 37)
    roof_x = hood.scoop_width(along)[:, None] * across
    roof_z = np.broadcast_to(along[:, None], roof_x.shape)
    roof = np.stack([roof_x, hood.roof_height(roof_x, roof_z), roof_z], axis=-1)
    footprint = np.concatenate([
        roof[0][:, [0, 2]],
        roof[1:, -1, :][:, [0, 2]],
        roof[-1, -2::-1, :][:, [0, 2]],
        roof[-2:0:-1, 0, :][:, [0, 2]],
    ])
    extractor_paths = [detail.rounded(sign * .535, -1.48, .165, .240, .022, 6)
                       for sign in [-1, 1]]
    boundary = hood.boundary()
    points, triangles = lattice(boundary[:, [0, 2]], .048 if simple else .034,
                                holes=[footprint, *extractor_paths])
    deck_points = np.c_[points[:, 0], hood.deck_height(points[:, 0], points[:, 1]), points[:, 1]]
    emit(deck_points, triangles, 'paint',
         hood.surface_normal(hood.deck_height, points[:, 0], points[:, 1]))

    rows, columns = roof_x.shape
    roof_faces = []
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            roof_faces.extend([(a, a + 1, a + columns + 1),
                               (a, a + columns + 1, a + columns)])
    emit(roof.reshape(-1, 3), roof_faces, 'paint',
         hood.surface_normal(hood.roof_height, roof_x, roof_z).reshape(-1, 3))

    # The scoop's leading face is open. Its planar surround meets the raised
    # roof above and the low bonnet deck below at the same sampled stations.
    front_x = roof_x[0]
    lower = np.c_[front_x, hood.deck_height(front_x, hood.INLET_Z)]
    face_outline = np.concatenate([lower, roof[0, -2:0:-1, :][:, [0, 1]]])
    mouth_y = float(hood.deck_height(0, hood.INLET_Z)) + .030
    mouth = detail.rounded(0, mouth_y, .590, .036, .008, 6)
    face_points, face_triangles = lattice(face_outline, .020, holes=[mouth])
    emit(np.c_[face_points, np.full(len(face_points), hood.INLET_Z)],
         face_triangles, 'paint', facing=[0, 0, -1])

    inner = np.array([0, mouth_y]) + (mouth - [0, mouth_y]) * [.96, .90]
    lip = np.c_[mouth, np.full(len(mouth), hood.INLET_Z)]
    throat = np.c_[inner, np.full(len(inner), hood.INLET_Z + .005)]
    vertices, faces = detail.ring([lip, throat])
    emit(vertices, faces, 'paint', facing=[0, 0, -1])
    back = np.c_[inner, np.full(len(inner), hood.INLET_Z + .075)]
    vertices, faces = detail.ring([throat, back])
    inward = unit(np.c_[-vertices[:, 0], mouth_y - vertices[:, 1], np.zeros(len(vertices))])
    emit(vertices, faces, 'dark', normals=inward)
    back_points = np.vstack([back, [0, mouth_y, hood.INLET_Z + .075]])
    emit(back_points, [(len(back), i, (i + 1) % len(back)) for i in range(len(back))],
         'dark', facing=[0, 0, -1])

    def add_vent(_name, vertices, faces, role, _group):
        emit(vertices, faces, 'paint' if role == 'paint' else 'dark', facing=[0, 1, 0])
    detail.vents(add_vent, extractor_paths, hood.deck_height)

    normals = hood.surface_normal(hood.deck_height, boundary[:, 0], boundary[:, 2])
    lower_boundary = boundary - [0, .008, 0]
    vertices, faces = detail.ring([boundary, lower_boundary])
    emit(vertices, faces, 'paint', normals=np.concatenate([normals, normals]))
    for role in ['paint', 'dark']:
        obj = next(obj for obj in exports if obj.name == 'hood__' + role)
        panels._write(obj, panels._symmetric(np.concatenate(records[role])))
    hood.stats['paint_triangles'] = sum(len(row) for row in records['paint'])
    hood.stats['dark_triangles'] = sum(len(row) for row in records['dark'])
    return hood


def finish_seams(exports, boundary, simple=False):
    """Seat the fender banks beneath one regular bonnet perimeter."""
    from mathutils.bvhtree import BVHTree
    import challenger_clean_panels as panels
    from challenger_exterior_geometry import records

    body = next(obj for obj in exports if obj.name == 'body__paint')
    hood = next(obj for obj in exports if obj.name == 'hood__paint')

    def survey(values):
        points = values[:, :, :3].reshape(-1, 3)
        faces = np.arange(len(points)).reshape(-1, 3)
        tree = BVHTree.FromPolygons(points.tolist(), faces.tolist(), all_triangles=True)

        def hit(x, z):
            point, geometric_normal, index, _ = tree.ray_cast((float(x), 2, float(z)), (0, -1, 0), 2)
            if point is None:
                return None
            triangle = values[index]
            a, b, c = triangle[:, :3]
            matrix = np.stack([(b - a)[[0, 2]], (c - a)[[0, 2]]], axis=1)
            if abs(np.linalg.det(matrix)) < 1e-14:
                return None
            u, v = np.linalg.solve(matrix, (np.asarray(point) - a)[[0, 2]])
            normal = unit((1 - u - v) * triangle[0, 3:] + u * triangle[1, 3:] + v * triangle[2, 3:])
            if normal[1] < .05 and geometric_normal.y > .05:
                normal = np.asarray(geometric_normal)
            return np.asarray(point), normal
        return values, hit

    body_values, body_hit = survey(records(body))
    _, hood_hit = survey(records(hood))
    boundary = np.asarray(boundary)
    segments = np.roll(boundary[:, [0, 2]], -1, axis=0) - boundary[:, [0, 2]]
    directions = unit(segments)
    turn = np.arccos(np.clip(np.sum(directions * np.roll(directions, 1, axis=0), axis=1), -1, 1))
    step = 4 if simple else 3
    while True:
        selected = (np.arange(len(boundary)) % step == 0) | (turn > .040)
        if selected.sum() <= 280:
            break
        step += 1
    edge = boundary[selected]
    tangent = unit(np.roll(edge[:, [0, 2]], -1, axis=0) - edge[:, [0, 2]])
    outward = np.c_[tangent[:, 1], -tangent[:, 0]]
    previous = np.roll(outward, 1, axis=0)
    across = (outward + previous) / np.maximum(1 + np.sum(outward * previous, axis=1), .1)[:, None]
    rows = []
    outer_misses = 0
    for point, direction in zip(edge, across):
        inner_xz = point[[0, 2]] - direction * .00125
        support = hood_hit(*inner_xz)
        inner_height = point[1] if support is None else support[0][1]
        inner_normal = np.array([0, 1, 0]) if support is None else support[1]
        inner = np.array([inner_xz[0], inner_height - .0015, inner_xz[1]])
        outer = None
        for distance in [.040, .050, .030, .020, .010]:
            outer_xz = point[[0, 2]] + direction * distance
            support = body_hit(*outer_xz)
            if support is not None and support[0][1] > .72 and support[1][1] > .05:
                outer = support[0].copy()
                outer[1] -= .0015
                outer_normal = support[1]
                break
        if outer is None:
            outer_misses += 1
            outer_xz = point[[0, 2]] + direction * .030
            outer = np.array([outer_xz[0], inner_height - .010, outer_xz[1]])
            outer_normal = inner_normal
        middle_xz = (inner_xz + outer[[0, 2]]) * .5
        radial = outer[[0, 2]] - inner_xz
        width = max(float(np.linalg.norm(radial)), .0001)
        radial /= width
        inner_gradient = -inner_normal[[0, 2]] / max(inner_normal[1], .20)
        outer_gradient = -outer_normal[[0, 2]] / max(outer_normal[1], .20)
        secant = (outer[1] - inner[1]) / width
        lower, upper = min(0, 3 * secant), max(0, 3 * secant)
        first_slope = np.clip(float(inner_gradient @ radial), lower, upper)
        last_slope = np.clip(float(outer_gradient @ radial), lower, upper)
        middle_height = .5 * (inner[1] + outer[1]) + .125 * width * (first_slope - last_slope)
        middle = np.array([middle_xz[0], middle_height, middle_xz[1]])
        radial_slope = 1.5 * secant - .25 * (first_slope + last_slope)
        tangent = np.array([-radial[1], radial[0]])
        along_slope = float(((inner_gradient + outer_gradient) * .5) @ tangent)
        gradient = radial * radial_slope + tangent * along_slope
        middle_normal = unit(np.array([-gradient[0], 1, -gradient[1]]))
        rows.append(np.c_[np.array([inner, middle, outer]),
                          np.array([inner_normal, middle_normal, outer_normal])])
    collar = []
    for index, row in enumerate(rows):
        following = rows[(index + 1) % len(rows)]
        for column in range(2):
            for triangle in [np.array([row[column], following[column], following[column + 1]]),
                             np.array([row[column], following[column + 1], row[column + 1]])]:
                cross = np.cross(triangle[1, :3] - triangle[0, :3], triangle[2, :3] - triangle[0, :3])
                if cross[1] < 0:
                    triangle = triangle[::-1]
                collar.append(triangle)
    collar = panels._symmetric(np.asarray(collar))
    # The overlapping underlap and the original outward bank share one normal
    # field. Keep returned faces and the upright aperture bevel separate.
    _, bank_hit = survey(collar)
    geometric = unit(np.cross(body_values[:, 1, :3] - body_values[:, 0, :3],
                              body_values[:, 2, :3] - body_values[:, 0, :3]))
    aligned = 0
    outward = body_values[geometric[:, 1] > .25].copy()
    for face in outward:
        for vertex in face:
            support = bank_hit(vertex[0], vertex[2])
            if support is not None:
                weight = 1 - ramp(.006, .020, abs(vertex[1] - support[0][1]))
                vertex[3:] = unit(vertex[3:] * (1 - weight) + support[1] * weight)
                aligned += int(weight > 0)
    body_values[geometric[:, 1] > .25] = outward
    panels._write(body, np.concatenate([body_values, collar]))
    dark = next(obj for obj in exports if obj.name == 'body__dark')
    dark_values = records(dark)
    vertices = dark_values.reshape(-1, 6)
    clipped = 0
    # The planar black carrier ends inside the actual white aperture rim.
    # Survey that rim after the corner correction so the backing cannot stand
    # proud of the finished upper edge.
    points = records(body)[:, :, :3].reshape(-1, 3)
    tree = BVHTree.FromPolygons(points.tolist(), np.arange(len(points)).reshape(-1, 3).tolist(), all_triangles=True)
    cap_x = np.linspace(-.80, .80, 321)
    cap_y = []
    for x in cap_x:
        height = .85
        for y in np.arange(.74, .85, .0005):
            hit, normal, *_ = tree.ray_cast((float(x), float(y), -3), (0, 0, 1), 1.05)
            if hit is not None and hit.z < -2.085 and normal.z < -.15:
                height = float(y) + .002
                break
        cap_y.append(height)
    for vertex in vertices:
        if vertex[2] >= -1.95 or vertex[1] <= .72 or vertex[5] >= -.90:
            continue
        carrier_cap = np.interp(vertex[0], cap_x, cap_y)
        if vertex[1] > carrier_cap:
            vertex[1] = carrier_cap
            clipped += 1
    panels._write(dark, vertices.reshape(-1, 3, 6))
    return {'seam_bank_stations': len(rows), 'added_triangles': len(collar),
            'outer_support_fallbacks': outer_misses, 'bank_underlap_metres': .0015,
            'carrier_vertices_trimmed': clipped, 'aligned_outward_normal_corners': aligned}
