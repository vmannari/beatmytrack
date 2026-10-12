extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Queue = preload("res://backend/result_save_queue.gd")
const Credits = preload("res://platform/resume_credits.gd")
var checks: int = 0
var failures: int = 0
var workspace: String
const TICKET: String = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
const RACE: String = "cccccccc-cccc-cccc-cccc-cccccccccccc"

class API extends Client:
	var mode: String = "normal"
	var paths: Array[String] = []
	var keys: Array[String] = []
	var schemas: Array[String] = []
	var received: Dictionary = {}
	var shared: Dictionary = {}
	var consumptions: int = 0
	var balance: int = 2
	func _send(path: String, _method: HTTPClient.Method, payload: Dictionary, _auth: bool, key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		paths.append(path)
		keys.append(key)
		if mode == "refresh":
			if path == "/auth/refresh":
				if not shared.has("body"):
					shared.body = payload.duplicate(true)
					return {"ok":false,"status":0,"data":{},"error":"NETWORK_ERROR","not_delivered":false}
				if shared.body != payload: return {"ok":false,"status":401,"data":{},"error":"REFRESH_REUSE_DETECTED"}
				return {"ok":true,"status":200,"data":{"access_token":"replacement-access","refresh_token":"replacement-refresh","player":{"id":"fixture-owner"}},"error":""}
			return {"ok":true,"status":200,"data":{"id":"fixture-owner"},"error":""} if _access_token == "replacement-access" else {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
		if mode == "resume":
			if path == "/resume-races": return {"ok":true,"status":201,"data":{"race_id":RACE,"used":0},"error":""}
			if path.ends_with("/resumes"):
				consumptions += 1
				balance -= 1
				return {"ok":false,"status":0,"data":{},"error":"NETWORK_ERROR","not_delivered":false}
			if path == "/resume-recovery":
				if payload.action == "abandon": balance = 2
				return {"ok":true,"status":200,"data":{"state":"abandoned","wallet":{"balance":balance,"free":1,"reset_at":1900000000}},"error":""}
		if path == "/runs":
			received = payload.replay.duplicate(true)
			schemas.append(str(payload.replay.schema))
			if mode == "legacy":
				if not _disable_gzip: return {"ok":false,"status":415,"data":{},"error":"COMPRESSED_REQUESTS_NOT_SUPPORTED"}
				if payload.replay.schema == "bmt-packed-input-v1": return {"ok":false,"status":422,"data":{},"error":"Unsupported replay envelope"}
			if mode == "malformed": return {"ok":true,"status":202,"data":{},"error":""}
			return {"ok":true,"status":202,"data":{"run_id":"recovered-run","ticket_id":TICKET,"status":"queued"},"error":""}
		if mode == "missing": return {"ok":false,"status":404,"data":{},"error":"Run not found"}
		return {"ok":true,"status":200,"data":{"run_id":"recovered-run","ticket_id":TICKET,"status":"queued"},"error":""}

class Store extends Node:
	var allowed: bool = false
	var frames: Array = []
	var calls: int = 0
	func save(_ticket: Dictionary, values: Array, _publish: String, _rewinds: Array) -> bool:
		calls += 1
		await get_tree().create_timer(0.02).timeout
		frames = values.duplicate(true)
		return allowed

func _initialize() -> void:
	workspace = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("build/exception-native-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(workspace)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func api(mode: String) -> API:
	var result := API.new()
	root.add_child(result)
	result.configure("https://exception-fixture.invalid")
	result.player = {"id":"fixture-owner"}
	result._access_token = "fixture-access"
	result._refresh_token = "r".repeat(64)
	result.mode = mode
	result._sample_time(1900000000)
	return result

func cloud_for(client: API, name: String) -> Node:
	var cloud: Node = Cloud.new()
	cloud.client = client
	cloud.root_override = workspace.path_join(name)
	root.add_child(cloud)
	return cloud

func run() -> void:
	var store := Store.new()
	root.add_child(store)
	var queue: Node = Queue.new()
	queue.sink = store.save
	root.add_child(queue)
	var original: Array = [[0,255,0],[10,200,0,12]]
	var expected: Array = original.duplicate(true)
	check(queue.enqueue({"ticket_id":TICKET},original,"",[]),"capture completed recording")
	original.clear()
	while queue.saving or store.calls == 0: await process_frame
	check(queue.jobs.size() == 1 and not queue.saving,"failed save retained after game data cleared")
	store.allowed = true
	queue.retry(TICKET)
	await queue.saved
	check(queue.jobs.is_empty() and store.frames == expected,"recovery saves exact captured recording")
	check(store.calls == 2,"failed save retried once")
	queue.queue_free(); store.queue_free()

	var legacy: API = api("legacy")
	legacy._capabilities = {"replay_wire_schema":"bmt-packed-input-v1","upload_encodings":["identity","gzip"]}
	var frames: Array = [[127,255,0,255,2],[-127,0,255],[0,128,0,20],[0,255,0]]
	var rewinds: Array = [{"receipt_id":RACE,"input_offset":2,"from_tick":2,"to_tick":1}]
	var response: Dictionary = await legacy.submit_run(TICKET,frames,"original-recording-key",rewinds)
	check(response.ok and legacy.paths.size() == 3,"mixed API transport recovers")
	check(legacy.keys.all(func(k: String) -> bool: return k == "original-recording-key"),"fallback retains original identity")
	check(legacy.received.schema == "bmt-replay-v2" and legacy.received.frames == frames and legacy.received.rewinds == rewinds,"fallback is lossless including launch and authorized rewind")
	legacy.queue_free()

	var malformed: API = api("malformed")
	var cloud: Node = cloud_for(malformed,"malformed")
	check(cloud.queue_run({"ticket_id":TICKET},[[0,255,0]],""),"fixture recording is durable")
	await cloud.flush_outbox()
	var job: Dictionary = cloud.upload_job(TICKET)
	check(not cloud.flushing and not job.has("failure") and not job.has("run_id"),"bad success releases latch and retains retryable recording")
	check(int(job.get("retry_delay",0)) > 0,"protocol failure backs off")
	malformed.mode = "normal"
	cloud._retry_deadlines[TICKET] = 0
	await cloud.flush_outbox()
	check(cloud.upload_job(TICKET).get("run_id") == "recovered-run","corrected response recovers without restart")
	cloud.queue_free(); malformed.queue_free()

	var missing: API = api("missing")
	cloud = cloud_for(missing,"missing")
	cloud.queue_run({"ticket_id":TICKET,"_submit_key":"restore-original-key"},[[0,255,0]],"")
	job = cloud.upload_job(TICKET)
	var path: String = str(job._path)
	job.erase("_path")
	job.run_id = "missing-run"
	job.retry_at = 9999999999 # A legacy broken device clock must not strand it.
	cloud._save_job(path,job)
	await cloud.flush_outbox()
	check(missing.paths == ["/runs/missing-run","/runs"],"missing run reconciles instead of polling forever")
	check(cloud.upload_job(TICKET).get("run_id") == "recovered-run" and missing.keys[-1] == "restore-original-key","restore keeps original ticket/key/recording")
	job = cloud.upload_job(TICKET)
	cloud._delay_job(job,30,true)
	check(not cloud._job_ready(job),"monotonic retry is deferred")
	missing._sample_time(1900000000+91*86400)
	check(not cloud._job_ready(job),"wall-clock changes cannot accelerate in-process retry")
	var key: String = missing.new_operation_key()
	check(key.begins_with("v2.") and abs(int(key.get_slice(".",1))-missing.server_now()) <= 1,"new keys use server time")
	check(Client.new_idempotency_key().begins_with("op."),"unknown time uses cryptographic legacy key")
	cloud.queue_free(); missing.queue_free()

	var first: API = api("refresh")
	first._capabilities = {"refresh_recovery_seconds":120}
	first.session_path = workspace.path_join("session.cfg")
	first._save_session()
	response = await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(not response.ok and first.signed_in(),"unknown refresh response does not sign out recoverable session")
	var config := ConfigFile.new()
	config.load(first.session_path)
	check(not str(config.get_value("session","refresh_request_id","")).is_empty(),"refresh operation persisted before delivery")
	var restart: API = api("refresh")
	restart._capabilities = {"refresh_recovery_seconds":120}
	restart.session_path = first.session_path
	restart.shared = first.shared
	restart._access_token = ""
	restart.player = {}
	response = await restart.restore_session()
	check(response.ok and restart.signed_in(),"same refresh operation recovers after client restart")
	config = ConfigFile.new()
	config.load(restart.session_path)
	check(str(config.get_value("session","refresh_request_id","")).is_empty(),"successful rotation retires recovery secret")
	first.queue_free(); restart.queue_free()

	var funder: API = api("resume")
	funder._capabilities = {"resume_recovery":true}
	funder.resume_recovery.root_override = workspace.path_join("resumes")
	var credits: Node = Credits.new()
	credits.client = funder
	root.add_child(credits)
	credits.begin(TICKET)
	response = await credits.consume(10,0,10)
	check(not response.ok and not credits.pending.is_empty() and funder.consumptions == 1,"uncertain charge remains paused with durable identity")
	var directory: String = funder.resume_recovery._directory("fixture-owner",funder.base_url())
	check(DirAccess.get_files_at(directory).size() == 1,"resume journal exists before charge")
	credits.free()
	await funder.resume_recovery.reconcile()
	check(funder.consumptions == 1 and funder.balance == 2,"abandoned recovery returns resource without replaying charge")
	check(DirAccess.get_files_at(directory).is_empty(),"authoritatively resolved operation is retired")
	funder.queue_free()

	check(not Client.valid_response("/runs",HTTPClient.METHOD_POST,{}),"missing run id is invalid protocol")
	check(not Client.valid_response("/runs/status",HTTPClient.METHOD_GET,{"items":["invalid"]}),"bad batch elements rejected")
	check(not Client.valid_response("/resume-races",HTTPClient.METHOD_POST,{"race_id":42,"used":0}),"bad resource success rejected")
	if OS.get_environment("BMT_CAPTURE_RECOVERY") == "1":
		root.size = Vector2i(1280,720)
		var parent := Control.new()
		parent.theme = MenuStyle.theme()
		root.add_child(parent)
		var shown: API = api("normal")
		var uploads: Node = cloud_for(shown,"capture")
		var blocked := Store.new()
		root.add_child(blocked)
		uploads.result_saves.sink = blocked.save
		uploads.enqueue_completed({"ticket_id":TICKET},[[0,255,0]],"",[])
		while uploads.result_saves.saving or blocked.calls == 0: await process_frame
		await uploads.show_uploads(parent)
		await process_frame
		await process_frame
		var target: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("build/backend-recovery-uploads.png")
		check(root.get_texture().get_image().save_png(target) == OK,"recovery UI captured")
	print("BACKEND_EXCEPTION_RECOVERY: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
