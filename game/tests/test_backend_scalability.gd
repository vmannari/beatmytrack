extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const Rivalry = preload("res://backend/weekly_rivalry_client.gd")
var checks: int = 0
var failures: int = 0
var frames_seen: int = 0

class SlowClient extends Client:
	var requests: int = 0
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		requests += 1
		await get_tree().create_timer(0.3).timeout
		return {"ok":true,"status":200,"data":{"run_id":"run-fixture","recording":{"ticks":12,"poses":[[0,0,0,0,0,0,0],[12,0,0,0,0,0,0]]}}}

func _initialize() -> void:
	process_frame.connect(func() -> void: frames_seen += 1)
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func run() -> void:
	var client := SlowClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:9")
	client.player = {"id":"scalability-fixture"}
	var controls: Array = [[127,255,0,5,2],[-127,0,255],[0,128,0,255]]
	var packed: Dictionary = Client._pack_replay(controls,[])
	var bytes: PackedByteArray = Marshalls.base64_to_raw(packed.controls)
	check(bytes == PackedByteArray([5,254,255,0,5,2,3,0,0,255,0,0,4,127,128,0,255,0]),"packed codec retains channels, widths and launch")
	check(Client._pack_replay([[0.5,255,0]],[]).is_empty(),"fractional controls rejected")
	check(Client._pack_replay(controls,[],false).frames == controls,"unadvertised protocol retains canonical legacy frames")
	var large: Array = []
	for index: int in range(216000): large.append([index%255-127,255,index%13,0])
	var before: int = frames_seen
	var started: int = Time.get_ticks_msec()
	var encoded: Variant = await client._background(Client._pack_replay.bind(large,[]))
	check(encoded is Dictionary and encoded.frame_count == 216000,"maximum replay retains every canonical tick")
	check(frames_seen > before+1,"maximum replay packing yields rendering frames")
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = "user://backend_scalability_"+Client.new_idempotency_key().sha256_text()
	root.add_child(cloud)
	before = frames_seen
	check(await cloud.queue_run_async({"ticket_id":"large-fixture"},large),"large outbox atomically persists")
	check(frames_seen > before+1,"outbox hash/JSON/file writes yield rendering frames")
	var jobs: Array = cloud.upload_jobs()
	check(jobs.size() == 1,"durable metadata names one outbox job")
	var restored: Variant = await client._background(Cloud._load_replay.bind(cloud.outbox_path().get_base_dir().path_join("runs").path_join(jobs[0].replay),jobs[0].replay_hash))
	check(restored is Dictionary and restored.has("frames") and restored.frames.size() == large.size(),"background read validates the full durable replay hash")
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0.0,0.0,0.0,0.0,0.0,0,0.0],[3,0.0,0.0,0.0,0.0,0.0,0,0.0]]}
	check(await cloud.queue_run_async({"ticket_id":"proof-fixture","_race_proof":proof},controls),"sparse movement proof persists with the completed result")
	var proof_job: Dictionary = cloud.upload_job("proof-fixture")
	var proof_saved: Variant = Cloud._load_replay(cloud.outbox_path().get_base_dir().path_join("runs").path_join(proof_job.replay),proof_job.replay_hash)
	var proof_wire: Dictionary = Client._pack_replay(proof_saved.frames,[],true,proof_saved.race_proof)
	check(proof_wire.get("race_proof",{}) == proof,"saved movement evidence survives the durable round trip after restoring integer wire fields")
	check(proof_wire.race_proof.samples[0][0] is int and proof_wire.race_proof.samples[0][6] is int,"restored float ticks and layer markers regain integer wire types")
	check(Client._pack_replay(proof_saved.frames,[],false,proof_saved.race_proof).race_proof == proof_wire.race_proof,"legacy wire fallback retains the same movement evidence")
	client.remember_run({"ticket_id":"proof-fixture","status":"queued"})
	await create_timer(0.3).timeout
	check(client.recent_run("proof-fixture").is_empty(),"pending result cache cannot hide a newly verified finish for three seconds")
	var rivalry := Rivalry.new()
	rivalry.client = client
	root.add_child(rivalry)
	rivalry.model.group_id = "group-fixture"
	rivalry.model.tracks = [{"entries":[{"id":"rival-fixture","run_id":"run-fixture"}]}]
	rivalry.snapshot_scope = rivalry.scope()
	var ghost_started: int = Time.get_ticks_msec()
	rivalry.prefetch_ghost(0,"rival-fixture")
	check(rivalry.cached_ghost(0,"rival-fixture").is_empty() and Time.get_ticks_msec()-ghost_started < 50,"cold optional ghost lookup returns immediately")
	rivalry.prefetch_ghost(0,"rival-fixture")
	await create_timer(0.5).timeout
	check(not rivalry.cached_ghost(0,"rival-fixture").is_empty() and client.requests == 1,"ghost prefetch coalesces and caches immutable run")
	client.player = {"id":"different-account"}
	check(rivalry.cached_ghost(0,"rival-fixture").is_empty(),"ghost cache isolated by account")
	print("Backend scalability: %d checks, %d failures; maximum replay work %d ms" % [checks,failures,Time.get_ticks_msec()-started])
	quit(1 if failures else 0)
