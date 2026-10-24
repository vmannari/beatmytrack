extends "res://tests/test_rivalry_start_failure.gd"
## Real App/Game/contract validation with isolated challenge transport and storage.

class FlowApp extends "res://core/app.gd":
	var storage_blocked: bool = false
	func _save_result_upload(_completed_game: Node, _ticket_data: Dictionary, _frames: Array, _publish_version: String, _rewinds: Array) -> void:
		if not storage_blocked: cloud_ticket = {}
	func _try_race_ad(_finished_game: int, _panel: Control) -> void: pass

class Transport extends "res://backend/backend_client.gd":
	signal released
	var tickets: Array[Dictionary] = []
	var ghosts: Array[int] = []
	var manifests: Array[Dictionary] = []
	var budgets: Array[int] = [3,3,3]
	var held: String = ""
	var fail: bool = false
	var corrupt: bool = false
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		var stage: int = int(path.get_slice("stage=",1)) if path.contains("stage=") else 0
		if path.contains("/tickets"):
			tickets.append({"stage":stage,"code":path.get_slice("/",2)})
			if held == "ticket": await released
			if fail: return {"ok":false,"error":"NETWORK_ERROR"}
			if budgets[stage] <= 0: return {"ok":false,"error":"No tries remaining"}
			budgets[stage] -= 1
			var contract: Dictionary = manifests[stage].duplicate(true)
			if corrupt: contract.track_content_hash = "different-track"
			return {"ok":true,"data":{"ticket_id":"flow-ticket-"+str(tickets.size()),"challenge_code":path.get_slice("/",2),"manifest":contract,"expires_at":9999999999,"attempt_limit":3,"attempts_used":3-budgets[stage],"attempts_remaining":budgets[stage]}}
		if path.contains("/ghost"):
			ghosts.append(stage)
			if held == "ghost": await released
			return {"ok":true,"data":{"recording":{}}}
		return {"ok":false,"error":"NOT_CONFIGURED"}

class QuietChallenges extends ChallengesClient:
	func poll_result() -> void: pass
	func refresh(_more: bool = false) -> void: pass

var transport: Transport
var adapter: QuietChallenges
var tracks: Array[NativeTrack] = []
var snapshot: Dictionary

func settle() -> void:
	for frame: int in range(5): await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"save native capture "+label)

func freeze() -> void:
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		app.game.set_process(false)
		app.game.paused = true
		app.game.hud.pause_menu.hide()

func finish() -> RaceResults:
	freeze()
	app.game.attempt_practice = false
	var session := TrackSession.new()
	session.completed_laps = 5
	session.elapsed_ticks = 13200
	session.lap_start_time = 110.0
	session.lap_times.assign([23.0,22.0,22.0,22.0,21.0])
	session.finished = true
	app.game.track_session = session
	app._results()
	await settle()
	return app.root_ui.find_child("RaceResults",true,false)

func start_late(done: Dictionary) -> void:
	await app._start_challenge_race()
	done.finished = true

func retry_late(done: Dictionary) -> void:
	await app._retry_race()
	done.finished = true

func dismiss() -> void:
	var dialog: AcceptDialog = notice()
	if dialog != null: dialog.queue_free()
	await settle()

func select_fresh(index: int = 0) -> void:
	app._clear_challenge_game()
	app.cloud_ticket = {}
	app.challenge_result_view = false
	adapter.selected = snapshot.duplicate(true)
	adapter.selected_stage = index
	transport.budgets = [3,3,3]
	adapter.error = ""
	app._open_challenges(true)
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	evidence = "res://../docs/evidence/challenge-race-flows-2026-10-24/ui/"+RenderingServer.get_current_rendering_method()
	root.size = Vector2i(1280,720)
	var folder: String = "user://challenge_flows_"+TrackLibrary.unique_id()
	app = FlowApp.new()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.player = {"id":"flow-self"}
	app.online.client._access_token = "isolated-fixture"
	var cloud := CloudFixture.new()
	cloud.client = app.online.client
	cloud.root_override = folder.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	transport = Transport.new()
	transport.player = app.online.client.player.duplicate(true)
	transport._access_token = "isolated-fixture"
	app.add_child(transport)
	adapter = QuietChallenges.new()
	adapter.client = transport
	adapter.cloud = cloud
	app.add_child(adapter)
	app.challenges = adapter
	adapter.changed.connect(app._challenges_changed)
	adapter.reset()
	snapshot = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/challenge_series_v1.json"))
	snapshot.self_id = "flow-self"
	snapshot.joined = true
	snapshot.state = "active"
	snapshot.standings = []
	for index: int in range(3):
		var doc: Dictionary = TrackDocument.create_default()
		doc.name = "Flow track "+str(index+1)
		doc.points[1][0] += index*4.0
		var body: String = JSON.stringify(doc)
		var entry: Dictionary = cloud.entry_from_metadata({"name":doc.name,"creator":"Beat my track","theme":doc.theme,"track_id":"flow-track-"+str(index),"version_id":"flow-version-"+str(index),"content_hash":body.sha256_text(),"points":doc.points})
		DirAccess.make_dir_recursive_absolute(str(entry.cache_path).get_base_dir())
		var file := FileAccess.open(str(entry.cache_path),FileAccess.WRITE)
		file.store_string(body)
		file.close()
		var track: NativeTrack = Cloud.compile_entry(entry)
		tracks.append(track)
		transport.manifests.append(manifest(track))
		snapshot.stages[index].entry = entry
		snapshot.stages[index].attempts_remaining = 3
		snapshot.stages[index].attempts_used = 0
		snapshot.stages[index].standings = []
	snapshot.entry = snapshot.stages[0].entry
	adapter.selected = snapshot.duplicate(true)
	app._open_challenges(true)
	await app._start_challenge_race()
	freeze()
	check(app.game != null and app.challenge_racing and app.game.native_track.content_hash == tracks[0].content_hash,"first 3x3 start uses track one and a challenge ticket")
	var panel: RaceResults = await finish()
	check(panel != null and panel.find_child("ContinueResultChallenge",true,false) == null,"normal results remove the redundant Continue challenge button")
	await capture("normal-results")
	app._results_continue(panel,panel.get_parent())
	await settle()
	check(app.game == null and not app.challenge_racing and app.challenge_result_view,"Continue releases the finished Game before opening challenge feedback")
	adapter.select_stage(1)
	await app._start_challenge_race()
	freeze()
	check(app.game != null and app.game.native_track.content_hash == tracks[1].content_hash and app.cloud_ticket.get("ticket_id") == "flow-ticket-2","track two after feedback starts the selected track instead of retrying track one")
	check(notice() == null,"switching challenge tracks shows no verified-retry warning")
	# Keep this reproduction bounded on the old implementation.
	if failures > 0:
		app.queue_free()
		await settle()
		print("CHALLENGE_RACE_FLOWS: %d checks, %d failures" % [checks,failures])
		quit(1)
		return
	# A real retry stays on its Game's stage even if the menu selection moved.
	var second_game: Node = app.game
	adapter.select_stage(2)
	await app._retry_race()
	freeze()
	check(app.game == second_game and transport.tickets[-1].stage == 1 and transport.ghosts[-1] == 1,"retry pins both ticket and ghost to the original stage")
	check(transport.budgets == [2,1,3],"retry spends only the original track's next try")
	panel = await finish()
	app._results_continue(panel,panel.get_parent())
	await settle()
	await app._start_challenge_race()
	freeze()
	check(app.game.native_track.content_hash == tracks[2].content_hash and transport.tickets[-1].stage == 2,"third track starts from challenge feedback")
	panel = await finish()
	app._results_continue(panel,panel.get_parent())
	await settle()
	await capture("three-track-feedback")
	# Starts from feedback and ordinary detail both prepare their selected track.
	adapter.select_stage(0)
	await app._start_challenge_race()
	freeze()
	check(app.game.native_track.content_hash == tracks[0].content_hash,"switching back to the first track starts its own remaining attempt")
	# One lock covers ticket acceptance and the entire optional ghost await.
	transport.held = "ghost"
	var requests: int = transport.tickets.size()
	var pending: Dictionary = {"finished":false}
	retry_late(pending)
	while transport.ghosts[-1] != 0 or transport.tickets.size() == requests: await process_frame
	await settle()
	check(app.cloud_starting and not pending.finished,"retry stays locked while its ghost is pending")
	await app._retry_race()
	await app._start_challenge_race()
	check(transport.tickets.size() == requests+1,"repeated retry and Race presses cannot reserve another try during ghost loading")
	transport.held = ""
	transport.released.emit()
	while not pending.finished: await process_frame
	freeze()
	check(not app.cloud_starting and app.cloud_ticket.get("ticket_id") == "flow-ticket-"+str(transport.tickets.size()),"one accepted retry is installed after its ghost completes")
	requests = transport.tickets.size()
	await app._retry_race()
	check(transport.tickets.size() == requests+1 and notice() != null and notice().dialog_text.contains("No tries remaining"),"exhausted track rejects a restart with an actionable reason")
	await dismiss()
	adapter.selected.state = "complete"
	requests = transport.tickets.size()
	await app._retry_race()
	check(transport.tickets.size() == requests and notice().dialog_text.contains("Challenge ended"),"ended challenge rejects a retry without requesting a ticket")
	await dismiss()
	await select_fresh(1)
	await app._start_challenge_race()
	freeze()
	transport.fail = true
	await app._retry_race()
	check(notice() != null and notice().dialog_text.contains("Check your connection") and not app.cloud_starting,"network failure reports its reason and releases the retry lock")
	await dismiss()
	transport.fail = false
	transport.corrupt = true
	await app._retry_race()
	check(notice() != null and notice().dialog_text.contains("Track differs from the server"),"contract failure reports Cloud's actual reason instead of an empty challenge error")
	await dismiss()
	transport.corrupt = false
	adapter.selected.code = "CD12CD34EF56AB78"
	requests = transport.tickets.size()
	await app._retry_race()
	check(transport.tickets.size() == requests and notice() != null,"a retained Game cannot retry against another invitation")
	await dismiss()
	# Delayed requests must not resurrect abandoned races or apply a stale budget.
	await select_fresh()
	await app._start_challenge_race()
	freeze()
	transport.held = "ghost"
	pending = {"finished":false}
	requests = transport.tickets.size()
	retry_late(pending)
	while transport.tickets.size() == requests: await process_frame
	await settle()
	app._leave_race()
	transport.held = ""
	transport.released.emit()
	while not pending.finished: await process_frame
	check(app.game == null and not app.cloud_starting,"leaving during retry ghost loading cannot revive the race")
	await select_fresh()
	transport.held = "ticket"
	pending = {"finished":false}
	requests = transport.tickets.size()
	start_late(pending)
	while transport.tickets.size() == requests: await process_frame
	adapter.selected = snapshot.duplicate(true)
	adapter.selected.code = "CD12CD34EF56AB78"
	transport.held = ""
	transport.released.emit()
	while not pending.finished: await process_frame
	check(app.game == null and adapter.selected.stages[0].attempts_remaining == 3 and not app.cloud_starting,"changing invitation discards a delayed ticket without changing the new invitation's budget")
	await select_fresh()
	transport.held = "ticket"
	pending = {"finished":false}
	requests = transport.tickets.size()
	start_late(pending)
	while transport.tickets.size() == requests: await process_frame
	adapter.select_stage(2)
	transport.held = ""
	transport.released.emit()
	while not pending.finished: await process_frame
	check(app.game == null and adapter.selected.stages[2].attempts_remaining == 3 and not app.cloud_starting,"changing stage while connecting does not launch the old stage or debit the new stage")
	await select_fresh()
	transport.held = "ticket"
	pending = {"finished":false}
	requests = transport.tickets.size()
	start_late(pending)
	while transport.tickets.size() == requests: await process_frame
	app.online.client.player = {"id":"replacement-account"}
	transport.player = app.online.client.player.duplicate(true)
	transport.held = ""
	transport.released.emit()
	while not pending.finished: await process_frame
	check(app.game == null and not app.cloud_starting,"account change discards an in-flight challenge start")
	app.online.client.player = {"id":"flow-self"}
	transport.player = app.online.client.player.duplicate(true)
	adapter.reset()
	# Do not discard the only completed recording when local queue admission fails.
	await select_fresh()
	await app._start_challenge_race()
	app.storage_blocked = true
	panel = await finish()
	var finished_game: Node = app.game
	app._results_continue(panel,panel.get_parent())
	check(app.game == finished_game and not app.cloud_ticket.is_empty(),"failed result storage keeps the finished Game and its original ticket")
	app.storage_blocked = false
	app._results_continue(panel,panel.get_parent())
	check(app.game == null and app.cloud_ticket.is_empty(),"Continue can transfer the result after storage recovers")
	await select_fresh()
	adapter.selected.joined = false
	await app._start_challenge_race()
	await settle()
	var join_button: Button = app.root_ui.find_child("ChallengeRace",true,false)
	check(app.game == null and not app.cloud_starting and join_button != null and not join_button.disabled,"failed join restores a usable Join & race action")
	for mode: String in ["beat","group"]:
		await select_fresh()
		adapter.selected.erase("stages")
		adapter.selected.mode = mode
		adapter.selected.creator_id = "another-driver"
		await app._start_challenge_race()
		freeze()
		var original_game: Node = app.game
		requests = transport.tickets.size()
		await app._retry_race()
		freeze()
		check(app.game == original_game and app.challenge_racing and transport.tickets.size() == requests+1,"authenticated "+mode+" challenge retries with a fresh ticket on the same Game")
		panel = await finish()
		app._results_continue(panel,panel.get_parent())
		check(app.game == null and app.challenge_result_view,"authenticated "+mode+" result returns to feedback without retaining a race")
	# Guest starts and retries stay local for both single and multi-track challenges.
	for single: bool in [false,true]:
		await select_fresh(1 if not single else 0)
		if single:
			adapter.selected.erase("stages")
			adapter.selected.mode = "group"
		adapter.selected.joined = false
		app.online.client._access_token = ""
		transport._access_token = ""
		requests = transport.tickets.size()
		await app._start_challenge_race()
		freeze()
		check(app.game != null and app.challenge_practice and not app.challenge_racing and app.cloud_ticket.is_empty(),"guest can try "+("single" if single else "multi-track")+" challenge locally")
		await app._retry_race()
		freeze()
		check(transport.tickets.size() == requests and app.cloud_ticket.is_empty(),"guest retry spends no competitive try")
		panel = await finish()
		app._results_continue(panel,panel.get_parent())
		check(app.game == null and not app.challenge_practice,"guest Continue returns to challenge selection")
		app.online.client._access_token = "isolated-fixture"
		transport._access_token = "isolated-fixture"
	app.queue_free()
	await settle()
	print("CHALLENGE_RACE_FLOWS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
