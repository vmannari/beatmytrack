class_name SpatialMeshChunks
extends RefCounted
## Immutable static meshes partitioned without clipping or resampling triangles.
const TILE_SIZE: float = 32.0
const MIN_TRIANGLES: int = 1024
const MAX_CHUNKS: int = 256

static func add(parent: Node3D, source: MeshInstance3D, enabled: bool = true, keep_original: bool = false, adaptive: bool = true, extra_budget: int = -1) -> Array[MeshInstance3D]:
	# Preserve the synchronous API. Without a callback, the shared implementation
	# cannot reach an await; Callable avoids marking existing callers coroutines.
	var build: Callable = add_cooperative
	return build.call(parent,source,enabled,keep_original,adaptive,extra_budget)

static func add_cooperative(parent: Node3D, source: MeshInstance3D, enabled: bool = true, keep_original: bool = false, adaptive: bool = true, extra_budget: int = -1, cooperate: Callable = Callable()) -> Array[MeshInstance3D]:
	if not enabled or source.mesh == null or source.mesh.get_surface_count() != 1:
		_attach(parent,source)
		return [source]
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var extent: Vector3 = source.mesh.get_aabb().size
	# Include boundary-vertex duplication and node allowance conservatively.
	var estimate: int = ceili((vertices.size()*96+count*4)*1.2)+MAX_CHUNKS*512
	if adaptive and extra_budget >= 0 and estimate > extra_budget:
		_attach(parent,source)
		return [source]
	if count/3 < MIN_TRIANGLES or maxf(extent.x,extent.z) <= TILE_SIZE*1.5:
		_attach(parent,source)
		return [source]
	var size: float = TILE_SIZE
	var groups: Dictionary = {}
	var object_ends: PackedInt32Array = source.get_meta("spatial_object_ends",PackedInt32Array())
	var object_centres: PackedVector3Array = source.get_meta("spatial_object_centres",PackedVector3Array())
	while true:
		groups.clear()
		for start: int in range(0,count,3):
			if start % 768 == 0 and cooperate.is_valid() and not await cooperate.call(): return []
			var a: int = indices[start] if not indices.is_empty() else start
			var b: int = indices[start+1] if not indices.is_empty() else start+1
			var c: int = indices[start+2] if not indices.is_empty() else start+2
			var center: Vector3 = (vertices[a]+vertices[b]+vertices[c])/3.0
			if not object_ends.is_empty():
				var object: int = object_ends.bsearch(a+1)
				assert(object<object_centres.size(),"Static prop assembly ranges must cover every triangle.")
				center = object_centres[object]
			var key := Vector2i(floori(center.x/size),floori(center.z/size))
			if not groups.has(key): groups[key] = PackedInt32Array()
			groups[key].append_array(PackedInt32Array([a,b,c]))
		if groups.size() <= MAX_CHUNKS: break
		size *= 2.0
	if groups.size() <= 1:
		_attach(parent,source)
		return [source]
	var result: Array[MeshInstance3D] = []
	# Preserve the original quantized normal/tangent stream. Decoding and then
	# uploading normals again can truncate an octahedral code one step lower.
	var raw: Dictionary = RenderingServer.mesh_get_surface(source.mesh.get_rid(),0)
	var format: int = source.mesh.surface_get_format(0)
	var preserve_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null and not (format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	var normal_offset: int = RenderingServer.mesh_surface_get_format_offset(format,vertices.size(),Mesh.ARRAY_NORMAL) if preserve_normals else 0
	var normal_stride: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,vertices.size()) if preserve_normals else 0
	var source_name: String = str(source.name) if not source.name.is_empty() else "MeshInstance3D"
	for key: Vector2i in groups:
		if cooperate.is_valid() and not await cooperate.call(): return []
		var chosen: PackedInt32Array = groups[key]
		var map: Dictionary = {}
		var used := PackedInt32Array()
		for corner: int in range(chosen.size()):
			if corner % 512 == 0 and cooperate.is_valid() and not await cooperate.call(): return []
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
				if index % 256 == 0 and cooperate.is_valid() and not await cooperate.call(): return []
				for component: int in range(stride):
					data[index*stride+component] = arrays[attribute][used[index]*stride+component]
			part[attribute] = data
		part[Mesh.ARRAY_INDEX] = chosen
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part)
		if preserve_normals:
			var packet: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),0)
			var packed: PackedByteArray = packet.vertex_data
			var destination_format: int = mesh.surface_get_format(0)
			var destination_offset: int = RenderingServer.mesh_surface_get_format_offset(destination_format,used.size(),Mesh.ARRAY_NORMAL)
			var destination_stride: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(destination_format,used.size())
			var original_data: PackedByteArray = raw.vertex_data
			assert(normal_stride==destination_stride and normal_stride in [4,8])
			for index: int in range(used.size()):
				if index % 512 == 0 and cooperate.is_valid() and not await cooperate.call(): return []
				if normal_stride==8: packed.encode_u64(destination_offset+index*destination_stride,original_data.decode_u64(normal_offset+used[index]*normal_stride))
				else: packed.encode_u32(destination_offset+index*destination_stride,original_data.decode_u32(normal_offset+used[index]*normal_stride))
			# Use ArrayMesh's serialized surface packet rather than a GPU update:
			# the headless dummy renderer ignores vertex-region updates. The pinned
			# engine's resource loader accepts the same format/versioned packet.
			packet.vertex_data = packed
			mesh.clear_surfaces()
			mesh.set("_surfaces",[packet])
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
		if adaptive:
			node.transform = Transform3D.IDENTITY
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.hide()
			source.add_child(node)
		else: parent.add_child(node)
		result.append(node)
	if adaptive:
		source.set_meta("spatial_mesh_family",true)
		source.set_script(preload("res://track/static_mesh_draw_view.gd"))
		source.set("draw_layers",source.layers)
		source.set("draw_shadow",source.cast_shadow)
		_attach(parent,source)
	elif not keep_original: source.free()
	return result

static func _attach(parent: Node3D, source: MeshInstance3D) -> void:
	if source.get_parent() != parent: parent.add_child(source)
