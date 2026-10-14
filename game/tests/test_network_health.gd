extends SceneTree
const Monitor = preload("res://backend/network_health.gd")
const Client = preload("res://backend/backend_client.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}
class MockTransport extends Client:
	var answer: Dictionary = {"ok":true,"status":200,"data":{"id":"fixture-player"},"error":""}
	var headers: PackedStringArray = PackedStringArray()
	var delay: float = 0.015
	func _send_transport(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _auth: bool, _key: String, _extra: PackedStringArray, _owner: int, metrics: Dictionary) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		while Time.get_ticks_usec()-started < int(delay*1000000.0): await get_tree().process_frame
		metrics.http_ms = (Time.get_ticks_usec()-started)/1000
		metrics.http_status = int(answer.status); metrics.request_id = Monitor.request_id(headers)
		metrics.request_body_bytes = 10; metrics.response_body_bytes = 20
		return answer.duplicate(true)
class FakeClient extends Node:
	var player: Dictionary = {"id":"network-fixture"}
	var supported: bool = true
	var network_health: RefCounted = Monitor.new()
	var calls: int = 0
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://127.0.0.1:18881"
	func telemetry_supported() -> bool: return true
	func network_supported() -> bool: return supported
	func auth_busy() -> bool: return false
	func server_now() -> int: return 0
	func cancel_telemetry() -> void: pass
	func request_telemetry(payload: Dictionary) -> Dictionary:
		calls += 1
		var acks: Array = []
		for event: Dictionary in payload.events: acks.append({"id":event.id,"status":"accepted"})
		return {"ok":true,"data":{"schema":"bmt-product-acks-v1","events":acks}}
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func numbers(status: int = 200) -> Dictionary:
	return {"http_status":status,"total_ms":200,"queue_ms":20,"encode_ms":10,"http_ms":160,"decode_ms":5,"retry_index":0,"upload_age_seconds":-1,"request_body_bytes":100,"response_body_bytes":200}
func wait_saved(telemetry: Node) -> void:
	var end: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < end:
		telemetry.pump()
		if telemetry._loaded and telemetry._thread == null and not telemetry._dirty: return
		await process_frame
	check(false,"atomic diagnostic snapshot completes")
func run() -> void:
	for path: String in ["/run-tickets?token=private","/rivalry/private/tickets","/challenges/private/tickets"]: check(Monitor.category(path) == "race_ticket","ticket category contains no identifiers")
	check(Monitor.category("/telemetry/batches").is_empty(),"telemetry transport is excluded to avoid feedback")
	check(Monitor.category("/unknown/private-id?secret=value") == "other","unknown paths use one bounded category")
	var identifier: String = Telemetry.uuid()
	check(Monitor.request_id(PackedStringArray(["x-request-id: "+identifier])) == identifier,"validated server request UUID survives")
	check(Monitor.request_id(PackedStringArray(["X-Request-Id: secret / credential"])).is_empty(),"arbitrary response identifiers are discarded")
	var monitor := Monitor.new()
	monitor.note_preparation("a","private-operation",12000,120)
	var first: Dictionary = monitor.begin("a","private-operation")
	var next: Dictionary = monitor.begin("a","private-operation")
	check(first.retry_index == 0 and first.extra_encode_us == 12000 and first.upload_age_seconds == 120,"preparation and anchored upload age attach to the first transmission")
	check(next.retry_index == 1 and next.extra_encode_us == 0,"operation repeats are counted and preparation is consumed once")
	var metrics: Dictionary = numbers(); metrics.upload_age_seconds = 120
	monitor.record("a","score_upload","POST",{"ok":true},metrics)
	metrics = numbers(429); metrics.retry_index = 1; metrics.upload_age_seconds = 120
	monitor.record("a","score_upload","POST",{"ok":false,"status":429,"error":"PRIVATE ERROR TEXT","request_id":identifier},metrics)
	monitor.record("a","score_upload","POST",{"ok":false,"status":0,"error":"NETWORK_ERROR","transport_result":HTTPRequest.RESULT_CANT_RESOLVE},numbers(0))
	monitor.record("a","score_upload","POST",{"ok":false,"status":0,"error":"CANCELLED"},numbers(0))
	var records: Array[Dictionary] = monitor.pending("a",Monitor.INTERVAL_MSEC+Time.get_ticks_msec())
	var summary: Dictionary = records[0].properties
	check(summary.attempts == 4 and summary.successes == 1 and summary.cancelled == 1 and summary.retries == 1 and summary.throttled == 1,"success, failure, cancellation, retry and throttling stay distinct")
	check(summary.upload_age_samples == 2 and summary.upload_age_buckets[4] == 2,"legacy/unanchored attempts do not invent upload age")
	check(summary.error_buckets[2] == 1 and summary.error_buckets[13] == 1,"DNS and server throttling use fixed failure types")
	check(not JSON.stringify(records).contains("PRIVATE ERROR") and not JSON.stringify(records).contains("private-operation"),"payload text, raw operation keys and URLs never enter summaries")
	check(records.size() == 3 and records[1].properties.request_id == identifier and not records[2].properties.has("request_id"),"selected failures retain received IDs and leave pre-server failures unavailable")
	check(not Monitor.normalize("network_summary",JSON.parse_string(JSON.stringify(summary))).is_empty(),"JSON restart normalizes integral numbers without stripping diagnostics")
	var corrupt: Dictionary = summary.duplicate(true); corrupt.http_ms = corrupt.total_ms+1
	check(Monitor.normalize("network_summary",corrupt).is_empty(),"impossible timing totals are rejected")
	for index: int in range(1000):
		monitor.note_preparation("a","op-"+str(index),0)
		monitor.record("a",Monitor.CATEGORIES[index%Monitor.CATEGORIES.size()],"GET",{"ok":false,"status":500},numbers(500))
	check(monitor._scopes.a.operations.size() <= Monitor.MAX_OPERATIONS and monitor._scopes.a.rows.size() <= Monitor.CATEGORIES.size() and monitor._scopes.a.failures.size() <= Monitor.MAX_FAILURES,"request storms keep fixed category, operation and selected-failure bounds")
	for index: int in range(10): monitor.record("scope-"+str(index),"profile","GET",{"ok":true},numbers())
	check(monitor._scopes.size() == Monitor.MAX_SCOPES and monitor.pending("a",999999999).is_empty(),"bounded profile retention never merges counters across accounts")
	var pending_scope: String = "scope-9"
	monitor._scopes[pending_scope].born = Time.get_ticks_msec()-Monitor.MAX_RAM_AGE_MSEC-1
	check(monitor.pending(pending_scope,999999999).is_empty(),"expired RAM counters cannot appear as new current observations")
	var transport := MockTransport.new(); root.add_child(transport)
	transport.configure("http://127.0.0.1:18881"); transport._access_token = "synthetic-only"; transport.player = {"id":"fixture-player"}
	transport._capabilities = {"product_telemetry":{"enabled":true,"schema_version":1,"network_schema_version":1}}
	transport.headers = PackedStringArray(["X-Request-Id: "+identifier])
	transport.answer = {"ok":false,"status":503,"data":{},"error":"TEMPORARY"}
	transport._busy = true
	var received: Array = []
	func_call(transport,received)
	var wait_until: int = Time.get_ticks_usec()+35000
	while Time.get_ticks_usec() < wait_until: await process_frame
	transport._busy = false
	while received.is_empty(): await process_frame
	var scope: String = transport._network_scope()
	check(received[0].request_id == identifier,"caller receives the safe request ID even on a failure")
	var measured: Dictionary = transport.network_health.pending(scope,Time.get_ticks_msec()+Monitor.INTERVAL_MSEC)[0].properties
	check(measured.queue_ms >= 20 and measured.http_ms > 0 and measured.total_ms >= measured.queue_ms+measured.http_ms,"actual mutation wait and HTTP callback interval are measured separately")
	var before: int = measured.attempts
	await transport.request_telemetry({"schema":"ignored"})
	check(transport.network_health.pending(scope,Time.get_ticks_msec()+Monitor.INTERVAL_MSEC)[0].properties.attempts == before,"telemetry delivery cannot measure and regenerate itself")
	var fake := FakeClient.new(); root.add_child(fake)
	var directory: String = "user://network-health-"+Telemetry.uuid()
	DirAccess.make_dir_recursive_absolute(directory)
	var telemetry := Telemetry.new(); telemetry.client = fake; telemetry.storage_path = directory.path_join("queue.json"); root.add_child(telemetry); telemetry._timer.stop()
	telemetry._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(telemetry)
	telemetry.queue.clear(); telemetry._persisted_ids.clear(); telemetry._recount_budget()
	fake.network_health.record(telemetry._scope,"profile","GET",{"ok":false,"status":503,"request_id":identifier},numbers(503))
	fake.network_health._scopes[telemetry._scope].due = 0
	telemetry.set_transport_allowed(false); telemetry._collect_network()
	check(telemetry.queue.is_empty() and telemetry._thread == null and fake.calls == 0,"racing starts no diagnostic snapshot, disk worker or HTTP request")
	telemetry.set_transport_allowed(true); telemetry._collect_network(); await wait_saved(telemetry)
	check(telemetry.queue.size() == 2 and telemetry.queue[0].event.name == "network_summary","menu-time snapshot moves one summary and selected failure into the existing outbox")
	telemetry._pending_since_msec = 0; telemetry._journey_pending_msec = -1
	check(not telemetry._flush_due(60000) and telemetry._flush_due(300000),"network-only diagnostics retain the existing five-minute passive batching policy")
	var event_ids: Array = telemetry.queue.map(func(entry: Dictionary) -> String: return str(entry.event.id))
	fake.supported = false
	check(telemetry.batch_payload().events.is_empty(),"old/disabled network capability defers persisted diagnostics without probing")
	fake.supported = true
	var restored := Telemetry.new(); restored.client = fake; restored.storage_path = telemetry.storage_path; root.add_child(restored); restored._timer.stop(); restored._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(restored)
	var diagnostics: Array = restored.queue.filter(func(entry: Dictionary) -> bool: return entry.event.name in Telemetry.NETWORK_NAMES)
	check(diagnostics.size() == 2 and diagnostics.map(func(entry: Dictionary) -> String: return str(entry.event.id)) == event_ids,"restart preserves immutable network event IDs and validated compact arrays")
	evidence.packet_bytes = JSON.stringify(restored.batch_payload()).to_utf8_buffer().size()
	await restored._upload(restored.batch_payload(),restored._scope)
	check(not restored.queue.any(func(entry: Dictionary) -> bool: return entry.event.name in Telemetry.NETWORK_NAMES),"only committed ACK removes diagnostic records")
	print("NETWORK_HEALTH: ",checks," checks, ",failures," failures; ",JSON.stringify(evidence))
	telemetry.queue_free(); restored.queue_free(); fake.queue_free(); transport.queue_free(); await process_frame
	quit(1 if failures else 0)
func func_call(transport: Node, received: Array) -> void:
	received.append(await transport.request_api("/me",HTTPClient.METHOD_PATCH,{"country_code":"FI"},"private-fixture-operation",true))
