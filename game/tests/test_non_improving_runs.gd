extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const ResultView = preload("res://ui/challenge_result_view.gd")
var checks: int = 0
var failures: int = 0

class OfflineClient extends "res://backend/backend_client.gd":
	var unexpected_requests: int = 0
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authorized: bool = false) -> Dictionary:
		unexpected_requests += 1
		return _failure("UNEXPECTED_TEST_REQUEST")

class SourceChoice extends "res://backend/challenges_client.gd":
	var requests: Array[Dictionary] = []
	var source_state: String = "skipped"
	var retryable: bool = false
	func _request(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _authorized: bool = true) -> Dictionary:
		requests.append({"path":path,"method":method})
		return {"ok":true,"data":{"run_id":"run","status":"queued" if method == HTTPClient.METHOD_POST else source_state,"retryable":retryable}}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("Native skip test timed out"); quit(1))
	var client := OfflineClient.new()
	root.add_child(client)
	check(client.configure("http://127.0.0.1:1") == OK,"isolated local origin")
	client._capabilities = {"trajectory_verification":true,"race_path_wire_version":1,"race_incident_rewards_version":1}
	check(not client.race_submission_options().has("result"),"old servers retain the exact old wire options")
	client._capabilities.non_improving_runs_version = 1
	var options: Dictionary = client.race_submission_options()
	check(options.result == 1 and options.path == 1 and options.incidents,"new protocol is negotiated")
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[100,0,0,0,0,0,0,0]]}
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/non_improving_run_v1.json"))
	var laps: Array = golden.claimed_lap_ticks.map(func(value: Variant) -> int: return int(value))
	var old: Dictionary = Client._pack_trajectory(100,proof,[])
	check(not old.has("claimed_lap_ticks"),"old recordings do not change their retry body")
	var packed: Dictionary = Client._pack_trajectory(100,proof,[],{},true,true,laps)
	check(packed.claimed_lap_ticks == laps and packed.race_proof.schema == "bmt-packed-path-v1","packed path retains the negative-only timing hint")
	check(Client._pack_trajectory(100,proof,[],{},false,false,[20,20,20,20,21]).is_empty(),"inconsistent summary rejected")
	check(Client._pack_trajectory(100,proof,[],{},false,false,[true,20,20,20,39]).is_empty(),"boolean lap tick rejected")
	var rewind: Array = [{"receipt_id":"00000000-0000-0000-0000-000000000001","input_offset":50,"from_tick":50,"to_tick":40}]
	check(Client._pack_trajectory(110,proof,rewind,{},false,false,laps).get("claimed_lap_ticks") == laps,"rewind summary uses net elapsed time")
	var folder: String = OS.get_environment("BMT_SKIP_NATIVE_ROOT").path_join(TrackLibrary.unique_id())
	check(not OS.get_environment("BMT_SKIP_NATIVE_ROOT").is_empty(),"test storage is explicitly isolated")
	DirAccess.make_dir_recursive_absolute(folder)
	var metadata: Dictionary = {"ticket_id":"00000000-0000-0000-0000-000000000002","_race_proof":proof,"_claimed_lap_ticks":laps,"_wire_options":options}
	var frames: Array = []
	for index: int in range(100): frames.append([0,255,0])
	check(Cloud._queue_run_io(metadata,frames,"",[],folder,"owner"),"summary is saved with the durable recording")
	var name: String = str(metadata.ticket_id).sha256_text()
	var directory: String = folder.path_join("players").path_join("owner".sha256_text()).path_join("runs")
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name+".job.json")))
	var recording: Dictionary = Cloud._load_replay(directory.path_join(str(job.replay)),str(job.replay_hash))
	var resumed: Dictionary = Client._pack_trajectory(100,recording.get("race_proof",{}),[],{},true,true,recording.get("claimed_lap_ticks",[]))
	check(resumed.get("claimed_lap_ticks") == laps and job.wire_options.result == 1,"restart retains timing and negotiated options")
	check(Cloud._queue_run_io(metadata,frames,"",[],folder,"owner"),"identical durable retry remains idempotent")
	metadata.ticket_id = "00000000-0000-0000-0000-000000000003"
	metadata._wire_options = {"path":1,"incidents":true}
	check(Cloud._queue_run_io(metadata,frames,"",[],folder,"owner"),"legacy negotiated recording can still be saved")
	name = str(metadata.ticket_id).sha256_text()
	job = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name+".job.json")))
	recording = Cloud._load_replay(directory.path_join(str(job.replay)),str(job.replay_hash))
	check(not recording.has("claimed_lap_ticks") and not job.wire_options.has("result"),"old-server recording keeps the old body through restart")
	var cloud := Cloud.new()
	cloud.client = client
	root.add_child(cloud)
	var bad_job: Dictionary = job.duplicate(true)
	bad_job.wire_options.unknown = 1
	var invalid: Dictionary = await cloud._submit_saved(bad_job,directory.path_join(name+".job.json"))
	check(invalid.get("status") == 422,"unknown third wire option is rejected before transport")
	bad_job.wire_options.erase("unknown")
	bad_job.wire_options.result = true
	invalid = await cloud._submit_saved(bad_job,directory.path_join(name+".job.json"))
	check(invalid.get("status") == 422,"boolean protocol version is rejected before transport")
	var terminal: Dictionary = {"run_id":"run","ticket_id":"ticket","status":"skipped","skip_reason":"no_improvement","poll_after_ms":0,"completion":{"version":1,"reward":{"status":"credited","amount":50,"rows":[]}}}
	check(Client.valid_run(terminal) and terminal.status == golden.terminal_fields.status,"skipped is an explicit successful terminal status")
	var malformed: Dictionary = terminal.duplicate(true)
	malformed.skip_reason = "unknown"
	check(not Client.valid_run(malformed),"unknown skip reason is rejected")
	client.remember_run(terminal)
	check(client.recent_completion("ticket").get("reward",{}).get("amount") == 50,"completion cache serves skipped rewards")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/challenge_series_v1.json"))
	var own: Dictionary = {}
	for row: Dictionary in snapshot.standings:
		if row.id == snapshot.self_id: own = row
	var outcome: Dictionary = {"counted":true,"improved":false,"before_ticks":100,"after":own,"stage_index":0,"completed_tracks":3,"ms":1000,"gap_ms":null,"beaten":false}
	client.player = {"id":snapshot.self_id}
	terminal.completion.challenge_result = {"status":"skipped","outcome":outcome,"challenge":snapshot,"poll_after_ms":0}
	client.remember_run(terminal)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.selected = snapshot
	root.add_child(adapter)
	adapter.begin_result("ticket")
	await adapter.poll_result()
	check(adapter.result_state == "skipped" and not adapter.outcome.get("improved",true),"challenge consumer completes without waiting for verification")
	check(client.unexpected_requests == 0,"cached completion needs no additional request")
	var choice := SourceChoice.new()
	var source: Dictionary = await choice.source("version","compact","ticket")
	check(source.status == "queued" and choice.requests.size() == 2 and choice.requests[1].method == HTTPClient.METHOD_POST and choice.requests[1].path == "/runs/run/retry","choosing a skipped competitive target explicitly requests verification")
	choice.requests.clear()
	choice.source_state = "verified"
	source = await choice.source("version","compact","ticket")
	check(source.status == "verified" and choice.requests.size() == 1,"already verified challenge sources remain read-only")
	choice.requests.clear()
	choice.source_state = "failed"
	choice.retryable = true
	source = await choice.source("version","compact","ticket")
	check(source.status == "queued" and choice.requests.size() == 2,"temporary verification failure retains the explicit competitive request")
	choice.free()
	root.size = Vector2i(1280,720)
	var view := ResultView.new()
	view.snapshot = snapshot
	view.outcome = outcome
	view.result_state = "skipped"
	view.signed_in = true
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var feedback := view.find_child("ChallengeResultFeedback",true,false) as Label
	check(feedback != null and feedback.text == "Race completed","skipped result shows completion instead of a verification spinner")
	var capture: String = OS.get_environment("BMT_SKIP_NATIVE_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK,"native result screenshot")
	view.queue_free()
	cloud.queue_free()
	adapter.queue_free()
	client.queue_free()
	await process_frame
	print("NON_IMPROVING_RUNS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
