extends RefCounted
## CPU arrays only. GPU materials, textures and scene nodes publish on main.
const BUDGET: int = 32 * 1024 * 1024
static var entries: Array = []
static var bytes: int = 0
static var gpu_bytes: int = 0
static var gpu_keys: Dictionary = {}
static var guard := Mutex.new()
static var section_entries: Dictionary = {}
static var section_bytes: int = 0
static var section_counts: Dictionary = {}
const SECTION_LIMITS: Dictionary = {"clip":512,"polygon":512,"piece":256,"normalize":256,"relief":256}

static func section_read(key: String) -> Variant:
	guard.lock()
	var entry: Dictionary = section_entries.get(key,{})
	if not entry.is_empty():
		section_entries.erase(key); section_entries[key] = entry
	guard.unlock()
	return entry.get("value")

static func section_write(key: String, value: Variant) -> void:
	var size: int = var_to_bytes(value).size()+key.length()*2+256
	guard.lock()
	if section_entries.has(key): _erase_section(key)
	# Keep room for final arrays as well as immutable intermediate sections.
	if size <= BUDGET/2:
		var role: String = key.get_slice("/",0)
		while int(section_counts.get(role,0)) >= int(SECTION_LIMITS.get(role,256)):
			for victim: String in section_entries:
				if victim.begins_with(role+"/"): _erase_section(victim); break
		while not section_entries.is_empty() and section_bytes+size > BUDGET/2: _evict_section()
		section_entries[key] = {"value":value,"bytes":size}; section_bytes += size
		section_counts[role] = int(section_counts.get(role,0))+1
	_trim_sections()
	guard.unlock()

static func _erase_section(key: String) -> void:
	section_bytes -= int(section_entries[key].bytes); section_entries.erase(key)
	var role: String = key.get_slice("/",0)
	section_counts[role] = int(section_counts.get(role,1))-1

static func _evict_section() -> void:
	# Thousands of tiny clipping fragments must not evict reusable road pieces
	# and finished tile streams on the scalar fallback path.
	for role: String in ["clip","polygon","normalize","relief","piece"]:
		if int(section_counts.get(role,0)) == 0: continue
		for key: String in section_entries:
			if key.begins_with(role+"/"): _erase_section(key); return
	if not section_entries.is_empty(): _erase_section(section_entries.keys()[0])

static func _trim_sections() -> void:
	while not section_entries.is_empty() and bytes+gpu_bytes+section_bytes > BUDGET:
		_evict_section()

static func key_for(track: NativeTrack) -> String:
	var doc: Dictionary = track.metadata.get("creator_document",{})
	var road_cells := PackedByteArray()
	if doc.get("theme",track.metadata.get("theme","pine")) == "desert":
		road_cells.resize(track.cells.size())
		for index: int in range(road_cells.size()): road_cells[index] = 1 if track.cells[index] == 0 else 0
	var geometry: Array = [load("res://editor/road_sections.gd").VERSION,NativeTrackVisual.VERSION,TrackTheme.normalized(str(track.metadata.get("theme","pine"))),doc.get("pieces",[]),doc.get("surface","asphalt"),doc.get("base_track",""),track.half_extent,track.cell_size,road_cells,track.kerbs.triangles]
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes(geometry))
	return digest.finish().hex_encode()

static func prepare(track: NativeTrack, force: bool = false, cached_only: bool = false, cancelled: Callable = Callable()) -> Dictionary:
	if track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): return {}
	var key: String = key_for(track)
	guard.lock()
	for entry: Dictionary in entries:
		if entry.key == key:
			guard.unlock(); return entry.packet
	var uploaded: bool = gpu_keys.has(key)
	guard.unlock()
	if cached_only or (uploaded and not force): return {"key":key,"parts":[],"metadata":{}}
	var stored: Dictionary = NativeTrackVisual.ROAD_DISK_CACHE.read_arrays(disk_key_for(track),key)
	if not stored.is_empty(): return stored
	var builder := NativeTrackVisual.new()
	builder.name = "RoadCPUBuilder"
	builder.theme_id = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	builder.colors = TrackTheme.palette(builder.theme_id)
	builder.cache_road_meshes = false; builder.persist_road_meshes = false
	builder._capture_road_arrays = true
	builder.road_sections = load("res://editor/road_sections.gd").new()
	if cancelled.is_valid(): builder.build_current = func() -> bool: return not cancelled.call()
	builder._build_creator_roads(track)
	if cancelled.is_valid() and cancelled.call(): builder.free(); return {}
	# Produce the final Desert road on the CPU. Match the old intermediate
	# ArrayMesh encoding before deformation, then upload only the finished mesh.
	if builder.theme_id == "desert":
		var relief = preload("res://track/desert_road_relief.gd").new(track)
		for part: Dictionary in builder._prepared_road_parts:
			if part.role != "road": continue
			if cancelled.is_valid() and cancelled.call(): builder.free(); return {}
			var relief_key: String = "relief/"+load("res://editor/road_sections.gd").digest([part.arrays,local_field(relief,part.arrays)])
			var reused: Variant = builder.road_sections.read(relief_key)
			if reused is Array:
				part.arrays = reused; part.relief_version = relief.VERSION; continue
			var streams: Array = [unpack_intermediate(part.arrays,true)]
			var final_arrays: Array = relief.prepare_arrays(cancelled,streams,Transform3D.IDENTITY,true)
			if final_arrays.is_empty(): builder.free(); return {}
			part.arrays = final_arrays[0]
			part.relief_version = relief.VERSION
			builder.road_sections.write(relief_key,part.arrays)
	if cancelled.is_valid() and cancelled.call(): builder.free(); return {}
	var metadata: Dictionary = {}
	for name: String in ["winter_smooth_sections","winter_deposits","desert_clod_count","desert_bank_sections"]:
		if builder.has_meta(name): metadata[name] = builder.get_meta(name)
	var parts: Array = []
	for part: Dictionary in builder._prepared_road_parts:
		for arrays: Array in load("res://editor/road_sections.gd").split(part.arrays,16.0 if builder.theme_id == "night_city" else 32.0):
			var section: Dictionary = part.duplicate()
			section.arrays = arrays
			section.mesh_key = load("res://editor/road_sections.gd").digest([part.role,arrays,part.get("relief_version","")])
			parts.append(section)
	var packet: Dictionary = {"key":key,"parts":parts,"metadata":metadata,"section_hits":builder.road_sections.hits,"section_misses":builder.road_sections.misses,"reused":builder.road_sections.reused.duplicate(),"rebuilt":builder.road_sections.rebuilt.duplicate()}
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
	_trim_sections()
	guard.unlock()
	return packet

static func local_field(relief: RefCounted, arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bounds := Rect2(Vector2(vertices[0].x,-vertices[0].z),Vector2.ZERO)
	for vertex: Vector3 in vertices: bounds = bounds.expand(Vector2(vertex.x,-vertex.z))
	# Bilinear field samples and normal derivatives reach outside each triangle.
	var area: Rect2 = bounds.grow(relief.track.cell_size*2.0)
	var track: NativeTrack = relief.track
	var first := Vector2i(floori((area.position.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-area.end.y)/track.cell_size))
	var last := Vector2i(ceili((area.end.x+track.half_extent.x)/track.cell_size),ceili((track.half_extent.y-area.position.y)/track.cell_size))
	var values := PackedFloat32Array()
	for y: int in range(maxi(0,first.y),mini(track.grid_height,last.y+1)):
		for x: int in range(maxi(0,first.x),mini(track.grid_width,last.x+1)):
			if not relief.field.is_empty(): values.append(relief.field[y*track.grid_width+x])
	return [relief.VERSION,track.half_extent,track.cell_size,first,last,relief.bounds.intersection(area),values]

static func account_gpu(cache: Array) -> void:
	guard.lock()
	gpu_bytes = 0; gpu_keys.clear()
	for entry: Dictionary in cache:
		gpu_bytes += int(entry.bytes)
		if not str(entry.get("geometry_key","")).is_empty(): gpu_keys[entry.geometry_key] = true
	while not entries.is_empty() and bytes+gpu_bytes > BUDGET: bytes -= int(entries.pop_front().bytes)
	_trim_sections()
	guard.unlock()

static func unpack_intermediate(arrays: Array, decode_normals: bool) -> Array:
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").roads()
	if native != null:
		var unpacked: Array = native.call("road_unpack",arrays,decode_normals)
		if not unpacked.is_empty(): return unpacked
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

static func run(cancelled: Callable, track: NativeTrack) -> Dictionary:
	return with_winter_cover(prepare(track,true,false,cancelled),track,cancelled)

static func with_winter_cover(packet: Dictionary, track: NativeTrack, cancelled: Callable) -> Dictionary:
	if track.metadata.get("theme","pine") != "winter" or (cancelled.is_valid() and cancelled.call()): return packet
	# Cover depends on the complete track, including solid objects and paint.
	# Keep it out of the reusable road-only geometry LRU.
	var result: Dictionary = packet.duplicate()
	result.winter_cover = track.editor_winter_cover if not track.editor_winter_cover.is_empty() else WinterScenery.cover_data(track,cancelled)
	result.winter_cover_key = track.content_hash
	return result

static func disk_key_for(track: NativeTrack) -> Array:
	var theme: String = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	return [track.content_hash,NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),true]
