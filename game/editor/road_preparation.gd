extends RefCounted
## CPU arrays only. GPU materials, textures and scene nodes publish on main.
const BUDGET: int = 32 * 1024 * 1024
static var entries: Array = []
static var bytes: int = 0
static var gpu_bytes: int = 0
static var gpu_keys: Dictionary = {}
static var guard := Mutex.new()

static func key_for(track: NativeTrack) -> String:
	var doc: Dictionary = track.metadata.get("creator_document",{})
	var road_cells := PackedByteArray()
	if doc.get("theme",track.metadata.get("theme","pine")) == "desert":
		road_cells.resize(track.cells.size())
		for index: int in range(road_cells.size()): road_cells[index] = 1 if track.cells[index] == 0 else 0
	var geometry: Array = [NativeTrackVisual.VERSION,TrackTheme.normalized(str(track.metadata.get("theme","pine"))),doc.get("pieces",[]),doc.get("surface","asphalt"),doc.get("base_track",""),track.half_extent,track.cell_size,road_cells,track.kerbs.triangles]
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes(geometry))
	return digest.finish().hex_encode()

static func prepare(track: NativeTrack, force: bool = false, cached_only: bool = false) -> Dictionary:
	if track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): return {}
	var key: String = key_for(track)
	guard.lock()
	for entry: Dictionary in entries:
		if entry.key == key:
			guard.unlock(); return entry.packet
	var uploaded: bool = gpu_keys.has(key)
	guard.unlock()
	if cached_only or (uploaded and not force): return {"key":key,"parts":[],"metadata":{}}
	var builder := NativeTrackVisual.new()
	builder.name = "RoadCPUBuilder"
	builder.theme_id = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	builder.colors = TrackTheme.palette(builder.theme_id)
	builder.cache_road_meshes = false; builder.persist_road_meshes = false
	builder._capture_road_arrays = true
	builder._build_creator_roads(track)
	var metadata: Dictionary = {}
	for name: String in ["winter_smooth_sections","winter_deposits","desert_clod_count","desert_bank_sections"]:
		if builder.has_meta(name): metadata[name] = builder.get_meta(name)
	var packet: Dictionary = {"key":key,"parts":builder._prepared_road_parts,"metadata":metadata}
	var size: int = 0
	for part: Dictionary in packet.parts:
		var arrays: Array = part.arrays
		size += arrays[Mesh.ARRAY_VERTEX].size()*96
		if arrays[Mesh.ARRAY_INDEX] != null: size += arrays[Mesh.ARRAY_INDEX].size()*4
	builder.free()
	guard.lock()
	if size <= BUDGET-gpu_bytes:
		while not entries.is_empty() and (entries.size() >= 8 or bytes+size+gpu_bytes > BUDGET): bytes -= int(entries.pop_front().bytes)
		entries.append({"key":key,"packet":packet,"bytes":size}); bytes += size
	guard.unlock()
	return packet

static func account_gpu(cache: Array) -> void:
	guard.lock()
	gpu_bytes = 0; gpu_keys.clear()
	for entry: Dictionary in cache:
		gpu_bytes += int(entry.bytes)
		if not str(entry.get("geometry_key","")).is_empty(): gpu_keys[entry.geometry_key] = true
	while not entries.is_empty() and bytes+gpu_bytes > BUDGET: bytes -= int(entries.pop_front().bytes)
	guard.unlock()

static func unpack_intermediate(arrays: Array, decode_normals: bool) -> Array:
	# Match this pinned engine's intermediate ArrayMesh encode/decode, without
	# creating a rendering resource. See the exact engine-source fixture checks.
	var result: Array = arrays.duplicate()
	if decode_normals and arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
		for index: int in range(normals.size()):
			var packed: Vector2 = normals[index].octahedron_encode()*65535.0
			var oct := Vector2(float(clampi(int(packed.x),0,65535))/65535.0,float(clampi(int(packed.y),0,65535))/65535.0)
			normals[index] = Vector3.octahedron_decode(oct)
		result[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_COLOR] != null:
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
		for index: int in range(colors.size()):
			var c: Color = colors[index]
			colors[index] = Color(float(clampi(int(c.r*255.0),0,255))/255.0,float(clampi(int(c.g*255.0),0,255))/255.0,float(clampi(int(c.b*255.0),0,255))/255.0,float(clampi(int(c.a*255.0),0,255))/255.0)
		result[Mesh.ARRAY_COLOR] = colors
	return result
