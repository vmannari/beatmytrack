extends Node
## Presentation observer only. Fixed counters, 1 Hz cells, no simulation writes.
const LIMITS: Array[float] = [8.0,12.0,17.0,25.0,34.0,50.0,100.0]
const MAX_CELLS: int = 16
var telemetry: Node
var app: Node
var bins: Dictionary = {}
var cells: Dictionary = {}
var _scope: String = ""
var _last_summary_msec: int = Time.get_ticks_msec()
var _last_cells_msec: int = Time.get_ticks_msec()
var _next_position_msec: int = 0
var _native_checked: bool = false
var _device: String = "desktop"
var _last_frame_usec: int = 0
var _slow_since_sample: bool = false
var dropped_cell_samples: int = 0

func supported() -> bool:
	return telemetry != null and telemetry.enabled and telemetry.client != null and telemetry.client.has_method("quality_supported") and telemetry.client.quality_supported() and telemetry._foreground

func _ready() -> void:
	if OS.get_name() == "Android": _device = "android_arm64" if OS.has_feature("arm64") else "android_other"
	elif OS.get_name() != "Windows" and OS.get_name() != "Linux": _device = "other"

func _process(delta: float) -> void:
	if not supported():
		bins.clear(); cells.clear(); _scope = ""
		_last_frame_usec = 0
		return
	var current_scope: String = telemetry._scope
	if current_scope != _scope:
		bins.clear(); cells.clear(); _scope = current_scope
		_last_summary_msec = Time.get_ticks_msec(); _last_cells_msec = _last_summary_msec
	var current_game: Node = app.get("game") if app != null else null
	var racing: bool = is_instance_valid(current_game) and not bool(current_game.get("paused")) and not bool(app.get("_telemetry_race_finished"))
	var scene: String = "race" if racing else "editor" if app != null and app.get("screen") == "create" else "menu"
	var usec: int = Time.get_ticks_usec()
	var frame_ms: float = (usec-_last_frame_usec)/1000.0 if _last_frame_usec > 0 else delta*1000.0
	_last_frame_usec = usec
	sample_frame(scene,frame_ms)
	if racing and frame_ms > 34.0: _slow_since_sample = true
	var at: int = Time.get_ticks_msec()
	if racing and at >= _next_position_msec:
		_next_position_msec = at+1000
		var sim: VehicleSimulation = current_game.get("sim")
		var track: NativeTrack = current_game.get("native_track")
		var session: TrackSession = current_game.get("track_session")
		if sim != null and session != null and track != null and sim.state.tick > 0:
			var version: String = str(track.metadata.get("cloud_version",""))
			if version.length() == 36:
				var segment: int = clampi(int(fposmod(session.last_progress,track.route_length)/maxf(track.route_length,1.0)*32),0,31)
				sample_cell(version,segment,sim.state.position,_slow_since_sample)
		_slow_since_sample = false
	if at-_last_summary_msec >= 300000:
		flush_frames(); _last_summary_msec = at
	if at-_last_cells_msec >= 600000 and telemetry._allowed:
		flush_cells(); _last_cells_msec = at
	if not _native_checked and telemetry._allowed and telemetry._loaded:
		_native_checked = true
		_collect_exits()

func sample_frame(scene: String, milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds < 0: return
	var value: PackedInt64Array = bins.get(scene,PackedInt64Array([0,0,0,0,0,0,0,0]))
	var bucket: int = 0
	while bucket < LIMITS.size() and milliseconds > LIMITS[bucket]: bucket += 1
	if value[bucket] < 1000000: value[bucket] += 1
	bins[scene] = value

func sample_cell(version: String, segment: int, position: Vector2, slow: bool) -> void:
	if not is_finite(position.x) or not is_finite(position.y): return
	var x: int = int(floor(position.x/20.0)); var y: int = int(floor(position.y/20.0))
	if absi(x) > 5000 or absi(y) > 5000: return
	var key: String = version+"/"+str(segment)+"/"+str(x)+"/"+str(y)
	if not cells.has(key) and cells.size() >= MAX_CELLS:
		# Retain the 16 lowest stable cell hashes instead of only start-line cells.
		var largest: String = key
		for existing: String in cells:
			if existing.sha256_text() > largest.sha256_text(): largest = existing
		if largest == key: dropped_cell_samples += 1; return
		dropped_cell_samples += int(cells[largest].samples); cells.erase(largest)
	var value: Dictionary = cells.get(key,{"track_version_id":version,"segment":segment,"cell_x":x,"cell_y":y,"samples":0,"slow":0})
	if value.samples < 1000000: value.samples += 1; value.slow += int(slow)
	cells[key] = value

func flush_frames() -> void:
	for scene: String in bins.keys():
		var value: PackedInt64Array = bins[scene]
		var props: Dictionary = {"device_class":_device,"scene":scene,"samples":0,"slow":value[5]+value[6]+value[7]}
		for index: int in range(8): props["b"+str(index)] = int(value[index]); props.samples += int(value[index])
		if props.samples > 0 and telemetry.observe("quality_summary",props): bins.erase(scene)

func flush_cells() -> void:
	for key: String in cells.keys():
		if telemetry.observe("segment_summary",cells[key]): cells.erase(key)

func _collect_exits() -> void:
	if not Engine.has_singleton("BmtGoogleSignIn"): return
	var native: Object = Engine.get_singleton("BmtGoogleSignIn")
	if not native.has_method("getProcessExits"): return
	var parsed: Variant = JSON.parse_string(native.getProcessExits())
	if not parsed is Array: return
	for entry: Variant in parsed:
		if not entry is Dictionary or int(entry.get("at",0)) <= telemetry._process_exit_cursor: continue
		var reason: int = int(entry.get("reason",0))
		if reason in [4,5,6] and telemetry.observe("process_exit",{"device_class":_device,"exit_reason":reason}):
			telemetry._process_exit_cursor = maxi(telemetry._process_exit_cursor,int(entry.at))
			telemetry._mark_dirty()
