extends SceneTree
## Lifecycle stress uses fixture result state; canonical driving is tested separately.
var checks: int = 0
var failures: int = 0
var app: Node
var sample_file: FileAccess
var report_directory: String = "res://../build/runtime-soak"
var sample_path: String
var cycles: int = 50
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames(count: int = 3) -> void:
	for _index: int in range(count): await process_frame
func garage_ready() -> bool:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app._retained_garage) and app._retained_garage.thumbnails.size()==7: return true
		await process_frame
	check(false,"Garage progressive image preparation deadline")
	return false
func editor_ready() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app.canvas) and app.editor_preview_thread==null and not app.canvas.preparing and not app.editor_world._building and not app.editor_commits.unsettled(): return
		await process_frame
	check(false,"editor preparation deadline")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="): cycles = int(arg.trim_prefix("--cycles="))
		if arg.begins_with("--report-dir="): report_directory = arg.trim_prefix("--report-dir=")
	# An empty Windows environment value can disappear, restoring the debug API
	# default. Write an explicit offline configuration only inside an owned lab.
	var lab_root: String = ProjectSettings.globalize_path("res://../build").simplify_path().replace("\\","/")
	var profile: String = OS.get_user_data_dir().simplify_path().replace("\\","/")
	if not profile.begins_with(lab_root+"/"):
		push_error("Runtime soak requires an isolated user-data directory under build/.")
		quit(1); return
	OS.unset_environment("BMT_API_URL")
	var offline := ConfigFile.new()
	offline.set_value("backend","url","")
	if offline.save("user://backend.cfg") != OK:
		push_error("Could not configure the isolated runtime soak offline.")
		quit(1); return
	report_directory = ProjectSettings.globalize_path(report_directory).simplify_path()
	DirAccess.make_dir_recursive_absolute(report_directory)
	var stem: String = "soak-"+str(cycles)+"-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()
	sample_path = report_directory.path_join(stem+".jsonl")
	sample_file = FileAccess.open(sample_path,FileAccess.WRITE)
	if sample_file == null:
		push_error("Could not open the runtime soak measurement stream.")
		quit(1); return
	root.size = Vector2i(1280,720)
	var folder: String = "user://runtime-soak-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(app.online.client.base_url().is_empty() and not app.online.configured,"isolated soak has no backend origin")
	if not app.online.client.base_url().is_empty():
		app.queue_free(); await frames(); sample_file.close(); quit(1); return
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "owned-soak-fixture"
	for cycle: int in range(cycles):
		app._show_screen("garage")
		while app.screen != "garage": await process_frame
		if not await garage_ready(): break
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
		write_sample(cycle)
	app.queue_free(); await frames(8)
	sample_file.close()
	var file := FileAccess.open(report_directory.path_join(stem+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cycles":cycles,"samples_file":sample_path,"engine":Engine.get_version_info()},"  "))
	file.close()
	print("RUNTIME_SOAK_RESULT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func write_sample(cycle: int) -> void:
	# Measure before constructing this row and release it on return. Retaining
	# nested measurement dictionaries was itself a steadily growing allocation.
	var bytes: int = OS.get_static_memory_usage()
	var row: Dictionary = {"cycle":cycle,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"static_bytes":bytes,"retained":app.editor_memory.retained(app)}
	sample_file.store_line(JSON.stringify(row)); sample_file.flush()
	print("RUNTIME_SOAK ",JSON.stringify(row))
