extends SceneTree
## Whole native creation/join/race/results/rematch flow against a disposable HTTP backend.
var checks: int = 0
var failures: int = 0
var fixture: Dictionary

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
		create_timer(120.0).timeout.connect(func() -> void:
			print("FAIL: challenge HTTP integration deadline")
			quit(1)))

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+detail)

func run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var folder: String = "user://challenge_http_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var login: Dictionary = await app.online.client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"creator signs into the disposable development backend")
	var catalogue: Dictionary = await app.online.client.request_api("/tracks?limit=20")
	check(catalogue.ok and not catalogue.data.items.is_empty(),"published canonical track is available")
	var metadata: Dictionary = catalogue.data.items[0]
	var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
	check(await app.cloud.download(entry),"exact published track downloads and passes integrity checks")
	var track: NativeTrack = app.cloud.compile_entry(entry)
	app.selected_track = track
	var seed_flow: bool = OS.get_environment("BMT_CHALLENGE_SEED_FLOW") == "true"
	# Establish a faster verified PB first: the challenge must still use the slower finish below.
	if not seed_flow:
		await app._start_race(track,false)
		var prior_ticket: String = str(app.cloud_ticket.get("ticket_id",""))
		_drive(app.game,fixture.replay.frames)
		app._results()
		var prior_status: Dictionary = {}
		for _poll: int in range(60):
			prior_status = await app.challenges.source(str(metadata.version_id),"compact",prior_ticket)
			if prior_status.get("status") == "verified": break
			await create_timer(0.15).timeout
		check(prior_status.get("status") == "verified","a real recorded faster PB is verified before the slower source race")
		app._clear_challenge_game()
	if seed_flow:
		app.cloud.entries.assign([metadata])
		app._open_challenges()
		while app.challenges.busy: await process_frame
		app._create_challenge_dialog(str(metadata.version_id),"compact")
		var draft: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
		while draft._checking: await process_frame
		check(draft.get_ok_button().disabled and draft._race.visible,"new creator is offered a race instead of an invented target")
		draft._choose_duration(86400)
		draft._choose_attempt_limit(3)
		draft._race.pressed.emit()
		while app.game == null: await process_frame
	else: await app._start_race(track,false)
	check(app.game != null and not app.rivalry_racing and not app.challenge_racing,"source run uses normal race mode")
	if app.game == null:
		print(app.cloud.last_error)
		quit(1)
		return
	var slower: Array = []
	for _tick: int in range(60): slower.append([0,0,0])
	slower.append_array(fixture.replay.frames)
	_drive(app.game,slower)
	check(app.game.track_session.finished,"creator completes a real five-lap race")
	var ticket_id: String = str(app.cloud_ticket.get("ticket_id",""))
	app._results()
	var summary: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	check(summary != null and summary.find_child("CreateResultChallenge",true,false) != null,"normal results offer creation while keeping PB/lap summary first")
	if seed_flow:
		summary.continue_requested.emit()
		check(app.game == null and app.root_ui.find_child("ChallengeCreate",true,false) != null,"source-race Continue returns to creation after showing normal results")
	check(not ticket_id.is_empty(),"source run retains its authenticated upload identity")
	var source: Dictionary = {}
	for _poll: int in range(60):
		source = await app.challenges.source(str(metadata.version_id),"compact",ticket_id)
		if source.get("status") == "verified": break
		await create_timer(0.15).timeout
	check(source.get("status") == "verified","canonical worker verifies the source run")
	if not seed_flow: (summary.find_child("CreateResultChallenge",true,false) as Button).pressed.emit()
	var form: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
	var wait_started: int = Time.get_ticks_msec()
	while is_instance_valid(form) and (form._checking or form._source.get("status") != "verified") and Time.get_ticks_msec()-wait_started < 12000:
		await process_frame
	check(form != null and not form.get_ok_button().disabled,"creation form preselects the just-finished verified time")
	check(form.locked_result() and form._track == null and form._vehicle == null and form._search == null and not form._race.visible,"finished-race creation is fixed and contains no rerace or unrelated selectors")
	check(app.screen == "challenge_create" and app.root_ui.find_child("MenuHeader",true,false) != null,"creation occupies the main menu under its original navigation")
	if not seed_flow:
		var saved_summary: RaceResults = app._challenge_return_ui.find_child("RaceResults",true,false)
		form.close()
		check(app.root_ui.find_child("RaceResults",true,false) == saved_summary,"Cancel restores the same completed summary without reracing or recording twice")
		(saved_summary.find_child("CreateResultChallenge",true,false) as Button).pressed.emit()
		form = app.root_ui.find_child("ChallengeCreate",true,false)
		while form._checking: await process_frame
		form._choose_attempt_limit(3)
	await capture("create",app)
	await capture("create-after-seed" if seed_flow else "create-from-results",app)
	form.confirmed.emit()
	while app.challenges.busy or (is_instance_valid(form) and form._submitting): await process_frame
	check(not app.challenges.selected.is_empty(),"Create & share persists a real server challenge")
	if app.challenges.selected.is_empty():
		print(app.challenges.error)
		quit(1)
		return
	var invitation: Dictionary = app.challenges.selected.duplicate(true)
	var code: String = str(invitation.code)
	check(invitation.attempt_limit == 3,"selected attempt limit survives creation and the race-first return")
	check(int(invitation.target_ticks) > int(fixture.time_ticks),"target pins the creator's actual slower run")
	if seed_flow: check(int(invitation.ends_at)-int(invitation.created_at) == 86400,"race-to-set flow preserves the chosen 24-hour duration")
	await capture("sent",app)
	for popup: Node in app.root_ui.get_children():
		if popup is AcceptDialog: popup.queue_free()
	await app.online.client.logout()
	app._receive_challenge(code)
	while app.challenges.busy: await process_frame
	check(not app.challenges.selected.is_empty() and not app.challenges.selected.joined,"guest opens invitation without signing in")
	await app._start_challenge_race()
	check(app.game != null and app.challenge_practice and not app.challenge_racing and app.cloud_ticket.is_empty(),"guest tries the track without a competitive ticket or sign-in gate")
	_drive(app.game,fixture.replay.frames)
	app._results()
	var guest_summary: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	guest_summary.continue_requested.emit()
	check(app.game == null and app.screen == "challenges" and not app.challenges.selected.joined,"guest summary returns to the invitation without creating a competitive result")
	var nonce: Dictionary = await app.online.client.google_challenge()
	var recipient: Dictionary = await app.online.client.google_login("challenge-fixture:"+str(nonce.data.nonce),str(nonce.data.challenge_id),"Challenge Racer")
	check(recipient.ok,"second isolated identity authenticates through the nonce-bound test provider")
	await app.challenges.open(code)
	app._open_challenges()
	while app.challenges.busy: await process_frame
	await app._start_challenge_race()
	check(app.game != null and app.challenge_racing and not app.rivalry_racing,"Join & race starts a challenge-bound canonical attempt")
	if app.game == null:
		print(app.challenges.error)
		quit(1)
		return
	check(app.game.ghost_mode == "race" and not app.game.ghost_bests.get("race",{}).is_empty(),"recipient races the actual verified creator ghost")
	check(not app.game.ghost_bests.race.has("frames"),"opponent raw inputs stay private")
	_drive(app.game,fixture.replay.frames)
	check(app.game.track_session.finished,"recipient completes all five ordered laps")
	app._results()
	summary = app.root_ui.find_child("RaceResults",true,false)
	check(summary != null and not app.challenge_result_view,"normal PB/lap results precede challenge feedback")
	check(summary.mode_buttons.size() == 3 and not summary.mode_buttons.any(func(button: Button) -> bool: return button.text == "Compare"),"normal results retain exactly Track/Sectors/Speed without Compare")
	summary.select_lap(1)
	check(summary.map.visible,"selecting a lap retains its analysis")
	var previous_ticks: Variant = app.challenges.selected.standings[-1].ticks
	check(previous_ticks == null,"unverified local time does not enter challenge standings")
	await capture("normal-results",app)
	var started: int = Time.get_ticks_msec()
	summary.continue_requested.emit()
	check(app.screen == "challenges" and app.challenge_result_view and Time.get_ticks_msec()-started < 1000,"Continue opens challenge feedback without waiting for verification")
	for _poll: int in range(120):
		await app.challenges.poll_result()
		if app.challenges.result_state == "verified": break
		await create_timer(0.15).timeout
	check(app.challenges.result_state == "verified" and app.challenges.outcome.get("beaten",false),"server confirms recipient beat the fixed target")
	check(int(app.challenges.outcome.gap_ms) < 0,"verified outcome carries a signed negative gap")
	await capture("verified-result",app)
	await app._retry_race()
	check(app.challenge_racing and not app.cloud_ticket.is_empty() and app.game.online_frames.is_empty(),"Race again obtains a fresh challenge ticket and clears prior inputs")
	check(not app.game.ghost_bests.get("race",{}).is_empty(),"retry retains the frozen creator target ghost")
	app._leave_race()
	check(app.game == null and app.screen == "challenges","leaving a challenge race returns to Challenges")
	await app.challenges.rematch()
	check(app.challenges.selected.code != code and app.challenges.selected.creator_id == app.online.client.player.id,"winner creates a reverse invitation from their own verified run")
	check(int(app.challenges.selected.target_ticks) == int(fixture.time_ticks),"rematch target equals the recipient's canonically verified time")
	app._create_challenge_dialog(str(metadata.version_id),"compact")
	var group_form: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
	group_form._choose_mode(1)
	group_form._search.text = str(metadata.name)
	group_form._search_timer.stop()
	await group_form._find_tracks()
	while group_form._checking: await process_frame
	check(not group_form.entries.is_empty() and str(group_form.entries[0].version_id) == str(metadata.version_id),"creation searches the global published catalog")
	check(not group_form.get_ok_button().disabled,"group creation works independently of a target time")
	group_form.confirmed.emit()
	while app.challenges.busy or (is_instance_valid(group_form) and group_form._submitting): await process_frame
	check(app.challenges.selected.mode == "group" and app.challenges.selected.target_ticks == null and app.challenges.selected.standings[0].ticks == null,"new group has no invented target or historical attempt score")
	for popup: Node in app.root_ui.get_children():
		if popup is AcceptDialog: popup.queue_free()
	await app._start_challenge_race()
	check(app.game != null and app.challenge_racing,"group creator can start a verified group attempt")
	_drive(app.game,fixture.replay.frames)
	app._results()
	var group_summary: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	group_summary.continue_requested.emit()
	for _poll: int in range(120):
		await app.challenges.poll_result()
		if app.challenges.result_state == "verified": break
		await create_timer(0.15).timeout
	check(app.challenges.result_state == "verified" and int(app.challenges.outcome.after.rank) == 1,"group attempt enters one verified best for its actual driver")
	await capture("group-verified",app)
	app._leave_race()
	await app.online.client.logout()
	check(app.challenges.items.is_empty() and app.challenges.result_ticket.is_empty(),"logout clears private challenge standings and polling")
	app.queue_free()
	await process_frame
	await process_frame
	print("CHALLENGES_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _drive(game: Node, frames: Array) -> void:
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.launch_countdown_seen = false
	game.launch_early = false
	var driver := ReplayInput.new()
	driver.frames = frames
	game.driver = driver
	for _tick: int in range(frames.size()): game._physics_process(1.0/120.0)

func capture(label: String, _app: Node) -> void:
	var directory: String = OS.get_environment("BMT_CAPTURE_CLOUD")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,"HTTP flow capture saves: "+label)
