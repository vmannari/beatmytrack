extends RefCounted
## Installation-local learning progress. Never part of records, accounts or race evidence.
const SCHEMA: int = 1
const MAX_BYTES: int = 8192
const STATUSES: Array[String] = ["new", "active", "completed", "skipped", "existing"]
const TOPICS: Array[String] = ["garage", "rivalry", "challenges", "creator", "rewind"]
var path: String
var status: String = "new"
var step: int = 0
var seen: Dictionary = {}
var last_error: Error = OK

func _init(file_path: String) -> void:
	path = file_path

func load_progress(existing_player: bool = false) -> void:
	for candidate: String in [path, path+".bak", path+".tmp"]:
		var value: Dictionary = _read(candidate)
		if value.is_empty(): continue
		status = value.status
		step = int(value.step)
		seen = value.seen.duplicate()
		return
	if existing_player:
		status = "existing"
		for topic: String in TOPICS: seen[topic] = true
		save()

static func has_played(records: LocalRecords) -> bool:
	return not records.records.is_empty() or not records.settings.get("raced_tracks",[]).is_empty() or not str(records.settings.get("last_track", "")).is_empty()

func begin(replay: bool = false) -> void:
	if replay or status != "active": step = 0
	status = "active"
	save()

func advance(next_step: int) -> void:
	step = clampi(next_step, 0, 5)
	if step == 5: status = "completed"
	save()

func skip() -> void:
	status = "skipped"
	save()

func dismiss(topic: String) -> void:
	if topic not in TOPICS: return
	seen[topic] = true
	save()

func save() -> Error:
	var value: Dictionary = {"schema":SCHEMA,"status":status,"step":step,"seen":seen.duplicate()}
	last_error = _write(value)
	return last_error

func _write(value: Dictionary) -> Error:
	var directory: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory != OK: return directory
	var temporary: String = path+".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or _read(temporary).is_empty(): return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(path):
		if not _read(path).is_empty():
			if FileAccess.file_exists(path+".bak"):
				error = DirAccess.remove_absolute(path+".bak")
				if error != OK: return error
			error = DirAccess.rename_absolute(path,path+".bak")
		else: error = DirAccess.remove_absolute(path)
		if error != OK: return error
	return DirAccess.rename_absolute(temporary,path)

static func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary or value.size() != 4 or value.get("schema") != SCHEMA: return {}
	if value.get("status") not in STATUSES or not value.get("seen") is Dictionary: return {}
	var number: Variant = value.get("step")
	if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)) or number < 0 or number > 5: return {}
	if value.status == "completed" and number != 5: return {}
	for topic: Variant in value.seen:
		if topic not in TOPICS or value.seen[topic] != true: return {}
	return value
