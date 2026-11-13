extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
const Quality = preload("res://backend/client_quality.gd")
var checks: int = 0
var failures: int = 0

class DelayedClient extends Client:
	signal release_response
	var entered: bool = false
	func _send_transport(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String, _headers: PackedStringArray, _owner: int, metrics: Dictionary) -> Dictionary:
		entered = true
		await release_response
		metrics.http_ms = 0
		metrics.http_status = 200
		return {"ok":true,"status":200,"data":{},"error":""}

class PacketClient extends Node:
	var player: Dictionary = {"id":"packet-owner"}
	var limit: int = 2
	var modern: bool = true
	func base_url() -> String: return "http://127.0.0.1:1"
	func signed_in() -> bool: return true
	func telemetry_supported() -> bool: return true
	func loss_counters_supported() -> bool: return modern
	func network_supported() -> bool: return true
	func server_now() -> int: return 0
	func auth_busy() -> bool: return false
	func cancel_telemetry() -> void: pass
	func request_telemetry(packet: Dictionary) -> Dictionary:
		await get_tree().process_frame
		if packet.events.size() > limit: return {"ok":false,"status":413}
		var acknowledgements: Array = []
		for event: Dictionary in packet.events: acknowledgements.append({"id":event.id,"status":"accepted"})
		return {"ok":true,"data":{"schema":"bmt-product-acks-v1","events":acknowledgements}}

func _initialize() -> void: call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+label)

func send(client: Node, completed: Array) -> void:
	completed.append(await client._send("/me",HTTPClient.METHOD_GET,{},true))

func wait_saved(telemetry: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		telemetry.pump()
		if telemetry._loaded and telemetry._thread == null and not telemetry._dirty: return
		await process_frame
	check(false,"bounded atomic outbox write completes")

func clear_queue(telemetry: Node) -> void:
	telemetry.queue.clear()
	telemetry._persisted_ids.clear()
	telemetry._recount_budget()
	telemetry._mark_dirty()

func equivalent(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return float(left) == float(right)
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index: int in range(left.size()):
			if not equivalent(left[index],right[index]): return false
		return true
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not equivalent(left[key],right[key]): return false
		return true
	return left == right

func run() -> void:
	for reenable: bool in [false,true]:
		var client := DelayedClient.new(); root.add_child(client)
		client.configure("http://127.0.0.1:1")
		client._access_token = "local-fixture-only"
		client.player = {"id":"fixture-owner","analytics_enabled":true}
		client._capabilities = {"product_telemetry":{"enabled":true,"schema_version":1,"network_schema_version":1,"quality_schema_version":2}}
		var telemetry := Telemetry.new(); telemetry.client = client; root.add_child(telemetry); telemetry._timer.stop()
		var quality := Quality.new(); quality.telemetry = telemetry; root.add_child(quality); quality.set_process(false)
		quality.sample_frame("menu",101.0)
		quality.start_race()
		quality.sample_frame("race",101.0)
		var completed: Array = []
		send(client,completed)
		check(client.entered,"ordinary request starts before withdrawal")
		telemetry.set_enabled(false)
		check(quality.bins.is_empty() and not quality._active and quality._race_frame_count == 0,"withdrawal immediately clears menu and active-race diagnostics")
		if reenable: telemetry.set_enabled(true)
		client.release_response.emit()
		while completed.is_empty(): await process_frame
		check(client.network_health._scopes.is_empty(),"late request completion cannot recreate counters across consent transition "+str(reenable))
		if not reenable: telemetry.set_enabled(true)
		quality.flush_frames()
		check(not quality.finish_race("finished") and not telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.event.name in ["quality_summary","network_summary","race_statistics"]),"re-enable cannot upload pre-withdrawal quality data")
		quality.queue_free(); telemetry.queue_free(); client.queue_free(); await process_frame

	var fake := PacketClient.new(); root.add_child(fake)
	var path: String = "user://telemetry-reliability/queue-"+Telemetry.uuid()+".json"
	var collector := Telemetry.new(); collector.client = fake; collector.storage_path = path
	root.add_child(collector); collector._timer.stop(); collector._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(collector)
	clear_queue(collector)
	for index: int in range(4): collector.observe("car_selected",{"car_id":"kart"})
	await wait_saved(collector)
	var original_ids: Array = collector.queue.map(func(entry: Dictionary) -> String: return entry.event.id)
	await collector._upload(collector.batch_payload(),collector._scope)
	check(collector.queue.size() == 4 and collector.batch_payload().events.size() == 2,"413 halves packet size and retains all durable events")
	await collector._upload(collector.batch_payload(),collector._scope)
	await wait_saved(collector)
	check(collector.queue.size() == 2 and collector.queue[0].event.id == original_ids[2],"reduced packet ACK removes only its own events")
	fake.limit = 0
	await collector._upload(collector.batch_payload(),collector._scope)
	await collector._upload(collector.batch_payload(),collector._scope)
	check(collector.queue.size() == 1 and collector.queue[0].event.id == original_ids[3] and collector.rejected_events == 1,"permanently oversized singleton is counted and cannot block its sibling")
	fake.limit = 1
	await collector._upload(collector.batch_payload(),collector._scope)
	check(collector.queue.is_empty(),"valid sibling drains after an oversized singleton")
	await wait_saved(collector)
	clear_queue(collector)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/telemetry_utf8_batch.json"))
	collector._batch_event_limit = Telemetry.MAX_BATCH_EVENTS
	for event: Dictionary in fixture.events:
		var normalized: Dictionary = collector._safe_properties(event.name,event.properties)
		check(equivalent(normalized,event.properties),"shared Unicode event normalizes without content changes")
		var native_event: Dictionary = event.duplicate(true)
		native_event.properties = normalized
		for field: String in ["occurred_at","seq","monotonic_ms"]: native_event[field] = int(native_event[field])
		collector.queue.append({"scope":collector._scope,"build_id":fixture.build_id,"platform":fixture.platform,"clock_quality":"client_clock","event":native_event})
		collector._persisted_ids[str(event.id)] = true
	var packet: Dictionary = collector.batch_payload()
	check(packet.events.size() == 50 and JSON.stringify(packet).to_utf8_buffer().size() < Telemetry.MAX_BATCH_BYTES,"actual client packet retains all 50 Unicode events below the 64KiB limit")
	clear_queue(collector)
	# Scope changes attribute increments before switching, never another account's
	# lifetime total. The exact source watermark survives atomic outbox restart.
	collector.dropped_events += 5
	collector._next_summary_msec = 0
	collector._report_losses()
	var first: Dictionary = collector.queue[-1].event.properties.duplicate()
	check(first.has("counter_id") and first.dropped_events >= 5,"modern capability reports a scoped counter lifetime")
	fake.player.id = "second-owner"; collector.update_identity()
	collector.dropped_events += 3; collector._next_summary_msec = 0; collector._report_losses()
	var second: Dictionary = collector.queue[-1].event.properties.duplicate()
	check(second.counter_id != first.counter_id and second.dropped_events == 3,"second account receives only its three new losses")
	await wait_saved(collector)
	fake.modern = false
	check(not collector.batch_payload().events.any(func(event: Dictionary) -> bool: return event.name == "collection_summary" and event.properties.has("counter_id")),"server downgrade defers modern loss records instead of permanent rejection")
	collector.dropped_events += 1; collector._next_summary_msec = 0
	var before_downgrade: int = collector.queue.size()
	collector._report_losses()
	check(collector.queue.size() == before_downgrade,"downgrade does not recount scoped observations as legacy totals")
	fake.modern = true
	collector._next_summary_msec = 0; collector._report_losses()
	second = collector.queue[-1].event.properties.duplicate()
	check(second.dropped_events == 4,"renegotiation keeps the exact scoped counter lifetime")
	await wait_saved(collector)
	var restored := Telemetry.new(); restored.client = fake; restored.storage_path = path
	root.add_child(restored); restored._timer.stop(); restored._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(restored)
	restored._next_summary_msec = 0; restored._report_losses()
	check(restored.queue[-1].event.properties.counter_id == second.counter_id and restored.queue[-1].event.properties.dropped_events == second.dropped_events,"restart retains counter identity and exact cumulative watermark")
	fake.player.id = "packet-owner"; restored.update_identity()
	restored.dropped_events += 1; restored._next_summary_msec = 0; restored._report_losses()
	check(restored.queue[-1].event.properties.counter_id == first.counter_id and restored.queue[-1].event.properties.dropped_events == first.dropped_events+1,"returning account continues its original watermark without importing other losses")
	# Bound the local bookkeeping and give evicted scopes a fresh lifetime.
	for index: int in range(40):
		fake.player.id = "bounded-owner-"+str(index); restored.update_identity()
		restored.dropped_events += 1; restored._next_summary_msec = 0; restored._report_losses()
	check(restored._losses.sources.size() == 32,"loss bookkeeping retains at most 32 account scopes")
	fake.player.id = "packet-owner"; restored.update_identity()
	restored.dropped_events += 1; restored._next_summary_msec = 0; restored._report_losses()
	check(restored.queue[-1].event.properties.counter_id != first.counter_id and restored.queue[-1].event.properties.dropped_events == 1,"evicted scope starts an independent counter lifetime")
	var withdrawn_id: String = restored.queue[-1].event.properties.counter_id
	restored.set_enabled(false); restored.set_enabled(true)
	restored._next_summary_msec = 0; restored._report_losses()
	check(not restored.queue.any(func(entry: Dictionary) -> bool: return entry.event.name == "collection_summary"),"withdrawal removes retained loss summaries and baselines")
	restored.dropped_events += 1; restored._next_summary_msec = 0; restored._report_losses()
	check(restored.queue[-1].event.properties.counter_id != withdrawn_id and restored.queue[-1].event.properties.dropped_events == 1,"new consent starts a fresh counter lifetime with only new losses")
	collector.queue_free(); restored.queue_free(); fake.queue_free(); await process_frame
	DirAccess.remove_absolute(path)
	print("TELEMETRY_RELIABILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
