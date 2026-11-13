extends Node
## Task-owned local profiler. Avoid typed game references during startup parsing.
const Trace = preload("res://diagnostics/tablet_phase_trace.gd")
var app: Node
var rows: Array = []
var frames: Array[float] = []
var spikes: Array = []
var last_frame: int = 0
var checks: int = 0
var failures: Array = []
var output: String
var saved_keep_on: bool = false
var last_garage_state: String = ""

func _ready() -> void:
	saved_keep_on = DisplayServer.screen_is_kept_on()
	DisplayServer.screen_set_keep_on(true)
	output = "user://tablet-loading-fixes-20261107/"+str(Trace.options.run)
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(900,true,false,true).timeout.connect(func() -> void: fail("watchdog timeout"); finish())
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Trace.options.get("desktop_fixture",false):
		app._publishing_slots_foreground = true
		if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true
	var now: int = Time.get_ticks_usec()
	if last_frame != 0 and frames.size() < 20000:
		var gap: float = (now-last_frame)/1000.0
		frames.append(gap)
		if gap > 50.0 and spikes.size() < 40:
			spikes.append({"ms":gap,"last_mark":Trace.events[-1].label if not Trace.events.is_empty() else "none"})
	last_frame = now
	if Trace.scope.begins_with("menu/garage") and is_instance_valid(app._retained_garage):
		var showroom: Node = app._retained_garage.showroom
		if is_instance_valid(showroom):
			var first: Node = showroom.get("_first")
			var state: String = "native:"+str(first.pending.size()) if is_instance_valid(first) else "geometry" if not showroom.showroom_ready else "settling" if showroom.get("preparing") == true else "revealed"
			if state != last_garage_state:
				last_garage_state = state
				Trace.mark("garage_state",{"state":state})

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fail(label)

func fail(label: String) -> void:
	failures.append(label)
	printerr("TABLET_PHASE_FAILURE ",label)

func draw() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func content_ready(page: String) -> bool:
	if app.screen != page or is_instance_valid(app._feature_loading): return false
	if page == "garage":
		return is_instance_valid(app._retained_garage) and app._retained_garage.showroom.showroom_ready and app._retained_garage.showroom.get("preparing") != true
	if page == "rivalry":
		var view: Node = app.content.find_child("WeeklyRivalryPage",true,false)
		if view == null or not view.standings_ready: return false
		for car: Node in view.find_children("RivalryPodiumCar_*","",true,false):
			if not car.presentation_ready: return false
	if page == "daily":
		var view: Node = app.root_ui.find_child("TrackOfDayPage",true,false)
		if view == null or view._busy: return false
		var card: Node = view._race_panel
		if is_instance_valid(card) and card._loading: return false
	if page == "tracks":
		var browser: Node = app.root_ui.find_child("TrackBrowser",true,false)
		if browser == null or browser.loading: return false
		for preview: Node in browser.find_children("*","TrackShowroom",true,false):
			if not preview.ready_for_display: return false
	if page == "challenges":
		var view: Node = app.root_ui.find_child("ChallengesPage",true,false)
		if view != null and view.busy: return false
	if page == "create":
		return is_instance_valid(app.canvas) and is_instance_valid(app.editor_world) and app.editor_preview_thread == null and app.canvas.native_preview != null and not app.editor_world._building and app.editor_world._initial_preparation_done and not app.editor_commits.unsettled()
	return true

func wait_ready(page: String, deadline_ms: int = 60000) -> bool:
	var until: int = Time.get_ticks_msec()+deadline_ms
	while not content_ready(page) and Time.get_ticks_msec()<until: await get_tree().process_frame
	return content_ready(page)

func begin_case(label: String) -> int:
	Trace.scope = label
	frames.clear()
	spikes.clear()
	last_frame = Time.get_ticks_usec()
	Trace.mark("case_begin")
	return last_frame

func frame_stats() -> Dictionary:
	var ordered: Array[float] = frames.duplicate()
	ordered.sort()
	if ordered.is_empty(): return {}
	return {"count":ordered.size(),"p50_ms":ordered[int((ordered.size()-1)*0.5)],"p95_ms":ordered[int((ordered.size()-1)*0.95)],"max_ms":ordered[-1],"spikes":spikes.duplicate(true)}

func writer_state() -> Dictionary:
	var script: Script = load("res://backend/menu_snapshot_writer.gd")
	var writer: Node = script.instance
	return {"exists":is_instance_valid(writer),"inside_tree":writer.is_inside_tree() if is_instance_valid(writer) else false,"pending_paths":writer.pending.size() if is_instance_valid(writer) else 0,"completed_writes":writer.completed_writes if is_instance_valid(writer) else 0}

func entry(page: String, cycle: int) -> void:
	var began: int = begin_case("menu/"+page+"/"+str(cycle))
	await app._show_screen(page)
	var dispatched: int = Time.get_ticks_usec()
	await draw()
	var first: int = Time.get_ticks_usec()
	var ready: bool = await wait_ready(page)
	check(ready,page+" content ready")
	while app.menu_page_motion != null and app.menu_page_motion.is_running(): await get_tree().process_frame
	await draw()
	if page == "rivalry":
		for _i: int in range(4): await draw()
	var row: Dictionary = {"kind":"menu","page":page,"cycle":cycle,"dispatch_ms":(dispatched-began)/1000.0,"first_draw_ms":(first-began)/1000.0,"ready_ms":(Time.get_ticks_usec()-began)/1000.0,"success":ready,"frames":frame_stats()}
	if page == "create":
		row.editor_state = {"canvas":is_instance_valid(app.canvas),"world":is_instance_valid(app.editor_world),"worker":app.editor_preview_thread != null,"native_preview":is_instance_valid(app.canvas) and app.canvas.native_preview != null,"building":app.editor_world._building if is_instance_valid(app.editor_world) else true,"prepared":app.editor_world._initial_preparation_done if is_instance_valid(app.editor_world) else false,"unsettled":app.editor_commits.unsettled()}
	if page == "garage":
		check(not is_instance_valid(app._feature_loading),"Garage has no modal loading window")
		check(app._retained_garage.showroom.reflections.views.size()==2,"Garage keeps both reflections")
	if page == "daily":
		var view: Node = app.root_ui.find_child("TrackOfDayPage",true,false)
		if view != null: row.data_available = not view.entry.is_empty(); row.card_failed = view._race_panel._failed
	rows.append(row)
	Trace.mark("case_ready")
	print("TABLET_PHASE_ROW ",JSON.stringify(row))
	await get_tree().create_timer(0.35).timeout

func editor_entry() -> void:
	var saved_library: RefCounted = app.library
	var saved_document: Dictionary = app.document.duplicate(true)
	var private_library: RefCounted = load("res://persistence/track_library.gd").new(output.path_join("editor-tracks"))
	private_library.owner_name = saved_library.owner_name
	app.library = private_library
	app.lifecycle.library = private_library
	app.document = load("res://editor/track_document.gd").create_default()
	for cycle: int in range(2):
		await entry("create",cycle)
		app._flush_editor_writes()
		app._finish_preview_thread()
		await app._show_screen("rivalry")
		await wait_ready("rivalry")
		await draw()
	app.library = saved_library
	app.lifecycle.library = saved_library
	app.document = saved_document
	await draw()

func race_case(theme: String, cycle: int, fixture: String) -> void:
	Trace.practice = true
	Trace.scope = "race/"+fixture+"/"+theme+"/"+str(cycle)
	var source: Dictionary = load("res://diagnostics/tablet_phase_tracks.gd").document(fixture)
	source.theme = theme
	var began_compile: int = Time.get_ticks_usec()
	var track: RefCounted = load("res://editor/track_compiler.gd").compile(source)
	var compile_ms: float = (Time.get_ticks_usec()-began_compile)/1000.0
	check(track != null,"local fixture compiles")
	if track == null: Trace.practice = false; return
	track.metadata.cloud_version = "local-tablet-phase-profile"
	app.records._conditions()
	var records: RefCounted = load("res://persistence/local_records.gd").new(output.path_join("practice-records.json"))
	records.settings = app.records.settings.duplicate(true)
	records.records = app.records.records.duplicate(true)
	Trace.practice_records = records
	var original_selection: RefCounted = app.selected_track
	app.selected_track = track
	app.race_profile_enabled = true
	var began: int = begin_case("race/"+fixture+"/"+theme+"/"+str(cycle))
	await app._start_race(track,false,true)
	var elapsed_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var game: Node = app.game
	check(is_instance_valid(game),"local practice Game installed")
	if not is_instance_valid(game): Trace.practice = false; app.selected_track = original_selection; return
	game.process_mode = Node.PROCESS_MODE_DISABLED
	check(game.sim.state.tick==0,"race frozen at tick zero")
	check(game.countdown_ticks==360,"full countdown retained")
	check(game.track_session.target_laps==5,"five laps retained")
	check(app.cloud_ticket.is_empty(),"no competitive ticket")
	check(game.preference_records==records,"private practice preferences")
	var row: Dictionary = {"kind":"race","fixture":fixture,"theme":theme,"cycle":cycle,"compile_ms":compile_ms,"ready_ms":elapsed_ms,"frames":frame_stats(),"game_costs":game.preparation_costs.duplicate(true),"world_costs":game.track_ground.build_costs.duplicate(true),"effects_ms":game.bridge_preparation_ms,"effects":game.effect_preparation_counts.duplicate(true),"native_groups":game.world_render_preparation.frame_groups if is_instance_valid(game.world_render_preparation) else 0,"native_draw_wait_max_us":game.world_render_preparation.draw_us_max if is_instance_valid(game.world_render_preparation) else 0}
	var viewport: Viewport = game.get("_render_viewport")
	if viewport != null: row.quality = {"pixels":str(viewport.get_visible_rect().size),"msaa":viewport.msaa_3d,"scale":viewport.scaling_3d_scale}
	var retry_begin: int = Time.get_ticks_usec()
	await app._retry_race(true)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	row.retry_ms = (Time.get_ticks_usec()-retry_begin)/1000.0
	check(game.sim.state.tick==0 and game.countdown_ticks==360,"retry retains frozen full start")
	check(game.preference_records==records,"retry keeps private practice preferences")
	rows.append(row)
	print("TABLET_PHASE_ROW ",JSON.stringify(row))
	app._telemetry_race_finished = true
	app._leave_race()
	app.selected_track = original_selection
	await draw()
	Trace.practice_records = null
	Trace.practice = false
	await get_tree().create_timer(0.5).timeout

func _run() -> void:
	while not app.startup_complete: await get_tree().process_frame
	# The shell's startup_complete flag precedes asynchronous restored navigation.
	# A transient restoring view is never the intended initial menu.
	var navigation_deadline: int = Time.get_ticks_msec()+90000
	while app.screen == "restoring" and Time.get_ticks_msec()<navigation_deadline:
		await get_tree().process_frame
	check(app.screen != "restoring","restored navigation completed")
	var first_page: String = app.screen
	var startup_ok: bool = first_page != "restoring" and await wait_ready(first_page,90000)
	check(startup_ok,"initial menu content ready")
	await draw()
	for _i: int in range(4): await draw()
	Trace.mark("initial_content_ready",{"page":first_page,"success":startup_ok})
	rows.append({"kind":"startup","engine_to_content_ms":Time.get_ticks_usec()/1000.0,"screen":first_page,"frames":frame_stats(),"signed_in":app.online.client.signed_in(),"menu_snapshot_writer":writer_state()})
	if Trace.options.get("desktop_fixture",false):
		app.rivalry.model = load("res://race/weekly_rivalry.gd").new(true)
	var mode: String = str(Trace.options.get("mode","startup"))
	if mode == "startup":
		var began: int = begin_case("startup_idle")
		await get_tree().create_timer(3.0).timeout
		rows.append({"kind":"startup_idle","elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"frames":frame_stats()})
	if mode == "menus":
		var pages: Array = Trace.options.get("pages",["rivalry","daily","tracks","challenges","biome","drafts","profile","settings","store","garage"])
		for cycle: int in range(2):
			for page: String in pages: await entry(page,cycle)
		if Trace.options.get("editor",true): await editor_entry()
	if mode == "races":
		load("res://race/checkpoint_layout_disk_cache.gd").directory = "user://tablet-loading-fixes-20261107/cache/checkpoints"
		load("res://track/road_mesh_disk_cache.gd").directory = "user://tablet-loading-fixes-20261107/cache/roads"
		for theme: String in Trace.options.get("themes",["pine","winter","desert","night_city","storm"]):
			for cycle: int in range(2): await race_case(theme,cycle,"oval")
		if Trace.options.get("star",true):
			for cycle: int in range(2): await race_case("pine",cycle,"star")
	finish()

func finish() -> void:
	set_process(false)
	Trace.mark("profile_complete")
	var report: Dictionary = {"schema":1,"run":Trace.options.run,"mode":Trace.options.get("mode","startup"),"checks":checks,"failures":failures,"events":Trace.events,"dropped_events":Trace.dropped,"rows":rows,"feature_load_ms":app.feature_load_ms.duplicate(true),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"model":OS.get_model_name(),"viewport":str(get_viewport().get_visible_rect().size),"quality":{"msaa":get_viewport().msaa_3d,"scale":get_viewport().scaling_3d_scale},"practice_records_private":true}
	report.menu_snapshot_writer = writer_state()
	var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	DirAccess.remove_absolute(Trace.CONFIG)
	DisplayServer.screen_set_keep_on(saved_keep_on)
	print("TABLET_PHASE_COMPLETE ",JSON.stringify({"run":Trace.options.run,"checks":checks,"failures":failures.size(),"output":output.path_join("result.json")}))
	if Trace.options.get("quit",false): get_tree().quit(0 if failures.is_empty() else 1)
	queue_free()
