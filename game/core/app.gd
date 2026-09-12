extends Node
## Local navigation and editor composition. Racing simulation stays in Game.

const GAME_SCENE: PackedScene = preload("res://core/game.tscn")
const BUILTIN_IDS: Array[String] = ["slicks_freeway_test", "slicks_1way_test", "slicks_66_test", "slicks_offroad_test", "slicks_arto4_test", "slicks_hiekka_test", "slicks_ovaali3_test"]
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
var editor_inspector: VBoxContainer

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
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	_show_screen(capture_screen)
	print("APP_READY")
	if not capture_path.is_empty(): _capture()

func _show_screen(next: String) -> void:
	if is_instance_valid(canvas):
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind}
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
	var background := ColorRect.new()
	background.color = MenuStyle.INK
	MenuStyle.fill(background)
	root_ui.add_child(background)
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
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	var nav := HBoxContainer.new()
	layout.add_child(nav)
	var logo := MenuStyle.label("CIRCUIT / 01", 24)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(logo)
	nav.add_child(MenuStyle.button("Back to race" if screen == "settings" else "Settings", _show_screen.bind("play" if screen == "settings" else "settings")))
	var tabs := HBoxContainer.new()
	if screen == "create": nav.add_child(tabs)
	else: layout.add_child(tabs)
	for item: Array in [["play","Race"],["garage","Garage"],["create","Create"]]:
		var id: String = item[0]
		var button: Button = MenuStyle.button(item[1], _show_screen.bind(id), screen == id or (id == "play" and screen == "tracks"))
		button.name = "Tab_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	if screen == "create": nav.move_child(nav.get_child(1),nav.get_child_count()-1)
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
	row.add_theme_constant_override("separation", 32)
	content.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var selector := HBoxContainer.new()
	left.add_child(selector)
	var previous_button: Button = MenuStyle.button("<", _cycle_track.bind(-1))
	previous_button.custom_minimum_size.x = 60
	previous_button.tooltip_text = "Previous circuit"
	selector.add_child(previous_button)
	var title := MenuStyle.label(track_title(selected_track), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector.add_child(title)
	var next_button: Button = MenuStyle.button(">", _cycle_track.bind(1))
	next_button.custom_minimum_size.x = 60
	next_button.tooltip_text = "Next circuit"
	selector.add_child(next_button)
	var preview := TrackShowroom.new()
	preview.track = selected_track
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	left.add_child(MenuStyle.button("Choose a track", _show_screen.bind("tracks")))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 340
	row.add_child(right)
	right.add_child(MenuStyle.label("YOUR CAR", 15, true))
	var showroom := CarShowroom.new()
	showroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(showroom)
	right.add_child(MenuStyle.label("COMPACT / 01", 24))
	right.add_child(MenuStyle.label("Balanced  /  3 laps", 18, true))
	var best: float = records.best_for(selected_track, load("res://resources/balanced.tres") as HandlingConfig)
	right.add_child(MenuStyle.label("Local best  /  %.3f s" % best if best > 0.0 else "Set your first local best", 18, true))
	var race_button: Button = MenuStyle.button("Race", _start_race.bind(selected_track, false), true)
	race_button.name = "StartRace"
	race_button.custom_minimum_size.y = 76
	race_button.add_theme_font_size_override("font_size", 28)
	right.add_child(race_button)

func _cycle_track(direction: int) -> void:
	var choices: Array[NativeTrack] = []
	for id: String in BUILTIN_IDS:
		choices.append(NativeTrack.read("res://resources/tracks/" + id + ".json"))
	for doc: Dictionary in library.list_documents():
		choices.append(TrackCompiler.compile(doc))
	var index: int = 0
	for i: int in range(choices.size()):
		if choices[i].identity == selected_track.identity: index = i
	selected_track = choices[posmod(index + direction, choices.size())]
	_show_screen("play")

func _tracks() -> void:
	_heading("TRACK LIBRARY", "Choose your next circuit.")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	content.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 350
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(MenuStyle.label("SLICKS COLLECTION", 15, true))
	for id: String in BUILTIN_IDS:
		var track: NativeTrack = NativeTrack.read("res://resources/tracks/" + id + ".json")
		list.add_child(MenuStyle.button(track_title(track), func() -> void:
			selected_track = track
			_show_screen("tracks"), selected_track.identity == id))
	list.add_child(MenuStyle.label("MY CIRCUITS", 15, true))
	for doc: Dictionary in library.list_documents():
		list.add_child(MenuStyle.button(str(doc.name), func() -> void:
			selected_track = TrackCompiler.compile(doc)
			_show_screen("tracks"), selected_track.identity == "creator_" + str(doc.id)))
	list.add_child(MenuStyle.button("+ New circuit", _new_document))
	list.add_child(MenuStyle.button("Import a circuit", _import_dialog))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var map := TrackShowroom.new()
	map.track = selected_track
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(map)
	detail.add_child(MenuStyle.label(track_title(selected_track), 28))
	detail.add_child(MenuStyle.label(str(selected_track.metadata.get("description", "A classic layout rebuilt for the Compact / 01.")), 17, true))
	detail.add_child(MenuStyle.label("3 laps  /  " + TrackTheme.title(str(selected_track.metadata.get("theme","pine")))))
	detail.add_child(MenuStyle.button("Race this circuit", _start_race.bind(selected_track, false), true))
	if selected_track.metadata.has("creator_document"):
		detail.add_child(MenuStyle.button("Edit circuit", func() -> void:
			document = selected_track.metadata.creator_document.duplicate(true)
			editor_view.clear()
			history.clear()
			redo_history.clear()
			_show_screen("create")))

func _garage() -> void:
	_heading("GARAGE", "Compact / 01")
	var car := CarShowroom.new()
	car.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(car)
	content.add_child(MenuStyle.label("Balanced handling  /  rear-wheel drive  /  original compact", 20))
	content.add_child(MenuStyle.label("Your current car is ready for every circuit.", 18, true))
	content.add_child(MenuStyle.button("Test drive", _start_race.bind(selected_track, false), true))

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
	records.settings = {"touch_scale":ui_touch_scale,"left_handed":ui_left_handed}
	if records.save_records() != OK: _notice("Settings could not be saved. Check free storage space.")

func _new_document() -> void:
	if not document.is_empty() and not TrackDocument.validate(document).is_empty():
		_notice("Fix or undo the unsaved route change before starting another circuit.")
		return
	_save_draft()
	editor_view.clear()
	canvas = null
	document = TrackDocument.create_default()
	document.id = TrackLibrary.unique_id()
	history.clear()
	redo_history.clear()
	_show_screen("create")

func _editor() -> void:
	if document.is_empty():
		document = TrackDocument.create_default()
		document.id = TrackLibrary.unique_id()
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := MenuStyle.label("TRACK STUDIO", 16, true)
	heading.add_child(title)
	var name_field := LineEdit.new()
	name_field.text = str(document.name)
	name_field.max_length = 40
	name_field.custom_minimum_size = Vector2(220, 52)
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_field)
	var name_save := Timer.new()
	name_save.one_shot = true
	name_save.wait_time = 0.6
	name_field.add_child(name_save)
	name_save.timeout.connect(_save_draft)
	name_field.text_changed.connect(func(value: String) -> void:
		document.name = value
		_refresh_editor()
		name_save.start())
	name_field.focus_exited.connect(_save_draft)
	var theme_choice := OptionButton.new()
	theme_choice.custom_minimum_size = Vector2(155,54)
	for id: String in ["pine","coast","desert"]: theme_choice.add_item("Theme / "+id.capitalize())
	theme_choice.selected = ["pine","coast","desert"].find(document.theme)
	theme_choice.item_selected.connect(func(index: int) -> void: _set_document_value("theme",["pine","coast","desert"][index]))
	heading.add_child(theme_choice)
	var road_choice := OptionButton.new()
	road_choice.custom_minimum_size = Vector2(160,54)
	for id: String in ["asphalt","dirt"]: road_choice.add_item("Road / "+id.capitalize())
	road_choice.selected = ["asphalt","dirt"].find(document.surface)
	road_choice.item_selected.connect(func(index: int) -> void: _set_document_value("surface",["asphalt","dirt"][index]))
	heading.add_child(road_choice)
	heading.add_child(MenuStyle.button("New", _new_document))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	canvas = EditorCanvas.new()
	canvas.document = document
	if not editor_view.is_empty():
		canvas.zoom = editor_view.zoom
		canvas.pan = editor_view.pan
		canvas.mode = editor_view.mode
		canvas.selected = mini(int(editor_view.get("selected",-1)),document.points.size()-1)
		canvas.selected_object = mini(int(editor_view.get("selected_object",-1)),document.objects.size()-1)
		canvas.stamp_kind = str(editor_view.get("stamp_kind","tree"))
		canvas.fitted = true
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(canvas)
	canvas.edit_started.connect(_remember)
	canvas.document_changed.connect(func() -> void:
		canvas.refresh()
		test_button.disabled = true
		share_button.disabled = true
		editor_status.text = "Release to check and save your route.")
	canvas.edit_finished.connect(_save_draft)
	canvas.hint_changed.connect(func(value: String) -> void: editor_status.text = value)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 264
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sidebar_scroll)
	editor_inspector = VBoxContainer.new()
	editor_inspector.add_theme_constant_override("separation",8)
	editor_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(editor_inspector)
	canvas.selection_changed.connect(_build_editor_tools)
	_build_editor_tools()
	var zooms := HBoxContainer.new()
	canvas.add_child(zooms)
	zooms.position = Vector2(12,12)
	zooms.add_child(MenuStyle.button("-", func() -> void: canvas.zoom_by(1.0 / 1.2)))
	zooms.add_child(MenuStyle.button("Fit", func() -> void: canvas.fit()))
	zooms.add_child(MenuStyle.button("+", func() -> void: canvas.zoom_by(1.2)))
	editor_status = MenuStyle.label("", 16, true)
	editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_status.custom_minimum_size.y = 40
	content.add_child(editor_status)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var undo_button: Button = MenuStyle.button("Undo", _undo)
	undo_button.disabled = history.is_empty()
	footer.add_child(undo_button)
	var redo_button: Button = MenuStyle.button("Redo", _redo)
	redo_button.disabled = redo_history.is_empty()
	footer.add_child(redo_button)
	footer.add_child(MenuStyle.button("My circuits", _show_screen.bind("tracks")))
	footer.add_child(MenuStyle.button("3D preview", _preview_document))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	share_button = MenuStyle.button("Share", _share_dialog)
	footer.add_child(share_button)
	test_button = MenuStyle.button("Test drive", _test_document, true)
	footer.add_child(test_button)
	_refresh_editor()
	if editor_view.is_empty(): canvas.call_deferred("fit")
	if TrackDocument.validate(document).is_empty(): canvas.show_native(TrackCompiler.compile(document))

func _build_editor_tools() -> void:
	if not is_instance_valid(editor_inspector) or not is_instance_valid(canvas): return
	for child: Node in editor_inspector.get_children():
		editor_inspector.remove_child(child)
		child.queue_free()
	var objects_mode: bool = canvas.mode in ["objects","place"]
	var tabs := HBoxContainer.new()
	editor_inspector.add_child(tabs)
	for pair: Array in [["move","Road"],["objects","Objects"]]:
		var value: String = pair[0]
		var button: Button = MenuStyle.button(pair[1],func() -> void:
			canvas.mode = value
			_build_editor_tools(), objects_mode == (value == "objects"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	if objects_mode:
		var palette := OptionButton.new()
		palette.custom_minimum_size.y = 54
		for id: String in CreatorObjects.KINDS: palette.add_item(id.capitalize())
		palette.selected = CreatorObjects.KINDS.find(canvas.stamp_kind)
		palette.item_selected.connect(func(index: int) -> void:
			canvas.stamp_kind = CreatorObjects.KINDS[index]
			canvas.mode = "place"
			_build_editor_tools())
		editor_inspector.add_child(palette)
		var actions := HBoxContainer.new()
		editor_inspector.add_child(actions)
		actions.add_child(MenuStyle.button("Stamp",func() -> void:
			canvas.mode = "place"
			_build_editor_tools(),canvas.mode == "place"))
		actions.add_child(MenuStyle.button("Select / move",func() -> void:
			canvas.mode = "objects"
			_build_editor_tools(),canvas.mode == "objects"))
		var message := MenuStyle.label(CreatorObjects.description(canvas.stamp_kind),16,true)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		editor_inspector.add_child(message)
		var chosen: int = canvas.selected_object
		editor_inspector.add_child(MenuStyle.label("Object %d / %s" % [chosen+1,document.objects[chosen].kind.capitalize()] if chosen >= 0 else "Tap to stamp; drag empty space to pan.",16))
		var operations := HBoxContainer.new()
		editor_inspector.add_child(operations)
		operations.add_child(MenuStyle.button("Rotate",_rotate_object))
		var duplicate: Button = MenuStyle.button("Copy",_duplicate_object)
		duplicate.disabled = chosen < 0
		operations.add_child(duplicate)
		var delete: Button = MenuStyle.button("Delete",_delete_selection)
		delete.disabled = chosen < 0
		operations.add_child(delete)
		editor_inspector.add_child(MenuStyle.label("%d / 96 objects   |   %.1f deg" % [document.objects.size(),canvas.stamp_rotation],15,true))
	else:
		var actions := HBoxContainer.new()
		editor_inspector.add_child(actions)
		for pair: Array in [["move","Move"],["add","Add bend"]]:
			var value: String = pair[0]
			actions.add_child(MenuStyle.button(pair[1],func() -> void:
				canvas.mode = value
				_build_editor_tools(),canvas.mode == value))
		var chosen: int = canvas.selected
		editor_inspector.add_child(MenuStyle.label("Node %d / road width" % [chosen+1] if chosen >= 0 else "Tap a road node to adjust it.",18))
		var widths := HBoxContainer.new()
		editor_inspector.add_child(widths)
		var minus: Button = MenuStyle.button("-",_change_node_width.bind(-1.0))
		minus.disabled = chosen < 0 or float(document.widths[chosen]) <= 6.0
		widths.add_child(minus)
		var width_label := MenuStyle.label("%.1f m" % float(document.widths[chosen]) if chosen >= 0 else "6 - 20 m",24)
		width_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		width_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		widths.add_child(width_label)
		var plus: Button = MenuStyle.button("+",_change_node_width.bind(1.0))
		plus.disabled = chosen < 0 or float(document.widths[chosen]) >= 20.0
		widths.add_child(plus)
		var corner := OptionButton.new()
		corner.custom_minimum_size.y = 54
		corner.add_item("Smooth corner")
		corner.add_item("Sharp corner")
		corner.disabled = chosen < 0
		if chosen >= 0: corner.selected = 1 if document.corners[chosen] == "sharp" else 0
		corner.item_selected.connect(func(index: int) -> void:
			_remember()
			document.corners[canvas.selected] = "sharp" if index == 1 else "smooth"
			_commit_selection())
		editor_inspector.add_child(corner)
		var operations := HBoxContainer.new()
		editor_inspector.add_child(operations)
		var delete: Button = MenuStyle.button("Remove",_delete_selection)
		delete.disabled = chosen < 0 or document.points.size() <= 4
		operations.add_child(delete)
		var start: Button = MenuStyle.button("Set start",_set_start_node)
		start.disabled = chosen < 0
		operations.add_child(start)

func _commit_selection() -> void:
	canvas.refresh()
	_save_draft()
	_build_editor_tools()

func _change_node_width(change: float) -> void:
	if canvas.selected < 0: return
	_remember()
	document.widths[canvas.selected] = clampf(float(document.widths[canvas.selected])+change,6,20)
	_commit_selection()

func _delete_selection() -> void:
	if canvas.mode in ["objects","place"]:
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

func _duplicate_object() -> void:
	if canvas.selected_object < 0 or document.objects.size() >= 96: return
	_remember()
	var object: Dictionary = document.objects[canvas.selected_object].duplicate(true)
	object.position = [clampf(float(object.position[0])+4,-110,110),clampf(float(object.position[1])+4,-110,110)]
	document.objects.append(object)
	canvas.selected_object = document.objects.size()-1
	canvas.mode = "objects"
	_commit_selection()

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
	editor_status.text = "Drag the large handles to shape your circuit. Changes save automatically." if errors.is_empty() else errors[0]
	test_button.disabled = not errors.is_empty()
	share_button.disabled = not errors.is_empty()
	if is_instance_valid(canvas): canvas.refresh()

func _save_draft() -> void:
	if document.is_empty(): return
	var errors: Array[String] = TrackDocument.validate(document)
	var message: String
	if not errors.is_empty(): message = "Unsaved change: " + errors[0] + " Undo or adjust the route."
	elif library.save_document(document) != OK: message = "Could not save: " + library.last_error
	else: message = "Saved on this device. Ready to test drive."
	if is_instance_valid(editor_status):
		editor_status.text = message
		test_button.disabled = not errors.is_empty()
		share_button.disabled = not errors.is_empty()
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(canvas):
		var footer: HBoxContainer = content.get_child(content.get_child_count()-1) as HBoxContainer
		(footer.get_child(0) as Button).disabled = history.is_empty()
		(footer.get_child(1) as Button).disabled = redo_history.is_empty()
		if errors.is_empty(): canvas.show_native(TrackCompiler.compile(document))

func _test_document() -> void:
	_save_draft()
	var track: NativeTrack = TrackCompiler.compile(document)
	if track != null: _start_race(track, true)

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
		if copied.to_utf8_buffer().size() <= 16384: text.text = copied
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
		if text.text.to_utf8_buffer().size() > 16384:
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
	if is_instance_valid(canvas):
		canvas.cancel_gesture()
		editor_view = {"zoom":canvas.zoom,"pan":canvas.pan,"mode":canvas.mode,"selected":canvas.selected,"selected_object":canvas.selected_object,"stamp_kind":canvas.stamp_kind}
	root_ui.visible = false
	game = GAME_SCENE.instantiate()
	game.set("initial_track", track)
	game.set("production_mode", true)
	game.set("editor_test", from_editor)
	game.connect("exit_requested", _leave_race)
	game.connect("race_completed", _results)
	game.connect("retry_requested", _retry_race)
	add_child(game)
	var hud: PlaygroundHUD = game.get("hud")
	hud.touch.control_scale = ui_touch_scale
	hud.touch.left_handed = ui_left_handed

func _leave_race() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null
	_show_screen("create" if returning_to_editor else "tracks")

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
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 620
	center.add_child(panel)
	_heading("TEST DRIVE COMPLETE" if returning_to_editor else "RACE COMPLETE", track_title(track), panel)
	panel.add_child(MenuStyle.label("%02d:%06.3f" % [int(total) / 60, fmod(total,60.0)], 56))
	var status: String = "Local personal best" if clean and (previous <= 0.0 or roundi(total*1000.0) < roundi(previous*1000.0)) else "Local race time"
	if not clean: status = "Practice run" if not returning_to_editor else "Your circuit is ready for another iteration."
	if not saved: status = "Time recorded on screen; storage failed. Personal best was not saved."
	panel.add_child(MenuStyle.label(status, 20, true))
	for i: int in range(session.lap_times.size()):
		panel.add_child(MenuStyle.label("LAP %d%s       %.3f s" % [i+1, " / standing start" if i == 0 else "", session.lap_times[i]],20))
	if clean and saved:
		var best: Dictionary = records.records.get(records.key_for(track,game.get("handling")),{})
		panel.add_child(MenuStyle.label("Personal best / %.3f s     Best flying lap / %.3f s" % [float(best.get("race_ms",0))/1000.0,float(best.get("flying_ms",0))/1000.0],18,true))
	panel.add_child(MenuStyle.label("Local results are unverified. Online comparisons come later.",16,true))
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	actions.add_child(MenuStyle.button("Retry", _retry_race, true))
	actions.add_child(MenuStyle.button("Back to editor" if returning_to_editor else "Choose track", _leave_race))

func _retry_race() -> void:
	root_ui.visible = false
	game.call("restart")

static func track_title(track: NativeTrack) -> String:
	return str(track.metadata.get("title", track.metadata.get("name", track.identity.trim_prefix("slicks_").trim_suffix("_test").to_upper())))

func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	if error == OK: print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit(0 if error == OK else 1)
