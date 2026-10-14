class_name SpatialMeshChunks
extends RefCounted
## Immutable static meshes partitioned without clipping or resampling triangles.
const TILE_SIZE: float = 32.0
const MIN_TRIANGLES: int = 1024
const MAX_CHUNKS: int = 256

static func add(parent: Node3D, source: MeshInstance3D, enabled: bool = true, keep_original: bool = false) -> Array[MeshInstance3D]:
	if not enabled or source.mesh == null or source.mesh.get_surface_count() != 1:
		parent.add_child(source)
		return [source]
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var extent: Vector3 = source.mesh.get_aabb().size
	if count/3 < MIN_TRIANGLES or maxf(extent.x,extent.z) <= TILE_SIZE*1.5:
		parent.add_child(source)
		return [source]
	var size: float = TILE_SIZE
	var groups: Dictionary = {}
	while true:
		groups.clear()
		for start: int in range(0,count,3):
			var a: int = indices[start] if not indices.is_empty() else start
			var b: int = indices[start+1] if not indices.is_empty() else start+1
			var c: int = indices[start+2] if not indices.is_empty() else start+2
			var center: Vector3 = (vertices[a]+vertices[b]+vertices[c])/3.0
			var key := Vector2i(floori(center.x/size),floori(center.z/size))
			if not groups.has(key): groups[key] = PackedInt32Array()
			groups[key].append_array(PackedInt32Array([a,b,c]))
		if groups.size() <= MAX_CHUNKS: break
		size *= 2.0
	if groups.size() <= 1:
		parent.add_child(source)
		return [source]
	var result: Array[MeshInstance3D] = []
	var source_name: String = str(source.name) if not source.name.is_empty() else "MeshInstance3D"
	for key: Vector2i in groups:
		var chosen: PackedInt32Array = groups[key]
		var map: Dictionary = {}
		var used := PackedInt32Array()
		for corner: int in range(chosen.size()):
			var original: int = chosen[corner]
			if not map.has(original):
				map[original] = used.size()
				used.append(original)
			chosen[corner] = map[original]
		var part: Array = []
		part.resize(Mesh.ARRAY_MAX)
		for attribute: int in range(Mesh.ARRAY_INDEX):
			if arrays[attribute] == null: continue
			var data: Variant = arrays[attribute].slice(0,0)
			var stride: int = 4 if attribute in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS] else 1
			data.resize(used.size()*stride)
			for index: int in range(used.size()):
				for component: int in range(stride): data[index*stride+component] = arrays[attribute][used[index]*stride+component]
			part[attribute] = data
		part[Mesh.ARRAY_INDEX] = chosen
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part)
		var node := MeshInstance3D.new()
		node.name = source_name if result.is_empty() else source_name+"_Tile_"+str(key.x)+"_"+str(key.y)
		node.mesh = mesh
		node.material_override = source.material_override
		node.transform = source.transform
		node.layers = source.layers
		node.cast_shadow = source.cast_shadow
		node.extra_cull_margin = source.extra_cull_margin
		for metadata: StringName in source.get_meta_list(): node.set_meta(metadata,source.get_meta(metadata))
		node.set_meta("spatial_mesh_tile",key)
		node.set_meta("spatial_mesh_tile_size",size)
		parent.add_child(node)
		result.append(node)
	if not keep_original: source.free()
	return result
