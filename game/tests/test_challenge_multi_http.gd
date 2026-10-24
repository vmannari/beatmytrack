extends "res://tests/test_challenges_http.gd"
## Real 3x3 native races, immediate Continue and per-stage server verification.

func run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var folder: String = "user://challenge_multi_http_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var login: Dictionary = await app.online.client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"disposable challenge creator signs in")
	await accept_public_rules(app.online.client)
	var catalogue: Dictionary = await app.online.client.request_api("/tracks?limit=20")
	check(catalogue.ok and catalogue.data.items.size() >= 3,"three distinct pinned tracks are available")
	var versions: Array[String] = []
	for index: int in range(3): versions.append(str(catalogue.data.items[index].version_id))
	await app.challenges.create_challenge({"mode":"3x3","version_id":versions[0],"version_ids":versions,"vehicle_id":"compact","attempt_limit":3,"duration_seconds":604800})
	check(not app.challenges.selected.is_empty() and app.challenges.selected.stages.size() == 3,"one real invitation contains all three tracks")
	app._open_challenges(true)
	while app.challenges.busy: await process_frame
	for stage: int in range(3):
		app.challenges.select_stage(stage)
		await app._start_challenge_race()
		check(app.game != null and app.challenge_racing and str(app.game.native_track.metadata.cloud_version) == versions[stage],"selected track starts with its own server ticket: "+str(stage))
		if app.game == null:
			print(app.challenges.error)
			quit(1)
			return
		var first_ticket: String = str(app.cloud_ticket.ticket_id)
		_drive(app.game,fixture.replay.frames)
		check(app.game.track_session.finished,"five ordered laps complete on track "+str(stage))
		app._results()
		var summary: RaceResults = app.root_ui.find_child("RaceResults",true,false)
		check(summary != null and summary.find_child("ContinueResultChallenge",true,false) == null,"normal results have no extra Continue challenge action")
		if stage == 0:
			await app._retry_race()
			check(app.cloud_ticket.get("ticket_id") != first_ticket and app.challenge_racing,"normal-results Race again obtains another ticket for track one")
			_drive(app.game,fixture.replay.frames)
			app._results()
			summary = app.root_ui.find_child("RaceResults",true,false)
		summary.continue_requested.emit()
		check(app.game == null and app.challenge_result_view,"immediate Continue releases the Game while verification proceeds")
		for attempt: int in range(100):
			await app.challenges.poll_result()
			if app.challenges.result_state == "verified": break
			await create_timer(0.1).timeout
		check(app.challenges.result_state == "verified" and int(app.challenges.outcome.stage_index) == stage,"server verifies the selected stage after Continue: "+str(stage))
		check(int(app.challenges.outcome.completed_tracks) == stage+1,"verified aggregate advances only after the actual track result")
		await capture("multi-feedback-"+str(stage),app)
	var budgets: Array = []
	for stage: Dictionary in app.challenges.selected.stages: budgets.append(int(stage.attempts_used))
	check(budgets == [2,1,1],"server confirms independent tries across first race, retry and track switches")
	var own: Dictionary = {}
	for row: Dictionary in app.challenges.selected.standings:
		if str(row.id) == str(app.online.client.player.id): own = row
	check(int(own.completed_tracks) == 3 and own.ticks != null,"all three accepted tracks produce one verified total")
	app.queue_free()
	await process_frame
	print("CHALLENGE_MULTI_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
