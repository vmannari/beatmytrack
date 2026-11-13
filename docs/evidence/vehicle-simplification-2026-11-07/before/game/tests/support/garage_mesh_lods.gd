extends RefCounted
## Offline-only index preparation. Runtime never runs mesh simplification.
var meshes: Dictionary = {}
var totals: Dictionary = {"meshes":0,"with_lods":0,"lods":0,"original_triangles":0,"smallest_triangles":0,"changed_vertex_streams":0}

func full_detail(source: Mesh) -> Mesh:
	if not source is ArrayMesh: return source
	var surfaces: Array = source.get("_surfaces").duplicate(true)
	for surface: Dictionary in surfaces: surface.erase("lods")
	var result := ArrayMesh.new()
	result.set("_surfaces",surfaces)
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	return result

func prepare(source: Mesh) -> Mesh:
	if meshes.has(source): return meshes[source]
	if not source is ArrayMesh or source.get_blend_shape_count() != 0: return source
	var importer := ImporterMesh.new()
	for surface: int in range(source.get_surface_count()):
		importer.add_surface(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),[],{},source.surface_get_material(surface))
	importer.generate_lods(0.0,0.0,[])
	var result := ArrayMesh.new()
	var original_surfaces: Array = source.get("_surfaces").duplicate(true)
	var count: int = 0
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var generated: Array = importer.get_surface_arrays(surface)
		var same: bool = true
		for attribute: int in range(Mesh.ARRAY_INDEX):
			if arrays[attribute] != generated[attribute]: same = false
		var lods: Dictionary = {}
		if same:
			for index: int in range(importer.get_surface_lod_count(surface)):
				lods[maxf(0.000001,importer.get_surface_lod_size(surface,index))] = importer.get_surface_lod_indices(surface,index)
		else: totals.changed_vertex_streams += 1
		var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
		totals.original_triangles += indices/3
		var smallest: int = indices
		for level: PackedInt32Array in lods.values(): smallest = mini(smallest,level.size())
		totals.smallest_triangles += smallest/3
		totals.lods += lods.size()
		count += lods.size()
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,[],lods,source.surface_get_format(surface) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		result.surface_set_material(surface,source.surface_get_material(surface))
		result.surface_set_name(surface,source.surface_get_name(surface))
	# Re-encoding compressed normals/tangents can round the original GPU bytes.
	# Use the pinned engine's resource storage format to transfer only new LOD
	# index buffers; positions, normals, UVs, colors and original indices stay exact.
	var generated_surfaces: Array = result.get("_surfaces")
	for surface: int in range(original_surfaces.size()):
		if generated_surfaces[surface].has("lods"):
			original_surfaces[surface].lods = generated_surfaces[surface].lods
	var exact := ArrayMesh.new()
	exact.set("_surfaces",original_surfaces)
	exact.custom_aabb = source.custom_aabb
	exact.shadow_mesh = source.shadow_mesh
	for surface: int in range(source.get_surface_count()):
		assert(exact.surface_get_arrays(surface) == source.surface_get_arrays(surface))
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	meshes[source] = exact if count > 0 else source
	totals.meshes += 1
	if count > 0: totals.with_lods += 1
	return meshes[source]

func bake(path: String) -> Error:
	var scene: PackedScene = load(path)
	var holder: Node = scene.instantiate()
	for part: Node in holder.find_children("*","MeshInstance3D",true,false):
		# Independently decimating close curved layers can make their triangles
		# intersect. Keep the layered Hover cockpit/hull and all glazing exact.
		var layered: bool = path.ends_with("/hovercraft.scn")
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material = part.get_active_material(surface)
			if material is ShaderMaterial and material.shader != null and material.shader.resource_path in ["res://vehicle/electric_glass.gdshader","res://vehicle/window_reflection.gdshader"]: layered = true
		part.mesh = full_detail(part.mesh) if layered else prepare(part.mesh)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error == OK: error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
