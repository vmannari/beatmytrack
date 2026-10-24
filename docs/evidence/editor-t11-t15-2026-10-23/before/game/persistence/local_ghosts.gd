class_name LocalGhosts
extends RefCounted
## Profile-scoped, atomic local PB poses. No ghost data is uploaded.
const SCHEMA: int = 1
const MAX_BYTES: int = 16777216
var folder: String

func _init(records_path: String = "user://local_records.json") -> void:
	folder = records_path.get_basename() + "_ghosts"

func load_best(key: String, best: Dictionary) -> Dictionary:
	var data: Dictionary = _load(key)
	var result: Dictionary = {}
	for mode: String in ["lap", "race"]:
		var recording: Dictionary = data.get(mode, {})
		if _matches(recording, best, mode): result[mode] = recording
	return result

func save_run(key: String, best: Dictionary, run: PersonalGhostRun) -> Error:
	if run.overflow: return ERR_OUT_OF_MEMORY
	var data: Dictionary = _load(key)
	var changed: bool = false
	for mode: String in ["lap", "race"]:
		var candidate: Dictionary = run.recording(mode)
		if not _matches(candidate, best, mode): continue
		var previous: Dictionary = data.get(mode, {})
		if _matches(previous,best,mode) and float(previous.ticks) <= float(candidate.ticks): continue
		data[mode] = candidate
		changed = true
	if not changed: return OK
	data.schema = SCHEMA
	data.key = key
	if not _valid(data, key): return ERR_INVALID_DATA
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK: return error
	var path: String = folder.path_join(key + ".json")
	var content: String = JSON.stringify(data)
	if content.to_utf8_buffer().size() > MAX_BYTES: return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or _read(path + ".tmp", key).is_empty(): return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(path):
		if not _read(path, key).is_empty():
			if FileAccess.file_exists(path + ".bak"):
				error = DirAccess.remove_absolute(path + ".bak")
				if error != OK: return error
			error = DirAccess.rename_absolute(path, path + ".bak")
		else: error = DirAccess.remove_absolute(path)
		if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func _load(key: String) -> Dictionary:
	if not _key_valid(key): return {}
	var path: String = folder.path_join(key + ".json")
	for candidate: String in [path, path + ".bak"]:
		var result: Dictionary = _read(candidate, key)
		if not result.is_empty(): return result
	return {}

static func _matches(recording: Dictionary, best: Dictionary, mode: String) -> bool:
	return not recording.is_empty() and roundi(float(recording.ticks) * 1000.0 / VehicleSimulation.TICK_RATE) == int(best.get("flying_ms" if mode == "lap" else "race_ms", 0))

static func _read(path: String, key: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var content: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(content) != OK: return {}
	return parser.data if _valid(parser.data, key) else {}

static func _key_valid(key: String) -> bool:
	if key.length() != 64: return false
	for character: String in key:
		if character not in "0123456789abcdef": return false
	return true

static func _valid(value: Variant, key: String) -> bool:
	if not _key_valid(key) or not value is Dictionary: return false
	if value.get("schema") != SCHEMA or value.get("key") != key or value.size() < 3 or value.size() > 4: return false
	for field: Variant in value:
		if field not in ["schema", "key", "lap", "race"]: return false
	for mode: String in ["lap", "race"]:
		if not value.has(mode): continue
		var recording: Variant = value[mode]
		if not recording is Dictionary or recording.size() != 2: return false
		var duration: Variant = recording.get("ticks")
		if not LocalRecords._number(duration) or duration <= 0 or duration > PersonalGhostRun.MAX_TICKS: return false
		var samples: Variant = recording.get("poses")
		if not samples is Array or samples.size() < 2 or samples.size() > PersonalGhostRun.MAX_TICKS / PersonalGhostRun.STRIDE + RaceRules.LAPS + 2: return false
		var previous: float = -1.0
		for pose: Variant in samples:
			if not pose is Array or pose.size() != 7: return false
			for component: Variant in pose:
				if not LocalRecords._number(component) or absf(float(component)) > 1000000.0: return false
			if pose[0] <= previous or pose[0] > duration: return false
			previous = float(pose[0])
		if samples[0][0] != 0 or previous != float(duration): return false
	return true
