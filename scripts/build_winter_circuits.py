"""Author the two original Winter circuits; Godot prepares their automatic routes.

No third-party packages, player reads/writes, or backend access.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/resources/creator_tracks"


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def mul(a, s):
    return (a[0] * s, a[1] * s)


def unit(a):
    return mul(a, 1 / math.hypot(*a))


def rounded(a):
    return [round(a[0], 6), round(a[1], 6)]


def circuit(identifier, name, vertices, radii, width):
    bends = []
    for i, p in enumerate(vertices):
        incoming = unit(sub(p, vertices[i - 1]))
        outgoing = unit(sub(vertices[(i + 1) % len(vertices)], p))
        turn = math.atan2(incoming[0] * outgoing[1] - incoming[1] * outgoing[0],
                          incoming[0] * outgoing[0] + incoming[1] * outgoing[1])
        trim = radii[i] * math.tan(abs(turn) / 2)
        bends.append((sub(p, mul(incoming, trim)), add(p, mul(outgoing, trim)),
                      incoming, outgoing, turn, radii[i]))
    pieces, samples = [], []
    for i, bend in enumerate(bends):
        previous = bends[i - 1]
        start, end = previous[1], bend[0]
        length = math.dist(start, end)
        # A fillet cannot consume the next straight, even when pointing back.
        assert length >= 2 and sum(a * b for a, b in zip(sub(end, start), bend[2])) > 0, (name, i)
        heading = math.degrees(math.atan2(bend[2][1], bend[2][0])) % 360
        common = dict(radius=16.0, width=width, flip=False)
        pieces.append(dict(kind="straight", position=rounded(start), heading=heading,
                           length=length, **common))
        steps = math.ceil(length / 0.5)
        samples += [add(start, mul(sub(end, start), j / steps)) for j in range(steps)]
        pieces.append(dict(kind="curve", position=rounded(end), heading=heading,
                           length=0.0, radius=bend[5], width=width,
                           flip=bend[4] < 0, angle=abs(math.degrees(bend[4]))))
        side = -1 if bend[4] < 0 else 1
        normal = (-bend[2][1] * side, bend[2][0] * side)
        center = add(end, mul(normal, bend[5]))
        radial = sub(end, center)
        steps = math.ceil(bend[5] * abs(bend[4]) / 0.5)
        for j in range(steps):
            t = bend[4] * j / steps
            samples.append(add(center, (radial[0] * math.cos(t) - radial[1] * math.sin(t),
                                        radial[0] * math.sin(t) + radial[1] * math.cos(t))))
    # Start on the longest straight, with ample room on either side of the line.
    longest = max((p for p in pieces if p["kind"] == "straight"), key=lambda p: p["length"])
    angle = math.radians(longest["heading"])
    start = add(longest["position"], (math.cos(angle) * longest["length"] * .52,
                                      math.sin(angle) * longest["length"] * .52))
    doc = dict(schema="creator-track-v5", id=identifier, name=name, creator="Ville",
               theme="winter", width=width, surface="asphalt", points=vertices,
               widths=[width] * len(vertices), corners=["smooth"] * len(vertices),
               objects=[], layout={}, paint=[], base_track="", route_override=True,
               pieces=pieces, start_line=dict(position=rounded(start), heading=longest["heading"]),
               automatic_scenery=False)
    return doc, samples


DIMENSIONS = {
    "tree": (3, 3), "rock": (2, 2), "boulder": (3, 3), "slate": (4, 2),
    "cliff": (8, 3), "log": (4, .8), "hut": (2.5, 2.5), "shed": (7, 5),
    "igloo": (7, 8.6), "snow_castle": (7.4, 6.4), "ice_compact": (3.4, 5.8),
    "snowman": (3, 2), "snow_lantern": (1.8, 1.8), "ice_lantern": (1.4, 1.4),
    "chevron": (1.5, .5), "braking_board": (1.5, .5), "flag": (1, 1),
    "guardrail": (6, .5), "fence": (6, .5), "gantry": (12, 1),
}


def prop(doc, road, kind, x, y, rotation=0, scale=1, length=None):
    """Reject blocked racing space and interpenetrating landmark footprints."""
    size = DIMENSIONS[kind]
    radius = math.hypot(*size) * scale / 2
    clearance = min(math.dist((x, y), q) for q in road) - doc["width"] / 2 - radius
    if kind != "gantry" and clearance < 2.0:
        return False
    for other in doc["objects"]:
        if kind == "gantry" or other["kind"] == "gantry":
            continue
        r = math.hypot(*DIMENSIONS[other["kind"]]) * other.get("scale", 1) / 2
        if math.dist((x, y), other["position"]) < radius + r + .35:
            return False
    item = dict(kind=kind, position=rounded((x, y)), rotation=rotation % 360)
    if scale != 1:
        item["scale"] = scale
    if length is not None:
        item["length"] = length
    doc["objects"].append(item)
    return True


def landmark(doc, road, kind, x, y, rotation=0, scale=1):
    assert prop(doc, road, kind, x, y, rotation, scale), (doc["name"], kind, x, y)


def roadside(doc, road, kind, fraction, side, offset=4, scale=1):
    index = int(fraction * len(road)) % len(road)
    point = road[index]
    tangent = unit(sub(road[(index + 3) % len(road)], road[(index - 3) % len(road)]))
    normal = (-tangent[1] * side, tangent[0] * side)
    position = add(point, mul(normal, doc["width"] / 2 + offset))
    return prop(doc, road, kind, *position, math.degrees(math.atan2(tangent[1], tangent[0])), scale)


def marker(doc, road, kind, fraction, side, offset=4, scale=1):
    for shift in [0, .008, -.008, .016, -.016]:
        for extra in [0, 2, 4]:
            if roadside(doc, road, kind, fraction + shift, side, offset + extra, scale):
                return
    raise AssertionError((doc["name"], kind, fraction))


def finish(doc, road, tree_count):
    # Reproducible clumps, with deliberate variation in silhouette and setback.
    added = 0
    for i in range(400):
        f = ((i * .61803398875) + .019) % 1
        side = 1 if i % 3 else -1
        offset = [7.5, 11.5, 17.0, 9.0, 14.0][i % 5]
        if roadside(doc, road, "tree", f, side, offset, [1.65, 2.1, 2.8, 1.9, 2.4][i % 5]):
            added += 1
        if added == tree_count:
            break
    assert added == tree_count
    assert len(doc["objects"]) <= 96
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / (doc["id"] + ".json")).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print(doc["name"], len(doc["pieces"]), "sections,", len(doc["objects"]), "props")


def frostline():
    doc, road = circuit("frostline", "Frostline",
        [(-64, 63), (43, 63), (81, 23), (72, -52), (32, -76),
         (-7, -42), (-38, -72), (-79, -39), (-60, 0), (-79, 30)],
        [20, 23, 24, 21, 18, 18, 17, 20, 22, 18], 11.0)
    for kind, x, y, rotation, scale in [
        ("shed", -20, 81, 180, 1.25), ("hut", 10, 79, 180, 1.0),
        ("boulder", 49, -13, 96, 3.0), ("boulder", 44, -37, 111, 2.8),
        ("slate", 33, -21, 25, 1.5), ("boulder", 28, -29, 13, 1.3),
        ("rock", 34, -38, 0, 1.1), ("log", -44, 4, 45, 1.1),
        ("log", -48, -12, 110, 1.0), ("snowman", -32, 79, 160, 1.0),
        ("ice_lantern", -11, 79, 0, 1.0), ("snow_lantern", 17, 78, 0, 1.0),
    ]:
        landmark(doc, road, kind, x, y, rotation, scale)
    # Marker groups precede the tighter rock crescent and the forest switchback.
    for f in [.28, .35, .48, .53, .62, .70, .80, .87]:
        marker(doc, road, "chevron", f, -1, 3.5)
    for f in [.42, .74]:
        marker(doc, road, "braking_board", f, -1, 4.5)
    for f in [.055, .12]:
        for side in [-1, 1]:
            marker(doc, road, "flag", f, side, 4)
    for f in [.25, .32]:
        marker(doc, road, "guardrail", f, -1, 4.5)
    for f in [.20, .40, .66, .91]:
        marker(doc, road, "rock", f, 1, 9, 1.3)
    # Gantry is perpendicular to the straight; its supports clear an 11 m road.
    start = doc["start_line"]
    landmark(doc, road, "gantry", *start["position"], start["heading"] + 90, 1.25)
    finish(doc, road, 56)


def lantern_village():
    doc, road = circuit("lantern_village", "Lantern Village",
        [(-65, 64), (51, 64), (78, 37), (67, 7), (20, 4),
         (22, -26), (64, -48), (47, -77), (-24, -77),
         (-41, -42), (-76, -30), (-67, 7), (-28, 23), (-49, 40)],
        [12, 18, 17, 14, 13, 15, 13, 15, 18, 16, 17, 16, 12, 13], 10.0)
    for kind, x, y, rotation, scale in [
        ("snow_castle", -5, -8, 0, 2.2),
        ("igloo", -25, -7, 40, 1.25), ("igloo", -23, -29, 100, 1.0),
        ("igloo", -4, -34, 160, 1.15), ("ice_compact", -4, 25, 35, 1.35),
        ("shed", -18, 83, 180, 1.2), ("hut", 6, 80, 180, 1.0),
        ("snowman", -30, 80, 165, 1.15), ("snowman", 5, -51, 30, 1.0),
        ("snowman", 43, 26, 230, .9),
        ("ice_lantern", -14, 19, 0, 1.1), ("ice_lantern", 6, 19, 0, 1.1),
        ("ice_lantern", -17, 4, 0, 1.1), ("ice_lantern", 9, 4, 0, 1.1),
        ("snow_lantern", -16, -43, 0, 1.2), ("snow_lantern", 0, -47, 0, 1.2),
        ("snow_lantern", 13, -40, 0, 1.1), ("rock", 43, -23, 0, 1.5),
        ("slate", 58, -20, 35, 1.4),
    ]:
        landmark(doc, road, kind, x, y, rotation, scale)
    for f in [.26, .36, .44, .52, .61, .71, .82, .91]:
        marker(doc, road, "chevron", f, -1, 3.5)
    for f in [.30, .48, .76]:
        marker(doc, road, "braking_board", f, -1, 4.5)
    for f in [.055, .115]:
        for side in [-1, 1]:
            marker(doc, road, "flag", f, side, 4)
    for f in [.19, .24, .64, .69, .84]:
        marker(doc, road, "fence", f, -1, 4.5)
    for f in [.17, .39, .58, .89]:
        marker(doc, road, "ice_lantern", f, 1, 4, 1.15)
    start = doc["start_line"]
    landmark(doc, road, "gantry", *start["position"], start["heading"] + 90, 1.2)
    finish(doc, road, 44)


if __name__ == "__main__":
    frostline()
    lantern_village()
