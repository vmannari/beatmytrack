extends RefCounted
## Bounded process-local numeric layouts. No track owners, disk or rendering.
const MAX_ENTRIES: int = 4
const MAX_BYTES: int = 2 * 1024 * 1024
const MAX_INPUT_BYTES: int = 16 * 1024 * 1024
static var _entries: Dictionary = {}
static var _bytes: int = 0
static var _generation: int = 0
static var _guard := Mutex.new()

static func key_for(track: NativeTrack, versions: Array) -> String:
	# A declared content hash alone is insufficient for editor/fixture mutations.
	# Include actual inputs used by TrackSession and its native geometry helpers.
	# Unknown subclasses may override queries, so they keep the uncached path.
	if track.get_script().resource_path != "res://track/native_track.gd" or track.kerbs.get_script().resource_path != "res://track/road_kerbs.gd": return ""
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var size: int = 0
	for value: Variant in [versions,track.content_hash,track.metadata,
		track.cell_size,track.grid_width,track.grid_height,track.half_extent,track.cells,track.deck_cells,
		track.route,track.route_widths,track.route_cumulative,track.route_length,track.route_radii,track.route_cut_radii,
		track.bridge_axis,track.bridge_height,track.creator_bridges,track.finish_center,track.finish_forward,track.finish_half_width,
		track.kerbs.triangles,track.kerbs.buckets,track.kerbs.blocked,track.kerbs.extent,track.kerbs.cell_size,track.kerbs.grid,track.kerbs.maximum_height]:
		var encoded: PackedByteArray = var_to_bytes(value)
		size += encoded.size()
		if size > MAX_INPUT_BYTES: return ""
		digest.update(encoded)
	return digest.finish().hex_encode()

static func read(key: String) -> Dictionary:
	_guard.lock()
	var entry: Dictionary = _entries.get(key,{})
	if not entry.is_empty():
		_entries.erase(key); _entries[key] = entry
	# Deep copies isolate nested notice dictionaries from every track/session.
	var result := {"generation":_generation,"layout":entry.layout.duplicate(true) if not entry.is_empty() else {}}
	_guard.unlock()
	return result

static func store(key: String, layout: Dictionary, generation: int) -> void:
	if key.is_empty(): return
	# Include container/hash-table headroom beyond serialized numeric payloads.
	var cost: int = var_to_bytes(layout).size()*4+key.length()*4+512
	if cost > MAX_BYTES: return
	var owned: Dictionary = layout.duplicate(true)
	_guard.lock()
	if generation != _generation:
		_guard.unlock(); return
	if _entries.has(key):
		_bytes -= int(_entries[key].bytes); _entries.erase(key)
	while not _entries.is_empty() and (_entries.size() >= MAX_ENTRIES or _bytes+cost > MAX_BYTES): _evict()
	_entries[key] = {"layout":owned,"bytes":cost}
	_bytes += cost
	_guard.unlock()

static func _evict() -> void:
	var oldest: String = _entries.keys()[0]
	_bytes -= int(_entries[oldest].bytes)
	_entries.erase(oldest)

static func trim_to(allowance: int = 0) -> void:
	_guard.lock()
	_generation += 1 # A worker already baking cannot repopulate after pressure.
	while not _entries.is_empty() and _bytes > maxi(0,allowance): _evict()
	_guard.unlock()

static func bytes_used() -> int:
	_guard.lock()
	var result: int = _bytes
	_guard.unlock()
	return result

static func count() -> int:
	_guard.lock()
	var result: int = _entries.size()
	_guard.unlock()
	return result
