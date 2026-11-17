extends RefCounted
## Final scenery, underneath the existing bounded RAM cache. Rendering resources
## are saved/loaded only on the main thread, before the race can advance.
const ARTIFACT = preload("res://track/prepared_world_artifact.gd")
const FORMAT: String = "prepared-world-1"
const MAX_FILES: int = 5
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_TOTAL_BYTES: int = 128 * 1024 * 1024
const MAX_RESIDENT_BYTES: int = 64 * 1024 * 1024
const MAX_NODES: int = 16384
static var directory: String = "user://cache/prepared_worlds_v1"
static var hits: int = 0
static var writes: int = 0
static var source_key: String = ""
static var rejected: Dictionary = {}
static var write_costs: Dictionary = {}
static var allow_headless: bool = false
static var allow_unqualified_renderer: bool = false # Evidence-only comparison.
static var allow_unqualified_theme: bool = false # Evidence-only comparison.
static var pending_writes: Array[Dictionary] = []
static var _tree: SceneTree
const MAX_PENDING: int = 2

static func _enabled() -> bool:
	# Native Vulkan controls found small serialized-material pixel differences.
	# Keep its original construction/RAM path until those differences qualify.
	return not directory.is_empty() and (DisplayServer.get_name() != "headless" or allow_headless) and (RenderingServer.get_current_rendering_method() == "gl_compatibility" or allow_unqualified_renderer)

static func identity_cooperative(key: Array, options: Array, visual: Node3D) -> String:
	if not _enabled() or not _qualified_key(key): return ""
	if source_key.is_empty():
		var build_hash: String = _build_hash()
		if not _hex(build_hash): return ""
		var job = load("res://editor/work_job.gd").start(_source_job.bind(build_hash),visual.get_tree())
		var tree: SceneTree = visual.get_tree()
		while not job.done:
			await tree.process_frame
			if not is_instance_valid(visual) or not visual._build_is_current(): job.cancel(); return ""
		if job.result is String: source_key = job.result
	return identity(key,options)

static func _source_job(cancelled: Callable, build_hash: String) -> String:
	if cancelled.call() or not _hex(build_hash): return ""
	var result: String = source_identity(build_hash)
	return "" if cancelled.call() else result

static func _build_hash() -> String:
	return str(load("res://core/build_identity.gd").get_script_constant_map().get("SOURCE_SHA256",""))

static func identity(key: Array, options: Array) -> String:
	if not _enabled() or not _qualified_key(key): return ""
	if source_key.is_empty(): source_key = source_identity()
	if source_key.is_empty(): return ""
	return _digest(var_to_bytes([FORMAT,source_key,key,options,Engine.get_version_info().string,Engine.get_version_info().hash,OS.get_name(),Engine.get_architecture_name(),OS.has_feature("double"),RenderingServer.get_current_rendering_method(),DisplayServer.get_name()]))

static func _qualified_key(key: Array) -> bool:
	# Night's deliberate corruption/repair cross-process fixture found a
	# structural mismatch. Keep its existing RAM path until it also qualifies.
	return key.size() > 4 and (str(key[4]) != "night_city" or allow_unqualified_theme)

static func source_identity(build_hash: String = "") -> String:
	if build_hash.is_empty(): build_hash = _build_hash()
	if not _hex(build_hash): return ""
	# Exported scripts are compiled/remapped. Their complete packaged identity is
	# authoritative. Source runs additionally fence real files: generated build
	# identity can otherwise lag edits to a generator, shader or imported texture.
	if not FileAccess.file_exists("res://track/native_track_visual.gd"): return build_hash
	var paths: Array[String] = ["res://project.godot"]
	_collect("res://",paths,false)
	_collect("res://assets/textures",paths,true)
	_collect("res://assets/scenery_lods_v1",paths,true)
	paths.sort()
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	digest.update(build_hash.to_utf8_buffer())
	for path: String in paths:
		var value: String = FileAccess.get_sha256(path)
		if not _hex(value): return ""
		digest.update((path+":"+value+"\n").to_utf8_buffer())
	return digest.finish().hex_encode()

static func _collect(path: String, paths: Array[String], all_files: bool) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name: String in folder.get_files():
		if all_files or name.get_extension() in ["gd","gdshader","gdshaderinc","gdextension","dll","so"]: paths.append(path.path_join(name))
	for name: String in folder.get_directories():
		if name.begins_with(".") or name in ["tests","android","assets","build","tmp","docs"] or name.begins_with("recordings-"): continue
		_collect(path.path_join(name),paths,all_files)

static func read_entry(id: String) -> Dictionary:
	if not _hex(id): return {}
	var lock: String = _acquire_lock()
	if lock.is_empty(): return {}
	var entry: Dictionary = _read_entry(id)
	if entry.is_empty() and not _manifest(id).is_empty():
		if rejected.size() >= 64: rejected.erase(rejected.keys()[0])
		rejected[id] = true
	elif not entry.is_empty(): rejected.erase(id)
	_release_lock(lock)
	return entry

static func _read_entry(id: String) -> Dictionary:
	var manifest: Dictionary = _manifest(id)
	if manifest.is_empty(): return {}
	var path: String = directory.path_join(manifest.file)
	if not _payload_valid(manifest): return {}
	# A downloaded document cannot name this file. Authenticate the complete
	# locally written bytes before asking ResourceLoader to decode any objects.
	var artifact: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	if artifact == null or artifact.get_script() != ARTIFACT or artifact.cache_id != id: return {}
	if artifact.scene == null or artifact.estimated_bytes <= 0 or artifact.estimated_bytes > MAX_RESIDENT_BYTES: return {}
	if not _valid_scene(artifact): return {}
	hits += 1
	return {"scene":artifact.scene,"metadata":artifact.world_metadata,"props":Array(artifact.prop_indices),"tyres":artifact.tyre_index,"scenic_count":artifact.scenic_count,"bytes":artifact.estimated_bytes}

static func _valid_scene(artifact: Resource) -> bool:
	var state: SceneState = artifact.scene.get_state()
	if state.get_node_count() < 2 or state.get_node_count() > MAX_NODES: return false
	var children: Array[StringName] = []
	for index: int in range(state.get_node_count()):
		if state.get_node_type(index) not in [&"Node3D",&"MeshInstance3D",&"MultiMeshInstance3D",&"OmniLight3D"]: return false
		if state.get_node_instance(index) != null: return false
		if index > 0 and state.get_node_path(index,true) == NodePath("."): children.append(state.get_node_type(index))
		for property: int in range(state.get_node_property_count(index)):
			if state.get_node_property_name(index,property) != &"script": continue
			var script: Variant = state.get_node_property_value(index,property)
			if script != null and (not script is GDScript or script.resource_path not in ["res://track/night_prop_effects.gd","res://track/night_light_budget.gd","res://track/static_mesh_draw_view.gd","res://track/tyre_batches.gd"]): return false
	if artifact.tyre_index < -1 or artifact.tyre_index >= children.size() or artifact.scenic_count < 0: return false
	if artifact.tyre_index >= 0 and children[artifact.tyre_index] != &"MultiMeshInstance3D": return false
	for index: int in artifact.prop_indices:
		if index < 0 or index >= children.size(): return false
	return true

static func write_entry(id: String, entry: Dictionary, current: Callable) -> bool:
	var receipt: Dictionary = _serialize(id,entry,current)
	if receipt.is_empty(): return false
	var cancelled: Callable = func() -> bool: return not current.call()
	var verified: Dictionary = _verify_write(cancelled,receipt)
	if verified.is_empty(): return false
	return _publish(verified,current)

static func queue_entry(id: String, entry: Dictionary, visual: Node3D, epoch: int) -> bool:
	_reap_writes()
	if pending_writes.size() >= MAX_PENDING or pending_writes.any(func(value: Dictionary) -> bool: return value.receipt.id == id): return false
	var current: Callable = func() -> bool: return is_instance_valid(visual) and visual._build_is_current() and load("res://track/prepared_world_cache.gd").generation == epoch
	var receipt: Dictionary = _serialize(id,entry,current)
	if receipt.is_empty(): return false
	var tree: SceneTree = visual.get_tree()
	var job = load("res://editor/work_job.gd").start(_verify_write.bind(receipt),tree)
	pending_writes.append({"receipt":receipt,"job":job,"visual":weakref(visual),"epoch":epoch,"key":entry.key.duplicate(true),"scene_id":entry.scene.get_instance_id()})
	if _tree == null:
		_tree = tree
		tree.process_frame.connect(_reap_writes)
		tree.root.tree_exiting.connect(_finish_writes)
	return true

static func _reap_writes() -> void:
	for index: int in range(pending_writes.size()-1,-1,-1):
		var pending: Dictionary = pending_writes[index]
		var visual: Node3D = pending.visual.get_ref()
		var worlds = load("res://track/prepared_world_cache.gd")
		var current: bool = _owner_current(visual) and pending.epoch == worlds.generation and worlds.entries.any(func(entry: Dictionary) -> bool: return entry.key == pending.key and entry.scene.get_instance_id() == pending.scene_id)
		if not current: pending.job.cancel()
		if not pending.job.done: continue
		var verified: Dictionary = pending.job.result if pending.job.result is Dictionary else {}
		var written: bool = false
		if current and visual.world_built and not verified.is_empty(): written = _publish(verified,func() -> bool: return true)
		else: DirAccess.remove_absolute(pending.receipt.temporary)
		if is_instance_valid(visual) and visual.profile_build:
			visual.build_costs.world_disk_written = written
			visual.build_costs.world_disk_write_parts = write_costs.duplicate() if written else pending.receipt.costs.duplicate()
		pending.job.result = null
		pending_writes.remove_at(index)

static func _owner_current(visual: Node3D) -> bool:
	if not is_instance_valid(visual) or not visual.is_inside_tree(): return false
	var ancestor: Node = visual
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return false
		ancestor = ancestor.get_parent()
	# Normal activation clears Game.preparation_current before closing the
	# cover. Its own current predicate therefore remains valid in a live race.
	return visual._build_is_current()

static func _finish_writes() -> void:
	# WorkJob's earlier tree-exit callback joins its workers before this cleanup.
	for pending: Dictionary in pending_writes:
		pending.job.cancel()
		DirAccess.remove_absolute(pending.receipt.temporary)
		pending.job.result = null
	pending_writes.clear(); _tree = null

static func _serialize(id: String, entry: Dictionary, current: Callable) -> Dictionary:
	write_costs = {}
	if not _hex(id) or directory.is_empty() or not current.call() or not entry.has_all(["scene","metadata","props","tyres","scenic_count","bytes"]): return {}
	if int(entry.bytes) <= 0 or int(entry.bytes) > MAX_RESIDENT_BYTES: return {}
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return {}
	_prune("",MAX_TOTAL_BYTES-MAX_FILE_BYTES)
	if _owned_bytes() > MAX_TOTAL_BYTES-MAX_FILE_BYTES: return {}
	# Never rewrite a hit. In particular mutable Winter leases and active prop
	# clocks are not serialized back into the pristine construction snapshot.
	var existing: Dictionary = _manifest(id)
	if not rejected.has(id) and not existing.is_empty() and _payload_valid(existing): return {}
	var artifact := ARTIFACT.new()
	artifact.cache_id = id; artifact.scene = entry.scene; artifact.world_metadata = entry.metadata
	artifact.prop_indices = PackedInt32Array(entry.props); artifact.tyre_index = int(entry.tyres)
	artifact.scenic_count = int(entry.scenic_count); artifact.estimated_bytes = int(entry.bytes)
	if not _valid_scene(artifact): return {}
	var temporary: String = directory.path_join(id+".pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())+".res")
	var mark: int = Time.get_ticks_usec()
	if ResourceSaver.save(artifact,temporary,ResourceSaver.FLAG_COMPRESS) != OK:
		DirAccess.remove_absolute(temporary); return {}
	write_costs.serialize_us = Time.get_ticks_usec()-mark
	var file := FileAccess.open(temporary,FileAccess.READ)
	var size: int = file.get_length() if file != null else 0
	if file != null: file.close()
	if size <= 0 or size > MAX_FILE_BYTES or not current.call():
		DirAccess.remove_absolute(temporary); return {}
	return {"id":id,"directory":directory,"temporary":temporary,"bytes":size,"source":source_key,"build":_build_hash(),"costs":write_costs.duplicate()}

static func _verify_write(cancelled: Callable, receipt: Dictionary) -> Dictionary:
	# This worker sees strings/numbers only, with no scene/renderer/owner access.
	if cancelled.call() or not _hex(receipt.build): DirAccess.remove_absolute(receipt.temporary); return {}
	var mark: int = Time.get_ticks_usec()
	var source: String = source_identity(receipt.build)
	var result: Dictionary = receipt.duplicate(true)
	result.costs.source_us = Time.get_ticks_usec()-mark
	if source != receipt.source or cancelled.call(): DirAccess.remove_absolute(receipt.temporary); return {}
	mark = Time.get_ticks_usec()
	result.sha256 = FileAccess.get_sha256(receipt.temporary)
	result.costs.checksum_us = Time.get_ticks_usec()-mark
	if not _hex(result.sha256) or cancelled.call(): DirAccess.remove_absolute(receipt.temporary); return {}
	return result

static func _publish(receipt: Dictionary, current: Callable) -> bool:
	if not current.call() or directory != receipt.directory or source_key != receipt.source: DirAccess.remove_absolute(receipt.temporary); return false
	var lock: String = _acquire_lock()
	if lock.is_empty(): DirAccess.remove_absolute(receipt.temporary); return false
	var result: bool = _publish_locked(receipt,current)
	_release_lock(lock)
	return result

static func _publish_locked(receipt: Dictionary, current: Callable) -> bool:
	var mark: int = Time.get_ticks_usec()
	write_costs = receipt.costs.duplicate()
	var id: String = receipt.id
	var checksum: String = receipt.sha256
	# Include the publishing PID so another process cannot prune a live writer's
	# uncommitted payload, or remove a shared final file after its own failure.
	var name: String = id+"-"+checksum+"-"+str(OS.get_process_id())+".res"
	var final_path: String = directory.path_join(name)
	if DirAccess.rename_absolute(receipt.temporary,final_path) != OK:
		DirAccess.remove_absolute(receipt.temporary); return false
	# The manifest is the single atomic commit point. An interrupted write can
	# leave only an unreferenced owned payload, never a half-valid published pair.
	var pending: String = directory.path_join(id+".json.pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"format":FORMAT,"id":id,"file":name,"sha256":checksum,"bytes":receipt.bytes}))
	file.flush(); var ok: bool = file.get_error() == OK; file.close()
	if not ok or not current.call() or DirAccess.rename_absolute(pending,directory.path_join(id+".json")) != OK:
		DirAccess.remove_absolute(pending); return false
	writes += 1
	rejected.erase(id)
	_prune_locked(id,MAX_TOTAL_BYTES)
	write_costs.publish_us = Time.get_ticks_usec()-mark
	return true

static func _payload_valid(manifest: Dictionary) -> bool:
	if manifest.is_empty(): return false
	var path: String = directory.path_join(manifest.file)
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	var size: int = file.get_length(); file.close()
	return size == int(manifest.bytes) and size > 0 and size <= MAX_FILE_BYTES and FileAccess.get_sha256(path) == manifest.sha256

static func _manifest(id: String) -> Dictionary:
	if directory.is_empty() or not _hex(id): return {}
	var file := FileAccess.open(directory.path_join(id+".json"),FileAccess.READ)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > 1024: file.close(); return {}
	var value: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not value is Dictionary or value.get("format") != FORMAT or value.get("id") != id: return {}
	var checksum: Variant = value.get("sha256")
	var filename: Variant = value.get("file")
	if not checksum is String or not _hex(checksum) or not filename is String or not filename.begins_with(id+"-"+checksum+"-") or _payload_owner(filename) <= 0: return {}
	if not value.get("bytes") is float and not value.get("bytes") is int: return {}
	if value.bytes <= 0 or value.bytes > MAX_FILE_BYTES: return {}
	return value

static func _prune(newest: String, allowance: int = MAX_TOTAL_BYTES) -> void:
	var lock: String = _acquire_lock()
	if lock.is_empty(): return
	_prune_locked(newest,allowance)
	_release_lock(lock)

static func _prune_locked(newest: String, allowance: int) -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	var entries: Array[Dictionary] = []
	var total: int = 0
	var referenced: Dictionary = {}
	for name: String in folder.get_files():
		if name.length() != 69 or not name.ends_with(".json") or not _hex(name.left(64)): continue
		var manifest: Dictionary = _manifest(name.left(64))
		if manifest.is_empty(): DirAccess.remove_absolute(directory.path_join(name)); continue
		referenced[manifest.file] = true
		entries.append({"id":manifest.id,"file":manifest.file,"bytes":int(manifest.bytes),"modified":FileAccess.get_modified_time(directory.path_join(name))})
		total += int(manifest.bytes)
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.id == newest: return false
		if b.id == newest: return true
		return a.id < b.id if a.modified == b.modified else a.modified < b.modified)
	while not entries.is_empty() and (entries.size() > MAX_FILES or total > allowance):
		var entry: Dictionary = entries.pop_front()
		if DirAccess.remove_absolute(directory.path_join(entry.id+".json")) == OK:
			DirAccess.remove_absolute(directory.path_join(entry.file)); referenced.erase(entry.file); total -= int(entry.bytes)
	for name: String in folder.get_files():
		# Final publication and pruning share this lock. No live publisher can
		# have an uncommitted final payload here; pending writes stay protected.
		if _payload_owner(name) > 0 and not referenced.has(name): DirAccess.remove_absolute(directory.path_join(name))
		elif _abandoned_pending(name): DirAccess.remove_absolute(directory.path_join(name))
	for name: String in DirAccess.get_directories_at(directory):
		if not name.begins_with(".publication-lock.pending-"): continue
		var token: String = name.trim_prefix(".publication-lock.pending-")
		var fields: PackedStringArray = token.split("-")
		if fields.size() == 2 and fields[0].is_valid_int() and fields[1].is_valid_int() and int(fields[0]) > 0 and not OS.is_process_running(int(fields[0])): _discard_lock_candidate(directory.path_join(name),token)

static func _owned_bytes() -> int:
	var total: int = 0
	for name: String in DirAccess.get_files_at(directory):
		if _payload_owner(name) <= 0 and not (_hex(name.left(64)) and (name.substr(64).begins_with(".pending-") or name.substr(64).begins_with(".json.pending-"))): continue
		var file := FileAccess.open(directory.path_join(name),FileAccess.READ)
		if file != null: total += file.get_length(); file.close()
	return total

static func _payload_owner(name: String) -> int:
	if name.length() < 135 or name.substr(64,1) != "-" or name.substr(129,1) != "-" or not name.ends_with(".res") or not _hex(name.left(64)) or not _hex(name.substr(65,64)): return 0
	var process: String = name.substr(130,name.length()-134)
	return int(process) if process.is_valid_int() and int(process) > 0 else 0

static func _acquire_lock() -> String:
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory): return ""
	var path: String = directory.path_join(".publication-lock")
	var token: String = str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var candidate: String = directory.path_join(".publication-lock.pending-"+token)
	if DirAccess.make_dir_absolute(candidate) != OK: return ""
	var owner_path: String = candidate.path_join("owner-"+token)
	var file := FileAccess.open(owner_path,FileAccess.WRITE)
	if file == null: DirAccess.remove_absolute(candidate); return ""
	file.store_string(token); file.flush(); var ok: bool = file.get_error() == OK; file.close()
	if not ok: _discard_lock_candidate(candidate,token); return ""
	# Publish a fully populated directory atomically. A live fixed lock is
	# never empty, so interrupted/finished empty directories can be reclaimed.
	if DirAccess.rename_absolute(candidate,path) != OK:
		var markers: PackedStringArray = DirAccess.get_files_at(path)
		if not markers.is_empty():
			if markers.size() != 1 or not markers[0].begins_with("owner-"): _discard_lock_candidate(candidate,token); return ""
			var fields: PackedStringArray = markers[0].trim_prefix("owner-").split("-")
			if fields.size() != 2 or not fields[0].is_valid_int() or int(fields[0]) <= 0 or not fields[1].is_valid_int() or OS.is_process_running(int(fields[0])): _discard_lock_candidate(candidate,token); return ""
			# Only one contender can unlink the exact observed dead owner's token.
			if DirAccess.remove_absolute(path.path_join(markers[0])) != OK: _discard_lock_candidate(candidate,token); return ""
		if DirAccess.remove_absolute(path) != OK or DirAccess.rename_absolute(candidate,path) != OK: _discard_lock_candidate(candidate,token); return ""
	return token

static func _discard_lock_candidate(path: String, token: String) -> void:
	DirAccess.remove_absolute(path.path_join("owner-"+token))
	DirAccess.remove_absolute(path)

static func _release_lock(token: String) -> void:
	var path: String = directory.path_join(".publication-lock")
	var owner_path: String = path.path_join("owner-"+token)
	if FileAccess.file_exists(owner_path) and FileAccess.get_file_as_string(owner_path) == token:
		DirAccess.remove_absolute(owner_path); DirAccess.remove_absolute(path)

static func _abandoned_pending(name: String) -> bool:
	if not _hex(name.left(64)): return false
	var tail: String = name.substr(64)
	if tail.begins_with(".pending-") and tail.ends_with(".res"): tail = tail.trim_prefix(".pending-").trim_suffix(".res")
	elif tail.begins_with(".json.pending-"): tail = tail.trim_prefix(".json.pending-")
	else: return false
	var fields: PackedStringArray = tail.split("-")
	if fields.size() != 2 or not fields[0].is_valid_int() or not fields[1].is_valid_int(): return false
	var process: int = int(fields[0])
	return process > 0 and process != OS.get_process_id() and not OS.is_process_running(process)

static func _hex(value: String) -> bool:
	return value.length() == 64 and value.is_valid_hex_number(false)

static func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()
