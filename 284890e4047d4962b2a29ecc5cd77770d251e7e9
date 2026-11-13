extends SceneTree
const Rules = preload("res://race/daily_elimination.gd")
var checks: int = 0
var failures: int = 0

class DailyApp extends "res://core/app.gd":
	var limits_available: bool = true
	var limit_requests: int = 0
	func _load_daily_limits(track: NativeTrack, vehicle: String, request: Dictionary) -> RefCounted:
		limit_requests += 1
		if not limits_available: return null
		var data: Dictionary = {"policy":"daily-flying-elimination-v1","version_id":str(request.version_id),"vehicle_id":vehicle,"tick_rate":120,"population":100,"cutoffs":[]}
		for i: int in range(9): data.cutoffs.append({"percentile":Rules.PERCENTILES[i],"lap_ticks":(30-i)*120})
		var rules := Rules.new()
		return rules if rules.configure(data,str(track.metadata.cloud_version),vehicle) else null

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Daily App deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	var directory: String = "user://daily_elimination_app"
	DirAccess.make_dir_recursive_absolute(directory)
	var app := DailyApp.new()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.race_area_mode = "daily"
	app._show_screen("daily")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	track.metadata.cloud_version = "daily-test"
	app.selected_track = track
	var records_before: Dictionary = app.records.records.duplicate(true)
	var request: Dictionary = {"day":20757,"version_id":"daily-test"}
	# The metadata/download path presents its overlay before any asynchronous work.
	track.metadata.cloud_entry = {}
	app._prepare_metadata_race(track,false,false,{},request)
	check(app.race_loading != null and "Elimination" in app.race_loading.facts_label.text,"metadata loading immediately identifies elimination")
	app._close_race_loading()
	await process_frame
	track.metadata.erase("cloud_entry")
	app._start_race(track,false,false,{},null,request)
	check(app.race_loading != null and "Elimination" in app.race_loading.facts_label.text,"daily race loading immediately identifies elimination")
	while app.cloud_starting: await process_frame
	check(app.game != null,"actual App enters the daily race")
	if app.game == null:
		app.queue_free()
		quit(1)
		return
	var game: Node = app.game
	game.set_physics_process(false)
	check(game.track_session.target_laps == 10 and game.daily_elimination != null,"daily rules reach prepared Game")
	check(not game.handling_test_enabled and app.cloud_ticket.is_empty(),"daily race cannot use experimental handling or an ordinary five lap ticket")
	game._process(0.0)
	await capture("app-opening")
	# Use the real Game physics boundary, with the preceding ordered gates already passed.
	game.countdown_ticks = 0
	game.race_cues.reset()
	var session: TrackSession = game.track_session
	session.lap_times.assign([100.0])
	session.lap_start_time = 100
	session.completed_laps = 1
	session.elapsed_ticks = 131*120
	session.next_checkpoint = session.checkpoint_count()
	session.finish_armed = true
	game.sim.state.tick = session.elapsed_ticks
	game.sim.state.position = track.finish_center-track.finish_forward*0.02
	game.sim.state.velocity = track.finish_forward*10.0
	game.sim.state.heading = atan2(track.finish_forward.x,track.finish_forward.y)
	game.sim.state.route_index = track.nearest_route(game.sim.state.position)
	game._process(0.0)
	check(game.hud.clock_caption.text == "Top 75%" and game.hud.race_timer.text == "0:30.000","main HUD displays the lap cutoff instead of total race time")
	await capture("app-first-cutoff")
	game._physics_process(1.0/120.0)
	check(session.completed_laps == 2 and game.daily_elimination.eliminated,"real finish crossing eliminates on a slow flying lap")
	check(game.finish_sim != null,"elimination enters the existing finish transition")
	game._complete_finish()
	check(game.has_node("DailyResults") and not game.hud.visible,"App completion displays daily results")
	await capture("app-eliminated")
	app._results()
	check(game.get_node("DailyResults").get_child_count() == 1,"duplicate completion has one result panel")
	check(app.records.records == records_before and app.cloud_ticket.is_empty(),"eliminated total never replaces ordinary records or enters uploads")
	await app._retry_daily_race()
	check(app.limit_requests == 2 and not game.has_node("DailyResults") and game.hud.visible,"retry refreshes limits and restores racing HUD")
	check(game.track_session.lap_times.is_empty() and not game.daily_elimination.eliminated and game.track_session.target_laps == 10,"retry resets opening lap and every stage")
	app._leave_race()
	check(app.game == null and app.screen == "daily","exit returns to Track of the Day")
	app.limits_available = false
	app.selected_track = track
	await app._start_race(track,false,false,{},null,{"day":20757,"version_id":"daily-test"})
	check(app.game == null and not app.cloud_starting,"missing cutoffs cannot start a race or strand the start lock")
	app.queue_free()
	await process_frame
	print("DAILY_ELIMINATION_APP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../docs/evidence/daily-elimination-2026-10-31/"+label+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"capture "+label)
