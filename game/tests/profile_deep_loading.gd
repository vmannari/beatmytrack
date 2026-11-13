extends SceneTree
## Diagnostic-only observer. No game-class references that prewarm feature graphs.
class TraceSink extends Node:
	var events: Array = []
	var frames: Array = []
	var costs: Dictionary = {}
	var phase: String = "startup"
	var frame_begin: int = 0
	var render_begin: int = 0
	var overflow: int = 0
	func mark(label: String, data: Dictionary = {}) -> void:
		if events.size() >= 12000: overflow += 1; return
		events.append({"us":Time.get_ticks_usec(),"phase":phase,"label":label,"data":data})
	func cost(label: String, usec: int) -> void:
		var key: String = phase+":"+label
		if not costs.has(key): costs[key] = {"calls":0,"total_us":0,"max_us":0}
		costs[key].calls += 1; costs[key].total_us += usec
		costs[key].max_us = maxi(costs[key].max_us,usec)
	func begin_frame() -> void:
		frame_begin = Time.get_ticks_usec()
	func before_render() -> void:
		render_begin = Time.get_ticks_usec()
	func after_render() -> void:
		if frames.size() >= 20000: overflow += 1; return
		var ended: int = Time.get_ticks_usec()
		frames.append({"begin_us":frame_begin,"render_begin_us":render_begin,"end_us":ended,"phase":phase})

var trace: TraceSink
var app: Node
var checks: int = 0
var failures: int = 0
var rows: Array = []
var mode: String = "rivalry"
var theme: String = "pine"

func instrument_contact() -> void:
	# Timers in the loaded diagnostic resource preserve the file-based asset
	# fingerprints and the original outline/cache algorithm and return paths.
	var script: GDScript = load("res://vehicle/visible_contact_audio.gd")
	var source: String = script.source_code.replace("\r\n","\n")
	var start: int = source.find("func configure(car:")
	var end: int = source.find("\nfunc reset()",start)
	check(start >= 0 and end > start,"outline instrumentation function anchors")
	if start < 0 or end <= start: return
	var body: String = source.substr(start,end-start)
	var replacements: Array = [
		["\tvar points := PackedVector2Array()",'\t_deep_contact("outline_begin")\n\tvar points := PackedVector2Array()'],
		["\t\tfor index: int in range(prepared_outlines.size()):",'\t\tvar ids: Array = []; var poses: Array = []\n\t\tfor item: Variant in key:\n\t\t\tif item is Array: ids.append(item[0]); poses.append(item[1])\n\t\t_deep_contact("outline_key",{"entries":prepared_outlines.size(),"hash":var_to_bytes(key).hex_encode().sha256_text(),"mesh_ids":ids,"poses_sha256":var_to_bytes([car.scale,poses]).hex_encode().sha256_text()})\n\t\tfor index: int in range(prepared_outlines.size()):'],
		["\t\t\toutline = entry.outline",'\t\t\t_deep_contact("outline_cache_hit")\n\t\t\toutline = entry.outline'],
		["\t\t\treturn",'\t\t\t_deep_contact("outline_end",{"sha256":var_to_bytes(outline).hex_encode().sha256_text()})\n\t\t\treturn'],
		["\tfor node: Node in parts:",'\t_deep_contact("outline_cache_miss",{"parts":parts.size()})\n\tfor node: Node in parts:'],
		["\t\t\tvar arrays: Array = part.mesh.surface_get_arrays(surface)",'\t\t\t_deep_contact("surface_read_begin",{"node":str(part.name),"mesh":part.mesh.get_instance_id(),"surface":surface})\n\t\t\tvar arrays: Array = part.mesh.surface_get_arrays(surface)\n\t\t\t_deep_contact("surface_read_end")'],
		["\tif prepared:\n\t\tvar bytes:",'\t_deep_contact("outline_hull_done",{"points":points.size(),"hull":outline.size()})\n\tif prepared:\n\t\tvar bytes:'],
		["\n\treset()",'\n\treset()\n\t_deep_contact("outline_end",{"sha256":var_to_bytes(outline).hex_encode().sha256_text()})']
	]
	for item: Array in replacements:
		check(body.count(item[0]) == 1,"exact outline anchor "+str(item[0]).left(70))
		if body.count(item[0]) != 1: return
		body = body.replace(item[0],item[1])
	source = source.substr(0,start)+body+source.substr(end)+"\nfunc _deep_contact(label: String, data: Dictionary = {}) -> void:\n\tvar trace: Node = Engine.get_main_loop().root.get_node_or_null(\"DeepTrace\")\n\tif trace != null: trace.mark(label,data)\n"
	trace.mark("outline_memory_instrumentation",{"original_file_sha256":FileAccess.get_sha256("res://vehicle/visible_contact_audio.gd"),"instrumented_source_sha256":source.sha256_text()})
	script.source_code = source
	check(script.reload() == OK,"outline resource reloads before any race is constructed")

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("DEEP_FAIL ",label)
func foreground() -> void:
	if not is_instance_valid(app): return
	app._publishing_slots_foreground = true
	if is_instance_valid(app._garage_preloader):
		app._garage_preloader.idle_ms = 100000000
		app._garage_preloader.foreground = false
func drawn() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func persist() -> void:
	var result: Dictionary = {"mode":mode,"theme":theme,"checks":checks,"failures":failures,"rows":rows,"events":trace.events,"frames":trace.frames,"costs":trace.costs,"overflow":trace.overflow,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"podium_count":OS.get_environment("BMT_DEEP_PODIUM_COUNT"),"network_disabled":not app.online.configured if is_instance_valid(app) else true}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result))
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): mode = argument.trim_prefix("--case=")
		if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
	root.size = Vector2i(1280,720)
	trace = TraceSink.new(); trace.name = "DeepTrace"; root.add_child(trace)
	process_frame.connect(trace.begin_frame)
	RenderingServer.frame_pre_draw.connect(trace.before_render)
	RenderingServer.frame_post_draw.connect(trace.after_render)
	process_frame.connect(foreground)
	create_timer(240,true,false,true).timeout.connect(func() -> void:
		printerr("DEEP_TIMEOUT"); failures += 1; persist(); quit(1))
	trace.mark("app_load_begin")
	var script: Script = load("res://core/app.gd")
	trace.mark("app_load_end")
	app = script.new()
	app.name = "CircuitApp"
	app.records = load("res://persistence/local_records.gd").new("user://deep/records.json")
	app.records.settings.music_enabled = false
	app.library = load("res://persistence/track_library.gd").new("user://deep/tracks")
	app.cloud_root_override = "user://deep/cloud"
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"offline private App")
	await drawn()
	trace.mark("startup_ready")
	if mode == "rivalry": await rivalry()
	else:
		if OS.get_environment("BMT_DEEP_CONTACT") == "1": instrument_contact()
		if failures > 0:
			persist(); app.queue_free(); app = null
			for _i: int in range(5): await process_frame
			quit(1); return
		await race()
	trace.phase = "teardown"
	check(trace.overflow == 0,"bounded trace retains every observation")
	persist()
	app.queue_free(); app = null
	script = null
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for _i: int in range(18): await process_frame
	print("DEEP_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func rivalry() -> void:
	app.rivalry.model = load("res://race/weekly_rivalry.gd").new(true)
	for cycle: int in range(2):
		trace.phase = "rivalry-"+str(cycle)
		var began: int = Time.get_ticks_usec()
		trace.mark("entry_begin")
		await app._show_screen("rivalry")
		trace.mark("handler_return")
		await drawn()
		trace.mark("first_draw_complete")
		var page: Node = app.content.find_child("WeeklyRivalryPage",true,false)
		var deadline: int = Time.get_ticks_msec()+60000
		while is_instance_valid(page) and not page.ready_for_display() and Time.get_ticks_msec()<deadline: await process_frame
		check(page != null and page.ready_for_display(),"Rivalry actual standings and cars ready")
		for _i: int in range(4): await drawn()
		trace.mark("entry_ready")
		var cars: Array = []
		for car: Node in page.find_children("RivalryPodiumCar_*","",true,false):
			if car.get_script()==load("res://ui/rivalry_simple_car.gd"):
				cars.append({"name":car.name,"ready":car.presentation_ready,"size":[car.size.x,car.size.y],"triangles":car.triangle_count,"canvas":true})
			else:
				cars.append({"name":car.name,"ready":car.presentation_ready,"size":[car.viewport.size.x,car.viewport.size.y],"mode":car.viewport.render_target_update_mode,"model_ready":car.car.model_ready})
		check(cars.size() == 3,"all three production podium widgets retained")
		var row: Dictionary = {"cycle":cycle,"wall_ms":(Time.get_ticks_usec()-began)/1000.0,"cars":cars,"feature_load_ms":app.feature_load_ms.duplicate(true)}
		rows.append(row); print("DEEP_ROW ",JSON.stringify(row))
		if cycle == 0 and DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join("rivalry.png"))
		await app._show_screen("account")
		await drawn()
func race() -> void:
	trace.phase = "track-selection"
	var retained_scene: Resource
	if OS.get_environment("BMT_DEEP_RETAIN_SCENE") == "1":
		var static_before: int = OS.get_static_memory_usage()
		var video_before: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		retained_scene = load("res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn")
		trace.mark("retain_prepared_scene",{"static_delta_bytes":OS.get_static_memory_usage()-static_before,"video_delta_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)-video_before})
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	doc.theme = theme
	var began: int = Time.get_ticks_usec()
	var track: Resource = load("res://editor/track_compiler.gd").compile(doc)
	check(track != null,"Star fixture compiles")
	trace.mark("track_compiled",{"ms":(Time.get_ticks_usec()-began)/1000.0})
	track.metadata.cloud_version = "owned-deep-investigation"
	for cycle: int in range(2):
		trace.phase = "race-"+str(cycle)
		await app._show_screen("tracks")
		app.selected_track = track
		app.records.settings.camera_mode = "overhead"
		trace.mark("race_begin")
		began = Time.get_ticks_usec()
		await app._start_race(track,false,true)
		trace.mark("race_ready")
		check(is_instance_valid(app.game),"race installed")
		if not is_instance_valid(app.game): continue
		var game: Node = app.game
		game.set_physics_process(false); game.hitch_diagnostics.persist_enabled = false
		check(game.preparation_complete,"construction complete")
		check(game.sim.state.tick == 0 and game.countdown_ticks == 360,"tick zero and full countdown")
		check(game.track_session.target_laps == 5,"original five-lap rules")
		check(not is_instance_valid(app.race_loading),"loading cover released after preparation")
		var row: Dictionary = {"cycle":cycle,"wall_ms":(Time.get_ticks_usec()-began)/1000.0,"game_costs":game.preparation_costs.duplicate(true),"world_costs":game.track_ground.build_costs.duplicate(true),"effects":game.effect_preparation_counts.duplicate(true),"feature_load_ms":app.feature_load_ms.duplicate(true),"groups":game.world_render_preparation.frame_groups}
		rows.append(row); print("DEEP_ROW ",JSON.stringify(row))
		app._leave_race()
		await process_frame
	retained_scene = null
