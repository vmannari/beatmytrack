extends RefCounted
## Task-only debug observation. No shader, simulation or network dependency.
const CONFIG: String = "user://tablet_phase_profile.json"
static var _checked: bool = false
static var _active: bool = false
static var options: Dictionary = {}
static var events: Array = []
static var scope: String = "startup"
static var practice: bool = false
static var practice_records: RefCounted
static var dropped: int = 0

static func active() -> bool:
	if not _checked:
		_checked = true
		if OS.is_debug_build() and FileAccess.file_exists(CONFIG):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
			if value is Dictionary and value.get("schema") == 1 and str(value.get("run","")).is_valid_filename():
				options = value
				_active = true
	return _active

static func mark(label: String, detail: Dictionary = {}) -> void:
	if not active(): return
	if events.size() >= 2000: dropped += 1; return
	events.append({"label":label,"us":Time.get_ticks_usec(),"scope":scope,"detail":detail})

static func network(path: String, phase: String, started: int) -> void:
	if not active(): return
	var category: String = path.get_slice("?",0).get_slice("/",1)
	if category not in ["bootstrap","auth","me","game-config","track-of-the-day","lap-standings","rivalries","challenges","discovery","track-versions","telemetry","players"]: category = "other"
	mark("network_"+phase,{"category":category,"ms":(Time.get_ticks_usec()-started)/1000.0})
