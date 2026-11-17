class_name LocalRecords
extends RefCounted
## Local, unverified PBs. Persistence and recovery stay outside canonical physics.
signal achievement_progress_committed
signal appearance_committed

const SCHEMA: int = 2
const MAX_BYTES: int = 4194304
const MAX_TIME_MS: int = 2147483647

var path: String
var records: Dictionary = {}
var settings: Dictionary = {}
var _committed_records: Dictionary = {}
var _committed_settings: Dictionary = {}
var _condition_store: Node
var _condition_revision: int = -1
var _condition_committed_revision: int = -1
var _pending_save: Dictionary = {}
var _records_json: String = ""
var _document_text: String = ""
static var _writers: Array[LocalRecords] = []
static var _writer_tree: SceneTree


func _init(file_path: String = "user://local_records.json") -> void:
	path = file_path


func load_records() -> void:
	flush_save()
	_flush_path(path)
	if is_instance_valid(_condition_store): _condition_store.flush(); _condition_store.release(self)
	_condition_store = null
	_condition_revision = -1
	_condition_committed_revision = -1
	records = {}
	settings = {}
	_committed_records = {}
	_committed_settings = {}
	_records_json = ""
	_document_text = ""
	# A temporary is uncommitted and is never loaded as a personal best.
	for candidate: String in [path,path+".bak"]:
		var document: Dictionary = _read_document(candidate)
		if document.is_empty():
			continue
		records = document.records
		settings = document.settings
		_document_text = FileAccess.get_file_as_string(candidate)
		break
	# A small sidecar overrides legacy embedded cosmetics, including when the
	# PB file does not yet exist. Old files remain intact until a normal commit.
	_remember_committed()
	_records_json = JSON.stringify(_committed_records,"",true)
	_conditions()


func _conditions() -> Node:
	var condition_path: String = ProjectSettings.globalize_path(path+".conditions.json").simplify_path()
	if not is_instance_valid(_condition_store) or _condition_store.path != condition_path:
		if is_instance_valid(_condition_store): _condition_store.flush(); _condition_store.release(self)
		_condition_store = preload("res://persistence/condition_store.gd").acquire(condition_path,settings.get("vehicle_conditions",{}),weakref(self))
		_condition_revision = -1
		_condition_committed_revision = -1
	_sync_conditions()
	return _condition_store


func _sync_conditions() -> void:
	if _condition_revision != _condition_store.revision and (not _condition_store.current.is_empty() or settings.has("vehicle_conditions")):
		settings.vehicle_conditions = _condition_store.current.duplicate(true)
	_condition_revision = _condition_store.revision
	if _condition_committed_revision != _condition_store.committed_revision and (not _condition_store.committed.is_empty() or _committed_settings.has("vehicle_conditions")):
		_committed_settings.vehicle_conditions = _condition_store.committed.duplicate(true)
	_condition_committed_revision = _condition_store.committed_revision


func save_vehicle_conditions(value: Dictionary, background: bool = false) -> Error:
	var store: Node = _conditions()
	var error: Error = store.stage(value)
	if error == OK and not background: error = store.flush()
	_sync_conditions()
	return error


func key_for(track: NativeTrack, handling: HandlingConfig) -> String:
	return (track.content_hash + VehicleSimulation.PHYSICS_VERSION + JSON.stringify(handling.snapshot(),"",true) + RaceRules.KEY).sha256_text()


func best_for(track: NativeTrack, handling: HandlingConfig) -> float:
	return float(records.get(key_for(track,handling),{}).get("race_ms",0)) / 1000.0


func record(track: NativeTrack, handling: HandlingConfig, race_time: float, laps: Array[float]) -> Error:
	if not _positive_seconds(race_time) or laps.size() != RaceRules.LAPS:
		return ERR_INVALID_DATA
	var total: float = 0.0
	for lap: float in laps:
		if not _positive_seconds(lap):
			return ERR_INVALID_DATA
		total += lap
	if absf(total-race_time) > 0.002:
		return ERR_INVALID_DATA
	var key: String = key_for(track,handling)
	var value: Dictionary = records.get(key,{}).duplicate(true)
	var race_ms: int = roundi(race_time*1000.0)
	var flying_ms: int = roundi(laps[1]*1000.0)
	for index: int in range(2, laps.size()):
		flying_ms = mini(flying_ms, roundi(laps[index]*1000.0))
	value.race_ms = mini(int(value.get("race_ms",race_ms)),race_ms)
	value.flying_ms = mini(int(value.get("flying_ms",flying_ms)),flying_ms)
	records[key] = value
	var raced: Array = settings.get("raced_tracks",[]).duplicate()
	if track.identity not in raced: raced.append(track.identity)
	settings["raced_tracks"] = raced
	preload("res://persistence/driving_history.gd").record(self,track,handling.vehicle_id)
	return save_records()


func _prepare_save() -> Error:
	if settings.has("vehicle_conditions") and not VehicleCondition.valid_collection(settings.vehicle_conditions): return _failed(ERR_INVALID_DATA)
	if is_instance_valid(_condition_store):
		# A caller may still deliberately update the legacy settings API. Keep
		# that valid change, without allowing invalid values to be overwritten.
		if _condition_revision == _condition_store.revision and settings.get("vehicle_conditions",{}) != _condition_store.current:
			_condition_store.stage(settings.get("vehicle_conditions",{}))
		var condition_error: Error = _condition_store.flush()
		if condition_error != OK: return _failed(condition_error)
		_condition_revision = -1
		_sync_conditions()
	return OK


func save_records() -> Error:
	flush_save()
	_flush_path(path)
	var error: Error = _prepare_save()
	if error != OK: return error
	var result: Dictionary = _write_document(path,{"schema":SCHEMA,"records":records,"settings":settings},_save_cache())
	if result.error != OK: return _failed(result.error)
	_accept_save(result)
	return OK


func save_records_async() -> Error:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null: return save_records()
	# Every caller observes its own durable result. The synchronous entry point
	# joins this same writer before reusing the primary/backup/temporary paths.
	var destination: String = _absolute_path(path)
	while not _pending_save.is_empty() or _path_pending(destination): await tree.process_frame
	var error: Error = _prepare_save()
	if error != OK: return error
	var job: Dictionary = {"destination":destination,"source":{"schema":SCHEMA,"records":records.duplicate(true),"settings":settings.duplicate(true)},"thread":Thread.new(),"done":false,"error":OK}
	_pending_save = job
	error = job.thread.start(_write_document.bind(destination,job.source,_save_cache()),Thread.PRIORITY_LOW)
	if error != OK:
		_pending_save = {}
		return _failed(error)
	_writers.append(self)
	if _writer_tree == null:
		_writer_tree = tree
		tree.process_frame.connect(_poll_saves)
		tree.root.tree_exiting.connect(_flush_saves)
	while not job.done:
		if job.thread.is_alive(): await tree.process_frame
		else: flush_save()
	return job.error


static func _poll_saves() -> void:
	for owner: LocalRecords in _writers.duplicate():
		if not owner._pending_save.is_empty() and not owner._pending_save.thread.is_alive(): owner.flush_save()


static func _absolute_path(destination: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(destination).simplify_path()
	return absolute.to_lower() if OS.get_name() == "Windows" else absolute


static func _path_pending(destination: String) -> bool:
	for owner: LocalRecords in _writers:
		if owner._pending_save.destination == destination: return true
	return false


static func _flush_path(destination: String) -> void:
	var absolute: String = _absolute_path(destination)
	for owner: LocalRecords in _writers.duplicate():
		if not owner._pending_save.is_empty() and owner._pending_save.destination == absolute: owner.flush_save()


static func _flush_saves() -> void:
	for owner: LocalRecords in _writers.duplicate(): owner.flush_save()
	_writer_tree = null


func flush_save() -> void:
	if _pending_save.is_empty(): return
	var job: Dictionary = _pending_save
	var result: Dictionary = job.thread.wait_to_finish()
	job.thread = null
	_pending_save = {}
	_writers.erase(self)
	# Preserve edits authored while the immutable worker snapshot was in flight.
	var live_records: Dictionary = records
	var live_settings: Dictionary = settings
	job.error = result.error
	if result.error == OK:
		_accept_save(result,job.source,{"records":live_records,"settings":live_settings})
	else:
		_failed(result.error)
		_merge_edits(records,job.source.records,live_records)
		_merge_edits(settings,job.source.settings,live_settings)
	job.done = true


static func _merge_edits(target: Dictionary, source: Dictionary, live: Dictionary) -> void:
	for key: Variant in source:
		if not live.has(key): target.erase(key)
	for key: Variant in live:
		if not source.has(key) or source[key] != live[key]: target[key] = live[key]


func _save_cache() -> Dictionary:
	return {"records":_committed_records,"records_json":_records_json,"content":_document_text}


static func _write_document(destination: String, source: Dictionary, cache: Dictionary) -> Dictionary:
	# Validated PBs are immutable between record commits. Preference writes can
	# reuse their encoding while still validating every changed preference.
	var same_records: bool = not cache.records_json.is_empty() and source.records == cache.records
	var document: Dictionary = _normalize({"schema":SCHEMA,"records":{},"settings":source.settings} if same_records else source)
	if document.is_empty():
		return {"error":ERR_INVALID_DATA}
	var encoded_records: String = cache.records_json if same_records else JSON.stringify(document.records,"",true)
	if same_records: document.records = cache.records
	var content: String = '{"records":'+encoded_records+',"schema":'+str(SCHEMA)+',"settings":'+JSON.stringify(document.settings,"",true)+'}'
	var bytes: PackedByteArray = content.to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return {"error":ERR_OUT_OF_MEMORY}
	var temporary: String = destination+".tmp"
	var backup: String = destination+".bak"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return {"error":FileAccess.get_open_error()}
	file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	# Compare the complete bytes against the already validated encoding.
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		return {"error":ERR_FILE_CANT_WRITE}
	if FileAccess.file_exists(destination):
		var known_primary: bool = not cache.content.is_empty() and FileAccess.get_file_as_bytes(destination) == cache.content.to_utf8_buffer()
		if known_primary or not _read_document(destination).is_empty():
			if FileAccess.file_exists(backup):
				error = DirAccess.remove_absolute(backup)
				if error != OK:
					return {"error":error}
			error = DirAccess.rename_absolute(destination,backup)
		else:
			# Keep the previous good backup when the primary is corrupt.
			error = DirAccess.remove_absolute(destination)
		if error != OK:
			return {"error":error}
	error = DirAccess.rename_absolute(temporary,destination)
	if error != OK:
		return {"error":error}
	return {"error":OK,"document":document,"records_json":encoded_records,"content":content,"same_records":same_records}


func _accept_save(result: Dictionary, source: Dictionary = {}, live: Dictionary = {}) -> void:
	var document: Dictionary = result.document
	_records_json = result.records_json
	_document_text = result.content
	if not result.same_records: records = document.records
	settings = document.settings
	var awards_changed: bool = settings.get("achievements",{}).get("unlocked",{}) != _committed_settings.get("achievements",{}).get("unlocked",{})
	var appearance_changed: bool = settings.get("vehicle_liveries",{}) != _committed_settings.get("vehicle_liveries",{}) or settings.get("vehicle_customisation",{}) != _committed_settings.get("vehicle_customisation",{})
	_remember_committed(result.same_records)
	if not source.is_empty():
		_merge_edits(records,source.records,live.records)
		_merge_edits(settings,source.settings,live.settings)
	if is_instance_valid(_condition_store):
		_condition_revision = -1
		_condition_committed_revision = -1
		_sync_conditions()
	if awards_changed: achievement_progress_committed.emit()
	if appearance_changed: appearance_committed.emit()


func _failed(error: Error) -> Error:
	# A result is visible as a saved PB only after its commit succeeds.
	records = _committed_records.duplicate(true)
	settings = _committed_settings.duplicate(true)
	_condition_revision = -1
	return error


func _remember_committed(same_records: bool = false) -> void:
	if not same_records: _committed_records = records.duplicate(true)
	_committed_settings = settings.duplicate(true)


static func _read_document(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	return _normalize(parser.data)


static func _normalize(data: Variant) -> Dictionary:
	data = preload("res://persistence/save_upgrades.gd").prepare(data)
	if not data is Dictionary or data.size() != 3 or not _number(data.get("schema")):
		return {}
	if float(data.schema) != float(SCHEMA):
		return {}
	if not data.get("records") is Dictionary or not data.get("settings") is Dictionary:
		return {}
	var preferences: Dictionary = data.settings
	for field: Variant in preferences:
		if field == "last_track":
			if not preferences[field] is String or preferences[field].is_empty() or preferences[field].length() > 64: return {}
			for character: String in preferences[field]:
				if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-": return {}
		elif field == "selected_car":
			if not preferences[field] is String or preferences[field] not in VehicleCatalog.ALL_IDS: return {}
		elif field == "achievements":
			if not AchievementProgress.valid(preferences[field]): return {}
		elif field == "driving_history":
			if not preload("res://persistence/driving_history.gd").valid(preferences[field]): return {}
		elif field == "guest_coins":
			if not preload("res://persistence/cosmetic_catalog.gd").valid_guest(preferences[field]): return {}
		elif field == "cosmetic_legacy":
			if not preload("res://persistence/cosmetic_catalog.gd").valid_owned(preferences[field]): return {}
		elif field == "music_record":
			if not preload("res://soundtrack/record_library.gd").valid_id(preferences[field]): return {}
		elif field == "music_playlist":
			if not preload("res://soundtrack/record_library.gd").valid_playlist(preferences[field]): return {}
		elif field == "vehicle_conditions":
			if not VehicleCondition.valid_collection(preferences[field]): return {}
		elif field == "vehicle_liveries":
			if not VehicleLivery.valid_collection(preferences[field]): return {}
		elif field == "vehicle_appearance_sync":
			if not preload("res://persistence/appearance_state.gd").valid(preferences[field]): return {}
		elif field == "vehicle_customisation":
			if not VehicleCustomisation.valid_collection(preferences[field]): return {}
		elif field == "camera_mode":
			if not preferences[field] is String or preferences[field] not in CameraProfile.MODES: return {}
		elif field in preload("res://presentation/graphics_preferences.gd").DEFAULTS:
			if not preload("res://presentation/graphics_preferences.gd").valid(field,preferences[field]): return {}
		elif field == "camera_speed_zoom_strength":
			if not _number(preferences[field]) or float(preferences[field]) < 0.0 or float(preferences[field]) > CameraProfile.MAX_SPEED_ZOOM_STRENGTH: return {}
		elif field == "ghost_mode":
			if not preferences[field] is String or preferences[field] not in PersonalGhostRun.MODES: return {}
		elif field == "track_ratings":
			if not preferences[field] is Dictionary: return {}
			for id: Variant in preferences[field]:
				var rating: Variant = preferences[field][id]
				if not id is String or id.is_empty() or id.length() > 128: return {}
				if not _number(rating) or float(rating) != floorf(float(rating)) or int(rating) < 1 or int(rating) > 5: return {}
		elif field in ["favorites","raced_tracks"]:
			if not preferences[field] is Array: return {}
			for id: Variant in preferences[field]:
				if not id is String or id.length() > 64 or id.is_empty(): return {}
				for character: String in id:
					if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-": return {}
		elif field == "control_layout":
			if not ControlLayout.valid(preferences[field]): return {}
		elif field in ["left_handed", "camera_speed_zoom", "control_labels", "development_show_ads", "optional_analytics", "music_enabled", "drift_haptics"]:
			if not preferences[field] is bool:
				return {}
		elif field in ["steering_haptics", "music_volume", "vehicle_volume", "interface_volume"]:
			if not _number(preferences[field]) or float(preferences[field]) < 0.0 or float(preferences[field]) > 1.0:
				return {}
		elif field == "touch_scale":
			if not _number(preferences[field]) or float(preferences[field]) < 1.0 or float(preferences[field]) > 1.4:
				return {}
		else:
			return {}
	var normalized: Dictionary = {}
	for key: Variant in data.records:
		if not key is String or key.length() != 64:
			return {}
		for character: String in key:
			if character not in "0123456789abcdef":
				return {}
		var entry: Variant = data.records[key]
		if not entry is Dictionary or entry.size() != 2:
			return {}
		var race: Variant = entry.get("race_ms")
		var flying: Variant = entry.get("flying_ms")
		if not _number(race) or not _number(flying):
			return {}
		if float(race) != floorf(float(race)) or float(flying) != floorf(float(flying)):
			return {}
		if float(race) < 1.0 or float(race) > MAX_TIME_MS or float(flying) < 1.0 or float(flying) > float(race):
			return {}
		normalized[key] = {"race_ms":int(race),"flying_ms":int(flying)}
	var normalized_preferences: Dictionary = preferences.duplicate(true)
	if normalized_preferences.has("achievements"):
		normalized_preferences.achievements = AchievementProgress.normalized(normalized_preferences.achievements)
	if normalized_preferences.has("guest_coins"):
		for field: String in ["version","balance","sequence"]:
			normalized_preferences.guest_coins[field] = int(normalized_preferences.guest_coins[field])
	return {"schema":SCHEMA,"records":normalized,"settings":normalized_preferences}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _positive_seconds(value: float) -> bool:
	return is_finite(value) and value >= 0.001 and value <= float(MAX_TIME_MS)/1000.0
