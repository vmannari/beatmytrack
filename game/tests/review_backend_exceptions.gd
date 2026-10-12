extends SceneTree
## Review observations intentionally reproduce unresolved faults. No real HTTP/identity.
var report: Dictionary = {}
var completed: bool = false

class DelayedStore extends Node:
	var calls: int = 0
	func queue_run_async(_ticket: Dictionary, _frames: Array, _publish: String, _rewinds: Array) -> bool:
		calls += 1
		await get_tree().create_timer(0.05).timeout
		return false
	func flush_outbox() -> void:
		pass

class StubAPI extends "res://backend/backend_client.gd":
	var mode: String = ""
	var calls: Array[String] = []
	var replay_schema: String = ""
	func _send(path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		calls.append(path)
		if path == "/runs": replay_schema = str(_payload.get("replay",{}).get("schema",""))
		if mode == "refresh":
			return {"ok":false,"status":503 if path == "/auth/refresh" else 401,"data":{},"error":"DATABASE_UNAVAILABLE" if path == "/auth/refresh" else "INVALID_SESSION"}
		if mode == "resume":
			if path == "/resume-races": return {"ok":true,"status":201,"data":{"race_id":"fixture-race"},"error":""}
			return {"ok":false,"status":0,"data":{},"error":"NETWORK_ERROR","not_delivered":false}
		if mode == "old_api":
			return {"ok":false,"status":422,"data":{},"error":"Unsupported replay envelope"}
		return {"ok":mode == "malformed","status":202 if mode == "malformed" else 404,"data":{},"error":"" if mode == "malformed" else "Run not found"}

func _initialize() -> void:
	_run.call_deferred()
	_timeout.call_deferred()

func _timeout() -> void:
	await create_timer(8).timeout
	if not completed:
		push_error("Review probe timed out")
		quit(2)

func _api(mode: String) -> StubAPI:
	var api := StubAPI.new()
	root.add_child(api)
	api.configure("https://exception-fixture.invalid")
	api.mode = mode
	api.player = {"id":"fixture-owner"}
	api._access_token = "fixture-access"
	api._refresh_token = "fixture-refresh"
	return api

func _run() -> void:
	var app: Node = preload("res://core/app.gd").new()
	var store := DelayedStore.new()
	root.add_child(store)
	app.cloud = store
	var old_game := Node.new()
	app.game = old_game
	app.cloud_ticket = {"ticket_id":"fixture-ticket"}
	app._save_result_upload(old_game,app.cloud_ticket,[[0,255,0]],"",[])
	# The Home/next-race path frees this game while durable save is outstanding.
	app.game = null
	old_game.free()
	await create_timer(0.1).timeout
	report["failed_save_after_leaving_results"] = {"save_attempts":store.calls,
		"retry_dialogs":app.get_child_count(),"save_busy":app._result_save_busy,"saved":false}
	app.free()
	store.queue_free()

	var refreshing: StubAPI = _api("refresh")
	var response: Dictionary = await refreshing.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	report["refresh_database_outage"] = {"status":response.status,"error":response.error,
		"signed_in":refreshing.signed_in(),"calls":refreshing.calls}
	refreshing.queue_free()

	var pending_api: StubAPI = _api("resume")
	var credits: Node = preload("res://platform/resume_credits.gd").new()
	root.add_child(credits)
	credits.client = pending_api
	credits.begin("fixture-ticket")
	await credits.consume(10,0,10)
	report["ambiguous_resume"] = {"pending":not credits.pending.is_empty(),"used":credits.used}
	# A new race/process does not persist or reconcile this operation.
	credits.begin("replacement-ticket")
	report["ambiguous_resume"]["pending_after_new_race"] = not credits.pending.is_empty()
	credits.queue_free()
	pending_api.queue_free()

	var modes: Array[String] = ["missing","old_api"]
	if OS.get_environment("BMT_EXCEPTION_FAULT") == "malformed": modes = ["malformed"]
	for mode: String in modes:
		var api: StubAPI = _api(mode)
		var cloud: Node = preload("res://backend/cloud_tracks.gd").new()
		root.add_child(cloud)
		cloud.client = api
		if mode == "old_api": api._capabilities = {"replay_wire_schema":"bmt-packed-input-v1"}
		var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		cloud.root_override = repository.path_join("build/exception-probe-outbox").path_join(mode+"-"+str(Time.get_ticks_usec()))
		var ticket_id: String = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
		cloud.queue_run({"ticket_id":ticket_id},[[0,255,0]],"",[])
		if mode == "missing":
			var job: Dictionary = cloud.upload_job(ticket_id)
			var path: String = str(job._path)
			job.erase("_path")
			job.run_id = "previously-accepted-run"
			cloud._save_job(path,job)
			await cloud.flush_outbox()
			report["missing_run_poll"] = {"paths":api.calls.duplicate(),"job":cloud.upload_job(ticket_id)}
		elif mode == "old_api":
			await cloud.flush_outbox()
			var before: int = api.calls.size()
			await cloud.flush_outbox()
			report["mixed_api_protocol"] = {"schema":api.replay_schema,"calls_before_retry":before,
				"calls_after_retry":api.calls.size(),"job_failure":cloud.upload_job(ticket_id).get("failure","")}
		else:
			# Expected GDScript error: a valid JSON success lacks run_id.
			# Do not await that aborted coroutine; observe its unreleased latch.
			report["malformed_success"] = {"response_status":202,"response_data":{},"expected_script_error":"cloud_tracks.gd:689"}
			_write_report()
			cloud.call_deferred("flush_outbox")
			var deadline: int = Time.get_ticks_msec()+2000
			while api.calls.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
			await process_frame
			var before: int = api.calls.size()
			cloud.flush_outbox()
			report["malformed_success"] = {"flushing_stuck":cloud.flushing,
				"calls_before_retry":before,"calls_after_retry":api.calls.size()}
		cloud.queue_free()
		api.queue_free()
	_write_report()
	completed = true
	quit(0)

func _write_report() -> void:
	var output: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("build/backend-exception-client.json")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(3); return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXCEPTION_REVIEW_OBSERVATIONS "+JSON.stringify(report))
