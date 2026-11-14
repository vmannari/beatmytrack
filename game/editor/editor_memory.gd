extends RefCounted
## One editor retention allowance, with explicit headroom for active replacements.
## Estimates describe owned streams, not RSS, Android PSS or driver allocation.
const RETAINED_BUDGET: int = 64 * 1024 * 1024
const GARAGE_BUDGET: int = 96 * 1024 * 1024
const PRESSURE_HISTORY: int = 2 * 1024 * 1024
const HISTORY = preload("res://editor/editor_history.gd")
const PROVIDERS: Dictionary = {
	"roads":"res://editor/road_preparation.gd",
	"reads":"res://persistence/document_read_cache.gd",
	"encoding":"res://persistence/document_encoding.gd",
	"worlds":"res://track/prepared_world_cache.gd",
	"gates":"res://race/checkpoint_layout_cache.gd",
	"visual":"res://track/native_track_visual.gd",
	"theme":"res://track/track_theme.gd",
	"effects":"res://vehicle/effect_render_preparation.gd",
	"contacts":"res://vehicle/visible_contact_audio.gd",
	"front":"res://vehicle/compact_detail.gd",
	"icons":"res://ui/garage_paint_icons.gd",
	"thumbnails":"res://editor/object_thumbnail.gd",
	"props":"res://track/creator_prop_visual.gd",
	"snow":"res://track/winter_road_snow_sources.gd",
	"support":"res://track/road_support_cache.gd",
	"boundary":"res://editor/roadside_boundary.gd",
	"work":"res://editor/work_job.gd"
}
var next_sample: int = 0
var pressure_requested: bool = false
var trims: int = 0
var telemetry: Dictionary = {}

static func _providers() -> Dictionary:
	# An absent script cannot own a live static cache. Inspect existing owners
	# without parsing their procedural/render graphs merely to count or trim.
	# Resolve afresh so a provider loaded later participates on the next sample;
	# retain these references only for this synchronous main-thread operation.
	var result: Dictionary = {}
	for key: String in PROVIDERS:
		var path: String = PROVIDERS[key]
		result[key] = load(path) if ResourceLoader.has_cached(path) else null
	return result

static func _workers_idle(providers: Dictionary) -> bool:
	return providers.work == null or providers.work.pending.is_empty()

func tick(app: Node) -> void:
	if Time.get_ticks_msec() < next_sample: return
	if is_instance_valid(app.canvas) and app.canvas.active_pointer != -99 and not pressure_requested: return
	next_sample = Time.get_ticks_msec()+1000
	if app.editor_preview_thread != null and not pressure_requested: return
	telemetry = retained(app)
	if not pressure_requested and telemetry.retained_bytes <= RETAINED_BUDGET and telemetry.optional_garage_bytes <= GARAGE_BUDGET: return
	var force: bool = pressure_requested
	var retry: bool = false
	var caches: Dictionary = _providers()
	# Numeric layouts are optional across track owners. Active tracks retain
	# their own copies; trimming never changes an installed race or joins a job.
	if caches.gates != null: caches.gates.trim_to(0 if force else maxi(0,caches.gates.bytes_used()-(telemetry.retained_bytes-RETAINED_BUDGET)))
	if app.has_method("_trim_hidden_garage") and (force or telemetry.optional_garage_bytes > GARAGE_BUDGET): app._trim_hidden_garage()
	# The completed Winter world and its small static radiance resource form
	# one useful presentation. Recreating that sky on re-entry repeats native
	# preparation; ordinary trims prefer independent road work below instead.
	var winter_world: bool = caches.worlds != null and caches.worlds.entries.any(func(entry: Dictionary) -> bool: return entry.key.size()>4 and entry.key[4]=="winter")
	if caches.theme != null and (force or not winter_world): caches.theme.trim_winter_sky()
	if force:
		if caches.effects != null: caches.effects.trim_cache(app)
		if caches.contacts != null: caches.contacts.trim_cache()
		if caches.front != null: caches.front.trim_front_cache()
		if caches.icons != null: caches.icons.images.clear()
	if is_instance_valid(app.editor_world): app.editor_world.trim_cache()
	if caches.thumbnails != null: caches.thumbnails.trim_cache()
	if caches.reads != null: retry = not caches.reads.trim_cache() or retry
	if caches.encoding != null: retry = not caches.encoding.trim_cache() or retry
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	# These dictionaries belong to the preview worker while it runs. Never join
	# a geometry thread in an input/memory-notification callback to trim them.
	if app.editor_preview_thread == null:
		app.editor_compiled_cache.clear()
		app.editor_raster_cache.clear(); app.editor_raster_cache["enabled"] = true
	else: retry = true
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if not force and caches.worlds != null and not caches.worlds.entries.is_empty():
		# Keep completed scenery and its initialized effect proxies before cheap
		# CPU work and independent road GPU entries. Those road resources have
		# verified artifact fallbacks; lost proxies require fresh covered draws.
		# Do not compete with any running preparation worker.
		if _workers_idle(caches) and caches.roads != null:
			var roads: Dictionary = caches.roads.residency()
			var excess: int = retained(app).retained_bytes-RETAINED_BUDGET
			caches.roads.trim_cpu_to(maxi(0,int(roads.packets)+int(roads.sections)-excess))
			if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
			if caches.visual != null: caches.visual.trim_private_road_cache(retained(app).retained_bytes-RETAINED_BUDGET)
			if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	# Retained contact geometry is reproducible from the live car. Prefer it
	# to completed native effect preparation and an entire scenery snapshot.
	if not force and caches.contacts != null:
		caches.contacts.trim_cache(maxi(0,caches.contacts.bytes_used()-(retained(app).retained_bytes-RETAINED_BUDGET)))
		if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if not force and caches.worlds != null and not caches.worlds.entries.is_empty():
		# If private road retention cannot meet the unchanged allowance, evict
		# only the remaining excess from idle proxies before dropping the world.
		# Active effects and in-flight preparation nodes retain their owners.
		var excess: int = retained(app).retained_bytes-RETAINED_BUDGET
		if caches.effects != null: caches.effects.trim_to(app,maxi(0,caches.effects.cache_bytes(app)-excess))
		if retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if caches.worlds != null: caches.worlds.trim_cache(0 if force else maxi(0,caches.worlds.bytes_used()-(retained(app).retained_bytes-RETAINED_BUDGET)))
	if force and caches.snow != null: caches.snow.trim_cache()
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if caches.props != null: retry = not caches.props.trim_cache() or retry
	if is_instance_valid(app.editor_world): app.editor_world.trim_prop_cache()
	if not force and retained(app).retained_bytes <= RETAINED_BUDGET: _finished(app,retry,force); return
	if caches.support != null: caches.support.trim()
	if caches.visual != null: caches.visual.trim_editor_cache()
	if force:
		app.editor_session.primed = {}
		HISTORY.trim(app.history,app.redo_history,PRESSURE_HISTORY)
		if is_instance_valid(app.canvas): app.canvas.trim_cache()
	# Roadside runs can also be prepared by a population worker. Defer this
	# main-thread-owned cache trim until all optional jobs have retired.
	if _workers_idle(caches):
		if caches.boundary != null:
			caches.boundary._cache.clear(); caches.boundary.cache_bytes = 0
	elif force: retry = true
	_finished(app,retry,force)

func _finished(app: Node, retry: bool, force: bool) -> void:
	trims += 1
	pressure_requested = retry and force
	telemetry = retained(app)

static func retained(app: Node) -> Dictionary:
	var caches: Dictionary = _providers()
	var roads: Dictionary = caches.roads.residency() if caches.roads != null else {"packets":0,"sections":0,"gpu":0}
	var shared_roads: int = mini(int(roads.gpu),caches.worlds.shared_road_bytes(caches.visual._road_mesh_cache)) if caches.worlds != null and caches.visual != null else 0
	var history: int = HISTORY.bytes_used([app.history,app.redo_history,app.editor_gesture_history,app.editor_gesture_redo,[app.editor_session.primed] if not app.editor_session.primed.is_empty() else []])
	var compiled: int = 0
	if app.editor_preview_thread == null:
		for entry: Dictionary in app.editor_compiled_cache: compiled += int(entry.bytes)
	else: compiled = app.EDITOR_COMPILED_BUDGET
	var raster: int = int(app.editor_raster_cache.get("prepared_bytes",0))+int(app.editor_raster_cache.get("auxiliary_bytes",0)) if app.editor_preview_thread == null else 24*1024*1024
	var scenes: int = app.editor_world.visual_cache_bytes if is_instance_valid(app.editor_world) else 0
	var props: int = caches.props.cache_bytes if caches.props != null else 0
	var other: Dictionary = {"read_bytes":caches.reads.bytes if caches.reads != null else 0,"encoding_bytes":caches.encoding.bytes if caches.encoding != null else 0,
		"race_world_bytes":maxi(0,caches.worlds.bytes_used()-shared_roads) if caches.worlds != null else 0,
		"checkpoint_layout_bytes":caches.gates.bytes_used() if caches.gates != null else 0,
		"road_support_bytes":caches.support.bytes_used() if caches.support != null else 0,
		"effect_preparation_bytes":caches.effects.cache_bytes(app) if caches.effects != null else 0,"front_fitting_bytes":caches.front.front_cache_bytes if caches.front != null else 0,
		"visible_contact_bytes":caches.contacts.bytes_used() if caches.contacts != null else 0,
		"winter_sky_bytes":caches.theme.WINTER_SKY_ESTIMATED_BYTES if caches.theme != null and caches.theme.winter_reflection_sky != null else 0,
		"winter_source_bytes":caches.snow.cache_bytes if caches.snow != null else 0,
		"garage_option_gpu_bytes":_option_texture_bytes(caches.icons),
		"thumbnail_bytes":caches.thumbnails.cache_bytes if caches.thumbnails != null else 0,"boundary_bytes":caches.boundary.cache_bytes if caches.boundary != null else 0,
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

static func _option_texture_bytes(icons: Script) -> int:
	var total: int = 0
	var seen: Dictionary = {}
	if icons == null: return 0
	for cache: Dictionary in [icons.images]:
		for texture: Texture2D in cache.values():
			if texture == null or seen.has(texture.get_instance_id()): continue
			seen[texture.get_instance_id()] = true
			total += texture.get_width()*texture.get_height()*4
	return total
