extends RefCounted
## Immutable CPU work shares the road LRU and its existing byte budget.
const VERSION: String = "editor-road-sections-1"
const UPLOAD_VERTICES: int = 12288
static var native_streams: bool = true
var hits: int = 0
var misses: int = 0
var reused: Dictionary = {}
var rebuilt: Dictionary = {}
var _stats_guard := Mutex.new()

static func digest(value: Variant) -> String:
	var hash_value := HashingContext.new()
	hash_value.start(HashingContext.HASH_SHA256)
	hash_value.update(var_to_bytes(value))
	return hash_value.finish().hex_encode()

func read(key: String) -> Variant:
	var value: Variant = load("res://editor/road_preparation.gd").section_read(key)
	var role: String = key.get_slice("/",0)
	_stats_guard.lock()
	if value == null: misses += 1; rebuilt[role] = int(rebuilt.get(role,0))+1
	else: hits += 1; reused[role] = int(reused.get(role,0))+1
	_stats_guard.unlock()
	return value

func write(key: String, value: Variant) -> void:
	load("res://editor/road_preparation.gd").section_write(key,value)

func reject(key: String) -> void:
	var role: String = key.get_slice("/",0)
	_stats_guard.lock()
	hits -= 1; misses += 1; reused[role] -= 1; rebuilt[role] = int(rebuilt.get(role,0))+1
	_stats_guard.unlock()

static func append_arrays(tool: SurfaceTool, arrays: Array) -> void:
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null: return
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").roads() if native_streams else null
	if native != null and native.has_method("editor_append") and native.call("editor_append",tool,arrays): return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	for cursor: int in range(indices.size() if not indices.is_empty() else vertices.size()):
		var i: int = indices[cursor] if not indices.is_empty() else cursor
		if arrays[Mesh.ARRAY_NORMAL] != null: tool.set_normal(arrays[Mesh.ARRAY_NORMAL][i])
		if arrays[Mesh.ARRAY_TEX_UV] != null: tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][i])
		if arrays[Mesh.ARRAY_TEX_UV2] != null: tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][i])
		if arrays[Mesh.ARRAY_COLOR] != null: tool.set_color(arrays[Mesh.ARRAY_COLOR][i])
		tool.add_vertex(vertices[i])

static func split(arrays: Array, tile_size: float = 32.0) -> Array:
	# Whole triangles, original attributes and order. Indexed surfaces retain
	# shared vertices within each upload; no clipping, welding or new normals.
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty(): return []
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").roads() if native_streams else null
	if native != null and native.has_method("editor_split"):
		var prepared: Array = native.call("editor_split",arrays,tile_size)
		if not prepared.is_empty(): return prepared
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var tiles: Dictionary = {}
	for first: int in range(0,count,3):
		var center := Vector3.ZERO
		for cursor: int in range(first,first+3): center += vertices[indices[cursor] if not indices.is_empty() else cursor]
		center /= 3.0
		var tile := Vector2i(floori(center.x/tile_size),floori(center.z/tile_size))
		if not tiles.has(tile): tiles[tile] = PackedInt32Array()
		for cursor: int in range(first,first+3): tiles[tile].append(indices[cursor] if not indices.is_empty() else cursor)
	var result: Array = []
	for tile: Vector2i in tiles:
		result.append_array(_split_indices(arrays,tiles[tile],not indices.is_empty()))
	return result

static func _split_indices(arrays: Array, indices: PackedInt32Array, indexed: bool) -> Array:
	var result: Array = []
	for first: int in range(0,indices.size(),UPLOAD_VERTICES):
		var part: Array = []; part.resize(Mesh.ARRAY_MAX)
		if not indexed:
			# Spatial groups usually contain long contiguous triangle runs. Copy
			# their packed attributes in bulk rather than dispatching per vertex.
			var last: int = mini(first+UPLOAD_VERTICES,indices.size())
			for channel: int in range(Mesh.ARRAY_MAX):
				if channel == Mesh.ARRAY_INDEX or arrays[channel] == null: continue
				var stream: Variant = arrays[channel].slice(0,0)
				var stride: int = arrays[channel].size()/arrays[Mesh.ARRAY_VERTEX].size()
				var cursor: int = first
				while cursor < last:
					var end: int = cursor+1
					while end < last and indices[end] == indices[end-1]+1: end += 1
					stream.append_array(arrays[channel].slice(indices[cursor]*stride,(indices[end-1]+1)*stride))
					cursor = end
				part[channel] = stream
			result.append(part)
			continue
		var remap: Dictionary = {}
		var selected := PackedInt32Array()
		var mapped := PackedInt32Array()
		for cursor: int in range(first,mini(first+UPLOAD_VERTICES,indices.size())):
			var original: int = indices[cursor]
			if not remap.has(original): remap[original] = selected.size(); selected.append(original)
			mapped.append(remap[original])
		for channel: int in range(Mesh.ARRAY_MAX):
			if channel == Mesh.ARRAY_INDEX or arrays[channel] == null: continue
			var stream: Variant = arrays[channel].slice(0,0)
			var stride: int = arrays[channel].size()/arrays[Mesh.ARRAY_VERTEX].size()
			for i: int in selected:
				for component: int in range(stride): stream.append(arrays[channel][i*stride+component])
			part[channel] = stream
		if indexed: part[Mesh.ARRAY_INDEX] = mapped
		result.append(part)
	return result
