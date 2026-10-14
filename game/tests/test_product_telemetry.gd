extends SceneTree
const Telemetry = preload("res://backend/product_telemetry.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}
var published_version: String = Telemetry.uuid()
var test_directory: String = ProjectSettings.globalize_path("res://../build/telemetry-analysis-2026-10-11/client-test")

class FakeClient extends Node:
	var player: Dictionary = {"id":"player-a"}
	var authenticated: bool = true
	var supported: bool = true
	var requests: Array[Dictionary] = []
	var failure: bool = false
	var ack_schema: String = "bmt-product-acks-v1"
	var ack_status: String = "accepted"
	var server_sample: int = 0
	var cancelled: int = 0
	func base_url() -> String: return "http://127.0.0.1:18181"
	func signed_in() -> bool: return authenticated
	func telemetry_supported() -> bool: return authenticated and supported
	func auth_busy() -> bool: return false
	func server_now() -> int: return server_sample
	func cancel_telemetry() -> void: cancelled += 1
	func request_telemetry(payload: Dictionary) -> Dictionary:
		requests.append(payload.duplicate(true))
		await get_tree().process_frame
		if failure: return {"ok":false,"status":503}
		var acknowledgements: Array[Dictionary] = []
		for event: Dictionary in payload.events: acknowledgements.append({"id":event.id,"status":ack_status})
		acknowledgements.append({"id":"00000000-0000-4000-8000-000000000000","status":"accepted"})
		return {"ok":true,"data":{"schema":ack_schema,"events":acknowledgements}}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)

func wait_saved(telemetry: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		telemetry.pump()
		if telemetry._loaded and telemetry._thread == null and not telemetry._dirty: return
		await process_frame
	check(false,"bounded worker persistence completes")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(test_directory)
	var path: String = test_directory.path_join("queue-"+Telemetry.uuid()+".json")
	var fake := FakeClient.new()
	root.add_child(fake)
	var telemetry := Telemetry.new()
	telemetry.client = fake
	telemetry.storage_path = path
	root.add_child(telemetry)
	telemetry._timer.stop()
	telemetry._next_upload_msec = Time.get_ticks_msec()+3600000
	telemetry.observe("menu_ready",{},"fast-menu")
	var early_events: Array[String] = []
	for entry: Dictionary in telemetry.queue: early_events.append(str(entry.event.name))
	check(early_events == ["session_started","app_first_open","menu_ready"],"fast authenticated startup reserves first-open before menu-ready while queue read is pending")
	check(int(telemetry.queue[1].event.seq) < int(telemetry.queue[2].event.seq) and int(telemetry.queue[1].event.monotonic_ms) <= int(telemetry.queue[2].event.monotonic_ms),"fast-start first-open ordering is consistent in sequence and monotonic time")
	await wait_saved(telemetry)
	check(telemetry.queue.size() == 3,"first authenticated collection persists one first-open and actual menu-ready")
	check(telemetry.queue[0].event.id.substr(14,1) == "4" and telemetry.queue[0].event.id.substr(19,1) in ["8","9","a","b"],"durable event IDs are UUIDv4")
	var before: int = telemetry.queue.size()
	fake.authenticated = false
	telemetry.update_identity()
	check(not telemetry.observe("race_started") and telemetry.queue.size() == before,"guests generate no observations and no linking")
	fake.authenticated = true
	fake.supported = false
	telemetry.update_identity()
	check(not telemetry.observe("race_started"),"old or disabled backend capability suppresses collection")
	fake.supported = true
	telemetry.update_identity()
	check(telemetry.queue[-1].event.name == "session_started","enabling negotiated collection within an account starts an observed session")
	check(telemetry.observe("track_exposed",{"track_version_id":Telemetry.uuid(),"position":0,"car_id":"compact","access_token":"private","biome":"player name / path","mode":"free"},"one"),"governed exposure accepted")
	check(not telemetry.observe("track_exposed",{"track_version_id":published_version},"one"),"session duplicate exposure suppressed")
	var properties: Dictionary = telemetry.queue[-1].event.properties
	check(not properties.has("access_token") and not properties.has("biome") and properties.has("car_id"),"freeform names paths tokens and unknown properties excluded")
	telemetry.set_transport_allowed(false)
	telemetry.observe("race_started",{"car_id":"compact","mode":"free"})
	telemetry.pump()
	check(telemetry._thread == null and fake.requests.is_empty(),"racing enqueues without starting disk workers or network")
	check(fake.cancelled > 0,"racing cancels optional in-flight traffic")
	telemetry.background()
	check(not telemetry._foreground and telemetry._thread == null,"focus-out cancels observations without starting persistence during a live race")
	telemetry.background(true)
	check(telemetry._thread == null,"explicit application pause keeps active-race observations in RAM without starting disk work")
	var pause_save_deadline: int = Time.get_ticks_msec()+10000
	while telemetry._thread != null and telemetry._thread.is_alive() and Time.get_ticks_msec() < pause_save_deadline: await process_frame
	telemetry._finish_thread()
	telemetry.foreground()
	telemetry.set_transport_allowed(true)
	await wait_saved(telemetry)
	var race_samples: Array[int] = []
	telemetry.set_transport_allowed(false)
	var race_pool_before: int = telemetry._event_ids.size()
	for index: int in range(64):
		var race_event_start: int = Time.get_ticks_usec()
		telemetry.observe("race_started",{"car_id":"compact","mode":"free"})
		race_samples.append(Time.get_ticks_usec()-race_event_start)
	race_samples.sort()
	evidence.race_enqueue_p50_usec = race_samples[32]
	evidence.race_enqueue_p95_usec = race_samples[60]
	evidence.race_enqueue_max_usec = race_samples[-1]
	check(telemetry._event_ids.size() == race_pool_before-64 and telemetry._thread == null,"race observation IDs are preallocated without refill or persistence work")
	var preserved_ids: Array[String] = telemetry._event_ids
	telemetry._event_ids = []
	var pool_loss_before: int = telemetry.dropped_events
	check(not telemetry.observe("session_heartbeat",{"foreground_ms":60000}) and telemetry.dropped_events == pool_loss_before+1,"exhausted live-race ID pool records loss instead of calling the random provider")
	telemetry._event_ids = preserved_ids
	telemetry.set_transport_allowed(true)
	await wait_saved(telemetry)
	var start: int = Time.get_ticks_usec()
	var samples: Array[int] = []
	for index: int in range(1100):
		var event_start: int = Time.get_ticks_usec()
		telemetry.observe("track_selected",{"track_version_id":published_version,"car_id":"compact","mode":"free","position":index%1001})
		samples.append(Time.get_ticks_usec()-event_start)
	evidence.enqueue_1100_usec = Time.get_ticks_usec()-start
	samples.sort()
	evidence.enqueue_p50_usec = samples[550]
	evidence.enqueue_p95_usec = samples[1045]
	evidence.enqueue_max_usec = samples[-1]
	check(telemetry.queue.size() == 1000 and telemetry.dropped_events >= 100,"offline queue drops oldest at exactly 1000 events")
	check(JSON.stringify({"queue":telemetry.queue}).to_utf8_buffer().size() < Telemetry.MAX_QUEUE_BYTES,"bounded queue fits 2 MiB cap")
	start = Time.get_ticks_usec()
	telemetry._save_if_needed()
	evidence.full_queue_snapshot_main_usec = Time.get_ticks_usec()-start
	await wait_saved(telemetry)
	evidence.full_queue_worker_save_usec = telemetry.last_save_usec
	evidence.queue_file_bytes = FileAccess.get_file_as_bytes(path).size()
	start = Time.get_ticks_usec()
	var batch: Dictionary = telemetry.batch_payload()
	evidence.batch_main_usec = Time.get_ticks_usec()-start
	evidence.batch_50_bytes = JSON.stringify(batch).to_utf8_buffer().size()
	check(batch.events.size() == 50 and evidence.batch_50_bytes <= 65536,"network packet respects 50 events and 64 KiB bounds")
	check(batch.purpose_policy == "bmt-product-telemetry-v1" and batch.has("build_id") and batch.has("platform") and not batch.has("player_id"),"purpose build platform version context excludes client identity")
	var first_id: String = str(batch.events[0].id)
	fake.ack_schema = "unsupported-acks-v2"
	await telemetry._upload(batch,telemetry._scope)
	check(telemetry.queue.size() == 1000,"unrecognized acknowledgement schema cannot delete durable observations")
	fake.ack_schema = "bmt-product-acks-v1"
	fake.failure = true
	await telemetry._upload(batch,telemetry._scope)
	check(telemetry.queue.size() == 1000 and telemetry._retry_delay_msec == 120000,"transient failure retains durable IDs with bounded backoff")
	check(telemetry.batch_payload().events[0].id == first_id,"retry preserves event IDs")
	fake.failure = false
	await telemetry._upload(batch,telemetry._scope)
	check(telemetry.queue.size() == 950 and not telemetry._persisted_ids.has(first_id),"committed per-event acknowledgements remove only exact sent events")
	await wait_saved(telemetry)
	var prior_session: String = telemetry._session_id
	telemetry.background()
	var prior_background_count: int = telemetry.queue.size()
	var due_count: Array[int] = [0]
	telemetry.observations_due.connect(func() -> void: due_count[0] += 1)
	telemetry._heartbeat_msec = Time.get_ticks_msec()-60001
	telemetry.pump()
	check(telemetry.queue.size() == prior_background_count,"background does not generate foreground heartbeats")
	check(due_count[0] == 0 and not telemetry.observe("track_exposed",{"car_id":"compact"}),"background does not ask the app for impressions or accept foreground observations")
	telemetry._background_msec = Time.get_ticks_msec()-1800001
	telemetry.foreground()
	check(telemetry._session_id != prior_session and telemetry.queue[-1].event.name == "session_foregrounded","30-minute inactivity begins a new foreground session")
	var foreground_session: String = telemetry._session_id
	telemetry.background()
	telemetry.foreground()
	check(telemetry._session_id == foreground_session,"short app pause preserves the current activity session")
	telemetry._heartbeat_msec = Time.get_ticks_msec()-60001
	telemetry.pump()
	check(telemetry.queue[-1].event.name == "session_heartbeat" and telemetry.queue[-1].event.properties.foreground_ms >= 0,"minute heartbeat records a bounded foreground interval")
	await wait_saved(telemetry)
	var old_scope: String = telemetry._scope
	fake.player = {"id":"player-b"}
	telemetry.update_identity()
	telemetry.observe("car_selected",{"car_id":"kart"})
	await wait_saved(telemetry)
	var account_b_batch: Dictionary = telemetry.batch_payload()
	check(account_b_batch.events.size() == 3,"account B packet excludes all account A events")
	check(telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.scope == old_scope),"account A durable evidence remains in isolated local scope")
	var original_build: String = telemetry._build_id
	telemetry._build_id = "future-test-build"
	telemetry.observe("car_selected",{"car_id":"compact"})
	await wait_saved(telemetry)
	var old_build_batch: Dictionary = telemetry.batch_payload()
	check(old_build_batch.build_id == original_build and old_build_batch.events.size() == 3,"queued old-build events retain their original batch attribution after upgrade")
	fake.ack_status = "rejected"
	var rejected_before: int = telemetry.rejected_events
	await telemetry._upload(old_build_batch,telemetry._scope)
	check(telemetry.rejected_events == rejected_before+3,"permanent per-event rejection drops exact records and counts losses")
	fake.ack_status = "accepted"
	await wait_saved(telemetry)
	check(telemetry.batch_payload().build_id == "future-test-build" and telemetry.batch_payload().events.size() == 1,"new-build events use a separate homogeneous packet")
	telemetry.queue[0].event.occurred_at = int(Time.get_unix_time_from_system())-86401
	var count: int = telemetry.queue.size()
	telemetry._prune()
	check(telemetry.queue.size() == count-1,"24-hour expiry removes bounded stale offline data")
	await wait_saved(telemetry)
	var restored := Telemetry.new()
	restored.client = fake
	restored.storage_path = path
	root.add_child(restored)
	restored._timer.stop()
	restored._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(restored)
	check(restored.queue.size() >= telemetry.queue.size() and restored.queue.any(func(entry: Dictionary) -> bool: return entry.scope == old_scope),"restart restores persisted event IDs and account isolation")
	check(restored._install_id == telemetry._install_id,"pseudonymous installation reference survives a restart")
	check(restored.queue.filter(func(entry: Dictionary) -> bool: return entry.scope == restored._scope and entry.event.name == "app_first_open").size() == telemetry.queue.filter(func(entry: Dictionary) -> bool: return entry.scope == restored._scope and entry.event.name == "app_first_open").size(),"async restore discards a provisional first-open when this account was already observed")
	var actual_client := Client.new()
	root.add_child(actual_client)
	var declined: Dictionary = await actual_client.request_telemetry({"events":[]})
	check(declined.error == "TELEMETRY_DEFERRED" and actual_client._telemetry_requests.is_empty(),"absent bootstrap support causes no HTTP probe")
	actual_client._access_token = "synthetic-test-only"
	actual_client._capabilities = {"telemetry_enabled":true}
	check(not actual_client.telemetry_supported(),"legacy scalar capability does not accidentally enable uploads")
	actual_client._capabilities = {"product_telemetry":{"enabled":true,"schema_version":1}}
	check(actual_client.telemetry_supported(),"existing bootstrap nested version capability enables the collector")
	actual_client._capabilities.product_telemetry.schema_version = 2
	check(not actual_client.telemetry_supported(),"unsupported event schema suppresses network work")
	var policy := Telemetry.new()
	policy.client = fake
	root.add_child(policy)
	policy._timer.stop()
	policy.queue.clear()
	policy._pending_since_msec = 0
	policy._journey_pending_msec = -1
	policy.observe("session_heartbeat",{"foreground_ms":60000})
	policy._persisted_ids[str(policy.queue[-1].event.id)] = true
	check(not policy._flush_due(60000) and policy._flush_due(300000),"isolated idle heartbeat waits five minutes before using network")
	policy.observe("track_selected",{"track_version_id":published_version,"car_id":"compact"})
	policy._persisted_ids[str(policy.queue[-1].event.id)] = true
	policy._journey_pending_msec = 0
	check(not policy._flush_due(59000) and policy._flush_due(60000),"meaningful menu journey flushes after a minute debounce")
	for index: int in range(48):
		policy.observe("track_selected",{"track_version_id":published_version,"car_id":"compact"})
		policy._persisted_ids[str(policy.queue[-1].event.id)] = true
	check(policy._flush_due(0),"full 50-event packet qualifies immediately subject to request spacing")
	policy.dropped_events = 3
	policy._report_losses()
	check(policy.queue[-1].event.name == "collection_summary" and policy.queue[-1].event.properties.dropped_events == 3,"bounded cumulative loss counters enter the governed quality stream")
	var summary_count: int = policy.queue.size()
	policy._report_losses()
	check(policy.queue.size() == summary_count,"unchanged reported-loss counters do not add redundant traffic")
	policy.queue.clear()
	fake.server_sample = int(Time.get_unix_time_from_system())+60
	policy._anchor_clock()
	policy.observe("track_selected",{"track_version_id":published_version,"car_id":"compact","biome":"unreleased_biome"})
	policy._persisted_ids[str(policy.queue[-1].event.id)] = true
	var server_clock_batch: Dictionary = policy.batch_payload()
	check(server_clock_batch.clock_quality == "server_estimate" and int(server_clock_batch.events[0].occurred_at) >= fake.server_sample,"existing server sample anchors monotonic session UTC with declared quality")
	check(not server_clock_batch.events[0].properties.has("biome"),"unknown biome identifiers cannot grow analytic dimension cardinality")
	policy.observe("purchase_requested",{"product_id":"ad_free_month","price_eur":"99","receipt":"private","provider":"test"})
	check(policy.queue[-1].event.properties == {"product_id":"ad_free_month"},"purchase observations contain only fixed SKU without price receipt or provider")
	var before_unknown_sku: int = policy.queue.size()
	check(not policy.observe("offer_exposed",{"product_id":"unregistered_product"}) and policy.queue.size() == before_unknown_sku,"unknown or missing store SKUs cannot establish an offer or grow the analytics dimension")
	fake.server_sample = 0
	policy.queue_free()
	evidence.network_model = await model_network(fake)
	evidence.checks = checks
	evidence.failures = failures
	var output := FileAccess.open(test_directory.path_join("metrics.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t"))
	output.close()
	print("PRODUCT_TELEMETRY: ",checks," checks, ",failures," failures; ",JSON.stringify(evidence))
	actual_client.queue_free()
	telemetry.queue_free()
	restored.queue_free()
	fake.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	quit(1 if failures else 0)

func model_network(fake: FakeClient) -> Dictionary:
	# Exercises the real packet builder and flush policy using virtual minutes.
	# It is an offline payload model, not a measured device/radio/TLS capture.
	var result: Dictionary = {}
	for scenario: String in ["idle_menu","active_menu","racing_45min","lost_ack"]:
		var collector := Telemetry.new()
		collector.client = fake
		root.add_child(collector)
		collector._timer.stop()
		collector.queue.clear()
		collector._persisted_ids.clear()
		collector._pending_since_msec = -1
		collector._journey_pending_msec = -1
		var request_count: int = 0
		var payload_bytes: int = 0
		var next_request: int = 0
		for minute: int in range(60):
			var now: int = minute*60000
			var was_empty: bool = collector.queue.is_empty()
			collector.observe("session_heartbeat",{"foreground_ms":60000})
			if was_empty: collector._pending_since_msec = now
			if scenario == "active_menu" and minute%3 == 0:
				collector.observe("track_selected",{"track_version_id":published_version,"car_id":"compact","mode":"free"})
				if collector._journey_pending_msec < 0 or collector._journey_pending_msec > now: collector._journey_pending_msec = now
			for entry: Dictionary in collector.queue: collector._persisted_ids[str(entry.event.id)] = true
			var racing: bool = scenario == "racing_45min" and minute < 45
			if racing or now < next_request or not collector._flush_due(now): continue
			var packet: Dictionary = collector.batch_payload()
			request_count += 1
			payload_bytes += JSON.stringify(packet).to_utf8_buffer().size()
			fake.failure = scenario == "lost_ack" and request_count == 1
			await collector._upload(packet,collector._scope)
			next_request = now+(120000 if fake.failure else 60000)
			if not collector.queue.is_empty():
				collector._pending_since_msec = now
				collector._journey_pending_msec = -1
				if collector.queue.any(func(entry: Dictionary) -> bool: return entry.event.name != "session_heartbeat"): collector._journey_pending_msec = now
		check(request_count <= (21 if scenario == "active_menu" else 12),"hourly flush model bounds "+scenario+" traffic")
		result[scenario] = {"requests_per_hour":request_count,"json_body_bytes":payload_bytes,"remaining_events":collector.queue.size(),"assumed_http_header_bytes_at_1k_per_request":request_count*1024,"tls_bytes":"unmeasured; connection reuse/platform dependent"}
		collector.queue_free()
		await process_frame
	fake.failure = false
	return result
