extends RefCounted
## CPU-only numeric spatial partition. Input arrays remain immutable.
static func run(cancelled: Callable, arrays: Array, indices: PackedInt32Array, vertices: PackedVector3Array, count: int, object_ends: PackedInt32Array, object_centres: PackedVector3Array, tile_size: float, max_chunks: int) -> Array[Dictionary]:
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
		result.append({"key":key,"size":size,"arrays":part,"used":used})
	return result
