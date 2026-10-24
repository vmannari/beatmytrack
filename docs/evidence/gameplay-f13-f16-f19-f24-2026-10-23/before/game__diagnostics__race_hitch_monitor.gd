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
const MAX_RENDER_ITEMS: int = 128
const MAX_RENDER_CONTEXTS: int = 64
var _render_items: Array[VisualInstance3D] = []
var _render_descriptors: Array[Dictionary] = []
var _render_seen: Dictionary = {}
var _render_context: Dictionary = {}
var _render_next_usec: int = 0
var _render_truncated: int = 0
var _bridge_items: Array[int] = []
var _bridge_seen: Dictionary = {}
var _bridge_context: Dictionary = {}

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
	_collect_render_items(game.get_node_or_null("World"))
	header.render_items = _render_descriptors
	header.render_items_truncated = _render_truncated
	header.schema = 2
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)

func _pre_draw() -> void:
	_sample_render_context(Time.get_ticks_usec())
	_sample_bridge_context()
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
	row.weathering_prepared = bool(game.get("weathering_prepared"))
	row.bridge_preparation = {"drawn": bool(game.get("bridge_prepared")), "meshes": int(game.get("bridge_preparation_meshes")), "shared_draw_ms": float(game.get("bridge_preparation_ms"))}
	row.hazard_preparation = {"drawn": bool(game.get("hazards_prepared")), "meshes": int(game.get("hazard_preparation_meshes"))}
	row.trails_prepared = bool(game.get("trails_prepared"))
	row.night_preparation = game.get("night_preparation").duplicate()
	row.effect_preparation = {"drawn":bool(game.get("effects_prepared")),"counts":game.get("effect_preparation_counts").duplicate()}
	row.previous_bridge_context = _bridge_context
	var track: NativeTrack = game.get("native_track")
	row.track_hash = track.content_hash if track != null else ""
	row.biome = str(track.metadata.get("theme", "pine")) if track != null else "pine"
	var dust: Node = game.get("sand_dust")
	row.effects = {"dust_emitters": dust.get("dust_emitters").size(), "spray_emitters": dust.get("spray_emitters").size(), "smoke_emitters": dust.get("smoke_emitters").size(), "snow_powder_emitters": dust.get("snow_powder").size(), "snow_bursts": int(dust.get("snow_burst_count")), "trail_cursor": int(game.get("trails").get("cursor"))}
	row.effects.clipping_active_mask = _emitter_mask(dust.get("clipping_emitters"))
	row.effects.mud_active_mask = _emitter_mask(dust.get("mud_emitters"))
	row.effects.dust_active_mask = _emitter_mask(dust.get("dust_emitters"))
	row.effects.smoke_active_mask = _emitter_mask(dust.get("smoke_emitters"))
	for group_name: String in ["tyre_emitters", "spray_emitters", "deck_dust_emitters", "deck_tyre_emitters", "water_drops", "snow_chips", "snow_powder", "snow_impacts", "snow_push"]:
		var group: Array = dust.get(group_name)
		row.effects[group_name + "_count"] = group.size()
		row.effects[group_name + "_active_mask"] = _emitter_mask(group)
	row.motion = {"jump_height": simulation.state.jump_height, "roll_ticks": simulation.state.roll_ticks, "heading": simulation.state.heading}
	row.previous_render_context = _render_context
	var storm: Node = game.get("storm_weather")
	if storm != null: row.effects.storm_strikes = storm.get("strikes")
	row.engine_monitors = {"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_tick_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "pipeline_canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS), "pipeline_mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH), "pipeline_surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), "pipeline_draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), "pipeline_specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
	observe(row, frame_us >= THRESHOLD_US and _last_usec > 0 and not blocked and not _was_blocked)
	_was_blocked = blocked
	_last_usec = now
	if _revision > _saved_revision and now >= _next_write_usec: flush_async()
	observed_frames += 1
	observer_total_us += Time.get_ticks_usec() - started

static func _emitter_mask(emitters: Array) -> int:
	var bits: int = 0
	for index: int in range(mini(32, emitters.size())):
		if emitters[index].emitting: bits |= 1 << index
	return bits

func _collect_render_items(node: Node) -> void:
	if node == null: return
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		if _render_items.size() >= MAX_RENDER_ITEMS:
			_render_truncated += 1
		else:
			var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node.multimesh != null else null
			var materials: Array[String] = []
			var shader_rids: Array[int] = []
			var shader_sources: Array[String] = []
			if mesh != null:
				for index: int in range(mini(4, mesh.get_surface_count())):
					var material: Material = node.material_override if node.material_override != null else node.get_active_material(index) if node is MeshInstance3D else mesh.surface_get_material(index)
					if material == null: continue
					var key: String = str(material.get_class())
					if material is ShaderMaterial and material.shader != null:
						key += ":" + material.shader.resource_path + ":" + material.shader.code.sha256_text()
						var shader_rid: int = material.shader.get_rid().get_id()
						if shader_rid not in shader_rids: shader_rids.append(shader_rid)
						var source: String = material.shader.resource_path
						var dynamic: Variant = material.get_meta("surface_dynamic_material") if material.has_meta("surface_dynamic_material") else null
						if source.is_empty() and dynamic is ShaderMaterial and dynamic.shader != null: source = dynamic.shader.resource_path
						if not source.is_empty() and source not in shader_sources: shader_sources.append(source)
					elif material is BaseMaterial3D:
						key += ":shade%d/diff%d/spec%d/alpha%d/cull%d/tex%d/normal%d/emission%d/coat%d/vertex%d" % [material.shading_mode, material.diffuse_mode, material.specular_mode, material.transparency, material.cull_mode, int(material.albedo_texture != null), int(material.normal_enabled), int(material.emission_enabled), int(material.clearcoat_enabled), int(material.vertex_color_use_as_albedo)]
					if key not in materials: materials.append(key)
			_render_descriptors.append({"id": _render_items.size(), "name": str(node.name).left(80), "class": node.get_class(), "materials": materials, "shader_rids":shader_rids, "shader_sources":shader_sources})
			_render_items.append(node)
			if node.is_in_group("race_bridge_rendering"): _bridge_items.append(_render_items.size() - 1)
	for child: Node in node.get_children(): _collect_render_items(child)

func _sample_bridge_context() -> void:
	if _bridge_items.is_empty() or not is_instance_valid(game): return
	var camera: Camera3D = game.get("camera")
	if camera == null: return
	var started: int = Time.get_ticks_usec()
	var visible: Array[int] = []
	var entered: Array[int] = []
	var planes: Array[Plane] = camera.get_frustum()
	for index: int in _bridge_items:
		if not is_instance_valid(_render_items[index]): continue
		var node: VisualInstance3D = _render_items[index]
		if not node.is_visible_in_tree(): continue
		var box: AABB = node.global_transform * node.get_aabb()
		var outside: bool = false
		for plane: Plane in planes:
			if plane.distance_to(box.get_center()) > (box.size * 0.5).dot(plane.normal.abs()):
				outside = true
				break
		if outside: continue
		visible.append(index)
		if not _bridge_seen.has(index):
			_bridge_seen[index] = true
			entered.append(index)
	# Actual geometry bounds, ignoring temporary preparation cull margins.
	# Every pre-draw sample accompanies the following measured render interval;
	# candidates still do not prove a GPU colour/shadow draw or compilation.
	_bridge_context = {"sample_wall_ms": (started - _started_usec) / 1000.0, "candidate_ids": visible, "first_candidate_ids": entered, "sampling_ms": (Time.get_ticks_usec() - started) / 1000.0}

func _sample_render_context(now: int) -> void:
	if now < _render_next_usec or not is_instance_valid(game): return
	_render_next_usec = now + 200000
	var camera: Camera3D = game.get("camera")
	if camera == null: return
	var started: int = Time.get_ticks_usec()
	var visible: Array[int] = []
	var entered: Array[int] = []
	var planes: Array[Plane] = camera.get_frustum()
	for index: int in range(_render_items.size()):
		if not is_instance_valid(_render_items[index]): continue
		var node: VisualInstance3D = _render_items[index]
		if not node.is_visible_in_tree(): continue
		var box: AABB = node.global_transform * node.get_aabb()
		var outside: bool = false
		for plane: Plane in planes:
			if plane.distance_to(box.get_center()) > (box.size * 0.5).dot(plane.normal.abs()):
				outside = true
				break
		if outside: continue
		visible.append(index)
		if not _render_seen.has(index):
			_render_seen[index] = true
			entered.append(index)
	var viewport: Viewport = game.get_viewport()
	# Candidates, not an assertion that these objects/shadow passes reached the GPU.
	_render_context = {"sample_wall_ms": (now - _started_usec) / 1000.0, "candidate_ids": visible, "first_candidate_ids": entered, "sampling_ms": (Time.get_ticks_usec() - started) / 1000.0, "width": viewport.get_visible_rect().size.x, "height": viewport.get_visible_rect().size.y, "msaa": viewport.msaa_3d, "render_scale": viewport.scaling_3d_scale, "projection": camera.projection, "fov": camera.fov, "size": camera.size}

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
	var captured: Array[Dictionary] = events.duplicate(true)
	var contexts: Array[Dictionary] = []
	var context_ids: Dictionary = {}
	var dropped_contexts: int = 0
	for event: Dictionary in captured:
		var rows: Array = [event.frame] + event.before + event.after
		for row: Dictionary in rows:
			if not row.get("previous_render_context") is Dictionary: continue
			var context: Dictionary = row.previous_render_context
			row.erase("previous_render_context")
			var key: String = str(context.get("sample_wall_ms", -1))
			if context.is_empty():
				row.render_context_id = -1
				continue
			if not context_ids.has(key) and contexts.size() < MAX_RENDER_CONTEXTS:
				context_ids[key] = contexts.size()
				contexts.append(context)
			row.render_context_id = int(context_ids.get(key, -1))
			if row.render_context_id < 0: dropped_contexts += 1
	return {"header": header.duplicate(true), "events": captured, "dropped_events": dropped_events, "render_contexts": contexts, "dropped_render_contexts": dropped_contexts}

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
