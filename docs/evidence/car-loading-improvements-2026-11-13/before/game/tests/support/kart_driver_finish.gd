extends RefCounted
## Split invariant helmet surfaces without changing positions or steering poses.
const ROOT = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
static func save(original: ArrayMesh) -> void:
	var pose_count: int = original.get_blend_shape_count()
	assert(original.get_surface_count()==6 and pose_count==preload("res://vehicle/kart_steering.gd").STEPS*2)
	var animated := ArrayMesh.new()
	animated.blend_shape_mode = original.blend_shape_mode
	for shape: int in range(pose_count): animated.add_blend_shape(original.get_blend_shape_name(shape))
	var packets: Array = original.get("_surfaces")
	var active: Array = []
	var static_packets: Array = []
	var removed: int = 0
	for surface: int in range(6):
		var packet: Dictionary = packets[surface].duplicate(true)
		if surface<2:
			if surface==1:
				var arrays: Array = original.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				arrays[Mesh.ARRAY_NORMAL] = soften(arrays[Mesh.ARRAY_NORMAL],indices)
				var shapes: Array[Array] = original.surface_get_blend_shape_arrays(surface)
				for shape: Array in shapes: shape[Mesh.ARRAY_NORMAL] = soften(shape[Mesh.ARRAY_NORMAL],indices)
				var refined := ArrayMesh.new()
				refined.blend_shape_mode = original.blend_shape_mode
				for index: int in range(pose_count): refined.add_blend_shape(original.get_blend_shape_name(index))
				refined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
				var polished: Dictionary = refined.get("_surfaces")[0]
				var count: int = packet.vertex_count
				var format: int = original.surface_get_format(surface)
				var positions: int = count*RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
				assert(packet.vertex_data.size()==polished.vertex_data.size())
				var vertices: PackedByteArray = packet.vertex_data.slice(0,positions)
				vertices.append_array(polished.vertex_data.slice(positions))
				packet.vertex_data = vertices
				var stride: int = packet.blend_shapes.size()/pose_count
				assert(packet.blend_shapes.size()==polished.blend_shapes.size())
				var poses := PackedByteArray()
				for pose: int in range(pose_count):
					poses.append_array(packet.blend_shapes.slice(pose*stride,pose*stride+positions))
					poses.append_array(polished.blend_shapes.slice(pose*stride+positions,(pose+1)*stride))
				packet.blend_shapes = poses
			active.append(packet)
		else:
			var arrays: Array = original.surface_get_arrays(surface)
			for shape: Array in original.surface_get_blend_shape_arrays(surface):
				for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]: assert(shape[attribute]==arrays[attribute])
			removed += packet.blend_shapes.size()
			packet.erase("blend_shapes")
			static_packets.append(packet)
	animated.set("_surfaces",active)
	animated.custom_aabb = original.get_aabb()
	for key: StringName in original.get_meta_list(): animated.set_meta(key,original.get_meta(key))
	var helmet := ArrayMesh.new()
	helmet.set("_surfaces",static_packets)
	helmet.custom_aabb = original.get_aabb()
	assert(removed==82620*pose_count)
	assert(ResourceSaver.save(animated,ROOT+"driver.res",ResourceSaver.FLAG_COMPRESS)==OK)
	assert(ResourceSaver.save(helmet,ROOT+"helmet_static.res",ResourceSaver.FLAG_COMPRESS)==OK)
	print("MODEL_DRIVER_SPLIT removed_morph_bytes=",removed," animated_surfaces=",animated.get_surface_count()," static_surfaces=",helmet.get_surface_count())

static func soften(normals: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	# Normal-only neighbourhood filter. Protect creases over 55 degrees and
	# retain every rest/pose position, index, UV and glove normal exactly.
	var sums := PackedVector3Array()
	sums.resize(normals.size())
	for offset: int in range(0,indices.size(),3):
		for a: int in range(3):
			var vertex: int = indices[offset+a]
			for b: int in range(3):
				var neighbour: int = indices[offset+b]
				if normals[vertex].dot(normals[neighbour])>0.57: sums[vertex] += normals[neighbour]
	var result: PackedVector3Array = normals.duplicate()
	for vertex: int in range(normals.size()):
		if sums[vertex].length_squared()>0.001: result[vertex] = normals[vertex].slerp(sums[vertex].normalized(),0.35).normalized()
	return result
