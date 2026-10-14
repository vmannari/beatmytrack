extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Recovery = preload("res://backend/resume_recovery.gd")
const Files = preload("res://backend/atomic_json.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const TICKET: String = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
const RACE: String = "cccccccc-cccc-cccc-cccc-cccccccccccc"
var checks: int = 0
var failures: int = 0
var workspace: String

class API extends Client:
	var bodies: Array[Dictionary] = []
	var paths: Array[String] = []
	var keys: Array[String] = []
	var held: bool = false
	var change_owner: bool = false
	var reply: Dictionary = {"ok":true,"status":200,"data":{"state":"consumed","receipt_id":RACE,"used":1,"wallet":{"balance":2,"free":1,"reset_at":1900000000}},"error":""}
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		bodies.append(payload.duplicate(true))
		paths.append(_path)
		keys.append(_key)
		if held: await get_tree().create_timer(0.02).timeout
		if change_owner: player = {"id":"other-owner"}
		return reply.duplicate(true)

func _initialize() -> void:
	workspace = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("build/resume-recovery-budget-"+str(Time.get_ticks_usec()))
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",description)

func journal(index: int = 0) -> Dictionary:
	return {"owner":"fixture-owner","origin":"https://recovery-fixture.invalid","begin_key":"begin-key-%04d"%index,"consume_key":"consume-key-%04d"%index,"race_id":RACE,"ticket_id":TICKET,"stage":"confirm","selection":{"ordinal":1,"input_offset":3600,"from_tick":3600,"to_tick":2400,"recovery":"v1"}}

func fixture(name: String) -> API:
	var api := API.new()
	api.configure("https://recovery-fixture.invalid")
	api.player = {"id":"fixture-owner"}
	api._access_token = "fixture-access"
	api._capabilities = {"resume_recovery":true}
	api._sample_time(1900000000)
	root.add_child(api)
	api.resume_recovery.root_override = workspace.path_join(name)
	api.resume_recovery.set_process(false)
	return api

func directory(api: API) -> String:
	return api.resume_recovery._directory("fixture-owner",api.base_url())

func path(api: API, entry: Dictionary) -> String:
	return directory(api).path_join(str(entry.consume_key).sha256_text()+".json")

func expire(api: API) -> void:
	api.resume_recovery._deadlines[directory(api)] = 0

func failure(status: int, code: String = "UNAVAILABLE", retry_after: int = 0) -> Dictionary:
	return {"ok":false,"status":status,"error":code,"data":{},"retry_after":retry_after}

func cloud_for(api: API, name: String) -> Node:
	var cloud := Cloud.new()
	cloud.client = api
	cloud.root_override = workspace.path_join(name)
	root.add_child(cloud)
	return cloud

func run() -> void:
	check(Client._retry_after(PackedStringArray(["Retry-After: 120"])) == 120,"HTTP header retains waits longer than one minute")
	check(Client._retry_after(PackedStringArray(["retry-after: nonsense"])) == 0,"invalid cooldown header does not become an immediate retry")
	check(Client._retry_after(PackedStringArray(["Retry-After: 999999"])) == 3600,"server cooldown is bounded to one hour")
	var api: API = fixture("wire")
	check(api.resume_recovery.save(journal()),"save integer recovery journal")
	await api.resume_recovery.reconcile()
	check(api.bodies.size() == 1,"restored journal reaches recovery")
	if not api.bodies.is_empty():
		var wire: String = Client._encode_request(api.bodies[0],false).body.get_string_from_utf8()
		var wire_path: String = OS.get_environment("BMT_RECOVERY_WIRE_PATH")
		if wire_path.is_empty(): wire_path = workspace.path_join("wire.json")
		check(Files.write(wire_path,api.bodies[0]),"actual recovery wire exported for strict backend integration")
		check(not wire.contains("3600.0") and not wire.contains("1.0"),"serialized wire uses JSON integers")
		for key: String in ["ordinal","input_offset","from_tick","to_tick"]:
			check(api.bodies[0].selection[key] is int,"restored %s stays an integer for strict server validation"%key)
	api.free()

	api = fixture("active-confirm")
	api.resume_recovery.save(journal())
	api.resume_recovery.register_race(journal().begin_key)
	await api.resume_recovery.reconcile()
	check(api.bodies.size() == 1 and api.bodies[0].action == "confirm","delivered resume confirms while its race is active")
	api.free()

	api = fixture("accepted-race")
	api.resume_recovery.save(journal())
	api.reply = failure(409,"RACE_ALREADY_SUBMITTED")
	await api.resume_recovery.reconcile()
	check(not FileAccess.file_exists(path(api,journal())),"accepted replay retires recovery without attempting a refund")
	api.free()

	api = fixture("capability")
	api.resume_recovery.save(journal())
	api._capabilities = {}
	await api.resume_recovery.reconcile()
	check(api.bodies.is_empty() and FileAccess.file_exists(path(api,journal())),"unsupported recovery retains the journal without a request")
	api.free()

	for status: int in [400,403,404,409,410,422]:
		api = fixture("terminal-%d"%status)
		var original: Dictionary = journal()
		api.resume_recovery.save(original)
		api.reply = failure(status,"DEFINITIVE_REJECTION")
		await api.resume_recovery.reconcile()
		expire(api)
		await api.resume_recovery.reconcile()
		var retained: Dictionary = Files.read(path(api,original))
		check(api.bodies.size() == 1,"terminal %d is not retried"%status)
		check(retained.get("recovery_failure") == "DEFINITIVE_REJECTION" and retained.consume_key == original.consume_key and Recovery._request_body(retained).selection == original.selection,"terminal %d preserves the exact operation for repair"%status)
		api.free()

	for status: int in [0,401,429,500,502,503]:
		api = fixture("transient-%d"%status)
		for index: int in range(17): check(api.resume_recovery.save(journal(index)),"durable transient backlog")
		api.reply = failure(status,"TEMPORARY",120 if status == 429 else 0)
		await api.resume_recovery.reconcile()
		for attempt: int in range(20): await api.resume_recovery.reconcile()
		check(api.bodies.size() == 1,"transient %d stops the whole backlog"%status)
		var retry: Dictionary = Files.read(directory(api).path_join(".retry.json"))
		check(int(retry.retry_delay) >= (120 if status == 429 else 30),"transient cooldown honors Retry-After")
		api._sample_time(1900000000+86400)
		await api.resume_recovery.reconcile()
		check(api.bodies.size() == 1,"server time adjustment cannot accelerate an in-process retry")
		api._sample_time(1900000000)
		var peer: API = fixture("transient-%d"%status)
		await peer.resume_recovery.reconcile()
		check(peer.bodies.is_empty(),"persisted transient wait survives restart/shared profile")
		peer.free()
		expire(api)
		api.reply = failure(503)
		await api.resume_recovery.reconcile()
		retry = Files.read(directory(api).path_join(".retry.json"))
		check(int(retry.retry_streak) == 2 and int(retry.retry_delay) >= 60,"consecutive failures back off exponentially")
		api.free()

	api = fixture("healthy-backlog")
	for index: int in range(17): api.resume_recovery.save(journal(index))
	await api.resume_recovery.reconcile()
	await api.resume_recovery.reconcile()
	check(api.bodies.size() == 1,"healthy backlog is paced too")
	for index: int in range(16):
		expire(api)
		await api.resume_recovery.reconcile()
	check(api.bodies.size() == 17,"all backlog entries eventually progress past the former sixteen-file prefix")
	api.free()

	api = fixture("invalid-journal")
	var invalid: Dictionary = journal()
	invalid.selection.ordinal = 1.5
	check(not api.resume_recovery.save(invalid),"fractional evidence cannot enter the queue")
	Files.write(path(api,invalid),invalid)
	api.resume_recovery.save(journal(1))
	await api.resume_recovery.reconcile()
	check(api.bodies.size() == 1 and api.bodies[0].consume_key == journal(1).consume_key,"invalid evidence does not block another operation")
	expire(api)
	await api.resume_recovery.reconcile()
	check(Files.read(path(api,invalid)).get("recovery_failure") == "INVALID_RECOVERY_JOURNAL","invalid original is preserved without a network retry")
	for field: String in ["ordinal","input_offset","from_tick","to_tick"]:
		invalid = journal()
		invalid.selection[field] = INF
		check(Recovery._request_body(invalid).is_empty(),"nonfinite %s rejected"%field)
	invalid = journal()
	invalid.selection.input_offset = "3600"
	check(Recovery._request_body(invalid).is_empty(),"string ticks rejected without coercion")
	invalid = journal()
	invalid.selection.to_tick = -1
	check(Recovery._request_body(invalid).is_empty(),"out-of-bound evidence rejected")
	invalid = journal()
	invalid.selection.extra = 1
	check(Recovery._request_body(invalid).is_empty(),"unknown selection fields rejected")
	api.free()

	api = fixture("active")
	var pending: Dictionary = journal()
	pending.stage = "pending"
	api.resume_recovery.save(pending)
	api.resume_recovery.register_race(pending.begin_key)
	await api.resume_recovery.reconcile()
	check(api.bodies.is_empty(),"active uncertain race cannot be abandoned")
	api.resume_recovery.leave_race(pending.begin_key)
	await api.resume_recovery.reconcile()
	check(api.bodies.size() == 1 and api.bodies[0].action == "abandon","leaving race recovers its original abandoned operation")
	api.free()

	api = fixture("owner-change")
	api.resume_recovery.save(journal())
	api.change_owner = true
	await api.resume_recovery.reconcile()
	check(FileAccess.file_exists(path(api,journal())) and not api.resume_recovery.busy,"late response after account switch preserves owner evidence and releases latch")
	api.free()

	api = fixture("overlap")
	api.resume_recovery.save(journal())
	api.held = true
	api.resume_recovery.reconcile()
	await api.resume_recovery.reconcile()
	while api.resume_recovery.busy: await process_frame
	check(api.bodies.size() == 1,"overlapping reconciliation sends exactly one operation")
	api.free()

	for rate_limited: bool in [false,true]:
		api = fixture("outbox-client-%s"%rate_limited)
		var cloud: Node = cloud_for(api,"outbox-%s"%rate_limited)
		for index: int in range(20):
			check(cloud.queue_run({"ticket_id":"outbox-ticket-%d"%index,"_submit_key":"original-key-%d"%index},[[0,255,0]]),"outbox backlog is durable")
		api.reply = failure(429,"RATE_LIMITED",120) if rate_limited else {"ok":true,"status":202,"data":{"run_id":"run-fixture","status":"verified"},"error":""}
		await cloud.flush_outbox()
		await cloud.flush_outbox()
		check(api.paths.size() == 1,"outbox %s does not spend the budget on every remaining job"%rate_limited)
		check(cloud.upload_jobs().size() == 20,"outbox retains every saved result")
		if rate_limited:
			var request_scope: String = api.base_url()+"/fixture-owner"
			check(int(cloud._flush_deadlines[request_scope])-Time.get_ticks_msec() > 110000,"whole outbox honors Retry-After")
		else:
			cloud._write_deadlines.clear()
			await cloud.flush_outbox()
			check(api.paths.size() == 2,"healthy paced backlog continues when its write interval expires")
		cloud.free()
		api.free()

	for status: int in [429,503,200,201]:
		api = fixture("publication-client-%d"%status)
		var cloud: Node = cloud_for(api,"publication-%d"%status)
		var flow := TrackLifecycle.new()
		flow.cloud = cloud
		flow.library = TrackLibrary.new(workspace.path_join("publication-library-%d"%status))
		root.add_child(flow)
		var job: Dictionary = {"schema":"track-lifecycle-1","scope":flow.scope(),"library_directory":flow.library.directory,"fingerprint":"fixture-fingerprint","upload_key":"fixture-publication-key","publish_key":"publish-key","ticket_key":"ticket-key","state":"queued","created_at":1900000000,"document":{"id":"publication_fixture","name":"Publication fixture"},"publish_requested":true,"publish_workflow":2,"publication_id":"publication-id"}
		var job_path: String = flow._root().path_join("fixture.job.json")
		check(flow._save(job_path,job),"publication recovery journal saved")
		api.reply = failure(status,"TEMPORARY",120) if status >= 400 else {"ok":true,"status":200,"data":{} if status == 200 else {"state":"published"},"error":""}
		await flow.process_jobs()
		for attempt: int in range(20): await flow.process_jobs()
		check(api.paths.size() == 1,"publication failure/malformed response %d backs off"%status)
		var saved: Dictionary = flow._read(job_path)
		check(not saved.has("_read_error") and saved.upload_key == job.upload_key and saved.document.id == job.document.id,"publication evidence remains readable after failure")
		check(int(saved.retry_delay) >= (120 if status >= 400 else 15),"publication polling honors error cooldown")
		api._sample_time(1900000000+86400)
		await flow.process_jobs()
		check(api.paths.size() == 1,"publication cooldown uses monotonic in-process time")
		api._sample_time(1900000000)
		flow._retry_deadlines.clear()
		await flow.process_jobs()
		check(api.paths.size() == 1,"publication cooldown survives scheduler restart")
		flow._retry_deadlines[job.upload_key] = 0
		# Both the per-job wait and the shared 429 wait must have elapsed.
		flow._batch_deadlines[flow.scope()] = 0
		api.reply = {"ok":true,"status":200,"data":{"state":"queued","poll_after_ms":2500},"error":""}
		await flow.process_jobs()
		check(api.paths.size() == 2 and int(flow._read(job_path).retry_streak) == 0,"publication service recovery resets backoff without replacing its identity")
		flow.free()
		cloud.free()
		api.free()
	api = fixture("publication-retry-journal")
	var retry_cloud: Node = cloud_for(api,"publication-retry-journal")
	var retry_library := TrackLibrary.new(workspace.path_join("publication-retry-library"))
	var retry_flow := TrackLifecycle.new()
	retry_flow.cloud = retry_cloud
	retry_flow.library = retry_library
	root.add_child(retry_flow)
	var retry_document: Dictionary = {"id":"publication_retry_fixture","name":"Retry fixture"}
	var retry_job: Dictionary = {"schema":"track-lifecycle-1","scope":retry_flow.scope(),"library_directory":retry_library.directory,"fingerprint":TrackLibrary.draft_fingerprint(retry_document),"upload_key":"immutable-publication-key","publish_key":"publish-key","ticket_key":"ticket-key","state":"failed","created_at":1900000000,"document":retry_document,"publish_requested":true,"publish_workflow":2,"publication_id":"retry-publication-id","failure":"Temporarily unavailable","remote":{"state":"failed","retryable":true}}
	var retry_path: String = retry_flow._path(retry_document)
	check(retry_flow._save(retry_path,retry_job),"publication retry journal saved")
	api.reply = failure(503,"UNAVAILABLE")
	await retry_flow.retry(retry_document)
	var pending_retry: Dictionary = retry_flow._read(retry_path)
	var retry_key: String = str(pending_retry.get("publication_retry_key",""))
	check(not retry_key.is_empty() and api.keys[0] == retry_key,"unknown publication retry keeps its saved operation key")
	check(pending_retry.upload_key == retry_job.upload_key,"retry never changes the original publication identity")
	retry_flow.free()
	retry_flow = TrackLifecycle.new()
	retry_flow.cloud = retry_cloud
	retry_flow.library = retry_library
	root.add_child(retry_flow)
	api.reply = {"ok":true,"status":200,"data":{"state":"queued","retryable":false,"poll_after_ms":2500},"error":""}
	await retry_flow.retry(retry_document)
	check(api.keys.size() == 1,"service-unavailable publication retry remains deferred after restart")
	api._sample_time(1900000016) # Advance the authoritative fixture clock past the 15-second pause.
	await retry_flow.retry(retry_document)
	check(api.keys[1] == retry_key,"publication retry survives restart with exactly the same operation key")
	var acknowledged: Dictionary = retry_flow._read(retry_path)
	check(not acknowledged.has("publication_retry_key") and acknowledged.upload_key == retry_job.upload_key,"acknowledgement retires only the retry key")
	acknowledged.state = "failed"
	acknowledged.failure = "Another dependency failure"
	acknowledged.remote = {"state":"failed","retryable":true}
	check(retry_flow._save(retry_path,acknowledged),"subsequent publication failure is saved")
	var previous_calls: int = api.keys.size()
	await retry_flow.retry(retry_document)
	check(api.keys[previous_calls] != retry_key,"a later explicit retry gets a new operation identity")
	retry_flow.free()
	retry_cloud.free()
	api.free()
	api = fixture("publication-size-client")
	var size_cloud: Node = cloud_for(api,"publication-size")
	var size_flow := TrackLifecycle.new()
	size_flow.cloud = size_cloud
	size_flow.library = TrackLibrary.new(workspace.path_join("publication-size-library"))
	root.add_child(size_flow)
	var size_job: Dictionary = {"schema":"track-lifecycle-1","scope":size_flow.scope(),"library_directory":size_flow.library.directory,"fingerprint":"size-fixture","upload_key":"original-size-publication-key","publish_key":"publish-key","ticket_key":"ticket-key","state":"publishing","created_at":1900000000,"document":{"id":"publication_size_fixture","name":"Size fixture"},"publish_requested":true,"publish_workflow":2,"vehicle":"compact","contract":{},"proof_file":"size.proof.json"}
	var size_path: String = size_flow._root().path_join("size.job.json")
	check(size_flow._save(size_path,size_job),"oversize publication job saved")
	check(Files.write(size_path.get_base_dir().path_join("size.proof.json"),{"input_count":6,"race_proof":{"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[6,0,0,0,0,0,0,0]]}}),"oversize publication evidence saved")
	api.reply = failure(413,"PAYLOAD_TOO_LARGE")
	await size_flow.process_jobs()
	await size_flow.process_jobs()
	var rejected: Dictionary = size_flow._read(size_path)
	check(api.paths == ["/publications"] and rejected.has("failure"),"413 stops automatic publication retries")
	check(rejected.upload_key == size_job.upload_key and FileAccess.file_exists(size_path.get_base_dir().path_join("size.proof.json")),"413 retains the original proof and operation identity")
	size_flow.free(); size_cloud.free(); api.free()
	var wire_client := Client.new()
	root.add_child(wire_client)
	wire_client.configure("https://oversize-fixture.invalid")
	var oversize: Dictionary = await wire_client._send("/publications",HTTPClient.METHOD_POST,{"document":"x".repeat(Client.MAX_RESPONSE_BYTES+1)},false)
	check(int(oversize.status) == 413 and oversize.error == "REQUEST_TOO_LARGE","local encoding limit returns the same terminal size status before any network request")
	wire_client.free()
	print("RESUME_RECOVERY_BUDGET: %d checks, %d failures"%[checks,failures])
	quit(0 if failures == 0 else 1)
