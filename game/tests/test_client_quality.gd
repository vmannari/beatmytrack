extends SceneTree
const Quality = preload("res://backend/client_quality.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
const BackendClient = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}
class Client extends Node:
	var player: Dictionary = {"id":"quality-fixture"}
	var authenticated: bool = true
	var quality_enabled: bool = true
	var requests: Array[Dictionary] = []
	var failure: bool = true
	var cancelled: int = 0
	var quality_version: int = 3
	func quality_supported() -> bool: return authenticated and quality_enabled
	func quality_schema_version() -> int: return quality_version if quality_supported() else 0
	func telemetry_supported() -> bool: return authenticated
	func signed_in() -> bool: return authenticated
	func base_url() -> String: return "http://127.0.0.1:18181"
	func server_now() -> int: return 0
	func auth_busy() -> bool: return false
	func cancel_telemetry() -> void: cancelled += 1
	func request_telemetry(payload: Dictionary) -> Dictionary:
		requests.append(payload.duplicate(true))
		await get_tree().process_frame
		if failure: return {"ok":false,"status":503}
		var acknowledgements: Array = []
		for event: Dictionary in payload.events: acknowledgements.append({"id":event.id,"status":"accepted"})
		return {"ok":true,"data":{"schema":"bmt-product-acks-v1","events":acknowledgements}}
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func _initialize() -> void:
	call_deferred("run")
func clear_queue(telemetry: Node) -> void:
	telemetry.queue.clear(); telemetry._persisted_ids.clear(); telemetry._recount_budget()
func persist_test_ids(telemetry: Node) -> void:
	for entry: Dictionary in telemetry.queue: telemetry._persisted_ids[str(entry.event.id)] = true
func wait_saved(telemetry: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		telemetry.pump()
		if telemetry._loaded and telemetry._thread == null and not telemetry._dirty: return
		await process_frame
	check(false,"bounded persistence worker completes")
func run() -> void:
	var client := Client.new(); root.add_child(client)
	var telemetry := Telemetry.new(); telemetry.client = client; root.add_child(telemetry)
	telemetry.set_process(false); telemetry._timer.stop(); clear_queue(telemetry)
	var quality := Quality.new(); quality.telemetry = telemetry; root.add_child(quality); quality.set_process(false)
	check(not quality._device_model.is_empty() and not quality._os_version.is_empty(),"actual platform adapter returns model/OS context")
	check(telemetry._build_id == ProjectSettings.get_setting("application/config/version") and telemetry._build_id != "unbuilt","telemetry and exported application share the generated source build identity")
	check(Quality._bounded_context(" model\n"+"x".repeat(100)).length() == 80 and not Quality._bounded_context("\n").contains("\n"),"device context has bounded text and no control characters")
	var track := NativeTrack.new(); track.metadata = {"cloud_version":Telemetry.uuid()}
	var ticket: Dictionary = {"ticket_id":Telemetry.uuid()}
	telemetry.set_transport_allowed(false)
	check(quality.start_race(track,ticket),"negotiated signed-in timed race starts one capture")
	var race_id: String = quality._race_id
	var original_render: Dictionary = quality._render_context.duplicate(true)
	if DisplayServer.get_name() != "headless":
		check(original_render.renderer == RenderingServer.get_current_rendering_method() and original_render.viewport_width > 0 and original_render.viewport_height > 0,"graphical capture records the actual renderer and render-target pixel dimensions")
	var saved_fps: int = Engine.max_fps
	Engine.max_fps = 42 if saved_fps != 42 else 43
	quality._next_context_msec = 0
	quality._process(0.016)
	Engine.max_fps = saved_fps
	for value: float in [8.0,9.0,12.0,17.0,25.0,34.0,35.0,50.0,51.0,100.0,101.0]: quality.sample_frame("race",value)
	quality.sample_frame("race",NAN)
	for index: int in range(500): quality.sample_cell(index%32,Vector2(index*20.0,-index*20.0),index%2 == 0)
	quality.flush_frames(); telemetry.pump(); telemetry.background(true)
	check(not telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.event.name in ["race_statistics","quality_summary","segment_summary"]) and client.requests.is_empty() and telemetry._thread == null,"sampling and explicit application pause cause no diagnostic event streaming, disk worker or network during driving")
	telemetry.foreground(); clear_queue(telemetry)
	check(quality.cells.size() == 128 and quality.dropped_cell_samples > 0 and quality.segments.size() == 32,"bounded spatial sample retains coverage and counts lost cells")
	client.quality_enabled = false
	quality._process(0.016)
	check(quality._active and quality.cells.size() == 128,"temporary support loss preserves local attempt counters")
	quality._race_started_msec = Time.get_ticks_msec()-500000
	check(quality.finish_race("finished"),"short-race lifecycle enqueues summary despite temporary bootstrap loss")
	check(not quality.finish_race("finished") and telemetry.queue.size() == 1,"duplicate finish/exit callback emits exactly one statistics event")
	var event: Dictionary = telemetry.queue[0].event
	var props: Dictionary = event.properties
	check(event.name == "race_statistics" and event.id == race_id and props.race_id == race_id,"immutable event ID and race ID identify one attempt")
	check(props.schema_version == 3 and props.render_context == original_render and props.render_context_changed,"rendering settings are frozen at start and observed in-race changes remain flagged after restoration")
	check(props.render_context.has_all(["renderer","car_detail","viewport_width","viewport_height","scale_percent","frame_limit","vsync","refresh_hz"]),"one versioned record covers renderer, graphics, pixel dimensions and frame-pacing settings")
	check(props.frame_buckets == [1,2,1,1,1,2,2,1],"inclusive frame histogram boundaries and nonfinite-frame rejection")
	check(props.position_samples == 500 and props.cells.size() == 128 and props.segments.size() == 32,"one package carries all bounded spatial and segment statistics")
	check(props.track_version_id == track.metadata.cloud_version and props.ticket_id == ticket.ticket_id,"published version and race ticket remain pinned to capture start")
	check(not props.has("raw_frames") and not props.has("position") and not props.has("device_id") and not props.has("condition") and not props.has("paint"),"no raw trajectory, unique hardware identity or local cosmetic data")
	check(telemetry._thread == null,"finalization does not itself start persistence")
	persist_test_ids(telemetry)
	check(telemetry.batch_payload().events.is_empty(),"unavailable schema2 defers stored package instead of probing an old server")
	client.quality_enabled = true; telemetry.set_transport_allowed(true)
	check(telemetry._flush_due(),"durable post-race package qualifies promptly subject to existing request interval")
	var packet: Dictionary = telemetry.batch_payload()
	var sample_directory: String = ProjectSettings.globalize_path("res://../build/studio-monitor-2026-10-12/client-test")
	DirAccess.make_dir_recursive_absolute(sample_directory)
	var sample_file: FileAccess = FileAccess.open(sample_directory.path_join("statistics-sample.json"),FileAccess.WRITE)
	if sample_file != null: sample_file.store_string(JSON.stringify(packet)); sample_file.close()
	evidence.race_package_event_bytes = JSON.stringify(packet.events[0]).to_utf8_buffer().size()
	evidence.race_package_packet_bytes = JSON.stringify(packet).to_utf8_buffer().size()
	check(evidence.race_package_event_bytes < 8192 and packet.events.size() == 1,"128 cells/32 segments fit one bounded event in the existing packet")
	await telemetry._upload(packet,telemetry._scope)
	check(telemetry.queue.size() == 1 and telemetry.batch_payload().events[0].id == race_id,"network failure retains the identical durable statistics package")
	client.failure = false
	await telemetry._upload(telemetry.batch_payload(),telemetry._scope)
	check(telemetry.queue.is_empty(),"only committed acknowledgement removes the exact package")
	check(not quality.start_race(track,{},false),"untimed practice and creator test drives stay local")
	var local_track := NativeTrack.new(); local_track.metadata = {"draft_name":"private draft","theme":"private theme"}
	check(quality.start_race(local_track),"local timed race can collect generic device performance")
	quality.sample_frame("race",16.0); quality.sample_cell(0,Vector2(30,40),true)
	quality.finish_race("abandoned")
	props = telemetry.queue[-1].event.properties
	check(not props.has("track_version_id") and props.cells.is_empty() and props.segments.is_empty() and props.position_samples == 0,"local draft geometry, name, biome and spatial observations never leave the device")
	clear_queue(telemetry)
	check(quality.start_race(track),"restart begins a new independent capture")
	var first_attempt_id: String = quality._race_id
	quality.sample_frame("race",16)
	quality.start_race(track)
	check(telemetry.queue.size() == 1 and telemetry.queue[0].event.properties.outcome == "restarted" and quality._race_id != first_attempt_id,"beginning a replacement attempt finalizes previous attempt once with a fresh ID")
	quality.finish_race("abandoned")
	check(telemetry.queue.size() == 2,"abandonment finalizes its own attempt once")
	clear_queue(telemetry)
	quality.start_race(track); quality.sample_cell(0,Vector2.ZERO,false)
	client.player = {"id":"other-player"}; telemetry.update_identity()
	check(not quality.finish_race("finished"),"account switch cannot reassign collected statistics")
	check(not telemetry.queue.any(func(entry: Dictionary) -> bool: return entry.event.name == "race_statistics"),"account switch sends no old-player race package")
	clear_queue(telemetry)
	client.authenticated = false; telemetry.update_identity()
	check(not quality.start_race(track),"guest quality capture remains unavailable")
	client.authenticated = true; telemetry.update_identity(); clear_queue(telemetry)
	quality.start_race(track)
	quality._race_frame_count = Quality.MAX_FRAMES-1; quality._race_frames[0] = Quality.MAX_FRAMES-1
	quality.sample_frame("race",8); quality.sample_frame("race",8)
	check(quality._race_frame_count == Quality.MAX_FRAMES,"frame histogram count has a hard total bound")
	quality._race_frame_count = 0; quality._race_frames = PackedInt64Array([0,0,0,0,0,0,0,0])
	var start: int = Time.get_ticks_usec()
	for index: int in range(10000): quality.sample_frame("race",16.5)
	evidence.frame_mean_usec = (Time.get_ticks_usec()-start)/10000.0
	start = Time.get_ticks_usec()
	for index: int in range(3601): quality.sample_cell(index%32,Vector2(index*20.0,-index*20.0),false)
	evidence.cell_mean_usec = (Time.get_ticks_usec()-start)/3601.0
	check(quality._position_count == 3600,"at most one hour of one-Hz spatial samples is accepted")
	quality._race_started_msec = Time.get_ticks_msec()-3600001
	start = Time.get_ticks_usec(); quality.finish_race("finished")
	evidence.finalize_usec = Time.get_ticks_usec()-start
	props = telemetry.queue[-1].event.properties
	check(props.elapsed_ms == 3600000 and props.position_samples == 3600,"duration and sample bounds are applied to the finalized package")
	var invalid: Dictionary = props.duplicate(true); invalid.cells.append(invalid.cells[0])
	check(telemetry._safe_race_statistics(invalid).is_empty(),"duplicate cells cannot inflate the package")
	invalid = props.duplicate(true); invalid.frame_buckets[0] = 1000001
	check(telemetry._safe_race_statistics(invalid).is_empty(),"oversized histogram is rejected")
	invalid = props.duplicate(true); invalid.dropped_samples += 1
	check(telemetry._safe_race_statistics(invalid).is_empty(),"cell coverage and discarded-sample totals must reconcile")
	clear_queue(telemetry)
	for index: int in range(300):
		var next: Dictionary = props.duplicate(true); next.race_id = Telemetry.uuid()
		telemetry.observe_race_statistics(next,telemetry._scope)
	check(telemetry.queue.size() < 300 and telemetry._queue_budget_bytes < Telemetry.MAX_QUEUE_BYTES and telemetry.dropped_events > 0,"offline race packages obey both event-count and 2MiB queue budget")
	check(JSON.stringify({"queue":telemetry.queue}).to_utf8_buffer().size() < Telemetry.MAX_QUEUE_BYTES,"actual serialized offline package queue fits its storage cap")
	persist_test_ids(telemetry)
	packet = telemetry.batch_payload()
	check(packet.events.size() <= 50 and JSON.stringify(packet).to_utf8_buffer().size() <= 65536,"multiple race packages still obey 50-event/64KiB transport limits")
	check(not telemetry.observe("draft_saved",{"reason":"save"}) and not telemetry.observe("editor_opened",{"biome":"pine"}),"local draft/editor observations have no backend event contract")
	check(not telemetry.observe("track_selected",{"biome":"pine","car_id":"compact"}) and not telemetry.observe("track_exposed",{"track_version_id":"draft-local-file"}),"unpublished local discovery has no backend track observation")
	var actual_client := BackendClient.new(); root.add_child(actual_client); actual_client._access_token = "synthetic-test-only"
	actual_client._capabilities = {"product_telemetry":{"enabled":true,"schema_version":1,"quality_schema_version":1}}
	check(not actual_client.quality_supported(),"old periodic quality contract cannot enable the new collector")
	actual_client._capabilities.product_telemetry.quality_schema_version = 2
	check(actual_client.quality_supported(),"bootstrap explicitly negotiates lifecycle statistics schema2")
	actual_client._capabilities.product_telemetry.quality_schema_version = 3
	check(actual_client.quality_supported() and actual_client.quality_schema_version() == 3,"new bootstrap negotiates rendering-context schema3")
	actual_client._capabilities.product_telemetry.quality_schema_version = 4
	check(not actual_client.quality_supported(),"unsupported future quality schema cannot enable collection")
	actual_client._capabilities.product_telemetry = {"enabled":true,"schema_version":1,"quality_schema_version":2,"quality_schema_versions":[2,3]}
	check(actual_client.quality_schema_version() == 3,"additive capability keeps older clients on schema2 and lets current clients choose schema3")
	clear_queue(telemetry)
	client.quality_version = 2
	quality.start_race(track)
	quality.finish_race("finished")
	var legacy: Dictionary = telemetry.queue[-1].event.properties
	check(legacy.schema_version == 2 and not legacy.has("render_context"),"older backend receives the original schema2 without unsupported rendering fields")
	clear_queue(telemetry)
	client.quality_version = 3
	quality.start_race(track)
	quality.finish_race("finished")
	persist_test_ids(telemetry)
	client.quality_version = 2
	check(telemetry.batch_payload().events.is_empty() and not telemetry._flush_due(),"backend downgrade defers a queued schema3 package without trimming evidence")
	client.quality_version = 3
	check(telemetry.batch_payload().events.size() == 1,"restored schema3 capability can send the unchanged package")
	var bad_context: Dictionary = telemetry.queue[-1].event.properties.duplicate(true)
	bad_context.render_context.viewport_width = 20000
	check(telemetry._safe_race_statistics(bad_context).is_empty(),"render dimensions stay bounded")
	bad_context = telemetry.queue[-1].event.properties.duplicate(true)
	bad_context.render_context.device_serial = "forbidden"
	check(telemetry._safe_race_statistics(bad_context).is_empty(),"rendering context cannot carry arbitrary or private fields")
	var directory: String = ProjectSettings.globalize_path("res://../build/studio-monitor-2026-10-12/client-test")
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("race-"+Telemetry.uuid()+".json")
	var durable := Telemetry.new(); durable.client = client; durable.storage_path = path; root.add_child(durable); durable._timer.stop()
	durable._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(durable)
	durable.set_transport_allowed(false); quality.telemetry = durable
	quality.start_race(track,ticket); quality.sample_frame("race",16); quality.sample_cell(1,Vector2(10,10),true)
	var durable_id: String = quality._race_id
	quality.finish_race("finished"); durable.pump()
	durable.observe("process_exit",{"device_class":"android_arm64","exit_reason":6})
	check(durable._thread == null and not durable._persisted_ids.has(durable_id),"completed package remains in RAM until race transport gate opens")
	durable.set_transport_allowed(true); await wait_saved(durable)
	check(durable._persisted_ids.has(durable_id) and durable._flush_due(),"atomic post-race write makes the package immediately eligible for upload")
	var restored := Telemetry.new(); restored.client = client; restored.storage_path = path; root.add_child(restored); restored._timer.stop()
	restored._next_upload_msec = Time.get_ticks_msec()+3600000
	await wait_saved(restored)
	var restored_packages: Array = restored.queue.filter(func(entry: Dictionary) -> bool: return entry.event.name == "race_statistics")
	check(restored_packages.size() == 1 and restored_packages[0].event.id == durable_id and restored_packages[0].event.properties.cells == [[0,0,1,1]],"restart restores one identical race ID and normalized compact arrays from durable outbox")
	var restored_exits: Array = restored.queue.filter(func(entry: Dictionary) -> bool: return entry.event.name == "process_exit")
	check(restored_exits.size() == 1 and restored_exits[0].event.properties == {"device_class":"android_arm64","exit_reason":6},"JSON restart retains normalized OS-exit integer reason instead of stripping its queued diagnostic")
	var restored_packet: Dictionary = restored.batch_payload()
	client.failure = false; await restored._upload(restored_packet,restored._scope); await wait_saved(restored)
	check(not restored.queue.any(func(entry: Dictionary) -> bool: return entry.event.id == durable_id),"ACK removal survives subsequent durable save")
	durable.queue_free(); restored.queue_free()
	print("QUALITY_EVIDENCE ",JSON.stringify(evidence))
	print("Client quality: %d checks, %d failures" % [checks,failures])
	quality.queue_free(); telemetry.queue_free(); client.queue_free(); actual_client.queue_free()
	await process_frame
	quit(1 if failures else 0)
