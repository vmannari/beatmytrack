extends RefCounted
## One editor retention allowance, with explicit headroom for active replacements.
## Estimates describe owned streams, not RSS, Android PSS or driver allocation.
const RETAINED_BUDGET: int = 64 * 1024 * 1024
const GARAGE_BUDGET: int = 96 * 1024 * 1024
const PRESSURE_HISTORY: int = 2 * 1024 * 1024
const ROADS = preload("res://editor/road_preparation.gd")
const HISTORY = preload("res://editor/editor_history.gd")
const READS = preload("res://persistence/document_read_cache.gd")
const ENCODING = preload("res://persistence/document_encoding.gd")
const WORLDS = preload("res://track/prepared_world_cache.gd")
var next_sample: int = 0
var pressure_requested: bool = false
var trims: int = 0
var telemetry: Dictionary = {}

func tick(app: Node) -> void:
	if Time.get_ticks_msec() < next_sample: return
	if is_instance_valid(app.canvas) and app.canvas.active_pointer != -99 and not pressure_requested: return
	next_sample = Time.get_ticks_msec()+1000
	if app.editor_preview_thread != null and not pressure_requested: return
	telemetry = retained(app)
	if not pressure_requested and telemetry.retained_bytes <= RETAINED_BUDGET and telemetry.optional_garage_bytes <= GARAGE_BUDGET: return
	var force: bool = pressure_requested
	var retry: bool = false
	if app.has_method("_trim_hidden_garage") and (force or telemetry.optional_garage_bytes > GARAGE_BUDGET): app._trim_hidden_garage()
	# The completed Winter world and its small static radiance resource form
	# one useful presentation. Recreating that sky on re-entry repeats native
	# preparation; ordinary trims prefer independent road work below instead.
	var winter_world: bool = WORLDS.entries.any(func(entry: Dictionary) -> bool: return entry.key.size()>4 and entry.key[4]=="winter")
	if force or not winter_world: TrackTheme.trim_winter_sky()
	if force:
		preload("res://vehicle/effect_render_preparation.gd").trim_cache(app)
		CompactDetail.trim_front_cache()
		preload("res://ui/garage_paint_icons.gd").images.clear()
		CompactKitThumbnail.images.clear()
	if is_instance_valid(app.editor_world): app.editor_world.trim_cache()
	ObjectThumbnail.trim_cache()
	retry = not READS.trim_cache() or retry
	retry = not ENCODING.trim_cache() or retry
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	# These dictionaries belong to the preview worker while it runs. Never join
	# a geometry thread in an input/memory-notification callback to trim them.
	if app.editor_preview_thread == null:
		app.editor_compiled_cache.clear()
		app.editor_raster_cache.clear(); app.editor_raster_cache["enabled"] = true
	else: retry = true
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if not force and not WORLDS.entries.is_empty():
		# Prefer the completed world to a few idle preparation proxies. Evicting
		# these never affects live effects; they are redrawn on the next entry.
		var excess: int = retained(app).retained_bytes-RETAINED_BUDGET
		var effects = preload("res://vehicle/effect_render_preparation.gd")
		effects.trim_to(app,maxi(0,effects.cache_bytes(app)-excess))
		if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
		# Preserve completed scenery before cheap CPU work and independent road
		# GPU entries. Do not compete with any running preparation worker.
		if preload("res://editor/work_job.gd").pending.is_empty():
			var roads: Dictionary = ROADS.residency()
			excess = retained(app).retained_bytes-RETAINED_BUDGET
			ROADS.trim_cpu_to(maxi(0,int(roads.packets)+int(roads.sections)-excess))
			if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
			NativeTrackVisual.trim_private_road_cache(retained(app).retained_bytes-RETAINED_BUDGET)
			if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	WORLDS.trim_cache(0 if force else maxi(0,WORLDS.bytes_used()-(retained(app).retained_bytes-RETAINED_BUDGET)))
	if force: preload("res://track/winter_road_snow_sources.gd").trim_cache()
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	retry = not CreatorPropVisual.trim_cache() or retry
	if is_instance_valid(app.editor_world): app.editor_world.trim_prop_cache()
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	preload("res://track/road_support_cache.gd").trim()
	NativeTrackVisual.trim_editor_cache()
	if force:
		app.editor_session.primed = {}
		HISTORY.trim(app.history,app.redo_history,PRESSURE_HISTORY)
		if is_instance_valid(app.canvas): app.canvas.trim_cache()
	# Roadside runs can also be prepared by a population worker. Defer this
	# main-thread-owned cache trim until all optional jobs have retired.
	if preload("res://editor/work_job.gd").pending.is_empty():
		RoadsideBoundary._cache.clear(); RoadsideBoundary.cache_bytes = 0
	elif force: retry = true
	_finished(app,retry,force)

func _finished(app: Node, retry: bool, force: bool) -> void:
	trims += 1
	pressure_requested = retry and force
	telemetry = retained(app)

static func retained(app: Node) -> Dictionary:
	var roads: Dictionary = ROADS.residency()
	var shared_roads: int = mini(int(roads.gpu),WORLDS.shared_road_bytes(NativeTrackVisual._road_mesh_cache))
	var history: int = HISTORY.bytes_used([app.history,app.redo_history,app.editor_gesture_history,app.editor_gesture_redo,[app.editor_session.primed] if not app.editor_session.primed.is_empty() else []])
	var compiled: int = 0
	if app.editor_preview_thread == null:
		for entry: Dictionary in app.editor_compiled_cache: compiled += int(entry.bytes)
	else: compiled = app.EDITOR_COMPILED_BUDGET
	var raster: int = int(app.editor_raster_cache.get("prepared_bytes",0))+int(app.editor_raster_cache.get("auxiliary_bytes",0)) if app.editor_preview_thread == null else 24*1024*1024
	var scenes: int = app.editor_world.visual_cache_bytes if is_instance_valid(app.editor_world) else 0
	var props: int = CreatorPropVisual.cache_bytes
	var other: Dictionary = {"read_bytes":READS.bytes,"encoding_bytes":ENCODING.bytes,"race_world_bytes":maxi(0,WORLDS.bytes_used()-shared_roads),
		"road_support_bytes":preload("res://track/road_support_cache.gd").bytes_used(),
		"effect_preparation_bytes":preload("res://vehicle/effect_render_preparation.gd").cache_bytes(app),"front_fitting_bytes":CompactDetail.front_cache_bytes,
		"winter_sky_bytes":TrackTheme.WINTER_SKY_ESTIMATED_BYTES if TrackTheme.winter_reflection_sky != null else 0,
		"winter_source_bytes":preload("res://track/winter_road_snow_sources.gd").cache_bytes,
		"garage_option_gpu_bytes":_option_texture_bytes(),
		"thumbnail_bytes":ObjectThumbnail.cache_bytes,"boundary_bytes":RoadsideBoundary.cache_bytes,
		"canvas_bytes":app.canvas.cache_bytes() if is_instance_valid(app.canvas) else 0,
		"batch_model_bytes":app.editor_world.prop_cache_bytes() if is_instance_valid(app.editor_world) else 0}
	# Texture residency is an estimate of decoded GPU surfaces, independent of
	# compressed PNG sizes. Keep the categories visible in pressure telemetry.
	var garage: Dictionary = app._garage_residency() if app.has_method("_garage_residency") else {}
	var garage_bytes: int = 0
	for category: String in garage: garage_bytes += int(garage[category])
	var other_bytes: int = 0
	for value: int in other.values(): other_bytes += value
	return {"history_bytes":history,"road_packet_bytes":roads.packets,"road_section_bytes":roads.sections,"road_gpu_bytes":roads.gpu,"shared_road_bytes":shared_roads,
		"compiled_bytes":compiled,"raster_bytes":raster,"detached_scene_bytes":scenes,"prop_bytes":props,
		"other":other,"garage":garage,"optional_garage_bytes":garage_bytes,"retained_bytes":history+roads.packets+roads.sections+roads.gpu+compiled+raster+scenes+props+other_bytes}

static func _option_texture_bytes() -> int:
	var total: int = 0
	var seen: Dictionary = {}
	for cache: Dictionary in [preload("res://ui/garage_paint_icons.gd").images,CompactKitThumbnail.images]:
		for texture: Texture2D in cache.values():
			if texture == null or seen.has(texture.get_instance_id()): continue
			seen[texture.get_instance_id()] = true
			total += texture.get_width()*texture.get_height()*4
	return total
