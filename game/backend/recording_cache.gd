extends RefCounted
## Disposable, bounded, account-scoped presentation bytes. No race authority.
const MAX_BYTES: int = 8388608
const DISK_BYTES: int = 67108864
const MAX_FILES: int = 64
const MAGIC: String = "bmt-recording-cache-v1"
static var _access: Dictionary = {}
static var _loaded_access: Dictionary = {}
static var _saved_access: Dictionary = {}
static var _access_mutex := Mutex.new()

static func _accessed(directory: String, path: String, touch: bool = false) -> int:
	_access_mutex.lock()
	if not _loaded_access.has(directory):
		var saved: Dictionary = preload("res://backend/atomic_json.gd").read(directory.path_join("access.json"),65536)
		for name: String in saved:
			if name.ends_with(".ghost") and name.length() == 70 and (saved[name] is float or saved[name] is int): _access[directory.path_join(name)] = int(saved[name])
		_loaded_access[directory] = true
	var stamp: int = int(Time.get_unix_time_from_system()*1000.0)
	if touch: _access[path] = stamp
	var value: int = int(_access.get(path,0))
	while _access.size() > MAX_FILES*4: _access.erase(_access.keys()[0])
	while _loaded_access.size() > 16: _loaded_access.erase(_loaded_access.keys()[0])
	while _saved_access.size() > 16: _saved_access.erase(_saved_access.keys()[0])
	if touch and stamp-int(_saved_access.get(directory,0)) >= 60000:
		var entries: Dictionary = {}
		for candidate: String in _access:
			if candidate.get_base_dir() == directory: entries[candidate.get_file()] = _access[candidate]
		preload("res://backend/atomic_json.gd").write(directory.path_join("access.json"),entries,65536)
		_saved_access[directory] = stamp
	_access_mutex.unlock()
	return value

static func valid(recording: Variant) -> Dictionary:
	if not recording is Dictionary or not recording.has_all(["poses","ticks"]) or not recording.poses is Array or recording.poses.size() < 2 or recording.poses.size() > 36007: return {}
	var previous: float = -1.0
	for pose: Variant in recording.poses:
		if not pose is Array or pose.size() != 7: return {}
		for number: Variant in pose:
			if not (number is float or number is int) or not is_finite(float(number)): return {}
		for component: int in range(1,7):
			if absf(float(pose[component])) > 100000.0: return {}
		if float(pose[0]) <= previous: return {}
		previous = float(pose[0])
	if not (recording.ticks is float or recording.ticks is int) or not is_finite(float(recording.ticks)): return {}
	if float(recording.ticks) <= 0 or float(recording.ticks) > PersonalGhostRun.MAX_TICKS or previous != float(recording.ticks) or float(recording.poses[0][0]) != 0.0: return {}
	return recording

static func _path(directory: String, scope: String, identity: String) -> String:
	return directory.path_join((scope+"\n"+identity).sha256_text()+".ghost")

static func _digest(body: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(body)
	return context.finish().hex_encode()

static func read(directory: String, scope: String, identity: String) -> Dictionary:
	if directory.is_empty(): return {}
	var file := FileAccess.open(_path(directory,scope,identity),FileAccess.READ)
	if file == null or file.get_length() < 64 or file.get_length() > MAX_BYTES+64: return {}
	var digest: String = file.get_buffer(64).get_string_from_ascii()
	var body: PackedByteArray = file.get_buffer(file.get_length()-64)
	if body.is_empty() or _digest(body) != digest: return {}
	var decoded: PackedByteArray = body.decompress_dynamic(MAX_BYTES,FileAccess.COMPRESSION_GZIP)
	if decoded.is_empty(): return {}
	var value: Variant = bytes_to_var(decoded)
	if not value is Dictionary or value.get("schema") != MAGIC or value.get("scope") != scope or value.get("identity") != identity: return {}
	var recording: Dictionary = valid(value.get("recording"))
	if not recording.is_empty(): _accessed(directory,_path(directory,scope,identity),true)
	return recording

static func write(directory: String, scope: String, identity: String, recording: Dictionary) -> bool:
	if directory.is_empty() or valid(recording).is_empty(): return false
	var raw: PackedByteArray = var_to_bytes({"schema":MAGIC,"scope":scope,"identity":identity,"recording":recording})
	if raw.size() > MAX_BYTES: return false
	var body: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	if body.is_empty() or body.size() > MAX_BYTES or DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path: String = _path(directory,scope,identity)
	var files: Array[Dictionary] = []
	var total: int = body.size()+64
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".ghost") or name == path.get_file(): continue
		var candidate: String = directory.path_join(name)
		var old := FileAccess.open(candidate,FileAccess.READ)
		if old == null: continue
		files.append({"path":candidate,"bytes":old.get_length(),"at":maxi(_accessed(directory,candidate),int(FileAccess.get_modified_time(candidate))*1000)})
		total += old.get_length()
		old.close()
		if files.size() > MAX_FILES*2: return false
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.path < b.path if a.at == b.at else a.at < b.at)
	while not files.is_empty() and (files.size() >= MAX_FILES or total > DISK_BYTES):
		var oldest: Dictionary = files.pop_front()
		if DirAccess.remove_absolute(oldest.path) != OK: return false
		total -= int(oldest.bytes)
	var temporary: String = path+"."+str(Time.get_ticks_usec())+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(_digest(body).to_ascii_buffer())
	file.store_buffer(body)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if ok and DirAccess.rename_absolute(temporary,path) == OK:
		_accessed(directory,path,true)
		return true
	DirAccess.remove_absolute(temporary)
	return false
