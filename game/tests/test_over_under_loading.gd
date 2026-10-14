extends SceneTree
## Isolated actual bridge-track start and revisit, without network/player writes.
var app: Node
var failures: int = 0
var checks: int = 0

class HeldTicket extends "res://backend/cloud_tracks.gd":
	signal released
	var requested: bool = false
	func ticket(_track: NativeTrack, _creator: bool = false, _vehicle: String = "", _handling: HandlingConfig = null, _issued: Dictionary = {}) -> Dictionary:
		last_error = "Isolated held request"
		requested = true
		await released
		return {}
	func flush_outbox() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = "user://over_under_loading_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track != null, "Over and Under compiles")
	track.metadata.cloud_version = "isolated-over-under"
	app.selected_track = track
	for repeat: int in range(3):
		var began: int = Time.get_ticks_msec()
		app._start_race(track, false, true)
		var revealed: Dictionary = {}
		app.race_loading.tree_exiting.connect(func() -> void:
			if is_instance_valid(app.game):
				revealed.countdown = app.game.countdown_ticks
				revealed.tick = app.game.sim.state.tick)
		while app.cloud_starting and Time.get_ticks_msec()-began < 15000: await process_frame
		check(not app.cloud_starting and app.race_loading == null and is_instance_valid(app.game), "bridge start completes pass " + str(repeat))
		if is_instance_valid(app.game):
			app.game.set_physics_process(false)
			check(app.game.hud != null and app.game.track_session.target_laps == 5 and revealed.get("countdown", -1) == 360 and revealed.get("tick", -1) == 0, "prepared five-lap bridge race remains at full countdown")
			check(app.game.weathering_prepared == (DisplayServer.get_name() != "headless") and not app.game.car_weathering._render_warming, "preparation records an actual draw and restores clean bindings before racing")
			print("OVER_UNDER_LOAD_MS ", Time.get_ticks_msec()-began)
			app._leave_race()
		await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
		var presentation: Dictionary = {"done": false}
		_present_without_rendering(presentation)
		await create_timer(2.5).timeout
		check(presentation.done, "suspended rendering cannot strand preparation on frame_post_draw")
		RenderingServer.render_loop_enabled = true
		await process_frame
		await RenderingServer.frame_post_draw
	await _check_deadline_recovery(track)
	app.queue_free()
	await process_frame
	print("OVER_UNDER_LOADING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _present_without_rendering(result: Dictionary) -> void:
	await app._present_race_loading()
	result.done = true

func _check_deadline_recovery(track: NativeTrack) -> void:
	var original_cloud: Node = app.cloud
	var first := HeldTicket.new()
	first.client = original_cloud.client
	first.root_override = original_cloud.root_override
	app.add_child(first)
	app.cloud = first
	app.online.client._access_token = "isolated-held-ticket"
	app.online.client.player = {"id": "isolated"}
	app._start_race(track, false)
	var loading: Node = app.race_loading
	var deadline: Timer = loading.get_node("RaceLoadingDeadline")
	check(is_equal_approx(deadline.wait_time, 45.0), "production loading deadline is 45 seconds")
	while not first.requested: await process_frame
	deadline.start(0.1)
	await create_timer(0.2).timeout
	check(not app.cloud_starting and app.race_loading == null and app.game == null and app.root_ui.visible, "stalled ticket returns to an interactive menu")
	check(app.cloud_ticket.is_empty(), "timeout retains no competitive ticket")
	var dialog: AcceptDialog
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: dialog = child
	check(dialog != null and dialog.dialog_text == "Race loading timed out. Try again.", "timeout shows one actionable recovery message")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/race-loading-stuck-2026-10-10")
		DirAccess.make_dir_recursive_absolute(evidence)
		root.get_texture().get_image().save_png(evidence.path_join("timeout-recovery.png"))
	if dialog != null: dialog.queue_free()
	var second := HeldTicket.new()
	second.client = original_cloud.client
	second.root_override = original_cloud.root_override
	app.add_child(second)
	app.cloud = second
	app._start_race(track, false)
	var retry: Node = app.race_loading
	while not second.requested: await process_frame
	first.released.emit()
	await process_frame
	check(app.cloud_starting and app.race_loading == retry and app.game == null, "late timed-out reply cannot close or overwrite a retry")
	app._race_loading_timed_out(loading.get_instance_id() if is_instance_valid(loading) else 1)
	check(app.race_loading == retry and app.cloud_starting, "stale deadline cannot cancel a retry")
	app._show_screen("garage")
	second.released.emit()
	await process_frame
	check(app.screen == "garage" and not app.cloud_starting and app.race_loading == null and app.game == null, "late reply cannot launch a race after navigation")
	app.cloud = original_cloud
	app.online.client._access_token = ""
	app.online.client.player = {}
	first.queue_free()
	second.queue_free()
	await process_frame
	app._show_screen("tracks")
	await app._start_race(track, false, true)
	check(app.game != null and not app.cloud_starting and app.race_loading == null, "race can start after deadline recovery")
	if app.game != null: app._leave_race()
	var partial := Node.new()
	partial.process_mode = Node.PROCESS_MODE_DISABLED
	app.add_child(partial)
	app.game = partial
	app.root_ui.visible = false
	app.cloud_starting = true
	app.cloud_ticket = {"ticket_id": "isolated-unstarted"}
	var partial_loading: Node = app._open_race_loading(track)
	partial_loading.stage("Preparing start…")
	partial_loading.get_node("RaceLoadingDeadline").start(0.1)
	await create_timer(0.2).timeout
	check(app.game == null and not is_instance_valid(partial) and app.root_ui.visible and not app.cloud_starting, "aborted scene setup removes the frozen partial world and restores menus")
	check(app.cloud_ticket.is_empty() and app.race_loading == null, "aborted setup clears only its unstarted ticket/loading")
