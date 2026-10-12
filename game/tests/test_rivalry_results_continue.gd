extends "res://tests/test_rivalry_result.gd"
## Real pointer input after the race replaces a warmed Rivalry menu.

class FixtureClient extends Node:
	var player: Dictionary = {"id":"driver_2"}
	var snapshot: Dictionary
	func base_url() -> String: return "http://fixture.invalid"
	func signed_in() -> bool: return true
	func recent_run(_ticket: String) -> Dictionary: return {}
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		await get_tree().process_frame
		return {"ok":true,"data":{"status":"queued"} if path.ends_with("/result") else snapshot.duplicate(true)}

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-continue-2026-10-09/ui")
	DirAccess.make_dir_recursive_absolute(evidence)
	OS.set_environment("BMT_API_URL", "")
	var folder: String = "user://rivalry_continue_" + TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var client := FixtureClient.new()
	client.snapshot = fixture()
	root.add_child(client)
	app.rivalry.client = client
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for state: String in ["verified", "pending", "failed"]:
			await continue_flow(dimensions,state)
	app.queue_free()
	client.queue_free()
	await process_frame
	print("RIVALRY_CONTINUE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func continue_flow(dimensions: Vector2i, state: String) -> void:
	app.rivalry.model.apply_snapshot(fixture())
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app.rivalry.result_ticket = ""
	app.rivalry_track = 1
	app.rivalry_section = "overview"
	app._show_screen("rivalry")
	await settle()
	var hub: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
	hub.standings_scroll.scroll_vertical = 75
	await settle()
	var scroll_offset: int = hub.standings_scroll.scroll_vertical
	app.rivalry_section = "detail"
	app._rivalry()
	await settle()
	check(not app.menu_neighbors.is_empty(),"fixture starts from a warmed Rivalry menu")
	var track: NativeTrack = app.selected_track
	track.metadata.cloud_version = "rivalry-continue-fixture"
	await app._start_race(track,false,true,{"fixture":true})
	var completed_game: Node = app.game
	completed_game.set_physics_process(false)
	completed_game.paused = true
	completed_game.attempt_practice = false
	# Owned capture windows can lose focus during scene preparation. Dismiss
	# that unrelated pause overlay before emulating the completed-race event.
	completed_game.hud.pause_menu.hide()
	var session := TrackSession.new()
	session.completed_laps = 5
	session.elapsed_ticks = 13080
	session.lap_start_time = 109.0
	session.lap_times.assign([22.0,22.0,22.0,22.0,21.0])
	session.finished = true
	completed_game.track_session = session
	completed_game.race_completed.emit()
	await settle()
	var normal: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	check(normal != null and normal.is_visible_in_tree() and app.rivalry_section == "race_results","normal five-lap summary appears first")
	check(app.content == null and app.menu_body == null and app.menu_body_slot == null and app.menu_neighbors.is_empty(),"summary retires previous menu controls and prepared pages")
	check(app.rivalry_standings_view.offset == scroll_offset,"summary preserves the remembered standings scroll")
	app.rivalry_result_pending = state == "pending"
	app.rivalry.error = "Could not connect. Try again." if state == "failed" else ""
	# Keep verification state independent of HTTP: only the navigation is under test.
	app.rivalry.result_state = state
	if state != "failed":
		var outcome: Dictionary = app.rivalry.model.preview_result(1,session.elapsed_ticks,109.0)
		if state == "verified":
			outcome.erase("provisional")
			app.rivalry.model.apply_outcome(outcome,1)
		else:
			app.rivalry.result_ticket = "pending-fixture"
	check(normal.next_button.is_visible_in_tree() and not normal.next_button.disabled,"Continue remains usable in " + state)
	if DisplayServer.get_name() != "headless": await capture("normal-"+state,dimensions)
	if dimensions.x == 1280:
		await mouse_click(normal.next_button.get_global_rect().get_center())
	else:
		await tap(normal.next_button.get_global_rect().get_center())
	await settle()
	var result_view: WeeklyRivalryResult = app.root_ui.find_child("RivalryRaceResult",true,false)
	check(app.rivalry_section == "result" and result_view != null and result_view.is_visible_in_tree(),"native Continue opens Rivalry feedback in " + state)
	check(app.game == completed_game,"Continue preserves the completed race for Race Again")
	if result_view == null: return
	if DisplayServer.get_name() != "headless": await capture("feedback-"+state,dimensions)
	var back: Button = app.root_ui.find_child("RivalryResultHome",true,false)
	await tap(back.get_global_rect().get_center())
	await settle()
	var returned: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
	check(app.rivalry_section == "overview" and returned.track_rows.size() == 5 and app.root_ui.find_child("RivalryTracksPanel",true,false) != null,"Back to Rivalry opens the five-track overview")
	check(app.game == null and not app.rivalry_racing,"Back to Rivalry releases the completed race")
	check(returned.standings_scroll != null and returned.standings_scroll.scroll_vertical == scroll_offset,"return restores standings scroll")
	if DisplayServer.get_name() != "headless": await capture("overview-"+state,dimensions)

func mouse_click(position: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
