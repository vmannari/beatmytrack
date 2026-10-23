extends SceneTree
## Synthetic completed sessions exercise the real app results/retry/save boundary.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func finish_fixture(app: Node, seconds: float) -> RaceResults:
	var game: Node = app.game
	var session: TrackSession = game.track_session
	session.finished = true
	session.completed_laps = RaceRules.LAPS
	session.elapsed_ticks = roundi(seconds*VehicleSimulation.TICK_RATE)
	session.lap_start_time = seconds
	session.lap_times.assign([seconds/5,seconds/5,seconds/5,seconds/5,seconds/5])
	game.attempt_practice = false
	game.paused = true
	app._results()
	return app.root_ui.find_child("RaceResults",true,false) as RaceResults
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var directory: String = "user://coin_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var document: Dictionary = TrackDocument.create_default()
	document.id = "coin_app_fixture"
	var track: NativeTrack = TrackCompiler.compile(document)
	app.selected_track = track
	track.metadata.cloud_version = "isolated-coin-result-fixture"
	await app._start_race(track,false,true)
	check(is_instance_valid(app.game),"real app starts the isolated race fixture")
	if not is_instance_valid(app.game):
		quit(1)
		return
	track.metadata.erase("cloud_version")
	app.game.set_physics_process(false)
	var panel: RaceResults = finish_fixture(app,50.0)
	check(panel != null and panel.saved,"real results commit the completed session")
	check(app.cosmetic_economy.balance() == 0 and not app.records.settings.has("guest_coins"),"first completed guest session creates no coins or wallet")
	check(panel.get_meta("coin_receipt").amount == 0,"guest results hold no credited receipt")
	app._results()
	check(app.cosmetic_economy.balance() == 0,"duplicate guest finish remains coin-free")
	app._results_continue(panel,panel.get_parent())
	var completion: RaceComplete = app.root_ui.find_child("RaceComplete",true,false)
	check(completion != null and completion.economy == app.cosmetic_economy,"Continue uses the actual persistent economy")
	if completion.reward_reveal != null:
		completion.reward_reveal.pause()
		completion.reward_reveal.custom_step(10.0)
	check(completion.reward_total.text == "+ 0" and completion._reward_status.text == "Sign in to earn coins.","actual guest result page offers sign-in and displays zero coins")
	await app._retry_race()
	panel = finish_fixture(app,45.0)
	check(panel.saved and app.cosmetic_economy.balance() == 0,"guest retry saves PB without any rewards")
	var loaded := LocalRecords.new(app.records.path)
	loaded.load_records()
	check(not loaded.settings.has("guest_coins") and loaded.best_for(track,app.game.handling) == 45.0,"reloaded PB is retained without a guest wallet")
	await app._retry_race()
	app.records.path = directory.path_join("missing/records.json")
	panel = finish_fixture(app,40.0)
	check(not panel.saved and app.cosmetic_economy.balance() == 0,"failed guest results save remains coin-free")
	check(panel.get_meta("coin_receipt").amount == 0 and app.records.best_for(track,app.game.handling) == 45.0,"failed actual results save rolls back PB and keeps a zero receipt")
	root.remove_child(app)
	app.free()
	await process_frame
	print("EARNED_COINS_APP: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
