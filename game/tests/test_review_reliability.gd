extends SceneTree
## Reproductions of review failures, using only isolated disposable persistence.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class OfflineClient extends "res://backend/backend_client.gd":
	var delivered: bool = false
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		var result: Dictionary = _failure("NETWORK_ERROR")
		result.not_delivered = not delivered
		return result

class ReviewApp extends "res://core/app.gd":
	var last_notice: String = ""
	func _ready() -> void: pass
	func _notice(message: String) -> void: last_notice = message

class FailingCloud extends Node:
	var last_error: String = "NETWORK_ERROR"
	func ticket(_track: NativeTrack, _test: bool = false, _vehicle: String = "", _handling: HandlingConfig = null) -> Dictionary: return {}

class ReviewOnline extends "res://backend/account_controller.gd":
	func _ready() -> void: pass

class RunningGame extends Node:
	var vehicle_id: String = "compact"
	var handling: HandlingConfig = VehicleCatalog.config("compact")
	var native_track := NativeTrack.new()
	var track_session := TrackSession.new()
	var resume_ticket_id: String = "active-old-ticket"

class SlowClient extends "res://backend/backend_client.gd":
	var pending: bool = false
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		pending = true
		await get_tree().create_timer(0.4).timeout
		pending = false
		return {"ok":true,"status":200,"error":"","data":{"items":[],"population":0,"next_cursor":null}}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var folder: String = "user://review_fix_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var client := OfflineClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client.session_path = folder.path_join("session.cfg")
	client._refresh_token = "fixture-refresh"
	client.player = {"id":"fixture-player"}
	client._save_session()
	await client.restore_session()
	check(client.has_saved_session(),"a request that never connected preserves the remembered session")
	client.delivered = true
	await client.restore_session()
	check(not client.has_saved_session(),"ambiguous rotation cannot reuse a single-use refresh token")
	client._access_token = "fixture-access"
	client.player = {"id":"fixture-player"}
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var frames: Array = []
	for index: int in range(216000): frames.append([0,255,0,255])
	for index: int in range(3): check(cloud.queue_run({"ticket_id":"fixture-ticket-"+str(index)},frames),"maximum replay %d is durably queued" % index)
	check(cloud.upload_jobs().size() == 3,"three maximum replays survive an adapter reload")
	check(cloud.queue_run({"ticket_id":"fixture-ticket-0"},frames),"repeated completion accepts the same recorded replay")
	check(cloud.upload_jobs().size() == 3,"repeated completion retains one submission")
	check(not cloud.queue_run({"ticket_id":"fixture-ticket-0"},[[0,0,0]]),"a conflicting attempt cannot overwrite the saved replay")
	var legacy: String = cloud.outbox_path()
	cloud._write(legacy,{"jobs":[{"ticket":"legacy-ticket","frames":[[0,0,0]],"key":"legacy-key","publish":"","publish_key":"publish-key"}]})
	check(cloud._migrate_outbox() and FileAccess.file_exists(legacy+".migrated"),"legacy replay migration retains a recovery copy")
	check(cloud.upload_jobs().size() == 4,"migration preserves prior and newly queued races")
	var corrupt := FileAccess.open(legacy,FileAccess.WRITE)
	corrupt.store_string("broken JSON")
	corrupt.close()
	check(not cloud._migrate_outbox() and FileAccess.get_file_as_string(legacy) == "broken JSON","corrupt legacy state is reported and preserved")
	var app := ReviewApp.new()
	var online := ReviewOnline.new()
	online.client.free()
	online.client = client
	var running := RunningGame.new()
	running.native_track.metadata = {"cloud_version":"fixture-version"}
	app.game = running
	app.online = online
	app.cloud = FailingCloud.new()
	app.cloud_ticket = {"ticket_id":"active-old-ticket"}
	root.add_child(app)
	app.add_child(online)
	app.add_child(running)
	app.add_child(app.cloud)
	await app._retry_race()
	check(app.cloud_ticket.get("ticket_id") == "active-old-ticket" and running.resume_ticket_id == "active-old-ticket","failed Restart preserves both active ticket owners")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var session := TrackSession.new()
	session._configure(track)
	var exercised: bool = false
	for index: int in range(session.checkpoint_count()):
		if not session._layers[index]: continue
		var center: Vector2 = session._centers[index]
		var direction: Vector2 = session._directions[index]
		session.next_checkpoint = index
		session.advance(track,center-direction*0.2,center+direction*0.2,0,false)
		check(session.next_checkpoint == index,"underpass cannot consume a bridge gate")
		session.advance(track,center-direction*0.2,center+direction*0.2,0,true)
		check(session.next_checkpoint > index,"matching deck layer consumes the same gate")
		exercised = true
		break
	check(exercised,"supported bridge fixture exercises the layer regression")
	var slow := SlowClient.new()
	root.add_child(slow)
	var slow_cloud := Cloud.new()
	slow_cloud.client = slow
	slow_cloud.root_override = folder.path_join("slow")
	root.add_child(slow_cloud)
	var browser := TrackBrowser.new()
	browser.library = TrackLibrary.new(folder.path_join("drafts"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.builtin_ids = []
	browser.state = {}
	browser.cloud = slow_cloud
	browser.selected_track = track
	root.add_child(browser)
	while browser.loading: await process_frame
	track.metadata.cloud_version = "fixture-version"
	# Current Race requires a backend catalog entry, even for a cached track.
	# Keep that availability contract while isolating slow optional standings.
	browser.catalog.entries = [{"id":track.identity,"source":"cloud","name":"Bridge fixture","creator":"Review fixture","theme":"pine","version_id":"fixture-version","rating_average":null,"rating_count":0}]
	browser.selecting = true
	browser._finish_selection({"track":track})
	check(slow.pending and not browser.selecting and browser.selected_track == track and not browser.race_button.disabled,"cached cloud selection is playable while optional standings are pending")
	await create_timer(0.5).timeout
	browser.queue_free()
	slow_cloud.queue_free()
	slow.queue_free()
	app.free()
	cloud.free()
	client.free()
	cleanup(folder)
	await process_frame
	print("REVIEW_RELIABILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(folder: String) -> void:
	if not folder.begins_with("user://review_fix_track_"): return
	var directory := DirAccess.open(folder)
	if directory == null: return
	for name: String in directory.get_files(): DirAccess.remove_absolute(folder.path_join(name))
	for name: String in directory.get_directories(): cleanup(folder.path_join(name))
	DirAccess.remove_absolute(folder)
