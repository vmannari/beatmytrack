extends RefCounted
## Disposable local presentation cache. Canonical track compilation stays separate.
const ARTIFACT = preload("res://track/road_mesh_artifact.gd")
const FORMAT: String = "road-artifact-2"
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_RESIDENT_BYTES: int = 96 * 1024 * 1024
const MAX_TOTAL_BYTES: int = 96 * 1024 * 1024
const MAX_FILES: int = 8
const MAX_MESHES: int = 4096 # Night roads are partitioned into light-sized tiles.
const ARRAY_FORMAT: String = "device-road-arrays-1"
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
	if artifact.estimated_bytes <= 0 or artifact.estimated_bytes > MAX_RESIDENT_BYTES or artifact.meshes.is_empty() or artifact.meshes.size() > MAX_MESHES: return {}
	for data: Dictionary in artifact.meshes:
		if not data.has_all(["mesh","material","transform","layers","shadow"]): return {}
		if not data.mesh is ArrayMesh or not data.material is ShaderMaterial or not data.transform is Transform3D: return {}
	return {"key":key.duplicate(true),"meshes":artifact.meshes,"metadata":artifact.road_metadata,"bytes":artifact.estimated_bytes}

static func read_arrays(key: Array, geometry_key: String) -> Dictionary:
	if directory.is_empty(): return {}
	var id: String = identity(key)
	var path: String = directory.path_join(id+".arrays")
	var raw := FileAccess.open(path,FileAccess.READ)
	if raw == null: return {}
	var size: int = raw.get_length(); raw.close()
	if size <= 0 or size > MAX_FILE_BYTES: return {}
	var checksum := FileAccess.open(path+".sha256",FileAccess.READ)
	if checksum == null: return {}
	if checksum.get_length() != 64: checksum.close(); return {}
	var expected: String = checksum.get_as_text(); checksum.close()
	if FileAccess.get_sha256(path) != expected: return {}
	var file := FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > MAX_RESIDENT_BYTES: file.close(); return {}
	# Private local numeric arrays only; deserialization cannot create objects.
	var value: Variant = file.get_var(false)
	var ok: bool = file.get_error() in [OK,ERR_FILE_EOF]; file.close()
	if not ok or not value is Dictionary or value.get("format","") != ARRAY_FORMAT or value.get("id","") != id: return {}
	var packet: Variant = value.get("packet")
	if not packet is Dictionary or packet.get("key","") != geometry_key or not packet.get("parts") is Array or not packet.get("metadata") is Dictionary: return {}
	if packet.parts.is_empty() or packet.parts.size() > MAX_MESHES: return {}
	var estimated: int = 0
	for part: Variant in packet.parts:
		if not part is Dictionary or part.get("role","") not in ["road","winter","kerb"] or not part.get("arrays") is Array: return {}
		var arrays: Array = part.arrays
		if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return {}
		estimated += arrays[Mesh.ARRAY_VERTEX].size()*96
		if arrays[Mesh.ARRAY_INDEX] != null:
			if not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: return {}
			estimated += arrays[Mesh.ARRAY_INDEX].size()*4
		if part.role == "road" and (not part.get("arguments") is Array or part.arguments.size() != 8): return {}
	if estimated <= 0 or estimated > MAX_RESIDENT_BYTES: return {}
	return packet

static func stage_arrays(key: Array, packet: Dictionary, cancelled: Callable) -> Dictionary:
	if directory.is_empty() or packet.get("parts",[]).is_empty(): return {}
	if cancelled.is_valid() and cancelled.call(): return {}
	var estimated: int = 0
	for part: Dictionary in packet.parts:
		var arrays: Array = part.arrays
		estimated += arrays[Mesh.ARRAY_VERTEX].size()*96
		if arrays[Mesh.ARRAY_INDEX] != null: estimated += arrays[Mesh.ARRAY_INDEX].size()*4
		if estimated > MAX_RESIDENT_BYTES: return {}
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return {}
	var id: String = identity(key)
	var path: String = directory.path_join(id+".arrays.pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var file := FileAccess.open_compressed(path,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if file == null: return {}
	file.store_var({"format":ARRAY_FORMAT,"id":id,"packet":packet},false)
	var size: int = file.get_position()
	var ok: bool = file.get_error() == OK; file.close()
	var raw := FileAccess.open(path,FileAccess.READ)
	var compressed_size: int = raw.get_length() if raw != null else 0
	if raw != null: raw.close()
	if not ok or size > MAX_RESIDENT_BYTES or compressed_size <= 0 or compressed_size > MAX_FILE_BYTES or (cancelled.is_valid() and cancelled.call()):
		DirAccess.remove_absolute(path); return {}
	return {"path":path,"id":id,"key":key,"sha256":FileAccess.get_sha256(path)}

static func discard_arrays(receipt: Dictionary) -> void:
	if _owns_pending_arrays(receipt): DirAccess.remove_absolute(receipt.path)

static func publish_arrays(receipt: Dictionary) -> bool:
	if not _owns_pending_arrays(receipt): return false
	if receipt.get("sha256","").length() != 64: discard_arrays(receipt); return false
	var path: String = directory.path_join(str(receipt.id)+".arrays")
	if DirAccess.rename_absolute(receipt.path,path) != OK: discard_arrays(receipt); return false
	var checksum := FileAccess.open(path+".sha256.tmp",FileAccess.WRITE)
	if checksum == null: DirAccess.remove_absolute(path); return false
	checksum.store_string(receipt.sha256); checksum.flush()
	var ok: bool = checksum.get_error() == OK; checksum.close()
	if not ok or DirAccess.rename_absolute(path+".sha256.tmp",path+".sha256") != OK:
		DirAccess.remove_absolute(path); DirAccess.remove_absolute(path+".sha256.tmp"); return false
	prune(path)
	return true

static func _owns_pending_arrays(receipt: Dictionary) -> bool:
	if not receipt.has_all(["path","id","key"]) or directory.is_empty(): return false
	var id: String = str(receipt.id)
	return id == identity(receipt.key) and str(receipt.path).get_base_dir() == directory and str(receipt.path).get_file().begins_with(id+".arrays.pending-")

static func write_entry(entry: Dictionary) -> bool:
	if directory.is_empty() or not entry.has_all(["key","meshes","metadata","bytes"]): return false
	if int(entry.bytes) <= 0 or int(entry.bytes) > MAX_RESIDENT_BYTES or entry.meshes.is_empty() or entry.meshes.size() > MAX_MESHES: return false
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
	# The installed GPU artifact supersedes its CPU staging representation.
	DirAccess.remove_absolute(directory.path_join(id+".arrays"))
	DirAccess.remove_absolute(directory.path_join(id+".arrays.sha256"))
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
	if not ((name.length() == 68 and name.ends_with(".res")) or (name.length() == 71 and name.ends_with(".arrays"))): return false
	for character: String in name.left(64):
		if character not in "0123456789abcdef": return false
	return true
