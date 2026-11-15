"""Conservative enclosed-face and screen-density study of exported live pieces."""
from __future__ import annotations
import json
import math
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-deep-review-2026-11-14"
WORK = ROOT / "build/car-deep-review-2026-11-14"
MARGIN = 0.0005
WORLD_EXTENT = 35/1.15
ELEVATION = math.radians(56)


def geometry(row, data):
    surfaces=[]
    for surface in row["surfaces"]:
        vertices=np.frombuffer(data,dtype="<f4",count=surface["vertex_count"]*3,
                               offset=surface["vertex_offset"]).reshape(-1,3).astype(np.float64)
        indices=np.frombuffer(data,dtype="<i4",count=surface["index_count"],
                              offset=surface["index_offset"]).reshape(-1,3)
        surfaces.append((vertices,indices))
    triangles=np.concatenate([v[i] for v,i in surfaces])
    row["_surfaces"]=surfaces
    row["_triangles"]=triangles
    row["_low"]=triangles.min(axis=(0,1));row["_high"]=triangles.max(axis=(0,1))
    row["_protected"]=bool(row["morphs"] or any(x in row["path"] for x in ("Driver","Helmet","SteeringAssembly")))


def convex_planes(row):
    if not row["opaque"] or row["_protected"] or len(row["surfaces"])!=1 or row["triangles"]>1500:
        return None
    triangles=row["_triangles"]
    cross=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
    lengths=np.linalg.norm(cross,axis=1)
    keep=lengths>1e-12
    triangles=triangles[keep];cross=cross[keep];lengths=lengths[keep]
    if len(triangles)<4:
        return None
    # Close position seams, then require each geometric edge exactly twice.
    _,ids=np.unique(np.rint(triangles.reshape(-1,3)*1e6).astype(np.int64),axis=0,return_inverse=True)
    faces=ids.reshape(-1,3)
    edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
    if not np.all(np.unique(edges,axis=0,return_counts=True)[1]==2):
        return None
    vertices=np.unique(triangles.reshape(-1,3),axis=0)
    center=vertices.mean(axis=0)
    signed=np.einsum("ij,ij->i",cross,triangles.mean(axis=1)-center)
    # Godot fronts are clockwise. Reject inward-only or mixed-winding solids
    # under back culling; double-sided solids must still be consistently wound.
    if row["cull_mode"]==1 or (row["cull_mode"]==0 and np.any(signed>1e-10)):
        return None
    if np.any(signed>1e-10) and np.any(signed<-1e-10):
        return None
    normals=cross/lengths[:,None]
    normals[np.einsum("ij,ij->i",normals,triangles.mean(axis=1)-center)<0]*=-1
    distance=np.einsum("ij,ij->i",normals,triangles[:,0])
    rounded=np.rint(np.column_stack((normals,distance))*1e6).astype(np.int64)
    _,unique=np.unique(rounded,axis=0,return_index=True)
    normals=normals[unique];distance=distance[unique]
    if len(normals)>256 or (vertices@normals.T-distance).max()>2e-6:
        return None
    return normals,distance


def selected_proposal(parts, masks):
    result=[]
    for part,mask in zip(parts,masks):
        if not np.any(mask):continue
        rows={};offset=0
        for surface,(vertices,indices) in enumerate(part["_surfaces"]):
            selected=np.flatnonzero(mask[offset:offset+len(indices)]).tolist()
            if selected:rows[str(surface)]=selected
            offset+=len(indices)
        result.append({"ordinal":part["ordinal"],"name":part["name"],"triangles":part["triangles"],
                       "removed":int(mask.sum()),"surfaces":rows})
    return result


def main():
    inventory=json.loads((OUT/"inventory.json").read_text())
    reports=[];proposals={}
    for car in inventory["sources"]:
        pixels_per_local_metre=720/WORLD_EXTENT*car["model_scale"]
        data=(WORK/(car["vehicle"]+"-geometry.bin")).read_bytes()
        parts=car["parts"]
        for part in parts:geometry(part,data)
        occluders=[]
        for part in parts:
            planes=convex_planes(part)
            if planes is not None:occluders.append((part,planes))
        masks=[];zero_masks=[];details=[]
        for part in parts:
            triangles=part["_triangles"]
            zero=np.all(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])==0,axis=1)
            enclosed=np.zeros(len(triangles),dtype=bool)
            if not part["_protected"]:
                minimum=triangles.min(axis=1);maximum=triangles.max(axis=1)
                for other,(normals,distance) in occluders:
                    if other["ordinal"]==part["ordinal"] or part["frame"]!=other["frame"]:continue
                    if part["layers"]!=other["layers"]:continue
                    if part["cast_shadow"]!=0 and other["cast_shadow"]==0:continue
                    if np.any(part["_high"]<other["_low"]+MARGIN) or np.any(part["_low"]>other["_high"]-MARGIN):continue
                    possible=np.flatnonzero(~enclosed & np.all(minimum>other["_low"]+MARGIN,axis=1)
                                            & np.all(maximum<other["_high"]-MARGIN,axis=1))
                    if not len(possible):continue
                    selected=triangles[possible].reshape(-1,3)
                    inside=np.all(selected@normals.T-distance < -MARGIN,axis=1).reshape(-1,3).all(axis=1)
                    enclosed[possible[inside]]=True
            max_area=np.zeros(len(triangles))
            span=0.0
            for angle in np.arange(8)*np.pi/4:
                elevation=ELEVATION
                right=np.array([np.cos(angle),0,-np.sin(angle)])
                up=np.array([-np.sin(angle)*np.sin(elevation),np.cos(elevation),-np.cos(angle)*np.sin(elevation)])
                projected=np.stack([triangles@right,triangles@up],axis=-1)*pixels_per_local_metre
                a=projected[:,1]-projected[:,0];b=projected[:,2]-projected[:,0]
                max_area=np.maximum(max_area,0.5*np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0]))
                span=max(span,float(np.ptp(projected,axis=(0,1)).max()))
            masks.append(enclosed);zero_masks.append(zero & ~part["_protected"])
            details.append({"ordinal":part["ordinal"],"path":part["path"],"kind":part["kind"],
                            "triangles":part["triangles"],"enclosed":int(enclosed.sum()),
                            "strict_zero_area":int(zero.sum()),"all_heading_under_quarter_pixel":int((max_area<0.25).sum()),
                            "all_heading_under_one_pixel":int((max_area<1).sum()),"max_span_race_pixels":round(span,3)})
        combined=[a|b for a,b in zip(masks,zero_masks)]
        proposals[car["vehicle"]]={"enclosed":selected_proposal(parts,masks),"zero_area":selected_proposal(parts,zero_masks),
                                   "invisible_cleanup":selected_proposal(parts,combined)}
        row={"vehicle":car["vehicle"],"triangles":car["triangles"],"source_parts":len(parts),"qualified_convex_occluders":len(occluders),
             "enclosed_triangles":sum(int(a.sum()) for a in masks),"zero_area_triangles":sum(int(a.sum()) for a in zero_masks),
             "cleanup_union_triangles":sum(int(a.sum()) for a in combined),"round_candidate":car["round_candidate"],
             "under_quarter_pixel_triangles":sum(x["all_heading_under_quarter_pixel"] for x in details),
             "under_one_pixel_triangles":sum(x["all_heading_under_one_pixel"] for x in details),
             "tiny_parts_under_one_pixel":sum(x["max_span_race_pixels"]<1 for x in details),
             "details":sorted(details,key=lambda x:x["triangles"],reverse=True)}
        reports.append(row)
        print(car["vehicle"],"convex",len(occluders),"enclosed",row["enclosed_triangles"],"zero",row["zero_area_triangles"],
              "small_round",car["round_candidate"]["saved_triangles"],"subpixel",row["under_quarter_pixel_triangles"])
    (OUT/"geometry-analysis.json").write_text(json.dumps({"containment_margin_m":MARGIN,"projection":{"height_px":720,"world_extent_m":WORLD_EXTENT,"elevation_rad":ELEVATION,"headings":8,"model_scale":"per-car source model_scale; 0.88 in this sample","speed_zoom_multiplier":1.0},"cars":reports},indent=2)+"\n")
    (WORK/"proposals.json").write_text(json.dumps(proposals))


if __name__=="__main__":main()
