extends SceneTree
## A real game race, upload, verifier result and derived rival ghost over HTTP.
var checks: int = 0
var failures: int = 0

class ReplayInput extends DriverInput:
	var frames: Array = []
	var cursor: int = 0
	func sample() -> DriveFrame:
		var frame := DriveFrame.new()
		if cursor < frames.size():
			frame.steer = int(frames[cursor][0])
			frame.throttle = int(frames[cursor][1])
			frame.brake = int(frames[cursor][2])
			frame.handbrake = int(frames[cursor][3]) if frames[cursor].size() >= 4 else 0
			cursor += 1
		return frame

func _initialize() -> void:
	call_deferred("run")
	root.ready.connect(func() -> void:
		create_timer(100.0).timeout.connect(func() -> void:
			print("FAIL: weekly HTTP integration deadline")
			quit(1)))

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+description)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var folder: String = "user://weekly_http_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var login: Dictionary = await app.online.client.development_login("weekly-alice","Weekly Alice",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"isolated driver authenticates")
	var expire_at_finish: bool = OS.get_environment("BMT_RIVALRY_EXPIRED_SESSION") == "true"
	var restored_at_finish: bool = OS.get_environment("BMT_RIVALRY_SESSION_RESTORED") == "true"
	if expire_at_finish or restored_at_finish: app.rivalry.set_test_population(true)
	app._open_rivalry()
	while app.rivalry.busy: await process_frame
	check(app.rivalry.model.status == "not_joined" and app.rivalry.model.tracks.is_empty(),"no invented results before joining")
	await app.rivalry.join()
	check(app.rivalry.model.tracks.size() == 5 and app.rivalry.model.standing().size() == 1,"server pins five eligible official tracks and real member")
	check(not app.rivalry.model.sample,"shipping view uses the server field")
	app.rivalry_section = "detail"
	app._rivalry()
	await app._start_rivalry_race(0,3)
	check(app.game != null and app.rivalry_racing and not app.cloud_ticket.is_empty(),"pre-race starts with a rivalry-bound verified ticket")
	if app.game == null:
		print(app.rivalry.error)
		quit(1)
		return
	var game: Node = app.game
	game.set_physics_process(false)
	game.countdown_ticks = 0
	var driver := ReplayInput.new()
	driver.frames = fixture.replay.frames
	game.driver = driver
	# The real player has rendered the race before reaching results. Do not
	# charge first-ever 3D shader compilation to a later Continue interaction.
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	for _tick: int in range(fixture.replay.frames.size()): game._physics_process(1.0/120.0)
	check(game.track_session.finished,"actual pinned replay finishes five legal laps")
	check(game.online_frames.size() == fixture.replay.frames.size(),"rivalry records all canonical inputs")
	if expire_at_finish:
		# Do not change the client clock or alter its session. The disposable API
		# issues short-lived access so the simultaneous upload/read must refresh.
		await create_timer(2.2).timeout
	var restored_client: Node
	if restored_at_finish:
		if OS.get_environment("BMT_RIVALRY_CROSS_PROCESS") == "true":
			var notify: String = ProjectSettings.globalize_path(folder.path_join("restored.json"))
			var pid: int = OS.create_process(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/session_restore_worker.gd","--","--session="+ProjectSettings.globalize_path(app.online.client.session_path),"--notify="+notify]))
			check(pid > 0,"a separate pinned engine process starts")
			var started: int = Time.get_ticks_msec()
			while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec()-started < 20000: await process_frame
			var restored: Variant = JSON.parse_string(FileAccess.get_file_as_string(notify)) if FileAccess.file_exists(notify) else {}
			check(restored is Dictionary and restored.get("ok",false),"a separate process restores the same disposable remembered session")
		else:
			restored_client = load("res://backend/backend_client.gd").new()
			root.add_child(restored_client)
			restored_client.configure(app.online.client.base_url())
			restored_client.session_path = app.online.client.session_path
			var restored: Dictionary = await restored_client.restore_session()
			check(restored.ok,"a second client restores the same disposable remembered session")
	var records: LocalRecords = game.preference_records
	var total: float = game.track_session.race_time_seconds()
	var old_laps: Array[float] = game.track_session.lap_times.duplicate()
	for i: int in range(old_laps.size()): old_laps[i] += 0.2
	check(records.record(game.native_track,game.handling,total+1.0,old_laps) == OK,"isolated prior PB fixture saves")
	app._results()
	check(app.rivalry.model.last_result.get("provisional",false) and app.rivalry.model.last_result.get("points_delta") == 30,"finished race immediately projects weekly rank and points before verification")
	var summary: RaceResults = app.root_ui.find_child("RaceResults",true,false) as RaceResults
	check(app.rivalry_result_pending and app.rivalry_section == "race_results" and summary != null,"rivalry opens normal results while verification runs")
	check(summary.saved and absf(summary.previous-total-1.0) < 0.001 and absf(summary.best-total) < 0.001,"rivalry saves the all-time personal best through normal results")
	check((summary.find_child("RaceAchievement",true,false) as Label).text == "NEW PERSONAL BEST","normal results celebrate the personal best")
	check((summary.find_child("ResultDelta",true,false) as Label).text == "-1.000 s vs personal best","normal results compare the prior all-time personal best")
	var personal: Dictionary = game.ghost_store.load_best(records.key_for(game.native_track,game.handling),records.records[records.key_for(game.native_track,game.handling)])
	check(not personal.get("race",{}).is_empty(),"rivalry PB saves its personal ghost")
	var immediate_continue: bool = OS.get_environment("BMT_RIVALRY_IMMEDIATE_CONTINUE") == "true"
	if immediate_continue:
		# Continue becomes a user action once the normal summary is displayed.
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		var continue_started: int = Time.get_ticks_msec()
		summary.next_button.pressed.emit()
		print("RIVALRY_FEEDBACK_BUILD_MS: %d" % (Time.get_ticks_msec()-continue_started))
		await process_frame
		print("RIVALRY_IMMEDIATE_FEEDBACK_MS: %d" % (Time.get_ticks_msec()-continue_started))
		check(Time.get_ticks_msec()-continue_started < 250,"Continue renders useful feedback within a quarter second on the desktop fixture")
		check(app.rivalry_section == "result" and app.rivalry_result_pending and app.rivalry.model.last_result.get("provisional",false),"immediate Continue displays projected feedback while replay verification is pending")
		await capture("provisional-feedback")
	var verification_started: int = Time.get_ticks_msec()
	for _poll: int in range(200):
		if not app.online.client.signed_in(): break
		if app.rivalry.result_state in ["verified","failed","rejected"]: break
		await create_timer(0.2).timeout
	print("RIVALRY_AUTOMATIC_CONFIRMATION_MS: %d" % (Time.get_ticks_msec()-verification_started))
	check(Time.get_ticks_msec()-verification_started < 15000,"automatic verification completes during the normal summary without manual polling")
	check(app.rivalry.result_state == "verified","real worker verifies the rivalry upload")
	check(app.online.client.signed_in() and app.online.player_name() == "Weekly Alice","race completion and verification retain the signed-in driver")
	if not app.online.client.signed_in():
		if restored_client != null: restored_client.queue_free()
		app.queue_free()
		await process_frame
		print("WEEKLY_RIVALRY_HTTP_TESTS: %d checks, %d failures" % [checks,failures])
		quit(1)
		return
	check(not app.rivalry_result_pending and app.rivalry.model.last_result.get("points_delta") == 30,"verified result changes the championship points")
	if not immediate_continue:
		check(is_instance_valid(summary) and summary.is_visible_in_tree() and app.rivalry_section == "race_results","verification never replaces the normal results summary")
		summary.select_lap(0)
		check(summary.selected_lap == 0,"normal lap analysis remains interactive after verification")
		await capture("normal-results")
		summary.next_button.pressed.emit()
		await process_frame
	else:
		check(app.rivalry.model.last_result.valid and not app.rivalry.model.last_result.has("provisional"),"pending feedback automatically becomes confirmed in the same screen")
	check(app.rivalry_section == "result" and app.root_ui.find_child("WeeklyRivalryPage",true,false) != null,"Continue opens weekly position and points feedback")
	await capture("rivalry-feedback")
	# Result confirmation deliberately precedes the independent board refresh.
	while app.rivalry.busy: await process_frame
	var own: Dictionary = WeeklyRivalry.self_row(app.rivalry.model.standing())
	check(own.points == 30 and own.rank == 1,"Overview reflects one best result")
	var recording: Dictionary = await app.rivalry.ghost(0,str(app.online.client.player.id))
	check(not recording.is_empty() and not recording.has("replay"),"weekly ghost contains derived poses without raw driver controls")
	check(not PersonalGhostRun.sample(recording,0.0).is_empty() and PersonalGhostRun.sample(recording,float(recording.get("ticks",0))+1.0).is_empty(),"verified recording is bounded without extrapolation")
	app.rivalry_ghost_choice = 2
	await app._retry_race()
	check(app.rivalry_racing and app.game.online_frames.is_empty() and not app.cloud_ticket.is_empty(),"Rivalry Race Again gets a fresh weekly ticket")
	check(app.game.ghost_mode == "race" and not app.game.ghost_bests.get("race",{}).is_empty(),"retry loads the latest chosen verified weekly ghost")
	app._leave_race()
	check(app.game == null and app.screen == "rivalry","exit returns to championship Overview")
	await app.online.client.logout()
	if restored_client != null: restored_client.queue_free()
	check(app.rivalry.model.tracks.is_empty() and app.rivalry.result_ticket.is_empty(),"sign-out fences old rivalry standings and result polling")
	app.queue_free()
	await process_frame
	print("WEEKLY_RIVALRY_HTTP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(state: String) -> void:
	var folder: String = OS.get_environment("BMT_CAPTURE_CLOUD")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var path: String = folder.path_join("%s-%dx%d.png" % [state,dimensions.x,dimensions.y])
		check(root.get_texture().get_image().save_png(path) == OK,"result flow screenshot saves")
		print("CAPTURE_SAVED: "+path)
