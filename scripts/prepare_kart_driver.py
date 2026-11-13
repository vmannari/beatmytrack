"""Pose tomkart's CC-BY driver offline; reconstruct a continuous fitted garment.

Usage: python scripts/prepare_kart_driver.py path/to/source.zip --output folder
Textures are copied unchanged here; use the reviewed unbranded textures for shipping.
"""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

import numpy as np

from kart_driver_geometry import normals as mesh_normals, subdivide, two_bone, union_cloth, front_seam


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
    scale = 0.42
    # A proper 180-degree rotation faces the kart's -Z nose without mirroring.
    forward = np.diag([-1., 1., -1.])
    lean = np.deg2rad(44)
    torso_rotation = np.array([[1, 0, 0], [0, np.cos(lean), -np.sin(lean)], [0, np.sin(lean), np.cos(lean)]])
    pelvis_source = np.array([0, .10, -.24]) * scale
    pelvis_target = np.array([0, .35, .021])

    def reclined(points):
        return (points - pelvis_source) @ torso_rotation.T + pelvis_target

    def torso(points):
        points=points.copy()
        height=points[:,1]/scale
        width=np.interp(height,[-.3,.15,.45,.8,1.1,1.3,1.45,1.57],
                        [.36,.40,.37,.42,.49,.47,.24,.14])*scale
        depth=np.interp(height,[-.3,.15,.45,.8,1.1,1.3,1.45,1.57],
                        [.27,.28,.24,.26,.29,.24,.19,.15])*scale
        radial=points[:,[0,2]]-np.array([0,-.23])*scale
        radius=np.linalg.norm(radial/np.c_[width,depth],axis=1)
        # Round the source's broad flat chest/waist facets into the garment's
        # elliptical sections. Interior cap vertices remain inside the volume.
        influence=np.clip((radius-.45)/.30,0,1)*.72
        radial*=((1-influence)+influence/np.maximum(radius,.1))[:,None]
        points[:,[0,2]]=radial+np.array([0,-.23])*scale
        neck = np.array([0, 1.50, -.23]) * scale
        aligned = points - neck + reclined(neck[None, :])[0]
        weight = np.clip((points[:, 1]/scale-1.32)/(1.57-1.32),0,1)
        weight = weight*weight*(3-2*weight)
        posed=reclined(points)*(1-weight[:, None])+aligned*weight[:, None]
        # The source object's origin is at the waist, above its hip joints.
        # Seat the pelvis by the actual hip reference, without lifting the
        # chest/head or pulling the trouser junction down through the bucket.
        source_hip=np.array([0,-.11,-.23])*scale
        hip_correction=pelvis_target-np.array([0,.005,0])-reclined(source_hip[None,:])[0]
        pelvic_weight=np.clip((points[:,1]/scale+.05)/.40,0,1)
        pelvic_weight=1-pelvic_weight*pelvic_weight*(3-2*pelvic_weight)
        posed+=pelvic_weight[:,None]*hip_correction
        thoracic=np.clip((height-.80)/.45,0,1)
        thoracic=thoracic*thoracic*(3-2*thoracic)
        posed[:,2]-=.022*thoracic
        return posed

    def segment(points, start, end, target_start, target_end):
        start, end = np.array(start) * scale, np.array(end) * scale
        target_start, target_end = np.array(target_start), np.array(target_end)
        rotation = rotation_between(end - start, target_end - target_start)
        axis = (end - start) / np.linalg.norm(end - start)
        stretch = np.linalg.norm(target_end - target_start) / np.linalg.norm(end - start)
        delta = points - start
        delta += np.outer(delta @ axis, axis) * (stretch - 1)
        return delta @ rotation.T + target_start

    # Fit the boot's load-bearing sole to the real PedalPlate back face. The
    # source sole faces down; kart pedal normals face up/back by 0.30 radians.
    foot_angle = np.pi/2-.30
    foot_rotation = np.array([[1,0,0],[0,np.cos(foot_angle),-np.sin(foot_angle)],
                              [0,np.sin(foot_angle),np.cos(foot_angle)]])
    pedal_normal = np.array([0,np.sin(.30),np.cos(.30)])
    toe_splay=np.deg2rad(22)
    axis=pedal_normal
    skew=np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
    foot_rotation=(np.eye(3)+np.sin(-toe_splay)*skew+(1-np.cos(toe_splay))*skew@skew)@foot_rotation
    sole_source = np.array([.30,-2.220,-.27])*scale
    sole_target = np.array([.17,.28,-.94])+pedal_normal*(.023/2+.001)
    sole_target+=np.array([0,np.cos(.30),-np.sin(.30)])*.002
    ankle_source = np.array([.30,-2.02,-.17])*scale
    ankle_target = (ankle_source-sole_source)@foot_rotation.T+sole_target
    hip_target = np.array([.125,.345,.021])
    knee_target = two_bone(hip_target,ankle_target,.470,.465,np.array([.62,.69,-.44]))
    # Grip the upper side quadrants of the existing steering rim. Solve the
    # elbow to the grip with the forearm and proximal hand on one axis.
    wheel_angle=1.15
    grip_angle=np.pi/2
    grip_target=np.array([np.sin(grip_angle)*.168,
                          .54-np.sin(wheel_angle)*max(-.12,np.cos(grip_angle)*.168),
                          -.31+np.cos(wheel_angle)*max(-.12,np.cos(grip_angle)*.168)])
    shoulder_target=torso(np.array([[.42,1.32,-.17]])*scale)[0]
    elbow_target=two_bone(shoulder_target,grip_target,.335,.320+.085,np.array([.55,.34,.03]))
    hand_axis=(grip_target-elbow_target)/np.linalg.norm(grip_target-elbow_target)
    wrist_target=grip_target-hand_axis*.085
    finger_curl=-(grip_target-np.array([0,.54,-.31]))
    finger_curl-=hand_axis*np.dot(finger_curl,hand_axis)
    finger_curl/=np.linalg.norm(finger_curl)
    fingertip_target=wrist_target+hand_axis*.145

    def mirror(point, side):
        return np.array(point)*np.array([side,1,1])

    def pose(points, index):
        if index in [0,1,2,3,4]:
            neck = np.array([0,1.50,-.23])*scale
            return points-neck+torso(neck[None,:])[0]
        if index in [11,12,13,20]:
            return torso(points)
        side = -1 if index in [5,6,7,14,15,16] else 1
        def blend(a,b,low,high):
            weight=np.clip((points[:,1]/scale-low)/(high-low),0,1)
            weight=weight*weight*(3-2*weight)
            return a*(1-weight[:,None])+b*weight[:,None]
        if index in [5,6,7,8,9,10]:
            # Tailored sleeve volume: the source forearm is almost as wide as
            # its upper sleeve. Narrow the cuff gradually around the bone axis.
            axis_start=np.array([side*.96,.31,-.23])*scale
            axis_end=np.array([side*.73,.83,-.17])*scale
            axis=(axis_end-axis_start)/np.linalg.norm(axis_end-axis_start)
            offset=points-axis_start
            radial=offset-np.outer(offset@axis,axis)
            cuff_weight=np.clip((1.08-points[:,1]/scale)/.70,0,1)
            points=points-radial*(.23*cuff_weight[:,None])
            shoulder=mirror(shoulder_target,side)
            elbow=mirror(elbow_target,side)
            wrist=mirror(wrist_target,side)
            upper=segment(points,[side*.42,1.32,-.17],[side*.73,.83,-.17],shoulder,elbow)
            forearm=segment(points,[side*.73,.83,-.17],[side*.96,.31,-.23],elbow,wrist)
            hand=segment(points,[side*.96,.31,-.23],[side*1.02,-.23,-.23],
                         wrist,mirror(fingertip_target,side))
            # Curl the distal fingers around the rim cross-section. The
            # wrist/proximal palm keeps the forearm's neutral axis.
            direction=mirror(hand_axis,side)
            inward=mirror(finger_curl,side)
            tangent=np.cross(direction,inward)
            along=(hand-wrist)@direction
            palm_taper=np.clip((.31-points[:,1]/scale)/.20,0,1)
            palm_taper=palm_taper*palm_taper*(3-2*palm_taper)
            arc=np.clip((along-.070)/.020,0,2.75)
            radial=(hand-wrist-along[:,None]*direction)*(1-.30*palm_taper[:,None])
            bent_radial=(radial*np.cos(arc)[:,None]+np.cross(tangent,radial)*np.sin(arc)[:,None]+
                         (radial@tangent)[:,None]*tangent*(1-np.cos(arc))[:,None])
            center=(wrist+np.minimum(along,.070)[:,None]*direction+
                    .020*np.sin(arc)[:,None]*direction+.020*(1-np.cos(arc))[:,None]*inward)
            remainder=np.maximum(along-.070-.020*2.75,0)
            center+=remainder[:,None]*(np.cos(arc)[:,None]*direction+np.sin(arc)[:,None]*inward)
            hand=center+bent_radial
            arm=blend(hand,forearm,.26,.40)
            arm=blend(arm,upper,.69,.96)
            return blend(arm,torso(points),1.15,1.36)
        if index in [14,15,16,17,18,19]:
            hip,knee,ankle=[mirror(v,side)for v in [hip_target,knee_target,ankle_target]]
            thigh=segment(points,[side*.22,-.11,-.23],[side*.25,-1.07,-.20],hip,knee)
            shin=segment(points,[side*.25,-1.07,-.20],[side*.30,-2.02,-.17],knee,ankle)
            reflect=np.diag([side,1,1])
            rotation=reflect@foot_rotation@reflect
            foot=(points-mirror(sole_source,side))@rotation.T+mirror(sole_target,side)
            if index in [14,17]:
                return foot
            leg=blend(foot,shin,-2.10,-1.88)
            leg=blend(leg,thigh,-1.22,-.91)
            return blend(leg,torso(points),-.29,.06)
        raise ValueError(index)

    result = {"asset": dict(source["asset"]), "scene": 0, "scenes": [{"nodes": [0]}],
              "nodes": [{"name": "TomkartDriver", "mesh": 0}], "meshes": [{"name": "TomkartSeatedDriver", "primitives": []}],
              "materials": source["materials"], "images": source["images"], "textures": source["textures"],
              "samplers": source.get("samplers", []), "buffers": [{"uri": "driver.bin"}], "bufferViews": [], "accessors": []}
    result["asset"]["generator"] = "Beat my track offline seated adaptation of tomkart's CC-BY-4.0 model"
    result["asset"]["extras"]["modifications"] = "Control-fitted seated pose; continuous remeshed garment; lettering and brand marks removed."
    payload = bytearray()

    def write(values, kind, component=5126):
        values = np.asarray(values, dtype={5126: "<f4", 5123: "<u2",5125:"<u4"}[component])
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

    hip,knee,ankle=hip_target,knee_target,ankle_target
    report={"source_sha256":hashlib.sha256(args.archive.read_bytes()).hexdigest(),
            "pelvis_corrective_translation":(pelvis_target-np.array([0,.005,0])-reclined((np.array([0,-.11,-.23])*scale)[None,:])[0]).tolist(),
            "scale":scale,"torso_recline_degrees":float(np.rad2deg(lean)),
            "foot_rotation_degrees":float(np.rad2deg(foot_angle)),"toe_splay_degrees":float(np.rad2deg(toe_splay)),
            "hip":hip.tolist(),"knee":knee.tolist(),"ankle":ankle.tolist(),
            "knee_flexion_degrees":float(np.rad2deg(np.arccos(np.clip(np.dot(knee-hip,ankle-knee)/
                (np.linalg.norm(knee-hip)*np.linalg.norm(ankle-knee)),-1,1)))),
            "thigh_length":float(np.linalg.norm(knee-hip)),"shin_length":float(np.linalg.norm(ankle-knee)),
            "shoulder":shoulder_target.tolist(),"elbow":elbow_target.tolist(),
            "grip":grip_target.tolist(),"fingertip":fingertip_target.tolist(),
            "wrist_angle_degrees":float(np.rad2deg(np.arccos(np.clip(np.dot((wrist_target-elbow_target)/np.linalg.norm(wrist_target-elbow_target),(fingertip_target-wrist_target)/np.linalg.norm(fingertip_target-wrist_target)),-1,1)))),
            "wrist":wrist_target.tolist(),"sole_contact":sole_target.tolist(),"parts":[]}
    cloth_parts=[]
    def emit(positions,normals,uv,indices,material,label,colors=None):
        result["meshes"][0]["primitives"].append({"attributes":{
            "POSITION":write(positions,"VEC3"),"NORMAL":write(normals,"VEC3"),
            "TEXCOORD_0":write(uv,"VEC2")},
            "indices":write(indices.reshape(-1),"SCALAR",5125),"material":material})
        if colors is not None:
            result["meshes"][0]["primitives"][-1]["attributes"]["COLOR_0"]=write(colors,"VEC3")
        report["parts"].append({"source_mesh":label,"triangles":len(indices.reshape(-1))//3,
                              "min":positions.min(0).tolist(),"max":positions.max(0).tolist()})
    for index,mesh in enumerate(source["meshes"]):
        if index==12:
            continue
        primitive=mesh["primitives"][0]
        vertices=read(primitive["attributes"]["POSITION"])
        transformed=(world[index]@np.c_[vertices,np.ones(len(vertices))].T).T[:,:3]
        standing=transformed@forward.T*scale
        faces=read(primitive["indices"]).reshape(-1,3)
        if index in [6,7,9,10,11,13,15,16,18,19,20]:
            standing,mapping=np.unique(standing.round(5),axis=0,return_inverse=True)
            faces=mapping[faces]
            edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
            _,counts=np.unique(edges,axis=0,return_counts=True)
            print("Source garment",index,"boundary edges",int(np.sum(counts==1)),flush=True)
            standing,faces=subdivide(standing,faces,2)
            cloth_parts.append((pose(standing,index),faces))
            cloth_material=primitive["material"]
            continue
        source_uv=read(primitive["attributes"]["TEXCOORD_0"])
        source_normals=read(primitive["attributes"]["NORMAL"])
        if index in [5,8]:
            attributes,faces=subdivide(np.c_[standing,source_uv,source_normals],faces,1)
            standing,source_uv,source_normals=attributes[:,:3],attributes[:,3:5],attributes[:,5:]
        if index in [14,17]:
            # Flatten only the original tread contact vertices, removing its
            # tiny left/right tilt before aligning with the pedal plane.
            sole=standing[:,1]<standing[:,1].min()+.055*scale
            standing[sole,1]=sole_source[1]
            # A small outsole lip keeps the tilted sole covering the pedal's
            # full load patch; the upper boot and toe width stay unchanged.
            side=-1 if index==14 else 1
            center=side*sole_source[0]
            standing[sole,0]=center+(standing[sole,0]-center)*1.15
        positions=pose(standing,index)
        epsilon=1e-5
        jacobian=np.stack([(pose(standing+np.eye(3)[axis]*epsilon,index)-
                            pose(standing-np.eye(3)[axis]*epsilon,index))/(2*epsilon)
                            for axis in range(3)],axis=2)
        linear=jacobian@forward@world[index][:3,:3]
        normals=np.einsum('ni,nij->nj',source_normals,np.linalg.inv(linear))
        normals/=np.linalg.norm(normals,axis=1,keepdims=True)
        emit(positions,normals,source_uv,faces,primitive["material"],index)
    positions,faces=union_cloth(cloth_parts)
    def rgb(value):
        return np.array([int(value[n:n+2],16)/255 for n in [0,2,4]])
    colors=np.tile(rgb("465861"),(len(positions),1))
    local=((positions-pelvis_target)@torso_rotation+pelvis_source)/scale
    # Native panels follow the garment, rather than world-height thresholds.
    def smooth(value,low,high):
        t=np.clip((value-low)/(high-low),0,1)
        return t*t*(3-2*t)
    yoke=smooth(local[:,1],1.10,1.14)*(1-smooth(local[:,1],1.26,1.30))
    yoke*=1-smooth(np.abs(local[:,0]),.40,.49)
    yoke*=1-smooth(local[:,2],-.33,-.28)
    colors=colors*(1-yoke[:,None])+rgb("73868b")*yoke[:,None]
    collar=(local[:,1]>1.39)&(np.abs(local[:,0])<.29)
    colors[collar]=rgb("26343a")
    waist=(local[:,1]>.27)&(local[:,1]<.39)&(np.abs(local[:,0])<.43)&(positions[:,2]>.02)
    colors[waist]=rgb("2b3d46")
    side_panel=(np.abs(local[:,0])>.34)&(local[:,1]>.40)&(local[:,1]<1.1)&(positions[:,2]>.02)
    colors[side_panel]=rgb("354852")
    for side in [-1,1]:
        cuff=np.linalg.norm(positions-mirror(wrist_target,side),axis=1)<.045
        colors[cuff]=rgb("26343a")
        knee_distance=np.linalg.norm((positions-mirror(knee_target,side))*[1,1.0,1.0],axis=1)
        knee_panel=(knee_distance<.10)&(positions[:,1]>knee_target[1]+.015)
        colors[knee_panel]=rgb("354852")
    emit(positions,mesh_normals(positions,faces),positions[:,[0,1]],faces,cloth_material,"continuous_suit",colors)
    seam_vertices,seam_faces=front_seam(positions,faces,[(0,y)for y in np.linspace(.445,torso((np.array([0,1.50,-.23])*scale)[None,:])[0,1]-.015,35)])
    emit(seam_vertices,mesh_normals(seam_vertices,seam_faces),seam_vertices[:,[0,1]],seam_faces,
         cloth_material,"zipper",np.tile(rgb("8a9697"),(len(seam_vertices),1)))
    result["buffers"][0]["byteLength"] = len(payload)
    (output / "driver.bin").write_bytes(payload)
    (output / "driver.gltf").write_text(json.dumps(result, separators=(",", ":")) + "\n", encoding="utf-8")
    (output / "pose.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Posed", sum(part["triangles"] for part in report["parts"]), "triangles in", output)


if __name__ == "__main__":
    main()
