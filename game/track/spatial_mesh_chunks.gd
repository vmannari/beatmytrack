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
	var estimate: int = ceili((vertices.size()*96+count*4)*1.2)+MAX_CHUNKS*512+int(source.mesh.get_meta("scenery_lod_bytes",0))*2
	if adaptive and extra_budget >= 0 and estimate > extra_budget:
		_attach(parent,source)
		return [source]
	if count/3 < MIN_TRIANGLES or maxf(extent.x,extent.z) <= TILE_SIZE*1.5:
		_attach(parent,source)
		return [source]
	var object_ends: PackedInt32Array = source.get_meta("spatial_object_ends",PackedInt32Array())
	var object_centres: PackedVector3Array = source.get_meta("spatial_object_centres",PackedVector3Array())
	if not object_ends.is_empty() and not _valid_object_ranges(object_ends,object_centres,count):
		# Older cached/prepared meshes can carry ranges from before deformation.
		# Keep their complete drawable geometry attached rather than losing the
		# whole family when a detached staged source cannot be partitioned safely.
		_attach(parent,source)
		return [source]
	# Numerical grouping/remapping does not need the scene tree or renderer.
	# Running it on the existing worker removes repeated main-frame waits.
	var lod_packets: Array = preload("res://track/scenery_mesh_lods.gd").packets(source.mesh) if source.mesh is ArrayMesh else []
	var prepare: Callable = preload("res://track/spatial_mesh_preparation.gd").run.bind(arrays,indices,vertices,count,object_ends,object_centres,TILE_SIZE,MAX_CHUNKS,lod_packets)
	var prepared: Array = []
	if cooperate.is_valid() and parent.is_inside_tree():
		var job = preload("res://editor/work_job.gd").start(prepare,parent.get_tree())
		while not job.done:
			var frame: int = Engine.get_process_frames()
			if not await cooperate.call(): job.cancel(); return []
			if frame == Engine.get_process_frames(): await parent.get_tree().process_frame
		if not await cooperate.call(): return []
		prepared = job.result if job.result is Array else []
	else:
		prepared = prepare.call(func() -> bool: return false)
	if prepared.is_empty():
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
	for data: Dictionary in prepared:
		if cooperate.is_valid() and not await cooperate.call(): return []
		var key: Vector2i = data.key
		var size: float = data.size
		var part: Array = data.arrays
		var used: PackedInt32Array = data.used
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
		mesh = preload("res://track/scenery_mesh_lods.gd").attach(mesh,data.get("lods",{}))
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
		# Release this CPU packet as its immutable renderer resource takes over.
		# The completed WorkJob shares these dictionaries; it retains no copies.
		data.clear()
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

static func _valid_object_ranges(ends: PackedInt32Array, centres: PackedVector3Array, count: int) -> bool:
	if ends.size() != centres.size() or ends[-1] != count: return false
	var previous: int = 0
	for index: int in range(ends.size()):
		if ends[index] <= previous or ends[index] % 3 != 0 or not centres[index].is_finite(): return false
		previous = ends[index]
	return true
