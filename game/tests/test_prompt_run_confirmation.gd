extends SceneTree
## A completion after the first wait must not fall into multi-second polling.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class Server extends "res://backend/backend_client.gd":
	signal entered
	signal batch_release
	var calls: int = 0
	var batch_reads: int = 0
	var hold_batch: bool = false
	var finish_after: int = 3
	var immediate_pending: bool = false
	func _ready() -> void: pass
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _auth: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		if _path.begins_with("/runs/status?"):
			batch_reads += 1
			if hold_batch: await batch_release
			var pending: Dictionary = value("verifying")
			remember_run(pending) # The real transport caches batch rows before returning.
			return {"ok":true,"status":200,"error":"","data":{"items":[pending]}}
		calls += 1
		entered.emit()
		var until: int = Time.get_ticks_msec()+30
		while not immediate_pending and Time.get_ticks_msec() < until: await get_tree().process_frame
		return {"ok":true,"status":200,"error":"","data":value("verified" if calls >= finish_after else "verifying")}
	func value(status: String) -> Dictionary:
		return {"run_id":"run-a","ticket_id":"ticket-a","status":status,"time_ticks":100,"lap_ticks":[20,20,20,20,20],"outcome":null,"slot":null}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func adapter() -> Server:
	var server := Server.new()
	server._base_url = "http://fixture.invalid"
	server._access_token = "owned-fixture-token"
	server.player = {"id":"driver-a"}
	server._capabilities = {"run_wait_ms":30}
	root.add_child(server)
	return server

func collect(server: Node, target: Dictionary) -> void:
	target.response = await server.wait_for_run("run-a","ticket-a")
	target.done = true

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var server := adapter()
	var emissions := [0]
	server.run_completed.connect(func() -> void: emissions[0] += 1)
	var started: int = Time.get_ticks_msec()
	var first: Dictionary = {"done":false}
	var joined: Dictionary = {"done":false}
	collect(server,first)
	collect(server,joined)
	while not first.done or not joined.done: await process_frame
	check(first.response.data.status == "verified" and joined.response.data.status == "verified","late verification remains in the shared foreground wait")
	check(server.calls == 3 and Time.get_ticks_msec()-started < 1000,"completion after two wait windows avoids the polling delay")
	check(emissions[0] == 1 and server.recent_run("ticket-a").status == "verified","one exact terminal receipt wakes all result consumers")
	server.queue_free()
	await process_frame
	server = adapter()
	server.finish_after = 99
	var pending: Dictionary = await server.wait_for_run("run-a","ticket-a")
	check(pending.data.status == "verifying" and server.calls == 4 and not server.run_wait_pending("ticket-a"),"unfinished work returns to durable polling after four bounded requests")
	server.queue_free()
	await process_frame
	server = adapter()
	server.finish_after = 99
	server.immediate_pending = true
	pending = await server.wait_for_run("run-a","ticket-a")
	check(pending.data.status == "verifying" and server.calls == 1,"a busy or unsupported listener cannot cause a tight request loop")
	server.queue_free()
	await process_frame
	server = adapter()
	var stale: Dictionary = {"done":false}
	collect(server,stale)
	var deadline: int = Time.get_ticks_msec()+1000
	while server.calls < 2 and not stale.done and Time.get_ticks_msec() < deadline: await process_frame
	server.clear_session()
	server.player = {"id":"driver-b"}
	server._access_token = "owned-other-token"
	while not stale.done: await process_frame
	check(not stale.response.ok and stale.response.error == "ACCOUNT_CHANGED" and server.recent_run("ticket-a").is_empty(),"account changes between wait windows cannot publish another owner's result")
	server.queue_free()
	await process_frame
	server = adapter()
	server._capabilities.batch_run_status = true
	server.hold_batch = true
	var cloud := Cloud.new()
	cloud.client = server
	cloud.root_override = "user://prompt_completion_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	check((await cloud.queue_run_async({"ticket_id":"ticket-a"},[[0,255,0]])),"outbox fixture keeps the original durable evidence")
	var job: Dictionary = cloud.upload_job("ticket-a")
	job.run_id = "run-a"
	cloud._save_job(str(job._path),job)
	cloud.flush_outbox()
	deadline = Time.get_ticks_msec()+1000
	while server.batch_reads == 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(server.batch_reads == 1 and cloud.flushing,"a previous authoritative status read is in flight")
	await cloud._wait_for_upload("run-a","ticket-a","driver-a",server.base_url())
	server.batch_release.emit()
	deadline = Time.get_ticks_msec()+500
	while not cloud.upload_job("ticket-a").get("done",false) and Time.get_ticks_msec() < deadline: await process_frame
	check(cloud.upload_job("ticket-a").get("done",false) and server.batch_reads == 1 and server.calls == 3,"late pending poll cannot postpone the confirmed receipt or add another HTTP read")
	server.remember_run(server.value("verifying"))
	check(server.recent_run("ticket-a").status == "verified","a stale poll cannot replace terminal proof in the shared cache")
	server.remember_run(server.value("queued"),true)
	check(server.recent_run("ticket-a").status == "queued","an acknowledged explicit retry can restart the original run")
	cloud.queue_free()
	server.queue_free()
	await process_frame
	print("PROMPT_RUN_CONFIRMATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
