"""Read the owner-supplied scene with embedded-script execution disabled."""
import bpy
import json
from pathlib import Path
import sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
source, destination = Path(args[0]), Path(args[1])
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
result = {"blender": bpy.app.version_string, "source": str(source), "objects": [], "materials": [],
          "images": [], "texts": [{"name": t.name, "characters": len(t.as_string())} for t in bpy.data.texts]}
original_modifiers = {}
for obj in bpy.data.objects:
    original_modifiers[obj.name] = [{"name": m.name, "type": m.type,
        "viewport": m.show_viewport, "render": m.show_render,
        **({"levels": m.levels, "render_levels": m.render_levels} if m.type == "SUBSURF" else {})} for m in obj.modifiers]
    for modifier in obj.modifiers:
        if modifier.type == "SUBSURF": modifier.levels = min(modifier.levels, 1)
depsgraph = bpy.context.evaluated_depsgraph_get()
for obj in bpy.data.objects:
    row = {"name": obj.name, "type": obj.type, "parent": obj.parent.name if obj.parent else None,
           "hide_render": obj.hide_render, "hide_viewport": obj.hide_viewport,
           "location": list(obj.location), "dimensions": list(obj.dimensions), "modifiers": original_modifiers[obj.name]}
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        row.update({"raw_triangles": len(obj.data.loop_triangles), "vertices": len(obj.data.vertices),
                    "materials": [m.name if m else None for m in obj.data.materials], "uv_layers": len(obj.data.uv_layers)})
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        row["world_bounds"] = [[min(v[i] for v in corners) for i in range(3)], [max(v[i] for v in corners) for i in range(3)]]
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh(); mesh.calc_loop_triangles()
        row["evaluated_level1_triangles"] = len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
        print(obj.name, row["raw_triangles"], row["evaluated_level1_triangles"], row["materials"], flush=True)
    result["objects"].append(row)
for mat in bpy.data.materials:
    result["materials"].append({"name": mat.name, "diffuse_color": list(mat.diffuse_color),
        "nodes": [{"name": n.name, "type": n.type,
                   **({"image": n.image.name if n.image else None} if n.type == "TEX_IMAGE" else {}),
                   **({"base_color": list(n.inputs["Base Color"].default_value),
                       "metallic": n.inputs["Metallic"].default_value,
                       "roughness": n.inputs["Roughness"].default_value} if n.type == "BSDF_PRINCIPLED" else {})}
                  for n in mat.node_tree.nodes] if mat.use_nodes else []})
for image in bpy.data.images:
    result["images"].append({"name": image.name, "size": list(image.size), "packed": bool(image.packed_file), "filepath": image.filepath})
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(result, indent=2), encoding="utf-8")
print("INSPECTION_SAVED", destination, flush=True)
