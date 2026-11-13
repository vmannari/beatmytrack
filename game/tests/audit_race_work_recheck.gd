extends SceneTree
## Race-work re-audit with late-completion probes: real App/race, private records, synthetic transport.
## Forced timer probes reproduce due work; they are not traffic-rate estimates.
const STATE = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var report: Dictionary = {"schema":1,"scope":"Actual App demand-driven work regression; private records, synthetic transport, natural timer window and injected late completions","observations":{},"probes":{}}
var output: String = "res://../docs/evidence/race-background-work-audit-2026-10-27/expanded.json"
const AUDITED_SOURCES: Array[String] = ["core/app.gd","core/game.gd","backend/cloud_tracks.gd","backend/appearance_sync.gd","backend/cosmetic_economy.gd","backend/achievements_client.gd","backend/challenges_client.gd","backend/weekly_rivalry_client.gd","backend/product_telemetry.gd","backend/game_configuration.gd","backend/client_quality.gd","backend/resume_recovery.gd","backend/comparison_preloader.gd","editor/editor_memory.gd","diagnostics/race_hitch_monitor.gd","ui/track_browser.gd","persistence/condition_store.gd"]

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in AUDITED_SOURCES + ["ui/header_car_appearance_cache.gd","ui/header_car_icons.gd","ui/garage_preloader.gd","ui/garage_preloaded_studio.gd","ui/garage_page.gd","ui/car_showroom.gd","backend/menu_snapshot_writer.gd","platform/challenge_links.gd"]: result[path] = FileAccess.get_sha256("res://"+path)
	return result

class SyntheticClient extends "res://backend/backend_client.gd":
	var phase: String = "setup"
	var calls: Array[Dictionary] = []
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return await intercepted(path,method)
	func _send(path: String, method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		return await intercepted(path,method)
	func intercepted(path: String, method: HTTPClient.Method) -> Dictionary:
		calls.append({"phase":phase,"path":path,"method":method,"msec":Time.get_ticks_msec()})
		await get_tree().process_frame
		return {"ok":false,"status":503,"error":"AUDIT_SYNTHETIC_OFFLINE","data":{}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("AUDIT_FAIL: ",label)
func frames(count: int = 8) -> void:
	for _index: int in range(count): await process_frame
func paths(client: Node, phase: String) -> Array:
	return client.calls.filter(func(row: Dictionary) -> bool: return row.phase == phase).map(func(row: Dictionary) -> String: return row.path)
func inventory(node: Node, result: Dictionary, game: Node) -> void:
	if node == game: return
	var script: Script = node.get_script()
	if node.can_process() and (node.is_processing() or node.is_physics_processing()) and script != null:
		result.processing.append({"path":str(node.get_path()),"script":script.resource_path,"process":node.is_processing(),"physics":node.is_physics_processing()})
	if node is Timer and node.can_process() and not node.is_stopped():
		result.timers.append({"path":str(node.get_path()),"seconds":node.wait_time})
	if node is SubViewport:
		result.viewports.append({"path":str(node.get_path()),"update_mode":node.render_target_update_mode,"can_process":node.can_process()})
	for child: Node in node.get_children(): inventory(child,result,game)
func emit_app_timer(seconds: float) -> void:
	for child: Node in app.get_children():
		if child is Timer and is_equal_approx(child.wait_time,seconds): child.timeout.emit()
	await frames()
	while app.cloud.flushing: await process_frame

func run() -> void:
	report.sources_at_start = source_hashes()
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output = argument.trim_prefix("--report=")
	var folder: String = "user://race-work-audit-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.records.settings.optional_analytics = true
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	while is_instance_valid(app._retained_garage) and not app._retained_garage.showroom.showroom_ready: await process_frame
	await frames(30)
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/"+str(app.BUILTIN_IDS[0])+".json")
	track.metadata.cloud_version = "audit-private-fixture"
	app._show_screen("tracks"); app.selected_track = track
	await app._start_race(track,false,true)
	check(is_instance_valid(app.game) and app.game.preparation_complete,"Actual App race prepared")
	if not is_instance_valid(app.game): quit(1); return
	app.game.countdown_ticks = 0
	await frames(20)
	check(not app.game.paused and app.game.finish_sim == null,"Race actively simulates")
	check(not app.product_telemetry._allowed and not app.game_configuration._allowed,"Telemetry and configuration transport gated")
	check(is_instance_valid(app._retained_garage) and not app._retained_garage.can_process(),"Parked Garage processing disabled")
	var listing: Dictionary = {"processing":[],"timers":[],"viewports":[]}
	inventory(app,listing,app.game)
	check(listing.viewports.size() == 3 and listing.viewports.all(func(row: Dictionary) -> bool: return row.update_mode == SubViewport.UPDATE_DISABLED and not row.can_process),"All three parked Garage viewports disabled")
	report.observations.background_nodes = listing
	report.observations.menu_root = {"visible":app.root_ui.is_visible_in_tree(),"can_process":app.root_ui.can_process(),"process_mode":app.root_ui.process_mode}
	var memory_before: int = app.editor_memory.next_sample
	var tick_before: int = app.game.sim.state.tick
	var position_before: Vector2 = app.game.sim.state.position
	var driving: bool = "--drive" in OS.get_cmdline_user_args()
	if driving: Input.action_press("accelerate")
	var profile_before: int = app.game.hitch_diagnostics.observer_total_us
	var count_before: int = app.game.hitch_diagnostics.observed_frames
	await create_timer(2.5).timeout
	report.observations.guest_race = {"ticks":app.game.sim.state.tick-tick_before,"editor_memory_sampled":app.editor_memory.next_sample>memory_before,"diagnostic_frames":app.game.hitch_diagnostics.observed_frames-count_before,"diagnostic_callback_us":app.game.hitch_diagnostics.observer_total_us-profile_before,"diagnostic_detail":app.game.hitch_diagnostics.detailed}
	report.observations.guest_race.driving = driving
	report.observations.guest_race.distance_from_start_m = app.game.sim.state.position.distance_to(position_before)
	if driving: check(report.observations.guest_race.distance_from_start_m>1,"Accelerator input moves real race simulation")
	check(app.game.sim.state.tick>tick_before,"Canonical race advances during measurement")
	check(not report.observations.guest_race.editor_memory_sampled,"No routine editor/Garage memory sampling during race")
	check(not app.root_ui.can_process(),"Hidden race menu processing is suspended")
	# Attach synthetic account after race entry: no sign-in or race-ticket requests.
	# Production App callbacks and service logic remain unchanged.
	var client := SyntheticClient.new()
	client._base_url = "https://race-work-audit.invalid"
	client._access_token = "synthetic-not-a-credential"
	client.player = {"id":"audit-driver","display_name":"Audit Driver","country_code":"FI","needs_username":false}
	client.session_path = folder.path_join("synthetic-session.cfg")
	client._capabilities = {"batch_run_status":true,"resume_recovery":true}
	app.add_child(client)
	app.online.client = client
	for field: String in ["cloud","cosmetic_economy","appearance_sync","achievements","rivalry","challenges","product_telemetry","game_configuration","race_ad_breaks"]: app.get(field).client = client
	client.game_configuration = app.game_configuration
	client.resume_recovery.background_allowed = app._background_work_allowed
	app.cosmetic_economy.sync_identity()
	app.achievements.sync_identity()
	app.appearance_sync.bind_records(app.records)
	var baseline: Dictionary = {}
	for id: String in VehicleCatalog.IDS: baseline[id] = STATE.car(app.records.settings,id)
	app.records.settings[STATE.KEY] = {"version":1,"baseline":baseline,"pending":{}}
	app.appearance_sync.status = ""
	await frames()
	client.phase = "clean_due_timers"
	app.appearance_sync._poll_refresh()
	app.cosmetic_economy._timer.timeout.emit()
	app.product_telemetry.pump()
	app.game_configuration.pump()
	await emit_app_timer(1.0)
	await emit_app_timer(0.5)
	await frames()
	report.probes.clean_due_timers = paths(client,client.phase)
	check(report.probes.clean_due_timers.is_empty(),"Clean due timers make no synthetic HTTP request")
	var empty_flush_costs: Array[int] = []
	for _sample: int in range(8):
		var flush_start: int = Time.get_ticks_usec()
		await app.cloud.flush_outbox()
		empty_flush_costs.append(Time.get_ticks_usec()-flush_start)
	report.observations.empty_outbox_flush_us = empty_flush_costs
	client.phase = "pending_outbox"
	var ticket: String = "audit-previous-race"
	var job_path: String = app.cloud.outbox_path().get_base_dir().path_join("runs").path_join(ticket.sha256_text()+".job.json")
	check(app.cloud._save_pending_job(job_path,{"ticket":ticket,"key":"audit-existing-operation","run_id":"audit-existing-run"}),"Private previous-run journal saved")
	await emit_app_timer(1.0)
	report.probes.pending_outbox = paths(client,client.phase)
	check(report.probes.pending_outbox.is_empty(),"Pending old uploads do not poll during active race")
	var flush_passes: int = app.cloud.profile_flush_passes
	await app.cloud.flush_outbox()
	check(app.cloud.profile_flush_passes == flush_passes,"Completion-triggered direct flush is also gated")
	client.phase = "pending_appearance"
	app.appearance_sync.status = "Fixture: pending recovery"
	app.records.settings[STATE.KEY].pending.compact = baseline.compact.duplicate(true)
	app.appearance_sync._poll.timeout.emit()
	await frames()
	report.probes.pending_appearance = paths(client,client.phase)
	check(report.probes.pending_appearance.is_empty(),"Appearance recovery remains pending during race")
	client.phase = "pending_purchase"
	app.cosmetic_economy.pending = {"item_id":str(app.cosmetic_economy.Shop.items().keys()[0]),"key":"audit-existing-purchase","expected_price":1}
	app.cosmetic_economy._timer.timeout.emit()
	await frames()
	report.probes.pending_purchase = paths(client,client.phase)
	check(report.probes.pending_purchase.is_empty() and not app.cosmetic_economy.pending.is_empty(),"Purchase recovery preserves pending operation without race-time reads or writes")
	client.phase = "pending_result_polls"
	app.challenges.result_ticket = "audit-old-challenge"
	app.challenges.result_state = "queued"
	app.challenges._next_poll = 0
	app.rivalry.result_ticket = "audit-old-rivalry"
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app.rivalry.model.sample = false
	app.rivalry_result_pending = true
	await emit_app_timer(0.5)
	report.probes.pending_result_polls = paths(client,client.phase)
	check(report.probes.pending_result_polls.is_empty(),"Old challenge/rivalry results are not polled during race")
	app.challenges.poll_result(); app.rivalry.poll_result()
	await frames()
	check(paths(client,client.phase).is_empty(),"Direct result-completion callbacks obey demand gate")
	client.phase = "focus_return"
	app.achievements._attempt_at = -60000
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames()
	report.probes.focus_return = paths(client,client.phase)
	check(report.probes.focus_return.is_empty(),"Focus return does not refresh unused achievement data")
	client.phase = "race_achievement_event"
	app.achievements.refresh_after_activity()
	await create_timer(0.5).timeout
	check(paths(client,client.phase).is_empty() and app.achievements._activity_pending,"Real achievement invalidation is retained without race-time transport")
	await audit_extras(client,folder)
	var parked_root: Control = app.root_ui
	app._race_menu_visible(true)
	check(parked_root.can_process(),"Retained race menu restores its original process mode")
	app._race_menu_visible(false)
	check(not parked_root.can_process(),"Retry can suspend the same menu again")
	var memory_trims: int = app.editor_memory.trims
	var pressure_tick: int = app.game.sim.state.tick
	app._notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
	app._process(0.0)
	check(app.editor_memory.trims>memory_trims and app.game.sim.state.tick == pressure_tick,"Real memory pressure still trims without stepping race simulation")
	# Return to the actual menu; pending operations now have consumers and
	# their original operation identities must remain intact.
	Input.action_release("accelerate")
	client.phase = "menu_recovery"
	app._leave_race()
	await frames(12)
	check(not is_instance_valid(app.game) and app.root_ui.is_visible_in_tree() and app.root_ui.can_process(),"Race exit restores usable menu")
	app.cosmetic_economy._timer.timeout.emit()
	app.appearance_sync._poll.timeout.emit()
	await emit_app_timer(1.0)
	await create_timer(0.5).timeout
	var recovery: Array = paths(client,client.phase)
	report.probes.menu_recovery = recovery
	check(recovery.any(func(path: String) -> bool: return path.begins_with("/runs/status?")),"Durable old upload resumes after race")
	check("/me/appearances" in recovery,"Pending appearance sync resumes after race")
	check("/economy/purchases" in recovery and app.cosmetic_economy.pending.key == "audit-existing-purchase","Pending purchase retries with original identity")
	check("/achievements" in recovery,"Receipt-driven achievement invalidation resumes after race")
	client.phase = "clean_menu_appearance"
	app.appearance_sync.status = ""
	app.records.settings[STATE.KEY].pending = {}
	for _index: int in range(3): app.appearance_sync._poll.timeout.emit()
	await frames()
	check(not "/me/appearances" in paths(client,client.phase),"Clean appearance never polls merely because timer expires")
	check(app.appearance_sync._poll.is_stopped(),"Clean appearance has no running periodic timer")
	app.appearance_sync.status = "Earlier read failed"
	app.appearance_sync._poll.timeout.emit()
	await frames()
	check(not "/me/appearances" in paths(client,client.phase),"A failed clean read is not an unsatisfied operation or an automatic polling reason")
	client.phase = "hidden_results"
	app.challenges._next_poll = 0; app.rivalry._next_poll_msec = 0
	await emit_app_timer(0.5)
	check(paths(client,client.phase).is_empty(),"Hidden challenge/rivalry results have no polling consumer")
	client.phase = "visible_challenge_result"
	await app._show_screen("challenges")
	app.challenges._next_poll = 0
	app.challenges.poll_result()
	await frames()
	check(paths(client,client.phase).any(func(path: String) -> bool: return path.begins_with("/challenge-results/")),"Visible pending challenge result still polls")
	client.phase = "visible_rivalry_result"
	await app._show_screen("rivalry")
	var rivalry_probe_deadline: int = Time.get_ticks_msec()+3000
	while app.rivalry.busy and Time.get_ticks_msec()<rivalry_probe_deadline: await process_frame
	check(not app.rivalry.busy,"Rivalry entry read completes before the result polling probe")
	app.rivalry._next_poll_msec = 0
	app.rivalry.poll_result()
	await frames()
	check(paths(client,client.phase).any(func(path: String) -> bool: return path.begins_with("/rivalry/tickets/")),"Visible pending rivalry result still polls")
	client.phase = "empty_outbox"
	var empty_cloud: Node = load("res://backend/cloud_tracks.gd").new()
	empty_cloud.client = client; empty_cloud.root_override = folder.path_join("empty-cloud")
	app.add_child(empty_cloud)
	await empty_cloud.flush_outbox()
	var empty_passes: int = empty_cloud.profile_flush_passes
	for _index: int in range(8): await empty_cloud.flush_outbox()
	check(empty_cloud.profile_flush_passes == empty_passes,"Known-empty outbox performs no repeated scan")
	var next_ticket: String = "audit-new-result"
	var next_path: String = empty_cloud.outbox_path().get_base_dir().path_join("runs").path_join(next_ticket.sha256_text()+".job.json")
	empty_cloud._save_pending_job(next_path,{"ticket":next_ticket,"key":"audit-existing-operation-2","run_id":"audit-existing-run-2"})
	await empty_cloud.flush_outbox()
	check(empty_cloud.profile_flush_passes>empty_passes and paths(client,client.phase).any(func(path: String) -> bool: return path.contains("audit-existing-run-2")),"New durable result wakes an idle outbox")
	check(app.cloud.upload_job(ticket).key == "audit-existing-operation","Race deferral preserves original upload identity")
	for retry: bool in [false,true]:
		var writer: Node = load("res://backend/cloud_tracks.gd").new()
		writer.client = client; writer.root_override = folder.path_join("writer-"+str(retry))
		app.add_child(writer)
		await writer.flush_outbox()
		var before_write: int = writer.profile_flush_passes
		var ticket_data: Dictionary = {"ticket_id":"audit-writer-"+str(retry),"_submit_key":"audit-writer-original-key"}
		if retry: await writer.queue_run_async(ticket_data,[[0,255,0]])
		var saved: bool = await writer.queue_run_async(ticket_data,[[0,255,0]])
		await writer.flush_outbox()
		check(saved and writer.profile_flush_passes>before_write and writer.upload_job(ticket_data.ticket_id).key == ticket_data._submit_key,"Actual asynchronous result writer wakes idle outbox with original key")
	client.phase = "empty_resume_recovery"
	await client.resume_recovery.reconcile()
	var recovery_callbacks: int = client.resume_recovery.profile_callback_us
	client.resume_recovery._next_msec = 0
	client.resume_recovery._process(0.0)
	check(not client.resume_recovery.is_processing() and client.resume_recovery.profile_callback_us == recovery_callbacks,"Empty resume-recovery journal sleeps without rescanning")
	var journal: Dictionary = {"owner":"audit-driver","origin":client.base_url(),"begin_key":"audit-resume-begin","consume_key":"audit-resume-consume","stage":"pending","race_id":"cccccccc-cccc-cccc-cccc-cccccccccccc","ticket_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","selection":{"ordinal":1,"input_offset":100,"from_tick":100,"to_tick":50,"recovery":"v1"}}
	check(client.resume_recovery.save(journal) and client.resume_recovery.is_processing(),"Saving a real pending recovery operation wakes its worker")
	report.calls = client.calls
	report.checks = checks; report.failures = failures
	report.renderer = RenderingServer.get_current_rendering_method()
	report.display = DisplayServer.get_name()
	report.sources_at_end = source_hashes()
	var target: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file := FileAccess.open(target,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	# Do not invoke leave-race: it would deliberately start menu refresh work.
	Input.action_release("accelerate")
	app.queue_free(); await frames(8)
	print("RACE_WORK_REAUDIT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)


class CompletedIconIO extends RefCounted:
	var done: bool = true
	var result: Dictionary = {}
	func cancel() -> void: pass

func root_inventory() -> Dictionary:
	var result: Dictionary = {"processing":[],"timers":[],"viewports":[]}
	inventory(root,result,app.game)
	return result

func quiet_counters() -> Dictionary:
	var cache: Node = app.header_car_cache
	var preloader: Node = app._garage_preloader
	var writer: Node = preload("res://backend/menu_snapshot_writer.gd").instance
	return {"tick":app.game.sim.state.tick,"condition_save_attempts":app.game.condition_save_count,"cloud_flush_passes":app.cloud.profile_flush_passes,"editor_memory_sample":app.editor_memory.next_sample,"header_captures":cache.captures,"header_disk_hits":cache.disk_hits,"header_active_worlds":cache.active_worlds,"header_processing":cache.is_processing(),"preloader_processing":preloader.is_processing(),"preloader_has_work":preloader.has_work(),"snapshot_writes":writer.completed_writes if is_instance_valid(writer) else 0,"telemetry_allowed":app.product_telemetry._allowed,"configuration_allowed":app.game_configuration._allowed}

func audit_extras(client: Node, folder: String) -> void:
	client.phase = "natural_race_window"
	var before: Dictionary = quiet_counters()
	var start: int = Time.get_ticks_usec()
	await create_timer(35.0).timeout
	var after: Dictionary = quiet_counters()
	report.observations.natural_window = {"seconds":(Time.get_ticks_usec()-start)/1000000.0,"before":before,"after":after,"http":paths(client,client.phase),"nodes":root_inventory()}
	check(paths(client,client.phase).is_empty(),"Natural 35-second driving window sends no synthetic HTTP with old pending operations")
	check(after.tick>before.tick and not app.game.paused,"Longer natural window remains an active unpaused race")
	check(after.header_captures==before.header_captures and after.header_disk_hits==before.header_disk_hits and after.header_active_worlds==0,"Natural race starts no header captures or icon reads")
	check(after.snapshot_writes==before.snapshot_writes and after.cloud_flush_passes==before.cloud_flush_passes,"Natural race dispatches no menu snapshot writes or old-upload flushes")
	check(after.editor_memory_sample==before.editor_memory_sample,"Natural race performs no routine editor memory inventory")
	# Counterexample: a menu response that finishes after race entry queues its
	# optional cache snapshot. No production request, account or cache is used.
	client.phase = "injected_late_menu_snapshot"
	var writer: Node = preload("res://backend/menu_snapshot_writer.gd").shared()
	var destination: String = folder.path_join("late-menu-snapshot.json")
	var writes: int = writer.completed_writes
	var snapshot_start: int = Time.get_ticks_usec()
	preload("res://backend/menu_snapshot_writer.gd").queue(destination,{"scope":"audit-private","items":[{"value":"x".repeat(16384)}]})
	var deadline: int = Time.get_ticks_msec()+3000
	while writer.completed_writes==writes and Time.get_ticks_msec()<deadline: await process_frame
	report.observations.injected_snapshot = {"race_active":is_instance_valid(app.game) and not app.game.track_session.finished,"policy_allowed":app._background_work_allowed(),"writes":writer.completed_writes-writes,"file_exists":FileAccess.file_exists(destination),"bytes":FileAccess.get_file_as_bytes(destination).size() if FileAccess.file_exists(destination) else 0,"completion_wall_ms":(Time.get_ticks_usec()-snapshot_start)/1000.0}
	check(writer.completed_writes>writes and FileAccess.file_exists(destination),"Reproduced a late menu snapshot persisting while race work policy is closed")
	# Counterexample: completed PNG I/O is published before the header cache's
	# allowed check. Supply an in-memory ready result; do not render a car.
	client.phase = "injected_late_header_read"
	var cache: Node = app.header_car_cache
	check(cache._io==null and cache.canvas==null,"Header late-read probe begins with no live worker or viewport")
	var id: String = VehicleCatalog.selected
	var key: String = preload("res://ui/header_car_icons.gd").appearance_key(id,cache.records)
	var icon_cache: Dictionary = preload("res://ui/header_car_icons.gd").customized
	var previous: Variant = icon_cache.get(key)
	var had_previous: bool = icon_cache.has(key)
	var ready := CompletedIconIO.new()
	var pixels := Image.create(176,112,false,Image.FORMAT_RGBA8)
	pixels.fill(Color(0.1,0.2,0.3,1))
	ready.result = {"image":pixels}
	cache._io = ready
	cache._io_job = {"vehicle":id,"key":key,"epoch":cache._epoch}
	cache._io_kind = "read"
	var hits: int = cache.disk_hits
	var icon_start: int = Time.get_ticks_usec()
	cache._process(0.0)
	report.observations.injected_header = {"policy_allowed":cache.allowed.call(),"disk_hits_delta":cache.disk_hits-hits,"texture_published":icon_cache.has(key),"callback_us":Time.get_ticks_usec()-icon_start,"active_worlds":cache.active_worlds,"rgba_bytes":176*112*4}
	check(cache.disk_hits>hits and icon_cache.has(key),"Reproduced completed header PNG publication while capture policy is closed")
	if had_previous: icon_cache[key] = previous
	else: icon_cache.erase(key)
	# The new preloader does not build a studio during racing, but its empty
	# process callback continues to poll/reset. Measure only that callback.
	var preloader: Node = app._garage_preloader
	var costs: Array[int] = []
	for _sample: int in range(120):
		var callback_start: int = Time.get_ticks_usec()
		preloader._process(0.0)
		costs.append(Time.get_ticks_usec()-callback_start)
	costs.sort()
	report.observations.empty_preloader_callbacks = {"processing":preloader.is_processing(),"can_process":preloader.can_process(),"has_work":preloader.has_work(),"pending_loads":preloader._pending.size(),"studio_present":is_instance_valid(preloader.studio),"samples":costs.size(),"median_us":costs[costs.size()/2],"max_us":costs.max()}
	check(not preloader.has_work() and not is_instance_valid(preloader.studio),"Garage preloader starts no native studio during active racing")
	report.probes.injected_completion_http = paths(client,"injected_late_menu_snapshot")+paths(client,"injected_late_header_read")
	check(report.probes.injected_completion_http.is_empty(),"Late-completion probes do not make synthetic HTTP calls")
