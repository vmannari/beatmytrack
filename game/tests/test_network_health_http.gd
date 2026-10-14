extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
const Monitor = preload("res://backend/network_health.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func run() -> void:
	var client := Client.new(); root.add_child(client)
	check(client.configure(OS.get_environment("BMT_NETWORK_HTTP_URL")) == OK,"owned loopback service configured")
	var bootstrap: Dictionary = await client.request_api("/bootstrap")
	check(bootstrap.ok and bootstrap.data.product_telemetry.network_schema_version == 1,"actual bootstrap negotiates network health")
	var signed: Dictionary = await client.development_login("network-http-fixture","Network Fixture",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(signed.ok and client.network_supported(),"owned development identity enables authenticated observations")
	if not signed.ok: quit(1); return
	var telemetry := Telemetry.new(); telemetry.client = client
	telemetry.storage_path = OS.get_environment("BMT_NETWORK_HTTP_EVIDENCE").get_base_dir().path_join("queue.json")
	root.add_child(telemetry); telemetry._timer.stop(); telemetry._next_upload_msec = Time.get_ticks_msec()+3600000
	telemetry.set_transport_allowed(false)
	var profile: Dictionary = await client.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	var failure: Dictionary = await client.request_api("/net-fixture-failure",HTTPClient.METHOD_GET,{},"",true)
	check(profile.ok and failure.status == 503 and failure.has("request_id"),"real HTTP failure preserves the middleware request ID for the caller")
	var rate: Dictionary = await client.request_api("/net-fixture-rate",HTTPClient.METHOD_GET,{},"",true)
	check(rate.status == 429 and rate.retry_after >= 60,"actual HTTP throttling and cooldown remain visible")
	var key: String = client.new_operation_key()
	client.note_upload_age(key,client.server_now()-120); client.note_request_preparation(key,10000)
	var payload: Dictionary = {"ticket_id":Telemetry.uuid(),"replay":{"schema":"bmt-trajectory-v1","input_count":1,"race_proof":{"schema":"bmt-race-path-v1","samples":[]},"rewinds":[]}}
	var first: Dictionary = await client.request_api("/runs",HTTPClient.METHOD_POST,payload,key,true)
	var second: Dictionary = await client.request_api("/runs",HTTPClient.METHOD_POST,payload,key,true)
	check(not first.ok and not second.ok,"diagnostic upload attempts create no verified race or score")
	var scope: String = client._network_scope()
	client.network_health._scopes[scope].due = 0
	telemetry._collect_network()
	check(not telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.event.name in Telemetry.NETWORK_NAMES),"closed race gate keeps network diagnostics in bounded RAM")
	telemetry.set_transport_allowed(true); telemetry._collect_network()
	var end: int = Time.get_ticks_msec()+10000
	while telemetry._dirty or telemetry._thread != null:
		telemetry.pump(); await process_frame
		if Time.get_ticks_msec() > end: break
	var packet: Dictionary = telemetry.batch_payload()
	var summaries: Array = packet.events.filter(func(event: Dictionary) -> bool: return event.name == "network_summary")
	var score: Dictionary = {}
	for event: Dictionary in summaries:
		if event.properties.category == "score_upload": score = event.properties
	check(summaries.size() == 3 and score.get("attempts") == 2 and score.get("retries") == 1 and score.get("upload_age_samples") == 2,"actual packet reports categories, repeated operations and anchored upload age")
	check(score.get("encode_ms",0) >= 10 and score.get("http_ms",0) >= 0,"external preparation is accounted separately from HTTP")
	var file := FileAccess.open(OS.get_environment("BMT_NETWORK_HTTP_EVIDENCE"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(packet)); file.close()
	check(file != null,"actual bounded packet retained for server-side comparison")
	await telemetry._upload(packet,telemetry._scope)
	check(not telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.event.name in Telemetry.NETWORK_NAMES),"actual committed server ACK removes immutable network events")
	check(client.network_health._scopes[scope].rows.is_empty(),"telemetry POST creates no recursive network observations")
	print("NETWORK_HTTP: ",checks," checks, ",failures," failures")
	telemetry.queue_free(); client.queue_free(); await process_frame; quit(1 if failures else 0)
