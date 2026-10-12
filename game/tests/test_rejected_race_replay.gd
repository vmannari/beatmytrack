extends SceneTree
## Actual retained compact inputs; no account, ticket or server identifiers.
const LEGACY_CONTACTS = preload("res://tests/fixtures/legacy_contact_physics.gd")
var failures: int = 0
var checks: int = 0

class OldGateSession extends TrackSession:
	func _bridge_gate_direction(_track: NativeTrack, _center: Vector2, direction: Vector2, _half_span: float) -> Vector2:
		return direction

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func simulate(track: NativeTrack, inputs: Array, session: TrackSession, historical: bool = true) -> Array[int]:
	if historical: track = LEGACY_CONTACTS.copy_track(track)
	var sim: VehicleSimulation = LEGACY_CONTACTS.Simulation.new(VehicleCatalog.config("compact")) if historical else VehicleSimulation.new(VehicleCatalog.config("compact"))
	sim.reset(track.spawn,track.spawn_heading)
	var distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	if CreatorBridges.at_any(track.creator_bridges,sim.state.position):
		sim.state.track_elevated = CreatorBridges.initial_layer(track.creator_bridges,sim.state.position,sim.state.heading)
	session._configure(track)
	var laps: Array[int] = []
	var last_lap: int = 0
	var first_miss: bool = false
	var trailing: bool = false
	for values: Array in inputs:
		trailing = trailing or session.finished
		var frame := DriveFrame.new()
		frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
		frame.handbrake = int(values[3]) if values.size() == 4 else 0
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if not first_miss and session.missed_checkpoint >= 0:
			first_miss = true
			print("FIRST_MISS tick=",sim.state.tick," gate=",session.missed_checkpoint," position=",sim.state.position)
		if session.completed_laps > laps.size():
			laps.append(session.elapsed_ticks-last_lap)
			last_lap = session.elapsed_ticks
	check(not trailing,"recording has no trailing finish frames")
	return laps

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under_rejected_inputs.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var old := OldGateSession.new()
	var old_laps: Array[int] = simulate(track,replay.frames,old)
	check(not old.finished,"old ramp-tangent gates reproduce the retained replay rejection")
	print("OLD_REPLAY laps=",old_laps," next_gate=",old.next_checkpoint)
	var fixed := TrackSession.new()
	var fixed_laps: Array[int] = simulate(track,replay.frames,fixed)
	check(fixed.finished and fixed.completed_laps == 5,"corrected ramp gates accept all five laps")
	check(fixed_laps == [1627,1412,1426,1553,1768],"actual recording keeps exact lap ticks")
	check(fixed.elapsed_ticks == 7786,"actual recording keeps exact finish tick")
	var current := TrackSession.new()
	simulate(track,replay.frames,current,false)
	check(not current.finished,"changed contact physics cannot relabel an unfinished historical recording")
	await rejection_upload()
	print("REJECTED_REPLAY_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

class RejectionClient extends "res://backend/backend_client.gd":
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return {"ok":true,"status":200,"data":{"run_id":"rejected-fixture-run","status":"rejected","failure_code":"invalid_replay","retryable":false}}

func rejection_upload() -> void:
	var client := RejectionClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._access_token = "disposable-fixture"
	client.player = {"id":"rejected-replay-fixture"}
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://rejected_replay_test_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	check(cloud.queue_run({"ticket_id":"rejected-fixture"},[[0,255,0]]),"queue disposable upload")
	var job: Dictionary = cloud.upload_jobs()[0]
	job.run_id = "rejected-fixture-run"
	cloud._save_job(str(job._path),job)
	await cloud.flush_outbox()
	check(cloud.status.contains("Server replay could not verify this finish") and not cloud.status.contains("invalid_replay"),"polled rejection explains recovery instead of showing an internal code")
	var retained: Dictionary = cloud.upload_jobs()[0]
	var replay_path: String = str(retained._path).get_base_dir().path_join(str(retained.replay))
	check(retained.failure == "invalid_replay" and not retained.retryable and cloud._replay_integrity(replay_path,str(retained.replay_hash)),"terminal rejection preserves replay and original diagnostic code")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		var ui := Control.new()
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var status := Label.new()
		status.text = cloud.status
		status.position = Vector2(24,24)
		ui.add_child(status)
		cloud.show_uploads(ui)
		for frame: int in range(5): await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://../docs/evidence/rejected-replay-2026-10-03/rejection-message.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		check(root.get_texture().get_image().save_png(path) == OK,"capture real rejected-upload UI with disposable identity")
		ui.free()
	cloud.free(); client.free()
