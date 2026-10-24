extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var client := Client.new()
	root.add_child(client)
	client.configure(OS.get_environment("BMT_API_URL"))
	var bootstrap: Dictionary = await client.request_api("/bootstrap")
	check(bootstrap.ok and int(bootstrap.data.get("race_path_wire_version",0)) == 1,"packed path negotiated over HTTP")
	check((await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))).ok,"fixture owner authenticated")
	var source: Dictionary = await client.request_api("/scale-fixture",HTTPClient.METHOD_GET,{},"",true)
	var issued: Dictionary = await client.race_ticket(str(source.data.version_id),"compact",Client.new_idempotency_key())
	check(issued.ok,"ordinary authoritative race ticket")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	issued.data._race_proof = fixture.race_proof
	issued.data._race_ghost = fixture.ghost
	issued.data._submit_key = client.new_operation_key()
	var cloud: Node = Cloud.new()
	cloud.client = client
	cloud.root_override = "user://packed_http_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	check(await cloud.queue_run_async(issued.data,fixture.replay.frames),"exact completed native recording is durable")
	var path: String = cloud.outbox_path().get_base_dir().path_join("runs").path_join(str(issued.data.ticket_id).sha256_text()+".job.json")
	var job: Dictionary = Cloud._read_file(path)
	check(int(job.wire_options.path) == 1,"durable journal pins negotiated format")
	var accepted: Dictionary = await cloud._submit_saved(job,path)
	check(accepted.ok,"packed body accepted by real HTTP receiver")
	if not accepted.ok:
		print("PACKED_HTTP_FAILURE "+str(accepted.get("error")))
		quit(1)
		return
	var result: Dictionary
	for turn: int in range(100):
		result = await client.request_api("/runs/"+str(accepted.data.run_id)+"?completion=true",HTTPClient.METHOD_GET,{},"",true)
		if result.ok and result.data.status in ["verified","rejected","failed"]: break
		await create_timer(0.1).timeout
	check(result.ok and result.data.status == "verified","real trajectory validator accepts same five laps")
	check(int(result.data.get("time_ticks",0)) == fixture.replay.frames.size(),"exact canonical finish ticks retained")
	check(result.data.get("lap_ticks",[]).size() == 5,"five actual lap splits retained")
	var stored: Dictionary = await client.request_api("/scale-fixture/stored?ticket_id="+str(issued.data.ticket_id),HTTPClient.METHOD_GET,{},"",true)
	var normal: Dictionary = Client._pack_trajectory(fixture.replay.frames.size(),fixture.race_proof,[],fixture.ghost,true)
	check(stored.ok and stored.data.replay == JSON.parse_string(JSON.stringify(normal)),"stored normalized proof/ghost match original unpacked native payload")
	var packed: Dictionary = Client._pack_trajectory(fixture.replay.frames.size(),fixture.race_proof,[],fixture.ghost,true,true)
	var plain_wire: Dictionary = Client._encode_request({"ticket_id":issued.data.ticket_id,"replay":normal})
	var packed_wire: Dictionary = Client._encode_request({"ticket_id":issued.data.ticket_id,"replay":packed})
	print("SCALE_WIRE_MEASUREMENTS "+JSON.stringify({"samples":fixture.race_proof.samples.size(),"plain_native_gzip_bytes":plain_wire.body.size(),"packed_native_gzip_bytes":packed_wire.body.size(),"includes_same_race_ghost":true}))
	var retry: Dictionary = await cloud._submit_saved(Cloud._read_file(path),path)
	check(retry.ok and retry.data.run_id == accepted.data.run_id,"exact retry recovers original run")
	var wallet: Dictionary = await client.request_api("/economy",HTTPClient.METHOD_GET,{},"",true)
	var second_wallet: Dictionary = await client.request_api("/economy",HTTPClient.METHOD_GET,{},"",true)
	check(wallet.ok and second_wallet.ok and wallet.data == second_wallet.data,"repeated wallet reads retain absolute reward and revision")
	check(result.data.get("completion",{}).get("reward",{}).get("status") == "credited","verified run still earns receipt")
	for node: Node in [cloud,client]: node.free()
	print("SCALE_OPTIMISATIONS_HTTP: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
