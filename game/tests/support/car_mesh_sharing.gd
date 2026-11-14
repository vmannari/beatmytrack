extends RefCounted
## Offline exact storage sharing. Instance transforms and mutable finishes stay owned.
static func key(mesh: ArrayMesh) -> String:
	var data: Array=[mesh.custom_aabb,mesh.get_aabb(),mesh.resource_name]
	for name: StringName in mesh.get_meta_list(): data.append([str(name),mesh.get_meta(name)])
	for packet: Dictionary in mesh.get("_surfaces"):
		var copy: Dictionary=packet.duplicate()
		copy.erase("material")
		data.append(copy)
	return var_to_bytes(data).hex_encode().sha256_text()

static func apply(holder: Node) -> int:
	var canonical: Dictionary={}
	var replacements: int=0
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0 or part.mesh.shadow_mesh!=null: continue
		# Material stored in a shared mesh must never become an active mutable finish.
		var independent: bool=true
		for surface: int in range(part.mesh.get_surface_count()):
			if part.material_override==null and part.get_surface_override_material(surface)==null: independent=false
		if not independent: continue
		var code: String=key(part.mesh)
		if canonical.has(code):
			if canonical[code]!=part.mesh: part.mesh=canonical[code]; replacements+=1
		else: canonical[code]=part.mesh
	return replacements
