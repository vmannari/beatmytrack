extends SceneTree
## Review probes use a temporary user directory, never owner files.

class OfflineClient:
	extends "res://backend/backend_client.gd"
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = []) -> Dictionary:
		return _failure("NETWORK_ERROR")

class ReviewApp:
	extends "res://core/app.gd"
	var last_notice: String = ""
	func _ready() -> void: pass
	func _notice(message: String) -> void: last_notice = message

class FailingCloud:
	extends Node
	var last_error: String = "NETWORK_ERROR"
	func ticket(_track: NativeTrack) -> Dictionary: return {}

class ReviewOnline:
	extends "res://backend/account_controller.gd"
	func _ready() -> void: pass

class RunningGame:
	extends Node
	var native_track: NativeTrack
	var resume_ticket_id: String = "active-old-ticket"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder: String = "user://review_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var client := OfflineClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client.session_path = folder.path_join("session.cfg")
	client._access_token = "review-access"
	client._refresh_token = "review-refresh"
	client.player = {"id":"review-player"}
	client._save_session()
	var restored: Dictionary = await client.restore_session()
	var output: Dictionary = {"refresh_network_failure":{"error":restored.error,"signed_in":client.signed_in(),"saved_session":client.has_saved_session()}}
	assert(not client.has_saved_session())
	client._access_token = "review-access"
	client.player = {"id":"review-player"}
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var frames: Array = []
	for index: int in range(216000): frames.append([0,255,0,255])
	var first: bool = cloud.queue_run({"ticket_id":"review-ticket-1"},frames)
	var second: bool = cloud.queue_run({"ticket_id":"review-ticket-2"},frames)
	var third: bool = cloud.queue_run({"ticket_id":"review-ticket-3"},frames)
	var jobs: Array = cloud._read(cloud.outbox_path()).get("jobs",[])
	output["outbox_capacity"] = {"first_saved":first,"second_saved":second,"third_saved":third,"persisted_jobs":jobs.size()}
	assert(first and second and not third and jobs.size() == 2)
	var app := ReviewApp.new()
	var online := ReviewOnline.new()
	online.client.free()
	online.client = client
	var running := RunningGame.new()
	running.native_track = NativeTrack.new()
	running.native_track.metadata = {"cloud_version":"review-version"}
	app.game = running
	app.online = online
	app.cloud = FailingCloud.new()
	app.cloud_ticket = {"ticket_id":"active-old-ticket"}
	root.add_child(app)
	app.add_child(online)
	app.add_child(running)
	app.add_child(app.cloud)
	await app._retry_race()
	output["failed_restart"] = {"original_game_ticket":running.resume_ticket_id,"app_ticket_retained":not app.cloud_ticket.is_empty(),"notice":app.last_notice}
	assert(app.cloud_ticket.is_empty() and running.resume_ticket_id == "active-old-ticket")
	# Find an elevated gate in a supported creator bridge fixture. A planar
	# crossing with ground-layer route hint still consumes the elevated gate.
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var session := TrackSession.new()
	session._configure(track)
	for index: int in range(session.checkpoint_count()):
		var center: Vector2 = session._centers[index]
		var hint: int = track.nearest_route(center)
		if not track.elevated_at(center,hint): continue
		if track.cell_at(center,false) == 4: continue
		var direction: Vector2 = session._directions[index]
		var ground_hint: int = -1
		for candidate: int in range(track.route.size()):
			if not track.elevated_at(center,candidate): ground_hint = candidate; break
		if ground_hint < 0: continue
		session.next_checkpoint = index
		session.advance(track,center-direction*0.2,center+direction*0.2,ground_hint)
		output["elevated_gate"] = {"gate":index,"next_gate":session.next_checkpoint,"ground_hint":ground_hint,"ground_cell":track.cell_at(center,false),"accepted":session.next_checkpoint > index}
		assert(session.next_checkpoint > index)
		break
	assert(output.has("elevated_gate"))
	print("REVIEW_PROBES: "+JSON.stringify(output))
	app.free()
	cloud.free()
	client.free()
	# Delete only files created beneath this uniquely allocated temporary folder.
	cleanup(folder)
	await process_frame
	quit(0)

func cleanup(folder: String) -> void:
	var directory := DirAccess.open(folder)
	if directory == null: return
	for name: String in directory.get_files(): DirAccess.remove_absolute(folder.path_join(name))
	for name: String in directory.get_directories(): cleanup(folder.path_join(name))
	DirAccess.remove_absolute(folder)
