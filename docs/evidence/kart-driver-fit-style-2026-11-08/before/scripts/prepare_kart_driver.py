"""Pose tomkart's CC-BY driver offline; retain its original mesh/UV topology.

Usage: python scripts/prepare_kart_driver.py path/to/source.zip --output folder
Textures are copied unchanged here; use the reviewed unbranded textures for shipping.
"""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

import numpy as np


def rotation_between(a, b):
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = np.dot(a, b)
    skew = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + skew + skew @ skew / (1 + c)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive) as archive:
        source = json.loads(archive.read("scene.gltf"))
        binary = archive.read("scene.bin")
        for entry in archive.infolist():
            if entry.is_dir() or not (entry.filename.startswith("textures/") or entry.filename == "license.txt"):
                continue
            target = (output / entry.filename).resolve()
            if not target.is_relative_to(output.resolve()):
                raise ValueError("Archive path escapes output")
            target.parent.mkdir(parents=True, exist_ok=True)
            original = (output.parent / "source" / entry.filename).resolve()
            if not original.is_relative_to((output.parent / "source").resolve()):
                raise ValueError("Archive path escapes source directory")
            original.parent.mkdir(parents=True, exist_ok=True)
            original.write_bytes(archive.read(entry))
            # Keep independently reviewed texture edits when rebaking the pose.
            if not target.exists():
                target.write_bytes(archive.read(entry))

    def read(index):
        accessor = source["accessors"][index]
        view = source["bufferViews"][accessor["bufferView"]]
        columns = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[accessor["type"]]
        dtype = np.dtype({5126: "<f4", 5123: "<u2", 5125: "<u4"}[accessor["componentType"]])
        return np.ndarray((accessor["count"], columns), dtype=dtype, buffer=binary,
                          offset=view.get("byteOffset", 0) + accessor.get("byteOffset", 0),
                          strides=(view.get("byteStride", dtype.itemsize * columns), dtype.itemsize)).copy()

    # Flatten the source node transforms first. This is a static A-pose asset,
    # with separate upper/lower limb meshes; no rig or runtime skinning is added.
    world = {}

    def visit(index, parent):
        node = source["nodes"][index]
        transform = parent @ np.array(node.get("matrix", np.eye(4).T.ravel())).reshape(4, 4).T
        if "mesh" in node:
            world[node["mesh"]] = transform
        for child in node.get("children", []):
            visit(child, transform)

    visit(0, np.eye(4))
    scale = 0.34
    # A proper 180-degree rotation faces the kart's -Z nose without mirroring.
    forward = np.diag([-1., 1., -1.])
    lean = np.deg2rad(16)
    torso_rotation = np.array([[1, 0, 0], [0, np.cos(lean), -np.sin(lean)], [0, np.sin(lean), np.cos(lean)]])
    pelvis_source = np.array([0, .10, -.24]) * scale
    pelvis_target = np.array([0, .35, .035])

    def torso(points):
        return (points - pelvis_source) @ torso_rotation.T + pelvis_target

    def segment(points, start, end, target_start, target_end):
        start, end = np.array(start) * scale, np.array(end) * scale
        target_start, target_end = np.array(target_start), np.array(target_end)
        rotation = rotation_between(end - start, target_end - target_start)
        axis = (end - start) / np.linalg.norm(end - start)
        stretch = np.linalg.norm(target_end - target_start) / np.linalg.norm(end - start)
        delta = points - start
        delta += np.outer(delta @ axis, axis) * (stretch - 1)
        return delta @ rotation.T + target_start

    def pose(points, index):
        if index in [0, 1, 2, 3, 4, 11, 12, 13, 20]:
            return torso(points)
        # Sides below are in the kart coordinate system after the half-turn.
        side = -1 if index in [5, 6, 7, 14, 15, 16] else 1
        def blend(a, b, low, high):
            weight = np.clip((points[:, 1] / scale - low) / (high - low), 0, 1)
            weight = weight * weight * (3 - 2 * weight)
            return a * (1 - weight[:, None]) + b * weight[:, None]

        if index in [5, 6, 7, 8, 9, 10]:
            shoulder = torso(np.array([[side * .42, 1.32, -.17]]) * scale)[0]
            upper = segment(points, [side * .42, 1.32, -.17], [side * .79, .55, -.17],
                            shoulder, [side * .235, .52, -.03])
            forearm = segment(points, [side * .79, .55, -.17], [side * .96, .31, -.23],
                              [side * .235, .52, -.03], [side * .19, .54, -.17])
            hand = segment(points, [side * .96, .31, -.23], [side * 1.02, -.23, -.23],
                           [side * .19, .54, -.17], [side * .15, .53, -.36])
            # All three separate source pieces use the same deformation at
            # overlapping seams, preserving their original shared boundaries.
            arm = blend(hand, forearm, .26, .36)
            arm = blend(arm, upper, .46, .64)
            return blend(arm, torso(points), 1.10, 1.33)
        hip, knee, ankle = [side * .10, .345, .035], [side * .135, .375, -.335], [side * .14, .245, -.72]
        if index in [14, 15, 16, 17, 18, 19]:
            thigh = segment(points, [side * .22, -.11, -.23], [side * .25, -1.07, -.20], hip, knee)
            shin = segment(points, [side * .25, -1.07, -.20], [side * .30, -2.02, -.17], knee, ankle)
            foot = points - np.array([side * .30, -2.02, -.17]) * scale + ankle
            leg = blend(foot, shin, -2.10, -1.93)
            leg = blend(leg, thigh, -1.18, -.94)
            return blend(leg, torso(points), -.26, -.05)
        raise ValueError(index)

    result = {"asset": dict(source["asset"]), "scene": 0, "scenes": [{"nodes": [0]}],
              "nodes": [{"name": "TomkartDriver", "mesh": 0}], "meshes": [{"name": "TomkartSeatedDriver", "primitives": []}],
              "materials": source["materials"], "images": source["images"], "textures": source["textures"],
              "samplers": source.get("samplers", []), "buffers": [{"uri": "driver.bin"}], "bufferViews": [], "accessors": []}
    result["asset"]["generator"] = "Beat my track offline seated adaptation of tomkart's CC-BY-4.0 model"
    result["asset"]["extras"]["modifications"] = "Seated kart pose; lettering and brand marks removed from textures."
    payload = bytearray()

    def write(values, kind, component=5126):
        values = np.asarray(values, dtype={5126: "<f4", 5123: "<u2"}[component])
        while len(payload) % 4:
            payload.append(0)
        offset = len(payload)
        payload.extend(values.tobytes())
        view = len(result["bufferViews"])
        result["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": values.nbytes})
        accessor = {"bufferView": view, "componentType": component, "count": len(values), "type": kind}
        if kind == "VEC3":
            accessor.update(min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist())
        result["accessors"].append(accessor)
        return len(result["accessors"]) - 1

    report = {"source_sha256": hashlib.sha256(args.archive.read_bytes()).hexdigest(), "parts": []}
    for index, mesh in enumerate(source["meshes"]):
        primitive = mesh["primitives"][0]
        vertices = read(primitive["attributes"]["POSITION"])
        transformed = (world[index] @ np.c_[vertices, np.ones(len(vertices))].T).T[:, :3]
        standing = transformed @ forward.T * scale
        positions = pose(standing, index)
        # Inverse-transpose Jacobians preserve source normals through the
        # blended joints as well as the rigid portions of each limb.
        epsilon = 1e-5
        jacobian = np.stack([(pose(standing + np.eye(3)[axis] * epsilon, index) -
                              pose(standing - np.eye(3)[axis] * epsilon, index)) / (2 * epsilon)
                             for axis in range(3)], axis=2)
        linear = jacobian @ forward @ world[index][:3, :3]
        normals = np.einsum('ni,nij->nj', read(primitive["attributes"]["NORMAL"]), np.linalg.inv(linear))
        normals /= np.linalg.norm(normals, axis=1, keepdims=True)
        indices = read(primitive["indices"]).reshape(-1)
        result["meshes"][0]["primitives"].append({"attributes": {
            "POSITION": write(positions, "VEC3"), "NORMAL": write(normals, "VEC3"),
            "TEXCOORD_0": write(read(primitive["attributes"]["TEXCOORD_0"]), "VEC2")},
            "indices": write(indices, "SCALAR", 5123), "material": primitive["material"]})
        report["parts"].append({"source_mesh": index, "triangles": len(indices)//3,
                                "min": positions.min(0).tolist(), "max": positions.max(0).tolist()})
    result["buffers"][0]["byteLength"] = len(payload)
    (output / "driver.bin").write_bytes(payload)
    (output / "driver.gltf").write_text(json.dumps(result, separators=(",", ":")) + "\n", encoding="utf-8")
    (output / "pose.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Posed", sum(part["triangles"] for part in report["parts"]), "triangles in", output)


if __name__ == "__main__":
    main()
