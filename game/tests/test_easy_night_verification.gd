extends "res://tests/test_pending_input_recovery.gd"
## Rewind plus a one-tick rounded summary must preserve the original upload.

func _cloud(service: Node) -> Node:
	var cloud := Cloud.new()
	cloud.client = service
	cloud.root_override = ProjectSettings.globalize_path("res://../build/easy-night-verification-2026-10-27/fixtures/"+TrackLibrary.unique_id())
	root.add_child(cloud)
	return cloud

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	var service := Service.new()
	root.add_child(service)
	service.configure("http://127.0.0.1:1")
	service.player = {"id":"fixture-owner"}
	service._capabilities = {"trajectory_verification":true,"submission_recovery_version":1,"non_improving_runs_version":1,"race_path_wire_version":1}
	var cloud: Node = _cloud(service)
	var rewinds: Array = [{"receipt_id":"11111111-1111-4111-8111-111111111111","input_offset":2427,"from_tick":2427,"to_tick":1848}]
	var claims: Array = [1053,966,902,905,901]
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[4728,1,2,0,0,0,0,0]],
		"incidents":{"schema":"bmt-race-incidents-v1","ticks":4728,"collision_count":0,"off_track":false}}
	check(Client._pack_trajectory(5307,proof,rewinds,{},true,true,claims).is_empty(),"original one-tick mismatch fails strict packing")
	check(Client._rounded_lap_mismatch(5307,rewinds,claims),"rounding recovery subtracts exactly the recorded rewind")
	var recording: Dictionary = {"schema":"bmt-local-trajectory-v1","input_count":5307,"race_proof":proof,"rewinds":rewinds,"claimed_lap_ticks":claims}
	var original: Dictionary = _saved(cloud,"easy-night-rewind",recording)
	original.merge({"submission_schema":"bmt-trajectory-v1","wire_options":{"path":1,"incidents":true,"result":1},"failure":"REPLAY_RECOVERY_REQUIRED","rejection_status":422})
	var path: String = str(cloud.upload_job("easy-night-rewind")._path)
	check(Cloud._write_file(path,original),"stranded rewind journal is durable")
	await cloud.flush_outbox()
	var repaired: Dictionary = cloud.upload_job("easy-night-rewind")
	check(repaired.has("run_id") and not repaired.has("failure"),"startup restores the exact one-tick rewind case")
	check(repaired.key == original.key and repaired.replay_hash == original.replay_hash,"recovery preserves operation and evidence identities")
	check(FileAccess.get_sha256(path.get_base_dir().path_join(str(original.replay))) == original.replay_hash,"all original recording bytes remain exact")
	check(service.writes.size() == 1,"normal transport receives one recovered submission")
	if not service.writes.is_empty():
		var packet: Dictionary = service.writes[0].body.replay
		check(packet.input_count == 5307 and not packet.has("claimed_lap_ticks"),"recovery omits only the inconsistent optional hint")
		check(packet.rewinds == rewinds,"original resume receipt and branch offsets survive recovery")
		check(packet.race_proof.incidents.ticks == 4728,"incident report retains the net elapsed duration")
		check(packet.race_proof.schema == "bmt-packed-path-v1","negotiated exact path transport is retained")
	var boundaries: Array[float] = [1053.4,2019.3,2921.2,3826.1,4727.2]
	var seconds: Array[float] = []
	var previous: float = 0.0
	for boundary: float in boundaries:
		seconds.append((boundary-previous)/120.0)
		previous = boundary
	var corrected: Array = Client._lap_tick_summary(seconds,4728,120)
	check(corrected == [1054,966,902,905,901],"new summaries use the integer lap boundary samples")
	check(not Client._pack_trajectory(5307,proof,rewinds,{},true,true,corrected).is_empty(),"new rewind summary meets the unchanged strict wire contract")
	cloud.queue_free(); service.queue_free()
	await process_frame
	print("EASY_NIGHT_VERIFICATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
