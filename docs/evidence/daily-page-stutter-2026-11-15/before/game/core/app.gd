extends Node
## Menu shell and navigation state. Native feature composition loads on demand.

var ObjectControls: Script:
	get: return _feature_resource("res://editor/object_properties.gd")
var GAME_SCENE: PackedScene:
	get: return _feature_resource("res://core/game.tscn")
const AccountController = preload("res://backend/account_controller.gd")
const ProductTelemetry = preload("res://backend/product_telemetry.gd")
const RaceLoading = preload("res://ui/race_loading.gd")
const RaceLoadingFlow = preload("res://core/race_loading_flow.gd")
const LoadingFacts = preload("res://ui/loading_facts.gd")
var PublicationPrompt: Script:
	get: return _feature_resource("res://ui/publication_dialog.gd")
const RACE_LOAD_DEADLINE_SECONDS: float = 45.0
const RACE_LOAD_DRAW_WAIT_MSEC: int = 2000
var race_loading: RaceLoading
var tutorial: Node
var _tutorial_existing_save: bool = false
var BUILTIN_IDS: Array[String] = BuiltinTracks.ids()
var screen: String = "tracks"
var menu_open_costs: Dictionary = {}
var root_ui: Control
var menu_body: Control
var menu_body_slot: Control
var menu_body_backgrounds: Array[Control] = []
var outgoing_menu_page: Control
var menu_neighbors: Dictionary = {}
var _garage_parking: Control
var _retained_garage: Control
var _garage_preloader: Node
var _garage_picture_navigation: int=0
var _retained_profile_car: Control
var race_profile_enabled: bool = false
var _rivalry_parking: Control
var _retained_rivalry_page: Control
var _retained_rivalry_scope: String = ""
var cosmetic_economy: Node
var appearance_sync: Node
var header_car_cache: Node
var achievements: Node
var race_ad_breaks: Node
var game_configuration: Node
var _ad_input_blocker: Control
var _ad_previous_focus: WeakRef
var achievement_notification: Control
var _achievement_finale: String = ""
var _reviewed_rivalry_summaries: Dictionary = {}
var _achievement_challenges: Dictionary = {}
var _suspended_menu: Dictionary = {}
var menu_neighbor_direction: int = 0
var returning_menu_neighbor: Dictionary = {}
const MENU_PAGE_GAP: float = 64.0
var menu_page_motion: Tween
var _preparing_rivalry_motion: Tween
var race_mode_transition_rail: RaceModeRail
const RACE_MODE_PAGES: Array[String] = ["rivalry", "daily", "tracks", "challenges"]
var _race_mode_request: int = 0
var _rivalry_entry_pending: bool = false
var _daily_track_cache: Dictionary = {}
var _daily_track_cache_scope: String = ""
var rivalry_standings_view: Dictionary = {}
var menu_edge_motion: Tween
var menu_drag_offset: float = 0.0
var content: VBoxContainer
var menu_layer: CanvasLayer
var game: Node
var selected_track: NativeTrack
var library := TrackLibrary.new()
var document: Dictionary = {}
var EDITOR_HISTORY: Script:
	get: return _feature_resource("res://editor/editor_history.gd")
var editor_session = preload("res://editor/editor_session.gd").new()
var history: Array[Dictionary]:
	get: return editor_session.undo
	set(value): editor_session.undo = value
var redo_history: Array[Dictionary]:
	get: return editor_session.redo
	set(value): editor_session.redo = value
var canvas: Control
var editor_status: Label
var editor_guidance: String = ""
var test_button: Button
var publish_button: Button
var share_button: Button
var capture_path: String = ""
var returning_to_editor: bool = false
var ui_touch_scale: float = 1.0
var ui_left_handed: bool = false
var records := LocalRecords.new()
var editor_view: Dictionary = {}
var editor_return_screen: String = "biome"
var editor_return_draft_view: Dictionary = {}
var editor_mode_buttons: Dictionary = {}
var editor_tools_open: bool = false
var editor_tools_panel: PanelContainer
var editor_map_panel: PanelContainer
var editor_undo: Button
var editor_redo: Button
var editor_world: Control
var object_browser_state: Dictionary = {}
var object_browser: Control
var object_population_panel: Control
var editor_palette: Control
var editor_context: HBoxContainer
var surface_toolbar: PanelContainer
var surface_actions: HBoxContainer
var editor_issue_button: Button
var editor_issues: Array[Dictionary] = []
var editor_geometry: String = ""
var object_controls_panel: PanelContainer
var object_controls: Control
var editor_object_property: String = ""
var _object_controls_target: String = ""
var editor_inspector: VBoxContainer
var browser_state: Dictionary = {}
var discovery_provider := TrackDiscoveryProvider.new()
var track_catalog: TrackCatalog
var pending_menu_notice: String = ""
var publication_notification: PanelContainer
var _publication_request_active: bool = false
var _publication_dialog: AcceptDialog
var _queued_track_link: String = ""
var _track_link_generation: int = 0
var editor_preview_cancel: RefCounted
var editor_preview_thread: Thread
var editor_preview_document: Dictionary = {}
var editor_raster_cache: Dictionary = {"enabled":true}
var editor_compiled_cache: Array[Dictionary] = []
const EDITOR_COMPILED_BUDGET: int = 16 * 1024 * 1024
var editor_memory = preload("res://core/app_memory.gd").new()
var _editor_exiting: bool = false
var editor_commits:
	get: return editor_session.commits
	set(value): editor_session.commits = value
var editor_validation_document: Dictionary:
	get: return editor_session.validated
	set(value): editor_session.validated = value
var editor_validation_errors: Array[String]:
	get: return editor_session.errors
	set(value): editor_session.errors = value
var editor_workflow_presentation: Dictionary:
	get: return editor_session.workflow
	set(value): editor_session.workflow = value
var editor_writes = preload("res://editor/write_queue.gd").new()
var editor_saved_snapshot: Dictionary = {}
var editor_route_pieces: Array = []
var editor_route_fields: Dictionary = {}
var editor_loading: PanelContainer
var editor_pending_road_bake: Dictionary = {}
var editor_save_button: Button
var editor_save_error: Error = OK
var editor_save_message: String = ""
var editor_pending_tools: Dictionary = {}
var editor_pending_id: String = ""
var editor_gesture_history: Array[Dictionary]:
	get: return editor_session.gesture_undo
	set(value): editor_session.gesture_undo = value
var editor_gesture_redo: Array[Dictionary]:
	get: return editor_session.gesture_redo
	set(value): editor_session.gesture_redo = value
var editor_issue_cursor: int = -1
var editor_hint_generation: int = 0
var editor_hint_active: bool = false
var editor_wip_saved: String = ""
var editor_wip_snapshot: Dictionary = {}
var editor_wip_store: TrackLibrary
var editor_saved_store: TrackLibrary
var editor_wip_disk_hash: String = ""
var editor_saved_disk_hash: String = ""
var editor_retry_original: bool = false
var online: AccountController
var account_button: Button
var _account_setup_pending: bool = false
var startup_complete: bool = false
var profile_root: String
var guest_records: LocalRecords
var guest_library: TrackLibrary
var active_profile: String = ""
var cloud: Node
var lifecycle: TrackLifecycle
var test_library_snapshot: TrackLibrary
var test_scope_snapshot: String = ""
var test_vehicle_snapshot: String = "compact"
var cloud_root_override: String = ""
var cloud_ticket: Dictionary = {}
var cloud_starting: bool = false:
	set(value):
		if cloud_starting == value: return
		cloud_starting = value
		if is_inside_tree(): _wake_optional_work.call_deferred()
var _result_game_id: int = 0
var _challenge_return_ui: Control
var _challenge_return_screen: String = ""
var _navigation_generation: int = 0
var _profile_draft_recovery: Dictionary = {}
var rivalry: Node
var race_area_mode: String = "rivalry"
var rivalry_section: String = "overview"
var rivalry_track: int = 0
var rivalry_ghost_choice: int = 0
var rivalry_racing: bool = false
var rivalry_recording: Dictionary = {}
var rivalry_result_pending: bool = false
var rivalry_race_details: Dictionary = {}
var rivalry_refresh_ticks: int = 0
var challenges: ChallengesClient
var challenge_racing: bool = false
var challenge_practice: bool = false
var challenge_recording: Dictionary = {}
var challenge_result_view: bool = false
var challenge_browsing: bool = false
var challenge_seed: Dictionary = {}
var challenge_invitation: String = ""
var challenge_queued_invitation: String = ""
var challenge_links: Node
var challenge_refresh_ticks: int = 0
var product_telemetry: Node
var client_quality: Node
var _telemetry_race_started: bool = false
var _telemetry_race_finished: bool = false
var SELECTED_PREPARATION: Script:
	get: return _feature_resource("res://race/selected_track_preparation.gd")
var _selected_preparation_job: RefCounted
var _selected_preparation_track: NativeTrack
var _selected_preparation_browser: WeakRef
var _selected_preparation_scope: String = ""
var _selected_preparation_navigation: int = 0
var _selected_preparation_vehicle: String = ""
var _selected_preparation_serial: int = 0
var _selected_preparation_generation: int = 0
var _selected_preparation_pending: bool = false
var _selected_preparation_entry: Dictionary = {}
var _selected_preparation_pin: Array = []
var _selected_preparation_source: Dictionary = {}
var _selected_preparation_queued: bool = false
var _selected_preparation_event: Dictionary = {}
var _publishing_slot_check_at: int = 0
var _publishing_slots_foreground: bool = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_OS_MEMORY_WARNING:
		if ResourceLoader.has_cached("res://vehicle/effect_render_preparation.gd"): load("res://vehicle/effect_render_preparation.gd").trim_cache(self)
		if ResourceLoader.has_cached("res://vehicle/compact_detail.gd"): load("res://vehicle/compact_detail.gd").trim_front_cache()
		if is_instance_valid(_garage_preloader): _garage_preloader.evict()
		editor_memory.pressure_requested = true
		editor_memory.next_sample = 0
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if is_instance_valid(canvas) and canvas.active_pointer != -99: canvas.cancel_gesture(false)
		_flush_editor_writes()
		_publishing_slots_foreground = false
		if race_ad_breaks != null:
			race_ad_breaks.observe_time(false)
			race_ad_breaks.flush_progress()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_publishing_slots_foreground = true
		if race_ad_breaks != null: race_ad_breaks.observe_time(false)
		_refresh_creation_slots(true)
		if appearance_sync != null and _background_work_allowed() and screen == "garage": appearance_sync.refresh_if_stale()

func _background_work_allowed() -> bool:
	if cloud_starting or is_instance_valid(race_loading) or is_instance_valid(_feature_loading): return false
	if not is_instance_valid(game): return true
	var session: TrackSession = game.get("track_session")
	return session != null and session.finished

func _wake_optional_work() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if is_instance_valid(header_car_cache): header_car_cache.resume_pending()
	preload("res://backend/menu_snapshot_writer.gd").resume()
	if is_instance_valid(_garage_preloader): _garage_preloader.invalidate()
	# Results restore the race menu without _show_screen. Wake any achievement
	# receipt deferred during driving/loading as soon as its read is allowed.
	if achievements != null and _background_work_allowed(): achievements.resume_pending()

func _result_poll_allowed(area: String) -> bool:
	if not _background_work_allowed(): return false
	return (screen == "challenges" or challenge_result_view) if area == "challenges" else (screen == "rivalry" or rivalry_racing)

func _refresh_creation_slots(force: bool = false) -> void:
	if not _publishing_slots_foreground or screen not in ["create","drafts"] or is_instance_valid(game): return
	if not is_instance_valid(lifecycle) or lifecycle.cloud == null or not lifecycle.cloud.client.signed_in(): return
	var now: int = Time.get_ticks_msec()
	if not force and (not lifecycle.no_publishing_slots() or now < _publishing_slot_check_at): return
	# Studio awards can arrive while this page is open. Recheck on return and
	# at most once a minute while blocked; only explicit Publish sends a track.
	_publishing_slot_check_at = now+60000
	lifecycle.refresh_publishing_slots(true)

func _exit_tree() -> void:
	_editor_exiting = true
	_cancel_selected_preparation()
	_flush_editor_writes()
	if is_instance_valid(_challenge_return_ui): _challenge_return_ui.queue_free()
	_finish_preview_thread()

func _finish_preview_thread() -> void:
	if editor_preview_thread != null:
		if editor_preview_cancel != null: editor_preview_cancel.cancel()
		editor_preview_thread.wait_to_finish()
		editor_preview_thread = null
	editor_preview_document = {}

func _process(_delta: float) -> void:
	if race_ad_breaks != null:
		race_ad_breaks.enabled = OS.is_debug_build() and bool(records.settings.get("development_show_ads",false))
		race_ad_breaks.observe_time(_ad_play_active())
	# Hidden editor/menu state cannot supply information the active race uses.
	# A real OS pressure signal remains actionable while driving.
	if not _background_work_allowed():
		if editor_memory.pressure_requested: editor_memory.tick(self)
		return
	_poll_selected_preparation()
	if screen == "create" or is_instance_valid(_retained_garage) or (is_instance_valid(_garage_preloader) and _garage_preloader.has_work()) or editor_memory.pressure_requested: editor_memory.tick(self)
	if _feature_resources.has("res://core/features/editor.gd"):
		_feature_resources["res://core/features/editor.gd"].run_poll_editor_frame(self)

func _queue_editor_preview() -> void:
	_feature_resource("res://core/features/editor.gd").run_queue_editor_preview(self)

func _objects_only_edit() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_objects_only_edit(self)

func _ready() -> void:
	preload("res://backend/menu_snapshot_writer.gd").shared().background_allowed = _background_work_allowed
	get_tree().node_added.connect(_popup_node_added)
	GameLanguage.instance().configure(records.path.get_base_dir().path_join("language.json"))
	var direct: bool = false
	var capture_screen: String = "tracks"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track=") or argument == "--demo": direct = true
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--screen="): capture_screen = argument.trim_prefix("--screen=")
	if direct:
		game = GAME_SCENE.instantiate()
		add_child(game)
		return
	guest_records = records
	guest_library = library
	_tutorial_existing_save = FileAccess.file_exists(records.path) or FileAccess.file_exists(records.path+".bak")
	profile_root = records.path.get_base_dir()
	records.load_records()
	GameSoundtrack.instance().bind_records(records)
	GameSoundtrack.instance().apply_settings(records.settings)
	library.owner_name = "Guest"
	online = AccountController.new()
	online.client.session_path = records.path.get_base_dir().path_join("account_session.cfg")
	if OS.is_debug_build() and OS.get_environment("BMT_PURCHASE_LAB") == "true":
		online.client.session_path = records.path.get_base_dir().path_join("purchase_lab_session.cfg")
	add_child(online)
	online.client.resume_recovery.background_allowed = _background_work_allowed
	race_ad_breaks = preload("res://platform/race_ad_breaks.gd").new()
	race_ad_breaks.client = online.client
	race_ad_breaks.storage_path = profile_root.path_join("ad_cadence.json")
	race_ad_breaks.blocking_changed.connect(_ad_blocking_changed)
	add_child(race_ad_breaks)
	cosmetic_economy = preload("res://backend/cosmetic_economy.gd").new()
	cosmetic_economy.records = records
	cosmetic_economy.client = online.client
	cosmetic_economy.background_allowed = _background_work_allowed
	add_child(cosmetic_economy)
	appearance_sync = preload("res://backend/appearance_sync.gd").new()
	appearance_sync.client = online.client
	appearance_sync.refresh_allowed = _background_work_allowed
	add_child(appearance_sync)
	appearance_sync.bind_records(records)
	appearance_sync.changed.connect(_garage_appearance_changed)
	header_car_cache = preload("res://ui/header_car_appearance_cache.gd").new()
	header_car_cache.allowed = _header_car_work_allowed
	header_car_cache.capture_allowed = _header_car_capture_allowed
	header_car_cache.capture_started.connect(_header_car_capture_started)
	header_car_cache.capture_finished.connect(_header_car_capture_finished)
	header_car_cache.changed.connect(_header_car_picture_ready)
	add_child(header_car_cache)
	header_car_cache.bind_records(records)
	achievements = preload("res://backend/achievements_client.gd").new()
	achievements.client = online.client
	achievements.refresh_allowed = _background_work_allowed
	achievements.records = records
	achievements.directory = profile_root.path_join("achievement_cache")
	add_child(achievements)
	achievements.sync_identity()
	product_telemetry = ProductTelemetry.new()
	product_telemetry.client = online.client
	product_telemetry.enabled = bool(records.settings.get("optional_analytics",false))
	online.client.analytics_opt_in = product_telemetry.enabled
	product_telemetry.storage_path = profile_root.path_join("product_telemetry.json")
	product_telemetry.observations_due.connect(_telemetry_observe_activity)
	add_child(product_telemetry)
	game_configuration = preload("res://backend/game_configuration.gd").new()
	game_configuration.client = online.client
	game_configuration.telemetry = product_telemetry
	product_telemetry.configuration = game_configuration
	game_configuration.storage_path = profile_root.path_join("game_configuration.json")
	online.client.game_configuration = game_configuration
	game_configuration.changed.connect(_remote_config_changed)
	game_configuration.rewarded_presented.connect(race_ad_breaks.rewarded_presented)
	add_child(game_configuration)
	race_ad_breaks.permission = game_configuration.permission
	online.account_removed.connect(_erase_removed_account)
	client_quality = preload("res://backend/client_quality.gd").new()
	client_quality.telemetry = product_telemetry
	client_quality.app = self
	add_child(client_quality)
	cloud = preload("res://backend/cloud_tracks.gd").new()
	cloud.changed.connect(_prime_free_race_comparisons)
	cloud.race_verified.connect(achievements.refresh_after_activity)
	cloud.client = online.client
	cloud.background_allowed = _background_work_allowed
	cloud.root_override = cloud_root_override
	add_child(cloud)
	cloud.load_cached()
	rivalry = preload("res://backend/weekly_rivalry_client.gd").new()
	rivalry.client = online.client
	rivalry.result_poll_allowed = _result_poll_allowed.bind("rivalry")
	rivalry.appearance_sync = appearance_sync.refresh
	rivalry.appearance_provider = func(id: String) -> Dictionary:
		return {"vehicle_id":id,"livery":VehicleLivery.for_car(records.settings,id),"customisation":VehicleCustomisation.for_car(records.settings,id)}
	rivalry.cache_directory = cloud.cache_root().path_join("menu/rivalry")
	add_child(rivalry)
	rivalry.changed.connect(_rivalry_changed)
	preload("res://backend/world_ranking_client.gd").for_client(online.client).circuit_requested.connect(_open_world_circuit)
	challenges = ChallengesClient.new()
	challenges.client = online.client
	challenges.result_poll_allowed = _result_poll_allowed.bind("challenges")
	challenges.cloud = cloud
	add_child(challenges)
	challenges.changed.connect(_challenges_changed)
	challenge_links = preload("res://platform/challenge_links.gd").new()
	add_child(challenge_links)
	challenge_links.invitation_received.connect(_receive_challenge)
	challenge_links.track_received.connect(_receive_track_link)
	challenge_links.results_share_failed.connect(_rivalry_share_failed)
	challenge_links.track_share_failed.connect(func(value: String) -> void: _notice("Couldn't open sharing. The track link was copied instead.\n"+value.get_slice("\n",value.get_slice_count("\n")-1)))
	var rivalry_timer := Timer.new()
	rivalry_timer.wait_time = 0.5
	rivalry_timer.autostart = true
	rivalry_timer.timeout.connect(func() -> void:
		if not _background_work_allowed(): return
		if challenges != null: challenges.poll_result()
		if screen == "challenges" and challenge_browsing and not is_instance_valid(game) and not challenges.busy:
			challenge_refresh_ticks += 1
			if challenge_refresh_ticks >= 60:
				challenge_refresh_ticks = 0
				challenges.refresh()
		if rivalry.busy or rivalry.model.sample or cloud_starting or is_instance_valid(race_loading): return
		if rivalry_result_pending: rivalry.poll_result()
		elif screen == "rivalry" and not is_instance_valid(game):
			rivalry_refresh_ticks += 1
			if rivalry_refresh_ticks >= 60:
				rivalry_refresh_ticks = 0
				rivalry.refresh())
	add_child(rivalry_timer)
	lifecycle = TrackLifecycle.new()
	lifecycle.cloud = cloud
	lifecycle.library = library
	lifecycle.records = records
	add_child(lifecycle)
	lifecycle.changed.connect(_lifecycle_changed)
	lifecycle.publication_accepted.connect(achievements.refresh_after_activity)
	var sync_timer := Timer.new()
	sync_timer.wait_time = 1.0
	sync_timer.autostart = true
	sync_timer.timeout.connect(func() -> void:
		if not online.busy and _background_work_allowed():
			_refresh_creation_slots()
			cloud.flush_outbox()
			if not is_instance_valid(game): lifecycle.process_jobs())
	add_child(sync_timer)
	online.changed.connect(_account_changed)
	VehicleCatalog.selected = VehicleCatalog.valid_id(str(records.settings.get("selected_car", "compact")))
	ui_touch_scale = float(records.settings.get("touch_scale", 1.0))
	ui_left_handed = bool(records.settings.get("left_handed", false))
	var startup_fallback: NativeTrack = NativeTrack.read("res://resources/tracks/" + BUILTIN_IDS[0] + ".json")
	selected_track = startup_fallback
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	publication_notification = preload("res://ui/publication_notification.gd").new()
	publication_notification.app = self
	publication_notification.open_requested.connect(_view_publication_notification)
	publication_notification.dismissed.connect(_dismiss_publication_notification)
	publication_notification.share_requested.connect(func(item: Dictionary) -> void: _share_track_link(item.receipt))
	menu_layer.add_child(publication_notification)
	publication_notification.set_entries(lifecycle.publication_notifications())
	var achievement_layer := CanvasLayer.new()
	achievement_layer.name = "AchievementOverlayLayer"
	achievement_layer.layer = 30
	add_child(achievement_layer)
	achievement_notification = preload("res://ui/achievement_notification.gd").new()
	achievement_notification.app = self
	achievement_notification.service = achievements
	achievement_layer.add_child(achievement_notification)
	_remember_publication_news()
	# Account/Race become usable without constructing an unrelated native Garage.
	# First Garage entry prepares one live showroom; carousel photos are cached.
	_show_screen("restoring")
	if capture_path.is_empty(): await online.start_session()
	# Account restoration selects its own track through _select_player_storage.
	# Compile Guest's remembered creation only when Guest remains the owner.
	if active_profile.is_empty(): _restore_selected_track(startup_fallback)
	# Restoring a saved account can replace Guest's music preferences. Start
	# only after the active profile is known, before the remaining picture work.
	GameSoundtrack.instance().show_menu()
	_garage_preloader=preload("res://ui/garage_preloader.gd").new()
	_garage_preloader.app=self
	add_child(_garage_preloader)
	# Missing custom pictures use a 2D silhouette. Native header preparation
	# belongs to an explicit Garage visit, never first-menu readiness.
	_show_screen(capture_screen if not capture_path.is_empty() else "rivalry" if online.profile_ready() else "account")
	startup_complete = true
	if DisplayServer.get_name() == "headless": _initial_menu_presented = true
	else: RenderingServer.frame_post_draw.connect(_initial_menu_drawn,CONNECT_ONE_SHOT)
	tutorial = preload("res://tutorial/tutorial_controller.gd").new()
	tutorial.app = self
	add_child(tutorial)
	if capture_path.is_empty() and online.profile_ready(): tutorial.offer()
	_telemetry_observe("menu_ready",{},"ready")
	_prefetch_discovery()
	_prefetch_rivalry()
	print("APP_READY")
	if OS.is_debug_build() and FileAccess.file_exists("user://mobile_probe.json"):
		var probe: Node = load("res://diagnostics/mobile_race_probe.gd").new()
		add_child(probe)
	if OS.is_debug_build() and FileAccess.file_exists("user://control_probe.json"):
		add_child(load("res://diagnostics/mobile_control_probe.gd").new())
	if OS.is_debug_build() and FileAccess.file_exists("user://menu_probe.json"):
		add_child(load("res://diagnostics/mobile_menu_probe.gd").new())
	if not capture_path.is_empty(): _capture()

func _show_screen(next: String) -> void:
	_feature_entry_generation += 1
	_close_feature_loading()
	_close_race_loading()
	var feature: String = "res://core/features/editor.gd" if next in ["create","drafts"] else ""
	if not feature.is_empty() and not _feature_resources.has(feature):
		if not await _prepare_feature_entry(feature): return
	if next == "rivalry" and rivalry_section == "overview" and not is_instance_valid(game) and _rivalry_needs_entry_data():
		_open_rivalry()
		return
	_garage_picture_navigation+=1
	_wake_optional_work.call_deferred()
	if next != "tracks" and discovery_provider != null: discovery_provider.comparisons.cancel_speculation()
	if appearance_sync != null and (next == "garage" or appearance_sync._needs_recovery()): appearance_sync.refresh_if_stale()
	if achievements != null: achievements.resume_pending()
	if game_configuration != null:
		game_configuration.set_transport_allowed(not is_instance_valid(game) or (game.get("track_session") != null and bool(game.get("track_session").finished)))
		game_configuration.enter_menu()
	# Normalize before deciding whether the retained shell can be promoted.
	if next == "play": next = "tracks"
	# Rebuilding the editor or returning from practice keeps its original parent.
	if next == "create" and screen != "create":
		editor_return_screen = "drafts" if screen == "drafts" else "biome"
		editor_return_draft_view = {}
		if screen == "drafts" and is_instance_valid(root_ui):
			var browser: Node = root_ui.find_child("DraftBrowser",true,false)
			if browser != null:
				editor_return_draft_view = {"directory":library.directory,"query":browser.query,"page":browser.page,"selected_id":str(browser.selection.get("id",""))}
				if browser.get_parent() is ScrollContainer: editor_return_draft_view.scroll = browser.get_parent().scroll_vertical
	if not _suspended_menu.is_empty() and _suspended_menu.records != records: _discard_suspended_menu()
	if next not in ["settings","profile","account","restoring","tracks","rivalry","challenges","daily","biome","garage","store"]: _discard_suspended_menu()
	if screen == "create" and next != "create": _flush_editor_writes()
	if next != "challenge_create" and is_instance_valid(_challenge_return_ui):
		_challenge_return_ui.queue_free()
		_challenge_return_ui = null
	if screen == "rivalry" and is_instance_valid(content): _remember_rivalry_standings(content)
	_close_race_loading()
	if challenge_racing and challenge_result_view and next not in ["challenges","challenge_create"] and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		challenge_racing = false
		challenge_result_view = false
	if not is_instance_valid(game) and (startup_complete or next != "restoring"): GameSoundtrack.instance().show_menu()
	if rivalry_racing and rivalry_section in ["race_results", "result"] and next not in ["rivalry","challenge_create"] and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		rivalry_racing = false
	if next in ["tracks","rivalry","challenges","daily","biome","garage","store"] and _restore_suspended_menu(next): return
	if next in ["settings","profile"] and is_instance_valid(menu_body_slot): _suspend_menu()
	_navigation_generation += 1
	_cancel_rivalry_entry()
	var drag_offset: float = menu_body.position.x if is_instance_valid(menu_body) and not is_zero_approx(menu_drag_offset) else 0.0
	_stop_menu_page_motion()
	menu_neighbors.clear()
	menu_neighbor_direction = 0
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var previous_page: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges","daily"] else screen
	var next_page: String = "biome" if next == "drafts" else "tracks" if next in ["rivalry","challenges","daily"] else next
	var vertical_slide: bool = is_instance_valid(menu_body) and screen in RACE_MODE_PAGES and next in RACE_MODE_PAGES and screen != next
	var race_slide_height: float = menu_body_slot.size.y if vertical_slide else 0.0
	var rail_rect := Rect2()
	if vertical_slide:
		var old_rail: Control = menu_body.find_child("RaceModes",true,false)
		if old_rail != null: rail_rect = Rect2(old_rail.get_global_position()-menu_body_slot.get_global_position(),old_rail.size)
	var slide: bool = is_instance_valid(root_ui) and root_ui.is_visible_in_tree() and previous_page in pages and next_page in pages and previous_page != next_page
	slide = slide or vertical_slide
	var slide_direction: int = 1 if pages.find(next_page) > pages.find(previous_page) else -1
	if vertical_slide: slide_direction = signi(RACE_MODE_PAGES.find(next)-RACE_MODE_PAGES.find(screen))
	if drag_offset * slide_direction > 0.0: drag_offset = 0.0
	# A departing page does not need its preview. The single worker retires in
	# _process; a newly opened document supersedes its output without joining.
	if is_instance_valid(object_browser):
		object_browser_state={"category":object_browser.category,"recent":object_browser.recent.duplicate(),"current":object_browser.current,"placement":object_browser.placement,"stamp_scale":object_browser.stamp_scale,"stamp_span":object_browser.stamp_span}
	if is_instance_valid(canvas):
		if canvas.document.get("id","") == document.get("id",""): _stash_pending_tool()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"stamp_span":canvas.stamp_span,"stamp_jump_profile":canvas.stamp_jump_profile,"stamp_container_color":canvas.stamp_container_color,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece,"selected_objects":canvas.object_indices(),"multi_select":canvas.multi_select,"object_snap":canvas.object_snap,"detailed_scenery":not editor_world._detail.enabled if is_instance_valid(editor_world) else false}
	screen = next
	if screen == "store": _telemetry_observe("store_opened",{},str(_navigation_generation))
	canvas = null
	editor_status = null
	test_button = null
	share_button = null
	if is_instance_valid(root_ui):
		if is_instance_valid(_retained_profile_car) and root_ui.is_ancestor_of(_retained_profile_car):
			_retained_profile_car.hide()
			_retained_profile_car.reparent(self,false)
		if slide:
			outgoing_menu_page = menu_body
			var departing_size: Vector2 = outgoing_menu_page.size
			outgoing_menu_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
			outgoing_menu_page.size = departing_size
			outgoing_menu_page.position.x = drag_offset
			outgoing_menu_page.get_parent().remove_child(outgoing_menu_page)
			outgoing_menu_page.process_mode = Node.PROCESS_MODE_DISABLED
			_disable_outgoing_menu(outgoing_menu_page)
		if is_instance_valid(_retained_garage) and root_ui.is_ancestor_of(_retained_garage): _park_garage()
		_park_rivalry_page(root_ui)
		menu_layer.remove_child(root_ui)
		root_ui.queue_free()
	menu_body = null
	menu_body_slot = null
	menu_body_backgrounds = []
	root_ui = Control.new()
	root_ui.clip_contents = true
	MenuStyle.fill(root_ui)
	root_ui.theme = MenuStyle.theme()
	menu_layer.add_child(root_ui)
	if screen in ["tracks", "rivalry", "challenges", "daily", "biome", "drafts", "garage", "store"]:
		var swipe := preload("res://ui/menu_page_swipe.gd").new()
		swipe.name = "MenuPageSwipe"
		swipe.menu = root_ui
		swipe.modal_root = self
		swipe.page_requested.connect(_swipe_menu_page)
		swipe.gesture_started.connect(_stop_menu_edge_motion)
		swipe.drag_changed.connect(_drag_menu_edge)
		swipe.drag_finished.connect(_settle_menu_edge)
		swipe.settle_requested.connect(_settle_menu_before_touch)
		root_ui.add_child(swipe)
	if screen == "restoring":
		account_button = null
		var backdrop := ColorRect.new()
		backdrop.color = Color("101a26")
		MenuStyle.fill(backdrop)
		root_ui.add_child(backdrop)
		var center := CenterContainer.new()
		MenuStyle.fill(center)
		root_ui.add_child(center)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 24)
		center.add_child(column)
		column.add_child(MenuBrand.new())
		var fact := MenuStyle.label("", 22)
		fact.name = "LoadingFact"
		fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(fact)
		GameText.bind(fact, LoadingFacts.random_fact())
		var loading_root: Control = root_ui
		var resize_fact := func() -> void:
			column.custom_minimum_size.x = minf(600.0, maxf(1.0, loading_root.size.x - 64.0))
		loading_root.resized.connect(resize_fact)
		resize_fact.call()
		return
	if screen == "account":
		account_button = null
		_account()
		return
	if screen == "create":
		_editor()
		return
	var background := MenuBackdrop.new()
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var scenery: Array[Control] = []
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		var factor: float = get_viewport().get_visible_rect().size.y / maxf(1.0, window.y)
		margin.add_theme_constant_override("margin_left", maxi(24, ceili(safe.position.x * factor)))
		margin.add_theme_constant_override("margin_right", maxi(24, ceili((window.x - safe.end.x) * factor)))
		margin.add_theme_constant_override("margin_top", maxi(20, ceili(safe.position.y * factor)))
		margin.add_theme_constant_override("margin_bottom", maxi(20, ceili((window.y - safe.end.y) * factor)))
	root_ui.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var nav := HBoxContainer.new()
	nav.name = "MenuHeader"
	layout.add_child(nav)
	var menu_brand := MenuBrand.new()
	menu_brand.logo_scale = 0.84
	nav.add_child(menu_brand)
	var tabs := HBoxContainer.new()
	tabs.name = "MenuNavigation"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 4)
	nav.add_child(tabs)
	for item: Array in [["tracks","RACE"],["create","CREATE"],["garage","GARAGE"],["store","STORE"]]:
		var id: String = item[0]
		var button: Button = MenuStyle.tab(item[1], _new_document if id == "create" else _open_race_area if id == "tracks" else _navigate_menu_page.bind(id), screen == id or (id == "tracks" and screen in ["rivalry","challenges","daily","challenge_create"]) or (id == "create" and screen in ["biome","drafts"]))
		button.name = "Tab_" + id
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	account_button = MenuStyle.button(online.player_name() if online.client.signed_in() else "Guest", _show_screen.bind("profile"))
	if online.client.signed_in(): GameText.user_text(account_button)
	account_button.name = "MenuAccount"
	account_button.tooltip_text = "Profile"
	account_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	account_button.custom_minimum_size = Vector2(240, 64)
	var profile_style: StyleBoxFlat = MenuStyle.box(MenuStyle.PANEL)
	profile_style.content_margin_left = 104
	profile_style.content_margin_right = 16
	if screen == "profile":
		profile_style.bg_color = Color(1, 1, 1, 0.07)
		account_button.add_theme_color_override("font_color", MenuStyle.ACCENT)
	account_button.add_theme_stylebox_override("normal", profile_style)
	for state: String in ["hover", "pressed", "disabled", "focus"]:
		var state_style: StyleBoxFlat = root_ui.theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		state_style.content_margin_left = 104
		state_style.content_margin_right = 16
		account_button.add_theme_stylebox_override(state, state_style)
	var car_picker := preload("res://ui/header_car_picker.gd").new()
	if header_car_cache != null:
		car_picker.request_pictures = header_car_cache.request_pictures
		header_car_cache.bind_records(records)
	car_picker.records = records
	car_picker.vehicle_selected.connect(_select_header_vehicle)
	account_button.add_child(car_picker)
	car_picker.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	car_picker.offset_right = 100
	if is_instance_valid(_retained_profile_car) and _retained_profile_car.records != records:
		_retained_profile_car.free()
	if not is_instance_valid(_retained_profile_car):
		_retained_profile_car = preload("res://ui/profile_car.gd").new()
	var profile_car: Control = _retained_profile_car
	profile_car.name = "MenuProfileCar"
	profile_car.records = records
	_attach_profile_car(account_button)
	account_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Let the name contribute to the minimum width; expanding tabs yield space.
	account_button.clip_text = false
	nav.add_child(account_button)
	var settings: Button = MenuStyle.button("",_show_screen.bind("settings"))
	settings.icon = MenuIcon.texture("gear")
	settings.tooltip_text = "Settings"
	if screen == "settings":
		var selected_style: StyleBoxFlat = MenuStyle.box(Color(1, 1, 1, 0.07))
		settings.add_theme_stylebox_override("normal", selected_style)
		settings.add_theme_color_override("icon_normal_color", MenuStyle.ACCENT)
	settings.name = "MenuSettings"
	settings.custom_minimum_size = Vector2(54,54)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(settings)
	layout.add_child(HSeparator.new())
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if screen in ["tracks", "rivalry", "challenges", "daily", "biome", "drafts", "garage", "store"]:
		menu_body_slot = Control.new()
		menu_body_slot.name = "MenuContentViewport"
		menu_body_slot.clip_contents = true
		menu_body_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_child(menu_body_slot)
		if is_instance_valid(outgoing_menu_page): menu_body_slot.add_child(outgoing_menu_page)
		menu_body = Control.new()
		menu_body.name = "MenuContentPage"
		menu_body.clip_contents = true
		MenuStyle.fill(menu_body)
		menu_body_slot.add_child(menu_body)
		var body_background := MenuBackdrop.new()
		menu_body.add_child(body_background)
		menu_body_backgrounds.append(body_background)
		for item: Control in scenery:
			item.reparent(menu_body, false)
			menu_body_backgrounds.append(item)
		MenuStyle.fill(content)
		menu_body.add_child(content)
		menu_body_slot.resized.connect(_layout_menu_body)
		_layout_menu_body()
	else: layout.add_child(content)
	match screen:
		"drafts": _drafts()
		"biome": _choose_biome()
		"tracks": _tracks()
		"daily": _track_of_day()
		"rivalry": _rivalry()
		"challenges": _challenges()
		"challenge_create": pass
		"create": _editor()
		"garage": _garage()
		"settings": _settings()
		"store":
			var store = load("res://ui/store_page.gd").new()
			store.client = online.client
			if game_configuration != null: store.offer_order = game_configuration.settings.store_order.duplicate()
			store.sign_in_requested.connect(_open_account)
			_connect_store_telemetry(store)
			content.add_child(store)
		"profile":
			var profile = load("res://ui/own_profile_page.gd").new()
			profile.app = self
			content.add_child(profile)
		"account": _account()
		_: _tracks()
	var page_swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	_remote_menu_notice()
	# _input visits children in reverse order: settle before the carousel hit-tests.
	if page_swipe != null: root_ui.move_child(page_swipe, root_ui.get_child_count() - 1)
	if vertical_slide: _slide_race_mode_page(slide_direction,rail_rect,race_slide_height)
	elif slide: _slide_menu_page(slide_direction, drag_offset)
	else: _prepare_menu_neighbors.call_deferred(_navigation_generation)

func _attach_profile_car(parent: Control) -> void:
	var view: Control = _retained_profile_car
	if view.get_parent() != null: view.reparent(parent,false)
	else: parent.add_child(view)
	# Resolve anchors against the destination button. While parked beneath App,
	# a Control resolves its anchors against the entire viewport instead.
	view.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	view.offset_left = 6
	view.offset_right = 94
	view.offset_top = -28
	view.offset_bottom = 28
	view.clip_contents = true
	view.show()
	view.refresh()
	if is_instance_valid(view.preview): MenuStyle.fill(view.preview)

func _layout_menu_body() -> void:
	if not is_instance_valid(menu_body_slot): return
	# Keep the established full-screen scenic framing, clipped below the header.
	var inset: Vector2 = menu_body_slot.get_global_position() - root_ui.get_global_position()
	var backgrounds: Array[Control] = menu_body_backgrounds.duplicate()
	for neighbor: Dictionary in menu_neighbors.values(): backgrounds.append_array(neighbor.backgrounds)
	for background: Control in backgrounds:
		background.set_anchors_preset(Control.PRESET_TOP_LEFT)
		background.position = -inset
		background.size = root_ui.size

func _suspend_menu() -> void:
	if not _suspended_menu.is_empty(): return
	_stop_menu_page_motion()
	_suspended_menu = {"root":root_ui,"body":menu_body,"slot":menu_body_slot,"backgrounds":menu_body_backgrounds,"neighbors":menu_neighbors.duplicate(),"content":content,"screen":screen,"records":records}
	root_ui.hide()
	root_ui.process_mode = Node.PROCESS_MODE_DISABLED
	_hide_outgoing_layers(root_ui)
	root_ui = null
	menu_body = null
	menu_body_slot = null
	menu_body_backgrounds = []
	menu_neighbors = {}
	content = null

func _discard_suspended_menu() -> void:
	if _suspended_menu.is_empty(): return
	var previous: Control = _suspended_menu.root
	if is_instance_valid(previous):
		if is_instance_valid(_retained_garage) and previous.is_ancestor_of(_retained_garage): _park_garage()
		_park_rivalry_page(previous)
		previous.queue_free()
	_suspended_menu = {}

func _restore_suspended_menu(destination: String) -> bool:
	if _suspended_menu.is_empty(): return false
	_navigation_generation += 1
	_cancel_rivalry_entry()
	_stop_menu_page_motion()
	if is_instance_valid(root_ui):
		if is_instance_valid(_retained_profile_car) and root_ui.is_ancestor_of(_retained_profile_car):
			_retained_profile_car.hide()
			_retained_profile_car.reparent(self,false)
		_park_rivalry_page(root_ui)
		root_ui.get_parent().remove_child(root_ui)
		root_ui.queue_free()
	root_ui = _suspended_menu.root
	menu_body = _suspended_menu.body
	menu_body_slot = _suspended_menu.slot
	menu_body_backgrounds = _suspended_menu.backgrounds
	menu_neighbors = _suspended_menu.neighbors
	content = _suspended_menu.content
	screen = _suspended_menu.screen
	_suspended_menu = {}
	root_ui.process_mode = Node.PROCESS_MODE_INHERIT
	root_ui.show()
	content.queue_sort()
	account_button = root_ui.find_child("MenuAccount",true,false)
	if is_instance_valid(account_button):
		account_button.text = online.player_name() if online.client.signed_in() else "Guest"
		if is_instance_valid(_retained_profile_car):
			_attach_profile_car(account_button)
	_layout_menu_body()
	_navigate_menu_page(destination)
	_activate_menu_page.call_deferred(_navigation_generation)
	_prepare_menu_neighbors.call_deferred(_navigation_generation)
	return true

func _disable_outgoing_menu(node: Node) -> void:
	_set_menu_preview_input(node,true)
	_hide_outgoing_layers(node)

func _hide_outgoing_layers(node: Node) -> void:
	if node is CanvasLayer: node.hide()
	for child: Node in node.get_children(): _hide_outgoing_layers(child)

func _stop_menu_page_motion() -> void:
	_preparing_rivalry_motion = null
	_stop_menu_edge_motion()
	if menu_page_motion != null:
		menu_page_motion.kill()
		menu_page_motion = null
	if is_instance_valid(race_mode_transition_rail):
		race_mode_transition_rail.get_parent().remove_child(race_mode_transition_rail)
		race_mode_transition_rail.queue_free()
		race_mode_transition_rail = null
	if is_instance_valid(menu_body):
		var rail: Control = menu_body.find_child("RaceModes",true,false)
		if rail != null: rail.modulate.a = 1.0
	if is_instance_valid(outgoing_menu_page):
		if not returning_menu_neighbor.is_empty():
			outgoing_menu_page.hide()
			menu_neighbors[int(returning_menu_neighbor.direction)] = returning_menu_neighbor
		else:
			if is_instance_valid(_retained_garage) and outgoing_menu_page.is_ancestor_of(_retained_garage): _park_garage()
			_park_rivalry_page(outgoing_menu_page)
			if outgoing_menu_page.get_parent() != null:
				outgoing_menu_page.get_parent().remove_child(outgoing_menu_page)
			outgoing_menu_page.queue_free()
		outgoing_menu_page = null
	returning_menu_neighbor = {}
	if is_instance_valid(root_ui):
		if is_instance_valid(menu_body): menu_body.position = Vector2.ZERO
		var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
		if swipe != null: swipe.set_process_input(true)

func _slide_menu_page(direction: int, drag_offset: float = 0.0) -> void:
	# A freshly built shell has not had its first container layout yet.
	var width: float = menu_body_slot.size.x
	if width <= 0.0:
		var margin: MarginContainer = menu_body_slot.get_parent().get_parent()
		width = get_viewport().get_visible_rect().size.x - margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right")
	var gap: float = _menu_page_gap(drag_offset) if not is_zero_approx(drag_offset) else MENU_PAGE_GAP
	var distance: float = (width + gap) * direction
	menu_body.position.x = distance + drag_offset
	# A new press settles this tween before any content hit-test, so rapid swipes
	# remain responsive and the track carousel still owns its final rectangle.
	menu_page_motion = create_tween().set_parallel(true)
	menu_page_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var duration: float = clampf(0.32 * (1.0 - absf(drag_offset) / absf(distance)), 0.18, 0.32)
	menu_page_motion.tween_property(menu_body, "position:x", 0.0, duration)
	menu_page_motion.tween_property(outgoing_menu_page, "position:x", -distance, duration)
	menu_page_motion.chain().tween_callback(_finish_menu_page_slide)
	_prepare_rivalry_page_motion()

func _slide_race_mode_page(direction: int, rail_rect: Rect2, height: float) -> void:
	# The rail stays anchored while the two real page bodies roll vertically.
	for body: Control in [menu_body,outgoing_menu_page]:
		var rail: Control = body.find_child("RaceModes",true,false)
		if rail != null: rail.modulate.a = 0.0
	if rail_rect.has_area():
		race_mode_transition_rail = RaceModeRail.new()
		race_mode_transition_rail.selected = "free" if screen == "tracks" else screen
		race_mode_transition_rail.mode_requested.connect(_request_race_mode)
		menu_body_slot.add_child(race_mode_transition_rail)
		race_mode_transition_rail.name = "RaceModeTransitionRail"
		race_mode_transition_rail.position = rail_rect.position
		race_mode_transition_rail.size = rail_rect.size
	# Capture the departing viewport before reparenting clears anchored sizes.
	var distance: float = (height+MENU_PAGE_GAP)*direction
	menu_body.position.y = distance
	menu_page_motion = create_tween().set_parallel(true)
	menu_page_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	menu_page_motion.tween_property(menu_body,"position:y",0.0,0.32)
	menu_page_motion.tween_property(outgoing_menu_page,"position:y",-distance,0.32)
	menu_page_motion.chain().tween_callback(_finish_menu_page_slide)
	if screen == "rivalry":
		_prepare_rivalry_page_motion()
	else:
		# The new swipe handler can see the same press that created this page.
		# Keep that press from settling the slide before its first visible frame.
		menu_page_motion.pause()
		_preparing_rivalry_motion = menu_page_motion
		_start_race_mode_motion.call_deferred(_navigation_generation,menu_page_motion)

func _start_race_mode_motion(generation: int, motion: Tween) -> void:
	# Let containers and deferred layout settle while the incoming body is still
	# clipped offscreen, as for the Rivalry page.
	var draws: int = 1 if DisplayServer.get_name() == "headless" else 4
	for index: int in range(draws):
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		if generation != _navigation_generation or motion != menu_page_motion: return
	_preparing_rivalry_motion = null
	motion.play()

func _prepare_rivalry_page_motion() -> void:
	if screen != "rivalry": return
	menu_page_motion.pause()
	_preparing_rivalry_motion = menu_page_motion
	_start_prepared_race_mode.call_deferred(_navigation_generation,menu_page_motion)

func _start_prepared_race_mode(generation: int, motion: Tween) -> void:
	# Layout, car viewports and Garage radiance settle offscreen before arrival.
	var prepared_draws: int = 0
	while generation == _navigation_generation and motion == menu_page_motion:
		var page: Control = content.find_child("WeeklyRivalryPage",true,false)
		if page == null: return
		if page.ready_for_display():
			prepared_draws += 1
		else: prepared_draws = 0
		# Canvas photographs draw with the incoming menu. A static error page
		# may stop requesting draws, so only actual 3D views need radiance warmup.
		var required_draws: int = 1 if DisplayServer.get_name() == "headless" or page.find_children("*","SubViewport",true,false).is_empty() else 4
		if prepared_draws >= required_draws:
			_preparing_rivalry_motion = null
			motion.play()
			return
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw

func _request_race_mode(mode: String) -> void:
	if mode == "rivalry": _open_rivalry()
	elif mode == "challenges": _open_challenges()
	elif mode == "free": _open_free_race()
	elif mode == "daily": _open_track_of_day()

func _open_track_of_day() -> void:
	_cancel_rivalry_entry()
	race_area_mode = "daily"
	_navigate_menu_page("daily")

func _track_of_day(parent: Control = null, preview: bool = false) -> void:
	_feature_resource("res://core/features/daily.gd").run_track_of_day(self ,parent, preview)

func _daily_cache_scope() -> String:
	return online.client.base_url()+"/"+(str(online.client.player.get("id","")) if online.client.signed_in() else "guest")

func _load_daily_limits(track: NativeTrack, vehicle: String, request: Dictionary) -> RefCounted:
	return await _feature_resource("res://core/features/race.gd").run_load_daily_limits(self ,track, vehicle, request)

func _daily_results() -> void:
	_feature_resource("res://core/features/race.gd").run_daily_results(self)

func _retry_daily_race() -> void:
	await _feature_resource("res://core/features/race.gd").run_retry_daily_race(self)

func _keep_race_mode_rail_fixed(page: Control) -> void:
	if not is_instance_valid(race_mode_transition_rail) or not menu_body.is_ancestor_of(page): return
	var rail: Control = page.find_child("RaceModes",true,false)
	if rail != null: rail.modulate.a = 0.0

func _open_free_race() -> void:
	_cancel_rivalry_entry()
	race_area_mode = "free"
	_navigate_menu_page("tracks")

func _stop_menu_edge_motion() -> void:
	if menu_edge_motion != null:
		menu_edge_motion.kill()
		menu_edge_motion = null
	if is_instance_valid(menu_body):
		menu_body.position.x = 0.0
		_set_menu_preview_input(menu_body, false)
	menu_drag_offset = 0.0
	menu_neighbor_direction = 0
	for neighbor: Dictionary in menu_neighbors.values():
		if is_instance_valid(neighbor.body): neighbor.body.hide()

func _drag_menu_edge(distance: float) -> void:
	if not is_instance_valid(menu_body): return
	# The page owns this horizontal gesture until it settles. No button on its
	# moving content may accept a parallel platform input and rebuild the page.
	_set_menu_preview_input(menu_body, true)
	var direction: int = 1 if distance < 0.0 else -1
	menu_neighbor_direction = direction
	# A neighbor is also an entry route. Do not expose its unresolved cards under
	# the finger while the initial membership request is still in flight.
	if menu_neighbors.has(direction) and menu_neighbors[direction].screen == "rivalry" and _rivalry_needs_entry_data():
		_prefetch_rivalry()
		for neighbor: Dictionary in menu_neighbors.values(): neighbor.body.hide()
		menu_body.position.x = signf(distance)*64.0*(1.0-exp(-absf(distance)/160.0))
		menu_drag_offset = 0.0
		return
	for neighbor_direction: int in menu_neighbors:
		menu_neighbors[neighbor_direction].body.visible = neighbor_direction == direction
	if (screen in ["tracks", "rivalry", "challenges", "daily"] and distance > 0.0) or (screen == "store" and distance < 0.0):
		# Match the track carousel's bounded resistance, followed by its spring return.
		menu_body.position.x = signf(distance) * 64.0 * (1.0 - exp(-absf(distance) / 160.0))
		menu_drag_offset = 0.0
	else:
		var width: float = menu_body_slot.size.x
		menu_drag_offset = clampf(distance, -width, width)
		menu_body.position.x = menu_drag_offset
		if menu_neighbors.has(direction):
			menu_neighbors[direction].body.position.x = (width + _menu_page_gap(menu_drag_offset)) * direction + menu_drag_offset

func _menu_page_gap(distance: float) -> float:
	# A growing gutter leaves the next page visible even on the first small pull.
	return minf(MENU_PAGE_GAP, absf(distance) * 0.5)

func _settle_menu_edge() -> void:
	if not is_instance_valid(menu_body): return
	if is_zero_approx(menu_body.position.x):
		_set_menu_preview_input(menu_body, false)
		return
	if menu_edge_motion != null: menu_edge_motion.kill()
	menu_edge_motion = create_tween().set_parallel(true)
	var edge: bool = is_zero_approx(menu_drag_offset)
	if edge:
		menu_edge_motion.tween_property(menu_body, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# One progress value keeps both pages and their gutter together. Smootherstep
		# has zero velocity and acceleration at each end, avoiding a release kick.
		var duration: float = 0.42 + 0.10 * minf(1.0, absf(menu_drag_offset) / menu_body_slot.size.x)
		var neighbor: Control = menu_neighbors[menu_neighbor_direction].body if menu_neighbors.has(menu_neighbor_direction) else null
		var neighbor_start: float = neighbor.position.x if is_instance_valid(neighbor) else 0.0
		menu_edge_motion.tween_method(_return_menu_drag.bind(menu_body.position.x, neighbor, neighbor_start, menu_body_slot.size.x * menu_neighbor_direction), 0.0, 1.0, duration)
	menu_edge_motion.chain().tween_callback(func() -> void:
		menu_edge_motion = null
		_set_menu_preview_input(menu_body, false)
		menu_drag_offset = 0.0
		menu_neighbor_direction = 0
		for neighbor: Dictionary in menu_neighbors.values(): neighbor.body.hide())

func _return_menu_drag(progress: float, start: float, neighbor: Control, neighbor_start: float, neighbor_end: float) -> void:
	var blend: float = progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
	if is_instance_valid(menu_body): menu_body.position.x = lerpf(start, 0.0, blend)
	if is_instance_valid(neighbor): neighbor.position.x = lerpf(neighbor_start, neighbor_end, blend)

func _prepare_menu_neighbors(generation: int) -> void:
	# A signal callback drops safely with its owner; a suspended method cannot
	# resume after app teardown. Race loading also cancels unnecessary page work.
	if generation != _navigation_generation or not is_inside_tree(): return
	var callback: Callable = _prepare_menu_neighbors_frame.bind(generation)
	if not get_tree().process_frame.is_connected(callback):
		get_tree().process_frame.connect(callback,CONNECT_ONE_SHOT)

func _prepare_menu_neighbors_frame(generation: int) -> void:
	if cloud_starting or is_instance_valid(game) or not root_ui.visible: return
	if generation != _navigation_generation or not is_instance_valid(menu_body_slot): return
	if menu_page_motion != null: return
	var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	if swipe == null: return
	if swipe.pointer != -1:
		_prepare_menu_neighbors.call_deferred(generation)
		return
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var current: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges","daily"] else screen
	var index: int = pages.find(current)
	if index < 0: return
	# Publish at most one real swipe neighbor per frame. Only retained Garage
	# pages participate; entering a cold Garage uses the
	# normal menu transition, without a separate restoring/loading screen.
	for destination: int in range(pages.size()):
		var direction: int = destination - index
		if direction == 0: continue
		if menu_neighbors.has(direction): continue
		var next: String = pages[destination]
		# Preparing an offscreen neighbor must not construct the native Garage.
		# Its first visible entry uses the ordinary cover; subsequent visits reuse it.
		if next == "garage" and (not is_instance_valid(_retained_garage) or _retained_garage.records != records): continue
		if next == "tracks" and race_area_mode == "rivalry": next = "rivalry"
		elif next == "tracks" and race_area_mode == "challenges": next = "challenges"
		elif next == "tracks" and race_area_mode == "daily": next = "daily"
		var body := Control.new()
		body.name = "AdjacentMenuPage"
		MenuStyle.fill(body)
		body.clip_contents = true
		body.process_mode = Node.PROCESS_MODE_DISABLED
		menu_body_slot.add_child(body)
		body.position.x = menu_body_slot.size.x * direction
		var backgrounds: Array[Control] = []
		var background := MenuBackdrop.new()
		body.add_child(background)
		backgrounds.append(background)
		var column := VBoxContainer.new()
		MenuStyle.fill(column)
		body.add_child(column)
		match next:
			"tracks": _tracks(column, true)
			"daily": _track_of_day(column, true)
			"rivalry": _rivalry(column)
			"challenges": _challenges(column)
			"biome": _choose_biome(column, true)
			"garage": _garage(column)
			"store":
				var store = load("res://ui/store_page.gd").new()
				store.page_preview = true
				store.client = online.client
				store.sign_in_requested.connect(_open_account)
				_connect_store_telemetry(store)
				column.add_child(store)
		_set_menu_preview_input(body, true)
		menu_neighbors[direction] = {"body":body,"content":column,"backgrounds":backgrounds,"screen":next}
		body.position.x = menu_body_slot.size.x * direction
		_layout_menu_body()
		_prepare_menu_neighbors.call_deferred(generation)
		break
	_hide_warmed_menu_neighbors.call_deferred(generation)

func _hide_warmed_menu_neighbors(generation: int) -> void:
	if generation != _navigation_generation or not is_inside_tree(): return
	var callback: Callable = _hide_warmed_menu_neighbors_frame.bind(generation)
	if not get_tree().process_frame.is_connected(callback):
		get_tree().process_frame.connect(callback,CONNECT_ONE_SHOT)

func _hide_warmed_menu_neighbors_frame(generation: int) -> void:
	if generation != _navigation_generation: return
	var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	if swipe != null and swipe.pointer != -1: return
	for neighbor: Dictionary in menu_neighbors.values(): neighbor.body.hide()

func _set_menu_preview_input(node: Node, disabled: bool) -> void:
	var control := node as Control
	if control == null: return
	# The pinned engine propagates these overrides natively. Keep descendant
	# mouse/focus preferences intact instead of rewriting hundreds of controls.
	control.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED if disabled else Control.MOUSE_BEHAVIOR_INHERITED
	control.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED if disabled else Control.FOCUS_BEHAVIOR_INHERITED
	if disabled and not control.has_meta("page_mouse_filter"):
		var garage: Control = control.find_child("GaragePage",true,false) as Control
		if garage != null and is_instance_valid(garage._preview_service): garage._preview_service.suspend_previews()
		control.set_meta("page_mouse_filter",control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif not disabled and control.has_meta("page_mouse_filter"):
		control.mouse_filter = control.get_meta("page_mouse_filter")
		control.remove_meta("page_mouse_filter")

func _commit_menu_neighbor(direction: int) -> void:
	if menu_neighbors[direction].screen == "rivalry" and _rivalry_needs_entry_data():
		_stop_menu_edge_motion()
		_open_rivalry()
		return
	if screen == "rivalry": _remember_rivalry_standings(content)
	var neighbor: Dictionary = menu_neighbors[direction]
	if neighbor.screen == "rivalry": _reset_rivalry_entry_view()
	_refresh_cached_menu_page(neighbor.screen, neighbor.content)
	var offset: float = menu_body.position.x
	_stop_menu_page_motion()
	menu_neighbors.erase(direction)
	# Keep the prepared page and the header alive. Commitment only changes ownership
	# and animates the remaining distance; no page construction runs under the finger.
	outgoing_menu_page = menu_body
	outgoing_menu_page.position.x = offset
	outgoing_menu_page.process_mode = Node.PROCESS_MODE_DISABLED
	_set_menu_preview_input(outgoing_menu_page, true)
	returning_menu_neighbor = {"body":menu_body,"content":content,"backgrounds":menu_body_backgrounds,"screen":screen,"direction":-direction}
	var outgoing_browser: Control = outgoing_menu_page.find_child("TrackBrowser", true, false)
	if outgoing_browser != null: outgoing_browser.page_preview = true
	menu_body = neighbor.body
	menu_body.show()
	menu_body.process_mode = Node.PROCESS_MODE_INHERIT
	_set_menu_preview_input(menu_body, false)
	content = neighbor.content
	menu_body_backgrounds = neighbor.backgrounds
	var remaining: Dictionary = {}
	for old_direction: int in menu_neighbors:
		remaining[old_direction - direction] = menu_neighbors[old_direction]
	menu_neighbors = remaining
	_navigation_generation += 1
	_cancel_rivalry_entry()
	if rivalry_racing and rivalry_section in ["race_results", "result"] and neighbor.screen != "rivalry" and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		rivalry_racing = false
	if challenge_racing and challenge_result_view and neighbor.screen != "challenges" and is_instance_valid(game):
		_clear_challenge_game()
		challenge_result_view = false
	screen = neighbor.screen
	if screen == "store": _telemetry_observe("store_opened",{},str(_navigation_generation))
	if screen == "biome" and document.is_empty():
		document = TrackDocument.create_blank()
		document.id = TrackLibrary.unique_id()
		_stamp_creator()
		history.clear()
		redo_history.clear()
	for id: String in ["tracks", "create", "garage", "store"]:
		var tab: Button = root_ui.find_child("Tab_" + id, true, false)
		var selected: bool = (id == "tracks" and screen in ["tracks", "rivalry"]) or (id == "create" and screen == "biome") or id == screen
		tab.add_theme_stylebox_override("normal", MenuStyle.box(Color(1,1,1,0.07) if selected else Color.TRANSPARENT,16))
		tab.add_theme_color_override("font_color", MenuStyle.ACCENT if selected else MenuStyle.MUTED)
	var browser: Control = menu_body.find_child("TrackBrowser", true, false)
	if browser != null:
		browser_state = browser.state
	_slide_menu_page(signi(direction), offset)

func _refresh_cached_menu_page(destination: String, column: VBoxContainer) -> void:
	if game_configuration != null and column == content and destination == screen:
		game_configuration.enter_menu()
		_remote_menu_notice()
	if destination == "store":
		var store: Node = column.find_child("StorePage",true,false)
		if store != null: store.activate()
	elif destination == "rivalry":
		_rivalry(column)
	elif destination == "challenges":
		_challenges(column)
	elif destination == "daily":
		var daily: Node = column.find_child("TrackOfDayPage",true,false)
		if daily != null: daily.activate()
	elif destination == "garage":
		var garage: Control = column.find_child("GaragePage",true,false) as Control
		if garage != null:
			garage.refresh_selection()
			garage.circuit_title = track_title(selected_track).to_upper()
		var circuit: MenuFeature = column.find_child("GarageCircuit",true,false)
		if circuit != null:
			var title: String = track_title(selected_track).to_upper()
			if circuit.heading != title:
				circuit.heading = title
				circuit.tooltip_text = title+". "+circuit.description
				circuit.queue_redraw()
	elif destination == "biome" and str(column.get_meta("biome_theme","")) != str(document.get("theme",TrackDocument.THEMES[0])):
		_update_creation_biome(column,str(document.get("theme",TrackDocument.THEMES[0])))

func _navigate_menu_page(next: String) -> void:
	_garage_picture_navigation+=1
	# Explicit refreshes still use _show_screen. User navigation promotes the same
	# already warmed controls as swipes, avoiding shell/layout rebuilding on taps.
	if next == "rivalry":
		if _rivalry_needs_entry_data():
			_open_rivalry()
			return
		_reset_rivalry_entry_view()
	if menu_page_motion != null: _finish_menu_page_slide()
	if not is_instance_valid(menu_body) or not menu_body.is_inside_tree() or not root_ui.is_ancestor_of(menu_body):
		_show_screen(next)
		return
	if next == screen and is_instance_valid(menu_body):
		_refresh_cached_menu_page(next,content)
		_set_menu_preview_input(menu_body,false)
		return
	for direction: int in menu_neighbors:
		if menu_neighbors[direction].screen == next:
			_commit_menu_neighbor(direction)
			return
	_show_screen(next)

func _finish_menu_page_slide() -> void:
	_stop_menu_page_motion()
	_activate_menu_page.call_deferred(_navigation_generation)
	_prepare_menu_neighbors.call_deferred(_navigation_generation)

func _settle_menu_before_touch() -> void:
	if menu_page_motion != null and _preparing_rivalry_motion == null: _finish_menu_page_slide()
	if menu_edge_motion != null: _stop_menu_edge_motion()

func _activate_menu_page(generation: int) -> void:
	if generation != _navigation_generation or not is_instance_valid(menu_body): return
	var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	if menu_page_motion != null or (swipe != null and swipe.pointer != -1):
		await get_tree().process_frame
		if is_inside_tree(): _activate_menu_page.call_deferred(generation)
		return
	var browser: Control = menu_body.find_child("TrackBrowser", true, false)
	if browser != null and browser.page_preview:
		browser.activate_page()
	if screen == "rivalry" and not cloud_starting and not is_instance_valid(race_loading) and not rivalry.model.sample and online.client.signed_in(): rivalry.refresh(false)
	if screen == "rivalry": _maybe_rivalry_summary.call_deferred()
	if screen == "challenges" and challenge_browsing: challenges.refresh()
	if screen == "daily":
		var daily: Node = menu_body.find_child("TrackOfDayPage",true,false)
		if daily != null: daily.activate()
	if screen == "store":
		var store: Node = menu_body.find_child("StorePage",true,false)
		if store != null: store.activate()

func _account_changed() -> void:
	_daily_track_cache.clear()
	_daily_track_cache_scope = ""
	if is_instance_valid(publication_notification):
		var empty_publications: Array[Dictionary] = []
		publication_notification.set_entries(empty_publications)
	if product_telemetry != null:
		product_telemetry.update_identity()
		if startup_complete: _telemetry_observe("menu_ready",{},"ready")
	var previous_profile: String = active_profile
	_select_player_storage()
	if cloud != null and previous_profile != active_profile: cloud.invalidate_outbox()
	if cosmetic_economy != null:
		cosmetic_economy.bind_records(records)
		cosmetic_economy.refresh()
	if appearance_sync != null:
		appearance_sync.bind_records(records)
		appearance_sync.refresh()
	if header_car_cache != null: header_car_cache.bind_records(records)
	if achievements != null:
		achievements.records = records
		achievements.sync_identity()
		achievements.refresh()
	if online.client.signed_in() and not bool(online.client.player.get("analytics_enabled",true)) and bool(records.settings.get("optional_analytics",false)):
		records.settings.optional_analytics = false
		records.save_records()
	_apply_privacy_choice(bool(records.settings.get("optional_analytics",false)))
	if not challenge_invitation.is_empty() and not is_instance_valid(game):
		_open_challenges(true)
		challenges.open(challenge_invitation)
	if lifecycle != null:
		lifecycle.library = library
		lifecycle.records = records
		if is_instance_valid(publication_notification): publication_notification.set_entries(lifecycle.publication_notifications())
		_remember_publication_news()
	if is_instance_valid(account_button):
		account_button.text = online.player_name() if online.client.signed_in() else "Guest"
		account_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED if online.client.signed_in() else Node.AUTO_TRANSLATE_MODE_INHERIT
	var completed_sign_in: bool = screen == "account" and _account_setup_pending and not online.busy and online.profile_ready()
	if previous_profile != active_profile and startup_complete and not is_instance_valid(game) and is_instance_valid(root_ui):
		_rebuild_profile_menu("rivalry" if completed_sign_in else "account" if not online.client.signed_in() else "drafts" if screen == "create" else screen)
	elif completed_sign_in:
		_show_screen("rivalry")
	if completed_sign_in and tutorial != null: tutorial.offer()
	_prefetch_discovery()
	_prefetch_rivalry()

func _prefetch_discovery() -> void:
	if cloud == null or is_instance_valid(game) or not cloud.paged_discovery_available(): return
	# Prime the visible page during sign-in/startup, before Free Race is opened.
	# The adapter coalesces this with menu activation and retains its scoped cache.
	cloud.query_discovery(browser_state,records.settings.get("favorites",[]),records.settings.get("raced_tracks",[]))
	_prime_free_race_comparisons()

func _prime_free_race_comparisons() -> void:
	if cloud == null or is_instance_valid(game) or not online.client.signed_in(): return
	if screen != "tracks":
		discovery_provider.comparisons.cancel_speculation()
		return
	if screen == "tracks" and startup_complete: return # Visible carousel owns its warming window.
	var scope: String = online.client.base_url()+"/"+str(online.client.player.get("id",""))+"/"+str(online.client.test_drivers_available())
	discovery_provider.configure_cache(cloud.cache_root().path_join("menu/"+scope.sha256_text()+".json"),scope)
	var entries: Array = []
	if selected_track != null and selected_track.metadata.has("cloud_version"):
		entries.append({"version_id":selected_track.metadata.cloud_version})
	for entry: Dictionary in cloud.entries.slice(0,6): entries.append(entry)
	discovery_provider.prime_comparisons(online.client,entries,VehicleCatalog.selected)

func _configure_result_comparisons() -> void:
	var scope: String = online.client.base_url()+"/"+str(online.client.player.get("id",""))+"/"+str(online.client.test_drivers_available())
	discovery_provider.configure_cache(cloud.cache_root().path_join("menu/"+scope.sha256_text()+".json"),scope)
	discovery_provider.comparisons.configure(online.client,discovery_provider.snapshot_cache.path+".comparisons.json",scope)

func _select_player_storage() -> void:
	var identity: String = str(online.client.player.get("id", "")) if online.client.signed_in() else ""
	var scope: String = (online.client._base_url + "/" + identity).sha256_text() if not identity.is_empty() else ""
	if scope == active_profile:
		library.owner_name = online.player_name() if not identity.is_empty() else "Guest"
		return
	# Save the outgoing editor under its original owner before selecting Guest or
	# another account. A running race already retains its preference_records.
	var profile_save_error: String = ""
	if not document.is_empty() and library != null:
		var binding: Dictionary = cloud._read(library.directory.path_join(".backend").path_join(str(document.id)+".json")) if cloud != null else {}
		if binding.get("source_fingerprint") != TrackLibrary.draft_fingerprint(document):
			if library.save_wip(document) != OK:
				_profile_draft_recovery[active_profile] = document.duplicate(true)
				profile_save_error = "The previous draft could not be saved. It remains in memory for that account; check available storage."
			else: _profile_draft_recovery.erase(active_profile)
	_flush_editor_writes()
	_navigation_generation += 1
	_finish_preview_thread()
	active_profile = scope
	if challenges != null:
		challenges.reset()
		challenge_seed = {}
		challenge_result_view = false
	if rivalry != null:
		rivalry.test_population = false
		rivalry.reset()
		rivalry_result_pending = false
	if scope.is_empty():
		records = guest_records
		library = guest_library
	else:
		var directory: String = profile_root.path_join("players").path_join(scope)
		DirAccess.make_dir_recursive_absolute(directory)
		records = LocalRecords.new(directory.path_join("records.json"))
		library = TrackLibrary.new(directory.path_join("tracks"))
	records.load_records()
	GameSoundtrack.instance().bind_records(records)
	GameSoundtrack.instance().apply_settings(records.settings)
	library.owner_name = online.player_name() if not identity.is_empty() else "Guest"
	document = {}
	if _profile_draft_recovery.has(scope): document = _profile_draft_recovery[scope].duplicate(true)
	history.clear()
	redo_history.clear()
	editor_view.clear()
	object_browser_state.clear()
	browser_state.clear()
	track_catalog = null
	discovery_provider = TrackDiscoveryProvider.new()
	if not is_instance_valid(game): test_document_snapshot = {}
	test_return_to_drafts = false
	returning_to_editor = false
	pending_menu_notice = profile_save_error
	_restore_selected_track()
	VehicleCatalog.selected = VehicleCatalog.valid_id(str(records.settings.get("selected_car", "compact")))
	ui_touch_scale = float(records.settings.get("touch_scale", 1.0))
	ui_left_handed = bool(records.settings.get("left_handed", false))

func _restore_selected_track(fallback: NativeTrack = null) -> void:
	selected_track = fallback if fallback != null else NativeTrack.read("res://resources/tracks/" + BUILTIN_IDS[0] + ".json")
	var last: String = str(records.settings.get("last_track", ""))
	if last in BUILTIN_IDS:
		selected_track = NativeTrack.read("res://resources/tracks/" + last + ".json")
	elif last.begins_with("creator_"):
		var saved: Dictionary = library.load_document(last.trim_prefix("creator_"))
		if not saved.is_empty():
			var track: NativeTrack = TrackCompiler.compile(saved)
			if track != null: selected_track = track
	elif last.begins_with("cloud_"): _restore_cloud_selection(last)

func _stamp_creator() -> void:
	if not document.is_empty(): document["creator"] = library.owner_name

func _restore_cloud_selection(identity: String) -> void:
	if cloud == null: return
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog,null,[identity])
	for entry: Dictionary in catalog.entries:
		if entry.id == identity or "cloud_"+str(entry.version_id) == identity:
			selected_track = cloud.presentation_track(entry)
			records.settings.last_track = entry.id
			return

func _open_account() -> void:
	_show_screen("account")
	online.refresh_options()

func _account() -> void:
	_account_setup_pending = not online.profile_ready()
	var background := preload("res://ui/account_backdrop.gd").new()
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32 if side in ["left", "right"] else 16)
	root_ui.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var panel := preload("res://ui/account_panel.gd").new()
	panel.account = online
	# Finish the guest button's input dispatch before replacing its menu tree.
	# Otherwise that same release can activate the newly created car picker.
	panel.continue_requested.connect(_continue_from_account,CONNECT_DEFERRED)
	center.add_child(panel)
	var fit_card := func() -> void:
		if not is_instance_valid(panel) or not panel.is_inside_tree(): return
		panel.fit_width()
	root_ui.resized.connect(fit_card)
	fit_card.call_deferred()

func _continue_from_account() -> void:
	if screen != "account": return
	_open_rivalry()
	if tutorial != null: tutorial.offer()

func _heading(eyebrow: String, title: String, parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	parent.add_child(MenuStyle.label(eyebrow, 15, true))
	parent.add_child(MenuStyle.label(title, 32))

func _feature(parent: HBoxContainer, title: String, description: String, action: Callable) -> void:
	var feature := MenuFeature.new()
	feature.heading = title
	feature.description = description
	feature.pressed.connect(action)
	parent.add_child(feature)

func _open_library(section: String) -> void:
	browser_state.section = "all" if section == "random" else section
	browser_state.page = 0
	if section == "random": browser_state.random_on_open = true
	_show_screen("tracks")

func _ensure_track_catalog() -> void:
	_feature_resource("res://core/features/tracks.gd").run_ensure_track_catalog(self)

func _tracks(parent: VBoxContainer = null, preview: bool = false) -> void:
	_feature_resource("res://core/features/tracks.gd").run_tracks(self ,parent, preview)

func _menu_track_selected(track: NativeTrack) -> void:
	selected_track = track
	if screen == "tracks":
		var properties: Dictionary = _telemetry_track_properties(track)
		properties.mode = "free"
		properties.car_id = VehicleCatalog.selected
		properties.erase("ticket_id")
		_telemetry_observe("track_selected",properties)
	if screen == "garage" and is_instance_valid(content): _refresh_cached_menu_page("garage",content)
	for neighbor: Dictionary in menu_neighbors.values():
		if neighbor.screen == "garage": _refresh_cached_menu_page("garage",neighbor.content)

func _prepare_selected_track(track: NativeTrack, browser: Control) -> void:
	_feature_resource("res://core/features/selected_track.gd").run_prepare_selected_track(self ,track, browser)

func _prepare_selected_event(kind: String, page: Control, entry: Dictionary, source: Dictionary = {}) -> void:
	_feature_resource("res://core/features/selected_track.gd").run_prepare_selected_event(self,kind,page,entry,source)

func _selected_event_track(entry: Dictionary) -> NativeTrack:
	return _feature_resource("res://core/features/selected_track.gd").run_selected_event_track(self,entry)

func _selected_preparation_obsolete(generation: int) -> bool:
	return _feature_resource("res://core/features/selected_track.gd").run_selected_preparation_obsolete(self ,generation)

func _begin_selected_geometry(generation: int, entry: Dictionary, source: Dictionary) -> void:
	_feature_resource("res://core/features/selected_track.gd").run_begin_selected_geometry(self ,generation, entry, source)

func _poll_selected_preparation() -> void:
	if not _selected_preparation_pending: return
	_feature_resource("res://core/features/selected_track.gd").run_poll_selected_preparation(self)

func _cancel_selected_preparation() -> void:
	_selected_preparation_generation += 1
	if _selected_preparation_job != null: SELECTED_PREPARATION.cancel(_selected_preparation_job)
	_selected_preparation_job = null
	_selected_preparation_pending = false
	_selected_preparation_track = null
	_selected_preparation_browser = null
	_selected_preparation_entry = {}
	_selected_preparation_pin = []
	_selected_preparation_source = {}
	_selected_preparation_queued = false
	_selected_preparation_event = {}

func _await_selected_preparation(track: NativeTrack, loading_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	return await _feature_resource("res://core/features/selected_track.gd").run_await_selected_preparation(self ,track, loading_id, scope, navigation, starting_screen, vehicle, selection)

func _open_race_area() -> void:
	if race_area_mode == "rivalry": _open_rivalry()
	elif race_area_mode == "challenges": _open_challenges()
	elif race_area_mode == "daily": _open_track_of_day()
	else: _navigate_menu_page("tracks")

func _open_challenges(browse: bool = false) -> void:
	_cancel_rivalry_entry()
	challenge_browsing = browse
	race_area_mode = "challenges"
	_navigate_menu_page("challenges")
	if browse and not challenges.busy: challenges.refresh()

func _browse_challenges() -> void:
	challenge_browsing = true
	if challenges.folder not in ["discover","friends","received"]:
		challenges.select_folder("discover")
		return
	_challenges()
	if not challenges.busy: challenges.refresh()

func _challenges_changed() -> void:
	if achievements != null and not challenges.busy:
		var completed: Array = challenges.items.duplicate()
		if not challenges.selected.is_empty(): completed.append(challenges.selected)
		var activity: bool = false
		for item: Dictionary in completed:
			if item.get("state") != "complete" or not item.get("joined",false): continue
			var key: String = achievements.scope+"/"+str(item.get("id",item.get("code","")))
			if _achievement_challenges.has(key): continue
			if _achievement_challenges.size() >= 128: _achievement_challenges.erase(_achievement_challenges.keys()[0])
			_achievement_challenges[key] = true
			activity = true
		if activity: achievements.refresh_after_activity()
	if not challenges.selected.is_empty():
		var identity: String = str(challenges.selected.get("id",""))
		_telemetry_observe("challenge_opened",{"challenge_id":identity,"reason":"open"},identity)
	if screen == "challenges" and is_instance_valid(content) and (not is_instance_valid(game) or challenge_result_view): _challenges()

func _challenges(parent: VBoxContainer = null) -> void:
	await _feature_resource("res://core/features/challenges.gd").run_challenges(self ,parent)

func _clear_challenge_game() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
	challenge_racing = false
	challenge_practice = false

func _receive_challenge(value: String) -> void:
	challenge_invitation = ChallengesClient.code_from(value)
	if challenge_invitation.is_empty(): return
	_track_link_generation += 1
	if not startup_complete:
		await get_tree().process_frame
		_receive_challenge.call_deferred(value)
		return
	if is_instance_valid(game):
		_queued_track_link = ""
		challenge_queued_invitation = challenge_invitation
		return
	_open_challenges(true)
	challenges.open(challenge_invitation)

func _receive_track_link(value: String) -> void:
	var version: String = preload("res://platform/track_links.gd").version_from(value)
	if version.is_empty(): return
	_track_link_generation += 1
	var generation: int = _track_link_generation
	_queued_track_link = value
	if not startup_complete:
		await get_tree().process_frame
		if _queued_track_link == value: _receive_track_link.call_deferred(value)
		return
	if is_instance_valid(game):
		challenge_queued_invitation = ""
		return
	_queued_track_link = ""
	var owner_scope: String = lifecycle.scope()
	var navigation: int = _navigation_generation
	# Resolve only through our configured service, never the incoming URL's host.
	var response: Dictionary = await online.client.request_api("/track-versions/"+version)
	if generation != _track_link_generation or owner_scope != lifecycle.scope() or navigation != _navigation_generation: return
	if is_instance_valid(game):
		_queued_track_link = value
		return
	if not response.get("ok",false) or not response.get("data") is Dictionary:
		_notice("This track link could not be opened. Connect and try again.")
		return
	var entry: Dictionary = response.data
	if not cloud._valid_entry(entry) or str(entry.get("version_id","")) != version or entry.get("state") != "published" or (is_instance_valid(online.client.safety) and not online.client.safety.allows(entry)):
		_notice("This track is no longer available.")
		return
	if not cloud.remember_publication(entry):
		_notice("Could not save the track link on this device. Check available storage and try again.")
		return
	_open_published_track(entry)

func _share_track_link(metadata: Dictionary) -> void:
	var link: String = preload("res://platform/track_links.gd").share_url(metadata,online.client.base_url())
	if link.is_empty(): return
	var title: String = str(metadata.get("name",metadata.get("track_name","Track")))
	if challenge_links.share_track(title+"\n"+link): return
	_notice("Track link copied.\n"+link)

func _challenge_code_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Open challenge"
	dialog.ok_button_text = "Open"
	var field := LineEdit.new()
	field.name = "ChallengeCode"
	field.placeholder_text = "Challenge code or invitation link"
	field.custom_minimum_size = Vector2(460,52)
	field.max_length = 2048
	dialog.add_child(field)
	_own_dialog(dialog)
	dialog.confirmed.connect(func() -> void:
		challenge_invitation = ChallengesClient.code_from(field.text)
		challenges.open(field.text))
	dialog.popup_centered(Vector2i(500,150))
	preload("res://ui/keyboard_dialog.gd").attach(dialog, field)
	field.grab_focus()

func _share_challenge(invitation: Dictionary = {}) -> void:
	var value: Dictionary = challenges.selected if invitation.is_empty() else invitation
	if value.is_empty(): return
	_telemetry_observe("share_clicked",{"challenge_id":str(value.get("id","")),"reason":"share"})
	var time: String = GameText.message("%.3f s") % (float(value.target_ms)/1000.0) if value.get("target_ms") != null else "Join my group challenge"
	var text: String = GameText.message("%s · %s · 5 laps · %s\n%s\nCode: %s") % [str(value.entry.name),time,VehicleCatalog.title(str(value.vehicle_id)),str(value.share_url),str(value.code)]
	if ChallengesClient.is_series(value):
		var names: PackedStringArray = []
		for stage: Dictionary in value.get("stages",[]): names.append(str(stage.entry.name))
		var limit: Variant = value.stages[0].attempt_limit
		var tries: String = "Unlimited tries" if limit == null else str(int(limit))+" tries each"
		text = ("3×3" if value.get("mode") == "3x3" else "Custom challenge")+" · "+str(value.stages.size())+" tracks · "+tries+" · Lowest total time wins\n"+" / ".join(names)+"\n"+str(value.share_url)+"\nCode: "+str(value.code)
	if challenge_links.share(text): return
	var dialog := AcceptDialog.new()
	dialog.title = "Challenge invitation copied"
	dialog.dialog_text = text
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(560,240))

func _cancel_challenge_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Cancel challenge?"
	dialog.dialog_text = "Participants will no longer be able to submit challenge times."
	dialog.ok_button_text = "Cancel challenge"
	_own_dialog(dialog)
	dialog.confirmed.connect(func() -> void: challenges.cancel())
	dialog.popup_centered()

func _create_challenge_dialog(version: String = "", vehicle: String = "", ticket_id: String = "", duration_seconds: int = 604800, finished: Dictionary = {}, attempt_limit: int = 0, configuration: Dictionary = {}, results_only: bool = false) -> void:
	_feature_resource("res://core/features/challenges.gd").run_create_challenge_dialog(self ,version, vehicle, ticket_id, duration_seconds, finished, attempt_limit, configuration, results_only)

func _race_created_challenge(code: String, scope: String) -> void:
	await _feature_resource("res://core/features/challenges.gd").run_race_created_challenge(self ,code, scope)

func _show_challenge_ready() -> void:
	_feature_resource("res://core/features/challenges.gd").run_show_challenge_ready(self)

func _close_challenge_create() -> void:
	_feature_resource("res://core/features/challenges.gd").run_close_challenge_create(self)

func _challenge_finished_context(track: NativeTrack, total: float, laps: int, ticket_id: String, vehicle: String) -> Dictionary:
	return _feature_resource("res://core/features/challenges.gd").run_challenge_finished_context(self ,track, total, laps, ticket_id, vehicle)

func _race_for_challenge(metadata: Dictionary, vehicle: String, duration_seconds: int = 604800, attempt_limit: int = 0, configuration: Dictionary = {}) -> void:
	await _feature_resource("res://core/features/challenges.gd").run_race_for_challenge(self ,metadata, vehicle, duration_seconds, attempt_limit, configuration)

func _start_challenge_race() -> void:
	await _feature_resource("res://core/features/challenges.gd").run_start_challenge_race(self)

func _challenge_selection_current(owner_scope: String, navigation: int, code: String, stage_index: int) -> bool:
	return _feature_resource("res://core/features/challenges.gd").run_challenge_selection_current(self ,owner_scope, navigation, code, stage_index)

func _abort_challenge_start(loading_id: int = 0) -> void:
	cloud_starting = false
	if loading_id != 0: _close_race_loading(loading_id)
	if screen == "challenges" and is_instance_valid(content): _challenges()

func _reset_rivalry_entry_view() -> void:
	if rivalry_racing and rivalry_section in ["race_results","result"] and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		rivalry_racing = false
	rivalry_section = "overview"

func _open_world_circuit() -> void:
	if is_instance_valid(game) or cloud_starting: return
	if online != null and not preload("res://backend/world_ranking_client.gd").circuit_open(online.client):
		_notice("The weekly Circuit has not opened. Check World Ranking for the launch date.")
		return
	var circuit_car: String = "compact"
	if online != null and preload("res://backend/world_ranking_client.gd").multi_supported(online.client):
		var ranking_adapter: Node = preload("res://backend/world_ranking_client.gd").for_client(online.client)
		circuit_car = ranking_adapter.circuit_vehicle if not ranking_adapter.circuit_vehicle.is_empty() else VehicleCatalog.selected
	rivalry.set_circuit_mode(true,circuit_car)
	rivalry_section = "overview"
	_open_rivalry()

func _open_rivalry() -> void:
	if game_configuration != null and not game_configuration.settings.get("features.rivalry_entry",true) and not rivalry_racing:
		_notice("Weekly Rivalry entry is temporarily unavailable.")
		return
	if _rivalry_entry_pending: return
	_race_mode_request += 1
	var request: int = _race_mode_request
	var navigation: int = _navigation_generation
	if not rivalry.model.sample: rivalry.refresh(false)
	var original: String = rivalry.scope()
	if online.client.signed_in() and not rivalry.has_snapshot() and rivalry.busy:
		_rivalry_entry_pending = true
		_update_rivalry_entry_button()
		while rivalry.busy and request == _race_mode_request and navigation == _navigation_generation and original == rivalry.scope():
			await get_tree().process_frame
	if request != _race_mode_request: return
	_rivalry_entry_pending = false
	_update_rivalry_entry_button()
	if navigation != _navigation_generation or original != rivalry.scope(): return
	race_area_mode = "rivalry"
	_navigate_menu_page("rivalry")

func _prefetch_rivalry() -> void:
	if rivalry == null or rivalry.model.sample or not online.client.signed_in() or is_instance_valid(game): return
	if rivalry.has_snapshot(): return
	rivalry.refresh(false)

func _rivalry_needs_entry_data() -> bool:
	return rivalry != null and not rivalry.model.sample and online.client.signed_in() and not rivalry.has_snapshot() and (rivalry.busy or rivalry.error.is_empty())

func _cancel_rivalry_entry() -> void:
	_race_mode_request += 1
	_rivalry_entry_pending = false
	_update_rivalry_entry_button()

func _update_rivalry_entry_button() -> void:
	var parent: Control = race_mode_transition_rail if is_instance_valid(race_mode_transition_rail) else menu_body
	if not is_instance_valid(parent): return
	var button: Button = parent.find_child("Mode_trophy",true,false)
	if button == null: return
	button.disabled = _rivalry_entry_pending
	button.icon = MenuIcon.texture("clock") if _rivalry_entry_pending else preload("res://ui/race_mode_icons.gd").texture("trophy")

func _rivalry_changed() -> void:
	if achievements != null and rivalry.model.completed and not rivalry.model.sample and not rivalry.busy and not rivalry.cached_snapshot:
		var finale: String = rivalry.snapshot_scope+"/"+rivalry.model.group_id
		if finale != _achievement_finale:
			_achievement_finale = finale
			achievements.refresh_after_activity()
	if rivalry.result_ticket.is_empty() or rivalry.result_state in ["verified","skipped","failed","rejected","expired"]: rivalry_result_pending = false
	if screen == "rivalry" and is_instance_valid(content) and (not is_instance_valid(game) or rivalry_section == "result"):
		_rivalry()
	# Swipe previews must follow the same membership state as the visible page.
	for neighbor: Dictionary in menu_neighbors.values():
		if neighbor.screen == "rivalry": _rivalry(neighbor.content)
	if returning_menu_neighbor.get("screen","") == "rivalry" and is_instance_valid(returning_menu_neighbor.get("content")):
		_rivalry(returning_menu_neighbor.content)

func _park_rivalry_page(branch: Node) -> void:
	if not is_instance_valid(_retained_rivalry_page) or not branch.is_ancestor_of(_retained_rivalry_page): return
	if not is_instance_valid(_rivalry_parking):
		_rivalry_parking = VBoxContainer.new()
		_rivalry_parking.name = "RetainedRivalry"
		_rivalry_parking.process_mode = Node.PROCESS_MODE_DISABLED
		_rivalry_parking.hide()
		menu_layer.add_child(_rivalry_parking)
		_set_menu_preview_input(_rivalry_parking,true)
	# Keep one actual page, including the three one-shot car viewports. It stays
	# visible in its departing body until that body's slide has completed.
	_retained_rivalry_page.reparent(_rivalry_parking,false)
	for viewport: SubViewport in _retained_rivalry_page.find_children("*","SubViewport",true,false):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _rivalry(parent: VBoxContainer = null) -> void:
	_feature_resource("res://core/features/rivalry.gd").run_rivalry(self ,parent)

func _rivalry_summary_key() -> String:
	if rivalry != null and rivalry.model.empty_completed_week(): return ""
	if rivalry == null or screen != "rivalry" or rivalry_section != "overview" or is_instance_valid(game): return ""
	if not is_instance_valid(root_ui) or not root_ui.is_visible_in_tree(): return ""
	if rivalry.model.sample or not rivalry.model.completed or rivalry.cached_snapshot or rivalry.model.tracks.size() != 5: return ""
	if rivalry.snapshot_scope != rivalry.scope() or rivalry.model.group_id.is_empty(): return ""
	return JSON.stringify([rivalry.scope(),rivalry.model.group_id,rivalry.model.week,rivalry.model.vehicle_id,rivalry.circuit_mode])

func _maybe_rivalry_summary() -> void:
	var key: String = _rivalry_summary_key()
	if key.is_empty() or _reviewed_rivalry_summaries.has(key) or rivalry.busy or cloud_starting: return
	if menu_page_motion != null or is_instance_valid(race_loading): return
	var payload: String = rivalry.model.finale_share_text()
	var existing: Window = root_ui.get_node_or_null("RivalrySummaryDialog") as Window
	if existing != null:
		if existing.receipt_key == key and existing.payload == payload: return
		existing.hide()
		root_ui.remove_child(existing)
		existing.queue_free()
	for child: Node in root_ui.get_children():
		if child is Window and child.visible:
			if not child.visibility_changed.is_connected(_maybe_rivalry_summary): child.visibility_changed.connect(_maybe_rivalry_summary,CONNECT_ONE_SHOT | CONNECT_DEFERRED)
			return
	var dialog = load("res://ui/rivalry_summary_dialog.gd").new()
	dialog.summary = rivalry.model.finale_summary()
	dialog.summary.personal_bests = rivalry.model.personal_best_slots.size()
	var opponent: Dictionary = {}
	for driver: Dictionary in rivalry.model.standing():
		if driver.id != WeeklyRivalry.SELF:
			opponent = driver
			break
	dialog.summary.opponent_points = opponent.get("points")
	dialog.summary.lead = int(dialog.summary.points)-int(opponent.get("points",0))
	var own: Dictionary = WeeklyRivalry.self_row(rivalry.model.standing())
	dialog.player_name = online.player_name() if online.client.signed_in() else str(own.get("name",GameText.message("You")))
	if dialog.player_name.is_empty(): dialog.player_name = str(own.get("name",GameText.message("You")))
	dialog.vehicle_id = rivalry.model.vehicle_id
	dialog.livery = VehicleLivery.for_car(records.settings,rivalry.model.vehicle_id)
	dialog.customisation = VehicleCustomisation.for_car(records.settings,rivalry.model.vehicle_id)
	dialog.condition = VehicleCondition.read(records,rivalry.model.vehicle_id)
	dialog.week = rivalry.model.week
	dialog.circuit = rivalry.circuit_mode
	dialog.receipt_key = key
	dialog.payload = payload
	var owner_id: int = root_ui.get_instance_id()
	dialog.context_current = func() -> bool: return is_instance_valid(root_ui) and root_ui.get_instance_id() == owner_id and _rivalry_summary_key() == key
	dialog.continue_available = func() -> bool: return dialog.context_current.call() and not rivalry.busy and not cloud_starting
	var reviewed: Callable = func() -> void:
		if is_instance_valid(root_ui) and root_ui.get_instance_id() == owner_id and _rivalry_summary_key() == key and rivalry.model.finale_share_text() == payload: _reviewed_rivalry_summaries[key] = true
	dialog.confirmed.connect(reviewed)
	dialog.canceled.connect(reviewed)
	dialog.continue_requested.connect(func() -> void:
		if not dialog.context_current.call() or rivalry.busy or cloud_starting or rivalry.model.finale_share_text() != payload: return
		reviewed.call()
		dialog.hide()
		dialog.queue_free()
		rivalry.continue_week())
	_own_dialog(dialog)
	dialog.present()

func _share_rivalry_results() -> void:
	if rivalry.busy or rivalry.cached_snapshot or not rivalry.model.completed: return
	if not rivalry.model.sample and rivalry.snapshot_scope != rivalry.scope(): return
	var text: String = rivalry.model.finale_share_text()
	if text.is_empty(): return
	if root_ui.get_node_or_null("RivalryShareDialog") != null: return
	var dialog = load("res://ui/rivalry_share_dialog.gd").new()
	dialog.model = rivalry.model
	dialog.native_sharing = challenge_links.can_share_results()
	dialog.player_name = online.player_name() if online.client.signed_in() else ""
	dialog.livery = VehicleLivery.for_car(records.settings,rivalry.model.vehicle_id)
	dialog.customisation = VehicleCustomisation.for_car(records.settings,rivalry.model.vehicle_id)
	dialog.condition = VehicleCondition.read(records,rivalry.model.vehicle_id)
	if not dialog.native_sharing: DisplayServer.clipboard_set(text)
	var context: Dictionary = {"scope":rivalry.scope(),"group":rivalry.model.group_id,"week":rivalry.model.week,"text":text,"screen":screen}
	dialog.share_requested.connect(_share_rivalry_card.bind(weakref(dialog),context))
	dialog.save_requested.connect(_save_rivalry_card.bind(weakref(dialog),context))
	_own_dialog(dialog)
	var bounds: Vector2 = root_ui.get_viewport().get_visible_rect().size
	dialog.popup_centered(Vector2i(minf(1120,bounds.x-48),minf(620,bounds.y-48)))
	if dialog.native_sharing: _share_rivalry_card.call_deferred(weakref(dialog),context)

func _rivalry_card_valid(dialog: AcceptDialog, context: Dictionary) -> bool:
	return is_instance_valid(dialog) and not dialog.is_queued_for_deletion() and dialog.visible \
		and screen == context.screen and rivalry.scope() == context.scope and not rivalry.cached_snapshot \
		and (rivalry.model.sample or rivalry.snapshot_scope == context.scope) \
		and rivalry.model.completed and rivalry.model.group_id == context.group and rivalry.model.week == context.week \
		and rivalry.model.finale_share_text() == context.text

func _share_rivalry_card(dialog_ref: WeakRef, context: Dictionary) -> void:
	var dialog: AcceptDialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context) or dialog.sharing: return
	dialog.set_sharing(true,"Preparing image…")
	dialog.request_id = ""
	var png: PackedByteArray = await _prepare_rivalry_card(dialog_ref,context)
	dialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context):
		if is_instance_valid(dialog): dialog.set_sharing(false,"Results changed. Close and share again.")
		return
	if png.is_empty():
		dialog.set_sharing(false,"Couldn't prepare the image. Try again.")
		return
	dialog.request_id = TrackLibrary.unique_id()
	dialog.set_sharing(false,"Ready to share")
	var opened: bool = challenge_links.share_results(dialog.request_id,png,str(context.text))
	if not opened: dialog.set_sharing(false,"Couldn't open sharing. Try again.")

func _prepare_rivalry_card(dialog_ref: WeakRef, context: Dictionary) -> PackedByteArray:
	var dialog: AcceptDialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context): return PackedByteArray()
	if not dialog.prepared_png.is_empty(): return dialog.prepared_png
	var values: Dictionary = dialog.image_values()
	values.owner = dialog_ref
	var renderer: Callable = dialog.image_renderer
	var png: PackedByteArray
	if renderer.is_valid(): png = await renderer.call(root_ui,values)
	else: png = await load("res://ui/rivalry_share_image.gd").render(root_ui,values)
	dialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context): return PackedByteArray()
	dialog.prepared_png = png
	return png

func _rivalry_share_failed(request_id: String, message: String) -> void:
	var dialog: AcceptDialog = root_ui.get_node_or_null("RivalryShareDialog") as AcceptDialog
	if is_instance_valid(dialog) and dialog.request_id == request_id: dialog.set_sharing(false,message)

func _save_rivalry_card(dialog_ref: WeakRef, context: Dictionary) -> void:
	var dialog: AcceptDialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context) or dialog.sharing: return
	dialog.set_sharing(true,"Preparing image…")
	var png: PackedByteArray = await _prepare_rivalry_card(dialog_ref,context)
	dialog = dialog_ref.get_ref() as AcceptDialog
	if not _rivalry_card_valid(dialog,context):
		if is_instance_valid(dialog): dialog.set_sharing(false,"Results changed. Close and share again.")
		return
	if png.is_empty():
		dialog.set_sharing(false,"Couldn't prepare the image. Try again.")
		return
	var picker := FileDialog.new()
	picker.title = "Save results card"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.use_native_dialog = true
	picker.theme = MenuStyle.theme()
	picker.filters = PackedStringArray(["*.png ; PNG image"])
	picker.current_file = GameText.message("Beat my track - Rivalry - Week %02d.png") % int(context.week)
	dialog.add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		if _rivalry_card_valid(dialog,context):
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file != null:
				file.store_buffer(png)
				file.flush()
				var error: Error = file.get_error()
				file.close()
				dialog.set_sharing(false,"Image saved" if error == OK else "Couldn't save the image. Try again.")
			else: dialog.set_sharing(false,"Couldn't save the image. Try again.")
		picker.queue_free())
	picker.canceled.connect(func() -> void:
		if is_instance_valid(dialog): dialog.set_sharing(false,"Results copied")
		picker.queue_free())
	picker.popup_centered_ratio(0.8)

func _remember_rivalry_standings(parent: Control) -> void:
	if not is_instance_valid(parent): return
	var page: Control = parent.find_child("WeeklyRivalryPage",true,false)
	if page == null or not page.standings_ready or not is_instance_valid(page.standings_scroll): return
	rivalry_standings_view = {"key":page.standings_identity,"offset":page.standings_scroll.scroll_vertical}

func _prepare_rivalry_track_preview(page: Control, index: int) -> void:
	await _feature_resource("res://core/features/rivalry.gd").run_prepare_rivalry_track_preview(self ,page, index)

func _rivalry_ghost(index: int, choice: int, wait_for_recording: bool = false) -> Dictionary:
	return await _feature_resource("res://core/features/rivalry.gd").run_rivalry_ghost(self ,index, choice, wait_for_recording)

func _start_rivalry_race(index: int, choice: int) -> void:
	await _feature_resource("res://core/features/rivalry.gd").run_start_rivalry_race(self ,index, choice)

func _ensure_garage_parking() -> void:
	if not is_instance_valid(_garage_parking):
		_garage_parking = VBoxContainer.new()
		_garage_parking.name = "RetainedGarage"
		_garage_parking.process_mode = Node.PROCESS_MODE_DISABLED
		menu_layer.add_child(_garage_parking)
		menu_layer.move_child(_garage_parking,0)
		MenuStyle.fill(_garage_parking)
		_set_menu_preview_input(_garage_parking,true)
		_garage_parking.hide()

func _park_garage() -> void:
	if not is_instance_valid(_retained_garage): return
	if is_instance_valid(_retained_garage.get("_preview_service")): _retained_garage._preview_service.suspend_previews()
	_ensure_garage_parking()
	_garage_parking.hide()
	if _retained_garage.get_parent() != _garage_parking:
		_retained_garage.reparent(_garage_parking,false)
	# Reparenting between inherited hidden branches need not emit visibility_changed.
	_retained_garage.showroom._reflection_visibility()

func _garage_residency() -> Dictionary:
	var result: Dictionary = {"image_gpu_bytes":0,"viewport_gpu_bytes":0,"scene_bytes":0,"preview_io_cpu_bytes":0}
	var seen: Dictionary = {}
	if is_instance_valid(_garage_preloader): result.merge(_garage_preloader.residency(seen))
	if not is_instance_valid(_retained_garage): return result
	for card: Control in _retained_garage.thumbnails.values():
		var image: TextureRect = card.get("_image")
		if image == null or image.texture == null or seen.has(image.texture.get_instance_id()): continue
		seen[image.texture.get_instance_id()] = true
		result.image_gpu_bytes += image.texture.get_width()*image.texture.get_height()*4
	for viewport: SubViewport in _retained_garage.find_children("*","SubViewport",true,false):
		result.viewport_gpu_bytes += viewport.size.x*viewport.size.y*8
	result.scene_bytes = load("res://track/prepared_world_cache.gd")._resource_bytes(_retained_garage,{})
	if is_instance_valid(_retained_garage.get("_preview_service")) and (_retained_garage._preview_service.worker != null or not _retained_garage._preview_service.pending_writes.is_empty()): result.preview_io_cpu_bytes = 16*1024*1024
	return result

func _trim_hidden_garage() -> void:
	if is_instance_valid(_garage_preloader): _garage_preloader.evict()
	if not is_instance_valid(_retained_garage) or _retained_garage.is_visible_in_tree(): return
	_discard_suspended_menu()
	var retired: Control = _retained_garage
	_retained_garage = null
	retired.get_parent().remove_child(retired)
	retired.queue_free()
	for direction: int in menu_neighbors.keys():
		if menu_neighbors[direction].screen!="garage": continue
		var body: Control=menu_neighbors[direction].body
		menu_neighbors.erase(direction)
		body.get_parent().remove_child(body)
		body.queue_free()

func _rebuild_profile_menu(destination: String) -> void:
	# Garage owns its account fence in _garage, like the other menu pages.
	if destination == "garage":
		_show_screen(destination)
		return
	_show_screen("restoring")
	var generation: int = _navigation_generation
	var owner_records: LocalRecords = records
	if is_instance_valid(_retained_garage) and _retained_garage.records != records:
		_retained_garage.get_parent().remove_child(_retained_garage)
		_retained_garage.queue_free()
		_retained_garage = null
	if not is_inside_tree() or generation != _navigation_generation or owner_records != records or is_instance_valid(game): return
	_show_screen(destination)

func _garage_appearance_changed() -> void:
	if is_instance_valid(_garage_preloader): _garage_preloader.invalidate()
	_refresh_account_car()
	if is_instance_valid(_retained_garage) and _retained_garage.records == records:
		_retained_garage.refresh_cosmetics()

func _prepare_garage_pictures() -> bool:
	# Explicit callers can request a complete snapshot. Startup/navigation
	# never await this optional work; visible missing views use car ghosts.
	var generation: int=_navigation_generation
	var owner_records: LocalRecords=records
	var current: Callable=func() -> bool: return is_inside_tree() and generation==_navigation_generation and records==owner_records
	return await _garage_preloader.prepare_pictures(current)

var _header_capture_navigation: int = -1

func _header_car_work_allowed() -> bool:
	return startup_complete and _publishing_slots_foreground and not is_instance_valid(game) and _background_work_allowed() and screen != "restoring"

func _header_car_capture_allowed(_vehicle: String) -> bool:
	if not _header_car_work_allowed() or not _initial_menu_presented or editor_memory.pressure_requested: return false
	if is_instance_valid(header_car_cache) and header_car_cache.capture_active() and _header_capture_navigation != _navigation_generation: return false
	if menu_page_motion != null and menu_page_motion.is_running(): return false
	if not is_instance_valid(_garage_preloader) or not _garage_preloader.presentation_idle(): return false
	if is_instance_valid(_garage_preloader.picture_service) and _garage_preloader.picture_service.renderer != null: return false
	if is_instance_valid(_garage_preloader.studio): return false
	if screen in ["account","tracks","rivalry","challenges","settings","profile"]:
		return not is_instance_valid(_retained_garage) or not _retained_garage.is_visible_in_tree()
	# A paint save already updates the live car. Keep it visible and interactive;
	# optional header rendering waits until the Garage has left the screen.
	return false

func _header_car_capture_started(_vehicle: String) -> void:
	_header_capture_navigation = _navigation_generation

func _header_car_capture_finished() -> void:
	_header_capture_navigation = -1

func _header_car_picture_ready(vehicle: String) -> void:
	if not is_instance_valid(account_button): return
	var header: Control = account_button.get_node_or_null("MenuProfileCar")
	if header != null and header.records == header_car_cache.records and vehicle == VehicleCatalog.selected: header.refresh()
	var picker: Control = account_button.get_node_or_null("MenuCarPicker")
	if picker != null and picker.records == header_car_cache.records: picker.refresh_picture(vehicle)
	if vehicle == VehicleCatalog.selected and records == header_car_cache.records and is_instance_valid(content):
		var profile: Node = content.find_child("OwnProfilePage",true,false)
		if profile != null: profile.refresh_car()

func _refresh_account_car() -> void:
	if not is_instance_valid(account_button): return
	var preview: Control = account_button.get_node_or_null("MenuProfileCar")
	if preview != null: preview.refresh()
	if is_instance_valid(content):
		var profile: Node = content.find_child("OwnProfilePage",true,false)
		if profile != null: profile.refresh_car()

func _garage(parent: Control = null) -> void:
	_feature_resource("res://core/features/garage.gd").run_garage(self ,parent)

func _start_garage_free_drive() -> void:
	await _feature_resource("res://core/features/garage.gd").run_start_garage_free_drive(self)

func _leave_garage_free_drive() -> void:
	_feature_resource("res://core/features/garage.gd").run_leave_garage_free_drive(self)

func _race_news_story(story: Dictionary) -> void:
	await _feature_resource("res://core/features/garage.gd").run_race_news_story(self ,story)

func _news_race_changed(loading_id: int, scope: String, navigation: int, vehicle: String, selection: NativeTrack) -> bool:
	return _feature_resource("res://core/features/garage.gd").run_news_race_changed(self ,loading_id, scope, navigation, vehicle, selection)

func _settings() -> void:
	_feature_resource("res://core/features/settings.gd").run_settings(self)

func _apply_privacy_choice(enabled: bool) -> void:
	if product_telemetry == null: return
	online.client.analytics_opt_in = enabled
	product_telemetry.set_enabled(enabled)
	if online.client.signed_in() and online.client.deletion_supported() and bool(online.client.player.get("analytics_enabled",true)) != enabled:
		var result: Dictionary = await online.client.request_api("/privacy/preferences",HTTPClient.METHOD_POST,{"analytics_enabled":enabled},"",true)
		if result.ok:
			online.client.player.analytics_enabled = enabled
			product_telemetry.update_identity()
		elif not enabled: _notice("Sharing is off on this device. The server preference could not be saved; retry when connected.")

func _erase_removed_account(origin: String, player_id: String) -> void:
	product_telemetry.erase_account(origin,player_id)
	if achievements != null and not achievements.erase_account(origin,player_id):
		_notice("Account removed. Achievement cache could not be erased; check storage.")
	if cosmetic_economy != null and not cosmetic_economy.erase_account(origin,player_id):
		_notice("Account removed. Coin recovery files could not be erased; check writable storage.")
	if not online.client.session_path.is_empty():
		var safety_path: String = online.client.session_path.get_base_dir().path_join("community/"+(origin+"/"+player_id).sha256_text()+".json")
		for path: String in [safety_path,safety_path+".tmp"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var paths: Array[String] = [
		(root_cloud_path(origin)).path_join("players").path_join(player_id.sha256_text()),
		online.client.resume_recovery._directory(player_id,origin),
		library.directory.path_join(".workflow").path_join((origin+"/"+player_id).sha256_text())]
	# Let pending replay/file preparations settle before a separate menu IO task
	# removes their old scope. No scene tree or canonical step enters that task.
	while not online.client._encoding_threads.is_empty(): await get_tree().process_frame
	var cleaned: Variant = await online.client._background(preload("res://backend/privacy_local.gd").erase_roots.bind(paths))
	if cleaned != true and is_inside_tree(): _notice("Account removed. Some local recovery files could not be erased; check writable storage.")

func root_cloud_path(origin: String) -> String:
	return (cloud.root_override if not cloud.root_override.is_empty() else "user://cloud").path_join(origin.sha256_text())

func _customize_controls() -> void:
	_feature_resource("res://core/features/settings.gd").run_customize_controls(self)

func _swipe_menu_page(direction: int) -> void:
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var current: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges","daily"] else screen
	var index: int = pages.find(current)
	if index < 0: return
	var destination: int = index + direction
	if destination < 0 or destination >= pages.size(): return
	if menu_neighbors.has(direction):
		_commit_menu_neighbor(direction)
		return
	# Revisit the current creation choices without replacing an in-progress draft.
	if pages[destination] == "biome" and document.is_empty(): _new_document()
	elif pages[destination] == "tracks": _open_race_area()
	else: _show_screen(pages[destination])

func _new_document() -> void:
	_feature_resource("res://core/features/creator.gd").run_new_document(self)

func _start_new_document() -> void:
	_feature_resource("res://core/features/creator.gd").run_start_new_document(self)

func _editor() -> void:
	_feature_resource("res://core/features/editor.gd").run_editor(self)

func _fit_editor_header(overlay: Control, header: HBoxContainer, track_title: Label, history_panel: PanelContainer, actions: HBoxContainer) -> void:
	_feature_resource("res://core/features/editor.gd").run_fit_editor_header(self ,overlay, header, track_title, history_panel, actions)

func _editor_box() -> StyleBoxFlat:
	return _feature_resource("res://core/features/editor.gd").run_editor_box(self)

func _layout_editor_surface_toolbar() -> void:
	_feature_resource("res://core/features/editor.gd").run_layout_editor_surface_toolbar(self)

func _layout_editor_feedback() -> void:
	_feature_resource("res://core/features/editor.gd").run_layout_editor_feedback(self)

func _editor_fit_area() -> Rect2:
	# A queued fit may outlive the departing page by one deferred callback.
	if not is_instance_valid(canvas): return Rect2()
	return _feature_resource("res://core/features/editor.gd").run_editor_fit_area(self)

func _editor_panel(parent: Control, node_name: String) -> PanelContainer:
	return _feature_resource("res://core/features/editor.gd").run_editor_panel(self ,parent, node_name)

func _apply_editor_safe_area(overlay: Control) -> void:
	_feature_resource("res://core/features/editor.gd").run_apply_editor_safe_area(self ,overlay)

func _editor_hint(message: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_editor_hint(self ,message)

func _update_editor_save_state() -> void:
	_feature_resource("res://core/features/editor.gd").run_update_editor_save_state(self)

func _retry_editor_save() -> void:
	_feature_resource("res://core/features/editor.gd").run_retry_editor_save(self)

func _editor_tool() -> String:
	return _feature_resource("res://core/features/editor.gd").run_editor_tool(self)

func _capture_pending_tool() -> Dictionary:
	return _feature_resource("res://core/features/editor.gd").run_capture_pending_tool(self)

func _stash_pending_tool() -> void:
	_feature_resource("res://core/features/editor.gd").run_stash_pending_tool(self)

func _restore_pending_tool(tool: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_restore_pending_tool(self ,tool)

func _pending_state_has_work(tool: String, state: Dictionary) -> bool:
	return _feature_resource("res://core/features/editor.gd").run_pending_state_has_work(self ,tool, state)

func _has_pending_editor_work() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_has_pending_editor_work(self)

func _discard_editor_previews() -> void:
	_feature_resource("res://core/features/editor.gd").run_discard_editor_previews(self)

func _commit_editor_previews() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_commit_editor_previews(self)

func _resolve_editor_previews(after: Callable, message: String = "Confirm or discard the pending previews before selecting an issue.") -> void:
	_feature_resource("res://core/features/editor.gd").run_resolve_editor_previews(self ,after, message)

func _editor_category(value: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_editor_category(self ,value)

func _context_button(label: String, glyph: String, action: Callable, chosen: bool = false) -> Button:
	return _feature_resource("res://core/features/editor.gd").run_context_button(self ,label, glyph, action, chosen)

func _build_editor_tools() -> void:
	_feature_resource("res://core/features/editor.gd").run_build_editor_tools(self)

func _set_piece_material(surface: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_set_piece_material(self ,surface)

func _change_piece(key: String, delta: float) -> void:
	_feature_resource("res://core/features/editor.gd").run_change_piece(self ,key, delta)

func _delete_piece() -> void:
	_feature_resource("res://core/features/editor.gd").run_delete_piece(self)

func _practice_start(track: NativeTrack) -> Vector2:
	return _feature_resource("res://core/features/editor.gd").run_practice_start(self ,track)

func _practice_heading(track: NativeTrack) -> float:
	return _feature_resource("res://core/features/editor.gd").run_practice_heading(self ,track)

func _update_editor_issues() -> void:
	_feature_resource("res://core/features/editor.gd").run_update_editor_issues(self)

func _update_test_access() -> void:
	_feature_resource("res://core/features/editor.gd").run_update_test_access(self)

func _focus_issue() -> void:
	_feature_resource("res://core/features/editor.gd").run_focus_issue(self)

func _commit_selection() -> void:
	_feature_resource("res://core/features/editor.gd").run_commit_selection(self)

func _delete_selection() -> void:
	_feature_resource("res://core/features/editor.gd").run_delete_selection(self)

func _rotate_object() -> void:
	_feature_resource("res://core/features/editor.gd").run_rotate_object(self)

func _object_property_editing(property: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_object_property_editing(self ,property)

func _build_object_controls(active: bool, browsing: bool) -> void:
	_feature_resource("res://core/features/editor.gd").run_build_object_controls(self ,active, browsing)

func _edit_object_control(property: String, value: Variant) -> void:
	_feature_resource("res://core/features/editor.gd").run_edit_object_control(self ,property, value)

func _object_rotation() -> float:
	return _feature_resource("res://core/features/editor.gd").run_object_rotation(self)

func _set_object_rotation(value: float) -> void:
	_feature_resource("res://core/features/editor.gd").run_set_object_rotation(self ,value)

func _object_rotation_dialog() -> void:
	_feature_resource("res://core/features/editor.gd").run_object_rotation_dialog(self)

func _scale_object(delta: float) -> void:
	_feature_resource("res://core/features/editor.gd").run_scale_object(self ,delta)

func _resize_speed_bump(delta: float) -> void:
	_feature_resource("res://core/features/editor.gd").run_resize_speed_bump(self ,delta)

func _fit_speed_bump() -> void:
	_feature_resource("res://core/features/editor.gd").run_fit_speed_bump(self)

func _duplicate_object() -> void:
	_feature_resource("res://core/features/editor.gd").run_duplicate_object(self)

func _remember() -> void:
	_feature_resource("res://core/features/editor.gd").run_remember(self)

func _set_document_value(key: String, value: Variant) -> void:
	_feature_resource("res://core/features/editor.gd").run_set_document_value(self ,key, value)

func _undo() -> void:
	_feature_resource("res://core/features/editor.gd").run_undo(self)

func _redo() -> void:
	_feature_resource("res://core/features/editor.gd").run_redo(self)

func _restore_editor_history() -> void:
	_feature_resource("res://core/features/editor.gd").run_restore_editor_history(self)

func _refresh_editor() -> void:
	_feature_resource("res://core/features/editor.gd").run_refresh_editor(self)

func _editor_copy_is_current(snapshot: Dictionary, storage: TrackLibrary, relative_path: String, disk_hash: String) -> bool:
	return _feature_resource("res://core/features/editor.gd").run_editor_copy_is_current(self ,snapshot, storage, relative_path, disk_hash)

func _apply_editor_writes() -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and editor_writes.completed.is_empty(): return
	_feature_resource("res://core/features/editor.gd").run_apply_editor_writes(self)

func _apply_editor_commits() -> void:
	if not _feature_resources.has("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_apply_editor_commits(self)

func _flush_editor_writes() -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and editor_writes.pending.is_empty() and editor_writes.thread == null and editor_writes.completed.is_empty(): return
	_feature_resource("res://core/features/editor.gd").run_flush_editor_writes(self)

func _save_draft(background_preview: bool = false) -> Error:
	return _feature_resource("res://core/features/editor.gd").run_save_draft(self ,background_preview)

func _test_document() -> void:
	await _feature_resource("res://core/features/editor.gd").run_test_document(self)

func _publish_current_document() -> void:
	await _feature_resource("res://core/features/editor.gd").run_publish_current_document(self)

func _share_dialog() -> void:
	_feature_resource("res://core/features/editor.gd").run_share_dialog(self)

func _export_file() -> void:
	_feature_resource("res://core/features/editor.gd").run_export_file(self)

func _import_dialog() -> void:
	_feature_resource("res://core/features/editor.gd").run_import_dialog(self)

func _accept_import(imported: Dictionary) -> void:
	_feature_resource("res://core/features/editor.gd").run_accept_import(self ,imported)

func _notice(message: String) -> void:
	var dialog := preload("res://ui/fault_dialog.gd").new()
	dialog.dialog_text = message
	_own_dialog(dialog)
	dialog.popup_message()

func _popup_node_added(node: Node) -> void:
	if node is Window and is_ancestor_of(node):
		preload("res://ui/popup_style.gd").watch(node)

func _own_dialog(dialog: AcceptDialog) -> void:
	# Practice suspends the retained editor. Its owned windows must still take
	# input without enabling the editor underneath the active race.
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ui.add_child(dialog)
	preload("res://ui/popup_style.gd").watch(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	if dialog is FileDialog:
		dialog.file_selected.connect(func(_path: String) -> void: dialog.queue_free())

var test_return_to_drafts: bool = false
var test_document_snapshot: Dictionary = {}
var _practice_editor_context: Dictionary = {}
var _race_menu_processing: Dictionary = {}

func _race_menu_visible(value: bool) -> void:
	_wake_optional_work.call_deferred()
	if not is_instance_valid(root_ui): return
	var identity: int = root_ui.get_instance_id()
	if not value:
		if _race_menu_processing.get("root",0) != identity:
			_race_menu_processing = {"root":identity,"mode":root_ui.process_mode}
		root_ui.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		if _race_menu_processing.get("root",0) == identity: root_ui.process_mode = _race_menu_processing.mode
		_race_menu_processing.clear()
	root_ui.visible = value
var _draft_test_save_context: Dictionary = {}
var _draft_test_save_dialog: AcceptDialog

func _open_race_loading(track: NativeTrack = null, practice: bool = false, elimination: bool = false) -> RaceLoading:
	return RaceLoadingFlow.run_open_race_loading(self ,track, practice, elimination)

func _present_race_loading() -> bool:
	return await RaceLoadingFlow.run_present_race_loading(self)

func _race_loading_matches(expected_id: int) -> bool:
	return RaceLoadingFlow.run_race_loading_matches(self ,expected_id)

func _race_preparation_changed(expected_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	return RaceLoadingFlow.run_race_preparation_changed(self ,expected_id, scope, navigation, starting_screen, vehicle, selection)

func _race_loading_timed_out(expected_id: int) -> void:
	RaceLoadingFlow.run_race_loading_timed_out(self ,expected_id)

func _close_race_loading(expected_id: int = 0) -> void:
	if not is_instance_valid(race_loading): return
	RaceLoadingFlow.run_close_race_loading(self ,expected_id)

func _prepare_metadata_race(track: NativeTrack, from_editor: bool, offline_only: bool, issued: Dictionary, daily_request: Dictionary = {}, prepared_loading: RaceLoading = null) -> void:
	await _feature_resource("res://core/features/race.gd").run_prepare_metadata_race(self ,track, from_editor, offline_only, issued, daily_request, prepared_loading)

func _start_race_road_job(track: NativeTrack) -> RefCounted:
	return _feature_resource("res://core/features/race.gd").run_start_race_road_job(self ,track)

func _start_race(track: NativeTrack, from_editor: bool, offline_only: bool = false, rivalry_issued: Dictionary = {}, prepared_loading: RaceLoading = null, daily_request: Dictionary = {}) -> void:
	if not _feature_resources.has("res://core/features/race.gd") or not _feature_resources.has("res://core/game.tscn"):
		if not RaceLoadingFlow.can_start(self,track,from_editor,prepared_loading): return
		var shell_loading: bool = not is_instance_valid(prepared_loading)
		prepared_loading = prepared_loading if is_instance_valid(prepared_loading) else _open_race_loading(track,from_editor,not daily_request.is_empty())
		var loading_id: int = prepared_loading.get_instance_id()
		var scope: String = lifecycle.scope()
		var navigation: int = _navigation_generation
		var starting_screen: String = screen
		var vehicle: String = VehicleCatalog.selected
		var selection: NativeTrack = selected_track
		var current: Callable = func() -> bool: return is_inside_tree() and not is_queued_for_deletion() and not _race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection)
		cloud_starting = true
		await _present_race_loading()
		for path: String in ["res://core/features/race.gd","res://core/game.tscn"]:
			if not current.call(): return
			if await _await_feature_resource(path,current) == null:
				if current.call():
					_close_race_loading(loading_id)
					_notice("Track could not be prepared. Try again.")
				return
		if not current.call(): return
		# A new cold entry has two bounded stages. Resource loading previously ran
		# before the cover/deadline; keep the full existing race-preparation budget
		# after it completes. A caller's existing ticket/download cover retains its
		# original deadline, so resource work cannot renew that admission window.
		if shell_loading: prepared_loading.get_node("RaceLoadingDeadline").start(RACE_LOAD_DEADLINE_SECONDS)
		cloud_starting = false
	await _feature_resource("res://core/features/race.gd").run_start_race(self ,track, from_editor, offline_only, rivalry_issued, prepared_loading, daily_request)

func _race_installation_current(loading_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	return _feature_resource("res://core/features/race.gd").run_race_installation_current(self ,loading_id, scope, navigation, starting_screen, vehicle, selection)

func _discard_preparing_game(prepared_game: Node) -> void:
	_feature_resource("res://core/features/race.gd").run_discard_preparing_game(self ,prepared_game)

func _prepare_night_lighting(loading_id: int, prepared_game: Node) -> Dictionary:
	return await _feature_resource("res://core/features/race.gd").run_prepare_night_lighting(self ,loading_id, prepared_game)

func _edit_here(position: Vector2) -> void:
	_feature_resource("res://core/features/race.gd").run_edit_here(self ,position)

func _leave_race() -> void:
	_feature_resource("res://core/features/race.gd").run_leave_race(self)

func _resume_practice_editor() -> bool:
	return _feature_resource("res://core/features/race.gd").run_resume_practice_editor(self)

func _results() -> void:
	_feature_resource("res://core/features/race.gd").run_results(self)

func _ad_play_active() -> bool:
	if not startup_complete or not _publishing_slots_foreground or cloud_starting or screen in ["create","drafts"] or returning_to_editor: return false
	return not is_instance_valid(game) or (not bool(game.get("paused")) and not bool(game.get("attempt_practice")))

func _try_race_ad(finished_game: int, panel: Control) -> void:
	await _feature_resource("res://core/features/race.gd").run_try_race_ad(self ,finished_game, panel)

func _remote_config_changed() -> void:
	if game_configuration != null and game_configuration.negotiated and race_ad_breaks != null:
		race_ad_breaks.set_policy(game_configuration.settings)

func _remote_menu_notice() -> void:
	if game_configuration == null or not is_instance_valid(content): return
	var previous: Node = content.get_node_or_null("RemoteGameNotice")
	if previous != null:
		content.remove_child(previous)
		previous.queue_free()
	var message: String = str(game_configuration.settings.get("notice.message",""))
	var expiry: int = int(game_configuration.settings.get("notice.expires_at",0))
	if expiry > 0 and (online.client.server_now() <= 0 or online.client.server_now() >= expiry): message = ""
	if not message.is_empty() and screen not in ["create","restoring"]:
		var notice: Label = MenuStyle.label(message,16)
		notice.name = "RemoteGameNotice"
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(notice)
		content.move_child(notice,0)
	if screen not in ["create","restoring"]: game_configuration.menu_applied(screen)

func _ad_blocking_changed(value: bool) -> void:
	if is_instance_valid(_ad_input_blocker):
		_ad_input_blocker.queue_free()
		_ad_input_blocker = null
	if not value and _ad_previous_focus != null:
		var previous: Control = _ad_previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
		_ad_previous_focus = null
	if value and is_instance_valid(menu_layer):
		var previous: Control = get_viewport().gui_get_focus_owner()
		_ad_previous_focus = weakref(previous) if previous != null else null
		_ad_input_blocker = Control.new()
		_ad_input_blocker.name = "AdInputBlocker"
		_ad_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_ad_input_blocker.focus_mode = Control.FOCUS_ALL
		menu_layer.add_child(_ad_input_blocker)
		MenuStyle.fill(_ad_input_blocker)
		_ad_input_blocker.grab_focus()

func _save_result_upload(completed_game: Node, ticket_data: Dictionary, frames: Variant, publish_version: String, rewinds: Array) -> void:
	_feature_resource("res://core/features/race.gd").run_save_result_upload(self ,completed_game, ticket_data, frames, publish_version, rewinds)

func _results_continue(results: Control, parent: Control) -> void:
	_feature_resource("res://core/features/race.gd").run_results_continue(self ,results, parent)

func _next_result_race(recommendation: Dictionary) -> void:
	_feature_resource("res://core/features/race.gd").run_next_result_race(self ,recommendation)

func _result_capacity_available() -> bool:
	return _feature_resource("res://core/features/race.gd").run_result_capacity_available(self)

func _retry_race(offline_only: bool = false) -> void:
	await _feature_resource("res://core/features/race.gd").run_retry_race(self ,offline_only)

func _prepare_race_rating(track: NativeTrack) -> void:
	_feature_resource("res://core/features/race.gd").run_prepare_race_rating(self ,track)

static func track_title(track: NativeTrack) -> String:
	return str(track.metadata.get("title", track.metadata.get("name", track.identity.replace("_"," ").to_upper())))

func _capture() -> void:
	await get_tree().process_frame
	for child: Node in content.get_children():
		if child is Control and child.get_script() != null and child.get_script().resource_path == "res://ui/track_browser.gd":
			while child.loading: await get_tree().process_frame
	if screen == "tracks":
		var browser: Control = root_ui.find_child("TrackBrowser",true,false)
		while browser != null and browser.loading: await get_tree().process_frame
		for preview: Node in root_ui.find_children("*","TrackShowroom",true,false):
			while not preview.ready_for_display: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	if error == OK: print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit(0 if error == OK else 1)


func _build_paint_tools() -> void:
	_feature_resource("res://core/features/editor.gd").run_build_paint_tools(self)

func _editor_help() -> void:
	_feature_resource("res://core/features/editor.gd").run_editor_help(self)

func _input(event: InputEvent) -> void:
	# Tab is a GUI navigation key and never reaches unhandled_key_input.
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB):
		if is_instance_valid(editor_map_panel) and editor_map_panel.visible: return
		_unhandled_key_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if screen != "create" or is_instance_valid(game): return
	_feature_resource("res://core/features/editor.gd").run_unhandled_key_input(self ,event)

func _save_track_explicit() -> void:
	_feature_resource("res://core/features/editor.gd").run_save_track_explicit(self)

func _save_track_now() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_save_track_now(self)

func _editor_has_unsaved_changes() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_editor_has_unsaved_changes(self)

func _request_editor_exit() -> void:
	_feature_resource("res://core/features/editor.gd").run_request_editor_exit(self)

func _return_from_editor() -> void:
	_feature_resource("res://core/features/editor.gd").run_return_from_editor(self)

func _confirm_editor_departure(after: Callable, allow_discard: bool = true) -> void:
	_feature_resource("res://core/features/editor.gd").run_confirm_editor_departure(self ,after, allow_discard)

func _prepare_editor_load() -> bool:
	return _feature_resource("res://core/features/editor.gd").run_prepare_editor_load(self)

var draft_return_screen: String = "biome"

func _open_drafts() -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_open_drafts(self)

func _open_drafts_after_resolution() -> void:
	_feature_resource("res://core/features/editor.gd").run_open_drafts_after_resolution(self)

func _drafts() -> void:
	_feature_resource("res://core/features/editor.gd").run_drafts(self)

func _fork_track_draft(source: Dictionary) -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_fork_track_draft(self ,source)

func _read_draft_for_action(id: String) -> Dictionary:
	return _feature_resource("res://core/features/editor.gd").run_read_draft_for_action(self ,id)

func _test_saved_draft(id: String) -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	await _feature_resource("res://core/features/editor.gd").run_test_saved_draft(self ,id)

func _complete_draft_test() -> void:
	_feature_resource("res://core/features/editor.gd").run_complete_draft_test(self)

func _draft_test_save_is_current(context: Dictionary) -> bool:
	return _feature_resource("res://core/features/editor.gd").run_draft_test_save_is_current(self ,context)

func _retry_draft_test_save(context: Dictionary) -> void:
	_feature_resource("res://core/features/editor.gd").run_retry_draft_test_save(self ,context)

func _show_draft_test_save_recovery() -> void:
	_feature_resource("res://core/features/editor.gd").run_show_draft_test_save_recovery(self)

func _return_from_draft_test_save(context: Dictionary) -> void:
	_feature_resource("res://core/features/editor.gd").run_return_from_draft_test_save(self ,context)

func _clear_draft_test_save_recovery() -> void:
	_feature_resource("res://core/features/editor.gd").run_clear_draft_test_save_recovery(self)

func _publish_saved_draft(id: String) -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_publish_saved_draft(self ,id)

func _close_publication_prompt(source: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int) -> void:
	_feature_resource("res://core/features/editor.gd").run_close_publication_prompt(self ,source, original_scope, storage, navigation)

func _confirm_saved_publication(id: String, loaded: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int, notice: AcceptDialog) -> void:
	await _feature_resource("res://core/features/editor.gd").run_confirm_saved_publication(self ,id, loaded, original_scope, storage, navigation, notice)

func _open_published_track(receipt: Dictionary) -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_open_published_track(self ,receipt)

func _prepare_creator_test(source: Dictionary, prepared: NativeTrack = null) -> bool:
	return await _feature_resource("res://core/features/editor.gd").run_prepare_creator_test(self ,source, prepared)

func _lifecycle_changed() -> void:
	if is_instance_valid(publication_notification): publication_notification.set_entries(lifecycle.publication_notifications())
	_remember_publication_news()
	if records != null and cloud != null: cloud.migrate_record_identities(records)
	if is_instance_valid(publish_button) and not document.is_empty():
		publish_button.disabled = not lifecycle.ready_to_publish(document)
		publish_button.tooltip_text = lifecycle.caption(document)
		if is_instance_valid(editor_status): editor_status.text = lifecycle.caption(document)

func _remember_publication_news() -> void:
	if online != null and is_instance_valid(online.client.news) and lifecycle != null:
		online.client.news.remember_publications(lifecycle.publication_receipts())

func _acknowledge_publication_dialog(source: Dictionary, owner_scope: String) -> void:
	if lifecycle.scope() != owner_scope: return
	var job: Dictionary = lifecycle.status_for(source)
	if job.get("state") in ["finishing","published"]:
		lifecycle.acknowledge_publication(str(job.get("receipt",{}).get("version_id","")),owner_scope)

func _dismiss_publication_notification(item: Dictionary) -> void:
	if not lifecycle.acknowledge_publication(str(item.version_id),str(item.scope)) and lifecycle.scope() == item.scope:
		_notice(lifecycle.last_error)

func _view_publication_notification(item: Dictionary) -> void:
	_feature_resource("res://core/features/editor.gd").run_view_publication_notification(self ,item)

func _confirm_delete_draft(id: String, title: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_confirm_delete_draft(self ,id, title)

func _load_track_dialog() -> void:
	_feature_resource("res://core/features/editor.gd").run_load_track_dialog(self)

func _load_saved_document(id: String) -> void:
	if not _feature_resources.has("res://core/features/editor.gd") and not await _prepare_feature_entry("res://core/features/editor.gd"): return
	_feature_resource("res://core/features/editor.gd").run_load_saved_document(self ,id)

func _editor_track_preview() -> NativeTrack:
	return _feature_resource("res://core/features/editor.gd").run_editor_track_preview(self)

func _compile_editor_preview(source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	if _editor_module == null: _feature_resource("res://core/features/editor.gd")
	return _editor_module.run_compile_editor_preview(self,source,cancelled)

func _compile_editor_preview_uncached(source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	if _editor_module == null: _feature_resource("res://core/features/editor.gd")
	return _editor_module.run_compile_editor_preview_uncached(self,source,cancelled)

func _compile_editor_with_masks(source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	if _editor_module == null: _feature_resource("res://core/features/editor.gd")
	return _editor_module.run_compile_editor_with_masks(self,source,cancelled)

func _confirm_delete_track(id: String, title: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_confirm_delete_track(self ,id, title)

func _delete_user_track(id: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_delete_user_track(self ,id)

func _choose_object(kind: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_choose_object(self ,kind)

func _container_colour(color: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_container_colour(self ,color)

func _open_object_population() -> void:
	_feature_resource("res://core/features/editor.gd").run_open_object_population(self)

func _close_object_population(applied: bool) -> void:
	_feature_resource("res://core/features/editor.gd").run_close_object_population(self ,applied)

func _object_placement(value: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_object_placement(self ,value)

func _choose_hazard(kind: String) -> void:
	_feature_resource("res://core/features/editor.gd").run_choose_hazard(self ,kind)

const CREATION_BIOME_DESCRIPTIONS: Dictionary = {
	"pine":"Sunlit grass and asphalt make a versatile setting for your track. Add trees, buildings and other objects to make it your own.",
	"desert":"Build across sunlit sand with compacted sand roads and drifting grains. Add rocks or ancient stone structures to shape the scene.",
	"night_city":"Dark asphalt and concrete set the scene after dusk. Light your track with street lamps and add industrial objects to make it your own.",
	"winter":"Snowy ground and icy roads make for slippery racing. Add snow-covered trees and winter objects to build your frozen circuit.",
	"storm":"Rain falls over wet roads under a dark sky. Reduced road grip makes every corner more demanding."
}

func _choose_biome(parent: VBoxContainer = null, preview: bool = false) -> void:
	_feature_resource("res://core/features/creator.gd").run_choose_biome(self ,parent, preview)

func _size_creation_biome_description(description: Label) -> void:
	_feature_resource("res://core/features/creator.gd").run_size_creation_biome_description(self ,description)

func _preview_creation_biome(biome: String) -> void:
	_feature_resource("res://core/features/creator.gd").run_preview_creation_biome(self ,biome)

func _update_creation_biome(parent: VBoxContainer, biome: String) -> void:
	_feature_resource("res://core/features/creator.gd").run_update_creation_biome(self ,parent, biome)

func _select_creation_biome(biome: String) -> void:
	_feature_resource("res://core/features/creator.gd").run_select_creation_biome(self ,biome)

func _notify_creation_slots(id: String) -> void:
	await _feature_resource("res://core/features/creator.gd").run_notify_creation_slots(self ,id)

func _rename_track() -> void:
	_feature_resource("res://core/features/editor.gd").run_rename_track(self)

func _telemetry_observe(name: String, properties: Dictionary = {}, once_key: String = "") -> void:
	if name in ["race_attempt","race_started","race_finished","race_abandoned","race_retried"] and (returning_to_editor or (is_instance_valid(game) and bool(game.get("attempt_practice")))): return
	if product_telemetry != null: product_telemetry.observe(name,properties,once_key)

func _connect_store_telemetry(store: Node) -> void:
	store.purchase_requested.connect(func(product_id: String) -> void:
		if screen == "store" and store.is_visible_in_tree():
			_telemetry_observe("purchase_requested",{"product_id":product_id}))

func _telemetry_track_properties(track: NativeTrack, reason: String = "") -> Dictionary:
	if track == null or str(track.metadata.get("cloud_version","")).length() != 36:
		return {"reason":reason} if not reason.is_empty() else {}
	var value: Dictionary = {"car_id":str(game.get("vehicle_id")) if is_instance_valid(game) else VehicleCatalog.selected,"mode":"creator" if returning_to_editor else "challenge" if challenge_racing or challenge_practice else "rivalry" if rivalry_racing else "free"}
	if track != null:
		var version: String = str(track.metadata.get("cloud_version",""))
		if version.length() == 36: value.track_version_id = version
		value.biome = str(track.metadata.get("theme","pine"))
	var ticket: String = str(cloud_ticket.get("ticket_id",""))
	if ticket.length() == 36: value.ticket_id = ticket
	if not reason.is_empty(): value.reason = reason
	return value

func _telemetry_begin_attempt(track: NativeTrack) -> void:
	if game_configuration != null: game_configuration.set_transport_allowed(false)
	_telemetry_race_started = false
	_telemetry_race_finished = false
	if product_telemetry != null: product_telemetry.set_transport_allowed(false)
	if client_quality != null:
		client_quality.start_race(track,cloud_ticket,not returning_to_editor and is_instance_valid(game) and not bool(game.get("attempt_practice")))
	_telemetry_observe("race_attempt",_telemetry_track_properties(track))

func _telemetry_observe_activity() -> void:
	if product_telemetry == null: return
	var racing: bool = is_instance_valid(game) and not _telemetry_race_finished
	if game_configuration != null: game_configuration.set_transport_allowed(not racing and not cloud_starting and not is_instance_valid(race_loading))
	product_telemetry.set_transport_allowed(not racing and not cloud_starting and not is_instance_valid(race_loading))
	if racing:
		# A coarse observer reads presentation state once/second. No simulation hook.
		var simulation: VehicleSimulation = game.get("sim")
		if not _telemetry_race_started and simulation != null and simulation.state.tick > 0:
			_telemetry_race_started = true
			_telemetry_observe("race_started",_telemetry_track_properties(game.get("native_track")))
		return
	if not is_instance_valid(root_ui) or not root_ui.visible or not is_instance_valid(content): return
	# Settled current content only; prepared neighbours and outgoing pages do not
	# establish an offer even when their render commands are warmed offscreen.
	if is_instance_valid(menu_body) and absf(menu_body.position.x) > 1.0: return
	if screen == "garage":
		var garage: Control = content.find_child("GaragePage",true,false) as Control
		if garage != null:
			for exposure: Dictionary in garage.telemetry_exposures():
				_telemetry_observe("car_exposed",exposure,str(_navigation_generation)+"/garage/"+str(exposure.car_id))
		return
	if screen == "store":
		var store: Node = content.find_child("StorePage",true,false)
		if store != null:
			if game_configuration != null and not store.telemetry_exposures().is_empty(): game_configuration.menu_applied("store",true)
			for product: String in store.telemetry_exposures():
				_telemetry_observe("offer_exposed",{"product_id":product},str(_navigation_generation)+"/"+product)
		return
	if screen != "tracks": return
	var browser: Control = content.find_child("TrackBrowser",true,false) as Control
	if browser == null: return
	for exposure: Dictionary in browser.telemetry_exposures():
		var properties: Dictionary = {"track_version_id":str(exposure.entry.get("version_id","")),"car_id":VehicleCatalog.selected,"biome":str(exposure.entry.get("theme","")),"mode":"free","position":int(exposure.position)}
		_telemetry_observe("track_exposed",properties,str(_navigation_generation)+"/"+str(properties.track_version_id)+"/"+str(properties.car_id))

func _select_header_vehicle(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size() or VehicleCatalog.IDS[index] == VehicleCatalog.selected: return
	var return_to_rivalry: bool = screen == "rivalry" and rivalry_section == "detail"
	if return_to_rivalry: rivalry_section = "overview"
	_select_vehicle(index)
	if return_to_rivalry: _rivalry()
	if is_instance_valid(_retained_garage) and _retained_garage.records == records and _retained_garage.is_visible_in_tree():
		_retained_garage.refresh_selection()
	if not is_instance_valid(content): return
	var daily_page: Node = content.find_child("TrackOfDayPage",true,false)
	if daily_page != null: daily_page.activate()
	var browser: Control = content.find_child("TrackBrowser",true,false) as Control
	if browser != null:
		browser._show_detail()
		browser._warm_visible_comparisons(maxi(0,int(browser.gallery.scroll_horizontal/browser.tile_stride)-1))

func _select_vehicle(index: int) -> void:
	var chosen: String = VehicleCatalog.IDS[clampi(index,0,VehicleCatalog.IDS.size()-1)]
	_telemetry_observe("car_selected",{"car_id":chosen})
	records.settings.selected_car = chosen
	var saved: Error = records.save_records()
	VehicleCatalog.selected = chosen
	_refresh_account_car()
	_prefetch_rivalry()
	_prime_free_race_comparisons()
	if saved != OK: _notice("Car selected for this session. Could not save preference: " + error_string(saved))

func _build_surface_toolbar() -> void:
	_feature_resource("res://core/features/editor.gd").run_build_surface_toolbar(self)

func _surface_point_controls() -> void:
	_feature_resource("res://core/features/editor.gd").run_surface_point_controls(self)


# Feature scripts are loaded on first use, never during shell parsing.
var _feature_resources: Dictionary = {}
var feature_load_ms: Dictionary = {}
var _editor_module: Node
func _feature_resource(path: String) -> Object:
	if not _feature_resources.has(path):
		var began: int = Time.get_ticks_usec()
		_install_feature_resource(path,load(path))
		feature_load_ms[path] = (Time.get_ticks_usec()-began)/1000.0
	return _feature_resources.get(path)

func _install_feature_resource(path: String, resource: Resource) -> Object:
	if resource == null: return null
	if _feature_resources.has(path): return _feature_resources[path]
	if path.begins_with("res://core/features/"):
		var controller: Node = resource.new()
		controller.name = "AppFeature_"+path.get_file().get_basename()
		_feature_resources[path] = controller
		add_child(controller)
	else: _feature_resources[path] = resource
	if path == "res://core/features/editor.gd": _editor_module = _feature_resources[path]
	if path in ["res://core/features/editor.gd","res://core/features/race.gd","res://core/features/garage.gd"] and editor_memory.has_method("activate"):
		editor_memory.activate()
	return _feature_resources[path]

var _feature_loading: CanvasLayer
var _feature_entry_generation: int = 0
var _feature_load_pending: int = 0
var _feature_focus_owner: WeakRef
var _feature_focus_root: WeakRef
var _feature_focus_behavior: int = Control.FOCUS_BEHAVIOR_INHERITED

func _await_feature_resource(path: String,current: Callable) -> Object:
	if not current.call(): return null
	if _feature_resources.has(path): return _feature_resources[path]
	# Heavy GDScript graphs remain serialized on the main thread. The pinned
	# engine leaks static objects under threaded initialization; a concurrent
	# foreground dependency load can also deadlock. Draw feedback first, then
	# yield between the native policy and requested feature resource stages.
	var paths: Array[String] = []
	if path in ["res://core/features/editor.gd","res://core/features/race.gd","res://core/features/garage.gd"] and editor_memory._policy == null:
		paths.append("res://editor/editor_memory.gd")
	paths.append(path)
	_feature_load_pending += 1
	var resource: Object
	for requested: String in paths:
		await _present_race_loading()
		if not current.call():
			_feature_load_pending -= 1
			return null
		resource = _feature_resource(requested)
		if resource == null: break
	_feature_load_pending -= 1
	return resource

func _prepare_feature_entry(path: String) -> bool:
	_feature_entry_generation += 1
	var generation: int = _feature_entry_generation
	var navigation: int = _navigation_generation
	var owner: LocalRecords = records
	var storage: TrackLibrary = library
	var starting_screen: String = screen
	var document_id: String = str(document.get("id",""))
	var starting_game_id: int = game.get_instance_id() if is_instance_valid(game) else 0
	_close_feature_loading()
	if is_instance_valid(root_ui):
		_feature_focus_root = weakref(root_ui)
		_feature_focus_behavior = root_ui.focus_behavior_recursive
		var focused: Control = get_viewport().gui_get_focus_owner()
		_feature_focus_owner = weakref(focused) if focused != null else null
		root_ui.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_feature_loading = preload("res://ui/feature_loading.gd").new()
	_feature_loading.cancelled.connect(func() -> void:
		_feature_entry_generation += 1
		_close_feature_loading())
	add_child(_feature_loading)
	var cover: CanvasLayer = _feature_loading
	var cover_id: int = cover.get_instance_id()
	var current: Callable = func() -> bool:
		return is_inside_tree() and not is_queued_for_deletion() and generation == _feature_entry_generation and navigation == _navigation_generation and owner == records and storage == library and starting_screen == screen and document_id == str(document.get("id","")) and is_instance_valid(_feature_loading) and _feature_loading.get_instance_id() == cover_id and (game.get_instance_id() if is_instance_valid(game) else 0) == starting_game_id and not is_instance_valid(race_loading)
	# The same bounded native draw fence used by race entry works without loading
	# any race controller. The headless path still yields one process frame.
	await _present_race_loading()
	var resource: Object = await _await_feature_resource(path,current) if current.call() else null
	var valid: bool = current.call()
	if is_instance_valid(cover) and _feature_loading == cover: _close_feature_loading()
	if valid and resource == null: _notice("Something went wrong")
	return valid and resource != null

func _close_feature_loading() -> void:
	if not is_instance_valid(_feature_loading): return
	remove_child(_feature_loading)
	_feature_loading.queue_free()
	_feature_loading = null
	var previous_root: Control = _feature_focus_root.get_ref() if _feature_focus_root != null else null
	if is_instance_valid(previous_root): previous_root.focus_behavior_recursive = _feature_focus_behavior
	var focused: Control = _feature_focus_owner.get_ref() if _feature_focus_owner != null else null
	if is_instance_valid(focused) and is_instance_valid(root_ui) and root_ui.is_ancestor_of(focused) and focused.is_visible_in_tree(): focused.grab_focus()
	_feature_focus_owner = null
	_feature_focus_root = null
	_wake_optional_work.call_deferred()

var _initial_menu_presented: bool = false
func _initial_menu_drawn() -> void:
	_initial_menu_presented = true
