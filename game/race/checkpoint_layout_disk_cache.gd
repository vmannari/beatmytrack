extends RefCounted
## Disposable worker-only numeric artifacts. Never consulted by a driving tick.
const ARTIFACT = preload("res://race/checkpoint_layout_artifact.gd")
const BUILD = preload("res://core/build_identity.gd")
const MAGIC: String = "BMTGATE1"
const HEADER_BYTES: int = 104
const MAX_FILES: int = 16
const MAX_TOTAL_BYTES: int = 8 * 1024 * 1024
static var directory: String = "user://cache/checkpoint_layouts_v1"
static var _guard := Mutex.new()

static func identity(key: String, versions: Array) -> String:
	if not _digest_name(key): return ""
	var build_script: GDScript = BUILD
	var source: String = build_script.get_script_constant_map().get("CHECKPOINT_LAYOUT_SHA256","")
	# Old/nonstandard builds without the preparation manifest keep construction.
	if not _digest_name(source): return ""
	return _digest(var_to_bytes([MAGIC,key,versions,source,TrackCompiler.VERSION,
		Engine.get_version_info().string,Engine.get_version_info().hash,OS.get_name(),Engine.get_architecture_name(),
		OS.has_feature("double"),var_to_bytes(Vector2.ONE).size()])).hex_encode()

static func read_entry(key: String, track: NativeTrack, versions: Array) -> Dictionary:
	if directory.is_empty(): return {}
	var id: String = identity(key,versions)
	if id.is_empty(): return {}
	var file := FileAccess.open(directory.path_join(id+".gates"),FileAccess.READ)
	if file == null: return {}
	var size: int = file.get_length()
	if size <= HEADER_BYTES or size > HEADER_BYTES+ARTIFACT.MAX_BYTES: file.close(); return {}
	var bytes: PackedByteArray = file.get_buffer(size)
	var ok: bool = file.get_error() in [OK,ERR_FILE_EOF]; file.close()
	if not ok or bytes.size() != size or bytes.slice(0,8).get_string_from_ascii() != MAGIC or bytes.slice(8,72).get_string_from_ascii() != id: return {}
	var payload: PackedByteArray = bytes.slice(HEADER_BYTES)
	if _digest(payload) != bytes.slice(72,HEADER_BYTES): return {}
	return ARTIFACT.new().decode(payload,track,versions)

static func write_entry(key: String, layout: Dictionary, track: NativeTrack, versions: Array, cancelled: Callable) -> bool:
	if directory.is_empty() or _cancelled(cancelled): return false
	var id: String = identity(key,versions)
	if id.is_empty(): return false
	var payload: PackedByteArray = ARTIFACT.encode(layout,track,versions)
	if payload.is_empty() or _cancelled(cancelled): return false
	_guard.lock()
	var result: bool = _write(id,payload,cancelled)
	_guard.unlock()
	return result

static func _write(id: String, payload: PackedByteArray, cancelled: Callable) -> bool:
	if _cancelled(cancelled) or DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path: String = directory.path_join(id+".gates")
	var temporary: String = path+".pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(MAGIC.to_ascii_buffer()); file.store_buffer(id.to_ascii_buffer())
	file.store_buffer(_digest(payload)); file.store_buffer(payload)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if not ok or _cancelled(cancelled) or DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary); return false
	# Atomic rename publishes the header and payload together, never a sidecar.
	_prune(path)
	return true

static func _prune(newest: String) -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	var entries: Array[Dictionary] = []
	var total: int = 0
	for name: String in folder.get_files():
		if not _owned_filename(name): continue
		var path: String = directory.path_join(name)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: continue
		var size: int = file.get_length(); file.close()
		entries.append({"path":path,"bytes":size,"modified":FileAccess.get_modified_time(path)})
		total += size
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.path == newest: return false
		if b.path == newest: return true
		return a.path < b.path if a.modified == b.modified else a.modified < b.modified)
	while not entries.is_empty() and (entries.size() > MAX_FILES or total > MAX_TOTAL_BYTES):
		var oldest: Dictionary = entries.pop_front()
		if DirAccess.remove_absolute(oldest.path) == OK: total -= int(oldest.bytes)

static func _owned_filename(name: String) -> bool:
	if not _digest_name(name.left(64)): return false
	var suffix: String = name.substr(64)
	if suffix == ".gates": return true
	if not suffix.begins_with(".gates.pending-"): return false
	var parts: PackedStringArray = suffix.trim_prefix(".gates.pending-").split("-")
	return parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int()

static func _digest_name(value: String) -> bool:
	if value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	return digest.finish()

static func _cancelled(cancelled: Callable) -> bool: return cancelled.is_valid() and cancelled.call()
