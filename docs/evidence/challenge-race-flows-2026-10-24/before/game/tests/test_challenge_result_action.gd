extends SceneTree
## Real App summaries and navigation, with isolated records and no upload transport.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = "res://../docs/evidence/challenge-result-action-2026-10-24/ui"

class ResultApp extends "res://core/app.gd":
	func _save_result_upload(_completed_game: Node, _ticket_data: Dictionary, _frames: Array, _publish_version: String, _rewinds: Array) -> void:
		cloud_ticket = {}
	func _try_race_ad(_finished_game: int, _panel: Control) -> void: pass

func _initialize() -> void:
	_timeout.call_deferred()
	run.call_deferred()

func _timeout() -> void:
	await create_timer(90.0).timeout
	push_error("Challenge result action fixture timed out")
	quit(1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for frame: int in range(5): await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	var directory: String = "user://challenge_result_action_"+TrackLibrary.unique_id()
	app = ResultApp.new()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.player = {"id":"challenge-result-fixture"}
	app.online.client._access_token = "fixture"
	app.challenges.reset()
	app.challenges.busy = true
	var track: NativeTrack = app.selected_track
	track.metadata.cloud_version = "00000000-0000-4000-8000-000000000001"
	await app._start_race(track,false,true)
	var game: Node = app.game
	game.set_physics_process(false)
	game.paused = true
	game.hud.pause_menu.hide()
	game.attempt_practice = false
	var session := TrackSession.new()
	session.completed_laps = 5
	session.elapsed_ticks = 13200
	session.lap_start_time = 110.0
	session.lap_times.assign([23.0,22.0,22.0,22.0,21.0])
	session.finished = true
	game.track_session = session
	# A slower finish must remain the challenge source rather than the saved PB.
	var prior_laps: Array[float] = [20.0,20.0,20.0,20.0,20.0]
	check(app.records.record(track,game.handling,100.0,prior_laps) == OK,"save isolated faster PB")
	for mode: String in ["free","challenge","practice","offline","seed"]:
		app._result_game_id = 0
		app.challenge_racing = mode == "challenge"
		app.challenge_practice = mode == "practice"
		app.challenge_seed = {"version_id":str(track.metadata.cloud_version),"vehicle_id":str(game.vehicle_id),"duration_seconds":86400,"attempt_limit":3,"configuration":{"format":"duel"}} if mode == "seed" else {}
		app.cloud_ticket = {} if mode == "offline" else {"ticket_id":"exact-finished-ticket"}
		app._results()
		await settle()
		var panel: RaceResults = app.root_ui.find_child("RaceResults",true,false)
		var create: Button = panel.find_child("CreateResultChallenge",true,false)
		var resume: Button = panel.find_child("ContinueResultChallenge",true,false)
		check(panel.total == 110.0 and panel.best == 100.0,mode+" summary retains actual slower finish and saved PB")
		if mode in ["challenge","practice","seed"]:
			check(create == null and resume != null,mode+" offers continuation instead of creating another challenge")
			check(resume.text == "CONTINUE CHALLENGE" and not resume.disabled,mode+" action identifies the challenge context")
		elif mode == "free":
			check(create != null and resume == null,"ordinary verified race still offers Create challenge")
		else:
			check(create == null and resume == null,"offline free race has no online challenge action")
		if mode != "seed":
			# Test the visible action's signal without leaving this reusable summary.
			panel.continue_requested.disconnect(app._results_continue.bind(panel,panel.get_parent()))
			var signals: Dictionary = {"continue":0,"create":0}
			panel.continue_requested.connect(func() -> void: signals["continue"] += 1)
			panel.challenge_requested.connect(func() -> void: signals.create += 1)
			if resume != null: resume.pressed.emit()
			elif create != null: create.pressed.emit()
			check(signals["continue"] == (1 if resume != null else 0) and signals.create == (1 if create != null else 0),mode+" action emits only its intended signal")
		await capture(mode)
		if mode == "seed":
			root.size = Vector2i(960,540)
			await settle()
			check(root.get_visible_rect().encloses(panel.get_global_rect()),"challenge summary fits the short landscape viewport")
			await capture("seed-960x540")
			root.size = Vector2i(1280,720)
			await settle()
			await click(resume.get_global_rect().get_center())
			await settle()
			var dialog: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
			check(dialog != null and app.screen == "challenge_create","challenge action resumes the original creation flow")
			if dialog != null:
				check(dialog.initial_ticket == "exact-finished-ticket" and dialog.result_context.total == 110.0,"continuation pins this completed ticket and time")
				check(dialog.initial_duration == 86400 and dialog.initial_attempt_limit == 3 and dialog.initial_configuration == {"format":"duel"},"continuation retains the chosen challenge settings")
			check(app.challenge_seed.is_empty() and app.game == null,"continuation consumes the seed and releases the finished race")
	app.queue_free()
	await settle()
	print("CHALLENGE_RESULT_ACTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func click(position: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func capture(mode: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(root.get_texture().get_image().save_png(evidence.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()+"-"+mode+".png")) == OK,"capture "+mode)
