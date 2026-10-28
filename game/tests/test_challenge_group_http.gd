extends "res://tests/test_challenges_http.gd"
## Complete group creation from results, three real accounts and independent tries.
var group_app: Node
var group_code: String

func wait_idle() -> void:
	while group_app.challenges.busy: await process_frame
	for frame: int in range(3): await process_frame

func close_popups() -> void:
	for popup: Node in group_app.root_ui.get_children():
		if popup is AcceptDialog: popup.queue_free()

func own_row(player_id: String) -> Dictionary:
	for row: Dictionary in group_app.challenges.selected.get("standings",[]):
		if row.id == player_id: return row
	return {}

func guest_state_is_clear() -> bool:
	var selected: Dictionary = group_app.challenges.selected
	# Public invitations can be selected again by the guest discovery refresh.
	return group_app.challenges.result_ticket.is_empty() and group_app.challenges.result_state.is_empty() and group_app.challenges.outcome.is_empty() and (selected.is_empty() or (str(selected.get("self_id","guest")) == "" and not selected.get("joined",true)))

func login_member(label: String, username: String) -> String:
	await group_app.online.client.logout()
	await wait_idle()
	check(guest_state_is_clear(),"logout clears the previous member's private result and membership")
	var nonce: Dictionary = await group_app.online.client.google_challenge()
	var answer: Dictionary = await group_app.online.client.google_login(label+":"+str(nonce.data.nonce),str(nonce.data.challenge_id),username)
	check(answer.ok,"independent group member signs in: "+label)
	await accept_public_rules(group_app.online.client)
	group_app._receive_challenge(group_code)
	await wait_idle()
	check(group_app.challenges.selected.get("code") == group_code and not group_app.challenges.selected.joined,"new member opens the same group invitation: "+label)
	return str(group_app.online.client.player.id)

func complete(frames: Array, label: String) -> Dictionary:
	var ticket: String = str(group_app.cloud_ticket.get("ticket_id",""))
	_drive(group_app.game,frames)
	check(group_app.game.track_session.finished,label+" completes five ordered laps")
	group_app._results()
	var summary: RaceResults = group_app.root_ui.find_child("RaceResults",true,false)
	check(summary != null and not group_app.challenge_result_view,label+" shows ordinary results before group feedback")
	summary.continue_requested.emit()
	check(group_app.game == null and group_app.challenge_result_view,label+" Continue releases the race and opens group feedback")
	for poll: int in range(120):
		await group_app.challenges.poll_result()
		if group_app.challenges.result_state == "verified": break
		await create_timer(0.15).timeout
	check(group_app.challenges.result_state == "verified" and group_app.challenges.result_ticket == ticket,label+" receives its own verified result")
	return group_app.challenges.outcome.duplicate(true)

func delayed(frames: Array, ticks: int) -> Array:
	var result: Array = []
	for tick: int in range(ticks): result.append([0,0,0])
	result.append_array(frames)
	return result

func run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var folder: String = "user://group_http_"+TrackLibrary.unique_id()
	group_app = load("res://core/app.tscn").instantiate()
	group_app.library = TrackLibrary.new(folder.path_join("tracks"))
	group_app.records = LocalRecords.new(folder.path_join("records.json"))
	group_app.cloud_root_override = folder.path_join("cloud")
	root.add_child(group_app)
	while not group_app.startup_complete: await process_frame
	var creator_login: Dictionary = await group_app.online.client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(creator_login.ok,"group creator signs into the disposable service")
	await accept_public_rules(group_app.online.client)
	var creator: String = str(group_app.online.client.player.id)
	var catalogue: Dictionary = await group_app.online.client.request_api("/tracks?limit=20")
	var metadata: Dictionary = catalogue.data.items[0]
	var entry: Dictionary = group_app.cloud.entry_from_metadata(metadata)
	check(await group_app.cloud.download(entry),"group's pinned track downloads with integrity validation")
	group_app.selected_track = group_app.cloud.compile_entry(entry)
	await group_app._start_race(group_app.selected_track,false)
	var source_ticket: String = str(group_app.cloud_ticket.ticket_id)
	_drive(group_app.game,delayed(fixture.replay.frames,60))
	check(group_app.game.track_session.finished,"creator completes the group opening race")
	group_app._results()
	var summary: RaceResults = group_app.root_ui.find_child("RaceResults",true,false)
	(summary.find_child("CreateResultChallenge",true,false) as Button).pressed.emit()
	var form: ChallengeCreate = group_app.root_ui.find_child("ChallengeCreate",true,false)
	check(form.results_only and form._step == ChallengeCreate.RESULT,"group creation enters the restricted results setup")
	(form.find_child("ChallengeResultMode_1",true,false) as Button).pressed.emit()
	(form.find_child("ChallengeDuration_86400",true,false) as Button).pressed.emit()
	(form.find_child("ChallengeTries_3",true,false) as Button).pressed.emit()
	for poll: int in range(120):
		if not form._checking and form._source.get("status") == "verified": break
		if not form._checking: form._check_source()
		await create_timer(0.15).timeout
	check(form.initial_ticket == source_ticket and not form.get_ok_button().disabled,"group setup uses the exact verified opening ticket")
	form.get_ok_button().pressed.emit()
	while group_app.challenges.busy or (is_instance_valid(form) and form._submitting): await process_frame
	check(not group_app.challenges.selected.is_empty(),"results setup creates a real group invitation")
	if group_app.challenges.selected.is_empty():
		print(group_app.challenges.error)
		quit(1)
		return
	var invitation: Dictionary = group_app.challenges.selected.duplicate(true)
	group_code = invitation.code
	check(invitation.mode == "group" and invitation.capacity == 20 and invitation.target_ticks == null,"group has twenty-player capacity and no duel target")
	check(int(invitation.ends_at)-int(invitation.created_at) == 86400 and invitation.attempt_limit == 3,"selected group duration and tries persist")
	check(invitation.attempts_used == 1 and invitation.attempts_remaining == 2 and invitation.standings.size() == 1,"opening source counts exactly one creator try")
	check(int(invitation.standings[0].ticks) == int(fixture.time_ticks)+60,"group retains the exact completed source time")
	check(group_app.game == null and not group_app.challenge_racing,"Create & share finishes without starting another race")
	close_popups()
	await capture("group-created-from-results",group_app)

	var first: String = await login_member("group-first","Group First")
	await group_app._start_challenge_race()
	check(group_app.game != null and group_app.challenge_racing and not group_app.challenge_practice,"first member joins and starts a verified group attempt")
	check(group_app.challenges.selected.attempts_used == 1 and group_app.challenges.selected.attempts_remaining == 2,"first member has an independent three-start budget")
	check(not group_app.game.ghost_bests.get("race",{}).is_empty() and not group_app.game.ghost_bests.race.has("frames"),"member receives the actual group ghost without raw controls")
	var outcome: Dictionary = await complete(fixture.replay.frames,"first member")
	var first_best: Dictionary = own_row(first).duplicate(true)
	check(int(first_best.ticks) == int(fixture.time_ticks) and first_best.rank == 1 and own_row(creator).rank == 2,"faster member moves above the opening creator")
	check(outcome.get("counted",false) and outcome.get("improved",false),"verified member result counts as its best")
	check(group_app.challenges.selected.rewards.finish_earned,"verified group finish earns its authoritative finish reward")
	await capture("group-first-member",group_app)
	await group_app._start_challenge_race()
	check(group_app.challenges.selected.attempts_remaining == 1,"slower retry reserves only this member's second start")
	outcome = await complete(delayed(fixture.replay.frames,30),"slower retry")
	check(not outcome.get("improved",true) and own_row(first).run_id == first_best.run_id and own_row(first).ticks == first_best.ticks,"slower retry preserves the member's verified best")
	await group_app._start_challenge_race()
	check(group_app.challenges.selected.attempts_remaining == 0,"third start exhausts only this member's budget")
	outcome = await complete(fixture.replay.frames,"tied retry")
	check(not outcome.get("improved",true) and own_row(first).run_id == first_best.run_id,"tied retry preserves the original best run")
	var race_button: Button = group_app.root_ui.find_child("ChallengeRace",true,false)
	check(race_button != null and race_button.disabled,"group feedback disables racing when this member has no tries")
	var denied: Dictionary = await group_app.online.client.request_api("/challenges/"+group_code+"/tickets",HTTPClient.METHOD_POST,{},group_app.online.client.new_operation_key(),true)
	check(not denied.ok and int(denied.get("status",0)) == 409,"server rejects an extra start after the group budget is exhausted")

	var second: String = await login_member("group-second","Group Second")
	check(second != first and second != creator,"third participant is a distinct real fixture account")
	await group_app._start_challenge_race()
	check(group_app.game != null and group_app.challenge_racing and group_app.challenges.selected.attempts_remaining == 2,"second member can join and race despite the first member's exhausted budget")
	await complete(delayed(fixture.replay.frames,120),"second member")
	check(own_row(first).rank == 1 and own_row(creator).rank == 2 and own_row(second).rank == 3,"three-driver standings order the actual verified times")
	check(group_app.challenges.selected.standings.size() == 3 and own_row(first).run_id == first_best.run_id,"group retains exactly one best per member")
	check(group_app.challenges.selected.attempts_used == 1 and group_app.challenges.selected.attempts_remaining == 2,"second member's own remaining tries stay independent")
	await group_app.challenges.join()
	check(group_app.challenges.selected.standings.size() == 3,"repeated join creates no duplicate group membership")
	await capture("group-three-members",group_app)
	await group_app.online.client.logout()
	await wait_idle()
	check(guest_state_is_clear(),"final logout clears the member's private result and polling")
	group_app.queue_free()
	for frame: int in range(3): await process_frame
	print("CHALLENGE_GROUP_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
