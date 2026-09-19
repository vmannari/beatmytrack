extends Node
## Local navigation and editor composition. Racing simulation stays in Game.

const GAME_SCENE: PackedScene = preload("res://core/game.tscn")
var BUILTIN_IDS: Array[String] = BuiltinTracks.ids()
var screen: String = "play"
var menu_open_costs: Dictionary = {}
var root_ui: Control
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
var track_catalog: TrackCatalog
var pending_menu_notice: String = ""
var editor_preview_thread: Thread
var editor_preview_document: Dictionary = {}
var editor_raster_cache: Dictionary = {"enabled":true}

func _exit_tree() -> void:
	_finish_preview_thread()

func _finish_preview_thread() -> void:
	if editor_preview_thread != null:
		editor_preview_thread.wait_to_finish()
		editor_preview_thread = null
	editor_preview_document = {}

func _process(_delta: float) -> void:
	if editor_preview_thread == null or editor_preview_thread.is_alive(): return
	# Finish the detailed scene between gestures, never underneath a finger.
	if is_instance_valid(canvas) and canvas.active_pointer != -99: return
	var result: NativeTrack = editor_preview_thread.wait_to_finish()
	editor_preview_thread = null
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
	var capture_screen: String = "play"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track=") or argument == "--demo": direct = true
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--screen="): capture_screen = argument.trim_prefix("--screen=")
	if direct:
		game = GAME_SCENE.instantiate()
		add_child(game)
		return
	records.load_records()
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
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	_show_screen(capture_screen)
	print("APP_READY")
	if OS.is_debug_build() and FileAccess.file_exists("user://mobile_probe.json"):
		var probe: Node = load("res://diagnostics/mobile_race_probe.gd").new()
		add_child(probe)
	if OS.is_debug_build() and FileAccess.file_exists("user://menu_probe.json"):
		add_child(load("res://diagnostics/mobile_menu_probe.gd").new())
	if not capture_path.is_empty(): _capture()

func _show_screen(next: String) -> void:
	_finish_preview_thread()
	if is_instance_valid(object_browser):
		object_browser_state={"category":object_browser.category,"recent":object_browser.recent.duplicate(),"current":object_browser.current,"placement":object_browser.placement,"stamp_scale":object_browser.stamp_scale}
	if is_instance_valid(canvas):
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
	screen = next
	canvas = null
	editor_status = null
	test_button = null
	share_button = null
	if is_instance_valid(root_ui):
		menu_layer.remove_child(root_ui)
		root_ui.queue_free()
	root_ui = Control.new()
	MenuStyle.fill(root_ui)
	root_ui.theme = MenuStyle.theme()
	menu_layer.add_child(root_ui)
	if screen == "create":
		_editor()
		return
	var background := MenuBackdrop.new()
	MenuStyle.fill(background)
	root_ui.add_child(background)
	if screen in ["play","garage"]:
		var stage := MenuStage.new()
		stage.setting = str(selected_track.metadata.get("theme","pine"))
		stage.garage = screen == "garage"
		MenuStyle.fill(stage)
		root_ui.add_child(stage)
		var scrim := MenuScrim.new()
		MenuStyle.fill(scrim)
		root_ui.add_child(scrim)
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
	layout.add_child(nav)
	nav.add_child(MenuBrand.new())
	var tabs := HBoxContainer.new()
	tabs.name = "MenuNavigation"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 4)
	nav.add_child(tabs)
	for item: Array in [["play","HOME"],["tracks","PLAY"],["create","CREATE"],["garage","GARAGE"]]:
		var id: String = item[0]
		var button: Button = MenuStyle.tab(item[1], _new_document if id == "create" else _show_screen.bind(id), screen == id)
		button.name = "Tab_" + id
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var identity := MenuStyle.label("SMALL TRACKS.\nBIG STORIES.", 15, true)
	identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(identity)
	var settings: Button = MenuStyle.button("",_show_screen.bind("play" if screen == "settings" else "settings"))
	settings.icon = MenuIcon.texture("settings")
	settings.tooltip_text = "Back to Home" if screen == "settings" else "Settings"
	settings.name = "MenuSettings"
	settings.custom_minimum_size = Vector2(54,54)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(settings)
	layout.add_child(HSeparator.new())
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	match screen:
		"biome": _choose_biome()
		"tracks": _tracks()
		"create": _editor()
		"garage": _garage()
		"settings": _settings()
		_: _home()

func _heading(eyebrow: String, title: String, parent: VBoxContainer = null) -> void:
	if parent == null: parent = content
	parent.add_child(MenuStyle.label(eyebrow, 15, true))
	parent.add_child(MenuStyle.label(title, 32))

func _home() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var scene_copy := VBoxContainer.new()
	scene_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scene_copy)
	var slogan := MenuStyle.label("SMALL TRACKS. BIG STORIES.",40)
	slogan.add_theme_color_override("font_shadow_color",Color(0.02,0.06,0.08,0.85))
	slogan.add_theme_constant_override("shadow_offset_x",1)
	slogan.add_theme_constant_override("shadow_offset_y",2)
	scene_copy.add_child(slogan)
	var controls := MenuStyle.label("WASD / arrows to steer  ·  Space to brake" if not OS.has_feature("mobile") else "Steer left. Pedals right. Make it yours.",17)
	controls.add_theme_color_override("font_shadow_color",MenuStyle.INK)
	controls.add_theme_constant_override("shadow_offset_y",2)
	scene_copy.add_child(controls)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_copy.add_child(space)
	var shortcuts := HBoxContainer.new()
	scene_copy.add_child(shortcuts)
	_feature(shortcuts,"EXPLORE CIRCUITS","%d tracks to make your own" % BUILTIN_IDS.size(),_open_library.bind("all"))
	_feature(shortcuts,"YOUR FAVORITES","%d saved for another run" % records.settings.get("favorites",[]).size(),_open_library.bind("favorites"))
	var invite: VBoxContainer = _menu_card(row)
	invite.add_theme_constant_override("separation",6)
	var eyebrow := MenuStyle.label("TIME ATTACK  /  SELECTED CIRCUIT",16)
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	invite.add_child(eyebrow)
	invite.add_child(MenuStyle.button(VehicleCatalog.title() + "  /  Change car",_show_screen.bind("garage")))
	var title := MenuStyle.label(track_title(selected_track).to_upper(),48)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = track_title(selected_track)
	invite.add_child(title)
	var route_row := HBoxContainer.new()
	invite.add_child(route_row)
	var outline := CircuitEmblem.new()
	outline.track = selected_track
	outline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_row.add_child(outline)
	var facts := VBoxContainer.new()
	facts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	route_row.add_child(facts)
	facts.add_child(MenuStyle.label("5 LAPS",25))
	facts.add_child(MenuStyle.label("Standing start",16,true))
	facts.add_child(MenuStyle.label(str(selected_track.metadata.get("theme","pine")).to_upper(),16,true))
	invite.add_child(HSeparator.new())
	var best: float = records.best_for(selected_track,HandlingSelection.config())
	invite.add_child(MenuStyle.label("YOUR TIME TO BEAT" if best > 0.0 else "YOUR FIRST RUN",16,true))
	var target := MenuStyle.label(MenuStyle.time_text(best) if best > 0.0 else "SET YOUR FIRST TIME",36)
	target.name = "RaceTarget"
	invite.add_child(target)
	var instruction := MenuStyle.label("Five laps. Find your next tenth." if best > 0.0 else "Finish five laps. Then beat your time.",17,true)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invite.add_child(instruction)
	var card_space := Control.new()
	card_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	invite.add_child(card_space)
	var race: Button = MenuStyle.button("RACE",_start_race.bind(selected_track,false),true)
	race.name = "StartRace"
	race.icon = MenuIcon.texture("arrow")
	race.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	race.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	race.custom_minimum_size.y = 66
	race.add_theme_font_size_override("font_size",30)
	invite.add_child(race)
	invite.add_child(MenuStyle.button("Change circuit",_open_library.bind("all")))

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

func _tracks() -> void:
	var began: int = Time.get_ticks_usec()
	var browser := TrackBrowser.new()
	var created: int = Time.get_ticks_usec()
	browser.name = "TrackBrowser"
	browser.library = library
	if track_catalog == null: track_catalog = TrackCatalog.new(library)
	browser.catalog = track_catalog
	browser.records = records
	browser.builtin_ids = BUILTIN_IDS
	browser.selected_track = selected_track
	browser.state = browser_state
	browser.race_requested.connect(func(track: NativeTrack) -> void: _start_race(track,false))
	browser.track_selected.connect(func(track: NativeTrack) -> void: selected_track = track)
	browser.import_requested.connect(_import_dialog)
	browser.delete_requested.connect(_confirm_delete_track)
	browser.notice.connect(_notice)
	browser.edit_requested.connect(func(doc: Dictionary) -> void:
		document = doc.duplicate(true)
		editor_view.clear()
		history.clear()
		redo_history.clear()
		_show_screen("create"))
	content.add_child(browser)
	menu_open_costs = {"browser_new_ms":(created-began)/1000.0,"browser_ready_ms":(Time.get_ticks_usec()-created)/1000.0}

func _garage() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
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
	_feature(footer,track_title(selected_track).to_upper()+" · 5 LAPS","Return to your selected circuit",_show_screen.bind("play"))
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
	var race := MenuStyle.button("RACE  →",_start_race.bind(selected_track,false),true)
	race.custom_minimum_size.y = 64
	info.add_child(race)
	info.add_child(MenuStyle.button("Choose circuit",_open_library.bind("all")))

func _settings() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size.x = 360
	columns.add_child(intro)
	intro.add_child(MenuStyle.label("MAKE YOURSELF\nCOMFORTABLE.",44))
	var help := MenuStyle.label("Your controls. Your racing line.",20,true)
	intro.add_child(help)
	var air := Control.new()
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro.add_child(air)
	intro.add_child(MenuStyle.button("Back to Home",_show_screen.bind("play")))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(panel)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation",14)
	panel.add_child(settings)
	settings.add_child(MenuStyle.label("DRIVING CONTROLS",28))
	settings.add_child(MenuStyle.label("Set up your touch controls for a comfortable reach.",18,true))
	var handedness := CheckButton.new()
	handedness.text = "Left-handed pedals"
	handedness.custom_minimum_size.y = 60
	handedness.button_pressed = ui_left_handed
	handedness.toggled.connect(func(value: bool) -> void:
		ui_left_handed = value
		_save_settings())
	settings.add_child(handedness)
	settings.add_child(HSeparator.new())
	settings.add_child(MenuStyle.label("TOUCH BUTTON SIZE", 16, true))
	var row := HBoxContainer.new()
	settings.add_child(row)
	for pair: Array in [[1.0,"Standard"],[1.2,"Large"],[1.4,"Extra large"]]:
		var scale: float = pair[0]
		var option := MenuStyle.button(pair[1], func() -> void:
			ui_touch_scale = scale
			_save_settings()
			_show_screen("settings"), is_equal_approx(ui_touch_scale, scale))
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(option)
	settings.add_child(HSeparator.new())
	settings.add_child(MenuStyle.label("KEYBOARD",16,true))
	for hint: String in ["WASD / arrows   Steer and accelerate", "Space   Brake     ·     R   Retry     ·     Esc   Pause", "Editor: drag to move, scroll or pinch to zoom."]:
		var label := MenuStyle.label(hint,18,true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		settings.add_child(label)

func _save_settings() -> void:
	records.settings.touch_scale = ui_touch_scale
	records.settings.left_handed = ui_left_handed
	if records.save_records() != OK: _notice("Settings could not be saved. Check free storage space.")

func _new_document() -> void:
	_save_draft()
	_finish_preview_thread()
	editor_view.clear()
	object_browser_state.clear()
	canvas = null
	document = TrackDocument.create_blank()
	document.id = TrackLibrary.unique_id()
	history.clear()
	redo_history.clear()
	_show_screen("biome")
	object_browser = null
	object_browser_state.clear()

func _editor() -> void:
	if document.is_empty():
		document = TrackDocument.create_blank()
		document.id = TrackLibrary.unique_id()
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
		_remember()
		if canvas.mode in ["move","add"]: document.route_override = true)
	canvas.document_changed.connect(func() -> void:
		canvas.refresh()
		test_button.disabled = true
		share_button.disabled = true)
	canvas.edit_finished.connect(func() -> void: _save_draft(true))
	canvas.hint_changed.connect(func(value: String) -> void: editor_status.text = value)
	var overlay := Control.new()
	overlay.name = "EditorOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(overlay)
	MenuStyle.fill(overlay)
	var close: Button = EditorButton.make("","close",func() -> void:
		_save_draft()
		_show_screen("play"))
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
	top.offset_left = -376; top.offset_right = -80; top.offset_top = 16
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
	surface_toolbar.offset_top = 8
	surface_toolbar.offset_bottom = 110
	surface_toolbar.resized.connect(func() -> void:
		surface_toolbar.offset_left = -surface_toolbar.size.x*0.5
		surface_toolbar.offset_right = surface_toolbar.size.x*0.5)
	surface_actions = HBoxContainer.new()
	surface_actions.add_theme_constant_override("separation",8)
	surface_toolbar.add_child(surface_actions)
	editor_status = MenuStyle.label("",17)
	editor_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(editor_status)
	# Retain status text for internal feedback consumers, without a canvas-wide hint bar.
	editor_status.hide()
	object_browser = ObjectBrowser.new()
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
	_build_editor_tools()
	_refresh_editor()
	var preview_track: NativeTrack = _editor_track_preview()
	if preview_track != null: canvas.show_native(preview_track)
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

func _editor_category(value: String) -> void:
	if value in ["waypoints","move","add"]: value = "road"
	canvas.cancel_gesture()
	canvas.ghost.clear()
	canvas.run_start = Vector2.INF
	canvas.run_preview.clear()
	canvas.mode = value
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
	editor_status.offset_top = -190 if browsing else -132
	editor_status.offset_bottom = -161 if browsing else -103
	for key: String in editor_mode_buttons: (editor_mode_buttons[key] as Button).set_pressed_no_signal(key == category)
	surface_toolbar.visible = category == "paint"
	var track_title: Label = root_ui.find_child("TrackName",true,false)
	if track_title != null: track_title.custom_minimum_size.x = 130 if category == "paint" else 220
	if category == "paint":
		if canvas.brush_surface == 0: canvas.brush_surface = 2
		_build_surface_toolbar()
	if category == "road":
		var piece: Dictionary = canvas.ghost if not canvas.ghost.is_empty() else document.pieces[canvas.selected_piece] if canvas.selected_piece >= 0 else {}
		if piece.is_empty():
			_context_button("Start line","race",canvas.choose_start_line)
			for pair: Array in [["straight","Straight"],["curve","Curve"],["s_bend","S-bend"],["hairpin","Hairpin"],["bridge","Bridge"]]:
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
	canvas.refresh()

func _change_piece(key: String, delta: float) -> void:
	var is_ghost: bool = not canvas.ghost.is_empty()
	if not is_ghost and canvas.selected_piece < 0: return
	var piece: Dictionary = (canvas.ghost if is_ghost else document.pieces[canvas.selected_piece]).duplicate(true)
	var before: Dictionary = piece.duplicate(true)
	if piece.kind == "s_bend" and key == "length": return
	if key == "flip": piece.flip = not piece.flip
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
		_save_draft()
	_build_editor_tools()

func _delete_piece() -> void:
	if not canvas.ghost.is_empty(): canvas.ghost.clear()
	elif canvas.selected_piece >= 0:
		_remember()
		document.pieces.remove_at(canvas.selected_piece)
		canvas.selected_piece = -1
		_save_draft()
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
		editor_issues.append({"message":join.message,"position":join.position,"object":-1,"index":join.index})
	editor_issue_button.text = "%d issue%s" % [editor_issues.size(),"s" if editor_issues.size() != 1 else ""]
	editor_issue_button.visible = not editor_issues.is_empty()
	_update_test_access()
	canvas.queue_redraw()

func _update_test_access() -> void:
	if not is_instance_valid(test_button) or not is_instance_valid(canvas): return
	var has_road: bool = not document.pieces.is_empty() or not document.layout.is_empty() or not document.paint.is_empty() or document.base_track != ""
	test_button.disabled = editor_preview_thread != null or not TrackDocument.validate(document).is_empty() or not has_road or not canvas.ghost.is_empty()
	if not editor_issues.is_empty() and int(editor_issues[0].object) != -1: test_button.disabled = true

func _focus_issue() -> void:
	if editor_issues.is_empty(): return
	var issue: Dictionary = editor_issues[0]
	_editor_category("objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road")
	canvas.issue_marker = issue.position
	canvas.issue_text = issue.message
	canvas.pan += canvas.size*0.5-canvas.to_screen(issue.position)
	if int(issue.object) >= 0: canvas.selected_object = issue.object
	elif int(issue.object) == -1: canvas.selected_piece = issue.index
	_build_editor_tools()
	editor_status.text = issue.message+" · drag to move, or delete the selection"
	if int(issue.object) == -2: editor_status.text = issue.message+" · paint Road over the obstacle, or place a start line under Track"
	canvas.refresh()

func _commit_selection() -> void:
	if canvas.mode in ["move","add"]: document.route_override = true
	canvas.refresh()
	_save_draft()
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
	var dialog := ConfirmationDialog.new()
	dialog.title = "Track creator"
	var input := LineEdit.new()
	input.placeholder_text = "Creator name (shown in track search)"
	input.text = str(document.get("creator",""))
	input.max_length = 40
	input.custom_minimum_size = Vector2(450,60)
	dialog.add_child(input)
	dialog.confirmed.connect(func() -> void:
		var value: String = input.text.strip_edges()
		if not value.is_empty():
			_remember()
			document["creator"] = value
			_save_draft())
	_own_dialog(dialog)
	dialog.popup_centered()
	input.grab_focus()

func _remember() -> void:
	history.append(document.duplicate(true))
	if history.size() > 40: history.pop_front()
	redo_history.clear()

func _set_document_value(key: String, value: Variant) -> void:
	if key in ["theme", "biome"]: return
	_remember()
	document[key] = value
	_save_draft()
	_show_screen("create")

func _undo() -> void:
	if history.is_empty(): return
	redo_history.append(document.duplicate(true))
	document = history.pop_back()
	_save_draft()
	_show_screen("create")

func _redo() -> void:
	if redo_history.is_empty(): return
	history.append(document.duplicate(true))
	document = redo_history.pop_back()
	_save_draft()
	_show_screen("create")

func _refresh_editor() -> void:
	if not is_instance_valid(editor_status): return
	var errors: Array[String] = TrackDocument.validate(document)
	editor_status.text = "Waypoints are generated from connected roads. Changes save automatically." if errors.is_empty() else errors[0]
	test_button.disabled = not errors.is_empty()
	share_button.disabled = not errors.is_empty()
	if is_instance_valid(canvas): canvas.refresh()

func _save_draft(background_preview: bool = false) -> Error:
	if not background_preview: _finish_preview_thread()
	if document.is_empty(): return ERR_INVALID_DATA
	if not document.pieces.is_empty():
		var auto_route: Dictionary = RoadPieces.route_from_pieces(document)
		if auto_route.ok:
			for key: String in ["points","widths","corners","route_override"]: document[key] = auto_route.document[key]
	var errors: Array[String] = TrackDocument.validate(document)
	var message: String
	var save_error: Error = library.save_wip(document)
	if save_error != OK: message = "Could not save: " + library.last_error
	elif not errors.is_empty(): message = "Draft saved. Before driving: " + errors[0]
	else: message = "WIP autosaved. Saved original unchanged."
	if is_instance_valid(editor_status):
		editor_status.text = message
		test_button.disabled = not errors.is_empty()
		share_button.disabled = not errors.is_empty()
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(canvas):
		if is_instance_valid(editor_undo): editor_undo.disabled = history.is_empty()
		if is_instance_valid(editor_redo): editor_redo.disabled = redo_history.is_empty()
		if background_preview and (canvas.road_approval_pending or _objects_only_edit()):
			if not canvas.road_approval_pending: editor_world.preview_objects(document)
			canvas.queue_redraw()
			test_button.disabled = true
			_queue_editor_preview()
		else:
			var preview_track: NativeTrack = _editor_track_preview()
			if preview_track != null: canvas.show_native(preview_track)
			_update_editor_issues()
	return save_error

func _test_document() -> void:
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	if not canvas.ghost.is_empty():
		editor_status.text = "Confirm or cancel the preview before testing."
		return
	_save_draft()
	var track: NativeTrack = TrackCompiler.compile(document)
	if track != null and not test_button.disabled:
		track.spawn = _practice_start(track)
		track.spawn_heading = _practice_heading(track)
		_start_race(track, true)

func _share_dialog() -> void:
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	_save_draft()
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

func _start_race(track: NativeTrack, from_editor: bool) -> void:
	returning_to_editor = from_editor
	if not from_editor:
		records.settings["last_track"] = track.identity
		if records.save_records() != OK:
			pending_menu_notice = "This circuit could not be remembered for next time. Check available storage."
	if is_instance_valid(canvas):
		canvas.cancel_gesture()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"stamp_scale":canvas.stamp_scale,"run_shape":canvas.run_shape,"free_run":canvas.free_run,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"paint_mode":canvas.paint_mode,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
	root_ui.visible = false
	game = GAME_SCENE.instantiate()
	game.set("initial_track", track)
	game.set("production_mode", true)
	game.set("editor_test", from_editor)
	game.connect("exit_requested", _leave_race)
	game.connect("edit_here_requested", _edit_here)
	game.connect("race_completed", _results)
	game.connect("retry_requested", _retry_race)
	add_child(game)
	var hud: PlaygroundHUD = game.get("hud")
	hud.touch.control_scale = ui_touch_scale
	hud.touch.left_handed = ui_left_handed

func _edit_here(position: Vector2) -> void:
	_leave_race()
	if is_instance_valid(canvas):
		canvas.pan += canvas.size*0.5-canvas.to_screen(position)
		canvas.refresh()

func _leave_race() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null
	_show_screen("create" if returning_to_editor else "tracks")
	if not pending_menu_notice.is_empty():
		_notice(pending_menu_notice)
		pending_menu_notice = ""

func _results() -> void:
	var session: TrackSession = game.get("track_session")
	var track: NativeTrack = game.get("native_track")
	var total: float = session.race_time_seconds()
	var clean: bool = not bool(game.get("attempt_practice")) and not returning_to_editor and session.shortcut_count == 0
	var previous: float = records.best_for(track, game.get("handling"))
	var saved: bool = not clean
	if clean: saved = records.record(track, game.get("handling"), total, session.lap_times) == OK
	(game.get("hud") as PlaygroundHUD).hide()
	root_ui.visible = true
	for child: Node in root_ui.get_children():
		root_ui.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.025,0.075,0.105,0.88)
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var center := CenterContainer.new()
	MenuStyle.fill(center)
	root_ui.add_child(center)
	var panel := RaceResults.new()
	panel.circuit = track_title(track)
	panel.vehicle_name = VehicleCatalog.title(game.vehicle_id)
	panel.total = total
	panel.previous = previous
	panel.best = records.best_for(track,game.get("handling"))
	panel.laps = session.lap_times.duplicate()
	panel.clean = clean
	panel.saved = saved
	panel.editor = returning_to_editor
	panel.retry_requested.connect(_retry_race)
	panel.return_requested.connect(_leave_race)
	center.add_child(panel)

func _retry_race() -> void:
	root_ui.visible = false
	(game.get("hud") as PlaygroundHUD).show()
	game.call("restart")

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
		_save_draft()
		_build_editor_tools()))
	editor_inspector.add_child(help)

func _editor_help() -> void:
	_notice("Changes autosave to a separate WIP. Load can reopen the WIP or original. Save (Ctrl+S) updates the saved original.\n\nDrag inside a road section to move it. Drag an end dot to resize and turn it; the other end stays fixed.\n\nPC: wheel zooms at the pointer. Middle/right drag or Space + left drag pans. F fits the map. Ctrl+Z / Ctrl+Shift+Z undo/redo. Enter confirms; Esc cancels. Delete removes the selection. 1–4 switch tools. Q/E rotate. Tab cycles overlapping roads.\n\nPhone: two fingers pan/zoom. Layer selects the other road at an overpass. Bridge spans include ramps at both ends; paint edits the ground underneath.")

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
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	if not canvas.ghost.is_empty():
		canvas.confirm_piece()
		if not canvas.ghost.is_empty():
			_notice("The preview cannot be placed here. Move or cancel it before saving.")
			return
	if _save_draft() != OK:
		_notice("Could not save: "+library.last_error)
		return
	if library.save_document(document) != OK:
		_notice("Could not save: "+library.last_error)
	elif not TrackDocument.validate(document).is_empty():
		_notice("Draft saved. You can reopen it in My circuits. Before driving: "+TrackDocument.validate(document)[0])
	else:
		# Menus retain a compiled selection independently of the saved-track index.
		# Replace it after committing edits so Race cannot launch its old geometry.
		if selected_track != null and selected_track.identity == "creator_"+str(document.id):
			var saved_track: NativeTrack = TrackCompiler.compile(document)
			if saved_track != null: selected_track = saved_track
		_notice("Saved on this device. Choose Saved tracks in the circuit library to drive it.")

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
	if not canvas.ghost.is_empty():
		canvas.confirm_piece()
		if not canvas.ghost.is_empty():
			_notice("Move or cancel the preview before loading another track.")
			return false
	if _save_draft() != OK:
		_notice("Could not save the current track: "+library.last_error)
		return false
	return true

func _load_track_dialog() -> void:
	if not canvas.paint_points.is_empty():
		_notice("Confirm or cancel the surface preview first.")
		return
	var saved: Array[Dictionary] = library.list_documents()
	for wip: Dictionary in library.list_wips():
		var item: Dictionary=wip.duplicate(true)
		item["_wip"]=true
		saved.append(item)
	saved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	var dialog := ConfirmationDialog.new()
	dialog.name = "LoadTrackDialog"
	dialog.title = "Saved tracks"
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Load for editing"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500,300)
	box.add_theme_constant_override("separation",12)
	dialog.add_child(box)
	var summary := MenuStyle.label("Choose a saved track to edit.",18,true)
	summary.name = "SavedTrackCount"
	box.add_child(summary)
	var search := LineEdit.new()
	search.name = "LoadSearch"
	search.placeholder_text = "Search saved tracks"
	search.custom_minimum_size.y = 48
	box.add_child(search)
	var choices := ItemList.new()
	choices.name = "SavedDrafts"
	choices.custom_minimum_size = Vector2(500,224)
	choices.add_theme_font_size_override("font_size",20)
	choices.add_theme_constant_override("v_separation",18)
	box.add_child(choices)
	var filter: Callable = func(query: String) -> void:
		choices.clear()
		for draft: Dictionary in saved:
			if not query.is_empty() and not (str(draft.name)+" "+str(draft.get("creator",""))).to_lower().contains(query.to_lower()): continue
			var label: String = str(draft.name)+(" (WIP)" if draft.get("_wip",false) else "")
			if not TrackDocument.validate(draft).is_empty(): label += " (draft)"
			var index: int = choices.add_item(label)
			choices.set_item_metadata(index,("wip:" if draft.get("_wip",false) else "")+str(draft.id))
		if choices.item_count > 0: choices.select(0)
		dialog.get_ok_button().disabled = choices.item_count == 0
		summary.text = "%d saved tracks" % choices.item_count if choices.item_count > 0 else ("No saved tracks yet." if saved.is_empty() else "No tracks match your search.")
	search.text_changed.connect(filter)
	filter.call("")
	var open_selected: Callable = func() -> void:
		var selected: PackedInt32Array = choices.get_selected_items()
		if selected.is_empty(): return
		if not _prepare_editor_load(): return
		_load_saved_document(str(choices.get_item_metadata(selected[0])))
	choices.item_activated.connect(func(_index: int) -> void: open_selected.call())
	dialog.confirmed.connect(open_selected)
	root_ui.add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540,400))
	choices.grab_focus()

func _load_saved_document(id: String) -> void:
	var loaded: Dictionary = library.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else library.load_document(id)
	if loaded.is_empty():
		_notice("Could not load this track: "+library.last_error)
		return
	document = loaded
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
	if TrackDocument.validate(source).is_empty(): return TrackCompiler.compile(source,editor_raster_cache)
	if not TrackDocument.validate(source,false).is_empty(): return null
	# A draft may have an unfinished lap. Render its actual map using a safe
	# preview-only route; never change the saved route or permit racing it.
	var preview_document: Dictionary = source.duplicate(true)
	var fallback: Dictionary = TrackDocument.create_default()
	for key: String in ["points","widths","corners"]: preview_document[key] = fallback[key]
	preview_document.route_override = true
	return TrackCompiler.compile(preview_document,editor_raster_cache)


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


func _choose_biome() -> void:
	if screen != "biome": return
	_heading("NEW TRACK", "Choose your biome")
	content.add_child(MenuStyle.label("This choice is permanent for this track. Each biome has its own nature objects.",18))
	var cards := HBoxContainer.new()
	cards.name = "BiomePicker"
	cards.add_theme_constant_override("separation",16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cards)
	for biome: String in TrackDocument.THEMES:
		var card := Button.new()
		card.name = "Biome_"+biome
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(180,260)
		card.icon = load("res://assets/editor/biome_"+biome+".svg")
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.text = TrackTheme.title(biome)
		card.add_theme_font_size_override("font_size",26)
		card.add_theme_constant_override("outline_size",0)
		card.pressed.connect(_select_creation_biome.bind(biome))
		cards.add_child(card)

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
		_save_draft()
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
