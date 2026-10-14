extends Node
## Local presentation diagnostics, including guests/practice. No telemetry/upload.
## Timings are observations only; never change canonical ticks, inputs or pause.
const FIELDS: Array[String] = ["physics_total", "process_total", "sim", "rules", "ai", "present", "particles", "trails", "telemetry", "weather", "car", "props", "camera", "hud", "audio", "contact", "music", "water", "history", "weathering", "condition"]
const THRESHOLD_US: int = 100000
const HISTORY_FRAMES: int = 64
const AFTER_FRAMES: int = 16
const MAX_EVENTS: int = 8
const MAX_FILES: int = 8
const MAX_FILE_BYTES: int = 2 * 1024 * 1024
var game: Node
var directory: String = "user://diagnostics/race_hitches"
var persist_enabled: bool = true
var console_enabled: bool = true
var events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var latest: Dictionary = {}
var header: Dictionary = {}
var log_path: String = ""
var dropped_events: int = 0
var observer_total_us: int = 0
var observed_frames: int = 0
var _previous: PackedInt64Array = PackedInt64Array()
var _last_usec: int = 0
var _started_usec: int = 0
var _idle_start_usec: int = 0
var _draw_start_usec: int = 0
var _draw_us: int = 0
var _draw_count: int = 0
var _last_draw_count: int = 0
var _foreground: bool = true
var _was_blocked: bool = false
var _thread: Thread
var _revision: int = 0
var _saved_revision: int = 0
var _writing_revision: int = 0
var _next_write_usec: int = 0
var _recovery_previous: int = 0
var _cloud_previous: int = 0

class IdleStart extends Node:
	var monitor: Node
	func _process(_delta: float) -> void:
		monitor._idle_start_usec = Time.get_ticks_usec()

func _ready() -> void:
	process_priority = 1000000
	var anchor := IdleStart.new()
	anchor.monitor = self
	anchor.process_priority = -1000000
	add_child(anchor)
	game.profile_enabled = true
	_previous.resize(FIELDS.size())
	_previous.fill(0)
	_started_usec = Time.get_ticks_usec()
	# Filename is local process context, not a player/device identity.
	var token: String = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id(), get_instance_id()]
	log_path = directory.path_join("race-" + token + ".json")
	var track: NativeTrack = game.get("native_track")
	header = {"schema": 1, "engine": Engine.get_version_info().string, "os": OS.get_name(), "os_version": OS.get_version(), "model": OS.get_model_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "debug_build": OS.is_debug_build(), "track_id": track.identity if track != null else "playground", "track_hash": track.content_hash if track != null else "", "biome": str(track.metadata.get("theme", "pine")) if track != null else "pine", "car": str(game.get("vehicle_id")), "practice": bool(game.get("editor_test")) or bool(game.get("attempt_practice")), "physics": VehicleSimulation.PHYSICS_VERSION, "rules": RaceRules.KEY, "track_kit": NativeTrackVisual.VERSION, "threshold_ms": THRESHOLD_US / 1000, "history_frames": HISTORY_FRAMES, "stage_note": "Nested timings overlap; engine monitors may be delayed/debug-only; draw_boundary_ms is wall time between render signals, not GPU time. Previous draw and current callbacks share one interval."}
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)

func _pre_draw() -> void:
	_draw_start_usec = Time.get_ticks_usec()

func _post_draw() -> void:
	if _draw_start_usec > 0: _draw_us = Time.get_ticks_usec() - _draw_start_usec
	_draw_count += 1

func _process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_reap_writer()
	if not is_instance_valid(game) or game.get("sim") == null: return
	var now: int = Time.get_ticks_usec()
	var frame_us: int = now - _last_usec if _last_usec > 0 else 0
	var blocked: bool = not _foreground or bool(game.get("paused")) or game.get("finish_sim") != null
	var sections: Dictionary = {}
	for index: int in range(FIELDS.size()):
		var value: int = int(game.get("profile_" + FIELDS[index] + "_us"))
		# External profilers may reset their counters; this observer never does.
		sections[FIELDS[index]] = max(0, value - _previous[index]) / 1000.0 if value >= _previous[index] else value / 1000.0
		_previous[index] = value
	var simulation: VehicleSimulation = game.get("sim")
	var condition: VehicleWeathering = game.get("car_weathering")
	var row: Dictionary = {"wall_ms": (now - _started_usec) / 1000.0, "frame_ms": frame_us / 1000.0, "tick": simulation.state.tick, "race_ms": simulation.state.tick * 1000.0 / VehicleSimulation.TICK_RATE, "countdown_ticks": int(game.get("countdown_ticks")), "callbacks_ms": (now - _idle_start_usec) / 1000.0 if _idle_start_usec > 0 else 0.0, "between_callbacks_ms": max(0, _idle_start_usec - _last_usec) / 1000.0 if _last_usec > 0 else 0.0, "stages_ms": sections, "draw_boundary_ms": _draw_us / 1000.0 if _draw_count != _last_draw_count else -1.0, "blocked": blocked, "speed_mps": simulation.state.velocity.length(), "route_index": simulation.state.route_index, "elevated": simulation.state.track_elevated, "weathering_installed": condition.installed, "condition_save_count": int(game.get("condition_save_count")), "rewind_entries": game.get("rewind_history").entries.size(), "proof_frames": game.get("online_frames").size()}
	_last_draw_count = _draw_count
	row.background = _background_context()
	var track: NativeTrack = game.get("native_track")
	row.track_hash = track.content_hash if track != null else ""
	row.biome = str(track.metadata.get("theme", "pine")) if track != null else "pine"
	var dust: Node = game.get("sand_dust")
	row.effects = {"dust_emitters": dust.get("dust_emitters").size(), "spray_emitters": dust.get("spray_emitters").size(), "smoke_emitters": dust.get("smoke_emitters").size(), "snow_powder_emitters": dust.get("snow_powder").size(), "snow_bursts": int(dust.get("snow_burst_count")), "trail_cursor": int(game.get("trails").get("cursor"))}
	var storm: Node = game.get("storm_weather")
	if storm != null: row.effects.storm_strikes = storm.get("strikes")
	row.engine_monitors = {"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_tick_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "pipeline_canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS), "pipeline_mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH), "pipeline_surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), "pipeline_draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), "pipeline_specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
	observe(row, frame_us >= THRESHOLD_US and _last_usec > 0 and not blocked and not _was_blocked)
	_was_blocked = blocked
	_last_usec = now
	if _revision > _saved_revision and now >= _next_write_usec: flush_async()
	observed_frames += 1
	observer_total_us += Time.get_ticks_usec() - started

func _background_context() -> Dictionary:
	var parent: Node = game.get_parent()
	if parent == null or parent.get_script() == null or parent.get_script().resource_path != "res://core/app.gd": return {}
	var result: Dictionary = {"cloud_starting": bool(parent.get("cloud_starting")), "editor_worker": parent.get("editor_preview_thread") != null}
	var online: Node = parent.get("online")
	if online != null and online.get("client") != null:
		var recovery: Node = online.get("client").get("resume_recovery")
		if recovery != null:
			var total: int = recovery.get("profile_callback_us")
			result.recovery_callback_ms = max(0, total - _recovery_previous) / 1000.0
			_recovery_previous = total
			result.recovery_busy = bool(recovery.get("busy"))
	var telemetry: Node = parent.get("product_telemetry")
	if telemetry != null:
		result.telemetry_writer = telemetry.get("_thread") != null
		result.telemetry_transport_allowed = bool(telemetry.get("_allowed"))
	var cloud: Node = parent.get("cloud")
	if cloud != null:
		var total: int = cloud.get("profile_local_io_us")
		result.cloud_local_io_ms = max(0, total - _cloud_previous) / 1000.0
		_cloud_previous = total
		result.cloud_flushing = bool(cloud.get("flushing"))
		result.cloud_refreshing = bool(cloud.get("refreshing"))
	return result

func observe(row: Dictionary, hitch: bool) -> void:
	latest = row
	for event: Dictionary in events:
		if event.after.size() < AFTER_FRAMES:
			event.after.append(row)
			_revision += 1
	if hitch:
		if events.size() >= MAX_EVENTS:
			# Keep the worst events if a device runs slowly for a whole race.
			var smallest: int = 0
			for index: int in range(1, events.size()):
				if events[index].frame.frame_ms < events[smallest].frame.frame_ms: smallest = index
			dropped_events += 1
			_revision += 1
			if row.frame_ms > events[smallest].frame.frame_ms: events.remove_at(smallest)
			else: hitch = false
		if hitch:
			events.append({"frame": row, "before": history.duplicate(), "after": []})
			_revision += 1
			if console_enabled: print("RACE_HITCH frame_ms=%.3f tick=%d countdown=%d local_log=%s" % [row.frame_ms, row.tick, row.countdown_ticks, log_path])
	history.append(row)
	if history.size() > HISTORY_FRAMES: history.pop_front()

func snapshot() -> Dictionary:
	return {"header": header.duplicate(true), "events": events.duplicate(true), "dropped_events": dropped_events}

func flush_async() -> void:
	if not persist_enabled or _thread != null or _revision <= _saved_revision: return
	_writing_revision = _revision
	# Detached immutable data only; worker never accesses scene objects.
	var payload: Dictionary = snapshot()
	_thread = Thread.new()
	var error: Error = _thread.start(_write_snapshot.bind(log_path, payload), Thread.PRIORITY_LOW)
	if error != OK:
		_thread = null
		_next_write_usec = Time.get_ticks_usec() + 5000000
		push_warning("Race hitch log worker failed: " + error_string(error))

func _reap_writer() -> void:
	if _thread == null or _thread.is_alive(): return
	var result: Error = _thread.wait_to_finish()
	_thread = null
	if result == OK: _saved_revision = _writing_revision
	else: push_warning("Race hitch log write failed: " + error_string(result))
	_next_write_usec = Time.get_ticks_usec() + (1000000 if result == OK else 5000000)

static func _write_snapshot(path: String, payload: Dictionary) -> Error:
	var folder: String = path.get_base_dir()
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK: return error
	var content: String = JSON.stringify(payload)
	if content.to_utf8_buffer().size() > MAX_FILE_BYTES: return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK: return error
	# Only our fixed-name diagnostic files in this one directory are eligible.
	var files: Array[String] = []
	for filename: String in DirAccess.get_files_at(folder):
		if filename.begins_with("race-") and filename.ends_with(".json"): files.append(filename)
	files.sort()
	var excess: int = maxi(0, files.size() - MAX_FILES)
	for oldest: String in files:
		if excess <= 0: break
		if folder.path_join(oldest) == path: continue
		if DirAccess.remove_absolute(folder.path_join(oldest)) == OK: excess -= 1
	return OK

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_foreground = false
		_last_usec = 0
		history.clear()
		flush_async()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_foreground = true
		_last_usec = 0
		history.clear()

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_post_draw)
	# Join only at teardown; never wait for a live worker during a racing frame.
	if _thread != null:
		var result: Error = _thread.wait_to_finish()
		if result == OK: _saved_revision = _writing_revision
		_thread = null
	if persist_enabled and _revision > _saved_revision:
		var error: Error = _write_snapshot(log_path, snapshot())
		if error != OK: push_warning("Final race hitch log write failed: " + error_string(error))
