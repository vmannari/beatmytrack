extends RefCounted
## Loading presentation is available before the race resource graph.
const RaceLoading = preload("res://ui/race_loading.gd")
const DailyPreparation = preload("res://race/daily_start_preparation.gd")

static func can_start(app: Node, track: NativeTrack, from_editor: bool, prepared_loading: RaceLoading) -> bool:
	if app.cloud_starting or (is_instance_valid(app.race_loading) and app.race_loading != prepared_loading): return false
	if track == null:
		app._notice("Choose a track before starting a race.")
		return false
	if app.cloud != null and is_instance_valid(app.online.client.get("safety")) and not app.online.client.safety.allows(track.metadata.get("cloud_entry",track.metadata)):
		app._notice("This player is blocked. Manage blocked players in Settings > Privacy > Community safety.")
		return false
	var tutorial_lesson: bool = app.tutorial != null and app.tutorial.authorizes(track)
	if not track.metadata.get("metadata_only",false) and not from_editor and not track.metadata.has("cloud_version") and app.cloud != null and not tutorial_lesson:
		app._notice("Choose a published backend track from Race.")
		return false
	return true

static func run_open_race_loading(app: Node, track: NativeTrack = null, practice: bool = false, elimination: bool = false) -> RaceLoading:
	if app.product_telemetry != null: app.product_telemetry.set_transport_allowed(false)
	if app.discovery_provider != null: app.discovery_provider.comparisons.cancel_speculation()
	app._stop_menu_page_motion()
	app.race_loading = RaceLoading.new()
	app.add_child(app.race_loading)
	var deadline = Timer.new()
	deadline.name = "RaceLoadingDeadline"
	deadline.process_mode = Node.PROCESS_MODE_ALWAYS
	deadline.one_shot = true
	app.race_loading.add_child(deadline)
	deadline.timeout.connect(app._race_loading_timed_out.bind(app.race_loading.get_instance_id()))
	deadline.start(app.RACE_LOAD_DEADLINE_SECONDS)
	if track != null:
		app.race_loading.configure(app.track_title(track), str(track.metadata.get("theme", "pine")), track.route, practice, elimination)
	return app.race_loading

static func run_present_race_loading(app: Node) -> bool:
	# Layout and actually draw the overlay before synchronous scene construction.
	var tree: SceneTree = app.get_tree()
	await tree.process_frame
	if not is_instance_valid(app) or not app.is_inside_tree() or app.is_queued_for_deletion(): return false
	if DisplayServer.get_name() == "headless": return false
	# Minimized/suspended windows may stop emitting frame_post_draw entirely.
	# Wait for an actual draw normally, but never make it an unbounded race gate.
	var drawn: Dictionary = {"done": false}
	var observe: Callable = func() -> void: drawn.done = true
	RenderingServer.frame_post_draw.connect(observe, CONNECT_ONE_SHOT)
	var began: int = Time.get_ticks_msec()
	var deadline: int = began+app.RACE_LOAD_DRAW_WAIT_MSEC
	while not drawn.done and Time.get_ticks_msec() < deadline and is_instance_valid(app) and app.is_inside_tree() and not app.is_queued_for_deletion():
		await tree.process_frame
	if RenderingServer.frame_post_draw.is_connected(observe):
		RenderingServer.frame_post_draw.disconnect(observe)
	return drawn.done

static func run_race_loading_matches(app: Node, expected_id: int) -> bool:
	return is_instance_valid(app.race_loading) and app.race_loading.get_instance_id() == expected_id

static func run_race_preparation_changed(app: Node, expected_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	if not app._race_loading_matches(expected_id): return true
	# Navigation cancels intentionally. Changes on the same page need feedback.
	if navigation != app._navigation_generation or starting_screen != app.screen:
		app._close_race_loading(expected_id)
		return true
	var reason: String = ""
	if scope != app.lifecycle.scope(): reason = "Account changed while preparing the race. Try again."
	elif vehicle != VehicleCatalog.selected: reason = "Car changed while preparing the race. Try again."
	elif selection != app.selected_track: reason = "Track changed while preparing the race. Try again."
	elif DailyPreparation.find(app.race_loading) != null and not DailyPreparation.find(app.race_loading).valid(): reason = "Lap limits are unavailable for this car. Try again shortly."
	if reason.is_empty(): return false
	app.cloud_ticket = {}
	app._close_race_loading(expected_id)
	app._notice(reason)
	return true

static func run_race_loading_timed_out(app: Node, expected_id: int) -> void:
	if not app._race_loading_matches(expected_id): return
	push_warning("Race preparation timed out at stage: " + app.race_loading.status_label.text)
	# A partially constructed world is still disabled and has no race result.
	if is_instance_valid(app.game) and app.game.process_mode == Node.PROCESS_MODE_DISABLED:
		app._discard_preparing_game(app.game)
	app.cloud_ticket = {}
	app.cloud_starting = false
	app._close_race_loading(expected_id)
	app._race_menu_visible(true)
	app._show_screen(app.screen)
	app._notice("Race loading timed out. Try again.")

static func run_close_race_loading(app: Node, expected_id: int = 0) -> void:
	if not is_instance_valid(app.race_loading): return
	if expected_id != 0 and app.race_loading.get_instance_id() != expected_id: return
	app.cloud_starting = false
	app.remove_child(app.race_loading)
	app.race_loading.queue_free()
	app.race_loading = null
