extends RefCounted
## CPU-only numeric spatial partition. Input arrays remain immutable.
static func run(cancelled: Callable, arrays: Array, indices: PackedInt32Array, vertices: PackedVector3Array, count: int, object_ends: PackedInt32Array, object_centres: PackedVector3Array, tile_size: float, max_chunks: int, lod_packets: Array = []) -> Array[Dictionary]:
	var size: float = tile_size
	var groups: Dictionary = {}
	while true:
		groups.clear()
		for start: int in range(0,count,3):
			if start % 768 == 0 and cancelled.call(): return []
			var a: int = indices[start] if not indices.is_empty() else start
			var b: int = indices[start+1] if not indices.is_empty() else start+1
			var c: int = indices[start+2] if not indices.is_empty() else start+2
			var center: Vector3 = (vertices[a]+vertices[b]+vertices[c])/3.0
			if not object_ends.is_empty():
				var object: int = object_ends.bsearch(start+1)
				assert(object<object_centres.size(),"Static prop assembly ranges must cover every triangle.")
				center = object_centres[object]
			var key := Vector2i(floori(center.x/size),floori(center.z/size))
			if not groups.has(key): groups[key] = PackedInt32Array()
			groups[key].append_array(PackedInt32Array([a,b,c]))
		if groups.size() <= max_chunks: break
		size *= 2.0
	if groups.size() <= 1: return []
	var lod_groups: Dictionary = {}
	for packet: Dictionary in lod_packets:
		var parts: Dictionary = {}
		var data: PackedByteArray = packet.data
		var stride: int = packet.stride
		var ends: PackedInt32Array = packet.object_ends
		for start: int in range(0,data.size()/stride,3):
			if start % 768 == 0 and cancelled.call(): return []
			var triangle := PackedInt32Array()
			for corner: int in range(3): triangle.append(data.decode_u16((start+corner)*stride) if stride == 2 else data.decode_u32((start+corner)*stride))
			var center: Vector3 = (vertices[triangle[0]]+vertices[triangle[1]]+vertices[triangle[2]])/3.0
			if not ends.is_empty(): center = object_centres[ends.bsearch(start+1)]
			var key := Vector2i(floori(center.x/size),floori(center.z/size))
			if not groups.has(key):
				# A collapsed face can move its centroid across a tile edge. Keep it
				# in an existing full-detail chunk; its actual AABB includes every vertex.
				var distance: float = INF
				var target: Vector2i = key
				for candidate: Vector2i in groups:
					var next: float = Vector2(candidate).distance_squared_to(Vector2(target))
					if next < distance: distance = next; key = candidate
			if not parts.has(key): parts[key] = PackedInt32Array()
			parts[key].append_array(triangle)
		lod_groups[float(packet.error)] = parts
	var result: Array[Dictionary] = []
	for key: Vector2i in groups:
		if cancelled.call(): return []
		var chosen: PackedInt32Array = groups[key]
		var map: Dictionary = {}
		var used := PackedInt32Array()
		for corner: int in range(chosen.size()):
			if corner % 512 == 0 and cancelled.call(): return []
			var original: int = chosen[corner]
			if not map.has(original):
				map[original] = used.size()
				used.append(original)
			chosen[corner] = map[original]
		var lods: Dictionary = {}
		for error: float in lod_groups:
			var local: PackedInt32Array = lod_groups[error].get(key,PackedInt32Array())
			# No reduced triangles assigned here means this full-detail chunk is
			# retained. An empty LOD is not a supported renderer representation.
			if local.is_empty(): continue
			for corner: int in range(local.size()):
				if corner % 512 == 0 and cancelled.call(): return []
				var original: int = local[corner]
				if not map.has(original): map[original] = used.size(); used.append(original)
				local[corner] = map[original]
			lods[error] = local
		var part: Array = []
		part.resize(Mesh.ARRAY_MAX)
		for attribute: int in range(Mesh.ARRAY_INDEX):
			if arrays[attribute] == null: continue
			var data: Variant = arrays[attribute].slice(0,0)
			var stride: int = 4 if attribute in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS] else 1
			data.resize(used.size()*stride)
			for index: int in range(used.size()):
				if index % 256 == 0 and cancelled.call(): return []
				for component: int in range(stride):
					data[index*stride+component] = arrays[attribute][used[index]*stride+component]
			part[attribute] = data
		part[Mesh.ARRAY_INDEX] = chosen
		var entry: Dictionary = {"key":key,"size":size,"arrays":part,"used":used}
		if not lods.is_empty(): entry.lods = lods
		result.append(entry)
	return result
