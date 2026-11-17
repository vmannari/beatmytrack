"""Offline Challenger Demon bonnet with an open leading scoop and extractors."""
import numpy as np

from challenger_clean_panels import CleanHood
from challenger_side_surface import Curve, ramp, unit


class ChallengerHood(CleanHood):
    INLET_Z = -1.98
    SCOOP_REAR_Z = -1.08
    SCOOP_RISE = .060

    def __init__(self, panel_seat):
        super().__init__()
        self.panel_seat = panel_seat
        self.deck = Curve(
            [-2.30, -2.22, -2.17, -2.05, -1.88, -1.55, -1.15, -.99, -.72],
            [.805, .853, .870, .880, .883, .907, .919, .967, .982],
        )
        self.stats = {
            'design': '2018 Challenger SRT Demon single Air-Grabber scoop',
            'scoop_rise_metres': self.SCOOP_RISE,
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
        shoulder = 1 - ramp(.76, 1, across)
        rear_blend = 1 - ramp(-1.52, self.SCOOP_REAR_Z, z)
        return self.deck_height(x, z) + self.SCOOP_RISE * shoulder * rear_blend

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
        roof[0, :, [0, 2]].T,
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
    back = np.c_[inner * [1, 1], np.full(len(inner), hood.INLET_Z + .075)]
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
