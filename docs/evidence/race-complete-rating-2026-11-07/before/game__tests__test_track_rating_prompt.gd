extends SceneTree
## Actual race finish/App results flow; fictional backend and isolated records only.
const Base = preload("res://tests/test_free_race_restart.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Vote = preload("res://backend/finish_rating.gd")
var checks: int = 0
var failures: int = 0
var capture_dir: String = ""

class VoteClient extends Base.TicketClient:
	var score: int = 0
	var eligible: bool = false
	var hold_read: bool = false
	var hold_save: bool = false
	var fail_save: bool = false
	var fail_read: bool = false
	var reads: int = 0
	var saves: int = 0
	var last_key: String = ""
	func signed_in() -> bool: return not player.is_empty()
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if not path.ends_with("/rating"):
			return {"ok":true,"data":{"free":1,"balance":0,"ad_preview_available":true,"ads_available":false,"purchases_available":false}}
		reads += 1
		var answer: Dictionary = {"ok":true,"data":{"score":score,"eligible":eligible}}
		while hold_read: await get_tree().process_frame
		if fail_read: return {"ok":false,"data":{}}
		return answer
	func rate_track(_version: String, value: int, key: String) -> Dictionary:
		saves += 1
		last_key = key
		while hold_save: await get_tree().process_frame
		if fail_save: return {"ok":false,"error":"Unavailable"}
		score = value
		return {"ok":true,"data":{"score":score}}

class RaceCloud extends Cloud:
	var queued: int = 0
	func enqueue_completed(_ticket: Dictionary, _frames: Variant, _publish: String = "", _rewinds: Array = []) -> bool:
		queued += 1
		return true

class FailedRecords extends LocalRecords:
	func save_records() -> Error: return ERR_CANT_CREATE

class RivalrySync extends Node:
	signal changed
	var result_state: String = ""

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)
func frames() -> void:
	for i: int in range(5): await process_frame
func click(button: Button) -> void:
	var down := InputEventMouseButton.new()
	down.position = button.get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down,true)
	var up := InputEventMouseButton.new()
	up.position = down.position
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up,true)
func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(1.5).timeout
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label+".png")) == OK,"capture "+label)
func drive(game: Node) -> void:
	game.set_physics_process(false)
	game.countdown_ticks = 0
	var driver := RouteDriver.new()
	for tick: int in range(36000):
		var frame: DriveFrame = driver.sample(game.sim.state,game.native_track,game.handling)
		var before: Vector2 = game.sim.state.position
		game.sim.step(frame,game.native_track)
		game.track_session.advance(game.native_track,before,game.sim.state.position,game.sim.state.route_index,game.sim.state.track_elevated)
		game.lap_telemetry.observe(game.track_session,game.native_track,game.sim.state.position,game.sim.state.velocity.length(),false)
		game.online_frames.append(preload("res://race/input_record.gd").pack(frame))
		if game.track_session.finished: break
	check(game.track_session.finished and game.track_session.completed_laps == 5,"actual canonical driving completes all five ordered laps")
	game._begin_finish()
	for tick: int in range(90): game._physics_process(1.0/120.0)

func prepare_vote(client: Node, cloud: Node, version: String = "handoff-version") -> Node:
	var vote := Vote.new()
	vote.client = client
	vote.sync = cloud
	vote.version = version
	cloud.add_child(vote)
	return vote

func filled(row: TrackRating, score: int) -> bool:
	for index: int in range(row.stars.size()):
		if row.stars[index].icon != MenuIcon.texture("star_filled" if index < score else "star"): return false
	return true

func result_vote_updates(client: VoteClient, cloud: Node, store: LocalRecords) -> void:
	client.score = 0
	client.eligible = true
	client.hold_save = true
	var saving: Variant = prepare_vote(client,cloud)
	saving.choose(4)
	await frames()
	var reads: int = client.reads
	var row := TrackRating.new()
	row.records = store
	row.cloud_client = client
	row.cloud_sync = cloud
	row.cloud_version = saving.version
	row.finish_vote = saving
	root.add_child(row)
	check(filled(row,4) and row.value() == 0,"results display the selected stars immediately while the confirmed score remains zero")
	check(row.locked and client.reads == reads,"pending results share the existing vote without a duplicate rating GET")
	client.hold_save = false
	await frames()
	check(not is_instance_valid(saving) and row.value() == 4 and filled(row,4),"visible results retain confirmed stars after the background vote exits")
	check(not row.locked and row.caption.text == "Rate the track","saved results remain editable with one stable label")
	row.queue_free()
	await frames()
	for state: String in ["unqualified","unavailable","signed-out"]:
		client.eligible = false
		client.fail_read = state == "unavailable"
		var player: Dictionary = client.player.duplicate()
		if state == "signed-out": client.player = {}
		row = TrackRating.new()
		row.records = store
		row.cloud_client = client
		row.cloud_sync = cloud
		row.cloud_version = "label-version"
		root.add_child(row)
		await frames()
		check(row.caption.text == "Rate the track" and row.locked,"rating label stays stable when "+state)
		row.queue_free()
		client.player = player
		await frames()
	client.fail_read = false

func handoff_races(client: VoteClient, cloud: Node) -> void:
	client.score = 0
	client.eligible = true
	client.hold_save = true
	var saving: Variant = prepare_vote(client,cloud)
	saving.choose(4)
	await frames()
	client.hold_read = true
	var reading: Node = prepare_vote(client,cloud)
	check(reading.loading and not reading.known,"next attempt can still be reading its pre-save zero")
	client.hold_save = false
	await frames()
	check(not is_instance_valid(saving) and reading.score == 4 and not reading.should_prompt(),"successful save reaches an attempt whose old GET is still pending")
	client.hold_read = false
	await frames()
	check(not reading.loading and reading.score == 4 and not reading.should_prompt(),"late pre-save zero cannot erase the server-confirmed rating")
	reading.abandon()
	await frames()
	# Confirmations are limited to the same server, account and immutable version.
	client.score = 0
	client.hold_save = true
	saving = prepare_vote(client,cloud)
	saving.choose(2)
	await frames()
	var matching: Node = prepare_vote(client,cloud)
	var other_version: Node = prepare_vote(client,cloud,"other-handoff-version")
	var other_account := VoteClient.new()
	other_account.configure(client.base_url())
	other_account.player = {"id":"other-handoff-player"}
	cloud.add_child(other_account)
	var account_vote: Node = prepare_vote(other_account,cloud)
	var other_origin := VoteClient.new()
	other_origin.configure("http://127.0.0.1:18182")
	other_origin.player = client.player.duplicate()
	cloud.add_child(other_origin)
	var origin_vote: Node = prepare_vote(other_origin,cloud)
	client.hold_save = false
	await frames()
	check(matching.score == 2 and not matching.should_prompt(),"confirmed save updates the matching attempt")
	check(other_version.score == 0 and other_version.should_prompt(),"confirmed save leaves another immutable version unrated")
	check(account_vote.score == 0 and account_vote.should_prompt(),"confirmed save leaves another account unrated")
	check(origin_vote.score == 0 and origin_vote.should_prompt(),"confirmed save leaves another server unrated")
	for vote: Node in [matching,other_version,account_vote,origin_vote]: vote.abandon()
	other_account.queue_free()
	other_origin.queue_free()
	await frames()
	# A failed request cannot turn the selected stars into a confirmed rating.
	client.score = 0
	client.fail_save = true
	client.hold_save = true
	saving = prepare_vote(client,cloud)
	saving.choose(5)
	await frames()
	matching = prepare_vote(client,cloud)
	check(not matching.should_prompt(),"in-flight selection suppresses the next attempt before failure is known")
	client.hold_save = false
	await frames()
	check(not is_instance_valid(saving) and matching.score == 0 and matching.should_prompt(),"failed save keeps the waiting attempt unrated and eligible for a later prompt")
	matching.abandon()
	client.fail_save = false
	await frames()

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-rating="): capture_dir = ProjectSettings.globalize_path(arg.trim_prefix("--capture-rating="))
	var folder: String = ProjectSettings.globalize_path("res://../build/instant-rating-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var client := VoteClient.new()
	client.document = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	client.configure("http://127.0.0.1:18181")
	client.player = {"id":"fictional-player"}
	client._access_token = "fictional-token"
	var account := Base.RestartAccount.new()
	account.client.free()
	account.client = client
	account.add_child(client)
	var app := Base.RestartApp.new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.online = account
	app.add_child(account)
	var cloud := RaceCloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	app.cloud = cloud
	app.add_child(cloud)
	app.challenges = preload("res://backend/challenges_client.gd").new()
	app.challenges.client = client
	app.add_child(app.challenges)
	app.lifecycle = TrackLifecycle.new()
	app.lifecycle.cloud = cloud
	app.lifecycle.library = app.library
	app.add_child(app.lifecycle)
	app.menu_layer = CanvasLayer.new()
	app.menu_layer.layer = 20
	app.add_child(app.menu_layer)
	app.root_ui = Control.new()
	MenuStyle.fill(app.root_ui)
	app.menu_layer.add_child(app.root_ui)
	root.add_child(app)
	app.selected_track = TrackCompiler.compile(client.document)
	app.selected_track.metadata.cloud_version = "fictional-version"
	app.selected_track.metadata.cloud_creator_id = "fictional-creator"
	VehicleCatalog.selected = "compact"
	await app._start_race(app.selected_track,false)
	var game: Node = app.game
	await frames()
	var vote: Node = game.cloud_rating
	var rivalry_sync := RivalrySync.new()
	cloud.add_child(rivalry_sync)
	vote.rivalry_sync = rivalry_sync
	rivalry_sync.changed.connect(vote._rivalry_changed)
	check(is_instance_valid(vote) and vote.should_prompt() and not vote.eligible,"actual race start prefetches an unrated first completion without waiting for eligibility")
	drive(game)
	await frames()
	var cues: Control = game.race_cues
	check(cues.rating_panel.visible and not app.root_ui.visible,"rating stays on the actual racing view before the normal summary")
	check(cues.rating_panel.position.y > cues.size.y*0.5-125.0,"rating is beneath the Race complete gantry")
	check(cloud.queued == 0,"choosing a rating is independent of the still-unsubmitted first race")
	await capture("race-finish-rating-1280x720")
	root.size = Vector2i(960,540)
	await frames()
	check(cues.get_global_rect().encloses(cues.rating_panel.get_global_rect()),"finish rating fits compact landscape")
	await capture("race-finish-rating-960x540")
	root.size = Vector2i(1280,720)
	await frames()
	client.hold_save = true
	client.fail_save = true
	click(cues.rating_panel.find_child("Rate4",true,false) as Button)
	check(game.paused and app.root_ui.visible and not cues.rating_panel.visible,"real star click immediately opens normal results with no confirmation wait")
	check(cloud.queued == 1 and client.saves == 0 and vote.selected_score == 4,"first race upload queues normally while choice awaits server qualification in background")
	check(vote.score == 0 and client.score == 0,"unsent choice never optimistically marks track rated")
	await capture("immediate-normal-results")
	var summary: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	summary.continue_requested.emit()
	await frames()
	var result_row: TrackRating = app.root_ui.find_child("RaceComplete",true,false).find_child("TrackRating",true,false)
	check(filled(result_row,4) and result_row.locked,"actual first-race results immediately show the pending four-star choice")
	check(result_row.caption.text == "Rate the track","first-race verification never replaces the rating label")
	await capture("results-pending-four-stars-1280x720")
	root.size = Vector2i(960,540)
	await capture("results-pending-four-stars-960x540")
	root.size = Vector2i(1280,720)
	check(app.root_ui.find_child("TrackRatingPrompt",true,false) == null,"results have no relocated rating popup")
	client.eligible = true
	rivalry_sync.result_state = "verified"
	rivalry_sync.changed.emit()
	await frames()
	check(client.saves == 1 and not client.last_key.is_empty() and app.root_ui.visible,"verified upload starts one idempotent vote while player stays in results")
	# Navigation/race nodes are not required for a selected vote to finish.
	vote.abandon()
	check(is_instance_valid(vote),"selected vote survives ordinary race-view cleanup")
	client.hold_save = false
	await frames()
	check(not is_instance_valid(vote) and client.score == 0,"failed background vote leaves track unrated without retry or feedback")
	check(result_row.value() == 0 and filled(result_row,0) and not result_row.locked,"failed background save clears the pending stars and allows an inline retry")
	await capture("results-failed-save")
	cloud.changed.emit()
	await frames()
	check(client.saves == 1,"failed vote is not retried from later verification events")
	client.fail_save = false
	cloud.status = "Race verified"
	await app._retry_race()
	game.set_physics_process(false)
	await frames()
	vote = game.cloud_rating
	check(vote.should_prompt(),"actual retry prefetch offers the track again after a failed vote")
	drive(game)
	await frames()
	check(game.race_cues.rating_panel.visible,"failed vote is asked again at next completed attempt")
	client.hold_save = true
	click(game.race_cues.rating_panel.find_child("Rate3",true,false) as Button)
	check(game.paused and app.root_ui.visible,"already-qualified vote also leaves finish view immediately despite slow PUT")
	await frames()
	check(client.saves == 2 and client.score == 0,"slow PUT keeps last server score unchanged")
	await app._retry_race()
	game.set_physics_process(false)
	await frames()
	check(not game.cloud_rating.should_prompt(),"retry suppresses prompt while same account/version vote is still saving")
	client.hold_save = false
	await frames()
	check(client.score == 3 and not is_instance_valid(vote),"successful best-effort vote stores server stars without confirmation UI")
	check(not game.cloud_rating.should_prompt(),"retry started during PUT retains confirmed rating after the saving vote is freed")
	drive(game)
	await frames()
	check(not game.finish_rating_pending and not is_instance_valid(game.race_cues.rating_panel),"that same retry finishes without asking for the saved rating again")
	for tick: int in range(240):
		if game.paused: break
		game._physics_process(1.0/120.0)
	check(game.paused and app.root_ui.visible,"already-rated completion reaches the visible normal results after its full coast")
	await capture("retry-after-saved-rating")
	summary = app.root_ui.find_child("RaceResults",true,false)
	summary.continue_requested.emit()
	await frames()
	result_row = app.root_ui.find_child("RaceComplete",true,false).find_child("TrackRating",true,false)
	check(result_row.value() == 3 and filled(result_row,3) and result_row.caption.text == "Rate the track","actual results show the confirmed three-star rating on the next completed race")
	await capture("results-saved-three-stars-1280x720")
	root.size = Vector2i(960,540)
	await capture("results-saved-three-stars-960x540")
	root.size = Vector2i(1280,720)
	await app._retry_race()
	game.set_physics_process(false)
	await frames()
	check(not game.cloud_rating.should_prompt(),"next attempt suppresses a server-confirmed rating")
	# If metadata arrives during the coast, use that same race-view location.
	client.score = 0
	client.hold_read = true
	app._prepare_race_rating(game.native_track)
	vote = game.cloud_rating
	drive(game)
	check(not game.finish_rating_pending and not app.root_ui.visible,"pending prefetch does not force a network wait at the finish")
	client.hold_read = false
	await frames()
	game._physics_process(1.0/120.0)
	check(game.finish_rating_pending and game.race_cues.rating_panel.visible,"late score read offers rating under the gantry during the existing coast")
	await frames()
	click(game.race_cues.rating_panel.find_child("SkipRating",true,false) as Button)
	await frames()
	check(game.paused and app.root_ui.visible and client.saves == 2 and not is_instance_valid(vote),"actual Skip continues immediately and abandons an unselected vote")
	# Local disk failure rolls back in-memory stars and proceeds in the same call.
	var local := FailedRecords.new()
	var row := TrackRating.new()
	row.records = local
	row.track_id = "local-unrated"
	row.instant_finish = true
	root.add_child(row)
	var selected: Array[bool] = []
	row.selected.connect(func() -> void: selected.append(true))
	row.choose(5)
	check(selected.size() == 1 and row.value() == 0 and row.caption.text == "Rate the track","failed local save proceeds immediately and remains unrated without feedback")
	row.queue_free()
	await result_vote_updates(client,cloud,app.records)
	await handoff_races(client,cloud)
	# Prefetch suppression and identity fencing without any live network.
	client.score = 0
	var own := Vote.new()
	own.client = client
	own.sync = cloud
	own.version = "fictional-version"
	own.creator_id = "fictional-player"
	cloud.add_child(own)
	check(not own.should_prompt(),"creator cannot be prompted to rate own track")
	own.abandon()
	client.hold_read = true
	var pending := Vote.new()
	pending.client = client
	pending.sync = cloud
	pending.version = "fictional-version"
	cloud.add_child(pending)
	check(not pending.should_prompt(),"unavailable score read never blocks finish or assumes track is unrated")
	client.player = {"id":"another-fictional-player"}
	client.identity_changed.emit()
	client.hold_read = false
	await frames()
	check(not is_instance_valid(pending),"account change discards pending vote and stale read")
	app.queue_free()
	await frames()
	print("TRACK_RATING_PROMPT_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
