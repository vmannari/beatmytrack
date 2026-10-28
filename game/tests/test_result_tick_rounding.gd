extends "res://tests/test_pending_input_recovery.gd"
## Completed-race summaries must use recorded tick boundaries after disk reload.

func _cloud(service: Node) -> Node:
	var cloud := Cloud.new()
	cloud.client = service
	cloud.root_override = ProjectSettings.globalize_path("res://../build/result-tick-rounding-2026-10-27/fixtures/"+TrackLibrary.unique_id())
	root.add_child(cloud)
	return cloud

func run() -> void:
	create_timer(40.0).timeout.connect(func() -> void: push_error("Result rounding test timed out"); quit(1))
	var service := Service.new()
	root.add_child(service)
	service.configure("http://127.0.0.1:1")
	service.player = {"id":"fixture-owner"}
	service._capabilities = {"trajectory_verification":true,"submission_recovery_version":1,"non_improving_runs_version":1,"race_path_wire_version":1}
	var cloud: Node = _cloud(service)
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[11373,1,2,0,0,0,0,0]]}
	# The reported race had these exact integer totals, with intact local bytes.
	var recording: Dictionary = {"schema":"bmt-local-trajectory-v1","input_count":11373,"race_proof":proof,"rewinds":[],"claimed_lap_ticks":[2331,2146,2514,2195,2185]}
	var original: Dictionary = _saved(cloud,"rounding",recording)
	original.submission_schema = "bmt-trajectory-v1"
	original.wire_options = {"path":1,"incidents":false,"result":1}
	var path: String = str(cloud.upload_job("rounding")._path)
	var replay_path: String = path.get_base_dir().path_join(str(original.replay))
	var before: int = service.writes.size()
	var submitted: Dictionary = await cloud._submit_saved(original,path)
	check(submitted.ok,"an intact race with the observed two-tick rounding gap uploads")
	if service.writes.size() > before:
		var packet: Dictionary = service.writes.back().body.replay
		check(packet.input_count == 11373 and not packet.has("claimed_lap_ticks"),"old rounded hints are omitted without inventing lap times")
		var disk: Dictionary = Cloud._load_replay(replay_path,str(original.replay_hash))
		check(packet.race_proof == Client._pack_trajectory(11373,disk.race_proof,[],{},false,true).race_proof,"the original recorded path reaches normal verification unchanged")
	check(FileAccess.get_sha256(replay_path) == original.replay_hash,"upload recovery preserves every replay byte")
	# A clean restart discovers the local failure even after its marker was retired.
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	original = _saved(cloud,"restart-rounding",recording)
	original.merge({"submission_schema":"bmt-trajectory-v1","wire_options":{"path":1,"incidents":false,"result":1},"failure":"REPLAY_RECOVERY_REQUIRED","rejection_status":422})
	path = str(cloud.upload_job("restart-rounding")._path)
	check(Cloud._write_file(path,original),"stranded rounding journal is durable")
	await cloud.flush_outbox()
	var repaired: Dictionary = cloud.upload_job("restart-rounding")
	check(repaired.has("run_id") and not repaired.has("failure"),"restart automatically queues a locally blocked rounding failure")
	check(repaired.key == original.key and repaired.replay_hash == original.replay_hash,"recovery retains the ticket, idempotency key and evidence hash")
	# Retry uncertainty retains exactly the first submitted body and key.
	var lost: Dictionary = _saved(cloud,"rounded-lost-reply",recording)
	lost.merge({"submission_schema":"bmt-trajectory-v1","wire_options":{"path":1,"incidents":false,"result":1}})
	path = str(cloud.upload_job("rounded-lost-reply")._path)
	service.lose_reply = true
	submitted = await cloud._submit_saved(lost,path)
	check(not submitted.ok and submitted.error == "NETWORK_ERROR","lost reply retains upload uncertainty")
	var first_write: Dictionary = service.writes.back().duplicate(true)
	service.conflict = true
	var disk_job: Dictionary = cloud.upload_job("rounded-lost-reply")
	submitted = await cloud._submit_saved(disk_job,path)
	check(submitted.ok and submitted.data.ticket_id == "rounded-lost-reply","an accepted retry resolves through the same ticket")
	check(service.writes.back() == first_write,"disk reload preserves the exact recovered body and original key")
	check(FileAccess.get_sha256(path.get_base_dir().path_join(str(lost.replay))) == lost.replay_hash,"lost replies preserve the original evidence")
	var rounded_rewind: Array = [{"receipt_id":"11111111-1111-4111-8111-111111111111","input_offset":500,"from_tick":500,"to_tick":380}]
	check(service.call("_rounded_lap_mismatch",11493,rounded_rewind,recording.claimed_lap_ticks),"recovered rounding uses the authorized rewind timeline's net duration")
	# Negative controls: no broad repair of corrupt evidence or server decisions.
	for kind: String in ["large-gap","fractional","boolean","missing-lap","hash","server-rejection","dismissed","already-submitted","bad-proof"]:
		var bad_recording: Dictionary = recording.duplicate(true)
		if kind == "large-gap": bad_recording.claimed_lap_ticks[0] = 1
		if kind == "fractional": bad_recording.claimed_lap_ticks[0] = 2331.5
		if kind == "boolean": bad_recording.claimed_lap_ticks[0] = true
		if kind == "missing-lap": bad_recording.claimed_lap_ticks.pop_back()
		if kind == "bad-proof": bad_recording.race_proof.samples[0] = [0]
		var job: Dictionary = _saved(cloud,kind,bad_recording)
		job.merge({"submission_schema":"bmt-trajectory-v1","wire_options":{"path":1,"incidents":false,"result":1},"failure":"REPLAY_RECOVERY_REQUIRED","rejection_status":422})
		if kind == "hash": job.replay_hash = "a".repeat(64)
		if kind == "server-rejection": job.failure = "invalid_replay"
		if kind == "dismissed": job.dismissed = true
		if kind == "already-submitted": job.run_id = "server-run"
		path = str(cloud.upload_job(kind)._path)
		check(Cloud._write_file(path,job),"negative fixture saves: "+kind)
		var plans: Array[Dictionary] = Cloud._discover_pending(path.get_base_dir())
		check(not plans.any(func(plan: Dictionary) -> bool: return plan.filename == path.get_file() and plan.has("repair")),"recovery preserves failure: "+kind)
	# New summaries use absolute integer boundaries, not independent rounding.
	check(service.has_method("_lap_tick_summary"),"completed races expose a tick-boundary summary")
	if service.has_method("_lap_tick_summary"):
		var seconds: Array[float] = [20.4/120.0,20.4/120.0,20.4/120.0,20.4/120.0,20.4/120.0]
		var laps: Array = service.call("_lap_tick_summary",seconds,102,120)
		check(laps == [21,20,21,20,20],"cumulative crossing ticks retain ticks lost by independent rounding")
		check(not Client._pack_trajectory(102,proof,[],{},false,false,laps).is_empty(),"new summary satisfies the strict wire envelope")
		check(service.call("_lap_tick_summary",seconds,103,120).is_empty(),"inconsistent capture duration omits the optional hint")
		seconds[0] = NAN
		check(service.call("_lap_tick_summary",seconds,102,120).is_empty(),"non-finite local timing cannot become a summary")
		seconds = [0.01,0.01,0.01,0.01]
		check(service.call("_lap_tick_summary",seconds,5,120).is_empty(),"incomplete laps produce no hint")
		for variant: int in range(32):
			var cumulative: Array[float] = [2331.01+variant*0.03,4477.99-variant*0.03,6991.1,9187.4,11372.068]
			seconds.clear()
			var previous: float = 0.0
			for boundary: float in cumulative:
				seconds.append((boundary-previous)/120.0)
				previous = boundary
			check(service.call("_lap_tick_summary",seconds,11373,120) == [2332,2146,2514,2196,2185],"fractional crossing boundaries remain exact: %d" % variant)
	check(Client._pack_trajectory(11373,proof,[],{},false,false,recording.claimed_lap_ticks).is_empty(),"strict wire packing still rejects inconsistent hints")
	cloud.queue_free(); service.queue_free()
	await process_frame
	print("RESULT_TICK_ROUNDING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
