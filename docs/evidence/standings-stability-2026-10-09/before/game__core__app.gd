extends Node
## Local navigation and editor composition. Racing simulation stays in Game.

const GAME_SCENE: PackedScene = preload("res://core/game.tscn")
const AccountController = preload("res://backend/account_controller.gd")
const RaceLoading = preload("res://ui/race_loading.gd")
var race_loading: RaceLoading
var BUILTIN_IDS: Array[String] = BuiltinTracks.ids()
var screen: String = "tracks"
var menu_open_costs: Dictionary = {}
var root_ui: Control
var menu_body: Control
var menu_body_slot: Control
var menu_body_backgrounds: Array[Control] = []
var outgoing_menu_page: Control
var menu_neighbors: Dictionary = {}
var menu_neighbor_direction: int = 0
var returning_menu_neighbor: Dictionary = {}
const MENU_PAGE_GAP: float = 64.0
var menu_page_motion: Tween
var race_mode_transition_rail: RaceModeRail
const RACE_MODE_PAGES: Array[String] = ["rivalry", "tracks", "challenges"]
var _race_mode_request: int = 0
var _rivalry_entry_pending: bool = false
var menu_edge_motion: Tween
var menu_drag_offset: float = 0.0
var content: VBoxContainer
var menu_layer: CanvasLayer
var game: Node
var selected_track: NativeTrack
var library := TrackLibrary.new()
var document: Dictionary = {}
var history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var canvas: EditorCanvas
var editor_status: Label
var test_button: Button
var publish_button: Button
var share_button: Button
var capture_path: String = ""
var returning_to_editor: bool = false
var ui_touch_scale: float = 1.0
var ui_left_handed: bool = false
var records := LocalRecords.new()
var editor_view: Dictionary = {}
var editor_mode_buttons: Dictionary = {}
var editor_tools_open: bool = false
var editor_tools_panel: PanelContainer
var editor_map_panel: PanelContainer
var editor_undo: Button
var editor_redo: Button
var editor_world: EditorWorld
var object_browser_state: Dictionary = {}
var object_browser: ObjectBrowser
var editor_palette: Control
var editor_context: HBoxContainer
var surface_toolbar: PanelContainer
var surface_actions: HBoxContainer
var editor_issue_button: Button
var editor_issues: Array[Dictionary] = []
var editor_geometry: String = ""
var editor_inspector: VBoxContainer
var browser_state: Dictionary = {}
var discovery_provider := TrackDiscoveryProvider.new()
var track_catalog: TrackCatalog
var pending_menu_notice: String = ""
var editor_preview_thread: Thread
var editor_preview_document: Dictionary = {}
var editor_raster_cache: Dictionary = {"enabled":true}
var editor_compiled_cache: Array[Dictionary] = []
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
var editor_gesture_history: Array[Dictionary] = []
var editor_gesture_redo: Array[Dictionary] = []
var editor_issue_cursor: int = -1
var editor_hint_generation: int = 0
var editor_wip_saved: String = ""
var editor_retry_original: bool = false
var online: AccountController
var account_button: Button
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
var cloud_publish_version: String = ""
var cloud_starting: bool = false
var _result_game_id: int = 0
var _navigation_generation: int = 0
var _profile_draft_recovery: Dictionary = {}
var rivalry: Node
var race_area_mode: String = "free"
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
var challenge_seed: Dictionary = {}
var challenge_invitation: String = ""
var challenge_queued_invitation: String = ""
var challenge_links: Node
var challenge_refresh_ticks: int = 0

func _exit_tree() -> void:
	_finish_preview_thread()

func _finish_preview_thread() -> void:
	if editor_preview_thread != null:
		editor_preview_thread.wait_to_finish()
		editor_preview_thread = null
	editor_preview_document = {}

func _process(_delta: float) -> void:
	if is_instance_valid(editor_loading) and is_instance_valid(canvas):
		editor_loading.visible = editor_preview_thread != null or canvas.native_preview == null or editor_world._building
	if editor_preview_thread == null or editor_preview_thread.is_alive(): return
	# Finish the detailed scene between gestures, never underneath a finger.
	if is_instance_valid(canvas) and canvas.active_pointer != -99: return
	var result: NativeTrack = editor_preview_thread.wait_to_finish()
	editor_preview_thread = null
	if result != null and not editor_pending_road_bake.is_empty() and result.metadata.get("creator_document",{}) == editor_pending_road_bake:
		NativeTrackVisual.request_saved_road_bake.call_deferred(result)
		editor_pending_road_bake.clear()
	if not is_instance_valid(canvas) or screen != "create": return
	if document != editor_preview_document:
		_queue_editor_preview()
		return
	editor_preview_document = {}
	if result != null: canvas.show_native(result)
	_update_editor_issues()

func _queue_editor_preview() -> void:
	if editor_preview_thread != null: return
	editor_preview_document = document.duplicate(true)
	editor_preview_thread = Thread.new()
	var error: Error = editor_preview_thread.start(_compile_editor_preview.bind(editor_preview_document))
	if error != OK:
		editor_preview_thread = null
		var track: NativeTrack = _compile_editor_preview(editor_preview_document)
		editor_preview_document = {}
		if track != null: canvas.show_native(track)
		_update_editor_issues()

func _objects_only_edit() -> bool:
	if not is_instance_valid(canvas) or canvas.native_preview == null: return false
	var previous: Dictionary = canvas.native_preview.metadata.get("creator_document",{}).duplicate(true)
	var current: Dictionary = document.duplicate(true)
	for key: String in ["objects","hidden_scenery"]:
		previous.erase(key)
		current.erase(key)
	return previous == current


func _ready() -> void:
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
	profile_root = records.path.get_base_dir()
	records.load_records()
	GameSoundtrack.instance().apply_settings(records.settings)
	GameSoundtrack.instance().show_menu()
	library.owner_name = "Guest"
	online = AccountController.new()
	online.client.session_path = records.path.get_base_dir().path_join("account_session.cfg")
	if OS.is_debug_build() and OS.get_environment("BMT_PURCHASE_LAB") == "true":
		online.client.session_path = records.path.get_base_dir().path_join("purchase_lab_session.cfg")
	add_child(online)
	cloud = preload("res://backend/cloud_tracks.gd").new()
	cloud.client = online.client
	cloud.root_override = cloud_root_override
	add_child(cloud)
	cloud.load_cached()
	rivalry = preload("res://backend/weekly_rivalry_client.gd").new()
	rivalry.client = online.client
	add_child(rivalry)
	rivalry.changed.connect(_rivalry_changed)
	challenges = ChallengesClient.new()
	challenges.client = online.client
	challenges.cloud = cloud
	add_child(challenges)
	challenges.changed.connect(_challenges_changed)
	challenge_links = preload("res://platform/challenge_links.gd").new()
	add_child(challenge_links)
	challenge_links.invitation_received.connect(_receive_challenge)
	var rivalry_timer := Timer.new()
	rivalry_timer.wait_time = 0.5
	rivalry_timer.autostart = true
	rivalry_timer.timeout.connect(func() -> void:
		if challenges != null: challenges.poll_result()
		if screen == "challenges" and not is_instance_valid(game) and not challenges.busy:
			challenge_refresh_ticks += 1
			if challenge_refresh_ticks >= 60:
				challenge_refresh_ticks = 0
				challenges.refresh()
		if rivalry.busy or rivalry.model.sample: return
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
	lifecycle.legacy_directories = _legacy_track_directories()
	add_child(lifecycle)
	lifecycle.changed.connect(_lifecycle_changed)
	var sync_timer := Timer.new()
	sync_timer.wait_time = 2.0
	sync_timer.autostart = true
	sync_timer.timeout.connect(func() -> void:
		if not online.busy and not cloud_starting:
			cloud.flush_outbox()
			if not is_instance_valid(game): lifecycle.process_jobs())
	add_child(sync_timer)
	online.changed.connect(_account_changed)
	VehicleCatalog.selected = VehicleCatalog.valid_id(str(records.settings.get("selected_car", "compact")))
	ui_touch_scale = float(records.settings.get("touch_scale", 1.0))
	ui_left_handed = bool(records.settings.get("left_handed", false))
	selected_track = NativeTrack.read("res://resources/tracks/" + BUILTIN_IDS[0] + ".json")
	var last: String = str(records.settings.get("last_track",""))
	if last in BUILTIN_IDS:
		selected_track = NativeTrack.read("res://resources/tracks/"+last+".json")
	elif last.begins_with("creator_"):
		var saved: Dictionary = library.load_document(last.trim_prefix("creator_"))
		if not saved.is_empty():
			var compiled: NativeTrack = TrackCompiler.compile(saved)
			if compiled != null: selected_track = compiled
	elif last.begins_with("cloud_"): _restore_cloud_selection(last)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	if not capture_path.is_empty():
		_show_screen(capture_screen)
	else:
		var restoring: bool = online.client.has_saved_session()
		_show_screen("restoring" if restoring else "account")
		await online.start_session()
		if restoring:
			_show_screen("tracks" if online.client.signed_in() and not online.needs_username() else "account")
		elif screen == "account" and online.client.signed_in() and not online.needs_username():
			_show_screen("tracks")
	startup_complete = true
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
	_close_race_loading()
	if challenge_racing and challenge_result_view and next != "challenges" and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		challenge_racing = false
		challenge_result_view = false
	if not is_instance_valid(game): GameSoundtrack.instance().show_menu()
	if rivalry_racing and rivalry_section in ["race_results", "result"] and next != "rivalry" and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		rivalry_racing = false
	_navigation_generation += 1
	_cancel_rivalry_entry()
	# Home was retired; normalize old callers and saved/debug launch arguments to Race.
	if next == "play": next = "tracks"
	var drag_offset: float = menu_body.position.x if is_instance_valid(menu_body) and not is_zero_approx(menu_drag_offset) else 0.0
	_stop_menu_page_motion()
	menu_neighbors.clear()
	menu_neighbor_direction = 0
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var previous_page: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges"] else screen
	var next_page: String = "biome" if next == "drafts" else "tracks" if next in ["rivalry","challenges"] else next
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
		object_browser_state={"category":object_browser.category,"recent":object_browser.recent.duplicate(),"current":object_browser.current,"placement":object_browser.placement,"stamp_scale":object_browser.stamp_scale}
	if is_instance_valid(canvas):
		if canvas.document.get("id","") == document.get("id",""): _stash_pending_tool()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
	screen = next
	canvas = null
	editor_status = null
	test_button = null
	share_button = null
	if is_instance_valid(root_ui):
		if slide:
			outgoing_menu_page = menu_body
			outgoing_menu_page.position.x = drag_offset
			outgoing_menu_page.get_parent().remove_child(outgoing_menu_page)
			outgoing_menu_page.process_mode = Node.PROCESS_MODE_DISABLED
			_disable_outgoing_menu(outgoing_menu_page)
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
	if screen in ["tracks", "rivalry", "challenges", "biome", "drafts", "garage", "store"]:
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
		var loading := MenuStyle.label("Loading...", 20, true)
		loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(loading)
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
	if screen == "garage":
		var stage := MenuStage.new()
		stage.setting = str(selected_track.metadata.get("theme","pine"))
		stage.garage = screen == "garage"
		MenuStyle.fill(stage)
		root_ui.add_child(stage)
		scenery.append(stage)
		var scrim := MenuScrim.new()
		MenuStyle.fill(scrim)
		root_ui.add_child(scrim)
		scenery.append(scrim)
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
	nav.add_child(MenuBrand.new())
	var tabs := HBoxContainer.new()
	tabs.name = "MenuNavigation"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 4)
	nav.add_child(tabs)
	for item: Array in [["tracks","RACE"],["create","CREATE"],["garage","GARAGE"],["store","STORE"]]:
		var id: String = item[0]
		var button: Button = MenuStyle.tab(item[1], _new_document if id == "create" else _open_race_area if id == "tracks" else _navigate_menu_page.bind(id), screen == id or (id == "tracks" and screen in ["rivalry","challenges"]) or (id == "create" and screen in ["biome","drafts"]))
		button.name = "Tab_" + id
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	account_button = MenuStyle.button(online.player_name() if online.client.signed_in() else "Guest", _show_screen.bind("profile"))
	account_button.name = "MenuAccount"
	account_button.tooltip_text = "Profile"
	account_button.icon = MenuIcon.texture("avatar")
	account_button.add_theme_constant_override("icon_max_width", 38)
	account_button.add_theme_constant_override("h_separation", 12)
	account_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	account_button.custom_minimum_size = Vector2(190, 54)
	var profile_style: StyleBoxFlat = MenuStyle.box(MenuStyle.PANEL)
	profile_style.content_margin_right = 38
	if screen == "profile":
		profile_style.bg_color = Color(1, 1, 1, 0.07)
		account_button.add_theme_color_override("font_color", MenuStyle.ACCENT)
	account_button.add_theme_stylebox_override("normal", profile_style)
	for state: String in ["hover", "pressed", "disabled", "focus"]:
		var state_style: StyleBoxFlat = root_ui.theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		state_style.content_margin_right = 38
		account_button.add_theme_stylebox_override(state, state_style)
	var chevron := TextureRect.new()
	chevron.texture = MenuIcon.texture("chevron")
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chevron.position = Vector2(-30, -10)
	chevron.size = Vector2(20, 20)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	account_button.add_child(chevron)
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
	if screen in ["tracks", "rivalry", "challenges", "biome", "drafts", "garage", "store"]:
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
		"rivalry": _rivalry()
		"challenges": _challenges()
		"create": _editor()
		"garage": _garage()
		"settings": _settings()
		"store":
			var store := preload("res://ui/store_page.gd").new()
			store.client = online.client
			store.sign_in_requested.connect(_open_account)
			content.add_child(store)
		"profile":
			content.add_child(MenuStyle.label("PROFILE",36))
			var manage := MenuStyle.button("Manage account" if online.client.signed_in() else "Sign in",_open_account)
			manage.name = "ManageAccount"
			content.add_child(manage)
			if online.client.signed_in(): content.add_child(MenuStyle.button("Race uploads",cloud.show_uploads.bind(root_ui)))
		"account": _account()
		_: _tracks()
	var page_swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	# _input visits children in reverse order: settle before the carousel hit-tests.
	if page_swipe != null: root_ui.move_child(page_swipe, root_ui.get_child_count() - 1)
	if vertical_slide: _slide_race_mode_page(slide_direction,rail_rect,race_slide_height)
	elif slide: _slide_menu_page(slide_direction, drag_offset)
	else: _prepare_menu_neighbors.call_deferred(_navigation_generation)

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

func _disable_outgoing_menu(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	if node is CanvasLayer: node.hide()
	for child: Node in node.get_children(): _disable_outgoing_menu(child)

func _stop_menu_page_motion() -> void:
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

func _request_race_mode(mode: String) -> void:
	if mode == "rivalry": _open_rivalry()
	elif mode == "challenges": _open_challenges()
	elif mode == "free": _open_free_race()

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
	for neighbor_direction: int in menu_neighbors:
		menu_neighbors[neighbor_direction].body.visible = neighbor_direction == direction
	if (screen in ["tracks", "rivalry", "challenges"] and distance > 0.0) or (screen == "store" and distance < 0.0):
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
	# Warm actual page controls between gestures, after the viewport has laid out.
	await get_tree().process_frame
	if generation != _navigation_generation or not is_instance_valid(menu_body_slot): return
	if menu_page_motion != null: return
	var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	if swipe == null: return
	if swipe.pointer != -1:
		_prepare_menu_neighbors.call_deferred(generation)
		return
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var current: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges"] else screen
	var index: int = pages.find(current)
	if index < 0: return
	# Keep all primary pages warm too, for another swipe immediately after
	# commitment. These are shared textures and inactive controls, not extra apps.
	for destination: int in range(pages.size()):
		var direction: int = destination - index
		if direction == 0: continue
		if menu_neighbors.has(direction): continue
		var next: String = pages[destination]
		if next == "tracks" and race_area_mode == "rivalry": next = "rivalry"
		elif next == "tracks" and race_area_mode == "challenges": next = "challenges"
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
		if next == "garage":
			var stage := MenuStage.new()
			stage.setting = str(selected_track.metadata.get("theme","pine"))
			stage.garage = true
			body.add_child(stage)
			backgrounds.append(stage)
			var scrim := MenuScrim.new()
			body.add_child(scrim)
			backgrounds.append(scrim)
		var column := VBoxContainer.new()
		MenuStyle.fill(column)
		body.add_child(column)
		match next:
			"tracks": _tracks(column, true)
			"rivalry": _rivalry(column)
			"challenges": _challenges(column)
			"biome": _choose_biome(column, true)
			"garage": _garage(column)
			"store":
				var store := preload("res://ui/store_page.gd").new()
				store.client = online.client
				store.sign_in_requested.connect(_open_account)
				column.add_child(store)
		_set_menu_preview_input(body, true)
		menu_neighbors[direction] = {"body":body,"content":column,"backgrounds":backgrounds,"screen":next}
		body.position.x = menu_body_slot.size.x * direction
		_layout_menu_body()
	_hide_warmed_menu_neighbors.call_deferred(generation)

func _hide_warmed_menu_neighbors(generation: int) -> void:
	# Let CanvasItems prepare draw commands and font glyphs once, offscreen and
	# clipped, so revealing them does not defer that work to the finger's first move.
	await get_tree().process_frame
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
		control.set_meta("page_mouse_filter",control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif not disabled and control.has_meta("page_mouse_filter"):
		control.mouse_filter = control.get_meta("page_mouse_filter")
		control.remove_meta("page_mouse_filter")

func _commit_menu_neighbor(direction: int) -> void:
	var neighbor: Dictionary = menu_neighbors[direction]
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
	var outgoing_browser: TrackBrowser = outgoing_menu_page.find_child("TrackBrowser", true, false)
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
	if rivalry_racing and rivalry_section in ["race_results", "result"] and neighbor.screen != "rivalry" and is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
		rivalry_racing = false
	if challenge_racing and challenge_result_view and neighbor.screen != "challenges" and is_instance_valid(game):
		_clear_challenge_game()
		challenge_result_view = false
	screen = neighbor.screen
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
	var browser: TrackBrowser = menu_body.find_child("TrackBrowser", true, false)
	if browser != null:
		browser_state = browser.state
	_slide_menu_page(signi(direction), offset)

func _refresh_cached_menu_page(destination: String, column: VBoxContainer) -> void:
	if destination == "rivalry":
		_rivalry(column)
	elif destination == "garage":
		var circuit: MenuFeature = column.find_child("GarageCircuit",true,false)
		if circuit != null:
			var title: String = track_title(selected_track).to_upper()+" · 5 LAPS"
			if circuit.heading != title:
				circuit.heading = title
				circuit.tooltip_text = title+". "+circuit.description
				circuit.queue_redraw()
	elif destination == "biome" and str(column.get_meta("biome_theme","")) != str(document.get("theme",TrackDocument.THEMES[0])):
		for child: Node in column.get_children():
			column.remove_child(child)
			child.queue_free()
		_choose_biome(column,true)

func _navigate_menu_page(next: String) -> void:
	# Explicit refreshes still use _show_screen. User navigation promotes the same
	# already warmed controls as swipes, avoiding shell/layout rebuilding on taps.
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
	if menu_page_motion != null: _finish_menu_page_slide()
	if menu_edge_motion != null: _stop_menu_edge_motion()

func _activate_menu_page(generation: int) -> void:
	if generation != _navigation_generation or not is_instance_valid(menu_body): return
	var swipe: Node = root_ui.get_node_or_null("MenuPageSwipe")
	if menu_page_motion != null or (swipe != null and swipe.pointer != -1):
		await get_tree().process_frame
		if is_inside_tree(): _activate_menu_page.call_deferred(generation)
		return
	var browser: TrackBrowser = menu_body.find_child("TrackBrowser", true, false)
	if browser != null and browser.page_preview:
		browser.activate_page()
	if screen == "rivalry" and not rivalry.model.sample and online.client.signed_in(): rivalry.refresh()
	if screen == "challenges": challenges.refresh()

func _account_changed() -> void:
	var previous_profile: String = active_profile
	_select_player_storage()
	if not challenge_invitation.is_empty() and not is_instance_valid(game):
		_open_challenges()
		challenges.open(challenge_invitation)
	if lifecycle != null:
		lifecycle.library = library
		lifecycle.records = records
		lifecycle.legacy_directories = _legacy_track_directories()
		for item: Dictionary in library.editable_entries(): lifecycle.defer_sync(item.document)
	if is_instance_valid(account_button):
		account_button.text = online.player_name() if online.client.signed_in() else "Guest"
	if previous_profile != active_profile and startup_complete and not is_instance_valid(game) and is_instance_valid(root_ui):
		_show_screen("account" if not online.client.signed_in() else "drafts" if screen == "create" else screen)
	_prefetch_rivalry()

func _legacy_track_directories() -> Array[String]:
	# Normal recovery must never inspect or clean another profile's drafts.
	return [library.directory]

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
	selected_track = NativeTrack.read("res://resources/tracks/" + BUILTIN_IDS[0] + ".json")
	var last: String = str(records.settings.get("last_track", ""))
	if last in BUILTIN_IDS:
		selected_track = NativeTrack.read("res://resources/tracks/" + last + ".json")
	elif last.begins_with("creator_"):
		var saved: Dictionary = library.load_document(last.trim_prefix("creator_"))
		if not saved.is_empty():
			var track: NativeTrack = TrackCompiler.compile(saved)
			if track != null: selected_track = track
	elif last.begins_with("cloud_"): _restore_cloud_selection(last)
	VehicleCatalog.selected = VehicleCatalog.valid_id(str(records.settings.get("selected_car", "compact")))
	ui_touch_scale = float(records.settings.get("touch_scale", 1.0))
	ui_left_handed = bool(records.settings.get("left_handed", false))

func _stamp_creator() -> void:
	if not document.is_empty(): document["creator"] = library.owner_name

func _restore_cloud_selection(identity: String) -> void:
	if cloud == null: return
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog,null,[identity])
	for entry: Dictionary in catalog.entries:
		if entry.id == identity or "cloud_"+str(entry.version_id) == identity:
			var track: NativeTrack = catalog.resolve(entry)
			if track != null:
				selected_track = track
				records.settings.last_track = entry.id
				records.save_records()
			return

func _open_account() -> void:
	_show_screen("account")
	online.refresh_options()

func _account() -> void:
	var background := preload("res://ui/account_backdrop.gd").new()
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	root_ui.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var brand_space := Control.new()
	brand_space.custom_minimum_size.y = 94
	column.add_child(brand_space)
	var brand := MenuBrand.new()
	brand.scale = Vector2(1.5, 1.5)
	brand_space.add_child(brand)
	brand_space.resized.connect(func() -> void: brand.position = Vector2((brand_space.size.x - 294) * 0.5, 0))
	var panel := preload("res://ui/account_panel.gd").new()
	panel.account = online
	panel.custom_minimum_size.x = 520
	panel.continue_requested.connect(_show_screen.bind("tracks"))
	column.add_child(panel)

func _heading(eyebrow: String, title: String, parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	parent.add_child(MenuStyle.label(eyebrow, 15, true))
	parent.add_child(MenuStyle.label(title, 32))

func _menu_card(parent: HBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 400
	panel.add_theme_stylebox_override("panel",MenuStyle.card())
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	panel.add_child(body)
	return body

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
	if track_catalog == null:
		track_catalog = TrackCatalog.new(library)
		if cloud != null: return # Race uses backend publications and their caches.
		if library.directory != guest_library.directory:
			track_catalog.shared_directories.append(guest_library.directory.path_join(".published"))
		var profiles := DirAccess.open(profile_root.path_join("players"))
		if profiles != null:
			for profile: String in profiles.get_directories():
				if profile == active_profile: continue
				track_catalog.shared_directories.append(profile_root.path_join("players").path_join(profile).path_join("tracks/.published"))

func _tracks(parent: VBoxContainer = null, preview: bool = false) -> void:
	if parent == null: parent = content
	var began: int = Time.get_ticks_usec()
	var browser := TrackBrowser.new()
	var created: int = Time.get_ticks_usec()
	browser.name = "TrackBrowser"
	browser.library = library
	_ensure_track_catalog()
	browser.catalog = track_catalog
	browser.cloud = cloud
	browser.discovery = discovery_provider
	browser.records = records
	browser.builtin_ids = BUILTIN_IDS
	browser.selected_track = selected_track
	browser.page_preview = preview
	browser.state = browser_state.duplicate(true) if preview else browser_state
	browser.race_requested.connect(func(track: NativeTrack) -> void: _start_race(track,false))
	browser.track_selected.connect(_menu_track_selected)
	browser.home_requested.connect(func() -> void: _show_screen("tracks"))
	browser.import_requested.connect(_import_dialog)
	browser.delete_requested.connect(_confirm_delete_track)
	browser.notice.connect(_notice)
	browser.rivalry_requested.connect(_open_rivalry)
	browser.challenges_requested.connect(_open_challenges)
	browser.edit_requested.connect(func(doc: Dictionary) -> void:
		document = doc.duplicate(true)
		editor_view.clear()
		history.clear()
		redo_history.clear()
		_show_screen("create"))
	parent.add_child(browser)
	if not preview: menu_open_costs = {"browser_new_ms":(created-began)/1000.0,"browser_ready_ms":(Time.get_ticks_usec()-created)/1000.0}

func _menu_track_selected(track: NativeTrack) -> void:
	selected_track = track
	if screen == "garage" and is_instance_valid(content): _refresh_cached_menu_page("garage",content)
	for neighbor: Dictionary in menu_neighbors.values():
		if neighbor.screen == "garage": _refresh_cached_menu_page("garage",neighbor.content)

func _open_race_area() -> void:
	if race_area_mode == "rivalry": _open_rivalry()
	elif race_area_mode == "challenges": _open_challenges()
	else: _navigate_menu_page("tracks")

func _open_challenges() -> void:
	_cancel_rivalry_entry()
	race_area_mode = "challenges"
	_navigate_menu_page("challenges")
	if not challenges.busy: challenges.refresh()

func _challenges_changed() -> void:
	if screen == "challenges" and is_instance_valid(content) and (not is_instance_valid(game) or challenge_result_view): _challenges()

func _challenges(parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var page := ChallengesPage.new()
	page.items = challenges.items
	page.selected = challenges.selected
	page.folder = challenges.folder
	page.signed_in = online.client.signed_in()
	page.busy = challenges.busy or cloud_starting
	page.error = challenges.error
	page.has_more = not challenges.next_cursor.is_empty()
	page.result_view = challenge_result_view
	page.result_state = challenges.result_state
	page.outcome = challenges.outcome
	page.mode_requested.connect(_request_race_mode)
	page.folder_requested.connect(func(folder: String) -> void:
		challenges.folder = folder
		challenges.items.clear()
		challenges.selected = {}
		challenges.refresh())
	page.selected_requested.connect(func(code: String) -> void: challenges.open(code))
	page.create_requested.connect(func() -> void: _create_challenge_dialog())
	page.code_requested.connect(_challenge_code_dialog)
	page.race_requested.connect(_start_challenge_race)
	page.share_requested.connect(_share_challenge)
	page.rematch_requested.connect(func() -> void:
		await challenges.rematch()
		if challenges.error.is_empty():
			challenge_result_view = false
			_clear_challenge_game()
			_open_challenges()
			_share_challenge())
	page.cancel_requested.connect(_cancel_challenge_dialog)
	page.refresh_requested.connect(func() -> void:
		if not challenges.selected.is_empty(): challenges.open(str(challenges.selected.code))
		else: challenges.refresh())
	page.more_requested.connect(func() -> void: challenges.refresh(true))
	page.sign_in_requested.connect(_open_account)
	page.back_requested.connect(func() -> void:
		challenge_result_view = false
		_clear_challenge_game()
		_open_challenges())
	parent.add_child(page)
	_keep_race_mode_rail_fixed(page)

func _clear_challenge_game() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
	challenge_racing = false

func _receive_challenge(value: String) -> void:
	challenge_invitation = ChallengesClient.code_from(value)
	if challenge_invitation.is_empty(): return
	if not startup_complete:
		await get_tree().process_frame
		_receive_challenge.call_deferred(value)
		return
	if is_instance_valid(game):
		challenge_queued_invitation = challenge_invitation
		return
	_open_challenges()
	challenges.open(challenge_invitation)

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
	field.grab_focus()

func _share_challenge() -> void:
	if challenges.selected.is_empty(): return
	var value: Dictionary = challenges.selected
	var time: String = "%.3f s" % (float(value.target_ms)/1000.0) if value.get("target_ms") != null else "Join my group challenge"
	var text: String = "%s · %s · 5 laps · %s\n%s\nCode: %s" % [str(value.entry.name),time,VehicleCatalog.title(str(value.vehicle_id)),str(value.share_url),str(value.code)]
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

func _create_challenge_dialog(version: String = "", vehicle: String = "", ticket_id: String = "", duration_seconds: int = 604800, finished: Dictionary = {}) -> void:
	if not online.client.signed_in():
		_open_account()
		return
	var dialog := ChallengeCreate.new()
	dialog.adapter = challenges
	dialog.entries = cloud.entries.duplicate(true)
	dialog.initial_version = version if not version.is_empty() else str(selected_track.metadata.get("cloud_version",""))
	dialog.initial_vehicle = VehicleCatalog.selected if vehicle.is_empty() else vehicle
	dialog.initial_ticket = ticket_id
	dialog.initial_duration = duration_seconds
	if not ticket_id.is_empty():
		if finished.is_empty() and is_instance_valid(game) and game.get("track_session").finished:
			finished = _challenge_finished_context(game.get("native_track"),game.get("track_session").race_time_seconds(),game.get("track_session").completed_laps,ticket_id,str(game.get("vehicle_id")))
		dialog.result_context = finished.duplicate(true)
		if not finished.is_empty():
			dialog.initial_version = str(finished.entry.version_id)
			dialog.initial_vehicle = str(finished.vehicle_id)
			dialog.initial_ticket = str(finished.ticket_id)
	var retained: Dictionary = cloud.retained_entry(selected_track.identity)
	if not retained.is_empty() and not dialog.entries.any(func(entry: Dictionary) -> bool: return str(entry.version_id) == str(retained.version_id)):
		dialog.entries.push_front(retained)
	if not challenges.selected.is_empty() and not dialog.entries.any(func(entry: Dictionary) -> bool: return str(entry.version_id) == str(challenges.selected.entry.version_id)):
		dialog.entries.push_front(challenges.selected.entry)
	dialog.created_callback = func() -> void:
		_clear_challenge_game()
		challenge_result_view = false
		challenges.folder = "sent"
		_open_challenges()
		_share_challenge()
	dialog.race_to_set_requested.connect(_race_for_challenge)
	root_ui.add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560,420))

func _challenge_finished_context(track: NativeTrack, total: float, laps: int, ticket_id: String, vehicle: String) -> Dictionary:
	var version: String = str(track.metadata.get("cloud_version",""))
	var entry: Dictionary = {}
	for candidate: Dictionary in cloud.entries:
		if str(candidate.get("version_id","")) == version:
			entry = candidate.duplicate(true)
			break
	if entry.is_empty():
		var points: Array = []
		for point: Vector2 in track.route: points.append([point.x,point.y])
		entry = {"version_id":version,"track_id":str(track.metadata.get("cloud_track_id","")),"content_hash":track.content_hash,"name":track_title(track),"creator":str(track.metadata.get("cloud_creator","")),"theme":str(track.metadata.get("theme","pine")),"points":points}
	return {"entry":entry,"ticket_id":ticket_id,"vehicle_id":vehicle,"total":total,"laps":laps,"scope":challenges.scope()}

func _race_for_challenge(metadata: Dictionary, vehicle: String, duration_seconds: int = 604800) -> void:
	var original: String = challenges.scope()
	var navigation: int = _navigation_generation
	var entry: Dictionary = cloud.entry_from_metadata(metadata)
	if not await cloud.download(entry):
		_notice(cloud.last_error)
		return
	if navigation != _navigation_generation or original != challenges.scope(): return
	var track: NativeTrack = cloud.compile_entry(entry)
	if track == null:
		_notice("Track could not be prepared. Try again.")
		return
	_clear_challenge_game()
	VehicleCatalog.selected = vehicle
	selected_track = track
	challenge_seed = {"version_id":str(metadata.version_id),"vehicle_id":vehicle,"duration_seconds":duration_seconds}
	await _start_race(track,false)

func _start_challenge_race() -> void:
	if cloud_starting or challenges.busy or challenges.selected.is_empty(): return
	if challenge_racing and is_instance_valid(game):
		_retry_race()
		return
	var original: String = challenges.scope()
	var navigation: int = _navigation_generation
	var selected: Dictionary = challenges.selected.duplicate(true)
	var guest: bool = not online.client.signed_in()
	if not guest and not selected.joined:
		await challenges.join()
		if not challenges.error.is_empty(): return
	if navigation != _navigation_generation or original != challenges.scope(): return
	cloud_starting = true
	_challenges()
	var loading: RaceLoading = _open_race_loading()
	var loading_id: int = loading.get_instance_id()
	var points := PackedVector2Array()
	for point: Array in selected.entry.points: points.append(Vector2(point[0],point[1]))
	loading.configure(str(selected.entry.name),str(selected.entry.get("theme","pine")),points)
	loading.stage("Connecting race…")
	await _present_race_loading()
	var issued: Dictionary = await challenges.ticket() if not guest else {}
	var entry: Dictionary = cloud.entry_from_metadata(selected.entry)
	var downloaded: bool = await cloud.download(entry) if guest or not issued.is_empty() else false
	var track: NativeTrack = cloud.compile_entry(entry) if downloaded else null
	var recording: Dictionary = await challenges.ghost() if track != null else {}
	cloud_starting = false
	_close_race_loading(loading_id)
	if navigation != _navigation_generation or original != challenges.scope(): return
	if track == null or (not guest and issued.is_empty()):
		if challenges.error.is_empty(): challenges.error = cloud.last_error if not cloud.last_error.is_empty() else "Track could not be prepared. Try again."
		_challenges()
		return
	_clear_challenge_game()
	VehicleCatalog.selected = str(selected.vehicle_id)
	selected_track = track
	challenge_recording = recording
	challenge_result_view = false
	await _start_race(track,false,guest,issued)

func _open_rivalry() -> void:
	if _rivalry_entry_pending: return
	_race_mode_request += 1
	var request: int = _race_mode_request
	var navigation: int = _navigation_generation
	if not rivalry.model.sample: rivalry.refresh()
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
	rivalry.refresh()

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
	if rivalry.result_ticket.is_empty() or rivalry.result_state in ["verified","failed","rejected","expired"]: rivalry_result_pending = false
	if screen == "rivalry" and is_instance_valid(content) and (not is_instance_valid(game) or rivalry_section == "result"):
		_rivalry()
	# Swipe previews must follow the same membership state as the visible page.
	for neighbor: Dictionary in menu_neighbors.values():
		if neighbor.screen == "rivalry": _rivalry(neighbor.content)
	if returning_menu_neighbor.get("screen","") == "rivalry" and is_instance_valid(returning_menu_neighbor.get("content")):
		_rivalry(returning_menu_neighbor.content)

func _rivalry(parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var page := WeeklyRivalryPage.new()
	page.model = rivalry.model
	page.section = rivalry_section
	page.selected = rivalry_track
	page.ghost_choice = rivalry_ghost_choice
	page.busy = rivalry.busy or cloud_starting
	page.error = rivalry.error
	page.signed_in = online.client.signed_in()
	page.pending_result = rivalry_result_pending
	page.race_details = rivalry_race_details
	page.section_requested.connect(func(section: String) -> void:
		if is_instance_valid(game):
			remove_child(game)
			game.queue_free()
			game = null
			rivalry_racing = false
		rivalry_section = section
		_rivalry()
		if not rivalry.model.sample: rivalry.refresh())
	page.track_requested.connect(func(index: int) -> void:
		rivalry_track = index
		rivalry_section = "detail"
		_rivalry())
	page.track_selected.connect(func(index: int) -> void: rivalry_track = index)
	page.race_requested.connect(_start_rivalry_race)
	page.free_race_requested.connect(func() -> void:
		if is_instance_valid(game):
			remove_child(game)
			game.queue_free()
			game = null
			rivalry_racing = false
		_open_free_race())
	page.join_requested.connect(func() -> void:
		if online.client.signed_in(): rivalry.join()
		else: _open_account())
	page.refresh_requested.connect(func() -> void: rivalry.refresh())
	page.challenges_requested.connect(_open_challenges)
	page.continue_requested.connect(func() -> void:
		if rivalry.model.sample:
			rivalry.model.next_week()
			_rivalry()
		else: rivalry.continue_week())
	page.retry_requested.connect(_retry_race)
	parent.add_child(page)
	_keep_race_mode_rail_fixed(page)
	if page.section == "detail" and not rivalry.model.sample and not rivalry.model.tracks.is_empty():
		_prepare_rivalry_track_preview(page,rivalry_track)

func _prepare_rivalry_track_preview(page: WeeklyRivalryPage, index: int) -> void:
	var entry: Dictionary = cloud.entry_from_metadata(rivalry.model.tracks[index].entry)
	var document: Dictionary = cloud.cached_document(entry)
	if document.is_empty():
		if not bool(rivalry.model.tracks[index].get("available",true)): return
		if not await cloud.download(entry): return
		document = cloud.cached_document(entry)
	if is_instance_valid(page) and page.is_inside_tree(): page.apply_track_preview(document)

func _rivalry_ghost(index: int, choice: int) -> Dictionary:
	if choice == 3: return {}
	var target: Dictionary = rivalry.model.ghost_target(index,choice)
	var driver: String = str(target.get("driver_id",""))
	rivalry.prefetch_ghost(index,driver)
	return rivalry.cached_ghost(index,driver)

func _start_rivalry_race(index: int, choice: int) -> void:
	if cloud_starting or rivalry.busy or not online.client.signed_in() or rivalry.model.sample: return
	var navigation: int = _navigation_generation
	var original_scope: String = rivalry.scope()
	cloud_starting = true
	_rivalry()
	var loading: RaceLoading = _open_race_loading()
	var loading_id: int = loading.get_instance_id()
	var metadata: Dictionary = rivalry.model.tracks[index].entry
	var points := PackedVector2Array()
	for point: Array in metadata.get("points", []): points.append(Vector2(point[0], point[1]))
	loading.configure(str(metadata.get("name", "Weekly Rivalry")), str(metadata.get("theme", "pine")), points)
	loading.stage("Connecting race…")
	await _present_race_loading()
	if navigation != _navigation_generation or original_scope != rivalry.scope():
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	_rivalry_ghost(index,choice) # Fetch presentation in parallel with required race data.
	var issued: Dictionary = await rivalry.ticket(index)
	if navigation != _navigation_generation or original_scope != rivalry.scope():
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	if issued.is_empty():
		cloud_starting = false
		_close_race_loading(loading_id)
		_rivalry()
		return
	var entry: Dictionary = cloud.entry_from_metadata(rivalry.model.tracks[index].entry)
	loading.stage("Downloading track…")
	var downloaded: bool = await cloud.download(entry)
	if navigation != _navigation_generation or original_scope != rivalry.scope():
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	if not downloaded:
		cloud_starting = false
		_close_race_loading(loading_id)
		rivalry.error = cloud.last_error
		_rivalry()
		return
	loading.stage("Preparing track…")
	await _present_race_loading()
	if navigation != _navigation_generation or original_scope != rivalry.scope():
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	var track: NativeTrack = cloud.compile_entry(entry)
	if track == null:
		cloud_starting = false
		_close_race_loading(loading_id)
		rivalry.error = "Track could not be prepared. Try again."
		_rivalry()
		return
	loading.stage("Loading ghost…")
	var recording: Dictionary = await _rivalry_ghost(index,choice)
	cloud_starting = false
	_close_race_loading(loading_id)
	if navigation != _navigation_generation or original_scope != rivalry.scope(): return
	rivalry_track = index
	rivalry_ghost_choice = choice
	rivalry_recording = recording
	rivalry_result_pending = false
	rivalry_race_details = {}
	rivalry.result_ticket = ""
	rivalry.result_state = ""
	selected_track = track
	await _start_race(track,false,false,issued)

func _garage(parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var scene_copy := VBoxContainer.new()
	scene_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scene_copy)
	var title := MenuStyle.label("YOUR GARAGE",48)
	title.add_theme_color_override("font_shadow_color",MenuStyle.INK)
	title.add_theme_constant_override("shadow_offset_y",2)
	scene_copy.add_child(title)
	scene_copy.add_child(MenuStyle.label("Drive. Improve. Repeat.",22,true))
	var scene_space := Control.new()
	scene_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_copy.add_child(scene_space)
	var footer := HBoxContainer.new()
	scene_copy.add_child(footer)
	_feature(footer,track_title(selected_track).to_upper()+" · 5 LAPS","Return to your selected circuit",_show_screen.bind("tracks"))
	footer.get_child(footer.get_child_count()-1).name = "GarageCircuit"
	_feature(footer,"DRIVING CONTROLS","Find your preferred layout",_show_screen.bind("settings"))
	var info: VBoxContainer = _menu_card(row)
	info.add_theme_constant_override("separation",6)
	var eyebrow := MenuStyle.label("YOUR CAR  /  READY TO RACE",16)
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	info.add_child(eyebrow)
	info.add_child(MenuStyle.label(VehicleCatalog.title(),36))
	var selector := OptionButton.new()
	selector.name = "VehicleSelector"
	selector.custom_minimum_size.y = 48
	for i: int in range(VehicleCatalog.IDS.size()):
		selector.add_item(VehicleCatalog.CLASSES[i])
	selector.select(VehicleCatalog.IDS.find(VehicleCatalog.selected))
	selector.item_selected.connect(_select_vehicle)
	info.add_child(selector)

	var description := MenuStyle.label(VehicleCatalog.description(),18,true)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	info.add_child(HSeparator.new())
	var handling: HandlingConfig = HandlingSelection.config()
	for pair: Array in [["Handling",handling.profile_name],["Mass","%d kg" % roundi(handling.mass)],["Speed limit","%d km/h" % roundi(handling.maximum_speed*3.6)]]:
		var stat := HBoxContainer.new()
		stat.custom_minimum_size.y = 35
		info.add_child(stat)
		var label := MenuStyle.label(pair[0],18,true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.add_child(label)
		stat.add_child(MenuStyle.label(pair[1],24))
	info.add_child(HSeparator.new())
	var tip := MenuStyle.label("All cars available. Personal bests are saved per car and handling.",17,true)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(tip)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(space)
	var race := MenuStyle.button("RACE  →",func() -> void: _start_race(selected_track,false),true)
	race.custom_minimum_size.y = 64
	info.add_child(race)
	info.add_child(MenuStyle.button("Choose circuit",_open_library.bind("all")))

func _settings() -> void:
	var page := SettingsPage.new()
	page.records = records
	page.purchase_client = online.client
	page.signed_in = online.client.signed_in()
	page.player_name = online.player_name() if page.signed_in else "Guest"
	page.country_code = str(online.client.player.get("country_code","")) if page.signed_in else ""
	page.customize_requested.connect(_customize_controls)
	page.account_requested.connect(_open_account)
	content.add_child(page)

func _customize_controls() -> void:
	var editor := ControlLayoutEditor.new()
	editor.records = records
	root_ui.visible = false
	add_child(editor)
	editor.closed.connect(func() -> void: _show_screen("settings"))

func _save_settings() -> void:
	records.settings.touch_scale = ui_touch_scale
	records.settings.left_handed = ui_left_handed
	if records.save_records() != OK: _notice("Settings could not be saved. Check free storage space.")

func _swipe_menu_page(direction: int) -> void:
	var pages: Array[String] = ["tracks", "biome", "garage", "store"]
	var current: String = "biome" if screen == "drafts" else "tracks" if screen in ["rivalry","challenges"] else screen
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
	if screen == "create" and _editor_has_unsaved_changes():
		_confirm_editor_departure(_start_new_document)
		return
	_start_new_document()

func _start_new_document() -> void:
	_finish_preview_thread()
	editor_view.clear()
	object_browser_state.clear()
	canvas = null
	document = TrackDocument.create_blank()
	document.id = TrackLibrary.unique_id()
	editor_saved_snapshot = {}
	_stamp_creator()
	history.clear()
	redo_history.clear()
	_navigate_menu_page("biome")
	object_browser = null
	object_browser_state.clear()

func _editor() -> void:
	_stamp_creator()
	if document.is_empty():
		document = TrackDocument.create_blank()
		document.id = TrackLibrary.unique_id()
		_stamp_creator()
	if editor_pending_id != str(document.id):
		editor_pending_tools.clear()
		editor_pending_id = str(document.id)
		editor_save_error = OK
		editor_retry_original = false
		editor_save_message = ""
		editor_wip_saved = ""
		editor_issue_cursor = -1
	editor_world = EditorWorld.new()
	root_ui.add_child(editor_world)
	MenuStyle.fill(editor_world)
	canvas = EditorCanvas.new()
	canvas.stamp_kind = "rock" if document.theme == "desert" else "light" if document.theme == "night_city" else "tree"
	canvas.document = document
	canvas.world_backdrop = true
	if not editor_view.is_empty():
		canvas.zoom = editor_view.zoom
		canvas.pan = editor_view.pan
		canvas.mode = "road" if editor_view.mode in ["waypoints","move","add"] else editor_view.mode
		canvas.selected = mini(int(editor_view.get("selected",-1)),document.points.size()-1)
		canvas.selected_object = mini(int(editor_view.get("selected_object",-1)),document.objects.size()-1)
		canvas.selected_piece = mini(int(editor_view.get("selected_piece",-1)),document.pieces.size()-1)
		canvas.stamp_kind = str(editor_view.get("stamp_kind","tree"))
		canvas.stamp_scale = float(editor_view.get("stamp_scale",1.0))
		canvas.run_shape = str(editor_view.get("run_shape","line"))
		canvas.free_run = bool(editor_view.get("free_run",false))
		canvas.brush_surface = int(editor_view.get("brush_surface",0))
		canvas.brush_width = float(editor_view.get("brush_width",10))
		canvas.brush_shape = str(editor_view.get("brush_shape","round"))
		canvas.paint_mode = str(editor_view.get("paint_mode","free"))
		canvas.fitted = true
	root_ui.add_child(canvas)
	MenuStyle.fill(canvas)
	editor_world.follow_canvas(canvas)
	canvas.native_changed.connect(editor_world.show_track)
	canvas.edit_started.connect(func() -> void:
		editor_gesture_history = history.duplicate()
		editor_gesture_redo = redo_history.duplicate()
		_remember()
		if canvas.mode in ["move","add"]: document.route_override = true)
	canvas.document_changed.connect(func() -> void:
		canvas.refresh()
		test_button.disabled = true
		publish_button.disabled = true
		share_button.disabled = true)
	canvas.edit_finished.connect(func() -> void:
		_save_draft(true)
		editor_gesture_history.clear()
		editor_gesture_redo.clear())
	canvas.edit_cancelled.connect(func() -> void:
		history = editor_gesture_history.duplicate()
		redo_history = editor_gesture_redo.duplicate()
		editor_gesture_history.clear()
		editor_gesture_redo.clear()
		canvas.selected_object = mini(canvas.selected_object,document.objects.size()-1)
		_update_editor_issues()
		_build_editor_tools())
	canvas.hint_changed.connect(_editor_hint)
	var overlay := Control.new()
	overlay.name = "EditorOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(overlay)
	MenuStyle.fill(overlay)
	var close: Button = EditorButton.make("","close",func() -> void:
		_request_editor_exit())
	close.name="CloseEditor"
	close.tooltip_text="Close editor"
	overlay.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-68; close.offset_right=-16; close.offset_top=16; close.offset_bottom=68
	var header_left := HBoxContainer.new()
	header_left.name="EditorIdentityAndHistory"
	header_left.position=Vector2(16,16)
	header_left.add_theme_constant_override("separation",12)
	overlay.add_child(header_left)
	var title := HBoxContainer.new()
	var title_panel := PanelContainer.new()
	var title_style: StyleBoxFlat=EditorStyle.panel()
	title_style.content_margin_top=0
	title_style.content_margin_bottom=0
	title_panel.add_theme_stylebox_override("panel",title_style)
	header_left.add_child(title_panel)
	title_panel.add_child(title)
	title.add_theme_constant_override("separation",4)
	var track_name := Label.new()
	track_name.name="TrackName"
	track_name.text=str(document.name)
	track_name.custom_minimum_size=Vector2(220,52)
	track_name.clip_text=true
	track_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	track_name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	track_name.add_theme_font_override("font",EditorStyle.FONT)
	track_name.add_theme_font_size_override("font_size",20)
	track_name.add_theme_color_override("font_color",EditorStyle.INK)
	title.add_child(track_name)
	var creator_label := MenuStyle.label("by " + library.owner_name, 16, true)
	creator_label.name = "TrackCreator"
	creator_label.custom_minimum_size.x = 160
	creator_label.clip_text = true
	creator_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_child(creator_label)
	var pencil: Button=EditorButton.make("","pencil",_rename_track)
	EditorStyle.transparent_button(pencil)
	pencil.name="RenameTrack"
	pencil.tooltip_text="Rename track"
	title.add_child(pencil)
	var history_panel := PanelContainer.new()
	history_panel.name="EditorHistory"
	history_panel.add_theme_stylebox_override("panel",title_style.duplicate())
	header_left.add_child(history_panel)
	var history := HBoxContainer.new()
	history.add_theme_constant_override("separation",4)
	history_panel.add_child(history)
	editor_undo=EditorButton.make("","undo",_undo)
	editor_undo.text="Undo"
	EditorStyle.integrated(editor_undo)
	editor_undo.tooltip_text="Undo"
	history.add_child(editor_undo)
	editor_redo=EditorButton.make("","redo",_redo)
	editor_redo.text="Redo"
	EditorStyle.integrated(editor_redo)
	editor_redo.tooltip_text="Redo"
	history.add_child(editor_redo)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	overlay.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -516; top.offset_right = -80; top.offset_top = 16
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.add_theme_constant_override("separation",8)
	editor_issue_button = EditorStyle.button("",_focus_issue)
	editor_issue_button.custom_minimum_size = Vector2(112,52)
	top.add_child(editor_issue_button)
	var settings: Button = EditorButton.make("","more",func() -> void:
		canvas.cancel_gesture()
		editor_map_panel.visible = not editor_map_panel.visible
		editor_tools_panel.hide())
	settings.text = "Map"
	settings.tooltip_text = "Map settings"
	top.add_child(settings)
	test_button = EditorButton.action("Test","play",_test_document)
	test_button.custom_minimum_size=Vector2(104,52)
	top.add_child(test_button)
	EditorStyle.apply(test_button)
	var disabled_play: StyleBoxFlat=EditorStyle.box()
	disabled_play.bg_color=Color("252d30")
	disabled_play.border_color=Color("586369")
	disabled_play.shadow_size=0
	test_button.add_theme_stylebox_override("disabled",disabled_play)
	for state: String in ["normal","hover","pressed","hover_pressed"]:
		var play_style: StyleBoxFlat=EditorStyle.box()
		play_style.bg_color=Color("29412e") if state=="hover" else Color(0.075,0.14,0.095,0.94)
		play_style.border_color=Color(0.65,0.82,0.43,0.45)
		play_style.set_border_width_all(1)
		test_button.add_theme_stylebox_override(state,play_style)
	publish_button = EditorButton.action("Publish","publish",_publish_current_document,true)
	publish_button.name = "PublishTrack"
	publish_button.tooltip_text = "Complete a test drive before publishing this version."
	publish_button.custom_minimum_size=Vector2(132,52)
	top.add_child(publish_button)
	var rail := VBoxContainer.new()
	rail.name = "EditorRail"
	var rail_panel := PanelContainer.new()
	rail_panel.name = "EditorRailPanel"
	rail_panel.anchor_top=0.5; rail_panel.anchor_bottom=0.5
	rail_panel.offset_left=16
	rail_panel.grow_vertical=Control.GROW_DIRECTION_BOTH
	rail_panel.resized.connect(func() -> void: rail_panel.offset_top=-rail_panel.size.y*0.5; rail_panel.offset_bottom=rail_panel.size.y*0.5)
	rail_panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(rail_panel)
	rail_panel.add_child(rail)
	rail.add_theme_constant_override("separation",6)
	editor_mode_buttons.clear()
	for pair: Array in [["road","Track","road"],["paint","Surfaces","surface"],["objects","Objects","objects"]]:
		var value: String = pair[0]
		var button: Button = EditorButton.make(pair[1],pair[2],_editor_category.bind(value))
		button.name = "Editor"+({"road":"Road","paint":"Surface"}.get(value,pair[1]))
		button.custom_minimum_size=Vector2(86,76)
		button.toggle_mode = true
		EditorStyle.integrated(button)
		editor_mode_buttons[value] = button
		rail.add_child(button)
	var bottom := CenterContainer.new()
	editor_palette = bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 108; bottom.offset_right = -112; bottom.offset_top = -98; bottom.offset_bottom = -16
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_editor_box())
	bottom.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360,68)
	panel.add_child(scroll)
	editor_context = HBoxContainer.new()
	editor_context.add_theme_constant_override("separation",6)
	scroll.add_child(editor_context)
	surface_toolbar = PanelContainer.new()
	surface_toolbar.name = "SurfacePlacementToolbar"
	surface_toolbar.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	overlay.add_child(surface_toolbar)
	surface_toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	surface_toolbar.offset_left = -270
	surface_toolbar.offset_right = 270
	surface_toolbar.offset_top = 78
	surface_toolbar.offset_bottom = 180
	surface_toolbar.resized.connect(func() -> void:
		surface_toolbar.offset_left = -surface_toolbar.size.x*0.5
		surface_toolbar.offset_right = surface_toolbar.size.x*0.5)
	surface_actions = HBoxContainer.new()
	surface_actions.add_theme_constant_override("separation",8)
	surface_toolbar.add_child(surface_actions)
	editor_status = MenuStyle.label("",17)
	editor_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(editor_status)
	editor_status.name = "EditorFeedback"
	editor_status.position = Vector2(16,128)
	editor_status.size = Vector2(280,64)
	editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Retain status text for internal feedback consumers, without a canvas-wide hint bar.
	editor_status.hide()
	editor_save_button = EditorStyle.button("Draft",_retry_editor_save)
	editor_save_button.name = "EditorSaveState"
	editor_save_button.position = Vector2(16,78)
	editor_save_button.custom_minimum_size = Vector2(260,42)
	overlay.add_child(editor_save_button)
	_update_editor_save_state()
	editor_loading = PanelContainer.new()
	editor_loading.name = "EditorPreparation"
	editor_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_loading.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(editor_loading)
	editor_loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	editor_loading.offset_left = -110; editor_loading.offset_right = 110
	editor_loading.offset_top = 198; editor_loading.offset_bottom = 240
	var preparing: Label = MenuStyle.label("Preparing track…",17)
	preparing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_loading.add_child(preparing)
	object_browser = ObjectBrowser.new()
	object_browser.visible = false
	for key: String in object_browser_state: object_browser.set(key,object_browser_state[key])
	object_browser.current = canvas.stamp_kind
	object_browser.biome = str(document.get("biome",document.theme))
	overlay.add_child(object_browser)
	object_browser.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	object_browser.offset_left = 108; object_browser.offset_right = -112
	object_browser.offset_top = -160; object_browser.offset_bottom = -16
	object_browser.hide()
	object_browser.asset_chosen.connect(_choose_object)
	object_browser.mode_chosen.connect(_object_placement)
	object_browser.size_chosen.connect(func(value: float) -> void: canvas.stamp_scale=value)
	object_browser.select_requested.connect(func() -> void:
		canvas.cancel_gesture(); canvas.mode="objects"; _build_editor_tools())
	editor_tools_panel = _editor_panel(overlay,"EditorTools")
	editor_inspector = VBoxContainer.new()
	editor_tools_panel.add_child(editor_inspector)
	editor_map_panel = _editor_panel(overlay,"EditorMap")
	editor_map_panel.anchor_bottom=0
	editor_map_panel.offset_bottom=82
	editor_map_panel.offset_left=-268
	var metadata := VBoxContainer.new()
	editor_map_panel.add_child(metadata)
	for entry: Array in [["New",_new_document],["Load",_load_track_dialog],["Save",_save_track_explicit]]:
		var command: Button=EditorStyle.button(entry[0],entry[1])
		command.name=entry[0]+"Track"
		metadata.add_child(command)
	share_button=EditorStyle.button("Share",_share_dialog)
	metadata.add_child(share_button)
	metadata.add_child(EditorStyle.button("Help",_editor_help))
	canvas.selection_changed.connect(_build_editor_tools)
	_restore_pending_tool(_editor_tool())
	_build_editor_tools()
	_refresh_editor()
	_update_editor_save_state()
	# Reuse an exact completed preview if the worker is idle; otherwise let the
	# existing single worker prepare the newest document while controls render.
	var cached_preview: NativeTrack
	if editor_preview_thread == null:
		for entry: Dictionary in editor_compiled_cache:
			if entry.document == document: cached_preview = entry.track; break
	if cached_preview != null: canvas.show_native(cached_preview)
	else: _queue_editor_preview()
	_update_editor_issues()
	if editor_view.is_empty(): canvas.call_deferred("fit")
	_apply_editor_safe_area(overlay)
	root_ui.resized.connect(_apply_editor_safe_area.bind(overlay))

func _editor_box() -> StyleBoxFlat:
	return EditorStyle.panel()


func _editor_panel(parent: Control, node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -322; panel.offset_right = -16
	panel.offset_top = 82; panel.offset_bottom = -146
	panel.add_theme_stylebox_override("panel",_editor_box())
	panel.hide()
	return panel

func _apply_editor_safe_area(overlay: Control) -> void:
	if not OS.has_feature("mobile"): return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	var factor: float = get_viewport().get_visible_rect().size.y/maxf(1,window.y)
	overlay.offset_left = maxf(0,safe.position.x*factor)
	overlay.offset_top = maxf(0,safe.position.y*factor)
	overlay.offset_right = -maxf(0,(window.x-safe.end.x)*factor)
	overlay.offset_bottom = -maxf(0,(window.y-safe.end.y)*factor)

func _editor_hint(message: String) -> void:
	if not is_instance_valid(editor_status): return
	editor_status.text = message
	editor_status.show()
	editor_hint_generation += 1
	var generation: int = editor_hint_generation
	var label_id: int = editor_status.get_instance_id()
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if generation == editor_hint_generation and is_instance_valid(editor_status) and editor_status.get_instance_id() == label_id and editor_save_error == OK: editor_status.hide())

func _update_editor_save_state() -> void:
	if not is_instance_valid(editor_save_button): return
	if editor_save_error != OK:
		editor_save_button.text = "Save failed · Retry"
		editor_save_button.disabled = false
		editor_save_button.tooltip_text = editor_save_message
		editor_save_button.add_theme_color_override("font_color",Color("ffbc8b"))
		if is_instance_valid(editor_status):
			editor_status.text = editor_save_message
			editor_status.show()
	elif _has_pending_editor_work():
		editor_save_button.text = "Preview pending"
		editor_save_button.disabled = true
		editor_save_button.tooltip_text = "Switching tools retains previews. Save confirms valid previews; Discard cancels them."
	elif not editor_saved_snapshot.is_empty() and TrackLibrary.draft_fingerprint(document) == TrackLibrary.draft_fingerprint(editor_saved_snapshot):
		editor_save_button.text = "Saved on device"
		editor_save_button.disabled = true
		editor_save_button.tooltip_text = "The saved original matches this document."
	else:
		editor_save_button.text = "WIP recovery saved" if editor_wip_saved == TrackLibrary.draft_fingerprint(document) else "Unsaved draft"
		editor_save_button.disabled = true
		editor_save_button.tooltip_text = "Recovery is separate from the saved original. Use Map → Save or Ctrl+S to keep it."

func _retry_editor_save() -> void:
	if editor_retry_original: _save_track_now()
	else: _save_draft(true)

func _editor_tool() -> String:
	if not is_instance_valid(canvas): return "road"
	if canvas.mode in ["paint","pan"] or (canvas.mode == "place" and canvas.stamp_kind in ["puddle","water","dirt"]): return "paint"
	return "objects" if canvas.mode in ["objects","place","run"] else "road"

func _capture_pending_tool() -> Dictionary:
	var state: Dictionary = {"mode":canvas.mode}
	var keys: Array = {"road":["ghost","piece_kind","snap_matched"],"paint":["paint_points","paint_mode","brush_surface","brush_width","brush_shape","protect_road","stamp_kind","stamp_scale"],"objects":["run_start","run_preview","run_draw","run_shape","free_run","stamp_kind","stamp_scale","stamp_rotation"]}[_editor_tool()]
	for key: String in keys:
		var value: Variant = canvas.get(key)
		state[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return state

func _stash_pending_tool() -> void:
	if is_instance_valid(canvas): editor_pending_tools[_editor_tool()] = _capture_pending_tool()

func _restore_pending_tool(tool: String) -> void:
	canvas.ghost = {}
	canvas.paint_points = []
	canvas.run_start = Vector2.INF
	canvas.run_preview = []
	canvas.run_draw = PackedVector2Array()
	canvas.mode = tool
	for key: String in editor_pending_tools.get(tool,{}): canvas.set(key,editor_pending_tools[tool][key])

func _pending_state_has_work(tool: String, state: Dictionary) -> bool:
	if tool == "road": return not state.get("ghost",{}).is_empty()
	if tool == "paint": return not state.get("paint_points",[]).is_empty()
	return state.get("run_start",Vector2.INF) != Vector2.INF or not state.get("run_preview",[]).is_empty() or state.get("run_draw",PackedVector2Array()).size() > 1

func _has_pending_editor_work() -> bool:
	var active: String = _editor_tool()
	for tool: String in ["road","paint","objects"]:
		var state: Dictionary = _capture_pending_tool() if is_instance_valid(canvas) and active == tool else editor_pending_tools.get(tool,{})
		if _pending_state_has_work(tool,state): return true
	return false

func _discard_editor_previews() -> void:
	editor_pending_tools.clear()
	if not is_instance_valid(canvas): return
	canvas.changed_in_gesture = false
	canvas.cancel_gesture()
	_restore_pending_tool(_editor_tool())
	canvas.queue_redraw()

func _commit_editor_previews() -> bool:
	_stash_pending_tool()
	var active: String = _editor_tool()
	for tool: String in ["road","paint","objects"]:
		if not _pending_state_has_work(tool,editor_pending_tools.get(tool,{})): continue
		canvas.changed_in_gesture = false
		canvas.cancel_gesture()
		_restore_pending_tool(tool)
		if tool == "road": canvas.confirm_piece()
		elif tool == "paint": canvas.confirm_paint()
		elif canvas.run_preview.is_empty():
			_editor_hint("Finish the object run, or cancel it before saving.")
		else:
			_remember()
			document.objects.append_array(canvas.run_preview.slice(0,maxi(0,96-document.objects.size())))
			canvas.run_preview.clear(); canvas.run_draw.clear(); canvas.run_start = Vector2.INF
			_save_draft(true)
		_stash_pending_tool()
		if _pending_state_has_work(tool,editor_pending_tools[tool]):
			_build_editor_tools()
			_notice("Complete or cancel this preview before saving. Your pending work is retained.")
			return false
	_restore_pending_tool(active)
	_build_editor_tools()
	return true

func _resolve_editor_previews(after: Callable) -> void:
	if root_ui.find_child("PendingPreviewDialog",true,false) != null: return
	var dialog := ConfirmationDialog.new()
	dialog.name = "PendingPreviewDialog"
	dialog.title = "Pending previews"
	dialog.dialog_text = "Confirm or discard the pending previews before selecting an issue."
	dialog.ok_button_text = "Confirm previews"
	dialog.add_button("Discard previews",true,"discard")
	dialog.confirmed.connect(func() -> void:
		dialog.hide()
		if _commit_editor_previews(): after.call()
		dialog.queue_free())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_discard_editor_previews()
			dialog.queue_free()
			after.call())
	dialog.canceled.connect(dialog.queue_free)
	root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(510,200))

func _editor_category(value: String) -> void:
	if value in ["waypoints","move","add"]: value = "road"
	_stash_pending_tool()
	canvas.cancel_gesture()
	_restore_pending_tool(value)
	canvas.selected_piece = -1
	canvas.selected_object = -1
	canvas.selected = -1
	editor_geometry = ""
	editor_tools_panel.hide()
	editor_map_panel.hide()
	_build_editor_tools()
	canvas.queue_redraw()

func _context_button(label: String, glyph: String, action: Callable, chosen: bool = false) -> Button:
	var button: Button = EditorButton.make(label,glyph,action,chosen)
	EditorStyle.card(button,chosen)
	editor_context.add_child(button)
	return button

func _build_editor_tools() -> void:
	if not is_instance_valid(editor_context) or not is_instance_valid(canvas): return
	_update_test_access()
	_update_editor_save_state()
	canvas.road_action = editor_geometry if editor_geometry != "" else "move"
	for child: Node in editor_context.get_children():
		editor_context.remove_child(child)
		child.queue_free()
	for child: Node in editor_inspector.get_children():
		editor_inspector.remove_child(child)
		child.queue_free()
	var category: String = "objects" if canvas.mode in ["objects","place","run"]  else "paint" if canvas.mode in ["paint","pan"] else "road"
	if canvas.mode == "place" and canvas.stamp_kind in ["puddle","water","dirt"]: category="paint"
	var biome: String = str(document.get("biome",document.theme))
	if object_browser.biome!=biome:
		object_browser.biome=biome
		object_browser.refresh()
	var browsing: bool = category=="objects" and not (canvas.selected_object>=0 and canvas.mode=="objects")
	object_browser.visible = browsing
	editor_palette.visible = not browsing
	for key: String in editor_mode_buttons: (editor_mode_buttons[key] as Button).set_pressed_no_signal(key == category)
	surface_toolbar.visible = category == "paint"
	var track_title: Label = root_ui.find_child("TrackName",true,false)
	if track_title != null: track_title.custom_minimum_size.x = 220
	if category == "paint":
		if canvas.brush_surface == 0: canvas.brush_surface = 2
		_build_surface_toolbar()
	if category == "road":
		var piece: Dictionary = canvas.ghost if not canvas.ghost.is_empty() else document.pieces[canvas.selected_piece] if canvas.selected_piece >= 0 else {}
		if piece.is_empty():
			_context_button("Start line","race",canvas.choose_start_line)
			for pair: Array in [["straight","Straight"],["taper","Taper"],["curve","Curve"],["s_bend","S-bend"],["hairpin","Hairpin"],["bridge","Bridge"],["spline","Spline"]]:
				_context_button(pair[1],pair[0],canvas.choose_piece.bind(pair[0]))
			editor_status.text = "Choose a section · drag empty ground to pan · pinch to zoom"
		elif editor_geometry != "" and piece.kind == "bridge":
			_context_button("Back","back",func() -> void:
				editor_geometry = ""
				_build_editor_tools())
			var key: String = "radius" if piece.kind == "s_bend" and editor_geometry == "length" else editor_geometry
			_context_button("- 5 deg" if key == "angle" else "- 1 m","minus",_change_piece.bind(key,-5.0 if key == "angle" else -1.0))
			_context_button(("Straight length" if key == "length" and piece.kind == "hairpin" else "Lead-in" if key == "length" and piece.kind not in ["straight","bridge"] else key.capitalize())+(" %.0f deg" if key == "angle" else " %.1f m") % (RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0))),"width",func() -> void: pass)
			_context_button("+ 5 deg" if key == "angle" else "+ 1 m","plus",_change_piece.bind(key,5.0 if key == "angle" else 1.0))
			if key != "width" and piece.kind == "hairpin": _context_button("Radius" if key == "length" else "Straight length" if piece.kind == "hairpin" else "Lead-in","curve",func() -> void:
				editor_geometry = "radius" if key == "length" else "length"
				_build_editor_tools())
			if piece.kind == "s_bend" and key != "height": _context_button("Height","width",func() -> void:
				editor_geometry = "height"
				_build_editor_tools())
			if piece.kind == "curve" and key != "angle": _context_button("Angle","curve",func() -> void:
				editor_geometry = "angle"
				_build_editor_tools())
			editor_status.text = "Both straight arms change equally; 0 m makes a plain U-turn. Radius stays separate." if piece.kind == "hairpin" and key == "length" else "Only this section changes. Reconnect any open ends afterwards."
		else:
			if piece.kind == "spline":
				_context_button("Point %d/5" % (canvas.spline_point+1),"spline",func() -> void:
					canvas.spline_point = (canvas.spline_point+1)%5
					_build_editor_tools())
				_context_button("Width −","minus",_change_piece.bind("point_width",-0.5))
				_context_button("%.1f m" % float(piece.point_widths[canvas.spline_point]),"width",func() -> void: pass)
				_context_button("Width +","plus",_change_piece.bind("point_width",0.5))
			if piece.kind == "bridge":
				_context_button("Shape",piece.kind,func() -> void:
					editor_geometry = "length" if piece.kind in ["straight","bridge"] else "radius"
					_build_editor_tools())
				if piece.kind == "hairpin": _context_button("Straight length","straight",func() -> void:
					editor_geometry = "length"
					_build_editor_tools())
				_context_button("Width","width",func() -> void:
					editor_geometry = "width"
					_build_editor_tools())
				_context_button("Rotate","rotate",_change_piece.bind("heading",15.0))
			_context_button("Flip","flip",_change_piece.bind("flip",1.0))
			_context_button("Snap on" if canvas.snap_enabled else "Snap off","snap",func() -> void:
				canvas.snap_enabled = not canvas.snap_enabled
				canvas.snap_matched = false
				_build_editor_tools(),canvas.snap_enabled)
			_context_button("Cancel" if not canvas.ghost.is_empty() else "Delete","delete",_delete_piece)
			if canvas.ghost.is_empty():
				_context_button("Connect","snap",canvas.connect_nearby)
				_context_button("Layer","surface",canvas.cycle_piece)
			editor_status.text = "Drag inside to move · end dots resize and turn · ✓ to place" if not canvas.ghost.is_empty() else "Drag inside to move · drag end dots to reshape · Layer selects overlapping roads"
			if piece.kind == "bridge": editor_status.text = "Bridge: ramps at both ends · ground road passes beneath the middle"
			if piece.kind == "spline": editor_status.text = "Drag the five numbered points · select a point to set its width · ✓ to place"
	elif category == "paint":
		for pair: Array in [[1,"Grass"],[2,"Sand"],[3,"Water"]]:
			_context_button(pair[1],"terrain_dirt" if pair[0] == 2 else "terrain_"+pair[1].to_lower(),func() -> void:
				canvas.brush_surface = pair[0]
				canvas.mode = "paint"
				_build_editor_tools(),canvas.mode == "paint" and canvas.brush_surface == pair[0])
		_context_button("Puddle","terrain_puddle",_choose_hazard.bind("puddle"))
		_build_paint_tools()
		editor_status.text = "Drag to paint freely" if canvas.paint_mode == "free" else "Tap to add points / drag dots to reshape / confirm to place"
	elif category == "objects":
		if canvas.selected_object >= 0 and canvas.mode == "objects":
			editor_status.text=CreatorObjects.description(document.objects[canvas.selected_object].kind)
			_context_button("Rotate","rotate",_rotate_object)
			_context_button("Copy","objects",_duplicate_object)
			if document.objects[canvas.selected_object].kind not in ["tyre_wall","tyre_stack"]:
				_context_button("Size -","minus",func() -> void: _scale_object(-0.25))
				_context_button("Size +","plus",func() -> void: _scale_object(0.25))
				editor_status.text = "%s / %.2fx" % [CreatorObjects.description(document.objects[canvas.selected_object].kind),float(document.objects[canvas.selected_object].get("scale",1.0))]
			_context_button("Delete","delete",_delete_selection)
			if canvas.issue_marker != Vector2.INF: _context_button("Move start","race",canvas.choose_start_line)
			_context_button("Palette","more",func() -> void:
				canvas.selected_object = -1
				_build_editor_tools())
		else:
			editor_status.text = CreatorCatalog.label(canvas.stamp_kind)+" / "+("Drag a curve; release to place" if canvas.run_shape=="curve" else "Drag a line, or tap its two ends" if canvas.mode=="run" else "Tap empty ground to place / tap an object to edit")
			if canvas.mode=="objects": editor_status.text="Tap an object to move, rotate or delete"

	var context_width: float = 0
	for child: Control in editor_context.get_children(): context_width += child.get_combined_minimum_size().x+6
	(editor_context.get_parent() as ScrollContainer).custom_minimum_size.x = clampf(context_width,320,maxf(320,canvas.size.x-260))
	_update_editor_save_state()
	canvas.refresh()

func _change_piece(key: String, delta: float) -> void:
	var is_ghost: bool = not canvas.ghost.is_empty()
	if not is_ghost and canvas.selected_piece < 0: return
	var piece: Dictionary = (canvas.ghost if is_ghost else document.pieces[canvas.selected_piece]).duplicate(true)
	var before: Dictionary = piece.duplicate(true)
	if piece.kind == "s_bend" and key == "length": return
	if key == "point_width" and piece.kind == "spline": piece = SplineRoad.with_width(piece,canvas.spline_point,float(piece.point_widths[canvas.spline_point])+delta)
	elif key == "flip": piece.flip = not piece.flip
	elif key == "heading": piece.heading = fposmod(float(piece.heading)+delta,360.0)
	else:
		var lower: float = 5.0 if key == "angle" else 6.0 if key == "width" else 2.0 if key == "height" else 3.0 if key == "radius" else 24.0 if piece.kind == "bridge" else 2.0 if piece.kind == "straight" else 0.0
		var upper: float = 270.0 if key == "angle" else 20.0 if key == "width" else 60.0 if key in ["radius","height"] else 120.0
		piece[key] = clampf((RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0)))+delta,lower,upper)
	piece = canvas.anchored_change(before,piece,key)
	var errors: Array[String] = RoadPieces.validate(piece)
	if not errors.is_empty():
		editor_status.text = errors[0]
		return
	if not canvas._valid_bridge_edit(piece,canvas.selected_piece): return
	if is_ghost:
		canvas.ghost = piece
		canvas.snap_matched = false
	else:
		_remember()
		document.pieces[canvas.selected_piece] = piece
		_save_draft(true)
	_build_editor_tools()

func _delete_piece() -> void:
	if not canvas.ghost.is_empty(): canvas.ghost.clear()
	elif canvas.selected_piece >= 0:
		_remember()
		document.pieces.remove_at(canvas.selected_piece)
		canvas.selected_piece = -1
		_save_draft(true)
	editor_geometry = ""
	_build_editor_tools()

func _route_from_roads() -> void:
	var result: Dictionary = RoadPieces.route_from_pieces(document)
	if not result.ok:
		editor_status.text = str(result.errors[0])
		return
	_remember()
	for key: String in ["points","widths","corners","route_override"]: document[key] = result.document[key]
	canvas.selected = -1
	_commit_selection()

func _practice_start(track: NativeTrack) -> Vector2:
	if document.has("start_line"): return Vector2(document.start_line.position[0],document.start_line.position[1])
	if document.has("practice_start"): return Vector2(document.practice_start.position[0],document.practice_start.position[1])
	if document.pieces.is_empty(): return track.spawn
	var samples: PackedVector2Array = RoadPieces.samples(document.pieces[0])
	return samples[mini(6,samples.size()-1)]

func _practice_heading(track: NativeTrack) -> float:
	if document.has("start_line"): return PI*0.5-deg_to_rad(float(document.start_line.heading))
	if document.has("practice_start"): return PI*0.5-deg_to_rad(float(document.practice_start.heading))
	if document.pieces.is_empty(): return track.spawn_heading
	var samples: PackedVector2Array = RoadPieces.samples(document.pieces[0])
	var index: int = mini(6,samples.size()-1)
	var tangent: Vector2 = samples[mini(index+1,samples.size()-1)]-samples[maxi(0,index-1)]
	return atan2(tangent.x,tangent.y)

func _move_practice_start() -> void:
	canvas.cancel_gesture()
	canvas.mode = "start"
	editor_tools_panel.hide()
	_build_editor_tools()
	editor_status.text = "Tap a clear road to place the practice start"

func _update_editor_issues() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(editor_issue_button): return
	var previous: Dictionary = editor_issues[editor_issue_cursor] if editor_issue_cursor >= 0 and editor_issue_cursor < editor_issues.size() else {}
	editor_issues.clear()
	canvas.issue_marker = Vector2.INF
	var track: NativeTrack = canvas.native_preview
	if track != null:
		var start: Vector2 = _practice_start(track)
		var config: HandlingConfig = HandlingSelection.config()
		var radius: float = config.collision_radius
		var elevated: bool = track.collision_elevated_at(start,track.nearest_route(start),radius)
		if track.overlaps_obstacle(start,radius,elevated):
			for i: int in range(document.objects.size()):
				var object: Dictionary = document.objects[i]
				if CreatorObjects.surface(object.kind) not in [3,4]: continue
				var local: Vector2 = (start-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
				var half: Vector2 = CreatorObjects.size_of(object)*0.5
				if local.distance_to(local.clamp(-half,half)) <= radius+track.cell_size*0.71:
					editor_issues.append({"message":"%s blocks the start" % str(object.kind).capitalize(),"position":start,"object":i})
			if editor_issues.is_empty(): editor_issues.append({"message":"Obstacle overlaps the starting car","position":start,"object":-2})
	for join: Dictionary in RoadPieces.joins(document.pieces):
		editor_issues.append({"message":join.message,"position":join.position,"object":-1,"index":join.index,"endpoint":join.endpoint})
	editor_issue_cursor = editor_issues.find(previous)
	editor_issue_button.text = "Issue %d/%d" % [editor_issue_cursor+1,editor_issues.size()] if editor_issue_cursor >= 0 else "%d issue%s" % [editor_issues.size(),"s" if editor_issues.size() != 1 else ""]
	editor_issue_button.tooltip_text = "Tap to focus the next issue."
	editor_issue_button.visible = not editor_issues.is_empty()
	_update_test_access()
	canvas.queue_redraw()

func _update_test_access() -> void:
	if not is_instance_valid(test_button) or not is_instance_valid(canvas): return
	var has_road: bool = not document.pieces.is_empty() or not document.layout.is_empty() or not document.paint.is_empty() or document.base_track != ""
	test_button.disabled = editor_preview_thread != null or not TrackDocument.validate(document).is_empty() or not has_road or _has_pending_editor_work()
	for issue: Dictionary in editor_issues:
		if int(issue.object) != -1: test_button.disabled = true

func _focus_issue() -> void:
	if editor_issues.is_empty(): return
	if _has_pending_editor_work():
		_resolve_editor_previews(_focus_issue)
		return
	editor_issue_cursor = (editor_issue_cursor+1)%editor_issues.size()
	var issue: Dictionary = editor_issues[editor_issue_cursor]
	_editor_category("objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road")
	canvas.mode = "objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road"
	canvas.issue_marker = issue.position
	canvas.issue_text = issue.message
	canvas.pan += canvas.size*0.5-canvas.to_screen(issue.position)
	if int(issue.object) >= 0: canvas.selected_object = issue.object
	elif int(issue.object) == -1: canvas.selected_piece = issue.index
	_build_editor_tools()
	editor_issue_button.text = "Issue %d/%d" % [editor_issue_cursor+1,editor_issues.size()]
	_editor_hint(issue.message+" · paint Road over the obstacle, or place a Start line." if int(issue.object) == -2 else issue.message+" · drag to repair, or delete the selection.")
	canvas.refresh()

func _commit_selection() -> void:
	if canvas.mode in ["move","add"]: document.route_override = true
	canvas.refresh()
	_save_draft(true)
	_build_editor_tools()

func _delete_selection() -> void:
	if canvas.mode in ["objects","place","run"]:
		if canvas.selected_object < 0: return
		_remember()
		document.objects.remove_at(canvas.selected_object)
		canvas.selected_object = -1
	else: return
	_commit_selection()

func _rotate_object() -> void:
	canvas.stamp_rotation = fposmod(canvas.stamp_rotation+45,360)
	if canvas.selected_object >= 0:
		_remember()
		document.objects[canvas.selected_object].rotation = fposmod(float(document.objects[canvas.selected_object].rotation)+45,360)
		_commit_selection()
	else: _build_editor_tools()

func _scale_object(delta: float) -> void:
	if canvas.selected_object < 0: return
	_remember()
	var object: Dictionary = document.objects[canvas.selected_object]
	object.scale = clampf(float(object.get("scale",1.0))+delta,0.5,1.5 if object.kind in CreatorCatalog.DECORATIVE else 3.0)
	_commit_selection()


func _duplicate_object() -> void:
	if canvas.selected_object < 0 or document.objects.size() >= 96: return
	_remember()
	var object: Dictionary = document.objects[canvas.selected_object].duplicate(true)
	object.position = [clampf(float(object.position[0])+4,-110,110),clampf(float(object.position[1])+4,-110,110)]
	document.objects.append(object)
	canvas.selected_object = document.objects.size()-1
	canvas.mode = "objects"
	_commit_selection()

func _creator_name() -> void:
	_notice("Track creator: " + library.owner_name + ". This comes from your racing account.")

func _remember() -> void:
	history.append(document.duplicate(true))
	if history.size() > 40: history.pop_front()
	redo_history.clear()

func _set_document_value(key: String, value: Variant) -> void:
	if key in ["theme", "biome", "creator"]: return
	_remember()
	document[key] = value
	_save_draft(true)
	_show_screen("create")

func _undo() -> void:
	if history.is_empty(): return
	redo_history.append(document.duplicate(true))
	document = history.pop_back()
	_restore_editor_history()

func _redo() -> void:
	if redo_history.is_empty(): return
	history.append(document.duplicate(true))
	document = redo_history.pop_back()
	_restore_editor_history()

func _restore_editor_history() -> void:
	# Keep the viewport, camera and controls alive; stale worker results are
	# discarded by _process, without waiting for them in the input handler.
	canvas.changed_in_gesture = false
	canvas.cancel_gesture()
	canvas.ghost.clear()
	canvas.selected_piece = -1
	canvas.selected_object = -1
	canvas.document = document
	canvas.road_approval_pending = false
	var title: Label = root_ui.find_child("TrackName",true,false) as Label
	if title != null: title.text = str(document.name)
	canvas.refresh()
	_save_draft(true)
	_build_editor_tools()

func _refresh_editor() -> void:
	if not is_instance_valid(editor_status): return
	var errors: Array[String] = TrackDocument.validate(document)
	editor_status.text = "Waypoints are generated from connected roads. Changes save automatically." if errors.is_empty() else errors[0]
	test_button.disabled = not errors.is_empty()
	publish_button.disabled = not errors.is_empty() or lifecycle == null or not lifecycle.ready_to_publish(document)
	share_button.disabled = not errors.is_empty()
	if is_instance_valid(canvas): canvas.refresh()

func _save_draft(background_preview: bool = false) -> Error:
	if not background_preview: _finish_preview_thread()
	if document.is_empty(): return ERR_INVALID_DATA
	_stamp_creator()
	if not document.pieces.is_empty():
		if document.pieces != editor_route_pieces or editor_route_fields.is_empty():
			var auto_route: Dictionary = RoadPieces.route_from_pieces(document)
			if auto_route.ok:
				editor_route_pieces = document.pieces.duplicate(true)
				editor_route_fields.clear()
				for key: String in ["points","widths","corners","route_override"]: editor_route_fields[key] = auto_route.document[key]
		if document.pieces == editor_route_pieces:
			for key: String in editor_route_fields: document[key] = editor_route_fields[key].duplicate(true) if editor_route_fields[key] is Array else editor_route_fields[key]
	var errors: Array[String] = TrackDocument.validate(document)
	var message: String
	var save_error: Error = library.save_wip(document)
	if save_error != OK or not editor_retry_original:
		editor_save_error = save_error
		editor_save_message = "Could not save: "+library.last_error if save_error != OK else ""
	if save_error == OK: editor_wip_saved = TrackLibrary.draft_fingerprint(document)
	if save_error == OK and lifecycle != null: lifecycle.defer_sync(document)
	if save_error != OK: message = "Could not save: " + library.last_error
	elif not errors.is_empty(): message = "Draft saved. Before driving: " + errors[0]
	else: message = "WIP autosaved. Saved original unchanged."
	if is_instance_valid(editor_status):
		editor_status.text = message
		test_button.disabled = not errors.is_empty()
		publish_button.disabled = not errors.is_empty() or lifecycle == null or not lifecycle.ready_to_publish(document)
		share_button.disabled = not errors.is_empty()
	_update_editor_save_state()
	if save_error != OK: _editor_hint(editor_save_message)
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(canvas):
		if is_instance_valid(editor_undo): editor_undo.disabled = history.is_empty()
		if is_instance_valid(editor_redo): editor_redo.disabled = redo_history.is_empty()
		if background_preview:
			if _objects_only_edit(): editor_world.preview_objects(document)
			canvas.queue_redraw()
			test_button.disabled = true
			_queue_editor_preview()
		else:
			var preview_track: NativeTrack = _editor_track_preview()
			if preview_track != null: canvas.show_native(preview_track)
			_update_editor_issues()
	return save_error

func _test_document() -> void:
	if _has_pending_editor_work():
		_notice("Confirm or cancel the pending previews before testing.")
		return
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	if not canvas.ghost.is_empty():
		editor_status.text = "Confirm or cancel the preview before testing."
		return
	if _save_draft() != OK: return
	if not await _prepare_creator_test(document): return
	var track: NativeTrack = TrackCompiler.compile(document)
	if track != null and not test_button.disabled:
		track.spawn = _practice_start(track)
		track.spawn_heading = _practice_heading(track)
		await _start_race(track, true)

func _publish_current_document() -> void:
	if _has_pending_editor_work():
		_notice("Confirm or cancel the preview before publishing.")
		return
	if _save_draft() != OK: return
	await _publish_saved_draft("wip:"+str(document.id))

func _share_dialog() -> void:
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	if _save_draft(true) != OK:
		_notice("Could not save: "+library.last_error)
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Share your circuit"
	dialog.dialog_text = "Copy this circuit and send it to a friend. They can paste it into Import.\nLocal creation and racing shared circuits are free."
	dialog.ok_button_text = "Done"
	dialog.add_button("Copy circuit", false, "copy")
	dialog.add_button("Export file", false, "file")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"copy":
			DisplayServer.clipboard_set(JSON.stringify(document))
			dialog.dialog_text = "Circuit copied. Your friend can paste it into Tracks > Import a circuit."
		else: _export_file())
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(650,220))

func _export_file() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Export circuit"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Circuit file"])
	dialog.current_file = str(document.id) + ".json"
	dialog.file_selected.connect(func(path: String) -> void:
		if library.export_document(document, path) == OK: _notice("Circuit exported.")
		else: _notice("Export failed: " + library.last_error))
	_own_dialog(dialog)
	dialog.popup_centered_ratio(0.8)

func _import_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Import a circuit"
	dialog.ok_button_text = "Import"
	var layout := VBoxContainer.new()
	dialog.add_child(layout)
	layout.add_child(MenuStyle.label("Paste a shared circuit below, or choose a circuit file.",18))
	var text := TextEdit.new()
	text.custom_minimum_size = Vector2(620,220)
	text.placeholder_text = "Paste circuit data here"
	layout.add_child(text)
	layout.add_child(MenuStyle.button("Paste from clipboard", func() -> void:
		var copied: String = DisplayServer.clipboard_get()
		if copied.to_utf8_buffer().size() <= TrackDocument.MAX_BYTES: text.text = copied
		else: _notice("That circuit is too large to import.")))
	layout.add_child(MenuStyle.button("Choose file", func() -> void:
		var picker := FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; Circuit file"])
		picker.file_selected.connect(func(path: String) -> void:
			var imported: Dictionary = library.import_document(path)
			if imported.is_empty(): _notice(library.last_error)
			else: _accept_import(imported))
		_own_dialog(picker)
		picker.popup_centered_ratio(0.8)))
	dialog.confirmed.connect(func() -> void:
		if text.text.to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
			_notice("That circuit is too large to import.")
			return
		var parsed: Variant = JSON.parse_string(text.text)
		var errors: Array[String] = TrackDocument.validate(parsed)
		if not errors.is_empty(): _notice(errors[0])
		else: _accept_import(parsed))
	_own_dialog(dialog)
	dialog.popup_centered()

func _accept_import(imported: Dictionary) -> void:
	if not document.is_empty() and not TrackDocument.validate(document).is_empty():
		_notice("Fix or undo your unsaved route change before importing another circuit.")
		return
	_save_draft()
	editor_view.clear()
	canvas = null
	document = imported.duplicate(true)
	# Import as a new local draft: never replace an existing author's work by ID.
	document.id = TrackLibrary.unique_id()
	_stamp_creator()
	history.clear()
	redo_history.clear()
	_save_draft()
	_show_screen("create")

func _notice(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(550,180))

func _own_dialog(dialog: AcceptDialog) -> void:
	root_ui.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	if dialog is FileDialog:
		dialog.file_selected.connect(func(_path: String) -> void: dialog.queue_free())

var test_return_to_drafts: bool = false
var test_document_snapshot: Dictionary = {}

func _open_race_loading(track: NativeTrack = null, practice: bool = false) -> RaceLoading:
	_stop_menu_page_motion()
	race_loading = RaceLoading.new()
	add_child(race_loading)
	if track != null:
		race_loading.configure(track_title(track), str(track.metadata.get("theme", "pine")), track.route, practice)
	return race_loading

func _present_race_loading() -> void:
	# Layout and actually draw the overlay before synchronous scene construction.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _close_race_loading(expected_id: int = 0) -> void:
	if not is_instance_valid(race_loading): return
	if expected_id != 0 and race_loading.get_instance_id() != expected_id: return
	remove_child(race_loading)
	race_loading.queue_free()
	race_loading = null

func _start_race(track: NativeTrack, from_editor: bool, offline_only: bool = false, rivalry_issued: Dictionary = {}) -> void:
	if cloud_starting or is_instance_valid(race_loading): return
	if not from_editor and not track.metadata.has("cloud_version") and cloud != null:
		_notice("Choose a published backend track from Race.")
		return
	var original_scope: String = lifecycle.scope()
	var navigation_generation: int = _navigation_generation
	var starting_screen: String = screen
	var selected_vehicle: String = VehicleCatalog.selected
	var starting_selection: NativeTrack = selected_track
	var loading: RaceLoading = _open_race_loading(track, from_editor)
	var loading_id: int = loading.get_instance_id()
	cloud_starting = true
	await _present_race_loading()
	if lifecycle.scope() != original_scope or navigation_generation != _navigation_generation or screen != starting_screen or VehicleCatalog.selected != selected_vehicle or selected_track != starting_selection:
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	cloud_ticket = {}
	cloud_publish_version = str(track.metadata.get("cloud_version","")) if track.metadata.get("cloud_publish",false) else ""
	if not offline_only and not from_editor and track.metadata.has("cloud_version") and online.client.signed_in():
		loading.stage("Connecting race…")
		var issued: Dictionary = await cloud.ticket(track,false,VehicleCatalog.selected,null,rivalry_issued) if not rivalry_issued.is_empty() else await cloud.ticket(track)
		if lifecycle.scope() != original_scope or navigation_generation != _navigation_generation or screen != starting_screen or VehicleCatalog.selected != selected_vehicle or selected_track != starting_selection:
			cloud_starting = false
			_close_race_loading(loading_id)
			return
		cloud_ticket = issued
		if not cloud_ticket.is_empty():
			cloud_ticket._owner_id = str(online.client.player.id)
			cloud_ticket._origin = str(online.client.base_url())
			if rivalry_issued.has("challenge_code"): challenges.result_ticket = str(cloud_ticket.ticket_id)
			elif not rivalry_issued.is_empty(): rivalry.result_ticket = str(cloud_ticket.ticket_id)
		if cloud_ticket.is_empty():
			cloud_starting = false
			_close_race_loading(loading_id)
			if not rivalry_issued.is_empty():
				if rivalry_issued.has("challenge_code"):
					challenges.error = cloud.last_error
					_challenges()
				else:
					rivalry.error = cloud.last_error
					_rivalry()
				return
			var offline_dialog := ConfirmationDialog.new()
			offline_dialog.title = "Online race unavailable"
			offline_dialog.dialog_text = cloud.last_error+"\nRace offline with a local time? This attempt will not enter the online leaderboard."
			offline_dialog.ok_button_text = "Race offline"
			_own_dialog(offline_dialog)
			offline_dialog.confirmed.connect(func() -> void:
				if navigation_generation == _navigation_generation and screen == starting_screen and VehicleCatalog.selected == selected_vehicle and selected_track == starting_selection:
					_start_race(track,from_editor,true))
			offline_dialog.popup_centered()
			return
	loading.stage("Loading track…")
	await _present_race_loading()
	if lifecycle.scope() != original_scope or navigation_generation != _navigation_generation or screen != starting_screen or VehicleCatalog.selected != selected_vehicle or selected_track != starting_selection:
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	returning_to_editor = from_editor
	challenge_racing = rivalry_issued.has("challenge_code")
	challenge_practice = offline_only and screen == "challenges" and not challenges.selected.is_empty()
	rivalry_racing = not rivalry_issued.is_empty() and not challenge_racing
	test_return_to_drafts = from_editor and screen == "drafts"
	test_document_snapshot = document.duplicate(true) if from_editor else {}
	if from_editor:
		test_library_snapshot = library
		test_scope_snapshot = lifecycle.scope() if lifecycle != null else ""
		test_vehicle_snapshot = VehicleCatalog.selected
	if not from_editor:
		records.settings["last_track"] = track.identity
		if records.save_records() != OK:
			pending_menu_notice = "This circuit could not be remembered for next time. Check available storage."
	if is_instance_valid(canvas):
		canvas.cancel_gesture()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
	_stop_menu_page_motion()
	root_ui.visible = false
	game = GAME_SCENE.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.set_meta("soundtrack_rivalry", rivalry_racing)
	game.set("initial_track", track)
	game.set("production_mode", true)
	game.set("resume_client",online.client)
	game.set("resume_ticket_id",str(cloud_ticket.get("ticket_id","")))
	game.set("rating_records", null if track.metadata.has("cloud_version") else records)
	game.set("preference_records", records)
	game.set("editor_test", from_editor)
	game.connect("exit_requested", _leave_race)
	game.connect("edit_here_requested", _edit_here)
	game.connect("race_completed", _results)
	game.connect("practice_lap_completed", _complete_draft_test,CONNECT_DEFERRED)
	game.connect("retry_requested", _retry_race)
	add_child(game)
	var prepared_game: Node = game
	if rivalry_racing:
		game.ghost_mode = "race" if not rivalry_recording.is_empty() else "off"
		game.ghost_bests = {"race":rivalry_recording} if not rivalry_recording.is_empty() else {}
	elif challenge_racing or (offline_only and screen == "challenges"):
		game.ghost_mode = "race" if not challenge_recording.is_empty() else "off"
		game.ghost_bests = {"race":challenge_recording} if not challenge_recording.is_empty() else {}
	var hud: PlaygroundHUD = game.get("hud")
	hud.touch.control_scale = ui_touch_scale
	hud.touch.left_handed = ui_left_handed
	hud.touch.haptic_strength = float(records.settings.get("steering_haptics",0.2))
	hud.touch.layout = ControlLayout.from_settings(records.settings)
	hud.touch.show_labels = bool(records.settings.get("control_labels", true))
	# Render the prepared world once with the countdown/input still frozen.
	game.call("_process", 0.0)
	loading.stage("Preparing start…")
	await _present_race_loading()
	if not is_instance_valid(prepared_game) or game != prepared_game:
		cloud_starting = false
		_close_race_loading(loading_id)
		return
	if lifecycle.scope() != original_scope or navigation_generation != _navigation_generation:
		cloud_starting = false
		_close_race_loading(loading_id)
		_leave_race()
		return
	game.process_mode = Node.PROCESS_MODE_INHERIT
	cloud_starting = false
	_close_race_loading(loading_id)

func _edit_here(position: Vector2) -> void:
	_leave_race()
	if is_instance_valid(canvas):
		canvas.pan += canvas.size*0.5-canvas.to_screen(position)
		canvas.refresh()

func _leave_race() -> void:
	if is_instance_valid(game) and not cloud_ticket.is_empty() and bool(game.get("track_session").finished):
		_results()
		if not cloud_ticket.is_empty(): return
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null
	if not challenge_queued_invitation.is_empty():
		var queued: String = challenge_queued_invitation
		challenge_queued_invitation = ""
		challenge_racing = false
		rivalry_racing = false
		challenge_result_view = false
		_receive_challenge(queued)
		return
	if challenge_racing or challenge_practice:
		challenge_racing = false
		challenge_practice = false
		challenge_result_view = false
		_show_screen("challenges")
	elif rivalry_racing:
		rivalry_racing = false
		rivalry_section = "overview"
		_show_screen("rivalry")
	else: _show_screen("drafts" if test_return_to_drafts else "create" if returning_to_editor else "tracks")
	test_return_to_drafts = false
	if not pending_menu_notice.is_empty():
		_notice(pending_menu_notice)
		pending_menu_notice = ""

func _results() -> void:
	var result_records: LocalRecords = game.get("preference_records")
	var session: TrackSession = game.get("track_session")
	var track: NativeTrack = game.get("native_track")
	var total: float = session.race_time_seconds()
	var clean: bool = not bool(game.get("attempt_practice")) and not returning_to_editor
	if _result_game_id == game.get_instance_id(): return
	_result_game_id = game.get_instance_id()
	var online_queued: bool = clean and session.finished and not cloud_ticket.is_empty()
	var challenge_source_ticket: String = str(cloud_ticket.get("ticket_id",""))
	var finished_challenge: Dictionary = _challenge_finished_context(track,total,session.completed_laps,challenge_source_ticket,str(game.get("vehicle_id"))) if online_queued else {}
	if challenge_racing and online_queued:
		challenges.begin_result(challenge_source_ticket)
		challenges.poll_result()
	if not challenge_seed.is_empty():
		challenge_seed.ticket_id = challenge_source_ticket
		challenge_seed.finished = finished_challenge.duplicate(true)
	if rivalry_racing:
		rivalry_result_pending = online_queued
		# Verification runs behind the normal PB/lap summary until Continue.
		rivalry_section = "race_results"
		if online_queued: rivalry.model.preview_result(rivalry_track,session.elapsed_ticks,total)
		else: rivalry.model.last_result = {"ms":roundi(total*1000.0)}
		if online_queued: rivalry.poll_result()
	var previous: float = result_records.best_for(track, game.get("handling"))
	if rivalry_racing:
		rivalry_race_details = {"previous":previous,"clean":clean and session.finished,
			"laps":session.completed_laps,"distance_m":track.route_length*session.completed_laps,
			"theme":str(track.metadata.get("theme","pine")),"route":track.route.duplicate()}
	GameSoundtrack.instance().results_feedback(previous - total if previous > 0.0 else 0.0, clean and session.finished)
	var previous_lap: float = float(result_records.records.get(result_records.key_for(track,game.get("handling")),{}).get("flying_ms",0))/1000.0
	var saved: bool = not clean
	if clean: saved = result_records.record(track, game.get("handling"), total, session.lap_times) == OK
	if clean and saved:
		var ghost_error: Error = game.save_personal_ghost()
		if ghost_error != OK: pending_menu_notice = "Best time saved. Could not save its local ghost."
	(game.get("hud") as PlaygroundHUD).hide()
	root_ui.visible = true
	for child: Node in root_ui.get_children():
		root_ui.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color.WHITE
	var blur := ShaderMaterial.new()
	blur.shader = preload("res://ui/results_backdrop.gdshader")
	background.material = blur
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var center := MarginContainer.new()
	MenuStyle.fill(center)
	for side: String in ["left","right"]: center.add_theme_constant_override("margin_"+side,32)
	for side: String in ["top","bottom"]: center.add_theme_constant_override("margin_"+side,16)
	root_ui.add_child(center)
	_apply_editor_safe_area(center)
	center.resized.connect(_apply_editor_safe_area.bind(center))
	var panel := RaceResults.new()
	panel.circuit = track_title(track)
	panel.vehicle_name = VehicleCatalog.title(game.vehicle_id)
	panel.total = total
	panel.previous = previous
	panel.best = result_records.best_for(track,game.get("handling"))
	panel.laps = session.lap_times.duplicate()
	panel.clean = clean
	panel.saved = saved
	panel.editor = returning_to_editor
	panel.challenge_available = online_queued and not returning_to_editor
	panel.challenge_requested.connect(func() -> void:
		_create_challenge_dialog(str(finished_challenge.entry.version_id),str(finished_challenge.vehicle_id),challenge_source_ticket,604800,finished_challenge))
	panel.result = RaceResultData.build(track,session.lap_times,game.get("lap_telemetry"),bool(game.get("attempt_practice")))
	var flying: float = 0.0
	for i: int in range(1,session.lap_times.size()):
		if flying == 0 or session.lap_times[i] < flying: flying = session.lap_times[i]
	var incident_free: bool = game.sim.state.collision_count == 0 and panel.result.laps.size() == RaceRules.LAPS
	for lap: Dictionary in panel.result.laps:
		if lap.get("samples",[]).is_empty() or not lap.get("events",[]).is_empty(): incident_free = false
	panel.set_meta("reward_facts",{"complete":clean and session.finished,"total":total,"previous":previous,"previous_lap":previous_lap,"flying":flying,"incident_free":incident_free})
	panel.continue_requested.connect(_results_continue.bind(panel,center))
	panel.retry_requested.connect(_retry_race)
	panel.return_requested.connect(_leave_race)
	center.add_child(panel)
	if track.metadata.has("cloud_version"):
		var online_status := Label.new()
		online_status.name = "CloudRunStatus"
		online_status.text = "Could not connect to the server. We'll retry automatically."
		online_status.visible = online_queued and cloud.run_connection_failed
		panel.add_child(online_status)
		if online_queued:
			var update_status: Callable = func() -> void:
				if is_instance_valid(online_status): online_status.visible = cloud.run_connection_failed
			cloud.changed.connect(update_status)
			online_status.tree_exiting.connect(func() -> void:
				if cloud.changed.is_connected(update_status): cloud.changed.disconnect(update_status))
	root_ui.modulate.a = 0.0
	create_tween().tween_property(root_ui, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if online_queued: _save_result_upload(game,cloud_ticket,game.get("online_frames"),cloud_publish_version,game.get("online_rewinds"))

func _save_result_upload(completed_game: Node, ticket_data: Dictionary, frames: Array, publish_version: String, rewinds: Array) -> void:
	if not cloud.enqueue_completed(ticket_data,frames,publish_version,rewinds):
		_notice("This recorded result could not enter the save queue. Keep this race open and free storage.")
		return
	# Ownership transfers immediately; navigation never cancels its durable save.
	if is_instance_valid(completed_game) and game == completed_game:
		cloud_ticket = {}
		cloud_publish_version = ""

func _results_continue(results: RaceResults, parent: Control) -> void:
	if challenge_practice:
		challenge_practice = false
		_clear_challenge_game()
		_show_screen("challenges")
		return
	if challenge_racing:
		challenge_result_view = true
		_show_screen("challenges")
		challenges.poll_result()
		return
	if not challenge_seed.is_empty():
		var seed: Dictionary = challenge_seed.duplicate(true)
		challenge_seed = {}
		if is_instance_valid(game):
			remove_child(game)
			game.queue_free()
			game = null
		_open_challenges()
		_create_challenge_dialog(str(seed.version_id),str(seed.vehicle_id),str(seed.get("ticket_id","")),int(seed.get("duration_seconds",604800)),seed.get("finished",{}))
		return
	if rivalry_racing:
		rivalry_section = "result"
		_show_screen("rivalry")
		if rivalry_result_pending: rivalry.poll_result()
		return
	results.hide()
	var page := RaceComplete.new()
	page.results = results
	page.rating_records = records
	page.rating_track_id = (game.get("native_track") as NativeTrack).identity
	page.cloud_client = online.client
	page.cloud_sync = cloud
	page.vehicle_id = str(game.get("vehicle_id"))
	page.cloud_version = str((game.get("native_track") as NativeTrack).metadata.get("cloud_version",""))
	page.facts = results.get_meta("reward_facts",{})
	_ensure_track_catalog()
	if track_catalog.indexed_revision != library.revision:
		track_catalog.entries.clear()
		if cloud != null:
			cloud.add_to_catalog(track_catalog,discovery_provider)
		else:
			for id: String in BUILTIN_IDS: track_catalog.add_builtin(id)
			for id: String in track_catalog.local_ids(): track_catalog.add_local(id)
		track_catalog.indexed_revision = library.revision
	page.recommendations = RaceRecommendations.suggest(track_catalog,game.get("native_track"))
	page.back_requested.connect(func() -> void:
		parent.remove_child(page)
		page.queue_free()
		results.show())
	page.home_requested.connect(func() -> void:
		if is_instance_valid(game):
			remove_child(game)
			game.queue_free()
		game = null
		returning_to_editor = false
		_show_screen("tracks"))
	page.tracks_requested.connect(_leave_race)
	page.race_requested.connect(_next_result_race)
	parent.add_child(page)

func _next_result_race(recommendation: Dictionary) -> void:
	if recommendation.entry.source == "cloud" and not await cloud.download(recommendation.entry):
		_notice(cloud.last_error)
		return
	var next_track: NativeTrack = track_catalog.resolve(recommendation.entry)
	if next_track == null:
		_notice("This track is no longer available. Choose another track.")
		return
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null
	selected_track = next_track
	_start_race(next_track,false)

func _retry_race() -> void:
	if cloud_starting or not is_instance_valid(game): return
	if not cloud_ticket.is_empty() and bool(game.get("track_session").finished):
		_results()
		if not cloud_ticket.is_empty(): return
	var active_game: Node = game
	var account_id: String = str(online.client.player.get("id",""))
	var origin: String = str(online.client.base_url())
	var track: NativeTrack = game.get("native_track")
	var replacement: Dictionary = {}
	if track.metadata.has("cloud_version") and online.client.signed_in():
		cloud_starting = true
		var issued: Dictionary = await challenges.ticket() if challenge_racing else await rivalry.ticket(rivalry_track) if rivalry_racing else {}
		replacement = await cloud.ticket(track,false,str(game.get("vehicle_id")),game.get("handling"),issued) if not (rivalry_racing or challenge_racing) or not issued.is_empty() else {}
		cloud_starting = false
		if game != active_game or not is_instance_valid(active_game) or str(online.client.player.get("id","")) != account_id or str(online.client.base_url()) != origin: return
		if replacement.is_empty():
			_notice("Could not start verified retry: "+(challenges.error if challenge_racing else cloud.last_error))
			return
	if challenge_racing:
		challenge_recording = await challenges.ghost()
		if game != active_game or not is_instance_valid(active_game) or str(online.client.player.get("id","")) != account_id or str(online.client.base_url()) != origin: return
		challenge_result_view = false
		challenges.result_ticket = ""
		challenges.result_state = ""
	if rivalry_racing:
		cloud_starting = true
		var refreshed_recording: Dictionary = await _rivalry_ghost(rivalry_track,rivalry_ghost_choice)
		cloud_starting = false
		if game != active_game or not is_instance_valid(active_game) or str(online.client.player.get("id","")) != account_id or str(online.client.base_url()) != origin: return
		rivalry_recording = refreshed_recording
	cloud_ticket = replacement
	if rivalry_racing:
		rivalry.result_ticket = str(replacement.get("ticket_id",""))
		rivalry.result_state = ""
		rivalry_result_pending = false
	if not cloud_ticket.is_empty():
		cloud_ticket._owner_id = account_id
		cloud_ticket._origin = origin
	cloud_publish_version = str(track.metadata.get("cloud_version","")) if track.metadata.get("cloud_publish",false) else ""
	root_ui.visible = false
	(game.get("hud") as PlaygroundHUD).show()
	game.set("resume_ticket_id",str(cloud_ticket.get("ticket_id","")))
	game.set("preference_records",records) # A confirmed restart begins a new attempt.
	game.set("rating_records",null if track.metadata.has("cloud_version") else records)
	# Retry reuses the Game node but starts a new scored attempt. Keep duplicate
	# finish signals idempotent within an attempt, without suppressing its retry.
	_result_game_id = 0
	game.call("restart")
	if rivalry_racing:
		game.ghost_mode = "race" if not rivalry_recording.is_empty() else "off"
		game.ghost_bests = {"race":rivalry_recording} if not rivalry_recording.is_empty() else {}
	elif challenge_racing:
		game.ghost_mode = "race" if not challenge_recording.is_empty() else "off"
		game.ghost_bests = {"race":challenge_recording} if not challenge_recording.is_empty() else {}

static func track_title(track: NativeTrack) -> String:
	return str(track.metadata.get("title", track.metadata.get("name", track.identity.replace("_"," ").to_upper())))

func _capture() -> void:
	await get_tree().process_frame
	for child: Node in content.get_children():
		if child is TrackBrowser:
			while child.loading: await get_tree().process_frame
	if screen == "tracks":
		var browser: TrackBrowser = root_ui.find_child("TrackBrowser",true,false)
		while browser != null and browser.loading: await get_tree().process_frame
		for preview: Node in root_ui.find_children("*","TrackShowroom",true,false):
			while not preview.ready_for_display: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	if error == OK: print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit(0 if error == OK else 1)


func _build_paint_tools() -> void:
	editor_inspector.add_child(EditorStyle.button("Keep road" if canvas.protect_road else "Paint all",func() -> void:
		canvas.protect_road = not canvas.protect_road
		_build_editor_tools()))
	if canvas.paint_mode != "free":
		editor_inspector.add_child(MenuStyle.button("Remove last point",func() -> void:
			if not canvas.paint_points.is_empty(): canvas.paint_points.pop_back()
			canvas.queue_redraw()))
		editor_inspector.add_child(MenuStyle.button("Cancel surface",func() -> void:
			canvas.cancel_gesture()
			canvas.queue_redraw()))
	var materials := OptionButton.new()
	materials.custom_minimum_size.y = 54
	for label: String in ["Grass / erase","Sand","Water","Barrier","Kerb","Rough ground","Low obstacles"]: materials.add_item(label)
	materials.selected = canvas.brush_surface-1
	materials.item_selected.connect(func(index: int) -> void:
		canvas.brush_surface = index+1
		canvas.mode = "paint"
		_build_editor_tools())
	editor_inspector.add_child(materials)
	var actions := HBoxContainer.new()
	editor_inspector.add_child(actions)
	for entry: Array in [["paint","Paint"],["pan","Pan"]]:
		var value: String = entry[0]
		actions.add_child(MenuStyle.button(entry[1],func() -> void:
			canvas.mode = value
			_build_editor_tools(),canvas.mode == value))
	var shapes := OptionButton.new()
	shapes.custom_minimum_size.y = 54
	shapes.add_item("Round brush")
	shapes.add_item("Square brush")
	shapes.selected = 1 if canvas.brush_shape == "square" else 0
	shapes.item_selected.connect(func(index: int) -> void: canvas.brush_shape = "square" if index else "round")
	editor_inspector.add_child(shapes)
	var help := MenuStyle.label("Tap to add points; drag dots to reshape. Confirm to place. Free painting commits on release.",16,true)
	if document.base_track != "": help.text += " Remix paints ground only."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_inspector.add_child(MenuStyle.button("Clear map",func() -> void:
		_remember()
		document.layout = {}
		document.paint = []
		document.pieces = []
		document.objects = []
		canvas.selected_object = -1
		canvas.selected = -1
		document.base_track = ""
		document.route_override = true
		_save_draft(true)
		_build_editor_tools()))
	editor_inspector.add_child(help)

func _editor_help() -> void:
	_notice("Changes autosave to a separate WIP. Load reopens the latest saved draft or autosave. Save (Ctrl+S) updates the saved original.\n\nDrag inside a road section to move it. Drag an end dot to resize and turn it; the other end stays fixed.\n\nPC: wheel zooms at the pointer. Middle/right drag or Space + left drag pans. F fits the map. Ctrl+Z / Ctrl+Shift+Z undo/redo. Enter confirms; Esc cancels. Delete removes the selection. 1–4 switch tools. Q/E rotate. Tab cycles overlapping roads.\n\nPhone: two fingers pan/zoom. Layer selects the other road at an overpass. Bridge spans include ramps at both ends; paint edits the ground underneath.")

func _input(event: InputEvent) -> void:
	# Tab is a GUI navigation key and never reaches unhandled_key_input.
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB):
		if is_instance_valid(editor_map_panel) and editor_map_panel.visible: return
		_unhandled_key_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if screen != "create" or is_instance_valid(game) or not event is InputEventKey or not event.pressed: return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var handled: bool = true
	if event.ctrl_pressed or event.meta_pressed:
		match key:
			KEY_Z:
				if event.shift_pressed: _redo()
				elif not canvas.ghost.is_empty(): _delete_piece()
				else: _undo()
			KEY_Y: _redo()
			KEY_S: _save_track_explicit()
			_: handled = false
	else:
		match key:
			KEY_F: canvas.fit()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: canvas.zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT: canvas.zoom_by(1.0/1.15)
			KEY_ENTER, KEY_KP_ENTER:
				if canvas.mode == "road": canvas.confirm_piece()
				elif canvas.mode in ["paint","pan"]: canvas.confirm_paint()
			KEY_ESCAPE:
				canvas.cancel_gesture()
				canvas.ghost.clear()
				canvas.selected_piece = -1
				editor_geometry = ""
				editor_tools_panel.hide()
				editor_map_panel.hide()
				_build_editor_tools()
			KEY_DELETE, KEY_BACKSPACE:
				if canvas.mode == "paint" and not canvas.paint_points.is_empty():
					canvas.paint_points.pop_back()
					canvas.paint_handle = -1
					canvas.queue_redraw()
				elif canvas.mode == "road": _delete_piece()
				else: _delete_selection()
			KEY_1: _editor_category("road")
			KEY_2: _editor_category("paint")
			KEY_3: _editor_category("objects")
			KEY_4: canvas.choose_start_line()
			KEY_Q: _change_piece("heading",-15.0)
			KEY_E: _change_piece("heading",15.0)
			KEY_TAB: canvas.cycle_piece()
			_: handled = false
	if handled: get_viewport().set_input_as_handled()

func _save_track_explicit() -> void:
	if str(document.get("name", "")).strip_edges().is_empty() or str(document.get("name", "")) == "My circuit":
		_confirm_editor_departure(Callable(), false)
		return
	_save_track_now()

func _save_track_now() -> bool:
	if not _commit_editor_previews(): return false
	if _save_draft(true) != OK:
		_notice("Could not save: "+library.last_error)
		return false
	if library.save_document(document) != OK:
		editor_retry_original = true
		editor_save_error = ERR_FILE_CANT_WRITE
		editor_save_message = "Could not save: "+library.last_error
		_update_editor_save_state()
		_notice("Could not save: "+library.last_error)
		return false
	elif not TrackDocument.validate(document).is_empty():
		_notice("Draft saved. Open Load track to edit it. Before testing: "+TrackDocument.validate(document)[0])
	else:
		# Menus retain a compiled selection independently of the saved-track index.
		# Replace it after committing edits so Race cannot launch its old geometry.
		if selected_track != null and selected_track.identity == "creator_"+str(document.id):
			var saved_track: NativeTrack = TrackCompiler.compile(document)
			if saved_track != null: selected_track = saved_track
		_notice("Saved on this device. Open Load track to edit or test it.")
		editor_pending_road_bake = document.duplicate(true)
		if canvas.native_preview != null and canvas.native_preview.metadata.get("creator_document",{}) == document:
			NativeTrackVisual.request_saved_road_bake.call_deferred(canvas.native_preview)
			editor_pending_road_bake.clear()
	var saved_title: Label = root_ui.find_child("TrackName",true,false) as Label
	if saved_title != null: saved_title.text = str(document.name)
	editor_saved_snapshot = document.duplicate(true)
	editor_retry_original = false
	editor_save_error = OK
	editor_save_message = ""
	_update_editor_save_state()
	return true

func _editor_has_unsaved_changes() -> bool:
	if document.is_empty(): return false
	return editor_save_error != OK or _has_pending_editor_work() or editor_saved_snapshot.is_empty() or TrackLibrary.draft_fingerprint(document) != TrackLibrary.draft_fingerprint(editor_saved_snapshot)

func _request_editor_exit() -> void:
	if not _editor_has_unsaved_changes():
		_show_screen("tracks")
		return
	_confirm_editor_departure(_show_screen.bind("tracks"))

func _confirm_editor_departure(after: Callable, allow_discard: bool = true) -> void:
	if root_ui.find_child("SaveChangesDialog", true, false) != null: return
	var dialog := ConfirmationDialog.new()
	dialog.name = "SaveChangesDialog"
	dialog.title = "Save this draft?"
	dialog.dialog_text = "Enter a name to keep this draft. Discard removes the autosaved recovery copy."
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	var discard := dialog.add_button("Discard", true, "discard")
	discard.visible = allow_discard
	var field := LineEdit.new()
	field.name = "SaveDraftName"
	field.placeholder_text = "Track name"
	field.text = "" if str(document.get("name", "")) == "My circuit" else str(document.get("name", ""))
	field.max_length = 40
	field.custom_minimum_size = Vector2(440, 52)
	field.virtual_keyboard_enabled = true
	dialog.add_child(field)
	var update_save := func(value: String) -> void: dialog.get_ok_button().disabled = value.strip_edges().is_empty()
	field.text_changed.connect(update_save)
	update_save.call(field.text)
	dialog.confirmed.connect(func() -> void:
		dialog.hide() # Saving can open its own success/failure notice.
		document.name = field.text.strip_edges()
		if not _save_track_now():
			dialog.queue_free()
			return
		dialog.queue_free()
		if after.is_valid(): after.call())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"discard": return
		var id: String = str(document.get("id", ""))
		if TrackDocument.valid_id(id) and library.delete_wip(id) != OK:
			_notice("Could not discard the recovery draft: " + library.last_error)
			return
		dialog.queue_free()
		_discard_editor_previews()
		if after.is_valid(): after.call())
	root_ui.add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_clamped(Vector2i(520, 250))
	field.grab_focus()

func _open_saved_tracks() -> void:
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	if not canvas.ghost.is_empty():
		_notice("Confirm or cancel the preview before opening My circuits.")
		return
	if _save_draft() != OK:
		_notice("Could not save: "+library.last_error)
		return
	var saved_track: NativeTrack = TrackCompiler.compile(document)
	if saved_track != null: selected_track = saved_track
	browser_state.name = ""
	browser_state.creator = ""
	browser_state.theme = "all"
	_open_library("saved")

func _prepare_editor_load() -> bool:
	if not is_instance_valid(canvas): return true
	if _has_pending_editor_work(): return _commit_editor_previews()
	return true

var draft_return_screen: String = "biome"

func _open_drafts() -> void:
	if screen == "create" and _editor_has_unsaved_changes():
		_confirm_editor_departure(_open_drafts_after_resolution)
		return
	_open_drafts_after_resolution()

func _open_drafts_after_resolution() -> void:
	if not _prepare_editor_load(): return
	draft_return_screen = "create" if screen == "create" else "biome"
	_show_screen("drafts")

func _drafts() -> void:
	var browser: VBoxContainer = load("res://ui/draft_browser.gd").new()
	browser.name = "DraftBrowser"
	browser.set("library",library)
	browser.set("lifecycle",lifecycle)
	browser.connect("fork_requested",_fork_track_draft)
	browser.connect("edit_requested",_load_saved_document)
	browser.connect("test_requested",_test_saved_draft)
	browser.connect("publish_requested",_publish_saved_draft)
	browser.connect("back_requested",func() -> void: _show_screen(draft_return_screen if not document.is_empty() else "biome"))
	browser.connect("delete_requested",_confirm_delete_draft)
	if get_viewport().get_visible_rect().size.x < 1100 or get_viewport().get_visible_rect().size.y < 620:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(browser)
	else: content.add_child(browser)

func _fork_track_draft(source: Dictionary) -> void:
	var copy: Dictionary = source.duplicate(true)
	copy.id = TrackLibrary.unique_id()
	copy.name = str(copy.name)+" copy"
	document = copy
	_stamp_creator()
	if library.save_wip(document) != OK:
		_notice(library.last_error)
		return
	lifecycle.defer_sync(document)
	editor_view.clear()
	history.clear()
	redo_history.clear()
	_show_screen("create")

func _read_draft_for_action(id: String) -> Dictionary:
	var loaded: Dictionary = library.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else library.load_document(id)
	if loaded.is_empty():
		_notice("Could not load this draft: "+library.last_error)
	elif library.is_published(str(loaded.id)):
		_notice("This track is published and locked against editing.")
		return {}
	return loaded

func _test_saved_draft(id: String) -> void:
	var loaded: Dictionary = _read_draft_for_action(id)
	if loaded.is_empty(): return
	var route: Dictionary = RoadPieces.route_from_pieces(loaded)
	if not route.ok:
		_notice("Edit this track before testing: "+str(route.errors[0]))
		return
	if not loaded.has("start_line"):
		_notice("Place a start line in the editor before testing.")
		return
	loaded = route.document
	document = loaded
	if not await _prepare_creator_test(loaded): return
	loaded = document
	var track: NativeTrack = TrackCompiler.compile(loaded)
	if track == null:
		_notice("This track needs repairs before testing. Open Edit track for details.")
		return
	if library.save_wip(loaded) != OK:
		_notice(library.last_error)
		return
	document = loaded
	editor_view.clear()
	history.clear()
	redo_history.clear()
	track.spawn = _practice_start(track)
	track.spawn_heading = _practice_heading(track)
	await _start_race(track,true)

func _complete_draft_test() -> void:
	if not is_instance_valid(game) or test_document_snapshot.is_empty(): return
	var witness: TrackSession = game.get("practice_validation")
	if not witness.finished or not bool(game.get("practice_validation_eligible")): return
	var storage: TrackLibrary = test_library_snapshot if test_library_snapshot != null else library
	var proof_document: Dictionary = test_document_snapshot.duplicate(true)
	var proof_frames: Array = game.get("online_frames").duplicate(true)
	var staged: Dictionary = lifecycle.stage(proof_document,proof_frames,test_vehicle_snapshot,storage,test_scope_snapshot)
	if proof_frames.is_empty() or staged.is_empty() or storage.mark_tested(proof_document) != OK:
		var recovery := AcceptDialog.new()
		recovery.dialog_text = "The completed test could not be saved. Free storage, then retry saving this recording."
		recovery.ok_button_text = "Retry saving"
		_own_dialog(recovery)
		recovery.confirmed.connect(_complete_draft_test,CONNECT_DEFERRED)
		recovery.popup_centered()
		return # Keep the exact finished recording available until durable save succeeds.
	pending_menu_notice = "Test recording saved. Backend verification continues automatically."
	lifecycle.process_jobs()
	if test_return_to_drafts: _leave_race()

func _publish_saved_draft(id: String) -> void:
	var loaded: Dictionary = _read_draft_for_action(id)
	if loaded.is_empty(): return
	if online != null and online.client.signed_in():
		var original_scope: String = lifecycle.scope()
		if not await lifecycle.request_publish(loaded):
			_notice(lifecycle.last_error)
			return
		if lifecycle.scope() != original_scope: return
		if lifecycle.status_for(loaded).get("state") != "published":
			_notice(lifecycle.caption(loaded)+" Your publication request is saved and will retry.")
			return
		if not document.is_empty() and TrackLibrary.draft_fingerprint(document) == TrackLibrary.draft_fingerprint(loaded):
			document = {}
			editor_view.clear()
			history.clear()
			redo_history.clear()
		_open_published_track(lifecycle.status_for(loaded).receipt)
		_notice("Track published.")
		return
	_notice("Sign in to publish this track to the cloud. Your draft remains saved locally.")
	return

func _open_published_track(receipt: Dictionary) -> void:
	# Publishing is a direct navigation to the acknowledged public card.
	# Previous search/feed filters must not hide the track just published.
	browser_state.clear()
	browser_state.focus_track = "cloud_"+str(receipt.track_id)
	if cloud.paged_discovery_available(): browser_state.feed = "new"
	race_area_mode = "free"
	_show_screen("tracks")

func _prepare_creator_test(source: Dictionary) -> bool:
	if lifecycle == null: return true
	var original_scope: String = lifecycle.scope()
	var fingerprint: String = TrackLibrary.draft_fingerprint(source)
	cloud_starting = true
	var exact: Dictionary = await lifecycle.prepare_test(source.duplicate(true))
	cloud_starting = false
	if lifecycle.scope() != original_scope or document.is_empty() or TrackLibrary.draft_fingerprint(document) != fingerprint: return false
	if exact.is_empty():
		_notice(lifecycle.last_error)
		return false
	document = exact
	library.owner_name = str(exact.get("creator",library.owner_name))
	return library.save_wip(document) == OK

func _lifecycle_changed() -> void:
	if records != null and cloud != null: cloud.migrate_record_identities(records)
	if is_instance_valid(publish_button) and not document.is_empty():
		publish_button.disabled = not lifecycle.ready_to_publish(document)
		publish_button.tooltip_text = lifecycle.caption(document)
		if is_instance_valid(editor_status): editor_status.text = lifecycle.caption(document)

func _confirm_delete_draft(id: String, title: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "DeleteDraftDialog"
	dialog.title = "Delete draft?"
	dialog.dialog_autowrap = true
	dialog.dialog_text = 'Delete "%s" and its local autosave?\nIts private cloud draft will be archived; shared versions stay available.\nThis cannot be undone.' % title
	dialog.ok_button_text = "Delete draft"
	dialog.confirmed.connect(func() -> void:
		if lifecycle != null and not lifecycle.archive_draft(id):
			_notice(lifecycle.last_error)
			return
		if library.delete_editable(id) != OK:
			_notice(library.last_error)
			return
		if document.get("id","") == id:
			document = {}
			history.clear()
			redo_history.clear()
			editor_view.clear()
		if selected_track != null and selected_track.identity == "creator_"+id:
			selected_track = NativeTrack.read("res://resources/tracks/"+BUILTIN_IDS[0]+".json")
		var favorites: Array = records.settings.get("favorites",[]).duplicate()
		favorites.erase("creator_"+id)
		records.settings.favorites = favorites
		if records.settings.get("last_track","") == "creator_"+id: records.settings.last_track = selected_track.identity
		var settings_error: Error = records.save_records()
		_show_screen("drafts")
		if settings_error != OK: _notice("Draft deleted, but favorite settings could not be saved."))
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(500,210))
	dialog.get_cancel_button().grab_focus()

func _load_track_dialog() -> void:
	_open_drafts()

func _load_saved_document(id: String) -> void:
	var loaded: Dictionary = _read_draft_for_action(id)
	if loaded.is_empty(): return
	document = loaded
	editor_pending_tools.clear()
	editor_saved_snapshot = library.load_document(str(loaded.id)) if id.begins_with("wip:") else loaded.duplicate(true)
	canvas = null # Loading a different document must not capture the outgoing view.
	editor_view.clear()
	history.clear()
	redo_history.clear()
	editor_geometry = ""
	_show_screen("create")
	editor_status.text = "Loaded "+str(document.name)+" for editing."

func _editor_track_preview() -> NativeTrack:
	_finish_preview_thread()
	return _compile_editor_preview(document)

func _compile_editor_preview(source: Dictionary) -> NativeTrack:
	# Only the single preview worker (or its joined foreground replacement)
	# accesses this bounded cache. Undo can reuse collision and route data too.
	for entry: Dictionary in editor_compiled_cache:
		if entry.document == source: return entry.track
	var result: NativeTrack = _compile_editor_preview_uncached(source)
	if result != null:
		editor_compiled_cache.append({"document":source.duplicate(true),"track":result})
		if editor_compiled_cache.size() > 3: editor_compiled_cache.pop_front()
	return result

func _compile_editor_preview_uncached(source: Dictionary) -> NativeTrack:
	if TrackDocument.validate(source).is_empty(): return _compile_editor_with_masks(source)
	if not TrackDocument.validate(source,false).is_empty(): return null
	# A draft may have an unfinished lap. Render its actual map using a safe
	# preview-only route; never change the saved route or permit racing it.
	var preview_document: Dictionary = source.duplicate(true)
	var fallback: Dictionary = TrackDocument.create_default()
	for key: String in ["points","widths","corners"]: preview_document[key] = fallback[key]
	preview_document.route_override = true
	return _compile_editor_with_masks(preview_document)

func _compile_editor_with_masks(source: Dictionary) -> NativeTrack:
	var track: NativeTrack = TrackCompiler.compile(source,editor_raster_cache)
	if track != null:
		track.editor_overlay_mask = CreatorPreviewMasks.overlay(track,source.paint)
		track.editor_road_mask = CreatorPreviewMasks.road(track)
	return track


func _confirm_delete_track(id: String, title: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "DeleteTrackDialog"
	dialog.title = "Delete saved track?"
	dialog.dialog_text = 'Delete "%s" from this device?\nThis cannot be undone.' % title
	dialog.ok_button_text = "Delete track"
	dialog.confirmed.connect(_delete_user_track.bind(id))
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(480,190))
	dialog.get_cancel_button().grab_focus()

func _delete_user_track(id: String) -> void:
	if library.delete_document(id) != OK:
		_notice(library.last_error)
		return
	var identity: String = "creator_"+id
	if document.get("id","") == id:
		document = {}
		history.clear()
		redo_history.clear()
		editor_view.clear()
	if selected_track != null and selected_track.identity == identity:
		selected_track = NativeTrack.read("res://resources/tracks/"+BUILTIN_IDS[0]+".json")
	var favorites: Array = records.settings.get("favorites",[]).duplicate()
	favorites.erase(identity)
	records.settings["favorites"] = favorites
	if records.settings.get("last_track","") == identity: records.settings["last_track"] = selected_track.identity
	var settings_error: Error = records.save_records()
	_show_screen("tracks")
	if settings_error != OK: _notice("Track deleted, but favorite settings could not be saved.")

func _choose_object(kind: String) -> void:
	canvas.cancel_gesture()
	canvas.stamp_kind=kind
	canvas.stamp_scale=CreatorCatalog.default_scale(kind)
	object_browser.stamp_scale=canvas.stamp_scale
	canvas.selected_object=-1
	_object_placement("single")

func _object_placement(value: String) -> void:
	canvas.cancel_gesture()
	canvas.run_start=Vector2.INF
	canvas.run_preview.clear()
	canvas.run_shape="curve" if value=="curve" else "line"
	canvas.free_run=value!="road edge"
	canvas.mode="place" if value=="single" else "run"
	object_browser.placement=value
	_build_editor_tools()

func _choose_hazard(kind: String) -> void:
	canvas.cancel_gesture()
	canvas.ghost.clear()
	canvas.stamp_kind=kind
	canvas.stamp_scale=1.0
	canvas.selected_object=-1
	canvas.mode="place"
	_build_editor_tools()
	editor_status.text=CreatorObjects.description(kind)+" / tap to place; Objects > Select to adjust"


func _choose_biome(parent: VBoxContainer = null, preview: bool = false) -> void:
	if parent == null: parent = content
	parent.set_meta("biome_theme",str(document.get("theme",TrackDocument.THEMES[0])))
	if not preview and screen != "biome": return
	if document.is_empty() and not preview:
		document = TrackDocument.create_blank()
		document.id = TrackLibrary.unique_id()
		_stamp_creator()
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation",20)
	parent.add_child(heading_row)
	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_theme_constant_override("separation",2)
	heading_row.add_child(heading_copy)
	_heading("NEW TRACK", "Select biome",heading_copy)
	heading_copy.add_child(MenuStyle.label("Creator: " + library.owner_name, 18, true))
	var load_track := MenuStyle.button("LOAD TRACK",_open_drafts)
	load_track.name = "LoadTrack"
	load_track.icon = MenuIcon.texture("folder")
	load_track.custom_minimum_size = Vector2(190,58)
	load_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading_row.add_child(load_track)
	var selected_biome: String = str(document.get("theme",TrackDocument.THEMES[0]))
	if selected_biome not in TrackDocument.THEMES: selected_biome = TrackDocument.THEMES[0]
	var cards := HBoxContainer.new()
	cards.name = "BiomePicker"
	cards.add_theme_constant_override("separation",16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(cards)
	for biome: String in TrackDocument.THEMES:
		var card := Button.new()
		card.name = "Biome_"+biome
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(180,260)
		card.clip_contents = true
		card.text = ""
		var selected: bool = biome == selected_biome
		var card_style := MenuStyle.box(Color.TRANSPARENT,0)
		card_style.set_corner_radius_all(0)
		card_style.border_color = MenuStyle.BORDER
		card_style.set_border_width_all(1)
		for state: String in ["normal","hover","pressed","focus"]:
			card.add_theme_stylebox_override(state,card_style)
		var picture := TextureRect.new()
		picture.name = "BiomePicture"
		picture.texture = TrackTile.scenery_texture(biome)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.modulate = Color.WHITE if selected else Color(0.62,0.68,0.72)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyle.fill(picture)
		card.add_child(picture)
		var label_panel := PanelContainer.new()
		label_panel.name = "BiomeLabelOverlay"
		label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_panel.anchor_left = 0.0
		label_panel.anchor_top = 1.0
		label_panel.anchor_right = 1.0
		label_panel.anchor_bottom = 1.0
		label_panel.offset_top = -72
		label_panel.offset_bottom = -8
		var label_style := MenuStyle.box(MenuStyle.ACCENT if selected else Color("091720f2"),0)
		label_style.set_corner_radius_all(0)
		label_panel.add_theme_stylebox_override("panel",label_style)
		var label_center := CenterContainer.new()
		label_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_panel.add_child(label_center)
		var label_row := HBoxContainer.new()
		label_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_row.add_theme_constant_override("separation",10)
		label_center.add_child(label_row)
		var icon := TextureRect.new()
		icon.name = "BiomeIcon"
		icon.modulate = MenuStyle.INK if selected else (Color("c7dfff") if biome != "night_city" else Color("f1f4f3"))
		icon.texture = MenuIcon.texture({"pine":"leaf","desert":"cactus","night_city":"night","winter":"snowflake","storm":"storm"}.get(biome,"biomes"))
		icon.custom_minimum_size = Vector2(30,30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_row.add_child(icon)
		var label := MenuStyle.label(TrackTheme.title(biome).to_upper(),26)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if selected: label.add_theme_color_override("font_color",MenuStyle.INK)
		label_row.add_child(label)
		card.add_child(label_panel)
		card.pressed.connect(_preview_creation_biome.bind(biome))
		cards.add_child(card)
	var summary_panel := PanelContainer.new()
	summary_panel.name = "BiomeSummary"
	summary_panel.custom_minimum_size.y = 118
	summary_panel.add_theme_stylebox_override("panel",MenuStyle.card(16))
	parent.add_child(summary_panel)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation",20)
	summary_panel.add_child(summary_row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",4)
	summary_row.add_child(copy)
	var summary_title := HBoxContainer.new()
	summary_title.add_theme_constant_override("separation",10)
	copy.add_child(summary_title)
	var summary_icon := TextureRect.new()
	summary_icon.name = "BiomeSummaryIcon"
	summary_icon.modulate = Color("c7dfff") if selected_biome != "night_city" else Color("f1f4f3")
	summary_icon.texture = MenuIcon.texture({"pine":"leaf","desert":"cactus","night_city":"night","winter":"snowflake","storm":"storm"}.get(selected_biome,"biomes"))
	summary_icon.custom_minimum_size = Vector2(34,34)
	summary_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	summary_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary_title.add_child(summary_icon)
	summary_title.add_child(MenuStyle.label(TrackTheme.title(selected_biome).to_upper(),28))
	var descriptions: Dictionary = {
		"pine":"Lush forests, open fields and classic racing character. A balanced environment with clear visibility and a broad variety of scenery.",
		"desert":"Sunset canyons, compacted sand roads and dense lingering dust. Build fast, flowing routes through warm open terrain.",
		"night_city":"A moonlit waterfront city with warm street lamps and deep shadows. Shape technical routes that come alive after dark.",
		"winter":"Snow-covered forests, frozen scenery and low-grip ice. Create bright alpine circuits where smooth driving matters.",
		"storm":"Dark forest valleys, heavy rain and lightning over wet asphalt. Design dramatic routes with reduced grip and changing visibility."
	}
	var description := MenuStyle.label(str(descriptions.get(selected_biome,"Choose a setting for your new track.")),18,true)
	description.name = "BiomeDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	summary_row.add_child(VSeparator.new())
	var create := MenuStyle.button("CREATE TRACK",_select_creation_biome.bind(selected_biome),true)
	create.name = "CreateTrack"
	create.icon = MenuIcon.texture("create")
	create.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	create.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	create.add_theme_color_override("icon_pressed_color",MenuStyle.INK)
	create.custom_minimum_size = Vector2(250,70)
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.add_theme_font_size_override("font_size",26)
	summary_row.add_child(create)

func _preview_creation_biome(biome: String) -> void:
	if screen != "biome" or biome not in TrackDocument.THEMES: return
	document.theme = biome
	_show_screen("biome")

func _select_creation_biome(biome: String) -> void:
	if screen != "biome" or biome not in TrackDocument.THEMES: return
	document.theme = biome
	history.clear()
	redo_history.clear()
	_show_screen("create")

func _rename_track() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name="RenameDialog"
	dialog.borderless=true
	dialog.title="Name your track"
	dialog.ok_button_text="Apply name"
	dialog.add_theme_stylebox_override("panel",EditorStyle.box())
	EditorStyle.apply(dialog.get_ok_button())
	EditorStyle.apply(dialog.get_cancel_button())
	dialog.get_ok_button().custom_minimum_size=Vector2(130,44)
	dialog.get_cancel_button().custom_minimum_size=Vector2(110,44)
	var column := VBoxContainer.new()
	column.custom_minimum_size=Vector2(460,116)
	column.add_theme_constant_override("separation",12)
	dialog.add_child(column)
	column.add_child(MenuStyle.label("Give your track a name",22))
	var field := LineEdit.new()
	field.name="CircuitName"
	field.text=str(document.name)
	field.max_length=40
	field.custom_minimum_size=Vector2(440,52)
	field.virtual_keyboard_enabled=true
	EditorStyle.apply(field)
	field.add_theme_font_size_override("font_size",20)
	column.add_child(field)
	field.text_changed.connect(func(value: String) -> void: dialog.get_ok_button().disabled=value.strip_edges().is_empty())
	var apply_name: Callable=func() -> void:
		if field.text.strip_edges().is_empty(): return
		document.name=field.text.strip_edges()
		(root_ui.find_child("TrackName",true,false) as Label).text=document.name
		_save_draft(true)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.hide(); dialog.queue_free()
	dialog.confirmed.connect(apply_name)
	field.text_submitted.connect(func(_value: String) -> void: apply_name.call())
	dialog.canceled.connect(func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.queue_free())
	root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(500,220))
	var keyboard_timer := Timer.new()
	keyboard_timer.wait_time=0.1
	dialog.add_child(keyboard_timer)
	keyboard_timer.timeout.connect(func() -> void:
		var visible_size: Vector2=get_viewport().get_visible_rect().size
		var keyboard: float=0
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): keyboard=DisplayServer.virtual_keyboard_get_height()*visible_size.y/maxf(1.0,DisplayServer.window_get_size().y)
		dialog.position=Vector2i(_rename_dialog_position(visible_size,Vector2(dialog.size),keyboard)))
	keyboard_timer.start()
	field.grab_focus()
	field.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(field.text,field.get_viewport().get_screen_transform()*field.get_global_rect(),DisplayServer.KEYBOARD_TYPE_DEFAULT,40,0,field.text.length())

static func _rename_dialog_position(view: Vector2, dialog_size: Vector2, keyboard_height: float) -> Vector2:
	return Vector2(maxf(8,(view.x-dialog_size.x)*0.5),maxf(8,(view.y-keyboard_height-dialog_size.y)*0.5))


func _select_vehicle(index: int) -> void:
	var chosen: String = VehicleCatalog.IDS[clampi(index,0,VehicleCatalog.IDS.size()-1)]
	records.settings.selected_car = chosen
	var saved: Error = records.save_records()
	VehicleCatalog.selected = chosen
	_show_screen("garage")
	_prefetch_rivalry()
	if saved != OK: _notice("Car selected for this session. Could not save preference: " + error_string(saved))

func _build_surface_toolbar() -> void:
	for child: Node in surface_actions.get_children():
		surface_actions.remove_child(child)
		child.queue_free()
	surface_actions.add_theme_constant_override("separation",12)
	var modes := VBoxContainer.new()
	surface_actions.add_child(modes)
	var heading := MenuStyle.label("Paint mode",18)
	heading.add_theme_color_override("font_color",Color("97dce1"))
	modes.add_child(heading)
	var segments := HBoxContainer.new()
	segments.name = "SurfacePlacementModes"
	segments.add_theme_constant_override("separation",0)
	modes.add_child(segments)
	for entry: Array in [["free","Free","paint_brush"],["area","Area","paint_area"],["line","Line","paint_line"]]:
		var value: String = entry[0]
		var chosen: bool = canvas.paint_mode == value
		var button: Button = EditorButton.make(entry[1],entry[2],func() -> void:
			canvas.cancel_gesture()
			canvas.paint_mode = value
			canvas.mode = "paint"
			canvas.queue_redraw()
			_build_editor_tools(),chosen)
		button.name = "PaintMode_"+value
		button.custom_minimum_size = Vector2(78,68)
		for state: String in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat = EditorStyle.box(chosen or state in ["pressed","hover_pressed"],state=="hover",18)
			if chosen: style.bg_color = Color("087b8d")
			button.add_theme_stylebox_override(state,style)
		segments.add_child(button)
	var brush := VBoxContainer.new()
	brush.custom_minimum_size.x = 178
	surface_actions.add_child(brush)
	var size_label := MenuStyle.label("Brush size  %.1f m" % canvas.brush_width,18)
	size_label.name = "BrushSizeReadout"
	size_label.add_theme_color_override("font_color",Color("97dce1"))
	brush.add_child(size_label)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",EditorStyle.box())
	brush.add_child(panel)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	var slider := HSlider.new()
	slider.name = "BrushSizeSlider"
	slider.min_value = 0.5
	slider.max_value = 40.0
	slider.step = 0.5
	slider.value = canvas.brush_width
	slider.custom_minimum_size = Vector2(112,48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("304b54")
	rail.set_corner_radius_all(4)
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider",rail)
	var fill: StyleBoxFlat = rail.duplicate()
	fill.bg_color = EditorStyle.ACCENT
	slider.add_theme_stylebox_override("grabber_area",fill)
	slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	slider.value_changed.connect(func(value: float) -> void:
		canvas.brush_width = value
		size_label.text = "Brush size  %.1f m" % value
		canvas.queue_redraw())
	var smaller: Button = EditorStyle.button("-",func() -> void: slider.value -= 0.5)
	smaller.name = "BrushSmaller"
	smaller.custom_minimum_size = Vector2(36,48)
	controls.add_child(smaller)
	controls.add_child(slider)
	var bigger: Button = EditorStyle.button("+",func() -> void: slider.value += 0.5)
	bigger.name = "BrushBigger"
	bigger.custom_minimum_size = Vector2(36,48)
	controls.add_child(bigger)
	var options: Button = EditorButton.make("","options",func() -> void: editor_tools_panel.visible = not editor_tools_panel.visible)
	options.name = "SurfaceOptions"
	options.tooltip_text = "Brush shape, navigation and road protection"
	options.size_flags_vertical = Control.SIZE_SHRINK_END
	surface_actions.add_child(options)
