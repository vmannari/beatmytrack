extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://loading-shutdown-diagnostic"
	DirAccess.make_dir_recursive_absolute(folder)
	app.records = LocalRecords.new(folder+"/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder+"/tracks")
	app.cloud_root_override = folder+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.idle_ms = 100000000; app._garage_preloader.foreground = false; app._garage_preloader.set_process(false)
	var disk: Script = load("res://track/prepared_world_disk_cache.gd")
	if "--enable-headless-disk" in OS.get_cmdline_user_args(): disk.allow_headless = true
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var track: NativeTrack = TrackCompiler.compile(fixture.document)
	track.metadata.cloud_version = "owned-shutdown-diagnostic"
	VehicleCatalog.selected = "compact"
	for cycle: int in range(2):
		app._show_screen("tracks"); app.selected_track = track
		await app._start_race(track,false,true)
		app.game.set_physics_process(false)
		var deadline: int = Time.get_ticks_msec()+5000
		while not disk.pending_writes.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		print("SHUTDOWN_DIAGNOSTIC cycle=",cycle," pending=",disk.pending_writes.size()," worlds=",load("res://track/prepared_world_cache.gd").entries.size())
		app._leave_race()
		for frame: int in range(8): await process_frame
	app.queue_free(); app = null
	for frame: int in range(24): await process_frame
	print("SHUTDOWN_DIAGNOSTIC_COMPLETE pending=",disk.pending_writes.size())
	quit(0)
