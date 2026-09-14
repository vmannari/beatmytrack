extends Node
## Local navigation and editor composition. Racing simulation stays in Game.

const GAME_SCENE: PackedScene = preload("res://core/game.tscn")
var BUILTIN_IDS: Array[String] = BuiltinTracks.ids()
var screen: String = "play"
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
var editor_context: HBoxContainer
var editor_confirm: Button
var editor_issue_button: Button
var editor_issues: Array[Dictionary] = []
var editor_geometry: String = ""
var editor_inspector: VBoxContainer
var browser_state: Dictionary = {}
var track_catalog: TrackCatalog
var pending_menu_notice: String = ""

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
	if not capture_path.is_empty(): _capture()

func _show_screen(next: String) -> void:
	if is_instance_valid(canvas):
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
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
		MenuStyle.fill(stage)
		root_ui.add_child(stage)
		var scrim := MenuScrim.new()
		MenuStyle.fill(scrim)
		root_ui.add_child(scrim)
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		var factor: float = get_viewport().get_visible_rect().size.y / maxf(1.0, window.y)
		margin.add_theme_constant_override("margin_left", maxi(24, ceili(safe.position.x * factor)))
		margin.add_theme_constant_override("margin_right", maxi(24, ceili((window.x - safe.end.x) * factor)))
	root_ui.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var nav := HBoxContainer.new()
	layout.add_child(nav)
	var logo := MenuStyle.label("BEAT MY TRACK", 30)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(logo)
	nav.add_child(MenuStyle.tab("Back to race" if screen == "settings" else "Settings", _show_screen.bind("play" if screen == "settings" else "settings")))
	var tabs := HBoxContainer.new()
	nav.add_child(tabs)
	for item: Array in [["play","Race"],["tracks","Tracks"],["garage","Garage"],["create","Create"]]:
		var id: String = item[0]
		var button: Button = MenuStyle.tab(item[1], _show_screen.bind(id), screen == id)
		button.name = "Tab_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	nav.move_child(nav.get_child(1),nav.get_child_count()-1)
	var separator := HSeparator.new()
	layout.add_child(separator)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	match screen:
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
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var invite := VBoxContainer.new()
	invite.custom_minimum_size.x = 410
	invite.add_theme_constant_override("separation",10)
	row.add_child(invite)
	invite.add_child(MenuStyle.label("TIME ATTACK",18,true))
	var title := MenuStyle.label(track_title(selected_track).to_upper(),62)
	title.clip_text = true
	invite.add_child(title)
	invite.add_child(MenuStyle.label("5 LAPS   ·   STANDING START",18,true))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	invite.add_child(spacer)
	var best: float = records.best_for(selected_track,load("res://resources/balanced.tres") as HandlingConfig)
	invite.add_child(MenuStyle.label("YOUR TIME TO BEAT" if best > 0.0 else "YOUR FIRST RUN",16,true))
	var target := MenuStyle.label(MenuStyle.time_text(best) if best > 0.0 else "NO TIME SET",46)
	target.name = "RaceTarget"
	invite.add_child(target)
	var instruction := MenuStyle.label("Beat your best five-lap race." if best > 0.0 else "Finish five laps. Then beat your time.",18,true)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invite.add_child(instruction)
	if best <= 0.0:
		var controls := MenuStyle.label("Steer with the arrows or WASD. Space brakes." if not OS.has_feature("mobile") else "Use the steering and pedal buttons to drive.",16,true)
		controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		invite.add_child(controls)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	invite.add_child(space)
	var race: Button = MenuStyle.button("START RACE",_start_race.bind(selected_track,false),true)
	race.name = "StartRace"
	race.custom_minimum_size.y = 66
	race.add_theme_font_size_override("font_size",30)
	invite.add_child(race)
	invite.add_child(MenuStyle.tab("Change circuit",_open_library.bind("all")))
	var open_space := Control.new()
	open_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(open_space)
	var car_info := VBoxContainer.new()
	car_info.custom_minimum_size.x = 270
	row.add_child(car_info)
	var outline := CircuitEmblem.new()
	outline.track = selected_track
	car_info.add_child(outline)
	var above := Control.new()
	above.size_flags_vertical = Control.SIZE_EXPAND_FILL
	car_info.add_child(above)
	car_info.add_child(MenuStyle.label("COMPACT / 01",32))
	car_info.add_child(MenuStyle.label("Balanced handling · Rear-wheel drive",16,true))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",24)
	content.add_child(footer)
	_feature(footer,"EXPLORE CIRCUITS","%d tracks · Name and creator search" % BUILTIN_IDS.size(),_open_library.bind("all"))
	_feature(footer,"YOUR FAVORITES","%d saved · Pick a track or try a random one" % records.settings.get("favorites",[]).size(),_open_library.bind("favorites"))
	_feature(footer,"CREATE & SHARE","Build a circuit. Let someone else beat it.",_show_screen.bind("create"))

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
	var browser := TrackBrowser.new()
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
	browser.notice.connect(_notice)
	browser.edit_requested.connect(func(doc: Dictionary) -> void:
		document = doc.duplicate(true)
		editor_view.clear()
		history.clear()
		redo_history.clear()
		_show_screen("create"))
	content.add_child(browser)

func _garage() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 410
	row.add_child(info)
	_heading("YOUR CAR", "COMPACT / 01",info)
	info.add_child(MenuStyle.label("REAR-WHEEL DRIVE",18,true))
	var description := MenuStyle.label("A compact built for short circuits. Brake before the corner, then accelerate through the exit.",20,true)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	info.add_child(HSeparator.new())
	var handling: HandlingConfig = load("res://resources/balanced.tres")
	info.add_child(MenuStyle.label("HANDLING     "+handling.profile_name.to_upper(),22))
	info.add_child(MenuStyle.label("MASS              %d kg" % roundi(handling.mass),22))
	info.add_child(MenuStyle.label("SPEED LIMIT   %d km/h" % roundi(handling.maximum_speed*3.6),22))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(space)
	info.add_child(MenuStyle.button("Test drive",_start_race.bind(selected_track,false),true))
	info.add_child(MenuStyle.tab("Choose circuit",_open_library.bind("all")))
	var footer := HBoxContainer.new()
	content.add_child(footer)
	_feature(footer,"ON THE GRID",track_title(selected_track)+" · Five laps",_show_screen.bind("play"))
	_feature(footer,"DRIVING CONTROLS","Pedal layout and touch-button size",_show_screen.bind("settings"))

func _settings() -> void:
	_heading("SETTINGS", "Make yourself comfortable.")
	content.add_child(MenuStyle.label("Driving controls", 24))
	var handedness := CheckButton.new()
	handedness.text = "Left-handed pedals"
	handedness.custom_minimum_size.y = 60
	handedness.button_pressed = ui_left_handed
	handedness.toggled.connect(func(value: bool) -> void:
		ui_left_handed = value
		_save_settings())
	content.add_child(handedness)
	content.add_child(MenuStyle.label("Touch button size", 18, true))
	var row := HBoxContainer.new()
	content.add_child(row)
	for pair: Array in [[1.0,"Standard"],[1.2,"Large"],[1.4,"Extra large"]]:
		var scale: float = pair[0]
		row.add_child(MenuStyle.button(pair[1], func() -> void:
			ui_touch_scale = scale
			_save_settings()
			_show_screen("settings"), is_equal_approx(ui_touch_scale, scale)))
	content.add_child(MenuStyle.label("Keyboard: WASD or arrows to drive. Space brakes. R retries. Esc pauses.", 18, true))
	content.add_child(MenuStyle.label("Editor: drag a handle; drag the background to pan. Pinch or use + / - to zoom.", 18, true))

func _save_settings() -> void:
	records.settings.touch_scale = ui_touch_scale
	records.settings.left_handed = ui_left_handed
	if records.save_records() != OK: _notice("Settings could not be saved. Check free storage space.")

func _new_document() -> void:
	if not document.is_empty() and not TrackDocument.validate(document,false).is_empty():
		_notice("Fix or undo the unsaved route change before starting another circuit.")
		return
	_save_draft()
	editor_view.clear()
	canvas = null
	document = TrackDocument.create_blank()
	document.id = TrackLibrary.unique_id()
	history.clear()
	redo_history.clear()
	_show_screen("create")

func _editor() -> void:
	if document.is_empty():
		document = TrackDocument.create_blank()
		document.id = TrackLibrary.unique_id()
	editor_world = EditorWorld.new()
	root_ui.add_child(editor_world)
	MenuStyle.fill(editor_world)
	canvas = EditorCanvas.new()
	canvas.document = document
	canvas.world_backdrop = true
	if not editor_view.is_empty():
		canvas.zoom = editor_view.zoom
		canvas.pan = editor_view.pan
		canvas.mode = editor_view.mode
		canvas.selected = mini(int(editor_view.get("selected",-1)),document.points.size()-1)
		canvas.selected_object = mini(int(editor_view.get("selected_object",-1)),document.objects.size()-1)
		canvas.selected_piece = mini(int(editor_view.get("selected_piece",-1)),document.pieces.size()-1)
		canvas.stamp_kind = str(editor_view.get("stamp_kind","tree"))
		canvas.brush_surface = int(editor_view.get("brush_surface",0))
		canvas.brush_width = float(editor_view.get("brush_width",10))
		canvas.brush_shape = str(editor_view.get("brush_shape","round"))
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
	canvas.edit_finished.connect(_save_draft)
	canvas.hint_changed.connect(func(value: String) -> void: editor_status.text = value)
	var overlay := Control.new()
	overlay.name = "EditorOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(overlay)
	MenuStyle.fill(overlay)
	var back: Button = EditorButton.make("","back",func() -> void:
		_save_draft()
		_show_screen("play"))
	back.tooltip_text = "Back"
	overlay.add_child(back)
	back.position = Vector2(16,16)
	editor_undo = EditorButton.make("","undo",_undo)
	editor_undo.text = "Undo"
	editor_undo.tooltip_text = "Undo"
	overlay.add_child(editor_undo)
	editor_undo.position = Vector2(78,16)
	editor_redo = EditorButton.make("","redo",_redo)
	editor_redo.text = "Redo"
	editor_redo.tooltip_text = "Redo"
	overlay.add_child(editor_redo)
	editor_redo.position = Vector2(140,16)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	overlay.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -506; top.offset_right = -16; top.offset_top = 16
	top.add_theme_constant_override("separation",8)
	editor_issue_button = MenuStyle.button("",_focus_issue)
	editor_issue_button.custom_minimum_size = Vector2(112,52)
	top.add_child(editor_issue_button)
	var settings: Button = EditorButton.make("","more",func() -> void:
		canvas.cancel_gesture()
		editor_map_panel.visible = not editor_map_panel.visible
		editor_tools_panel.hide())
	settings.text = "Map"
	settings.tooltip_text = "Map settings"
	top.add_child(settings)
	test_button = MenuStyle.button("▶  Test",_test_document,true)
	test_button.custom_minimum_size = Vector2(100,52)
	var test_style: StyleBoxFlat = _editor_box()
	test_style.bg_color = Color("075562")
	test_style.border_color = EditorButton.CYAN
	test_button.add_theme_stylebox_override("normal",test_style)
	test_button.add_theme_color_override("font_color",Color.WHITE)
	var load_button: Button = MenuStyle.button("Load",_load_track_dialog)
	load_button.name = "LoadTrack"
	load_button.custom_minimum_size = Vector2(90,52)
	top.add_child(load_button)
	var save_button: Button = MenuStyle.button("Save",_save_track_explicit)
	save_button.name = "SaveTrack"
	save_button.custom_minimum_size = Vector2(90,52)
	top.add_child(save_button)
	top.add_child(test_button)
	var rail := VBoxContainer.new()
	rail.name = "EditorRail"
	overlay.add_child(rail)
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	rail.offset_left = 16; rail.offset_top = -142
	rail.add_theme_constant_override("separation",4)
	editor_mode_buttons.clear()
	for pair: Array in [["road","Road","road"],["paint","Surface","surface"],["objects","Objects","objects"],["move","Race","race"]]:
		var value: String = pair[0]
		var button: Button = EditorButton.make(pair[1],pair[2],_editor_category.bind(value))
		button.name = "Editor"+pair[1]
		button.toggle_mode = true
		editor_mode_buttons[value] = button
		rail.add_child(button)
	var bottom := CenterContainer.new()
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
	scroll.custom_minimum_size = Vector2(360,76)
	panel.add_child(scroll)
	editor_context = HBoxContainer.new()
	editor_context.add_theme_constant_override("separation",4)
	scroll.add_child(editor_context)
	editor_confirm = EditorButton.make("","confirm",func() -> void:
		if canvas.mode == "road": canvas.confirm_piece()
		else:
			canvas.selected_object = -1
			canvas.selected = -1
			canvas.mode = "objects" if canvas.mode in ["place","run"] else canvas.mode
			editor_tools_panel.hide()
			_build_editor_tools())
	editor_confirm.name = "ConfirmPiece"
	editor_confirm.custom_minimum_size = Vector2(64,64)
	editor_confirm.toggle_mode = true
	editor_confirm.button_pressed = true
	overlay.add_child(editor_confirm)
	editor_confirm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	editor_confirm.offset_left = -92; editor_confirm.offset_right = -28; editor_confirm.offset_top = -110; editor_confirm.offset_bottom = -46
	var fit_button: Button = EditorButton.make("","fit",func() -> void: canvas.fit())
	fit_button.text = "Fit"
	fit_button.tooltip_text = "Fit track · pinch or wheel to zoom"
	overlay.add_child(fit_button)
	fit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fit_button.offset_left = 28; fit_button.offset_top = -80; fit_button.offset_bottom = -28
	editor_status = MenuStyle.label("",17)
	editor_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(editor_status)
	editor_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	editor_status.offset_left = 118; editor_status.offset_right = -118; editor_status.offset_top = -132; editor_status.offset_bottom = -103
	editor_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	editor_status.add_theme_constant_override("shadow_outline_size",5)
	editor_status.clip_text = true
	editor_tools_panel = _editor_panel(overlay,"EditorTools")
	editor_inspector = VBoxContainer.new()
	editor_tools_panel.add_child(editor_inspector)
	editor_map_panel = _editor_panel(overlay,"EditorMap")
	var map_scroll := ScrollContainer.new()
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_map_panel.add_child(map_scroll)
	var metadata := VBoxContainer.new()
	metadata.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(metadata)
	metadata.add_child(MenuStyle.label("TRACK SETTINGS",20))
	var name_field := LineEdit.new()
	name_field.text = str(document.name)
	name_field.max_length = 40
	name_field.custom_minimum_size.y = 52
	metadata.add_child(name_field)
	name_field.text_changed.connect(func(value: String) -> void: document.name = value)
	name_field.focus_exited.connect(_save_draft)
	var theme_picker := OptionButton.new()
	theme_picker.custom_minimum_size.y = 52
	for value: String in TrackDocument.THEMES: theme_picker.add_item(value.capitalize())
	theme_picker.selected = TrackDocument.THEMES.find(document.theme)
	theme_picker.item_selected.connect(func(index: int) -> void:
		_remember()
		document.theme = TrackDocument.THEMES[index]
		_save_draft())
	metadata.add_child(theme_picker)
	metadata.add_child(MenuStyle.button("Creator",_creator_name))
	metadata.add_child(MenuStyle.button("New",_new_document))
	metadata.add_child(MenuStyle.button("My circuits",_open_saved_tracks))
	metadata.add_child(MenuStyle.button("3D preview",_preview_document))
	metadata.add_child(MenuStyle.button("Controls",_editor_help))
	share_button = MenuStyle.button("Share",_share_dialog)
	metadata.add_child(share_button)
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
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04,0.075,0.09,0.94)
	box.border_color = Color(0.5,0.68,0.7,0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(6)
	return box

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
	var category: String = "objects" if canvas.mode in ["objects","place","run"] else "move" if canvas.mode in ["move","add","start"] else "paint" if canvas.mode in ["paint","pan"] else "road"
	for key: String in editor_mode_buttons: (editor_mode_buttons[key] as Button).set_pressed_no_signal(key == category)
	if category == "road":
		var piece: Dictionary = canvas.ghost if not canvas.ghost.is_empty() else document.pieces[canvas.selected_piece] if canvas.selected_piece >= 0 else {}
		if piece.is_empty():
			for pair: Array in [["straight","Straight"],["curve","Curve"],["s_bend","S-bend"],["hairpin","Hairpin"],["bridge","Bridge"]]:
				_context_button(pair[1],pair[0],canvas.choose_piece.bind(pair[0]))
			editor_status.text = "Choose a section · drag empty ground to pan · pinch to zoom"
		elif editor_geometry != "":
			_context_button("Back","back",func() -> void:
				editor_geometry = ""
				_build_editor_tools())
			var key: String = editor_geometry
			_context_button("- 5 deg" if key == "angle" else "- 1 m","minus",_change_piece.bind(key,-5.0 if key == "angle" else -1.0))
			_context_button(("Lead-in" if key == "length" and piece.kind not in ["straight","bridge"] else key.capitalize())+(" %.0f deg" if key == "angle" else " %.1f m") % float(piece.get(key,90.0)),"width",func() -> void: pass)
			_context_button("+ 5 deg" if key == "angle" else "+ 1 m","plus",_change_piece.bind(key,5.0 if key == "angle" else 1.0))
			if key != "width" and piece.kind not in ["straight","bridge"]: _context_button("Radius" if key == "length" else "Lead-in","curve",func() -> void:
				editor_geometry = "radius" if key == "length" else "length"
				_build_editor_tools())
			if piece.kind == "curve" and key != "angle": _context_button("Angle","curve",func() -> void:
				editor_geometry = "angle"
				_build_editor_tools())
			editor_status.text = "Only this section changes. Reconnect any open ends afterwards."
		else:
			_context_button("Shape",piece.kind,func() -> void:
				editor_geometry = "length" if piece.kind in ["straight","bridge"] else "radius"
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
		for pair: Array in [[0,"Road"],[1,"Grass"],[2,"Dirt"],[3,"Water"]]:
			_context_button(pair[1],"surface",func() -> void:
				canvas.brush_surface = pair[0]
				canvas.mode = "paint"
				_build_editor_tools(),canvas.mode == "paint" and canvas.brush_surface == pair[0])
		_context_button("Brush","width",func() -> void:
			editor_tools_panel.visible = not editor_tools_panel.visible)
		_context_button("Pan","move",func() -> void:
			canvas.mode = "pan" if canvas.mode == "paint" else "paint"
			_build_editor_tools(),canvas.mode == "pan")
		_context_button("Keep road" if canvas.protect_road else "Paint all","road",func() -> void:
			canvas.protect_road = not canvas.protect_road
			_build_editor_tools(),canvas.protect_road)
		_build_paint_tools()
		editor_status.text = "Paint any road shape, terrain or intersection · %.1f m %s brush" % [canvas.brush_width,canvas.brush_shape]
	elif category == "objects":
		if canvas.selected_object >= 0 and canvas.mode == "objects":
			_context_button("Rotate","rotate",_rotate_object)
			_context_button("Copy","objects",_duplicate_object)
			if document.objects[canvas.selected_object].kind != "tyre_wall":
				_context_button("Size -","minus",func() -> void: _scale_object(-0.25))
				_context_button("Size +","plus",func() -> void: _scale_object(0.25))
				editor_status.text = "%s / %.2fx" % [CreatorObjects.description(document.objects[canvas.selected_object].kind),float(document.objects[canvas.selected_object].get("scale",1.0))]
			_context_button("Delete","delete",_delete_selection)
			if canvas.issue_marker != Vector2.INF: _context_button("Move start","race",_move_practice_start)
			_context_button("Palette","more",func() -> void:
				canvas.selected_object = -1
				_build_editor_tools())
		else:
			for pair: Array in [["barrier","Barrier"],["tyre_wall","Tyre wall"],["fence","Fence"],["tree","Tree"],["rock","Rock"],["boulder","Boulder"],["slate","Slate"],["cliff","Cliff"],["jump","Jump"],["oil","Oil"],["puddle","Shallow water"],["water","Pond"]]:
				_context_button(pair[1],pair[0],func() -> void:
					canvas.stamp_kind = pair[0]
					canvas.mode = "run" if pair[0] in ["barrier","fence"] else "place"
					canvas.free_run = pair[0] == "tyre_wall"
					canvas.run_start = Vector2.INF
					_build_editor_tools(),canvas.stamp_kind == pair[0] and canvas.mode in ["run","place"])
			_context_button("Select","move",func() -> void:
				canvas.mode = "objects"
				_build_editor_tools(),canvas.mode == "objects")
			if canvas.stamp_kind in ["barrier","tyre_wall","fence"]:
				_context_button("Single","objects",func() -> void:
					canvas.mode = "place"
					canvas.run_start = Vector2.INF
					_build_editor_tools(),canvas.mode == "place")
				for free: bool in [true,false]:
					_context_button("Free line" if free else "Road edge","move",func() -> void:
						canvas.free_run = free
						canvas.mode = "run"
						canvas.run_start = Vector2.INF
						_build_editor_tools(),canvas.mode == "run" and canvas.free_run == free)
			editor_status.text = "Two taps anywhere for a free wall line" if canvas.mode == "run" and canvas.free_run else "Two taps: start and end of a run along the road" if canvas.mode == "run" else "Tap to place · Select to move or remove objects"
	else:
		_context_button("Move","move",func() -> void:
			canvas.mode = "move"
			_build_editor_tools(),canvas.mode == "move")
		_context_button("Add bend","plus",func() -> void:
			canvas.mode = "add"
			_build_editor_tools(),canvas.mode == "add")
		_context_button("Set start","race",_set_start_node)
		_context_button("Use roads","road",_route_from_roads)
		_context_button("More","more",func() -> void: editor_tools_panel.visible = not editor_tools_panel.visible)
		var row := HBoxContainer.new()
		editor_inspector.add_child(MenuStyle.label("SELECTED ROUTE NODE",18))
		editor_inspector.add_child(row)
		row.add_child(MenuStyle.button("−",_change_node_width.bind(-1.0)))
		row.add_child(MenuStyle.label("%.1f m" % document.widths[canvas.selected] if canvas.selected >= 0 else "Width",20))
		row.add_child(MenuStyle.button("+",_change_node_width.bind(1.0)))
		for corner: String in ["sharp","smooth"]:
			editor_inspector.add_child(MenuStyle.button(corner.capitalize(),func() -> void:
				if canvas.selected >= 0:
					_remember()
					document.corners[canvas.selected] = corner
					_commit_selection()))
		editor_inspector.add_child(MenuStyle.button("Remove",_delete_selection))
		editor_inspector.add_child(MenuStyle.button("Practice start",_move_practice_start))
		editor_inspector.add_child(MenuStyle.button("Lay road along route",_lay_road))
		editor_status.text = "Numbered route sets lap order · Use roads traces a connected loop"
	var context_width: float = 0
	for child: Control in editor_context.get_children(): context_width += child.get_combined_minimum_size().x+4
	(editor_context.get_parent() as ScrollContainer).custom_minimum_size.x = clampf(context_width,320,maxf(320,canvas.size.x-260))
	canvas.refresh()

func _change_piece(key: String, delta: float) -> void:
	var is_ghost: bool = not canvas.ghost.is_empty()
	if not is_ghost and canvas.selected_piece < 0: return
	var piece: Dictionary = (canvas.ghost if is_ghost else document.pieces[canvas.selected_piece]).duplicate(true)
	if key == "flip": piece.flip = not piece.flip
	elif key == "heading": piece.heading = fposmod(float(piece.heading)+delta,360.0)
	else:
		var lower: float = 5.0 if key == "angle" else 6.0 if key == "width" else 3.0 if key == "radius" else 24.0 if piece.kind == "bridge" else 2.0 if piece.kind == "straight" else 0.0
		var upper: float = 270.0 if key == "angle" else 20.0 if key == "width" else 60.0 if key == "radius" else 120.0
		piece[key] = clampf(float(piece.get(key,90.0))+delta,lower,upper)
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
	canvas.selected = 0
	_commit_selection()

func _practice_start(track: NativeTrack) -> Vector2:
	if document.has("practice_start"): return Vector2(document.practice_start.position[0],document.practice_start.position[1])
	if document.pieces.is_empty(): return track.spawn
	var samples: PackedVector2Array = RoadPieces.samples(document.pieces[0])
	return samples[mini(6,samples.size()-1)]

func _practice_heading(track: NativeTrack) -> float:
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
		var config: HandlingConfig = load("res://resources/balanced.tres")
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
	test_button.disabled = not TrackDocument.validate(document).is_empty() or not has_road or not canvas.ghost.is_empty()
	if not editor_issues.is_empty() and int(editor_issues[0].object) != -1: test_button.disabled = true

func _focus_issue() -> void:
	if editor_issues.is_empty(): return
	var issue: Dictionary = editor_issues[0]
	_editor_category("objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road")
	canvas.issue_marker = issue.position
	canvas.issue_text = issue.message
	canvas.pan = -Vector2(issue.position.x,-issue.position.y)*canvas.scale_factor()
	if int(issue.object) >= 0: canvas.selected_object = issue.object
	elif int(issue.object) == -1: canvas.selected_piece = issue.index
	_build_editor_tools()
	editor_status.text = issue.message+" · drag to move, or delete the selection"
	if int(issue.object) == -2: editor_status.text = issue.message+" · paint Road over the obstacle, or move the practice start in Race"
	canvas.refresh()

func _commit_selection() -> void:
	if canvas.mode in ["move","add"]: document.route_override = true
	canvas.refresh()
	_save_draft()
	_build_editor_tools()

func _change_node_width(change: float) -> void:
	if canvas.selected < 0: return
	_remember()
	document.widths[canvas.selected] = clampf(float(document.widths[canvas.selected])+change,6,20)
	_commit_selection()

func _delete_selection() -> void:
	if canvas.mode in ["objects","place","run"]:
		if canvas.selected_object < 0: return
		_remember()
		document.objects.remove_at(canvas.selected_object)
		canvas.selected_object = -1
	else:
		if canvas.selected < 0 or document.points.size() <= 4: return
		_remember()
		for key: String in ["points","widths","corners"]: document[key].remove_at(canvas.selected)
		canvas.selected = -1
	_commit_selection()

func _set_start_node() -> void:
	if canvas.selected < 0: return
	_remember()
	for key: String in ["points","widths","corners"]:
		var values: Array = []
		for i: int in range(document.points.size()): values.append(document[key][(canvas.selected+i)%document.points.size()])
		document[key] = values
	canvas.selected = 0
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
	object.scale = clampf(float(object.get("scale",1.0))+delta,0.5,3.0)
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
	editor_status.text = "Paint the map freely. Edit Route to set the lap. Changes save automatically." if errors.is_empty() else errors[0]
	test_button.disabled = not errors.is_empty()
	share_button.disabled = not errors.is_empty()
	if is_instance_valid(canvas): canvas.refresh()

func _save_draft() -> Error:
	if document.is_empty(): return ERR_INVALID_DATA
	var errors: Array[String] = TrackDocument.validate(document)
	var message: String
	var save_error: Error = library.save_document(document)
	if save_error != OK: message = "Could not save: " + library.last_error
	elif not errors.is_empty(): message = "Draft saved. Before driving: " + errors[0]
	else: message = "Saved on this device. Ready to test drive."
	if is_instance_valid(editor_status):
		editor_status.text = message
		test_button.disabled = not errors.is_empty()
		share_button.disabled = not errors.is_empty()
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(canvas):
		if is_instance_valid(editor_undo): editor_undo.disabled = history.is_empty()
		if is_instance_valid(editor_redo): editor_redo.disabled = redo_history.is_empty()
		var preview_track: NativeTrack = _editor_track_preview()
		if preview_track != null: canvas.show_native(preview_track)
		_update_editor_issues()
	return save_error

func _test_document() -> void:
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

func _preview_document() -> void:
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null:
		_notice("Adjust the route before previewing it. " + TrackDocument.validate(document)[0])
		return
	var dialog := AcceptDialog.new()
	dialog.title = str(document.name) + " / " + TrackTheme.title(str(document.theme))
	dialog.ok_button_text = "Back to editing"
	var preview := TrackShowroom.new()
	preview.track = track
	preview.custom_minimum_size = Vector2(800,420)
	dialog.add_child(preview)
	_own_dialog(dialog)
	dialog.popup_centered()

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
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind,"brush_surface":canvas.brush_surface,"brush_width":canvas.brush_width,"brush_shape":canvas.brush_shape,"selected_piece":canvas.selected_piece}
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
		canvas.pan = -Vector2(position.x,-position.y)*canvas.scale_factor()
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
	var total: float = session.lap_start_time
	var clean: bool = not bool(game.get("attempt_practice")) and not returning_to_editor
	var previous: float = records.best_for(track, game.get("handling"))
	var saved: bool = true
	if clean: saved = records.record(track, game.get("handling"), total, session.lap_times) == OK
	root_ui.visible = true
	for child: Node in root_ui.get_children():
		root_ui.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.06,0.09,0.11,0.96)
	MenuStyle.fill(background)
	root_ui.add_child(background)
	var center := CenterContainer.new()
	MenuStyle.fill(center)
	root_ui.add_child(center)
	var panel := RaceResults.new()
	panel.circuit = track_title(track)
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
	game.call("restart")

static func track_title(track: NativeTrack) -> String:
	return str(track.metadata.get("title", track.metadata.get("name", track.identity.trim_prefix("slicks_").trim_suffix("_test").to_upper())))

func _capture() -> void:
	await get_tree().process_frame
	for child: Node in content.get_children():
		if child is TrackBrowser:
			while child.loading: await get_tree().process_frame
	if screen == "tracks":
		var browser: TrackBrowser = root_ui.find_child("TrackBrowser",true,false)
		while browser != null and browser.loading: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	if error == OK: print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit(0 if error == OK else 1)


func _build_paint_tools() -> void:
	var materials := OptionButton.new()
	materials.custom_minimum_size.y = 54
	for label: String in ["Asphalt","Grass / erase","Dirt / sand","Water","Barrier","Kerb","Rough ground","Low obstacles"]: materials.add_item(label)
	materials.selected = canvas.brush_surface
	materials.item_selected.connect(func(index: int) -> void:
		canvas.brush_surface = index
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
	var sizes := HBoxContainer.new()
	editor_inspector.add_child(sizes)
	sizes.add_child(MenuStyle.button("-",func() -> void:
		canvas.brush_width = maxf(0.5,canvas.brush_width-(0.5 if canvas.brush_width <= 4 else 2))
		_build_editor_tools()))
	var label := MenuStyle.label("%.1f m brush" % canvas.brush_width,20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sizes.add_child(label)
	sizes.add_child(MenuStyle.button("+",func() -> void:
		canvas.brush_width = minf(40,canvas.brush_width+(0.5 if canvas.brush_width < 4 else 2))
		_build_editor_tools()))
	var shapes := OptionButton.new()
	shapes.custom_minimum_size.y = 54
	shapes.add_item("Round brush")
	shapes.add_item("Square brush")
	shapes.selected = 1 if canvas.brush_shape == "square" else 0
	shapes.item_selected.connect(func(index: int) -> void: canvas.brush_shape = "square" if index else "round")
	editor_inspector.add_child(shapes)
	var help := MenuStyle.label("Paint freely. Pinch to zoom.\nRoute sets lap order.",16,true)
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

func _lay_road() -> void:
	_remember()
	document.layout = TrackDocument.road_layout(document)
	_commit_selection()

func _editor_help() -> void:
	_notice("Drag inside a road section to move it. Drag an end dot to resize and turn it; the other end stays fixed.\n\nPC: wheel zooms at the pointer. Middle/right drag or Space + left drag pans. F fits the map. Ctrl+Z / Ctrl+Shift+Z undo/redo. Enter confirms; Esc cancels. Delete removes the selection. 1–4 switch tools. Q/E rotate. Tab cycles overlapping roads.\n\nPhone: two fingers pan/zoom. Layer selects the other road at an overpass. Bridge spans include ramps at both ends; paint edits the ground underneath.")

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
			KEY_S: _save_draft()
			_: handled = false
	else:
		match key:
			KEY_F: canvas.fit()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: canvas.zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT: canvas.zoom_by(1.0/1.15)
			KEY_ENTER, KEY_KP_ENTER:
				if canvas.mode == "road": canvas.confirm_piece()
			KEY_ESCAPE:
				canvas.cancel_gesture()
				canvas.ghost.clear()
				canvas.selected_piece = -1
				editor_geometry = ""
				editor_tools_panel.hide()
				editor_map_panel.hide()
				_build_editor_tools()
			KEY_DELETE, KEY_BACKSPACE:
				if canvas.mode == "road": _delete_piece()
				else: _delete_selection()
			KEY_1: _editor_category("road")
			KEY_2: _editor_category("paint")
			KEY_3: _editor_category("objects")
			KEY_4: _editor_category("move")
			KEY_Q: _change_piece("heading",-15.0)
			KEY_E: _change_piece("heading",15.0)
			KEY_TAB: canvas.cycle_piece()
			_: handled = false
	if handled: get_viewport().set_input_as_handled()

func _save_track_explicit() -> void:
	if not canvas.ghost.is_empty():
		canvas.confirm_piece()
		if not canvas.ghost.is_empty():
			_notice("The preview cannot be placed here. Move or cancel it before saving.")
			return
	if _save_draft() != OK:
		_notice("Could not save: "+library.last_error)
	elif not TrackDocument.validate(document).is_empty():
		_notice("Draft saved. You can reopen it in My circuits. Before driving: "+TrackDocument.validate(document)[0])
	else:
		_notice("Saved on this device. Choose My circuits in Track settings, or Saved tracks in the circuit library, to drive it.")

func _open_saved_tracks() -> void:
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

func _load_track_dialog() -> void:
	if not canvas.ghost.is_empty():
		canvas.confirm_piece()
		if not canvas.ghost.is_empty():
			_notice("Move or cancel the preview before loading another track.")
			return
	if _save_draft() != OK:
		_notice("Could not save the current track: "+library.last_error)
		return
	var saved: Array[Dictionary] = library.list_documents()
	var dialog := AcceptDialog.new()
	dialog.name = "LoadTrackDialog"
	dialog.title = "Load track for editing"
	dialog.ok_button_text = "Load for editing"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500,300)
	box.add_theme_constant_override("separation",12)
	dialog.add_child(box)
	box.add_child(MenuStyle.label("Local drafts stay editable. Choose a track to continue.",18,true))
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
			if not (str(draft.name)+" "+str(draft.get("creator",""))).to_lower().contains(query.to_lower()): continue
			var label: String = str(draft.name)
			if not TrackDocument.validate(draft).is_empty(): label += " (draft)"
			var index: int = choices.add_item(label)
			choices.set_item_metadata(index,str(draft.id))
		if choices.item_count > 0: choices.select(0)
		dialog.get_ok_button().disabled = choices.item_count == 0
	search.text_changed.connect(filter)
	filter.call("")
	var open_selected: Callable = func() -> void:
		var selected: PackedInt32Array = choices.get_selected_items()
		if selected.is_empty(): return
		_load_saved_document(str(choices.get_item_metadata(selected[0])))
	choices.item_activated.connect(func(_index: int) -> void: open_selected.call())
	dialog.confirmed.connect(open_selected)
	_own_dialog(dialog)
	dialog.popup_centered(Vector2i(540,400))
	search.grab_focus()

func _load_saved_document(id: String) -> void:
	var loaded: Dictionary = library.load_document(id)
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
	if TrackDocument.validate(document).is_empty(): return TrackCompiler.compile(document)
	if not TrackDocument.validate(document,false).is_empty(): return null
	# A draft may have an unfinished lap. Render its actual map using a safe
	# preview-only route; never change the saved route or permit racing it.
	var preview_document: Dictionary = document.duplicate(true)
	var fallback: Dictionary = TrackDocument.create_default()
	for key: String in ["points","widths","corners"]: preview_document[key] = fallback[key]
	preview_document.route_override = true
	return TrackCompiler.compile(preview_document)
