extends RefCounted
## Offline-only index preparation. Runtime never runs mesh simplification.
var meshes: Dictionary = {}
var totals: Dictionary = {"meshes":0,"with_lods":0,"lods":0,"original_triangles":0,"smallest_triangles":0,"changed_vertex_streams":0}

func cache_order(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	# Reorder existing triangles only. Keep their corner order, every master
	# attribute/index byte, LOD error and screen-size threshold unchanged.
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_INDEX]=indices
	var temporary:=ArrayMesh.new()
	temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool:=SurfaceTool.new()
	tool.create_from(temporary,0)
	tool.optimize_indices_for_cache()
	var reordered: Array=tool.commit_to_arrays()
	assert(reordered[Mesh.ARRAY_VERTEX]==vertices)
	return reordered[Mesh.ARRAY_INDEX]

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
	if source.has_meta("car_authored_far"): return source
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
				lods[maxf(0.000001,importer.get_surface_lod_size(surface,index))] = cache_order(arrays[Mesh.ARRAY_VERTEX],importer.get_surface_lod_indices(surface,index))
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

func eligible(part: MeshInstance3D, vehicle: String) -> bool:
	# Authored joining skins already have their final compact sample rows.
	if part.mesh.has_meta("car_surface_guide_locked"): return false
	if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return false
	for surface: int in range(part.mesh.get_surface_count()):
		var material: Material = part.get_active_material(surface)
		if material is ShaderMaterial and material.shader != null and material.shader.resource_path in ["res://vehicle/electric_glass.gdshader","res://vehicle/window_reflection.gdshader"]: return false
	if vehicle == "hovercraft":
		# The separate rubber bag clears the canopy/deck layers. Its original
		# vertices/normals remain available at close range, like the fan rotors.
		if str(part.name)=="SportPressureSkirt": return true
		# Only the independently articulated rotors are separated from the layered
		# hull/canopy/ducts. Stable rotor names survive base and module packing.
		var ancestor: Node = part.get_parent()
		while ancestor != null:
			if str(ancestor.name) in ["FanRotorLeft","FanRotorRight"]: return true
			ancestor = ancestor.get_parent()
		return false
	return true

func prepare_vehicle(holder: Node, vehicle: String, bias: float = 1.0) -> void:
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		if not part.mesh.has_meta("car_authored_far"):
			part.mesh = prepare(part.mesh) if eligible(part,vehicle) else full_detail(part.mesh)
		# The race viewport retains its world-wide one-pixel policy. A car-only
		# bias of two uses the conservative half-pixel car threshold instead.
		# Garage viewports already use half a pixel and retain their unit bias.
		part.lod_bias = bias

func bake(path: String, vehicle: String = "", bias: float = 1.0) -> Error:
	if vehicle.is_empty() and path.get_file().get_basename() in VehicleCatalog.IDS:
		vehicle = path.get_file().get_basename()
	var scene: PackedScene = load(path)
	if scene == null: return ERR_CANT_OPEN
	var holder: Node = scene.instantiate()
	prepare_vehicle(holder,vehicle,bias)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error == OK: error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
