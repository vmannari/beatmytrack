extends SceneTree
## Lifecycle stress uses fixture result state; canonical driving is tested separately.
var checks: int = 0
var failures: int = 0
var app: Node
var samples: Array = []
var cycles: int = 50
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames(count: int = 3) -> void:
	for _index: int in range(count): await process_frame
func editor_ready() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app.canvas) and app.editor_preview_thread==null and not app.canvas.preparing and not app.editor_world._building and not app.editor_commits.unsettled(): return
		await process_frame
	check(false,"editor preparation deadline")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="): cycles = int(arg.trim_prefix("--cycles="))
	root.size = Vector2i(1280,720)
	var folder: String = "user://runtime-soak-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "owned-soak-fixture"
	for cycle: int in range(cycles):
		app._show_screen("garage")
		while app.screen != "garage": await process_frame
		await frames()
		check(is_instance_valid(app._retained_garage) and app._retained_garage.thumbnails.size()==7,"cycle "+str(cycle)+" current Garage has all seven images")
		app._show_screen("tracks"); app.selected_track = track
		await app._start_race(track,false,true)
		check(is_instance_valid(app.game) and app.game.preparation_complete,"actual ordinary race installs")
		if not is_instance_valid(app.game): break
		app.game.set_physics_process(false)
		app.game.paused = true
		app.game.track_session.finished = true
		app.game.track_session.completed_laps = 5
		app.game.track_session.elapsed_ticks = 1200
		app.game.track_session.lap_times.assign([2.0,2.0,2.0,2.0,2.0])
		app._results(); await frames()
		check(app._result_game_id==app.game.get_instance_id(),"actual results attach to the completed game once")
		app._results()
		app._leave_race(); await frames()
		app._show_screen("garage")
		while app.screen != "garage": await process_frame
		await frames()
		app.document = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/storm_freight.json"))
		app.document.theme = "pine"
		app.document.objects = []
		app.document.creator = app.library.owner_name
		app._show_screen("create"); await editor_ready()
		await app._test_document()
		check(is_instance_valid(app.game) and app.game.editor_test,"actual editor practice installs")
		if is_instance_valid(app.game): app._leave_race()
		app._show_screen("settings"); await frames()
		if cycle%10==0:
			var garage: WeakRef = weakref(app._retained_garage)
			app._notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
			app.editor_memory.tick(app)
			await frames()
			check(garage.get_ref()==null and not is_instance_valid(app._retained_garage),"pressure releases hidden native Garage and textures")
		if cycle%10==9:
			app.records = LocalRecords.new(folder.path_join("owner-"+str(cycle)+".json"))
			await app._rebuild_profile_menu("account")
			check(not is_instance_valid(app._retained_garage),"owner switch releases old cosmetics and images")
		await frames()
		samples.append({"cycle":cycle,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"condition_stores":preload("res://persistence/condition_store.gd")._stores.size(),"work_jobs":preload("res://editor/work_job.gd").pending.size(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"retained":app.editor_memory.retained(app)})
		print("RUNTIME_SOAK ",JSON.stringify(samples[-1]))
	app.queue_free(); await frames(8)
	var out: String = ProjectSettings.globalize_path("res://../docs/evidence/runtime-correctness-2026-10-26")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("diagnostic-objects-soak-"+str(cycles)+"-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "))
	print("RUNTIME_SOAK_RESULT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
