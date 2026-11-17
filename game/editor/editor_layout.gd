extends RefCounted
## Editor presentation: a shared header, navigation rail and one contextual dock.
## Authoring state and commands remain with App and EditorCanvas.

static func _reset(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func install(app: Node, overlay: Control) -> void:
	var header := PanelContainer.new()
	header.name = "EditorTopBar"
	header.add_theme_stylebox_override("panel",EditorStyle.workspace_panel())
	overlay.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16; header.offset_right = -16
	header.offset_top = 12; header.offset_bottom = 68
	var row := HBoxContainer.new()
	row.name = "EditorTopBarRow"
	row.add_theme_constant_override("separation",8)
	header.add_child(row)
	var identity: HBoxContainer = overlay.get_node("EditorIdentityAndHistory")
	identity.reparent(row); _reset(identity)
	(identity.get_child(0) as PanelContainer).add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var name_label: Label = identity.find_child("TrackName",true,false)
	var name_row: HBoxContainer = name_label.get_parent()
	var rename: Button = name_row.get_node("RenameTrack")
	rename.get_parent().remove_child(rename); rename.queue_free()
	var document := Button.new()
	document.name = "EditorDocumentName"
	document.custom_minimum_size = Vector2(200,48)
	document.tooltip_text = GameText.message("Rename track")
	EditorStyle.quiet(document)
	document.pressed.connect(app._rename_track)
	name_row.add_child(document)
	name_label.reparent(document)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 10; name_label.offset_right = -26
	name_label.custom_minimum_size = Vector2.ZERO
	name_label.add_theme_font_size_override("font_size",18)
	var edit_hint := EditorButton.new()
	edit_hint.glyph = "pencil"
	edit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_hint.focus_mode = Control.FOCUS_NONE
	EditorStyle.transparent_button(edit_hint)
	document.add_child(edit_hint)
	edit_hint.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	edit_hint.offset_left = -32; edit_hint.offset_right = -4
	edit_hint.modulate = EditorStyle.MUTED
	var saved: Label = overlay.get_node("EditorSaveLabel")
	_reset(saved)
	saved.custom_minimum_size = Vector2(110,0)
	saved.clip_text = true
	saved.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	saved.add_theme_font_size_override("font_size",13)
	saved.add_theme_color_override("font_color",EditorStyle.MUTED)
	saved.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	var history: PanelContainer = overlay.get_node("EditorHistory")
	history.reparent(row); _reset(history)
	history.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	EditorStyle.quiet(app.editor_undo); EditorStyle.quiet(app.editor_redo)
	var old_view: Control = overlay.get_node("EditorViewControls")
	var view := HBoxContainer.new()
	view.name = "EditorViewControls"
	view.add_theme_constant_override("separation",2)
	row.add_child(view)
	for button: Button in old_view.get_children():
		button.reparent(view); _reset(button)
		(button as EditorButton).caption = ""
		button.text = ""
		button.custom_minimum_size = Vector2(48,48)
		EditorStyle.quiet(button)
	old_view.get_parent().remove_child(old_view); old_view.queue_free()
	var actions: HBoxContainer = overlay.get_node("EditorHeaderActions")
	actions.reparent(row); _reset(actions)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved.reparent(actions); actions.move_child(saved,1)
	# Publication is a document action; it does not need a disabled canvas slot.
	var document_actions: Control = app.share_button.get_parent()
	app.publish_button.reparent(document_actions)
	document_actions.move_child(app.publish_button,3)
	app.publish_button.custom_minimum_size = Vector2(0,48)
	for button: Control in actions.get_children():
		if button is Button:
			button.custom_minimum_size.y = 48
			if button != app.test_button: EditorStyle.quiet(button)
			if button.name == "EditorSaveAction": button.custom_minimum_size.x = 64
	var close: Button = overlay.get_node("CloseEditor")
	close.reparent(actions); _reset(close); EditorStyle.quiet(close)
	for button: Button in [app.editor_undo,app.editor_redo,close]: button.custom_minimum_size = Vector2(48,48)
	var dock := PanelContainer.new()
	dock.name = "EditorToolDock"
	dock.add_theme_stylebox_override("panel",EditorStyle.workspace_panel())
	overlay.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 16; dock.offset_right = -16; dock.offset_bottom = -12
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	dock.add_child(column)
	var heading := HBoxContainer.new()
	heading.name = "EditorDockHeading"
	heading.add_theme_constant_override("separation",14)
	column.add_child(heading)
	var title := Label.new()
	title.name = "EditorDockTitle"
	title.add_theme_font_override("font",EditorStyle.FONT)
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",EditorStyle.INK)
	heading.add_child(title)
	title.hide()
	app.editor_status.reparent(heading); _reset(app.editor_status)
	app.editor_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.editor_status.custom_minimum_size = Vector2(0,22)
	app.editor_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	app.editor_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app.editor_status.clip_text = true
	app.editor_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	app.editor_status.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	app.editor_status.add_theme_color_override("font_color",EditorStyle.MUTED)
	var browse: Button = EditorStyle.button("Objects",func() -> void:
		set_picker(app,not bool(overlay.get_meta("object_picker_open",false))))
	browse.name = "EditorBrowseObjects"
	browse.custom_minimum_size = Vector2(116,48)
	EditorStyle.quiet(browse)
	heading.add_child(browse)
	app.editor_save_button.reparent(heading); _reset(app.editor_save_button)
	var body := HBoxContainer.new()
	body.name = "EditorDockBody"
	body.add_theme_constant_override("separation",12)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(body)
	var old_palette: Control = app.editor_palette
	var palette := HBoxContainer.new()
	palette.name = "EditorPalette"
	body.add_child(palette)
	var palette_content: Control = old_palette.get_child(0)
	palette_content.reparent(palette)
	palette_content.size_flags_horizontal = Control.SIZE_FILL
	old_palette.get_parent().remove_child(old_palette); old_palette.queue_free()
	app.editor_palette = palette
	app.editor_palette.size_flags_horizontal = Control.SIZE_FILL
	(app.editor_palette.get_child(0) as PanelContainer).add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	(app.editor_context.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	(app.editor_context.get_parent() as ScrollContainer).custom_minimum_size.y = 56
	install_menu_panel(app.editor_tools_panel,app.editor_inspector,"Surfaces")
	var map_scroll: ScrollContainer = app.editor_map_panel.get_child(0)
	install_menu_panel(app.editor_map_panel,map_scroll,"Track")
	app.editor_inspector.minimum_size_changed.connect(func() -> void: arrange.call_deferred(app))
	app.editor_tools_panel.visibility_changed.connect(func() -> void: arrange.call_deferred(app))
	app.surface_toolbar.reparent(body); _reset(app.surface_toolbar)
	app.surface_toolbar.size_flags_horizontal = Control.SIZE_FILL
	app.surface_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	app.surface_toolbar.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	app.object_controls_panel.reparent(body); _reset(app.object_controls_panel)
	app.object_controls_panel.size_flags_horizontal = Control.SIZE_FILL
	app.object_controls_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	app.object_browser.reparent(column); _reset(app.object_browser)
	app.object_browser.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	app.object_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Loading is a compact status in the same dock, never a centre-screen card.
	app.editor_loading.reparent(heading); _reset(app.editor_loading)
	app.editor_loading.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for key: String in app.editor_mode_buttons:
		var button: EditorButton = app.editor_mode_buttons[key]
		button.glyph = {"road":"road_nav","paint":"surface","objects":"objects_nav"}[key]
		EditorStyle.card(button)
	for panel: Control in [header,dock]: panel.minimum_size_changed.connect(arrange.bind(app))
	overlay.resized.connect(arrange.bind(app))
	set_picker(app,false,false)
	arrange.call_deferred(app)

static func set_picker(app: Node, opened: bool, rebuild: bool = true) -> void:
	if not is_instance_valid(app.canvas): return
	var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false)
	if overlay == null: return
	app.canvas.cancel_gesture(false)
	if opened: app.canvas.navigation_override = false
	overlay.set_meta("object_picker_open",opened)
	if opened: app.object_browser.reveal_current()
	if rebuild: app._build_editor_tools()

static func selection_changed(app: Node) -> void:
	if is_instance_valid(app.canvas) and app.canvas.mode == "objects" and app.canvas.selected_object >= 0:
		var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false)
		if overlay != null: overlay.set_meta("object_picker_open",false)
	app._build_editor_tools()

static func refresh(app: Node, category: String) -> void:
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	if dock == null: return
	var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false)
	var picker: bool = category == "objects" and bool(overlay.get_meta("object_picker_open",false))
	app.object_browser.visible = picker
	app.object_controls_panel.visible = category == "objects" and not picker
	app.editor_palette.visible = category != "objects" or (not picker and app.canvas.selected_object >= 0)
	app.surface_toolbar.visible = category == "paint"
	var browse: Button = dock.find_child("EditorBrowseObjects",true,false)
	var adjusting: bool = category == "objects" and app.editor_object_property != ""
	browse.visible = category == "objects" and not adjusting
	if adjusting: app.editor_palette.hide()
	browse.text = GameText.message("Close") if picker else GameText.message("Objects")+" ▾"
	browse.custom_minimum_size.x = 64 if picker else 116
	var body: Control = dock.find_child("EditorDockBody",true,false)
	var browse_parent: Control = app.object_browser.find_child("ObjectBrowserNavigation",true,false) if picker else body
	if browse.get_parent() != browse_parent:
		browse.reparent(browse_parent)
		browse_parent.move_child(browse,browse_parent.get_child_count()-1)
	body.visible = not picker
	var title: Label = dock.find_child("EditorDockTitle",true,false)
	if title.get_parent() != body:
		title.reparent(body); _reset(title)
		title.custom_minimum_size.x = 108
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size",16)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.move_child(title,0)
	title.visible = category == "objects" and not picker and not adjusting
	title.text = GameText.message({"road":"Road","paint":"Surfaces","objects":"Objects"}[category])
	if category == "objects" and not picker:
		var selected: bool = app.canvas.mode == "objects" and app.canvas.selected_object >= 0
		var kind: String = str(app.document.objects[app.canvas.selected_object].kind) if selected else app.canvas.stamp_kind
		title.text = GameText.message(CreatorCatalog.label(kind))
		if selected and app.canvas.object_indices().size() > 1: title.text = GameText.message("Objects")
	if category == "objects":
		app.object_controls_panel.get_parent().move_child(app.object_controls_panel,1)
		for button: Button in app.editor_context.get_children():
			if button.text == "Palette": button.hide()
			else:
				button.custom_minimum_size = Vector2(76,56)
				(button as EditorButton).compact = true
				EditorStyle.card(button)
	elif category == "paint":
		for button: Button in app.editor_context.get_children():
			button.custom_minimum_size = Vector2(maxf(76,EditorStyle.FONT.get_string_size(GameText.message(button.text),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20),56)
			EditorStyle.card(button,button.button_pressed)
	_compact_controls(app.object_controls_panel)
	_compact_controls(app.surface_toolbar)
	if category == "road": _compact_controls(app.editor_palette)
	EditorStyle.menu_tree(app.editor_inspector)
	var commands: ScrollContainer = app.editor_map_panel.find_child("EditorMenuScroll",true,false)
	if commands != null and commands.get_child_count() > 0: EditorStyle.menu_tree(commands.get_child(0))
	EditorStyle.popup((app.object_browser.find_child("ObjectSnap",true,false) as OptionButton).get_popup())
	app.editor_status.tooltip_text = app.editor_status.text
	arrange.call_deferred(app)

static func arrange(app: Node) -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.canvas) or not is_instance_valid(app.root_ui): return
	var overlay: Control = app.root_ui.find_child("EditorOverlay",true,false)
	var dock: PanelContainer = app.root_ui.find_child("EditorToolDock",true,false)
	var header: PanelContainer = app.root_ui.find_child("EditorTopBar",true,false)
	if overlay == null or dock == null or header == null: return
	var picker: bool = app.object_browser.visible
	var heading: Control = dock.find_child("EditorDockHeading",true,false)
	heading.visible = (not picker and app.canvas.mode == "road") or app.canvas.navigation_override or app.editor_hint_active or app.editor_save_error != OK or app.editor_loading.visible
	var height: float = dock.get_combined_minimum_size().y
	dock.offset_top = -12-height
	var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false)
	if rail != null:
		var middle: float = (header.offset_bottom+dock.position.y)*0.5
		rail.position.y = middle-rail.size.y*0.5
	var body: Control = dock.find_child("EditorDockBody",true,false)
	var available: float = maxf(200,dock.size.x-16)
	var palette_width: float = app.editor_context.get_combined_minimum_size().x if app.editor_palette.visible else 0.0
	var fixed: float = 0
	var count: int = 0
	for child: Control in body.get_children():
		if not child.visible: continue
		count += 1
		if child not in [app.editor_palette,app.object_controls_panel]: fixed += child.get_combined_minimum_size().x
	var room: float = available-fixed-maxi(0,count-1)*body.get_theme_constant("separation")
	if app.object_controls_panel.visible:
		var property_scroll: ScrollContainer = app.object_controls.get_parent()
		property_scroll.custom_minimum_size.x = minf(app.object_controls.get_combined_minimum_size().x,maxf(140,room-palette_width))
		app.object_controls.size_flags_horizontal = Control.SIZE_FILL
		room -= property_scroll.custom_minimum_size.x
	if app.editor_palette.visible:
		var scroll: ScrollContainer = app.editor_context.get_parent()
		scroll.custom_minimum_size.x = minf(palette_width,maxf(140,room))
		app.editor_palette.size_flags_horizontal = Control.SIZE_FILL
	var navigation: HBoxContainer = app.object_browser.find_child("ObjectBrowserNavigation",true,false)
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	var tabs: ScrollContainer = app.object_browser.categories.get_parent()
	var utilities: float = 0
	for child: Control in navigation.get_children():
		if child != tabs and child.visible: utilities += child.get_combined_minimum_size().x+navigation.get_theme_constant("separation")
	tabs.custom_minimum_size.x = minf(app.object_browser.categories.get_combined_minimum_size().x,maxf(140,available-utilities))
	tabs.size_flags_horizontal = Control.SIZE_FILL
	app.object_browser.tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	var brush_scroll: ScrollContainer = app.editor_tools_panel.find_child("EditorMenuScroll",true,false)
	fit_menu_panel(overlay,app.editor_tools_panel,brush_scroll,app.editor_inspector)
	var map_scroll: ScrollContainer = app.editor_map_panel.find_child("EditorMenuScroll",true,false)
	if map_scroll != null and map_scroll.get_child_count() > 0:
		fit_menu_panel(overlay,app.editor_map_panel,map_scroll,map_scroll.get_child(0))
	update_document_name(app)
	# Keep the same dock width and alignment across tools and selections.
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	app.canvas.queue_redraw()

static func update_document_name(app: Node) -> void:
	if not is_instance_valid(app.root_ui): return
	var title: Label = app.root_ui.find_child("TrackName",true,false)
	if title == null: return
	var name: String = str(app.document.get("name",""))
	var unnamed: bool = name.strip_edges().is_empty() or (name == "My circuit" and app.editor_saved_snapshot.is_empty())
	title.text = GameText.message("New track") if unnamed else name
	title.get_parent().tooltip_text = title.text+" / "+GameText.message("Rename track")

static func _compact_controls(parent: Node) -> void:
	for control: Node in parent.get_children():
		if control is EditorButton:
			control.compact = true
			control.custom_minimum_size.y = 56 if not control.caption.is_empty() else 48
			if control.glyph.begins_with("terrain_"):
				control.custom_minimum_size.x = maxf(76,EditorStyle.FONT.get_string_size(GameText.message(control.caption),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20)
		elif control is OptionButton: control.custom_minimum_size.y = 56
		if control is BaseButton: EditorStyle.card(control,control.button_pressed)
		if control is Label: control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if control is OptionButton: EditorStyle.popup(control.get_popup())
		_compact_controls(control)

static func install_menu_panel(panel: PanelContainer, content: Control, title: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label: Label = MenuStyle.label(title,18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var close: Button = EditorButton.make("","close",panel.hide)
	close.name = "Close"+str(panel.name)
	close.tooltip_text = GameText.message("Close")
	close.custom_minimum_size = Vector2(48,48)
	EditorStyle.quiet(close)
	heading.add_child(close)
	var scroll: ScrollContainer
	if content is ScrollContainer:
		scroll = content; content.reparent(column)
	else:
		scroll = ScrollContainer.new()
		column.add_child(scroll); content.reparent(scroll)
	scroll.name = "EditorMenuScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if not content is ScrollContainer: content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -322; panel.offset_right = -16
	panel.offset_top = 76; panel.offset_bottom = 76

static func fit_menu_panel(overlay: Control, panel: PanelContainer, scroll: ScrollContainer, content: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(scroll): return
	var header: Control = overlay.get_node_or_null("EditorTopBar")
	var dock: Control = overlay.get_node_or_null("EditorToolDock")
	if header == null or dock == null: return
	var top: float = header.position.y+header.size.y+8
	var bottom: float = dock.position.y-8
	var chrome: float = panel.get_combined_minimum_size().y-scroll.get_combined_minimum_size().y
	scroll.custom_minimum_size.x = 288 if panel.name == "EditorTools" else 232
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y,maxf(48,bottom-top-chrome))
	panel.position.y = top
	panel.size.y = panel.get_combined_minimum_size().y
