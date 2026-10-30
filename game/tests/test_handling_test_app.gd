extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", description)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280, 720)
	var folder: String = "user://handling-test-" + TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records.settings.music_enabled = false
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "handling-test-fixture"
	VehicleCatalog.selected = "pickup"
	app._show_screen("tracks")
	app.selected_track = track
	await app._start_race(track, false, true)
	var game: Node = app.game
	game.set_physics_process(false)
	app.cloud_ticket = {"ticket_id": "issued-canonical-ticket"}
	game.resume_ticket_id = "issued-canonical-ticket"
	game.select_handling_test(0)
	check(app.cloud_ticket.is_empty() and game.resume_ticket_id.is_empty(), "test selection retires the issued race ticket")
	check(game.get_meta("race_offline_only") and game.attempt_practice, "retry remains offline and current attempt is practice")
	game.track_session.finished = true
	game.track_session.completed_laps = 5
	game.track_session.elapsed_ticks = 1200
	game.track_session.lap_times.assign([2.0, 2.0, 2.0, 2.0, 2.0])
	var before: Dictionary = app.records.records.duplicate(true)
	app._results()
	var panel: RaceResults = app.root_ui.find_child("RaceResults", true, false)
	check(panel != null and not panel.clean, "experimental completion is presented as practice")
	check(app.records.records == before and app.cloud.result_saves.jobs.is_empty(), "experimental completion creates no personal best or online upload")
	app.queue_free()
	for _frame: int in range(8): await process_frame
	print("HANDLING_TEST_APP ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
