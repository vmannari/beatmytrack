extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Recovery = preload("res://backend/pending_input_recovery.gd")
const Original = preload("res://tests/fixtures/replay_wire_reference.gd")
var checks: int = 0
var failures: int = 0

class Service extends Client:
	var writes: Array[Dictionary] = []
	var accepted: Dictionary = {}
	var lose_reply: bool = false
	var conflict: bool = false
	var switch_account: bool = false
	func signed_in() -> bool: return true
	func wait_for_run(_run: String, _ticket: String, _timeout: int = 0) -> Dictionary:
		return {"ok":false,"status":0,"error":"FIXTURE_WAIT_DEFERRED","data":{}}
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", _authenticated: bool = false) -> Dictionary:
		if method == HTTPClient.METHOD_GET:
			if switch_account: player = {"id":"different-owner"}
			if path.ends_with("/submission"):
				return {"ok":true,"status":200,"data":{"run":accepted.get(path.get_slice("/",2))},"error":""}
			for value: Dictionary in accepted.values():
				if path.ends_with("/"+str(value.run_id)): return {"ok":true,"status":200,"data":value,"error":""}
			return {"ok":false,"status":404,"error":"MISSING","data":{}}
		writes.append({"key":key,"body":payload.duplicate(true)})
		var run: Dictionary = {"run_id":"run-"+str(payload.ticket_id),"ticket_id":payload.ticket_id,"status":"queued"}
		accepted[str(payload.ticket_id)] = run
		if lose_reply:
			lose_reply = false
			return {"ok":false,"status":0,"error":"NETWORK_ERROR","data":{}}
		if conflict:
			conflict = false
			return {"ok":false,"status":409,"error":"CONFLICT","data":{}}
		return {"ok":true,"status":202,"data":run,"error":""}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _cloud(service: Node) -> Node:
	var cloud := Cloud.new()
	cloud.client = service
	cloud.root_override = "user://pending_recovery_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	return cloud

func _saved(cloud: Node, ticket: String, recording: Dictionary, failed: bool = false) -> Dictionary:
	var name: String = ticket.sha256_text()
	var directory: String = cloud.outbox_path().get_base_dir().path_join("runs")
	var job: Dictionary = {"ticket":ticket,"key":"original-"+ticket,"replay":name+".replay.json","replay_hash":JSON.stringify(recording).sha256_text(),"publish":""}
	if failed: job.merge({"submission_schema":"bmt-trajectory-v1","failure":"INVALID_REPLAY","rejection_status":422})
	check(Cloud._write_file(directory.path_join(str(job.replay)),recording),"fixture replay is durable")
	check(Cloud._write_file(directory.path_join(name+".job.json"),job),"fixture journal is durable without a pending marker")
	return job

func run() -> void:
	var recording: Dictionary = {"frames":[[0.0,255.0,0.0,0.0,1.0],[5.0,90.0,2.0],[0.0,0.0,255.0],[0.0,0.0,0.0]],"rewinds":[]}
	var packet: Dictionary = Recovery.replay(recording)
	check(packet == Original.pack(recording.frames,[],false),"input recovery preserves the original canonical replay body")
	var rewound: Dictionary = recording.duplicate(true)
	rewound.rewinds = [{"receipt_id":"11111111-1111-4111-8111-111111111111","input_offset":2.0,"from_tick":2.0,"to_tick":0.0}]
	check(Recovery.replay(rewound) == Original.pack(rewound.frames,rewound.rewinds,false),"launch and rewind data retain the original integer body")
	var corrupt: Dictionary = recording.duplicate(true)
	corrupt.frames[1][0] = 0.5
	check(Recovery.replay(corrupt).is_empty(),"fractional controls cannot be recovered")
	corrupt = recording.duplicate(true); corrupt.frames[1] = [0,0,0,0,1]
	check(Recovery.replay(corrupt).is_empty(),"late launch markers cannot be recovered")
	corrupt = rewound.duplicate(true); corrupt.rewinds[0].from_tick = 3
	check(Recovery.replay(corrupt).is_empty(),"rewind timeline mismatches cannot be recovered")
	corrupt = rewound.duplicate(true); corrupt.rewinds.append(corrupt.rewinds[0].duplicate())
	check(Recovery.replay(corrupt).is_empty(),"duplicate receipts cannot be recovered")
	corrupt = recording.duplicate(true); corrupt.race_proof = {}
	check(Recovery.replay(corrupt).is_empty(),"a malformed movement proof cannot select input recovery")
	var too_many: Array = []; too_many.resize(216001)
	check(Recovery.replay({"frames":too_many}).is_empty(),"the monotonic input limit also applies to saved input recovery")
	var service := Service.new()
	root.add_child(service)
	service.configure("http://127.0.0.1:1")
	service.player = {"id":"fixture-owner"}
	service._capabilities = {"trajectory_verification":true,"submission_recovery_version":1}
	var cloud: Node = _cloud(service)
	# New compact journals and existing trajectory journals produce identical wire
	# bodies, hashes and keys after JSON reload, including launch/rewind receipts.
	var exact_controls: Array = [[0,255,0,0,2],[127,128,0,255],[-127,0,255]]
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0.0,0.0,0.0,0.0,0.0,0,0.0],[3,1.0,2.0,0.2,1.0,2.0,0,0.0]]}
	var receipt: Array = [{"receipt_id":"11111111-1111-4111-8111-111111111111","input_offset":2,"from_tick":2,"to_tick":0}]
	var ticket: Dictionary = {"ticket_id":"new-count-journal","_submit_key":"count-key","_race_proof":proof,"_race_ghost":{"ticks":3},"_wire_options":{"path":0,"incidents":false}}
	check(cloud.queue_run(ticket,exact_controls,"",receipt),"new count journal saves with actual proof and rewind")
	var count_job: Dictionary = cloud.upload_job(ticket.ticket_id)
	var count_path: String = str(count_job._path); count_job.erase("_path")
	var result: Dictionary = await cloud._submit_saved(count_job,count_path)
	# Ghost JSON numbers retain the existing disk-reload representation; controls,
	# sample ticks, input count and receipt integers are normalized by the codec.
	var expected: Dictionary = Client._pack_trajectory(3,proof,receipt,{"ticks":3.0},false,false)
	check(result.ok and service.writes.back().key=="count-key" and service.writes.back().body.replay==expected,"new count journal sends the exact pinned trajectory body and retry key")
	var original_trajectory: Dictionary = {"frames":exact_controls,"rewinds":receipt,"race_proof":proof,"ghost":{"ticks":3}}
	var old_job: Dictionary = _saved(cloud,"existing-trajectory",original_trajectory)
	var old_path: String = str(cloud.upload_job("existing-trajectory")._path)
	var old_hash: String = str(old_job.replay_hash)
	result = await cloud._submit_saved(old_job,old_path)
	check(result.ok and service.writes.back().body.replay==expected,"existing trajectory without pinned options remains sendable with the exact original body")
	check(str(cloud.upload_job("existing-trajectory").replay_hash)==old_hash,"existing trajectory replay hash is never replaced")
	check(cloud.upload_job("existing-trajectory").wire_options=={"path":0.0,"incidents":false},"first recovery pins old journal transport options for later retries")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	check(Cloud._write_file(cloud.outbox_path(),{"jobs":[{"ticket":"old-journal","key":"original-journal-key","frames":recording.frames,"rewinds":[]}]}),"original embedded outbox is durable")
	await cloud.flush_outbox()
	var migrated: Dictionary = cloud.upload_job("old-journal")
	check(migrated.has("run_id") and not migrated.has("failure"),"unaccepted embedded input-only outbox uploads after upgrade")
	check(service.writes.back().key == "original-journal-key" and service.writes.back().body.replay == packet,"migration preserves the key and canonical input body")
	var replay_path: String = str(migrated._path).get_base_dir().path_join(str(migrated.replay))
	check(FileAccess.get_sha256(replay_path) == migrated.replay_hash,"pending acceptance preserves the exact recorded replay bytes")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	var original: Dictionary = _saved(cloud,"stranded",recording,true)
	await cloud.flush_outbox()
	var repaired: Dictionary = cloud.upload_job("stranded")
	check(repaired.has("run_id") and not repaired.has("failure"),"a restart automatically restores jobs stranded by the previous cutover")
	check(repaired.key == original.key and repaired.replay_hash == original.replay_hash,"repair preserves the original operation and replay hash")
	check(service.writes.back().body.replay == packet,"restored input-only jobs use the original input envelope")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	corrupt = recording.duplicate(true); corrupt.frames[0][0] = 0.5
	var invalid: Dictionary = _saved(cloud,"corrupt",corrupt,true)
	var before: int = service.writes.size()
	await cloud.flush_outbox()
	check(service.writes.size() == before and cloud.upload_job("corrupt").failure == "INVALID_REPLAY","corrupt failed recordings are preserved without becoming retryable uploads")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	original = _saved(cloud,"storage",recording,true)
	var blocked_path: String = str(cloud.upload_job("storage")._path)
	DirAccess.make_dir_absolute(blocked_path+".tmp")
	await cloud.flush_outbox()
	check(cloud.upload_job("storage").failure == "INVALID_REPLAY","a failed journal repair retains its original failure document")
	DirAccess.remove_absolute(blocked_path+".tmp")
	cloud._recovered_outboxes.clear()
	await cloud.flush_outbox()
	check(cloud.upload_job("storage").has("run_id"),"recovery resumes after journal storage is repaired")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	original = _saved(cloud,"lost-reply",recording)
	service.lose_reply = true
	before = service.writes.size()
	await cloud.flush_outbox()
	var lost: Dictionary = cloud.upload_job("lost-reply")
	var path: String = str(lost._path); lost.erase("_path")
	var recovered: Dictionary = await cloud._submit_saved(lost,path)
	check(recovered.ok and service.writes.size() == before+1,"a lost input-recovery reply is resolved by ticket lookup without resubmission")
	check(lost.key == original.key,"lost-reply recovery never replaces the original retry key")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	original = _saved(cloud,"in-flight",recording)
	service.conflict = true
	var inflight: Dictionary = cloud.upload_job("in-flight")
	path = str(inflight._path); inflight.erase("_path")
	recovered = await cloud._submit_saved(inflight,path)
	check(recovered.ok and recovered.data.ticket_id == "in-flight","an original in-flight submission winning a 409 is recovered by its accepted ticket")
	cloud.queue_free(); await process_frame
	cloud = _cloud(service)
	original = _saved(cloud,"older-server",recording)
	service._capabilities.erase("submission_recovery_version")
	var waiting: Dictionary = cloud.upload_job("older-server")
	path = str(waiting._path); waiting.erase("_path")
	var journal_hash: String = FileAccess.get_sha256(path)
	before = service.writes.size()
	recovered = await cloud._submit_saved(waiting,path)
	check(recovered.error == "SUBMISSION_SERVER_UPDATE_REQUIRED" and service.writes.size() == before,"an older service leaves input recovery pending")
	check(FileAccess.get_sha256(path) == journal_hash,"an older service cannot relabel the retained job")
	service._capabilities.submission_recovery_version = 1
	service.switch_account = true
	recovered = await cloud._submit_saved(waiting,path)
	check(recovered.error == "ACCOUNT_CHANGED" and service.writes.size() == before,"an account switch during lookup cannot submit the previous owner's job")
	service.switch_account = false; service.player = {"id":"fixture-owner"}
	recovered = await service.submit_run("normal",recording.frames,"normal-key")
	check(recovered.error == "INVALID_REPLAY" and service.writes.size() == before,"ordinary race submissions retain trajectory-only validation")
	cloud.queue_free(); service.queue_free()
	await process_frame
	print("PENDING_INPUT_RECOVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
