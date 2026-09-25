class_name LocalRecords
extends RefCounted
## Local, unverified PBs. Persistence and recovery stay outside canonical physics.

const SCHEMA: int = 2
const MAX_BYTES: int = 4194304
const MAX_TIME_MS: int = 2147483647

var path: String
var records: Dictionary = {}
var settings: Dictionary = {}
var _committed_records: Dictionary = {}
var _committed_settings: Dictionary = {}


func _init(file_path: String = "user://local_records.json") -> void:
	path = file_path


func load_records() -> void:
	records = {}
	settings = {}
	_committed_records = {}
	_committed_settings = {}
	# A temporary is uncommitted and is never loaded as a personal best.
	for candidate: String in [path,path+".bak"]:
		var document: Dictionary = _read_document(candidate)
		if document.is_empty():
			continue
		records = document.records
		settings = document.settings
		_remember_committed()
		return


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
	return save_records()


func save_records() -> Error:
	var document: Dictionary = _normalize({"schema":SCHEMA,"records":records,"settings":settings})
	if document.is_empty():
		return _failed(ERR_INVALID_DATA)
	var content: String = JSON.stringify(document,"",true)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return _failed(ERR_OUT_OF_MEMORY)
	var temporary: String = path+".tmp"
	var backup: String = path+".bak"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return _failed(FileAccess.get_open_error())
	file.store_string(content)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or _read_document(temporary).is_empty():
		return _failed(ERR_FILE_CANT_WRITE)
	if FileAccess.file_exists(path):
		if not _read_document(path).is_empty():
			if FileAccess.file_exists(backup):
				error = DirAccess.remove_absolute(backup)
				if error != OK:
					return _failed(error)
			error = DirAccess.rename_absolute(path,backup)
		else:
			# Keep the previous good backup when the primary is corrupt.
			error = DirAccess.remove_absolute(path)
		if error != OK:
			return _failed(error)
	error = DirAccess.rename_absolute(temporary,path)
	if error != OK:
		return _failed(error)
	records = document.records
	settings = document.settings
	_remember_committed()
	return OK


func _failed(error: Error) -> Error:
	# A result is visible as a saved PB only after its commit succeeds.
	records = _committed_records.duplicate(true)
	settings = _committed_settings.duplicate(true)
	return error


func _remember_committed() -> void:
	_committed_records = records.duplicate(true)
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
	if not data is Dictionary or data.size() != 3 or not _number(data.get("schema")):
		return {}
	if float(data.schema) != 1.0 and float(data.schema) != float(SCHEMA):
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
			if not preferences[field] is String or preferences[field] not in VehicleCatalog.IDS: return {}
		elif field == "track_ratings":
			if not preferences[field] is Dictionary: return {}
			for id: Variant in preferences[field]:
				var rating: Variant = preferences[field][id]
				if not id is String or id.is_empty() or id.length() > 128: return {}
				if not _number(rating) or float(rating) != floorf(float(rating)) or int(rating) < 1 or int(rating) > 5: return {}
		elif field == "favorites":
			if not preferences[field] is Array: return {}
			for id: Variant in preferences[field]:
				if not id is String or id.length() > 64 or id.is_empty(): return {}
				for character: String in id:
					if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-": return {}
		elif field == "control_layout":
			if not ControlLayout.valid(preferences[field]): return {}
		elif field == "left_handed":
			if not preferences[field] is bool:
				return {}
		elif field == "steering_haptics":
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
		var race: Variant = entry.get("race_ms") if data.schema == SCHEMA else entry.get("race")
		var flying: Variant = entry.get("flying_ms") if data.schema == SCHEMA else entry.get("flying")
		if not _number(race) or not _number(flying):
			return {}
		if data.schema == 1:
			if not _positive_seconds(float(race)) or not _positive_seconds(float(flying)):
				return {}
			race = roundi(float(race)*1000.0)
			flying = roundi(float(flying)*1000.0)
		if float(race) != floorf(float(race)) or float(flying) != floorf(float(flying)):
			return {}
		if float(race) < 1.0 or float(race) > MAX_TIME_MS or float(flying) < 1.0 or float(flying) > float(race):
			return {}
		normalized[key] = {"race_ms":int(race),"flying_ms":int(flying)}
	return {"schema":SCHEMA,"records":normalized,"settings":preferences.duplicate(true)}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _positive_seconds(value: float) -> bool:
	return is_finite(value) and value >= 0.001 and value <= float(MAX_TIME_MS)/1000.0
