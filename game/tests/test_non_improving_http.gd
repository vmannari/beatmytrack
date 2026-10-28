extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class RetainedCloud extends "res://backend/cloud_tracks.gd":
	func _retire_replay(_job: Dictionary) -> void:
		pass # Keep this test's committed recording to exercise an exact retry body.

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	create_timer(90.0).timeout.connect(func() -> void: print("FAIL: skip HTTP deadline"); quit(1))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var client := Client.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_API_URL")) == OK,"configure owned loopback API")
	var boot: Dictionary = await client.request_api("/bootstrap")
	check(boot.ok and client._capabilities.get("non_improving_runs_version") == 1,"negotiate skip protocol")
	var login: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"authenticate the disposable fixture")
	var source: Dictionary = await client.request_api("/skip-fixture",HTTPClient.METHOD_POST,{},client.new_operation_key(),true)
	check(source.ok,"seed an authoritative race and flying-lap PB")
	if not source.ok: print(source); quit(1); return
	var issued: Dictionary = await client.race_ticket(str(source.data.version_id),"compact",client.new_operation_key())
	check(issued.ok,"obtain ordinary pinned race ticket")
	var cloud := RetainedCloud.new()
	cloud.client = client
	cloud.root_override = OS.get_environment("BMT_SKIP_NATIVE_ROOT")
	root.add_child(cloud)
	issued.data._race_proof = fixture.race_proof
	issued.data._race_ghost = fixture.ghost
	issued.data._claimed_lap_ticks = source.data.lap_ticks
	check(cloud.enqueue_completed(issued.data,fixture.replay.frames),"normal durable save queue accepts completed evidence")
	var directory: String = cloud.outbox_path().get_base_dir().path_join("runs")
	var path: String = directory.path_join(str(issued.data.ticket_id).sha256_text()+".job.json")
	var job: Dictionary = {}
	for attempt: int in range(80):
		await cloud.flush_outbox()
		job = Cloud._read_file(path)
		if job.get("done",false) or job.has("failure"): break
		await create_timer(0.1).timeout
	check(job.get("done",false) and not job.has("failure"),"skipped upload completes its outbox job")
	check(cloud.status == "Race completed","completion does not remain in verification pending")
	var recovered: Dictionary = await client.request_api(client.run_read_path("/run-tickets/"+str(issued.data.ticket_id)+"/submission"),HTTPClient.METHOD_GET,{},"",true)
	check(recovered.ok and recovered.data.run.status == "skipped" and recovered.data.run.skip_reason == "no_improvement","recover exact terminal skipped receipt")
	check(recovered.data.run.completion.reward.amount == 50,"normal completion reward is credited")
	var recording: Dictionary = Cloud._load_replay(directory.path_join(str(job.replay)),str(job.replay_hash))
	var body: Dictionary = Client._pack_trajectory(fixture.replay.frames.size(),recording.race_proof,recording.get("rewinds",[]),recording.get("ghost",{}),job.wire_options.incidents,int(job.wire_options.path) == 1,recording.claimed_lap_ticks)
	var retry: Dictionary = await client.request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":issued.data.ticket_id,"replay":body},str(job.key),true)
	check(retry.ok and retry.data.run_id == recovered.data.run.run_id and retry.data.status == "skipped","duplicate HTTP upload reuses the exact skipped run")
	var receipt: Dictionary = await client.request_api("/economy/rewards/"+str(issued.data.ticket_id),HTTPClient.METHOD_GET,{},"",true)
	check(receipt.ok and receipt.data.amount == 50,"durable reward receipt is unchanged after retry")
	var count: Dictionary = await client.request_api("/skip-fixture/count")
	check(count.ok and int(count.data.calls) == 0,"ordinary skipped completion invokes zero race verifications")
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	var chosen: Dictionary = await adapter.source(str(source.data.version_id),"compact",str(issued.data.ticket_id))
	check(chosen.get("status") in ["queued","verifying"],"choosing this run as a new Challenge target requests verification")
	for attempt: int in range(80):
		chosen = await adapter.source(str(source.data.version_id),"compact",str(issued.data.ticket_id))
		if chosen.get("status") == "verified": break
		await create_timer(0.1).timeout
	check(chosen.get("status") == "verified","the original real trajectory is verified for competitive reuse")
	count = await client.request_api("/skip-fixture/count")
	check(count.ok and int(count.data.calls) == 1,"explicit reuse invokes the verifier exactly once")
	receipt = await client.request_api("/economy/rewards/"+str(issued.data.ticket_id),HTTPClient.METHOD_GET,{},"",true)
	check(receipt.ok and receipt.data.amount == 50,"competitive reuse cannot credit a second reward")
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	print("NON_IMPROVING_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
