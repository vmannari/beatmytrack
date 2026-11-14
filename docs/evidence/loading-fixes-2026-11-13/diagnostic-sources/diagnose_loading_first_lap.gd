extends SceneTree
var rows: Array = []

func _initialize() -> void: run.call_deferred()

func describe(sim: VehicleSimulation, session: TrackSession) -> Dictionary:
	return {"tick":sim.state.tick,"position":[sim.state.position.x,sim.state.position.y],"speed":sim.state.velocity.length(),"heading":sim.state.heading,"route_index":sim.state.route_index,"laps":session.completed_laps,"checkpoint":session.next_checkpoint,"checkpoint_count":session.checkpoint_count(),"missed_checkpoint":session.missed_checkpoint,"progress":session.last_progress,"contacts":sim.state.collision_count}

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	fixture.document.theme = "pine"
	var track: NativeTrack = TrackCompiler.compile(fixture.document)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	var session := TrackSession.new()
	var driver := RouteDriver.new()
	var samples: Array = []
	for tick: int in range(120*180):
		var previous: Vector2 = sim.state.position
		sim.step(driver.sample(sim.state,track,config),track)
		session.advance(track,previous,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		if tick%1200 == 0: samples.append(describe(sim,session))
		if session.completed_laps >= 1: break
	var direct: Dictionary = {"mode":"direct","final":describe(sim,session),"samples":samples,"route_length":track.route_length,"route_size":track.route.size(),"spawn":[track.spawn.x,track.spawn.y],"continuous_turn_radius":config.continuous_turn_radius}
	rows.append(direct); print("FIRST_LAP_DIAGNOSTIC ",JSON.stringify(direct))
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://first-lap-diagnostic"
	DirAccess.make_dir_recursive_absolute(folder)
	app.records = LocalRecords.new(folder+"/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder+"/tracks")
	app.cloud_root_override = folder+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.idle_ms = 100000000; app._garage_preloader.foreground = false; app._garage_preloader.set_process(false)
	VehicleCatalog.selected = "compact"
	track.metadata.cloud_version = "owned-loading-first-lap-diagnostic"
	app._show_screen("tracks"); app.selected_track = track
	await app._start_race(track,false,true)
	var game: Node = app.game
	game.set_physics_process(false); game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ai_enabled = true; game.hitch_diagnostics.persist_enabled = false
	var initial: Dictionary = describe(game.sim,game.track_session)
	initial.countdown = game.countdown_ticks
	samples = []
	for tick: int in range(120*180+360):
		game._physics_process(1.0/120.0)
		if tick%1200 == 0: samples.append(describe(game.sim,game.track_session))
		if game.track_session.completed_laps >= 1: break
	var actual: Dictionary = {"mode":"actual_app","initial":initial,"final":describe(game.sim,game.track_session),"samples":samples,"countdown":game.countdown_ticks,"paused":game.paused,"prepared":game.preparation_complete,"driver_scale":game.route_driver.speed_scale,"frame":game.frame.packed()}
	rows.append(actual); print("FIRST_LAP_DIAGNOSTIC ",JSON.stringify(actual))
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	app.queue_free()
	for frame: int in range(12): await process_frame
	quit(0)
