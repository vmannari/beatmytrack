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
	var saves: int = 0
	var last_key: String = ""
	func signed_in() -> bool: return not player.is_empty()
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if not path.ends_with("/rating"):
			return {"ok":true,"data":{"free":1,"balance":0,"ad_preview_available":true,"ads_available":false,"purchases_available":false}}
		var answer: Dictionary = {"ok":true,"data":{"score":score,"eligible":eligible}}
		while hold_read: await get_tree().process_frame
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
	func enqueue_completed(_ticket: Dictionary, _frames: Array, _publish: String = "", _rewinds: Array = []) -> bool:
		queued += 1
		return true

class FailedRecords extends LocalRecords:
	func save_records() -> Error: return ERR_CANT_CREATE

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
		game.online_frames.append([frame.steer,frame.throttle,frame.brake])
		if game.track_session.finished: break
	check(game.track_session.finished and game.track_session.completed_laps == 5,"actual canonical driving completes all five ordered laps")
	game._begin_finish()
	for tick: int in range(90): game._physics_process(1.0/120.0)

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-rating="): capture_dir = arg.trim_prefix("--capture-rating=")
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
	check(app.root_ui.find_child("TrackRatingPrompt",true,false) == null,"results have no relocated rating popup")
	client.eligible = true
	cloud.status = "Race verified"
	cloud.changed.emit()
	await frames()
	check(client.saves == 1 and not client.last_key.is_empty() and app.root_ui.visible,"verified upload starts one idempotent vote while player stays in results")
	# Navigation/race nodes are not required for a selected vote to finish.
	vote.abandon()
	check(is_instance_valid(vote),"selected vote survives ordinary race-view cleanup")
	client.hold_save = false
	await frames()
	check(not is_instance_valid(vote) and client.score == 0,"failed background vote leaves track unrated without retry or feedback")
	cloud.changed.emit()
	await frames()
	check(client.saves == 1,"failed vote is not retried from later verification events")
	client.fail_save = false
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
	client.hold_save = false
	await frames()
	check(client.score == 3 and not is_instance_valid(vote),"successful best-effort vote stores server stars without confirmation UI")
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
