extends RefCounted
## Offline final packing, after batching and LOD creation. No runtime work.
static func bake(path: String, vehicle: String) -> Error:
	if vehicle not in ["compact","forklift"]: return OK
	var scene: PackedScene = load(path)
	if scene==null: return ERR_CANT_OPEN
	var holder: Node = scene.instantiate()
	var seen: Dictionary = {}
	var before: int = 0
	var after: int = 0
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh: continue
		if not seen.has(part.mesh):
			before += payload(part.mesh)
			seen[part.mesh] = preload("res://rendering/mesh_vertex_packing.gd").pack(part.mesh)
			after += payload(seen[part.mesh])
		part.mesh = seen[part.mesh]
	detach(holder)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error==OK: error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	print("CAR_MODEL_PACK ",path," ",before," -> ",after," saved=",before-after)
	return error

static func detach(holder: Node) -> void:
	# Source/LOD caches can share a mesh between successive quality bakes.
	# Give each saved scene fresh embedded identities without re-encoding data.
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		if not meshes.has(part.mesh):
			var copy: Mesh = part.mesh.duplicate()
			copy.resource_scene_unique_id = ""
			meshes[part.mesh] = copy
		part.mesh = meshes[part.mesh]
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material = part.get_active_material(surface)
			if material!=null and not materials.has(material):
				material.resource_scene_unique_id = ""
				materials[material] = true

static func payload(mesh: ArrayMesh) -> int:
	var bytes: int = 0
	for surface: Dictionary in mesh.get("_surfaces"):
		for key: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: bytes += surface.get(key,PackedByteArray()).size()
		var levels: Array = surface.get("lods",[])
		for index: int in range(1,levels.size(),2): bytes += levels[index].size()
	return bytes
