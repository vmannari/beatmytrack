extends SceneTree
## Read-only runtime audit: real App/race, private records, synthetic transport.
## Forced timer probes reproduce due work; they are not traffic-rate estimates.
const STATE = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var report: Dictionary = {"schema":1,"scope":"Actual App practice race; isolated user data; synthetic signed-in transport; no real HTTP","observations":{},"probes":{}}
var output: String = "res://../docs/evidence/race-background-work-audit-2026-10-26/runtime.json"
const AUDITED_SOURCES: Array[String] = ["core/app.gd","core/game.gd","backend/cloud_tracks.gd","backend/appearance_sync.gd","backend/cosmetic_economy.gd","backend/achievements_client.gd","backend/challenges_client.gd","backend/weekly_rivalry_client.gd","backend/product_telemetry.gd","backend/game_configuration.gd","backend/client_quality.gd","backend/resume_recovery.gd","backend/comparison_preloader.gd","editor/editor_memory.gd","diagnostics/race_hitch_monitor.gd","ui/track_browser.gd","persistence/condition_store.gd"]

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in AUDITED_SOURCES: result[path] = FileAccess.get_sha256("res://"+path)
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
	check(report.observations.guest_race.editor_memory_sampled,"Periodic retained-Garage memory inventory reproduced")
	var memory_costs: Array[int] = []
	for _sample: int in range(3):
		app.editor_memory.next_sample = 0
		var memory_start: int = Time.get_ticks_usec()
		app.editor_memory.tick(app)
		memory_costs.append(Time.get_ticks_usec()-memory_start)
	report.observations.forced_due_memory_samples = {"callback_us":memory_costs,"telemetry":app.editor_memory.telemetry,"trims":app.editor_memory.trims}
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
	check(not report.probes.pending_outbox.is_empty(),"App sync timer polls previous run during active race")
	client.phase = "pending_appearance"
	app.appearance_sync.status = "Fixture: pending recovery"
	app.appearance_sync._poll.timeout.emit()
	await frames()
	report.probes.pending_appearance = paths(client,client.phase)
	check("/me/appearances" in report.probes.pending_appearance,"Appearance recovery bypasses clean race gate")
	client.phase = "pending_purchase"
	app.cosmetic_economy.pending = {"item_id":str(app.cosmetic_economy.Shop.items().keys()[0]),"key":"audit-existing-purchase","expected_price":1}
	app.cosmetic_economy._timer.timeout.emit()
	await frames()
	report.probes.pending_purchase = paths(client,client.phase)
	check("/economy" in report.probes.pending_purchase and "/economy/purchases" in report.probes.pending_purchase,"Purchase recovery reads and retries during active race")
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
	check(report.probes.pending_result_polls.any(func(path: String) -> bool: return path.begins_with("/challenge-results/")),"Old challenge result polled during race")
	check(report.probes.pending_result_polls.any(func(path: String) -> bool: return path.begins_with("/rivalry/tickets/")),"Old rivalry result polled during race")
	client.phase = "focus_return"
	app.achievements._attempt_at = -60000
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames()
	report.probes.focus_return = paths(client,client.phase)
	check("/achievements" in report.probes.focus_return,"Focus return refreshes achievements during race")
	# Compare existing detailed/debug and compact/release observer callbacks on
	# the same running game. These are local callback costs, not GPU/FPS results.
	var modes: Array[Dictionary] = []
	for detail: bool in [true,false]:
		app.game.hitch_diagnostics.detailed = detail
		var start_us: int = app.game.hitch_diagnostics.observer_total_us
		var start_frames: int = app.game.hitch_diagnostics.observed_frames
		await frames(90)
		modes.append({"detailed":detail,"frames":app.game.hitch_diagnostics.observed_frames-start_frames,"callback_us":app.game.hitch_diagnostics.observer_total_us-start_us})
	report.observations.diagnostic_callbacks = modes
	report.observations.final_tick = app.game.sim.state.tick
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
	print("RACE_BACKGROUND_AUDIT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
