extends Node
## Presentation observer only. One bounded package per timed attempt; no live IO.
const LIMITS: Array[float] = [8.0,12.0,17.0,25.0,34.0,50.0,100.0]
const MAX_CELLS: int = 128
const MAX_POSITION_SAMPLES: int = 3600
const MAX_FRAMES: int = 1000000
const RenderContext = preload("res://backend/race_render_context.gd")
var telemetry: Node
var app: Node
var bins: Dictionary = {}
var cells: Dictionary = {}
var segments: Dictionary = {}
var dropped_cell_samples: int = 0
var _scope: String = ""
var _last_summary_msec: int = Time.get_ticks_msec()
var _next_position_msec: int = 0
var _native_checked: bool = false
var _device: String = "desktop"
var _device_model: String = "unknown"
var _os_version: String = "unknown"
var _last_frame_usec: int = 0
var _slow_since_sample: bool = false
var _race_id: String = ""
var _race_scope: String = ""
var _race_version: String = ""
var _race_ticket: String = ""
var _race_started_msec: int = 0
var _race_frames: PackedInt64Array = PackedInt64Array([0,0,0,0,0,0,0,0])
var _race_frame_count: int = 0
var _position_count: int = 0
var _active: bool = false
var _race_schema: int = 2
var _render_context: Dictionary = {}
var _context_changed: bool = false
var _next_context_msec: int = 0

func supported() -> bool:
	return telemetry != null and telemetry.enabled and telemetry.client != null and telemetry.client.has_method("quality_supported") and telemetry.client.quality_supported() and telemetry._foreground

func _ready() -> void:
	if OS.get_name() == "Android": _device = "android_arm64" if OS.has_feature("arm64") else "android_other"
	elif OS.get_name() != "Windows" and OS.get_name() != "Linux": _device = "other"
	# Actual adapter values only. No serial, hardware identifier or device name.
	_device_model = _bounded_context(OS.get_model_name())
	_os_version = _bounded_context(OS.get_version())

static func _bounded_context(value: String) -> String:
	var result: String = ""
	var source: String = value.strip_edges()
	for index: int in range(source.length()):
		var code: int = source.unicode_at(index)
		if code >= 32 and code != 127: result += source.substr(index,1)
		if result.length() >= 80: break
	return result.strip_edges() if not result.strip_edges().is_empty() else "unknown"

func start_race(track: NativeTrack = null, ticket: Dictionary = {}, timed: bool = true) -> bool:
	if _active: finish_race("restarted")
	if not timed or not supported(): return false
	var identifier: String = telemetry.reserve_capture_id()
	if identifier.is_empty(): return false
	_race_id = identifier
	_race_scope = telemetry._scope
	_race_version = str(track.metadata.get("cloud_version","")) if track != null else ""
	if telemetry._uuid_pattern.search(_race_version) == null: _race_version = ""
	_race_ticket = str(ticket.get("ticket_id",""))
	if telemetry._uuid_pattern.search(_race_ticket) == null: _race_ticket = ""
	_race_started_msec = Time.get_ticks_msec()
	_race_schema = telemetry.client.quality_schema_version() if telemetry.client.has_method("quality_schema_version") else 2
	_render_context = RenderContext.capture(self,app) if _race_schema == 3 else {}
	_context_changed = false
	_next_context_msec = _race_started_msec+1000
	_race_frames = PackedInt64Array([0,0,0,0,0,0,0,0])
	_race_frame_count = 0
	_position_count = 0
	dropped_cell_samples = 0
	cells.clear(); segments.clear()
	_next_position_msec = 0
	_last_frame_usec = 0
	_slow_since_sample = false
	_active = true
	return true

func finish_race(outcome: String) -> bool:
	if not _active or outcome not in ["finished","abandoned","restarted"]: return false
	_active = false
	var packed_cells: Array = []
	var coordinates: Array = cells.keys()
	coordinates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for coordinate: Vector2i in coordinates:
		var counts: Vector2i = cells[coordinate]
		packed_cells.append([coordinate.x,coordinate.y,counts.x,counts.y])
	var packed_segments: Array = []
	for segment: int in range(32):
		if segments.has(segment):
			var counts: Vector2i = segments[segment]
			packed_segments.append([segment,counts.x,counts.y])
	var properties: Dictionary = {"schema_version":_race_schema,"race_id":_race_id,"outcome":outcome,"elapsed_ms":clampi(Time.get_ticks_msec()-_race_started_msec,0,3600000),"device_class":_device,"device_model":_device_model,"os_version":_os_version,"frame_buckets":Array(_race_frames),"cells":packed_cells,"segments":packed_segments,"position_samples":_position_count,"dropped_samples":dropped_cell_samples}
	if _race_schema == 3:
		properties.render_context = _render_context
		properties.render_context_changed = _context_changed or RenderContext.capture(self,app) != _render_context
	if not _race_version.is_empty(): properties.track_version_id = _race_version
	if not _race_ticket.is_empty(): properties.ticket_id = _race_ticket
	# The negotiated attempt can finish while bootstrap is temporarily unavailable.
	# Enqueue under its original account/origin, then persist/upload only after race.
	var accepted: bool = telemetry.observe_race_statistics(properties,_race_scope)
	cells.clear(); segments.clear(); _race_id = ""
	return accepted

func _process(delta: float) -> void:
	if telemetry == null: return
	var current_scope: String = telemetry._scope
	if current_scope != _scope:
		bins.clear(); _scope = current_scope
		_last_summary_msec = Time.get_ticks_msec()
		# Never assign an unfinished attempt to a different signed-in account.
		if _active and _race_scope != current_scope:
			_active = false; cells.clear(); segments.clear(); _race_id = ""
		_last_frame_usec = 0
	if not telemetry.enabled or not telemetry._foreground:
		_last_frame_usec = 0
		return
	var current_game: Node = app.get("game") if app != null else null
	# A cancelled setup can briefly expose a partial node without race properties.
	var racing: bool = is_instance_valid(current_game) and current_game.get("paused") == false and app.get("_telemetry_race_finished") != true
	var usec: int = Time.get_ticks_usec()
	var frame_ms: float = (usec-_last_frame_usec)/1000.0 if _last_frame_usec > 0 else delta*1000.0
	_last_frame_usec = usec
	var at: int = Time.get_ticks_msec()
	if _active and _race_schema == 3 and at >= _next_context_msec:
		_next_context_msec = at+1000
		_context_changed = _context_changed or RenderContext.capture(self,app) != _render_context
	if racing and _active:
		sample_frame("race",frame_ms)
		if frame_ms > 34.0: _slow_since_sample = true
		if at >= _next_position_msec and not _race_version.is_empty():
			_next_position_msec = at+1000
			var sim: VehicleSimulation = current_game.get("sim")
			var track: NativeTrack = current_game.get("native_track")
			var session: TrackSession = current_game.get("track_session")
			if sim != null and session != null and track != null and sim.state.tick > 0:
				var segment: int = clampi(int(fposmod(session.last_progress,track.route_length)/maxf(track.route_length,1.0)*32),0,31)
				sample_cell(segment,sim.state.position,_slow_since_sample)
			_slow_since_sample = false
		return
	# Menu summaries are separate from attempt diagnostics; no cell events.
	if not supported() or not telemetry._allowed: return
	sample_frame("menu",frame_ms)
	if at-_last_summary_msec >= 300000:
		flush_frames(); _last_summary_msec = at
	if not _native_checked and telemetry._loaded:
		_native_checked = true
		_collect_exits()

func sample_frame(scene: String, milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds < 0: return
	var bucket: int = 0
	while bucket < LIMITS.size() and milliseconds > LIMITS[bucket]: bucket += 1
	if scene == "race":
		if _active and _race_frame_count < MAX_FRAMES:
			_race_frames[bucket] += 1; _race_frame_count += 1
		return
	var value: PackedInt64Array = bins.get(scene,PackedInt64Array([0,0,0,0,0,0,0,0]))
	if value[bucket] < MAX_FRAMES: value[bucket] += 1
	bins[scene] = value

static func _cell_rank(value: Vector2i) -> int:
	return ((value.x*73856093) ^ (value.y*19349663)) & 0x7fffffff

static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	var left: int = _cell_rank(a); var right: int = _cell_rank(b)
	return left < right or (left == right and (a.x < b.x or (a.x == b.x and a.y < b.y)))

func sample_cell(segment: int, position: Vector2, slow: bool) -> void:
	if not _active or _race_version.is_empty() or _position_count >= MAX_POSITION_SAMPLES or segment < 0 or segment >= 32: return
	if not is_finite(position.x) or not is_finite(position.y): return
	var coordinate := Vector2i(int(floor(position.x/20.0)),int(floor(position.y/20.0)))
	if absi(coordinate.x) > 5000 or absi(coordinate.y) > 5000: return
	_position_count += 1
	var segment_counts: Vector2i = segments.get(segment,Vector2i.ZERO)
	segments[segment] = segment_counts+Vector2i(1,int(slow))
	if not cells.has(coordinate) and cells.size() >= MAX_CELLS:
		# Deterministic bottom-k spatial sample; only scan the bounded set at 1 Hz.
		var largest: Vector2i = coordinate
		for existing: Vector2i in cells:
			if _cell_less(largest,existing): largest = existing
		if largest == coordinate: dropped_cell_samples += 1; return
		dropped_cell_samples += int(cells[largest].x); cells.erase(largest)
	var counts: Vector2i = cells.get(coordinate,Vector2i.ZERO)
	cells[coordinate] = counts+Vector2i(1,int(slow))

func flush_frames() -> void:
	if telemetry == null or not telemetry._allowed: return
	for scene: String in bins.keys():
		if scene == "race": continue
		var value: PackedInt64Array = bins[scene]
		var props: Dictionary = {"device_class":_device,"scene":scene,"samples":0,"slow":value[5]+value[6]+value[7]}
		for index: int in range(8): props["b"+str(index)] = int(value[index]); props.samples += int(value[index])
		if props.samples > 0 and telemetry.observe("quality_summary",props): bins.erase(scene)

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
