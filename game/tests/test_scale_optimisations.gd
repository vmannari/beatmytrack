extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Sync = preload("res://backend/appearance_sync.gd")
const State = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0

class Stub extends "res://backend/backend_client.gd":
	var requests: Array[Dictionary] = []
	var remote: Dictionary = {}
	var legacy_calls: int = 0
	func _ready() -> void: pass
	func _background(work: Callable) -> Variant: return work.call()
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", _auth: bool = false) -> Dictionary:
		requests.append({"path":path,"method":method,"payload":payload.duplicate(true),"key":key})
		if path == "/me/appearances":
			if method == HTTPClient.METHOD_PUT:
				remote[payload.appearance.vehicle_id] = payload.appearance.duplicate(true)
				return {"ok":true,"status":200,"data":payload.appearance,"error":""}
			return {"ok":true,"status":200,"data":{"appearances":remote.duplicate(true)},"error":""}
		return {"ok":true,"status":202,"data":{"run_id":"fixture-run","status":"queued"},"error":""}
	func submit_run(_ticket: String, _frames: Array, _key: String, _rewinds: Array = [], _proof: Dictionary = {}, _ghost: Dictionary = {}) -> Dictionary:
		legacy_calls += 1
		return {"ok":true,"status":202,"data":{"run_id":"old-job","status":"queued"},"error":""}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func proof() -> Dictionary:
	var negative_zero: float = PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
	return {"schema":"bmt-race-proof-v1","samples":[
		[0,-3.0,-18.0,0.0,0.0,0.0,0,0.0],
		[6,3,1.23456789012345,0.0,0.0,0.0,1,0.0],
		[12,negative_zero,7,0.0,0.0,0.0,0,0.0]],
		"incidents":{"schema":"bmt-race-incidents-v1","ticks":12,"collision_count":0,"off_track":false}}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var directory: String = "user://scale_optimisations_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var client := Stub.new()
	client._base_url = "http://fixture.invalid"
	client.player = {"id":"alice"}
	client._access_token = "owned-fixture-token"
	client._capabilities = {"race_path_wire_version":1,"race_incident_rewards_version":1,"trajectory_verification":true}
	root.add_child(client)
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/packed_path_v1.json"))
	var packet: Dictionary = Client._pack_trajectory(12,proof(),[],{},true,true)
	check(packet.race_proof.schema == "bmt-packed-path-v1","negotiated packed proof")
	if packet.race_proof.data != golden.packed.data: print("CODEC_DIAGNOSTIC "+JSON.stringify({"actual":packet.race_proof.data,"expected":golden.packed.data,"plain":Client._pack_trajectory(12,proof(),[],{},true)}))
	check(packet.race_proof.data == golden.packed.data,"native binary exactly matches independent golden Float64/integer/negative-zero records")
	check(packet.race_proof.incidents == proof().incidents,"incidents unchanged")
	check(Client._pack_trajectory(12,proof(),[],{},true).race_proof.schema == "bmt-race-path-v1","unnegotiated helper preserves old body")
	var frames: Array = [[0,255,0]]
	frames.resize(12)
	frames.fill([0,255,0])
	var cloud: Node = Cloud.new()
	cloud.client = client
	cloud.root_override = directory.path_join("cloud")
	root.add_child(cloud)
	var issued: Dictionary = {"ticket_id":"00000000-0000-4000-8000-000000000001","_submit_key":"pinned-original-key","_race_proof":proof()}
	check((await cloud.queue_run_async(issued,frames)),"durable new job admitted")
	var runs: String = cloud.outbox_path().get_base_dir().path_join("runs")
	var path: String = runs.path_join(str(issued.ticket_id).sha256_text()+".job.json")
	var job: Dictionary = Cloud._read_file(path)
	check(int(job.wire_options.path) == 1 and job.wire_options.incidents == true,"wire and reward options pinned before first request")
	var original_recording: String = FileAccess.get_file_as_string(runs.path_join(str(job.replay)))
	client._capabilities = {"trajectory_verification":true}
	check((await cloud.queue_run_async(issued,frames)),"repeat queue is idempotent after capability change")
	check(Cloud._read_file(path).wire_options.path == 1,"repeat queue never replaces original options")
	var deferred: Dictionary = await cloud._submit_saved(job,path)
	check(not deferred.ok and deferred.status == 503 and client.requests[-1].path == "/bootstrap","older server defers packed job without sending an unsupported submission")
	check(Cloud._read_file(path).key == "pinned-original-key" and not Cloud._read_file(path).has("failure"),"deferred job retains original identity and recovery")
	await cloud._flush_jobs()
	var deferred_job: Dictionary = Cloud._read_file(path)
	check(not deferred_job.has("failure") and int(deferred_job.wire_options.path) == 1 and int(deferred_job.get("retry_delay",0)) >= 15,"actual upload consumer retains unsupported job for retry")
	client._capabilities = {"race_path_wire_version":1,"trajectory_verification":true}
	await cloud._submit_saved(job,path)
	var sent: Dictionary = client.requests[-1].duplicate(true)
	check(sent.payload.replay.race_proof.schema == "bmt-packed-path-v1" and sent.key == "pinned-original-key","capability change cannot re-encode original queued body")
	# Reload both journal and controls, as a restarted client does.
	job = Cloud._read_file(path)
	await cloud._submit_saved(job,path)
	check(JSON.stringify(client.requests[-1].payload) == JSON.stringify(sent.payload) and client.requests[-1].key == sent.key,"restart/retry preserves exact body and operation key")
	check(FileAccess.get_file_as_string(runs.path_join(str(job.replay))) == original_recording,"retry does not rewrite original recording")
	job.erase("wire_options")
	await cloud._submit_saved(job,path)
	check(client.legacy_calls == 1,"pre-update saved job retains legacy encoder path")
	client._capabilities = {"trajectory_verification":true}
	issued.ticket_id = "00000000-0000-4000-8000-000000000002"
	check(await cloud.queue_run_async(issued,frames),"old-server job queued asynchronously")
	var old_path: String = runs.path_join(str(issued.ticket_id).sha256_text()+".job.json")
	var old_job: Dictionary = Cloud._read_file(old_path)
	client._capabilities = {"race_path_wire_version":1,"race_incident_rewards_version":1,"trajectory_verification":true}
	await cloud._submit_saved(old_job,old_path)
	check(client.requests[-1].payload.replay.race_proof.schema == "bmt-race-path-v1" and not client.requests[-1].payload.replay.race_proof.has("incidents"),"later server upgrade cannot change originally unnegotiated proof or bonus fields")
	var record := LocalRecords.new(directory.path_join("records.json"))
	record.load_records()
	var policy: Dictionary = {"allowed":false}
	var sync: Node = Sync.new()
	sync.client = client
	sync.clean_poll_allowed = func() -> bool: return bool(policy.allowed)
	root.add_child(sync)
	sync.bind_records(record)
	await sync.refresh()
	client.requests.clear()
	for ignored: int in range(60): sync._poll_refresh()
	check(client.requests.is_empty(),"sixty clean race timer opportunities create zero HTTP requests")
	var car: Dictionary = State.car(record.settings,"compact")
	car.livery.colors.body = "abcdef"
	client.remote["compact"] = car.duplicate(true)
	sync._last_success_msec = Time.get_ticks_msec()-30001
	policy.allowed = true
	await sync.refresh_if_stale()
	check(client.requests.size() == 1 and State.car(record.settings,"compact").livery.colors.body == "abcdef","return to menu restores remote edit promptly")
	await sync.refresh_if_stale()
	check(client.requests.size() == 1,"fresh menu transitions share current appearance")
	policy.allowed = false
	car.livery.colors.body = "123456"
	State.apply(record.settings,car)
	check(record.save_records() == OK,"local edit saved before sync")
	sync._debounce.stop()
	await sync._poll_refresh()
	check(client.remote.compact.livery.colors.body == "123456" and State.pending(record.settings).is_empty(),"dirty race state still sends GET/CAS write and acknowledges durably")
	var previous: int = client.requests.size()
	sync.status = "Retry required"
	await sync._poll_refresh()
	check(client.requests.size() == previous+1 and sync.status.is_empty(),"recovery remains active during race")
	var pending: Dictionary = State.car(record.settings,"compact")
	pending.livery.colors.body = "fedcba"
	State.apply(record.settings,pending)
	client.remote["compact"] = pending.duplicate(true)
	record.settings[State.KEY].pending = {"compact":pending.duplicate(true)}
	check(record.save_records() == OK,"lost-reply evidence persists")
	sync._debounce.stop()
	await sync._poll_refresh()
	check(State.pending(record.settings).is_empty() and State.baseline(record.settings).compact == pending,"lost reply acknowledged while clean polling is suppressed")
	var source_path: String = ""
	var output_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--proof-source="): source_path = arg.trim_prefix("--proof-source=")
		if arg.begins_with("--wire-output="): output_path = arg.trim_prefix("--wire-output=")
	if not source_path.is_empty() and not output_path.is_empty():
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var count: int = int(source.samples[-1][0])
		var paired: Dictionary = {"plain":Client._pack_trajectory(count,source,[]),"packed":Client._pack_trajectory(count,source,[],{},false,true)}
		var timings: Dictionary = {}
		for mode: String in ["plain","packed"]:
			var elapsed: Array[int] = []
			for trial: int in range(11):
				var started: int = Time.get_ticks_usec()
				var sample: Dictionary = Client._pack_trajectory(count,source,[],{},false,mode == "packed")
				var encoded: Dictionary = Client._encode_request({"ticket_id":"timing-fixture","replay":sample})
				elapsed.append(Time.get_ticks_usec()-started)
				timings[mode+"_native_gzip_bytes"] = encoded.body.size()
			elapsed.sort()
			timings[mode+"_preparation_encode_gzip_median_usec"] = elapsed[5]
		paired.native_metrics = timings
		var file := FileAccess.open(output_path,FileAccess.WRITE)
		check(file != null,"paired native proof artifact opens")
		if file != null: file.store_string(JSON.stringify(paired))
	for node: Node in [sync,cloud,client]: node.free()
	print("SCALE_OPTIMISATIONS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
