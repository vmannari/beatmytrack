extends RefCounted
## Disposable local presentation cache. Canonical track compilation stays separate.
const ARTIFACT = preload("res://track/road_mesh_artifact.gd")
const FORMAT: String = "road-artifact-1"
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_TOTAL_BYTES: int = 96 * 1024 * 1024
const MAX_FILES: int = 8
const MAX_MESHES: int = 4096 # Night roads are partitioned into light-sized tiles.
static var directory: String = "user://cache/road_meshes_v1"

static func identity(key: Array) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes([FORMAT,Engine.get_version_info().string,key]))
	return digest.finish().hex_encode()

static func read_entry(key: Array) -> Dictionary:
	if directory.is_empty(): return {}
	var id: String = identity(key)
	var path: String = directory.path_join(id+".res")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var size: int = file.get_length()
	file.close()
	if size <= 0 or size > MAX_FILE_BYTES: return {}
	var digest_path: String = path+".sha256"
	file = FileAccess.open(digest_path,FileAccess.READ)
	if file == null: return {}
	if file.get_length() > 128:
		file.close()
		return {}
	var expected: String = file.get_as_text().strip_edges()
	file.close()
	if expected.length() != 64 or FileAccess.get_sha256(path) != expected: return {}
	# Only our private, locally written artifacts enter this path. Downloaded
	# creator documents never provide filenames or serialized engine resources.
	var artifact: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	if artifact == null or artifact.get_script() != ARTIFACT or artifact.cache_id != id: return {}
	if artifact.estimated_bytes <= 0 or artifact.estimated_bytes > MAX_FILE_BYTES or artifact.meshes.is_empty() or artifact.meshes.size() > MAX_MESHES: return {}
	for data: Dictionary in artifact.meshes:
		if not data.has_all(["mesh","material","transform","layers","shadow"]): return {}
		if not data.mesh is ArrayMesh or not data.material is ShaderMaterial or not data.transform is Transform3D: return {}
	return {"key":key.duplicate(true),"meshes":artifact.meshes,"metadata":artifact.road_metadata,"bytes":artifact.estimated_bytes}

static func write_entry(entry: Dictionary) -> bool:
	if directory.is_empty() or not entry.has_all(["key","meshes","metadata","bytes"]): return false
	if int(entry.bytes) <= 0 or int(entry.bytes) > MAX_FILE_BYTES: return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var id: String = identity(entry.key)
	var path: String = directory.path_join(id+".res")
	var temporary: String = directory.path_join(id+".pending.res")
	var artifact := ARTIFACT.new()
	artifact.cache_id = id
	artifact.meshes = entry.meshes
	artifact.road_metadata = entry.metadata
	artifact.estimated_bytes = int(entry.bytes)
	if ResourceSaver.save(artifact,temporary,ResourceSaver.FLAG_COMPRESS) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	var file := FileAccess.open(temporary,FileAccess.READ)
	if file == null:
		DirAccess.remove_absolute(temporary)
		return false
	var size: int = file.get_length()
	file.close()
	if size > MAX_FILE_BYTES:
		DirAccess.remove_absolute(temporary)
		return false
	var checksum: String = FileAccess.get_sha256(temporary)
	if checksum.length() != 64 or DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	file = FileAccess.open(path+".sha256.tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(checksum)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path+".sha256.tmp",path+".sha256") != OK:
		DirAccess.remove_absolute(path+".sha256.tmp")
		return false
	prune(path)
	return true

static func prune(newest_path: String = "") -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	var entries: Array[Dictionary] = []
	var total: int = 0
	for name: String in folder.get_files():
		if not _artifact_filename(name): continue
		var path: String = directory.path_join(name)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: continue
		var size: int = file.get_length()
		file.close()
		entries.append({"path":path,"bytes":size,"modified":FileAccess.get_modified_time(path)})
		total += size
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.path == newest_path: return false
		if b.path == newest_path: return true
		return str(a.path) < str(b.path) if a.modified == b.modified else a.modified < b.modified)
	while not entries.is_empty() and (entries.size() > MAX_FILES or total > MAX_TOTAL_BYTES):
		var oldest: Dictionary = entries.pop_front()
		total -= int(oldest.bytes)
		DirAccess.remove_absolute(oldest.path)
		DirAccess.remove_absolute(str(oldest.path)+".sha256")

static func _artifact_filename(name: String) -> bool:
	if name.length() != 68 or not name.ends_with(".res"): return false
	for character: String in name.left(64):
		if character not in "0123456789abcdef": return false
	return true
