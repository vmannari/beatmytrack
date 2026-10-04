extends SceneTree
## Real preparation/render/countdown boundaries, with isolated persistence.

const Loading = preload("res://ui/race_loading.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = "res://../docs/evidence/race-loading-2026-10-04"
var drawn_loading: int = 0
var frozen_world: int = 0
var saved_transition: bool = false
var graphical: bool = false
var countdown_at_reveal: int = -1

class FailedTicket extends Node:
	var last_error: String = "Isolated ticket failure fixture"
	var app: Node
	var saw_loading: bool = false
	func ticket(_track: NativeTrack) -> Dictionary:
		saw_loading = is_instance_valid(app.race_loading) and app.race_loading.status_label.text == "Connecting race…"
		await get_tree().process_frame
		return {}
	func flush_outbox() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	OS.set_environment("BMT_API_URL", "")
	if graphical:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
		RenderingServer.frame_post_draw.connect(_observe_draw)
	else:
		process_frame.connect(_observe_draw)
	var directory: String = "user://race_loading_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.cloud_version = "isolated-loading-fixture"
	app.selected_track = track
	app._start_race(track, false, true)
	check(app.race_loading != null and app.game == null, "loading appears before race scene construction")
	check(app.race_loading.title_label.text == app.track_title(track), "loading names the actual track")
	check(app.race_loading.activity.indeterminate and not app.race_loading.activity.show_percentage, "activity indicator does not invent percentage progress")
	var first: Node = app.race_loading
	first.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game): countdown_at_reveal = app.game.countdown_ticks)
	app._start_race(track, false, true)
	check(app.race_loading == first, "repeated start requests keep one loading operation")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	check(app.race_loading == first and app.game == null, "preparation consumes Escape without opening race or menu controls")
	await _wait_loading()
	check(app.game != null and app.race_loading == null and not app.cloud_starting, "prepared race replaces loading and clears its busy state")
	check(drawn_loading >= 2, "loading spans actual preparation frames")
	check(frozen_world > 0, "prepared world has a render frame with simulation and countdown frozen")
	if app.game != null:
		app.game.set_physics_process(false)
		check(app.game.track_session.target_laps == 5, "ordinary race keeps five laps")
		check(app.game.sim.state.tick == 0 and app.game.track_session.elapsed_ticks == 0, "loading does not add canonical time or recorded inputs")
		check(countdown_at_reveal == 360 and app.game.process_mode == Node.PROCESS_MODE_INHERIT, "all three countdown seconds remain when loading is dismissed")
		app._leave_race()
	app._start_race(track, false, true)
	app._show_screen("garage")
	await _wait_loading()
	check(app.game == null and app.race_loading == null and app.screen == "garage", "navigation cancels stale preparation without launching a hidden race")
	await app._start_race(track, true, true)
	check(app.game != null and app.game.editor_test and app.game.countdown_ticks == 0 and app.race_loading == null, "editor practice uses loading then remains untimed")
	if app.game != null: app._leave_race()
	await _check_ticket_failure(track)
	if graphical:
		await _capture_layouts(track)
		check(saved_transition, "real menu-to-race loading screenshot saved")
	app.queue_free()
	await process_frame
	print("RACE_LOADING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_ticket_failure(track: NativeTrack) -> void:
	var original_cloud: Node = app.cloud
	var fixture := FailedTicket.new()
	fixture.app = app
	app.add_child(fixture)
	app.cloud = fixture
	# Test credentials stay in this disposable app and never touch a real API.
	app.online.client._access_token = "isolated-loading-test-token"
	app.online.client.player = {"id": "isolated-loading-test-player"}
	await app._start_race(track, false)
	check(fixture.saw_loading, "online ticket preparation displays loading")
	check(app.game == null and app.race_loading == null and not app.cloud_starting and app.root_ui.visible, "failed ticket returns to the visible menu without a stuck loading overlay")
	var confirmation: ConfirmationDialog
	for child: Node in app.root_ui.get_children():
		if child is ConfirmationDialog: confirmation = child
	check(confirmation != null and confirmation.visible and confirmation.ok_button_text == "Race offline", "existing offline choice remains available after failed preparation")
	if confirmation != null:
		confirmation.hide()
		confirmation.queue_free()
	app.cloud = original_cloud
	app.online.client._access_token = ""
	app.online.client.player = {}
	fixture.queue_free()
	await process_frame

func _wait_loading() -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
	while app.cloud_starting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.cloud_starting, "race preparation completes within its deadline")

func _observe_draw() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.race_loading): return
	drawn_loading += 1
	if app.game != null:
		check(app.game.process_mode == Node.PROCESS_MODE_DISABLED and app.game.sim.state.tick == 0 and app.game.countdown_ticks in [0, 360], "loading never advances the race/countdown beneath the overlay")
		frozen_world += 1
	if graphical and not saved_transition:
		saved_transition = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(evidence.path_join("race-transition-1280x720.png"))) == OK

func _capture_layouts(track: NativeTrack) -> void:
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = viewport_size
		for biome: String in ["pine", "desert", "winter", "night_city", "storm"]:
			var loading := Loading.new()
			root.add_child(loading)
			loading.configure("Starter Circuit", biome, track.route)
			loading.stage("Loading track…")
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			check(loading.surface.get_global_rect().encloses(loading.panel.get_global_rect()), "loading panel fits %s at %s" % [biome, viewport_size])
			check(loading.panel.get_global_rect().encloses(loading.status_label.get_global_rect()), "loading status fits its panel")
			check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(evidence.path_join("loading-%s-%dx%d.png" % [biome, viewport_size.x, viewport_size.y]))) == OK, "biome loading screenshot saved")
			loading.configure("A very long community circuit title that must stay inside the loading panel", biome, track.route, true)
			await process_frame
			await RenderingServer.frame_post_draw
			check(loading.panel.get_global_rect().encloses(loading.title_label.get_global_rect()), "long title stays within loading panel")
			root.remove_child(loading)
			loading.queue_free()
			await process_frame
