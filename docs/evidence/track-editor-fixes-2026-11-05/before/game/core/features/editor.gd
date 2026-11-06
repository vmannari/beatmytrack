extends Node
## Editor composition. State and scene ownership stay with App.
const PublicationPrompt = preload("res://ui/publication_dialog.gd")

func run_queue_editor_preview(app: Node) -> void:
	if app.editor_preview_thread != null:
		if app.editor_preview_cancel != null and app.document != app.editor_preview_document: app.editor_preview_cancel.cancel()
		return
	app.editor_preview_document = app.document.duplicate(true)
	app.editor_preview_thread = Thread.new()
	app.editor_preview_cancel = preload("res://editor/work_job.gd").new()
	var error: Error = app.editor_preview_thread.start(app._compile_editor_preview.bind(app.editor_preview_document,app.editor_preview_cancel.cancelled))
	if error != OK:
		app.editor_preview_thread = null
		var track: NativeTrack = app._compile_editor_preview(app.editor_preview_document)
		app.editor_preview_document = {}
		if track != null: app.canvas.show_native(track)
		app._update_editor_issues()

func run_objects_only_edit(app: Node) -> bool:
	if not is_instance_valid(app.canvas) or app.canvas.native_preview == null: return false
	var previous: Dictionary = app.canvas.native_preview.metadata.get("creator_document",{})
	for key: Variant in app.document:
		if key in ["objects","hidden_scenery"]: continue
		if not previous.has(key) or previous[key] != app.document[key]: return false
	for key: Variant in previous:
		if key not in ["objects","hidden_scenery"] and not app.document.has(key): return false
	return true


func run_editor(app: Node) -> void:
	app._stamp_creator()
	if app.document.is_empty():
		app.document = TrackDocument.create_blank()
		app.document.id = TrackLibrary.unique_id()
		app._stamp_creator()
	if app.editor_pending_id != str(app.document.id):
		app.editor_pending_tools.clear()
		app.editor_pending_id = str(app.document.id)
		app.editor_save_error = OK
		app.editor_retry_original = false
		app.editor_save_message = ""
		app.editor_wip_saved = ""
		app.editor_wip_snapshot.clear()
		app.editor_wip_store = null
		app.editor_wip_disk_hash = ""
		app.editor_issue_cursor = -1
	app.editor_world = EditorWorld.new()
	app.editor_world._detail.enabled = not bool(app.editor_view.get("detailed_scenery",false))
	app.editor_session.prime(app.document)
	app.editor_world.theme_id = str(app.document.theme)
	app.root_ui.add_child(app.editor_world)
	MenuStyle.fill(app.editor_world)
	app.canvas = EditorCanvas.new()
	app.canvas.stamp_kind = "rock" if app.document.theme == "desert" else "light" if app.document.theme == "night_city" else "tree"
	app.canvas.document = app.document
	if not app.editor_view.is_empty():
		app.canvas.zoom = app.editor_view.zoom
		app.canvas.pan = app.editor_view.pan
		app.canvas.mode = app.editor_view.mode
		app.canvas.selected = mini(int(app.editor_view.get("selected",-1)),app.document.points.size()-1)
		app.canvas.selected_object = mini(int(app.editor_view.get("selected_object",-1)),app.document.objects.size()-1)
		app.canvas.selected_piece = mini(int(app.editor_view.get("selected_piece",-1)),app.document.pieces.size()-1)
		app.canvas.multi_select = bool(app.editor_view.get("multi_select",false))
		app.canvas.selected_objects.assign(app.editor_view.get("selected_objects",[]))
		app.canvas.object_snap = float(app.editor_view.get("object_snap",1.0))
		app.canvas.stamp_kind = str(app.editor_view.get("stamp_kind","tree"))
		app.canvas.stamp_scale = float(app.editor_view.get("stamp_scale",1.0))
		app.canvas.stamp_span = float(app.editor_view.get("stamp_span",8.0))
		app.canvas.stamp_jump_profile = str(app.editor_view.get("stamp_jump_profile",""))
		app.canvas.run_shape = str(app.editor_view.get("run_shape","line"))
		app.canvas.free_run = bool(app.editor_view.get("free_run",false))
		app.canvas.brush_surface = int(app.editor_view.get("brush_surface",0))
		app.canvas.brush_width = float(app.editor_view.get("brush_width",10))
		app.canvas.brush_shape = str(app.editor_view.get("brush_shape","round"))
		app.canvas.paint_mode = str(app.editor_view.get("paint_mode","free"))
		app.canvas.fitted = true
	app.root_ui.add_child(app.canvas)
	MenuStyle.fill(app.canvas)
	app.editor_world.follow_canvas(app.canvas)
	app.canvas.native_changed.connect(app.editor_world.show_track)
	app.canvas.edit_started.connect(func() -> void:
		app.editor_session.begin_gesture(app.document)
		if app.canvas.mode in ["move","add"]: app.document.route_override = true)
	app.canvas.document_changed.connect(func() -> void:
		app.canvas.refresh()
		app.test_button.disabled = true
		app.publish_button.disabled = true
		app.share_button.disabled = true)
	app.canvas.edit_finished.connect(func() -> void:
		app._save_draft(true)
		app.editor_session.finish_gesture())
	app.canvas.edit_cancelled.connect(func() -> void:
		app.editor_session.cancel_gesture()
		app.canvas.selected_object = mini(app.canvas.selected_object,app.document.objects.size()-1)
		app._save_draft(true)
		app._update_editor_issues()
		app._build_editor_tools())
	app.canvas.hint_changed.connect(app._editor_hint)
	var overlay = Control.new()
	overlay.name = "EditorOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.root_ui.add_child(overlay)
	MenuStyle.fill(overlay)
	var close: Button = EditorButton.make("","close",func() -> void:
		app._request_editor_exit())
	close.name="CloseEditor"
	close.tooltip_text="Close editor"
	overlay.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-68; close.offset_right=-16; close.offset_top=16; close.offset_bottom=68
	var header_left = HBoxContainer.new()
	header_left.name="EditorIdentityAndHistory"
	header_left.position=Vector2(16,16)
	header_left.add_theme_constant_override("separation",12)
	overlay.add_child(header_left)
	var title = HBoxContainer.new()
	var title_panel = PanelContainer.new()
	var title_style: StyleBoxFlat=EditorStyle.panel()
	title_style.content_margin_top=0
	title_style.content_margin_bottom=0
	title_panel.add_theme_stylebox_override("panel",title_style)
	header_left.add_child(title_panel)
	title_panel.add_child(title)
	title.add_theme_constant_override("separation",4)
	var track_name = Label.new()
	track_name.name="TrackName"
	track_name.text=str(app.document.name)
	track_name.custom_minimum_size=Vector2(160,52)
	track_name.clip_text=true
	track_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	track_name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	track_name.add_theme_font_override("font",EditorStyle.FONT)
	track_name.add_theme_font_size_override("font_size",20)
	track_name.add_theme_color_override("font_color",EditorStyle.INK)
	title.add_child(track_name)
	var pencil: Button=EditorButton.make("","pencil",app._rename_track)
	EditorStyle.transparent_button(pencil)
	pencil.name="RenameTrack"
	pencil.tooltip_text="Rename track"
	title.add_child(pencil)
	var history_panel = PanelContainer.new()
	history_panel.name="EditorHistory"
	history_panel.add_theme_stylebox_override("panel",title_style.duplicate())
	overlay.add_child(history_panel)
	var history = HBoxContainer.new()
	history.add_theme_constant_override("separation",4)
	history_panel.add_child(history)
	app.editor_undo=EditorButton.make("","undo",app._undo)
	app.editor_undo.text="Undo"
	EditorStyle.integrated(app.editor_undo)
	app.editor_undo.tooltip_text="Undo"
	history.add_child(app.editor_undo)
	app.editor_redo=EditorButton.make("","redo",app._redo)
	app.editor_redo.text="Redo"
	EditorStyle.integrated(app.editor_redo)
	app.editor_redo.tooltip_text="Redo"
	history.add_child(app.editor_redo)
	var top = HBoxContainer.new()
	top.name = "EditorHeaderActions"
	top.alignment = BoxContainer.ALIGNMENT_END
	# The right-aligned container is wider than its visible buttons. Empty
	# space must not intercept the history controls when Issues is hidden.
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -600; top.offset_right = -80; top.offset_top = 16
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.add_theme_constant_override("separation",8)
	app.editor_issue_button = EditorStyle.button("",app._focus_issue)
	app.editor_issue_button.custom_minimum_size = Vector2(112,52)
	top.add_child(app.editor_issue_button)
	var settings: Button = EditorButton.make("","more",func() -> void:
		app.canvas.cancel_gesture()
		app.editor_map_panel.visible = not app.editor_map_panel.visible
		app.editor_tools_panel.hide())
	settings.text = "Map"
	settings.tooltip_text = "Map settings"
	top.add_child(settings)
	var save_action: Button = EditorStyle.button("Save",app._save_track_explicit)
	save_action.name = "EditorSaveAction"
	save_action.custom_minimum_size = Vector2(76,52)
	top.add_child(save_action)
	app.test_button = EditorButton.action("Test","play",app._test_document)
	app.test_button.custom_minimum_size=Vector2(104,52)
	top.add_child(app.test_button)
	EditorStyle.apply(app.test_button)
	var disabled_play: StyleBoxFlat=EditorStyle.box()
	disabled_play.bg_color=Color("252d30")
	disabled_play.border_color=Color("586369")
	disabled_play.shadow_size=0
	app.test_button.add_theme_stylebox_override("disabled",disabled_play)
	for state: String in ["normal","hover","pressed","hover_pressed"]:
		var play_style: StyleBoxFlat=EditorStyle.box()
		play_style.bg_color=Color("29412e") if state=="hover" else Color(0.075,0.14,0.095,0.94)
		play_style.border_color=Color(0.65,0.82,0.43,0.45)
		play_style.set_border_width_all(1)
		app.test_button.add_theme_stylebox_override(state,play_style)
	app.publish_button = EditorButton.action("Publish","publish",app._publish_current_document,true)
	app.publish_button.name = "PublishTrack"
	app.publish_button.tooltip_text = "Complete a test drive before publishing this version."
	app.publish_button.custom_minimum_size=Vector2(132,52)
	top.add_child(app.publish_button)
	# Center history while keeping clear of the title and right-hand actions.
	var fit_header: Callable = app._fit_editor_header.bind(overlay,header_left,track_name,history_panel,top)
	overlay.resized.connect(fit_header)
	top.minimum_size_changed.connect(fit_header)
	app.editor_issue_button.visibility_changed.connect(fit_header)
	fit_header.call_deferred()
	var rail = VBoxContainer.new()
	rail.name = "EditorRail"
	var rail_panel = PanelContainer.new()
	rail_panel.name = "EditorRailPanel"
	rail_panel.anchor_top=0.5; rail_panel.anchor_bottom=0.5
	rail_panel.offset_left=16
	rail_panel.grow_vertical=Control.GROW_DIRECTION_BOTH
	rail_panel.resized.connect(func() -> void: rail_panel.offset_top=-rail_panel.size.y*0.5; rail_panel.offset_bottom=rail_panel.size.y*0.5)
	rail_panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(rail_panel)
	rail_panel.add_child(rail)
	rail.add_theme_constant_override("separation",6)
	app.editor_mode_buttons.clear()
	for pair: Array in [["road","Track","road"],["paint","Surfaces","surface"],["objects","Objects","objects"]]:
		var value: String = pair[0]
		var button: Button = EditorButton.make(pair[1],pair[2],app._editor_category.bind(value))
		button.name = "Editor"+({"road":"Road","paint":"Surface"}.get(value,pair[1]))
		button.custom_minimum_size=Vector2(86,76)
		button.toggle_mode = true
		EditorStyle.integrated(button)
		app.editor_mode_buttons[value] = button
		rail.add_child(button)
	var bottom = CenterContainer.new()
	app.editor_palette = bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 108; bottom.offset_right = -112; bottom.offset_top = -98; bottom.offset_bottom = -16
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",app._editor_box())
	bottom.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360,68)
	panel.add_child(scroll)
	app.editor_context = HBoxContainer.new()
	app.editor_context.add_theme_constant_override("separation",6)
	scroll.add_child(app.editor_context)
	app.surface_toolbar = PanelContainer.new()
	app.surface_toolbar.name = "SurfacePlacementToolbar"
	app.surface_toolbar.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(app.surface_toolbar)
	app.surface_toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	app.surface_toolbar.offset_left = -270
	app.surface_toolbar.offset_right = 270
	app.surface_toolbar.offset_top = 78
	app.surface_toolbar.offset_bottom = 180
	app.surface_toolbar.resized.connect(app._layout_editor_surface_toolbar)
	app.surface_actions = HBoxContainer.new()
	app.surface_actions.add_theme_constant_override("separation",8)
	app.surface_toolbar.add_child(app.surface_actions)
	app.editor_hint_active = false
	app.editor_status = MenuStyle.label("",17)
	app.editor_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(app.editor_status)
	app.editor_status.name = "EditorFeedback"
	app.editor_status.position = Vector2(16,128)
	app.editor_status.size = Vector2(320,80)
	app.editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.editor_status.add_theme_font_size_override("font_size",15)
	app.editor_status.add_theme_stylebox_override("normal",EditorStyle.panel())
	app.editor_status.hide()
	app.editor_save_button = EditorStyle.button("Draft",app._retry_editor_save)
	app.editor_save_button.name = "EditorSaveState"
	app.editor_save_button.position = Vector2(16,78)
	app.editor_save_button.custom_minimum_size = Vector2(260,42)
	overlay.add_child(app.editor_save_button)
	app._update_editor_save_state()
	app.editor_loading = PanelContainer.new()
	app.editor_loading.name = "EditorPreparation"
	app.editor_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.editor_loading.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(app.editor_loading)
	app.editor_loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	app.editor_loading.offset_left = -110; app.editor_loading.offset_right = 110
	app.editor_loading.offset_top = 198; app.editor_loading.offset_bottom = 240
	var preparing: Label = MenuStyle.label("Preparing track…",17)
	preparing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app.editor_loading.add_child(preparing)
	app.object_browser = ObjectBrowser.new()
	app.object_browser.visible = false
	for key: String in app.object_browser_state: app.object_browser.set(key,app.object_browser_state[key])
	app.object_browser.current = CreatorCatalog.jump_asset(app.canvas.stamp_jump_profile,str(app.document.theme)) if app.canvas.stamp_kind == "jump" else app.canvas.stamp_kind
	app.object_browser.stamp_span = app.canvas.stamp_span
	app.object_browser.stamp_container_color = app.canvas.stamp_container_color
	app.object_browser.biome = str(app.document.get("biome",app.document.theme))
	overlay.add_child(app.object_browser)
	app.object_browser.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	app.object_browser.offset_left = 108; app.object_browser.offset_right = -112
	app.object_browser.offset_top = -174; app.object_browser.offset_bottom = -16
	app.object_browser.hide()
	app.object_browser.asset_chosen.connect(app._choose_object)
	app.object_browser.mode_chosen.connect(app._object_placement)
	app.object_browser.size_chosen.connect(func(value: float) -> void: app.canvas.stamp_scale=value)
	app.object_browser.span_chosen.connect(func(value: float) -> void: app.canvas.stamp_span=value)
	app.object_browser.container_color_chosen.connect(app._container_colour)
	app.object_browser.rotation_requested.connect(app._object_rotation_dialog)
	app.object_browser.rotation_chosen.connect(app._set_object_rotation)
	app.object_browser.controls_requested.connect(func() -> void: app._object_property_editing(""))
	app.object_controls_panel = PanelContainer.new()
	app.object_controls_panel.name = "ObjectControlStrip"
	app.object_controls_panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(app.object_controls_panel)
	app.object_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	app.object_controls_panel.offset_left = 108
	app.object_controls_panel.offset_right = -112
	var property_scroll = ScrollContainer.new()
	property_scroll.name = "ObjectControlScroll"
	# Keep the strip's height stable when its controls exceed the available
	# width; the row still supports horizontal dragging just like the palette.
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	property_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app.object_controls_panel.add_child(property_scroll)
	app.object_controls = app.object_browser.options
	app.object_controls.reparent(property_scroll)
	app.object_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.object_controls.edited.connect(app._edit_object_control)
	app.object_controls.editing_changed.connect(app._object_property_editing)
	app.object_controls.fit_requested.connect(func() -> void: app._fit_speed_bump())
	app.object_browser.snap_step = app.canvas.object_snap
	app.object_browser.snap_chosen.connect(func(step: float) -> void: app.canvas.object_snap = step)
	app.object_browser.select_requested.connect(func() -> void:
		app.canvas.cancel_gesture(); app.canvas.mode="objects"; app._build_editor_tools())
	app.object_browser.populate_requested.connect(app._open_object_population)
	app.editor_tools_panel = app._editor_panel(overlay,"EditorTools")
	app.editor_inspector = VBoxContainer.new()
	app.editor_tools_panel.add_child(app.editor_inspector)
	app.editor_map_panel = app._editor_panel(overlay,"EditorMap")
	app.editor_map_panel.anchor_bottom=0
	app.editor_map_panel.offset_bottom=82
	app.editor_map_panel.offset_left=-268
	var metadata = VBoxContainer.new()
	app.editor_map_panel.add_child(metadata)
	for entry: Array in [["New",app._new_document],["Load",app._load_track_dialog],["Save",app._save_track_explicit]]:
		var command: Button=EditorStyle.button(entry[0],entry[1])
		command.name=entry[0]+"Track"
		metadata.add_child(command)
	var fit_view: Button = EditorStyle.button("Fit view",func() -> void:
		app.editor_map_panel.hide()
		app.canvas.fit())
	fit_view.name = "EditorFitView"
	metadata.add_child(fit_view)
	app.share_button=EditorStyle.button("Share",app._share_dialog)
	metadata.add_child(app.share_button)
	metadata.add_child(EditorStyle.button("Help",app._editor_help))
	var detail: CheckButton = CheckButton.new()
	detail.name = "EditorDetailedScenery"
	detail.text = "Detailed scenery"
	detail.button_pressed = not app.editor_world._detail.enabled
	detail.custom_minimum_size.y = 48
	detail.toggled.connect(func(enabled: bool) -> void:
		app.editor_world._detail.enabled = not enabled)
	metadata.add_child(detail)
	if str(app.document.theme) == "night_city":
		var lighting: Button = EditorStyle.button("Race lighting",func() -> void: pass)
		lighting.name = "EditorRaceLighting"
		lighting.toggle_mode = true
		lighting.toggled.connect(app.editor_world.set_race_lighting_preview)
		metadata.add_child(lighting)
	app.canvas.selection_changed.connect(app._build_editor_tools)
	app.canvas.fit_area = app._editor_fit_area
	app.surface_toolbar.resized.connect(app._layout_editor_feedback)
	app._restore_pending_tool(app._editor_tool())
	app._build_editor_tools()
	app._refresh_editor()
	app._update_editor_save_state()
	# Reuse an exact completed preview if the worker is idle; otherwise let the
	# existing single worker prepare the newest document while controls render.
	var cached_preview: NativeTrack
	if app.editor_preview_thread == null:
		for entry: Dictionary in app.editor_compiled_cache:
			if entry.document == app.document: cached_preview = entry.track; break
	if cached_preview != null: app.canvas.show_native(cached_preview)
	else: app._queue_editor_preview()
	app._update_editor_issues()
	if app.editor_view.is_empty(): app.canvas.call_deferred("fit")
	app._apply_editor_safe_area(overlay)
	app.root_ui.resized.connect(app._apply_editor_safe_area.bind(overlay))
	app.root_ui.resized.connect(app._layout_editor_feedback)
	app.root_ui.resized.connect(app._layout_editor_surface_toolbar)

func run_fit_editor_header(app: Node, overlay: Control, header: HBoxContainer, track_title: Label, history_panel: PanelContainer, actions: HBoxContainer) -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(header) or not is_instance_valid(history_panel) or not is_instance_valid(actions): return
	var history_width: float = history_panel.get_combined_minimum_size().x
	var actions_left: float = overlay.size.x-80.0-actions.get_combined_minimum_size().x
	var available_title: float = actions_left-header.position.x-history_width-16.0
	var title_extra: float = header.get_combined_minimum_size().x-track_title.custom_minimum_size.x
	track_title.custom_minimum_size.x = clampf(available_title-title_extra,40.0,160.0)
	header.size = header.get_combined_minimum_size()
	history_panel.size = history_panel.get_combined_minimum_size()
	var minimum_x: float = header.position.x+header.size.x+8.0
	var maximum_x: float = maxf(minimum_x,actions_left-history_width-8.0)
	history_panel.position = Vector2(clampf((overlay.size.x-history_width)*0.5,minimum_x,maximum_x),16.0)


func run_editor_box(app: Node) -> StyleBoxFlat:
	return EditorStyle.panel()


func run_layout_editor_surface_toolbar(app: Node) -> void:
	if not is_instance_valid(app.surface_toolbar): return
	var overlay: Control = app.surface_toolbar.get_parent() as Control
	var width: float = app.surface_toolbar.size.x
	var left: float = (overlay.size.x-width)*0.5
	if is_instance_valid(app.editor_save_button) and app.editor_save_button.is_visible_in_tree():
		left = maxf(left,app.editor_save_button.get_global_rect().end.x-overlay.global_position.x+8)
	left = minf(left,overlay.size.x-width-16)
	app.surface_toolbar.offset_left = left-overlay.size.x*0.5
	app.surface_toolbar.offset_right = app.surface_toolbar.offset_left+width


func run_layout_editor_feedback(app: Node) -> void:
	if not is_instance_valid(app.editor_status) or not is_instance_valid(app.canvas): return
	if app.root_ui.size.y < 672:
		var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false) as Control
		var origin: Vector2 = (app.editor_status.get_parent() as Control).global_position
		var left: float = rail.get_global_rect().end.x+8-origin.x if is_instance_valid(rail) else 124.0
		var top: float = app.surface_toolbar.get_global_rect().end.y+8-origin.y if is_instance_valid(app.surface_toolbar) and app.surface_toolbar.is_visible_in_tree() else 128.0
		app.editor_status.position = Vector2(left,top)
		app.editor_status.size = Vector2(270,80)
	else:
		app.editor_status.position = Vector2(16,128)
		app.editor_status.size = Vector2(320,80)


## Keep a fitted circuit clear of the persistent rail, feedback and the
## currently open authoring panels. Manual pan and zoom remain unrestricted.
func run_editor_fit_area(app: Node) -> Rect2:
	var view: Rect2 = app.canvas.get_global_rect()
	var left: float = view.position.x+16
	var top: float = view.position.y+84
	var right: float = view.end.x-16
	var bottom: float = view.end.y-16
	var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false) as Control
	if is_instance_valid(rail) and rail.is_visible_in_tree(): left = maxf(left,rail.get_global_rect().end.x+8)
	if is_instance_valid(app.editor_status) and app.editor_status.is_visible_in_tree(): left = maxf(left,app.editor_status.get_global_rect().end.x+8)
	if is_instance_valid(app.surface_toolbar) and app.surface_toolbar.is_visible_in_tree(): top = maxf(top,app.surface_toolbar.get_global_rect().end.y+8)
	for panel: Control in [app.editor_palette,app.object_browser,app.object_controls_panel]:
		if is_instance_valid(panel) and panel.is_visible_in_tree(): bottom = minf(bottom,panel.get_global_rect().position.y-8)
	left = minf(left,view.position.x+view.size.x*0.5)
	return Rect2(Vector2(left,top)-view.position,Vector2(maxf(0,right-left),maxf(0,bottom-top)))


func run_editor_panel(app: Node, parent: Control, node_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = node_name
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -322; panel.offset_right = -16
	panel.offset_top = 82; panel.offset_bottom = -146
	panel.add_theme_stylebox_override("panel",app._editor_box())
	panel.hide()
	return panel

func run_apply_editor_safe_area(app: Node, overlay: Control) -> void:
	if not OS.has_feature("mobile"): return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	var factor: float = app.get_viewport().get_visible_rect().size.y/maxf(1,window.y)
	overlay.offset_left = maxf(0,safe.position.x*factor)
	overlay.offset_top = maxf(0,safe.position.y*factor)
	overlay.offset_right = -maxf(0,(window.x-safe.end.x)*factor)
	overlay.offset_bottom = -maxf(0,(window.y-safe.end.y)*factor)

func run_editor_hint(app: Node, message: String) -> void:
	if not is_instance_valid(app.editor_status): return
	app.editor_status.text = message
	app.editor_status.show()
	app.editor_hint_active = true
	app.editor_hint_generation += 1
	var generation: int = app.editor_hint_generation
	var label_id: int = app.editor_status.get_instance_id()
	app.get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if generation == app.editor_hint_generation and is_instance_valid(app.editor_status) and app.editor_status.get_instance_id() == label_id:
			app.editor_hint_active = false
			if app.editor_save_error == OK: app.editor_status.hide())

func run_update_editor_save_state(app: Node) -> void:
	if not is_instance_valid(app.editor_save_button): return
	app.editor_save_button.visible = app.editor_save_error != OK
	if app.editor_save_error != OK:
		app.editor_save_button.text = "Save failed · Retry"
		app.editor_save_button.disabled = false
		app.editor_save_button.tooltip_text = app.editor_save_message
		app.editor_save_button.add_theme_color_override("font_color",Color("ffbc8b"))
		if is_instance_valid(app.editor_status):
			app.editor_status.text = app.editor_save_message
			app.editor_status.show()
	elif app.editor_commits.unsettled() or app.editor_writes.unsettled(app.library,str(app.document.get("id",""))):
		app.editor_save_button.text = "Saving..."
		app.editor_save_button.disabled = true
		app.editor_save_button.tooltip_text = "Saving changes on this device."
	elif app._has_pending_editor_work():
		app.editor_save_button.text = "Preview pending"
		app.editor_save_button.disabled = true
		app.editor_save_button.tooltip_text = "Switching tools retains previews. Save confirms valid previews; Discard cancels them."
	elif not app.editor_saved_snapshot.is_empty() and app.document == app.editor_saved_snapshot:
		app.editor_save_button.text = "Saved on device"
		app.editor_save_button.disabled = true
		app.editor_save_button.tooltip_text = "The saved original matches this document."
	else:
		app.editor_save_button.text = "Autosaved draft" if (app.editor_wip_store == app.library and app.document == app.editor_wip_snapshot) else "Unsaved draft"
		app.editor_save_button.disabled = true
		app.editor_save_button.tooltip_text = "Your draft is kept separately. Save updates the named track."

func run_retry_editor_save(app: Node) -> void:
	if app.editor_retry_original: app._save_track_now()
	else: app._save_draft(true)

func run_editor_tool(app: Node) -> String:
	if not is_instance_valid(app.canvas): return "road"
	if app.canvas.mode in ["paint","pan"] or (app.canvas.mode == "place" and app.canvas.stamp_kind in ["puddle","water","dirt"]): return "paint"
	return "objects" if app.canvas.mode in ["objects","place","run"] else "road"

func run_capture_pending_tool(app: Node) -> Dictionary:
	var state: Dictionary = {"mode":app.canvas.mode}
	var keys: Array = {"road":["ghost","piece_kind","snap_matched"],"paint":["paint_points","paint_mode","brush_surface","brush_width","brush_shape","protect_road","stamp_kind","stamp_scale"],"objects":["run_start","run_preview","run_draw","run_shape","free_run","stamp_kind","stamp_scale","stamp_span","stamp_jump_profile","stamp_rotation","stamp_container_color"]}[app._editor_tool()]
	for key: String in keys:
		var value: Variant = app.canvas.get(key)
		state[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return state

func run_stash_pending_tool(app: Node) -> void:
	if is_instance_valid(app.canvas): app.editor_pending_tools[app._editor_tool()] = app._capture_pending_tool()

func run_restore_pending_tool(app: Node, tool: String) -> void:
	app.canvas.ghost = {}
	app.canvas.paint_points = []
	app.canvas.run_start = Vector2.INF
	app.canvas.run_preview = []
	app.canvas.run_draw = PackedVector2Array()
	app.canvas.mode = tool
	for key: String in app.editor_pending_tools.get(tool,{}): app.canvas.set(key,app.editor_pending_tools[tool][key])

func run_pending_state_has_work(app: Node, tool: String, state: Dictionary) -> bool:
	if tool == "road": return not state.get("ghost",{}).is_empty()
	if tool == "paint": return not state.get("paint_points",[]).is_empty()
	return state.get("run_start",Vector2.INF) != Vector2.INF or not state.get("run_preview",[]).is_empty() or state.get("run_draw",PackedVector2Array()).size() > 1

func run_has_pending_editor_work(app: Node) -> bool:
	var active: String = app._editor_tool()
	for tool: String in ["road","paint","objects"]:
		var state: Dictionary = app._capture_pending_tool() if is_instance_valid(app.canvas) and active == tool else app.editor_pending_tools.get(tool,{})
		if app._pending_state_has_work(tool,state): return true
	return false

func run_discard_editor_previews(app: Node) -> void:
	app.editor_pending_tools.clear()
	if not is_instance_valid(app.canvas): return
	app.canvas.changed_in_gesture = false
	app.canvas.cancel_gesture()
	app._restore_pending_tool(app._editor_tool())
	app.canvas.queue_redraw()

func run_commit_editor_previews(app: Node) -> bool:
	app._stash_pending_tool()
	var active: String = app._editor_tool()
	for tool: String in ["road","paint","objects"]:
		if not app._pending_state_has_work(tool,app.editor_pending_tools.get(tool,{})): continue
		app.canvas.changed_in_gesture = false
		app.canvas.cancel_gesture()
		app._restore_pending_tool(tool)
		if tool == "road": app.canvas.confirm_piece()
		elif tool == "paint": app.canvas.confirm_paint()
		elif app.canvas.run_preview.is_empty():
			app._editor_hint("Finish the object run, or cancel it before saving.")
		else:
			var additions: Array = preload("res://editor/creator_limits.gd").take(app.document.objects,app.canvas.run_preview,str(app.document.theme))
			if not app.canvas.admit("objects",app.document.objects+additions): return false
			app._remember()
			app.document.objects.append_array(additions)
			app.canvas.run_preview.clear(); app.canvas.run_draw.clear(); app.canvas.run_start = Vector2.INF
			app._save_draft(true)
		app._stash_pending_tool()
		if app._pending_state_has_work(tool,app.editor_pending_tools[tool]):
			app._build_editor_tools()
			app._notice("Complete or cancel this preview before saving. Your pending work is retained.")
			return false
	app._restore_pending_tool(active)
	app._build_editor_tools()
	return true

func run_resolve_editor_previews(app: Node, after: Callable, message: String = "Confirm or discard the pending previews before selecting an issue.") -> void:
	if app.root_ui.find_child("PendingPreviewDialog",true,false) != null: return
	var dialog = ConfirmationDialog.new()
	dialog.name = "PendingPreviewDialog"
	dialog.title = "Pending previews"
	dialog.dialog_text = message
	dialog.ok_button_text = "Confirm previews"
	dialog.add_button("Discard previews",true,"discard")
	dialog.confirmed.connect(func() -> void:
		dialog.hide()
		if app._commit_editor_previews(): after.call()
		dialog.queue_free())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			dialog.hide()
			app._discard_editor_previews()
			dialog.queue_free()
			after.call())
	dialog.canceled.connect(dialog.queue_free)
	app.root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(510,200))

func run_editor_category(app: Node, value: String) -> void:
	app._stash_pending_tool()
	app.canvas.cancel_gesture()
	app._restore_pending_tool(value)
	app.canvas.selected_piece = -1
	app.canvas.selected_object = -1
	app.canvas.selected = -1
	app.editor_geometry = ""
	app.editor_tools_panel.hide()
	app.editor_map_panel.hide()
	app._build_editor_tools()
	app.canvas.queue_redraw()

func run_context_button(app: Node, label: String, glyph: String, action: Callable, chosen: bool = false) -> Button:
	var button: Button = EditorButton.make(label,glyph,action,chosen)
	EditorStyle.card(button,chosen)
	app.editor_context.add_child(button)
	return button

func run_build_editor_tools(app: Node) -> void:
	var active_hint: String = app.editor_status.text if app.editor_hint_active and is_instance_valid(app.editor_status) else ""
	if not is_instance_valid(app.editor_context) or not is_instance_valid(app.canvas): return
	app._update_test_access()
	app._update_editor_save_state()
	app.canvas.road_action = app.editor_geometry if app.editor_geometry != "" else "move"
	for child: Node in app.editor_context.get_children():
		app.editor_context.remove_child(child)
		child.queue_free()
	for child: Node in app.editor_inspector.get_children():
		app.editor_inspector.remove_child(child)
		child.queue_free()
	var category: String = "objects" if app.canvas.mode in ["objects","place","run"]  else "paint" if app.canvas.mode in ["paint","pan"] else "road"
	if app.canvas.mode == "place" and app.canvas.stamp_kind in ["puddle","water","dirt"]: category="paint"
	var biome: String = str(app.document.get("biome",app.document.theme))
	if app.object_browser.biome!=biome:
		app.object_browser.biome=biome
		app.object_browser.refresh()
	var browsing: bool = category=="objects" and not (app.canvas.selected_object>=0 and app.canvas.mode=="objects")
	app.object_browser.visible = browsing
	app.object_browser.set_stamp_rotation(app.canvas.stamp_rotation)
	app.editor_palette.visible = not browsing
	for key: String in app.editor_mode_buttons: (app.editor_mode_buttons[key] as Button).set_pressed_no_signal(key == category)
	app.surface_toolbar.visible = category == "paint"
	if category == "paint":
		if app.canvas.brush_surface == 0: app.canvas.brush_surface = 2
		app._build_surface_toolbar()
	if category == "road":
		var piece: Dictionary = app.canvas.ghost if not app.canvas.ghost.is_empty() else app.document.pieces[app.canvas.selected_piece] if app.canvas.selected_piece >= 0 else {}
		if piece.is_empty():
			var start_action: Button = app._context_button("Start line","race",app.canvas.choose_start_line)
			start_action.disabled = app.document.pieces.is_empty() and app.document.layout.is_empty() and app.document.base_track == "" and app.document.paint.is_empty()
			for kind: String in RoadPieces.KINDS:
				app._context_button(preload("res://editor/road_piece_catalog.gd").title(kind),kind,app.canvas.choose_piece.bind(kind))
			app.editor_status.text = "Choose Straight or Curve to begin. Two fingers move the view." if app.document.pieces.is_empty() else "Choose another section, or place the start line."
		elif app.editor_geometry != "" and piece.kind == "bridge":
			app._context_button("Back","back",func() -> void:
				app.editor_geometry = ""
				app._build_editor_tools())
			var key: String = "radius" if piece.kind == "s_bend" and app.editor_geometry == "length" else app.editor_geometry
			app._context_button("- 5 deg" if key == "angle" else "- 1 m","minus",app._change_piece.bind(key,-5.0 if key == "angle" else -1.0))
			app._context_button(("Straight length" if key == "length" and piece.kind == "hairpin" else "Lead-in" if key == "length" and piece.kind not in ["straight","bridge"] else key.capitalize())+(" %.0f deg" if key == "angle" else " %.1f m") % (RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0))),"width",func() -> void: pass)
			app._context_button("+ 5 deg" if key == "angle" else "+ 1 m","plus",app._change_piece.bind(key,5.0 if key == "angle" else 1.0))
			if key != "width" and piece.kind == "hairpin": app._context_button("Radius" if key == "length" else "Straight length" if piece.kind == "hairpin" else "Lead-in","curve",func() -> void:
				app.editor_geometry = "radius" if key == "length" else "length"
				app._build_editor_tools())
			if piece.kind == "s_bend" and key != "height": app._context_button("Height","width",func() -> void:
				app.editor_geometry = "height"
				app._build_editor_tools())
			if piece.kind == "curve" and key != "angle": app._context_button("Angle","curve",func() -> void:
				app.editor_geometry = "angle"
				app._build_editor_tools())
			app.editor_status.text = "Both straight arms change equally; 0 m makes a plain U-turn. Radius stays separate." if piece.kind == "hairpin" and key == "length" else "Only this section changes. Reconnect any open ends afterwards."
		else:
			if piece.kind == "spline":
				app._context_button(GameText.message("Point %d/5") % (app.canvas.spline_point+1),"spline",func() -> void:
					app.canvas.spline_point = (app.canvas.spline_point+1)%5
					app._build_editor_tools())
				app._context_button("Width −","minus",app._change_piece.bind("point_width",-0.5))
				app._context_button(GameText.message("%.1f m") % float(piece.point_widths[app.canvas.spline_point]),"width",func() -> void: pass)
				app._context_button("Width +","plus",app._change_piece.bind("point_width",0.5))
			if piece.kind == "bridge":
				app._context_button("Shape",piece.kind,func() -> void:
					app.editor_geometry = "length" if piece.kind in ["straight","bridge"] else "radius"
					app._build_editor_tools())
				if piece.kind == "hairpin": app._context_button("Straight length","straight",func() -> void:
					app.editor_geometry = "length"
					app._build_editor_tools())
				app._context_button("Width","width",func() -> void:
					app.editor_geometry = "width"
					app._build_editor_tools())
				app._context_button("Rotate","rotate",app._change_piece.bind("heading",15.0))
			app._context_button("Flip","flip",app._change_piece.bind("flip",1.0))
			if app.document.theme in ["pine","storm"]:
				for surface: String in ["asphalt","gravel"]:
					var material_button: Button = app._context_button(surface.capitalize(),"terrain_road" if surface == "asphalt" else "terrain_dirt",app._set_piece_material.bind(surface),RoadPieces.material(piece,app.document) == surface)
					material_button.name = "RoadMaterial_"+surface
					material_button.tooltip_text = "Road material for this section"
			app._context_button("Snap on" if app.canvas.snap_enabled else "Snap off","snap",func() -> void:
				app.canvas.snap_enabled = not app.canvas.snap_enabled
				app.canvas.snap_matched = false
				app._build_editor_tools(),app.canvas.snap_enabled)
			app._context_button("Cancel" if not app.canvas.ghost.is_empty() else "Delete","delete",app._delete_piece)
			if app.canvas.ghost.is_empty():
				app._context_button("Connect","snap",app.canvas.connect_nearby)
				app._context_button("Layer","surface",app.canvas.cycle_piece)
			app.editor_status.text = "Drag inside to move · end dots resize and turn · ✓ to place" if not app.canvas.ghost.is_empty() else "Drag inside to move · drag end dots to reshape · Layer selects overlapping roads"
			if piece.kind == "bridge": app.editor_status.text = "Bridge: ramps at both ends · ground road passes beneath the middle"
			if piece.kind == "spline": app.editor_status.text = "Drag the five numbered points · select a point to set its width · ✓ to place"
	elif category == "paint":
		for pair: Array in [[1,"Grass"],[2,"Sand"],[3,"Water"]]:
			var surface_button: Button = app._context_button(preload("res://editor/surface_labels.gd").title(pair[0],biome),preload("res://editor/surface_labels.gd").glyph(pair[0],biome),func() -> void:
				app.canvas.brush_surface = pair[0]
				app.canvas.mode = "paint"
				app._build_editor_tools(),app.canvas.mode == "paint" and app.canvas.brush_surface == pair[0])
			(surface_button as EditorButton).surface_tint = TrackTheme.palette(biome)[pair[0]]
		app._context_button("Puddle","terrain_puddle",app._choose_hazard.bind("puddle"))
		app._build_paint_tools()
		app.editor_status.text = "Drag to paint freely" if app.canvas.paint_mode == "free" else "Tap to add points / drag dots to reshape / confirm to place"
	elif category == "objects":
		if app.canvas.selected_object >= 0 and app.canvas.mode == "objects":
			app.editor_status.text=CreatorObjects.description(app.document.objects[app.canvas.selected_object].kind)
			if app.canvas.object_indices().size() > 1:
				app.editor_status.text = GameText.message("%d objects selected ? drag one to move the group") % app.canvas.object_indices().size()
			if app.canvas.multi_select and app.canvas.object_indices().size() == 1: app.editor_status.text = "Multi-select: tap to add or remove; drag to move."
			app._context_button("Copy","copy",app._duplicate_object)
			var multiple: Button = app._context_button("Multi-select","multi_select",app.canvas.toggle_multi_select,app.canvas.multi_select)
			multiple.name = "MultiSelectObjects"
			app._context_button("Next object","cycle_objects",app.canvas.cycle_objects)
			app._context_button("Delete","delete",app._delete_selection)
			if app.canvas.issue_marker != Vector2.INF: app._context_button("Move start","race",app.canvas.choose_start_line)
			app._context_button("Palette","more",func() -> void:
				app.canvas.multi_select = false
				app.canvas.selected_object = -1
				app._build_editor_tools())
		else:
			var stamp_label: String = CreatorCatalog.label(CreatorCatalog.jump_asset(app.canvas.stamp_jump_profile,str(app.document.theme))) if app.canvas.stamp_kind == "jump" else CreatorCatalog.label(app.canvas.stamp_kind)
			app.editor_status.text = stamp_label+" / "+("Drag a curve; release to place" if app.canvas.run_shape=="curve" else "Drag a line, or tap its two ends" if app.canvas.mode=="run" else "Tap empty ground to place / tap an object to edit")
			if app.canvas.mode=="objects": app.editor_status.text="Tap an object to move, rotate or delete"
	app._build_object_controls(category == "objects",browsing)
	app.editor_guidance = app.editor_status.text
	if app.editor_hint_active: app.editor_status.text = active_hint
	if app.editor_save_error == OK and not app.editor_hint_active: app.editor_status.hide()
	app._layout_editor_feedback()

	var context_width: float = 0
	for child: Control in app.editor_context.get_children(): context_width += child.get_combined_minimum_size().x+6
	(app.editor_context.get_parent() as ScrollContainer).custom_minimum_size.x = clampf(context_width,320,maxf(320,app.canvas.size.x-260))
	app._update_editor_save_state()
	app.canvas.refresh()

func run_set_piece_material(app: Node, surface: String) -> void:
	if not is_instance_valid(app.canvas) or app.document.theme not in ["pine","storm"] or surface not in ["asphalt","gravel"]: return
	var is_ghost: bool = not app.canvas.ghost.is_empty()
	if not is_ghost and (app.canvas.selected_piece < 0 or app.canvas.selected_piece >= app.document.pieces.size()): return
	var piece: Dictionary = (app.canvas.ghost if is_ghost else app.document.pieces[app.canvas.selected_piece]).duplicate(true)
	if RoadPieces.material(piece,app.document) == surface:
		app._build_editor_tools()
		return
	piece.surface = surface
	if is_ghost: app.canvas.ghost = piece
	else:
		app._remember()
		app.document.pieces[app.canvas.selected_piece] = piece
		app._save_draft(true)
	app._build_editor_tools()

func run_change_piece(app: Node, key: String, delta: float) -> void:
	var is_ghost: bool = not app.canvas.ghost.is_empty()
	if not is_ghost and app.canvas.selected_piece < 0: return
	var piece: Dictionary = (app.canvas.ghost if is_ghost else app.document.pieces[app.canvas.selected_piece]).duplicate(true)
	var before: Dictionary = piece.duplicate(true)
	if piece.kind == "s_bend" and key == "length": return
	if key == "point_width" and piece.kind == "spline": piece = SplineRoad.with_width(piece,app.canvas.spline_point,float(piece.point_widths[app.canvas.spline_point])+delta)
	elif key == "flip": piece.flip = not piece.flip
	elif key == "heading": piece.heading = fposmod(float(piece.heading)+delta,360.0)
	else:
		var lower: float = 5.0 if key == "angle" else 6.0 if key == "width" else 2.0 if key == "height" else 3.0 if key == "radius" else 24.0 if piece.kind == "bridge" else 2.0 if piece.kind == "straight" else 0.0
		var upper: float = 270.0 if key == "angle" else 20.0 if key == "width" else 60.0 if key in ["radius","height"] else 120.0
		piece[key] = clampf((RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0)))+delta,lower,upper)
	piece = app.canvas.anchored_change(before,piece,key)
	var errors: Array[String] = RoadPieces.validate(piece)
	if not errors.is_empty():
		app._editor_hint(errors[0])
		return
	if not app.canvas._valid_bridge_edit(piece,app.canvas.selected_piece): return
	if is_ghost:
		app.canvas.ghost = piece
		app.canvas.snap_matched = false
	else:
		var proposed: Array = app.document.pieces.duplicate()
		proposed[app.canvas.selected_piece] = piece
		if not app.canvas.admit("pieces",proposed): return
		app._remember()
		app.document.pieces[app.canvas.selected_piece] = piece
		app._save_draft(true)
	app._build_editor_tools()

func run_delete_piece(app: Node) -> void:
	if not app.canvas.ghost.is_empty(): app.canvas.ghost.clear()
	elif app.canvas.selected_piece >= 0:
		app._remember()
		app.document.pieces.remove_at(app.canvas.selected_piece)
		app.canvas.selected_piece = -1
		app._save_draft(true)
	app.editor_geometry = ""
	app._build_editor_tools()

func run_practice_start(app: Node, track: NativeTrack) -> Vector2:
	if app.document.has("start_line"): return Vector2(app.document.start_line.position[0],app.document.start_line.position[1])
	if app.document.has("practice_start"): return Vector2(app.document.practice_start.position[0],app.document.practice_start.position[1])
	if app.document.pieces.is_empty(): return track.spawn
	var samples: PackedVector2Array = RoadPieces.samples(app.document.pieces[0])
	return samples[mini(6,samples.size()-1)]

func run_practice_heading(app: Node, track: NativeTrack) -> float:
	if app.document.has("start_line"): return PI*0.5-deg_to_rad(float(app.document.start_line.heading))
	if app.document.has("practice_start"): return PI*0.5-deg_to_rad(float(app.document.practice_start.heading))
	if app.document.pieces.is_empty(): return track.spawn_heading
	var samples: PackedVector2Array = RoadPieces.samples(app.document.pieces[0])
	var index: int = mini(6,samples.size()-1)
	var tangent: Vector2 = samples[mini(index+1,samples.size()-1)]-samples[maxi(0,index-1)]
	return atan2(tangent.x,tangent.y)

func run_update_editor_issues(app: Node) -> void:
	if not is_instance_valid(app.canvas) or not is_instance_valid(app.editor_issue_button): return
	var previous: Dictionary = app.editor_issues[app.editor_issue_cursor] if app.editor_issue_cursor >= 0 and app.editor_issue_cursor < app.editor_issues.size() else {}
	app.editor_issues.clear()
	app.canvas.issue_marker = Vector2.INF
	var track: NativeTrack = app.canvas.native_preview
	if track != null:
		var start: Vector2 = app._practice_start(track)
		var config: HandlingConfig = HandlingSelection.config()
		var radius: float = config.collision_radius
		var elevated: bool = track.collision_elevated_at(start,track.nearest_route(start),radius)
		if track.overlaps_obstacle(start,radius,elevated):
			for i: int in range(app.document.objects.size()):
				var object: Dictionary = app.document.objects[i]
				if CreatorObjects.surface(object.kind) not in [3,4]: continue
				var local: Vector2 = (start-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
				var half: Vector2 = CreatorObjects.size_of(object)*0.5
				if local.distance_to(local.clamp(-half,half)) <= radius+track.cell_size*0.71:
					app.editor_issues.append({"message":GameText.message("%s blocks the start") % str(object.kind).capitalize(),"position":start,"object":i})
			if app.editor_issues.is_empty(): app.editor_issues.append({"message":"Obstacle overlaps the starting car","position":start,"object":-2})
	for join: Dictionary in RoadPieces.joins(app.document.pieces):
		app.editor_issues.append({"message":join.message,"position":join.position,"object":-1,"index":join.index,"endpoint":join.endpoint})
	app.editor_issue_cursor = app.editor_issues.find(previous)
	app.editor_issue_button.text = GameText.message("Issue %d/%d") % [app.editor_issue_cursor+1,app.editor_issues.size()] if app.editor_issue_cursor >= 0 else GameText.plural("{count} issue","{count} issues",app.editor_issues.size())
	app.editor_issue_button.tooltip_text = "Tap to focus the next issue."
	app.editor_issue_button.visible = not app.editor_issues.is_empty()
	app._update_test_access()
	app.canvas.queue_redraw()

func run_update_test_access(app: Node) -> void:
	if not is_instance_valid(app.test_button) or not is_instance_valid(app.canvas): return
	var has_road: bool = not app.document.pieces.is_empty() or not app.document.layout.is_empty() or not app.document.paint.is_empty() or app.document.base_track != ""
	app.test_button.disabled = app.editor_commits.unsettled() or app.editor_preview_thread != null or not (app.editor_validation_errors if app.document == app.editor_validation_document else TrackDocument.validate(app.document)).is_empty() or not has_road or app._has_pending_editor_work()
	for issue: Dictionary in app.editor_issues:
		if int(issue.object) != -1: app.test_button.disabled = true

func run_focus_issue(app: Node) -> void:
	if app.editor_issues.is_empty(): return
	if app._has_pending_editor_work():
		app._resolve_editor_previews(app._focus_issue)
		return
	app.editor_issue_cursor = (app.editor_issue_cursor+1)%app.editor_issues.size()
	var issue: Dictionary = app.editor_issues[app.editor_issue_cursor]
	app._editor_category("objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road")
	app.canvas.mode = "objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road"
	app.canvas.issue_marker = issue.position
	app.canvas.issue_text = issue.message
	app.canvas.pan += app.canvas.size*0.5-app.canvas.to_screen(issue.position)
	if int(issue.object) >= 0: app.canvas.selected_object = issue.object
	elif int(issue.object) == -1: app.canvas.selected_piece = issue.index
	app._build_editor_tools()
	app.editor_issue_button.text = GameText.message("Issue %d/%d") % [app.editor_issue_cursor+1,app.editor_issues.size()]
	app._editor_hint(issue.message+" · paint Road over the obstacle, or place a Start line." if int(issue.object) == -2 else issue.message+" · drag to repair, or delete the selection.")
	app.canvas.refresh()

func run_commit_selection(app: Node) -> void:
	var error: String = preload("res://editor/authoring_admission.gd").error(app.document)
	if not error.is_empty():
		if not app.history.is_empty():
			app.document = preload("res://editor/editor_history.gd").restore(app.history.pop_back())
			app._restore_editor_history()
		app._editor_hint(error)
		return
	if app.canvas.mode in ["move","add"]: app.document.route_override = true
	app.canvas.refresh()
	app._save_draft(true)
	app._build_editor_tools()

func run_delete_selection(app: Node) -> void:
	if app.canvas.mode in ["objects","place","run"]:
		if app.canvas.selected_object < 0: return
		app._remember()
		var indices: Array[int] = app.canvas.object_indices()
		indices.reverse()
		for index: int in indices: app.document.objects.remove_at(index)
		app.canvas.selected_object = -1
	else: return
	app._commit_selection()

func run_rotate_object(app: Node) -> void:
	app._set_object_rotation(preload("res://editor/object_rotation.gd").next_angle(app._object_rotation()))

func run_selected_object_properties(app: Node) -> void:
	app._object_property_editing("")

func run_object_property_editing(app: Node, property: String) -> void:
	app.editor_object_property = property
	app._build_editor_tools()

func run_build_object_controls(app: Node, active: bool, browsing: bool) -> void:
	if not is_instance_valid(app.object_controls): return
	app.object_controls_panel.visible = active
	app.object_controls.visible = active
	if not active: return
	var selected: bool = app.canvas.mode == "objects" and app.canvas.selected_object >= 0 and app.canvas.selected_object < app.document.objects.size()
	var state: Dictionary = app.document.objects[app.canvas.selected_object].duplicate(true) if selected else {"kind":app.canvas.stamp_kind,"scale":app.canvas.stamp_scale,"rotation":app.canvas.stamp_rotation,"span":app.canvas.stamp_span,"placement":app.object_browser.placement,"color":app.canvas.stamp_container_color}
	state["multiple"] = selected and app.canvas.object_indices().size() > 1
	if selected: state["span"] = CreatorObjects.size_of(state).y
	if state.kind == "jump": state["jump_profile"] = JumpProfiles.id(state) if selected else app.canvas.stamp_jump_profile
	var target: String = str(app.document.id)+"/"+str(app.canvas.selected_object if selected else -1)+"/"+str(state.kind)+"/"+str(state.multiple)
	if target != app._object_controls_target:
		app.editor_object_property = ""
		app._object_controls_target = target
	app.object_controls_panel.offset_bottom = app.object_browser.offset_top-8 if browsing else -104
	app.object_controls_panel.offset_top = app.object_controls_panel.offset_bottom-84
	app.object_controls.show_state(state,selected,app.editor_object_property)
	var controls_width: float = minf(maxf(196,app.object_controls.get_combined_minimum_size().x+16),maxf(196,app.canvas.size.x-220))
	app.object_controls_panel.anchor_left = 0.5
	app.object_controls_panel.anchor_right = 0.5
	app.object_controls_panel.offset_left = -controls_width*0.5
	app.object_controls_panel.offset_right = controls_width*0.5
	app.object_browser.rotation_button = app.object_controls.find_child("ObjectOrientation",true,false) as Button
	if app.editor_object_property == "scale": app.editor_status.text = GameText.message("Size")+" / "+app.object_controls._dimensions()
	elif app.editor_object_property == "rotation": app.editor_status.text = "Use - / + or type an angle. Back returns to object controls."
	elif app.editor_object_property == "span": app.editor_status.text = "Set the width here, or drag the speed bump end dots."

func run_edit_object_control(app: Node, property: String, value: Variant) -> void:
	if not is_instance_valid(app.canvas) or app.screen != "create" or app.canvas.mode not in ["objects","place","run"]: return
	var selected: bool = app.canvas.mode == "objects" and app.canvas.selected_object >= 0
	match property:
		"kind": app.object_browser.choose(str(value)); return
		"placement": app._object_placement(str(value)); return
		"rotation": app._set_object_rotation(float(value)); return
		"scale":
			if selected: app._scale_object(float(value)-float(app.document.objects[app.canvas.selected_object].get("scale",1.0))); return
			app.canvas.stamp_scale = float(value)
			app.object_browser.stamp_scale = float(value)
		"span":
			if selected: app._resize_speed_bump(float(value)-CreatorObjects.size_of(app.document.objects[app.canvas.selected_object]).y); return
			app.canvas.stamp_span = float(value)
			app.object_browser.stamp_span = float(value)
		"color": app._container_colour(str(value)); return
	app._build_editor_tools()

func run_object_rotation(app: Node) -> float:
	return float(app.document.objects[app.canvas.selected_object].rotation) if app.canvas.selected_object >= 0 else app.canvas.stamp_rotation

func run_set_object_rotation(app: Node, value: float) -> void:
	if not is_finite(value): return
	var angle: float = fposmod(value,360.0)
	app.canvas.stamp_rotation = angle
	if app.canvas.selected_object >= 0 and not is_equal_approx(float(app.document.objects[app.canvas.selected_object].rotation),angle):
		var proposed: Array = preload("res://editor/object_editing.gd").rotated(app.document.objects,app.canvas.object_indices(),angle-float(app.document.objects[app.canvas.selected_object].rotation))
		if proposed.is_empty(): app._editor_hint("Keep the whole selection inside the map."); return
		if not app.canvas.admit("objects",proposed): return
		app._remember()
		app.document.objects = proposed
		app._commit_selection()
	else: app._build_editor_tools()
	app.object_browser.set_stamp_rotation(angle)

func run_object_rotation_dialog(app: Node) -> void:
	if app.root_ui.find_child("ObjectRotationDialog",true,false) != null: return
	if is_instance_valid(app.object_browser.options): app.object_browser.options.hide()
	app.canvas.cancel_gesture()
	var dialog = preload("res://editor/object_rotation.gd").new()
	dialog.angle = app._object_rotation()
	var owner_canvas: EditorCanvas = app.canvas
	var source: Dictionary = app.document
	var selection: int = app.canvas.selected_object
	var kind: String = app.canvas.stamp_kind
	dialog.confirmed.connect(func() -> void:
		if not is_instance_valid(owner_canvas) or app.canvas != owner_canvas or app.screen != "create": return
		if not is_same(app.document,source) or app.canvas.selected_object != selection or app.canvas.stamp_kind != kind: return
		if dialog.free_rotation: dialog.field.apply()
		app._set_object_rotation(dialog.angle))
	app._own_dialog(dialog)
	dialog.popup_centered_clamped(Vector2i(410,360))

func run_scale_object(app: Node, delta: float) -> void:
	if app.canvas.selected_object < 0: return
	if app.document.objects[app.canvas.selected_object].kind == "speed_bump":
		app._resize_speed_bump(delta*4.0)
		return
	app._remember()
	var object: Dictionary = app.document.objects[app.canvas.selected_object]
	object.scale = clampf(float(object.get("scale",1.0))+delta,0.5,1.5 if object.kind in CreatorCatalog.DECORATIVE else 3.0)
	app._commit_selection()


func run_resize_speed_bump(app: Node, delta: float) -> void:
	if app.canvas.selected_object < 0: return
	var object: Dictionary = app.document.objects[app.canvas.selected_object]
	if object.kind != "speed_bump": return
	var span: float = clampf(CreatorObjects.size_of(object).y+delta,SpeedBumpEdit.MIN_SPAN,SpeedBumpEdit.MAX_SPAN)
	if is_equal_approx(span,CreatorObjects.size_of(object).y): return
	app._remember()
	object["span"] = span
	app.document.objects[app.canvas.selected_object] = SpeedBumpEdit.serialize_ready(object)
	app._commit_selection()


func run_fit_speed_bump(app: Node) -> void:
	if app.canvas.selected_object < 0: return
	var object: Dictionary = app.document.objects[app.canvas.selected_object]
	if object.kind != "speed_bump": return
	var fitted: Dictionary = SpeedBumpEdit.fit_road(app.document,object,app.canvas.native_preview)
	if fitted.is_empty():
		app._editor_hint("Place the speed bump on a ground road first.")
		return
	if fitted == object: return
	app._remember()
	app.document.objects[app.canvas.selected_object] = fitted
	app._commit_selection()


func run_duplicate_object(app: Node) -> void:
	if app.canvas.selected_object < 0: return
	if app.document.objects.size() >= preload("res://editor/creator_limits.gd").MAX_OBJECTS:
		app._editor_hint("Remove an object before adding more."); return
	var indices: Array[int] = app.canvas.object_indices()
	var moved: Array = preload("res://editor/object_editing.gd").moved(app.document.objects,indices,Vector2(4,4))
	var additions: Array = []
	for index: int in indices: additions.append(moved[index])
	var admission: String = preload("res://editor/creator_limits.gd").addition_error(app.document.objects,additions,str(app.document.theme))
	if not admission.is_empty(): app._editor_hint(admission); return
	if not app.canvas.admit("objects",app.document.objects+additions): return
	app._remember()
	var first: int = app.document.objects.size()
	app.document.objects.append_array(additions)
	app.canvas.multi_select = additions.size() > 1 or app.canvas.multi_select
	app.canvas.selected_objects.clear()
	for index: int in range(first,app.document.objects.size()): app.canvas.selected_objects.append(index)
	app.canvas.selected_object = app.document.objects.size()-1
	app.canvas.mode = "objects"
	app._commit_selection()

func run_remember(app: Node) -> void:
	app.editor_session.remember(app.document)

func run_set_document_value(app: Node, key: String, value: Variant) -> void:
	if key in ["theme", "biome", "creator"]: return
	if not app.canvas.admit(key,value): return
	app._remember()
	app.document[key] = value
	app._save_draft(true)
	app._show_screen("create")

func run_undo(app: Node) -> void:
	if app.history.is_empty(): return
	app.document = app.editor_session.restore(app.document,true)
	app._restore_editor_history()

func run_redo(app: Node) -> void:
	if app.redo_history.is_empty(): return
	app.document = app.editor_session.restore(app.document,false)
	app._restore_editor_history()

func run_restore_editor_history(app: Node) -> void:
	# Keep the viewport, camera and controls alive; stale worker results are
	# discarded by _process, without waiting for them in the input handler.
	app.canvas.changed_in_gesture = false
	app.canvas.cancel_gesture()
	app.canvas.ghost.clear()
	app.canvas.selected_piece = -1
	app.canvas.selected_object = -1
	app.canvas.document = app.document
	app.canvas.road_approval_pending = false
	var title: Label = app.root_ui.find_child("TrackName",true,false) as Label
	if title != null: title.text = str(app.document.name)
	app.canvas.refresh()
	app._save_draft(true)
	app._build_editor_tools()

func run_refresh_editor(app: Node) -> void:
	if not is_instance_valid(app.editor_status): return
	var errors: Array[String] = TrackDocument.validate(app.document)
	app.editor_status.text = app.editor_guidance if errors.is_empty() else errors[0]
	app.test_button.disabled = not errors.is_empty()
	app.publish_button.disabled = not errors.is_empty() or app.lifecycle == null or not app.lifecycle.ready_to_publish(app.document)
	app.share_button.disabled = not errors.is_empty()
	if is_instance_valid(app.canvas): app.canvas.refresh()

func run_editor_copy_is_current(app: Node, snapshot: Dictionary, storage: TrackLibrary, relative_path: String, disk_hash: String) -> bool:
	if storage != app.library or app.document != snapshot or disk_hash.is_empty(): return false
	var path: String = app.library.directory.path_join(relative_path)
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path) == disk_hash

func run_apply_editor_writes(app: Node) -> void:
	for receipt: Dictionary in app.editor_writes.completed:
		var storage: TrackLibrary = receipt.storage
		if receipt.error == OK: storage.revision += 1
		if storage != app.library: continue
		if receipt.document != app.document:
			if receipt.error != OK and str(receipt.document.get("id","")) == str(app.document.get("id","")):
				app.editor_save_error = receipt.error; app.editor_save_message = "Could not save: "+str(receipt.message)
				if not app._editor_exiting and app.is_inside_tree(): app._editor_hint(app.editor_save_message); app._update_editor_save_state()
			continue
		app.library.last_error = receipt.message
		if receipt.error != OK or not app.editor_retry_original:
			app.editor_save_error = receipt.error
			app.editor_save_message = "Could not save: "+str(receipt.message) if receipt.error != OK else ""
		if receipt.error == OK:
			app.editor_wip_snapshot = receipt.document.duplicate(true); app.editor_wip_store = storage; app.editor_wip_disk_hash = receipt.digest
			app.editor_wip_saved = TrackLibrary.draft_fingerprint(receipt.document)
			if is_instance_valid(app.editor_status) and app.editor_status.text == "Saving...": app.editor_status.text = app.editor_guidance
		elif not app._editor_exiting and app.is_inside_tree(): app._editor_hint(app.editor_save_message)
		if not app._editor_exiting and app.is_inside_tree(): app._update_editor_save_state()
	app.editor_writes.completed.clear()

func run_apply_editor_commits(app: Node) -> void:
	for receipt: Dictionary in app.editor_commits.completed:
		# A newer in-progress gesture must not discard the preceding committed
		# revision's recovery write. Analysis and writes both preserve order.
		if not receipt.has("error"): app.editor_writes.enqueue(receipt.storage,receipt.document)
		if not app.editor_session.accept(receipt,app.library,app.document): continue
		if receipt.has("error"):
			app.editor_save_error = receipt.error; app.editor_save_message = "Could not prepare the draft for saving. Use Save to retry."
			if not app._editor_exiting and app.is_inside_tree(): app._editor_hint(app.editor_save_message)
			continue
		# Preserve the bound dictionary, selection and session identity.
		for key: String in ["points","widths","corners","route_override"]:
			app.document[key] = receipt.document[key]
		if not app.editor_retry_original: app.editor_save_error = OK; app.editor_save_message = ""
		if not app._editor_exiting and app.is_inside_tree() and is_instance_valid(app.canvas) and app.canvas.is_inside_tree() and app.canvas.document == app.document:
			app.canvas.refresh()
			if app.canvas.native_preview != null and app.canvas.native_preview.metadata.get("creator_document",{}) == app.document:
				app._update_editor_issues()
			else:
				if app._objects_only_edit(): app.editor_world.preview_objects(app.document)
				app._queue_editor_preview()
			if is_instance_valid(app.editor_undo): app.editor_undo.disabled = app.history.is_empty()
			if is_instance_valid(app.editor_redo): app.editor_redo.disabled = app.redo_history.is_empty()
			app.publish_button.disabled = not app.editor_validation_errors.is_empty() or app.lifecycle == null or app.lifecycle.no_publishing_slots() or not bool(app.editor_workflow_presentation.get("ready",false))
			app.share_button.disabled = not app.editor_validation_errors.is_empty()
		if not app._editor_exiting and app.is_inside_tree(): app._update_editor_save_state()
	app.editor_commits.completed.clear()

func run_flush_editor_writes(app: Node) -> void:
	app.editor_commits.flush(); app._apply_editor_commits()
	app.editor_writes.flush(); app._apply_editor_writes()

func run_save_draft(app: Node, background_preview: bool = false) -> Error:
	var deferred_write: bool = background_preview and is_instance_valid(app.canvas) and app.library.get_script() == preload("res://persistence/track_library.gd")
	if deferred_write:
		if app.document.is_empty(): return ERR_INVALID_DATA
		app._stamp_creator()
		app.editor_session.enqueue(app.library,app.document,app.lifecycle._root() if app.lifecycle != null else "")
		app.editor_commits.poll()
		app.test_button.disabled = true; app.publish_button.disabled = true; app.share_button.disabled = true
		if is_instance_valid(app.editor_status): app.editor_status.text = "Saving..."
		app._update_editor_save_state()
		return OK
	if not deferred_write: app._flush_editor_writes()
	if not background_preview: app._finish_preview_thread()
	if app.document.is_empty(): return ERR_INVALID_DATA
	app._stamp_creator()
	if not app.document.pieces.is_empty():
		if app.document.pieces != app.editor_route_pieces or app.editor_route_fields.is_empty():
			var auto_route: Dictionary = RoadPieces.route_from_pieces(app.document)
			if auto_route.ok:
				app.editor_route_pieces = app.document.pieces.duplicate(true)
				app.editor_route_fields.clear()
				for key: String in ["points","widths","corners","route_override"]: app.editor_route_fields[key] = auto_route.document[key]
		if app.document.pieces == app.editor_route_pieces:
			for key: String in app.editor_route_fields: app.document[key] = app.editor_route_fields[key].duplicate(true) if app.editor_route_fields[key] is Array else app.editor_route_fields[key]
	var errors: Array[String] = TrackDocument.validate(app.document)
	var message: String
	# A successful immutable snapshot belongs to this exact local library.
	# Missing primaries and failed writes still take the real recovery path.
	# A durable match can still be overwritten by an older in-flight revision.
	# Queue this final state after it; enqueue coalesces only unstarted writes.
	var wip_current: bool = not app.editor_writes.unsettled(app.library,str(app.document.id)) and (app.editor_save_error == OK or app.editor_retry_original) and app._editor_copy_is_current(app.editor_wip_snapshot,app.editor_wip_store,"wip/"+str(app.document.id)+".json",app.editor_wip_disk_hash) and not app.library.is_published(str(app.document.id))
	var save_error: Error = OK if wip_current else app.editor_writes.enqueue(app.library,app.document) if deferred_write else app.library.save_wip(app.document)
	if wip_current: app.library.last_error = ""
	if save_error != OK or not app.editor_retry_original:
		app.editor_save_error = save_error
		app.editor_save_message = "Could not save: "+app.library.last_error if save_error != OK else ""
	if save_error == OK and not wip_current and not deferred_write:
		app.editor_wip_saved = TrackLibrary.draft_fingerprint(app.document)
		app.editor_wip_snapshot = app.document.duplicate(true)
		app.editor_wip_store = app.library
		app.editor_wip_disk_hash = FileAccess.get_sha256(app.library.directory.path_join("wip/"+str(app.document.id)+".json"))
	if save_error != OK: message = "Could not save: " + app.library.last_error
	elif deferred_write and not wip_current: message = "Saving..."
	elif not errors.is_empty(): message = "Draft saved. Before driving: " + errors[0]
	else: message = "WIP autosaved. Saved original unchanged."
	if is_instance_valid(app.editor_status):
		app.editor_status.text = message
		app.test_button.disabled = not errors.is_empty()
		app.publish_button.disabled = not errors.is_empty() or app.lifecycle == null or not app.lifecycle.ready_to_publish(app.document)
		app.share_button.disabled = not errors.is_empty()
	app._update_editor_save_state()
	if save_error != OK: app._editor_hint(app.editor_save_message)
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(app.canvas):
		if is_instance_valid(app.editor_undo): app.editor_undo.disabled = app.history.is_empty()
		if is_instance_valid(app.editor_redo): app.editor_redo.disabled = app.redo_history.is_empty()
		if background_preview:
			app.canvas.queue_redraw()
			if app.canvas.native_preview != null and app.canvas.native_preview.metadata.get("creator_document",{}) == app.document:
				app._update_editor_issues()
			else:
				if app._objects_only_edit(): app.editor_world.preview_objects(app.document)
				app.test_button.disabled = true
				app._queue_editor_preview()
		else:
			var preview_track: NativeTrack = app.canvas.native_preview if TrackLifecycle.prepared_test_matches(app.document,app.canvas.native_preview) else app._editor_track_preview()
			if preview_track != null and preview_track != app.canvas.native_preview: app.canvas.show_native(preview_track)
			app._update_editor_issues()
	return save_error

func run_test_document(app: Node) -> void:
	if is_instance_valid(app.canvas) and app.canvas.active_pointer != -99:
		app._editor_hint("Release the track before testing.")
		return
	if app._has_pending_editor_work():
		app._notice("Confirm or cancel the pending previews before testing.")
		return
	if not app.canvas.paint_points.is_empty():
		app._notice("Confirm or cancel the surface preview first.")
		return
	if not app.canvas.ghost.is_empty():
		app.editor_status.text = "Confirm or cancel the preview before testing."
		return
	if app._save_draft() != OK: return
	var prepared: NativeTrack = app.canvas.native_preview
	if not await app._prepare_creator_test(app.document,prepared): return
	# Practice owns its mutable spawn/contact helpers. The editor's exact
	# compiled snapshot remains available for the next edit and test cycle.
	var track: NativeTrack = preload("res://editor/prepared_track_cache.gd").copy_track(prepared) if prepared != null else null
	if track != null and not app.test_button.disabled:
		track.spawn = app._practice_start(track)
		track.spawn_heading = app._practice_heading(track)
		await app._start_race(track, true)

func run_publish_current_document(app: Node) -> void:
	if app._has_pending_editor_work():
		app._notice("Confirm or cancel the preview before publishing.")
		return
	if app._save_draft() != OK: return
	await app._publish_saved_draft("wip:"+str(app.document.id))

func run_share_dialog(app: Node) -> void:
	if app._has_pending_editor_work():
		app._resolve_editor_previews(app._share_dialog,"Confirm or discard the pending previews before sharing this circuit.")
		return
	if app._save_draft() != OK:
		app._notice("Could not save: "+app.library.last_error)
		return
	var dialog = AcceptDialog.new()
	dialog.title = "Share your circuit"
	dialog.dialog_text = "Copy this circuit and send it to a friend. They can paste it into Import.\nLocal creation and racing shared circuits are free."
	dialog.ok_button_text = "Done"
	dialog.add_button("Copy circuit", false, "copy")
	dialog.add_button("Export file", false, "file")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"copy":
			DisplayServer.clipboard_set(JSON.stringify(app.document))
			dialog.dialog_text = "Circuit copied. Your friend can paste it into Tracks > Import a circuit."
		else: app._export_file())
	app._own_dialog(dialog)
	dialog.popup_centered(Vector2i(650,220))

func run_export_file(app: Node) -> void:
	var dialog = FileDialog.new()
	dialog.title = "Export circuit"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Circuit file"])
	dialog.current_file = str(app.document.id) + ".json"
	dialog.file_selected.connect(func(path: String) -> void:
		if app.library.export_document(app.document, path) == OK: app._notice("Circuit exported.")
		else: app._notice("Export failed: " + app.library.last_error))
	app._own_dialog(dialog)
	dialog.popup_centered_ratio(0.8)

func run_import_dialog(app: Node) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Import a circuit"
	dialog.ok_button_text = "Import"
	var layout = VBoxContainer.new()
	dialog.add_child(layout)
	layout.add_child(MenuStyle.label("Paste a shared circuit below, or choose a circuit file.",18))
	var text = TextEdit.new()
	text.custom_minimum_size = Vector2(620,220)
	text.placeholder_text = "Paste circuit data here"
	layout.add_child(text)
	layout.add_child(MenuStyle.button("Paste from clipboard", func() -> void:
		var copied: String = DisplayServer.clipboard_get()
		if copied.to_utf8_buffer().size() <= TrackDocument.MAX_BYTES: text.text = copied
		else: app._notice("That circuit is too large to import.")))
	layout.add_child(MenuStyle.button("Choose file", func() -> void:
		var picker = FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; Circuit file"])
		picker.file_selected.connect(func(path: String) -> void:
			var imported: Dictionary = app.library.import_document(path)
			if imported.is_empty(): app._notice(app.library.last_error)
			else: app._accept_import(imported))
		app._own_dialog(picker)
		picker.popup_centered_ratio(0.8)))
	dialog.confirmed.connect(func() -> void:
		if text.text.to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
			app._notice("That circuit is too large to import.")
			return
		var parsed: Variant = JSON.parse_string(text.text)
		var errors: Array[String] = TrackDocument.validate(parsed)
		if not errors.is_empty(): app._notice(errors[0])
		else: app._accept_import(parsed))
	app._own_dialog(dialog)
	dialog.popup_centered()

func run_accept_import(app: Node, imported: Dictionary) -> void:
	if not app.document.is_empty() and not TrackDocument.validate(app.document).is_empty():
		app._notice("Fix or undo your unsaved route change before importing another circuit.")
		return
	app._save_draft()
	app.editor_view.clear()
	app.canvas = null
	app.document = imported.duplicate(true)
	# Import as a new local draft: never replace an existing author's work by ID.
	app.document.id = TrackLibrary.unique_id()
	app._stamp_creator()
	app.history.clear()
	app.redo_history.clear()
	app._save_draft()
	app._show_screen("create")

func run_build_paint_tools(app: Node) -> void:
	app.editor_inspector.add_child(EditorStyle.button("Keep road" if app.canvas.protect_road else "Paint all",func() -> void:
		app.canvas.protect_road = not app.canvas.protect_road
		app._build_editor_tools()))
	if app.canvas.paint_mode != "free":
		app.editor_inspector.add_child(MenuStyle.button("Remove last point",func() -> void:
			if not app.canvas.paint_points.is_empty(): app.canvas.paint_points.pop_back()
			app.canvas.queue_redraw()))
		app.editor_inspector.add_child(MenuStyle.button("Cancel surface",func() -> void:
			app.canvas.cancel_gesture()
			app.canvas.queue_redraw()))
	var materials = OptionButton.new()
	materials.custom_minimum_size.y = 54
	for surface: int in range(1,8):
		var label: String = preload("res://editor/surface_labels.gd").title(surface,str(app.document.theme))
		materials.add_item(GameText.message(label)+(" / "+GameText.message("Erase") if surface == 1 else ""))
	materials.selected = app.canvas.brush_surface-1
	materials.item_selected.connect(func(index: int) -> void:
		app.canvas.brush_surface = index+1
		app.canvas.mode = "paint"
		app._build_editor_tools())
	app.editor_inspector.add_child(materials)
	var actions = HBoxContainer.new()
	app.editor_inspector.add_child(actions)
	for entry: Array in [["paint","Paint"],["pan","Pan"]]:
		var value: String = entry[0]
		actions.add_child(MenuStyle.button(entry[1],func() -> void:
			app.canvas.mode = value
			app._build_editor_tools(),app.canvas.mode == value))
	if app.canvas.paint_mode != "area":
		var shapes = OptionButton.new()
		shapes.custom_minimum_size.y = 54
		shapes.add_item("Round brush")
		shapes.add_item("Square brush")
		shapes.selected = 1 if app.canvas.brush_shape == "square" else 0
		shapes.item_selected.connect(func(index: int) -> void: app.canvas.brush_shape = "square" if index else "round")
		app.editor_inspector.add_child(shapes)
	var help = MenuStyle.label("Tap to add points; drag dots to reshape. Confirm to place. Free painting commits on release.",16,true)
	if app.document.base_track != "": help.text += " Remix paints ground only."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.editor_inspector.add_child(MenuStyle.button("Clear map",func() -> void:
		app._remember()
		app.document.layout = {}
		app.document.paint = []
		app.document.pieces = []
		app.document.objects = []
		app.canvas.selected_object = -1
		app.canvas.selected = -1
		app.document.base_track = ""
		app.document.route_override = true
		app._save_draft(true)
		app._build_editor_tools()))
	app.editor_inspector.add_child(help)

func run_editor_help(app: Node) -> void:
	app._notice("Changes autosave to a separate WIP. Load reopens the latest saved draft or autosave. Save (Ctrl+S) updates the saved original.\n\nDrag inside a road section to move it. Drag an end dot to resize and turn it; the other end stays fixed.\n\nPC: wheel zooms at the pointer. Middle/right drag or Space + left drag pans. F fits the map. Ctrl+Z / Ctrl+Shift+Z undo/redo. Enter confirms; Esc cancels. Delete removes the selection. 1–4 switch tools. Q/E rotate. Tab cycles overlapping roads.\n\nPhone: two fingers pan/zoom. Layer selects the other road at an overpass. Bridge spans include ramps at both ends; paint edits the ground underneath.")

func run_unhandled_key_input(app: Node, event: InputEvent) -> void:
	if is_instance_valid(app.object_population_panel): return
	if app.screen != "create" or is_instance_valid(app.game) or not event is InputEventKey or not event.pressed: return
	var focus: Control = app.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var handled: bool = true
	if event.ctrl_pressed or event.meta_pressed:
		match key:
			KEY_Z:
				if event.shift_pressed: app._redo()
				elif not app.canvas.ghost.is_empty(): app._delete_piece()
				else: app._undo()
			KEY_Y: app._redo()
			KEY_S: app._save_track_explicit()
			_: handled = false
	else:
		match key:
			KEY_F: app.canvas.fit()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: app.canvas.zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT: app.canvas.zoom_by(1.0/1.15)
			KEY_ENTER, KEY_KP_ENTER:
				if app.canvas.mode == "road": app.canvas.confirm_piece()
				elif app.canvas.mode in ["paint","pan"]: app.canvas.confirm_paint()
			KEY_ESCAPE:
				app.canvas.cancel_gesture()
				app.canvas.ghost.clear()
				app.canvas.selected_piece = -1
				app.editor_geometry = ""
				app.editor_tools_panel.hide()
				app.editor_map_panel.hide()
				app._build_editor_tools()
			KEY_DELETE, KEY_BACKSPACE:
				if app.canvas.mode == "paint" and not app.canvas.paint_points.is_empty():
					app.canvas.paint_points.pop_back()
					app.canvas.paint_handle = -1
					app.canvas.queue_redraw()
				elif app.canvas.mode == "road": app._delete_piece()
				else: app._delete_selection()
			KEY_1: app._editor_category("road")
			KEY_2: app._editor_category("paint")
			KEY_3: app._editor_category("objects")
			KEY_4: app.canvas.choose_start_line()
			KEY_Q:
				if app.canvas.mode in ["objects","place"]: app._set_object_rotation(app._object_rotation()-22.5)
				else: app._change_piece("heading",-15.0)
			KEY_E:
				if app.canvas.mode in ["objects","place"]: app._set_object_rotation(app._object_rotation()+22.5)
				else: app._change_piece("heading",15.0)
			KEY_TAB:
				if app.canvas.mode == "objects": app.canvas.cycle_objects()
				else: app.canvas.cycle_piece()
			_: handled = false
	if handled: app.get_viewport().set_input_as_handled()

func run_save_track_explicit(app: Node) -> void:
	if str(app.document.get("name", "")).strip_edges().is_empty() or str(app.document.get("name", "")) == "My circuit":
		app._confirm_editor_departure(Callable(), false)
		return
	app._save_track_now()

func run_save_track_now(app: Node) -> bool:
	app._flush_editor_writes()
	if not app._commit_editor_previews(): return false
	app._stamp_creator()
	var id: String = str(app.document.id)
	if app.editor_save_error == OK and not app.editor_retry_original and app._editor_copy_is_current(app.editor_saved_snapshot,app.editor_saved_store,id+".json",app.editor_saved_disk_hash) and app._editor_copy_is_current(app.editor_wip_snapshot,app.editor_wip_store,"wip/"+id+".json",app.editor_wip_disk_hash) and not app.library.is_published(id):
		app.library.last_error = ""
		app._update_editor_save_state()
		return true
	if app._save_draft() != OK:
		app._notice("Could not save: "+app.library.last_error)
		return false
	var original_current: bool = not app.editor_retry_original and app._editor_copy_is_current(app.editor_saved_snapshot,app.editor_saved_store,id+".json",app.editor_saved_disk_hash) and not app.library.is_published(id)
	if not original_current and app.library.save_document(app.document) != OK:
		app.editor_retry_original = true
		app.editor_save_error = ERR_FILE_CANT_WRITE
		app.editor_save_message = "Could not save: "+app.library.last_error
		app._update_editor_save_state()
		app._notice("Could not save: "+app.library.last_error)
		return false
	elif not TrackDocument.validate(app.document).is_empty():
		app._notice("Draft saved. Open Load track to edit it. Before testing: "+TrackDocument.validate(app.document)[0])
	else:
		# Menus retain a compiled selection independently of the saved-track index.
		# Replace it after committing edits so Race cannot launch its old geometry.
		if app.selected_track != null and app.selected_track.identity == "creator_"+str(app.document.id) and app.selected_track.metadata.get("creator_document",{}) != app.document:
			var saved_track: NativeTrack = app.canvas.native_preview if app.canvas.native_preview != null and app.canvas.native_preview.metadata.get("creator_document",{}) == app.document else TrackCompiler.compile(app.document)
			if saved_track != null: app.selected_track = saved_track
		app._notice("Saved on this device. Open Load track to edit or test it.")
		if not original_current:
			app.editor_pending_road_bake = app.document.duplicate(true)
			if app.canvas.native_preview != null and app.canvas.native_preview.metadata.get("creator_document",{}) == app.document:
				NativeTrackVisual.request_saved_road_bake.call_deferred(app.canvas.native_preview,app.get_tree())
				app.editor_pending_road_bake.clear()
	var saved_title: Label = app.root_ui.find_child("TrackName",true,false) as Label
	if saved_title != null: saved_title.text = str(app.document.name)
	app.editor_saved_snapshot = app.document.duplicate(true)
	app.editor_saved_store = app.library
	if not original_current: app.editor_saved_disk_hash = FileAccess.get_sha256(app.library.directory.path_join(id+".json"))
	app.editor_retry_original = false
	app.editor_save_error = OK
	app.editor_save_message = ""
	app._update_editor_save_state()
	return true

func run_editor_has_unsaved_changes(app: Node) -> bool:
	if app.document.is_empty(): return false
	return app.editor_save_error != OK or app._has_pending_editor_work() or app.editor_saved_snapshot.is_empty() or TrackLibrary.draft_fingerprint(app.document) != TrackLibrary.draft_fingerprint(app.editor_saved_snapshot)

func run_request_editor_exit(app: Node) -> void:
	# Apply final write errors before deciding whether departure needs a retry.
	app._flush_editor_writes()
	if not app._editor_has_unsaved_changes():
		app._return_from_editor()
		return
	app._confirm_editor_departure(app._return_from_editor)

func run_return_from_editor(app: Node) -> void:
	# Closing an editor reached through its own Load action must not create a Back loop.
	if app.editor_return_screen == "drafts": app.draft_return_screen = "biome"
	app._show_screen(app.editor_return_screen)

func run_confirm_editor_departure(app: Node, after: Callable, allow_discard: bool = true) -> void:
	if app.root_ui.find_child("SaveChangesDialog", true, false) != null: return
	var dialog = ConfirmationDialog.new()
	dialog.name = "SaveChangesDialog"
	dialog.title = "Save this draft?"
	dialog.dialog_text = ""
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	var discard = dialog.add_button("Discard", true, "discard")
	discard.visible = allow_discard
	var field = LineEdit.new()
	field.name = "SaveDraftName"
	field.placeholder_text = "Track name"
	field.text = "" if str(app.document.get("name", "")) == "My circuit" else str(app.document.get("name", ""))
	field.max_length = 40
	field.custom_minimum_size = Vector2(440, 52)
	field.virtual_keyboard_enabled = true
	dialog.add_child(field)
	var update_save = func(value: String) -> void: dialog.get_ok_button().disabled = value.strip_edges().is_empty()
	field.text_changed.connect(update_save)
	update_save.call(field.text)
	dialog.confirmed.connect(func() -> void:
		dialog.hide() # Saving can open its own success/failure notice.
		app.document.name = field.text.strip_edges()
		if not app._save_track_now():
			dialog.queue_free()
			return
		dialog.queue_free()
		if after.is_valid(): after.call())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"discard": return
		var id: String = str(app.document.get("id", ""))
		if TrackDocument.valid_id(id) and app.library.delete_wip(id) != OK:
			app._notice("Could not discard the recovery draft: " + app.library.last_error)
			return
		dialog.queue_free()
		app._discard_editor_previews()
		if after.is_valid(): after.call())
	app.root_ui.add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_clamped(Vector2i(520, 180))
	preload("res://ui/keyboard_dialog.gd").attach(dialog, field)
	field.text_submitted.connect(func(_value: String) -> void:
		if not dialog.get_ok_button().disabled: dialog.confirmed.emit())
	field.grab_focus()

func run_prepare_editor_load(app: Node) -> bool:
	if not is_instance_valid(app.canvas): return true
	if app._has_pending_editor_work(): return app._commit_editor_previews()
	return true

func run_open_drafts(app: Node) -> void:
	if app.screen == "create" and app._editor_has_unsaved_changes():
		app._confirm_editor_departure(app._open_drafts_after_resolution)
		return
	app._open_drafts_after_resolution()

func run_open_drafts_after_resolution(app: Node) -> void:
	if not app._prepare_editor_load(): return
	app.draft_return_screen = "create" if app.screen == "create" else "biome"
	app._show_screen("drafts")

func run_drafts(app: Node) -> void:
	var browser: VBoxContainer = load("res://ui/draft_browser.gd").new()
	browser.name = "DraftBrowser"
	browser.set("library",app.library)
	browser.set("lifecycle",app.lifecycle)
	if app.editor_return_draft_view.get("directory","") == app.library.directory:
		browser.set("restore_view",app.editor_return_draft_view.duplicate())
	app.editor_return_draft_view = {}
	browser.connect("fork_requested",app._fork_track_draft)
	browser.connect("edit_requested",app._load_saved_document)
	browser.connect("test_requested",app._test_saved_draft)
	browser.connect("publish_requested",app._publish_saved_draft)
	browser.connect("store_requested",app._navigate_menu_page.bind("store"))
	browser.connect("back_requested",func() -> void: app._show_screen(app.draft_return_screen if not app.document.is_empty() else "biome"))
	browser.connect("delete_requested",app._confirm_delete_draft)
	if app.get_viewport().get_visible_rect().size.x < 1100 or app.get_viewport().get_visible_rect().size.y < 620:
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		app.content.add_child(scroll)
		browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(browser)
	else: app.content.add_child(browser)

func run_fork_track_draft(app: Node, source: Dictionary) -> void:
	var copy: Dictionary = source.duplicate(true)
	copy.id = TrackLibrary.unique_id()
	copy.name = str(copy.name)+" copy"
	app.document = copy
	app._stamp_creator()
	if app.library.save_wip(app.document) != OK:
		app._notice(app.library.last_error)
		return
	app.editor_view.clear()
	app.history.clear()
	app.redo_history.clear()
	app._show_screen("create")
	app._notify_creation_slots(str(app.document.id))

func run_read_draft_for_action(app: Node, id: String) -> Dictionary:
	var loaded: Dictionary = app.library.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else app.library.load_document(id)
	if loaded.is_empty():
		app._notice("Could not load this draft: "+app.library.last_error)
	elif app.library.is_published(str(loaded.id)):
		app._notice("This track is published and locked against editing.")
		return {}
	return loaded

func run_test_saved_draft(app: Node, id: String) -> void:
	var loaded: Dictionary = app._read_draft_for_action(id)
	if loaded.is_empty(): return
	var route: Dictionary = RoadPieces.route_from_pieces(loaded)
	if not route.ok:
		app._notice("Edit this track before testing: "+str(route.errors[0]))
		return
	if not loaded.has("start_line"):
		app._notice("Place a start line in the editor before testing.")
		return
	loaded = route.document
	app.document = loaded
	var track: NativeTrack = TrackCompiler.compile(loaded)
	if track == null:
		app._notice("This track needs repairs before testing. Open Edit track for details.")
		return
	if not await app._prepare_creator_test(loaded,track): return
	loaded = app.document
	app.document = loaded
	app.editor_view.clear()
	app.history.clear()
	app.redo_history.clear()
	track.spawn = app._practice_start(track)
	track.spawn_heading = app._practice_heading(track)
	await app._start_race(track,true)

func run_complete_draft_test(app: Node) -> void:
	if not is_instance_valid(app.game) or not app.game.preparation_complete or app.test_document_snapshot.is_empty(): return
	var witness: TrackSession = app.game.get("practice_validation")
	if not witness.finished or not bool(app.game.get("practice_validation_eligible")): return
	if not app._draft_test_save_is_current(app._draft_test_save_context):
		app._clear_draft_test_save_recovery()
		app._draft_test_save_context = {"game":app.game.get_instance_id(),"witness":witness,
			"storage":app.test_library_snapshot if app.test_library_snapshot != null else app.library,
			"scope":app.test_scope_snapshot,"vehicle":app.test_vehicle_snapshot,
			"document":app.test_document_snapshot.duplicate(true),"trajectory":app.game.race_proof.recording(witness),"was_paused":bool(app.game.get("paused"))}
	app._retry_draft_test_save(app._draft_test_save_context)

func run_draft_test_save_is_current(app: Node, context: Dictionary) -> bool:
	return not context.is_empty() and context==app._draft_test_save_context and is_instance_valid(app.game) and app.game.preparation_complete \
		and app.game.get_instance_id()==int(context.game) and app.game.get("practice_validation")==context.witness \
		and app.test_library_snapshot==context.storage and app.library==context.storage \
		and app.lifecycle!=null and app.lifecycle.scope()==str(context.scope) \
		and app.test_vehicle_snapshot==str(context.vehicle) and app.test_document_snapshot==context.document

func run_retry_draft_test_save(app: Node, context: Dictionary) -> void:
	if not app._draft_test_save_is_current(context): return
	if context.trajectory.is_empty():
		context.error = "The test recording is incomplete. Restart the test drive to record a new lap."
		app._show_draft_test_save_recovery()
		return
	if not context.has("staged"):
		var staged: Dictionary = app.lifecycle.stage(context.document.duplicate(true),[],str(context.vehicle),context.storage,str(context.scope),context.trajectory)
		if staged.is_empty():
			context.error = app.lifecycle.last_error if not app.lifecycle.last_error.is_empty() else "The completed test could not be saved. Free storage, then retry saving this recording."
			app._show_draft_test_save_recovery()
			return
		context.staged = staged
	var storage: TrackLibrary = context.storage
	var error: Error = storage.mark_tested(context.document.duplicate(true))
	if error != OK:
		var detail: String = storage.last_error if not storage.last_error.is_empty() else error_string(error)
		context.error = "The test recording is saved, but the test could not be marked complete. "+detail
		app._show_draft_test_save_recovery()
		return
	if not bool(context.was_paused) and bool(app.game.get("paused")): app.game.toggle_pause(false)
	app._clear_draft_test_save_recovery()
	app.pending_menu_notice = "Test lap saved on this device. Ready to publish."
	if app.test_return_to_drafts: app._leave_race()

func run_show_draft_test_save_recovery(app: Node) -> void:
	if not app._draft_test_save_is_current(app._draft_test_save_context): return
	if not bool(app.game.get("paused")): app.game.toggle_pause(false)
	if is_instance_valid(app._draft_test_save_dialog) and not app._draft_test_save_dialog.is_queued_for_deletion():
		if not app._draft_test_save_dialog.visible: app._draft_test_save_dialog.call("popup_message")
		return
	var context: Dictionary = app._draft_test_save_context
	var recovery = preload("res://ui/practice_save_recovery.gd").new()
	recovery.return_caption = "Return to drafts" if app.test_return_to_drafts else "Return to editor"
	recovery.retry_caption = "Restart" if context.trajectory.is_empty() else "Retry saving"
	recovery.dialog_text = str(context.get("error","The completed test could not be saved."))+"\nYour track remains saved on this device."
	app._draft_test_save_dialog = recovery
	app._own_dialog(recovery)
	recovery.confirmed.connect(func() -> void:
		if app._draft_test_save_dialog==recovery: app._draft_test_save_dialog = null
		if not app._draft_test_save_is_current(context): return
		if context.trajectory.is_empty():
			app._clear_draft_test_save_recovery()
			app.game.restart()
		else: app._retry_draft_test_save.call_deferred(context))
	recovery.return_requested.connect(func() -> void:
		app._return_from_draft_test_save.call_deferred(context))
	recovery.tree_exited.connect(func() -> void:
		if app._draft_test_save_dialog==recovery: app._draft_test_save_dialog = null)
	recovery.popup_message()

func run_return_from_draft_test_save(app: Node, context: Dictionary) -> void:
	if not app._draft_test_save_is_current(context): return
	app._clear_draft_test_save_recovery()
	app._leave_race()

func run_clear_draft_test_save_recovery(app: Node) -> void:
	app._draft_test_save_context = {}
	if is_instance_valid(app._draft_test_save_dialog):
		app._draft_test_save_dialog.hide()
		app._draft_test_save_dialog.queue_free()
	app._draft_test_save_dialog = null

func run_publish_saved_draft(app: Node, id: String) -> void:
	if is_instance_valid(app._publication_dialog): return
	if app._publication_request_active:
		app._notice("Publication is already in progress. Please wait for its status to update.")
		return
	var loaded: Dictionary = app._read_draft_for_action(id)
	if loaded.is_empty(): return
	app._telemetry_observe("publish_requested",{"biome":str(loaded.get("theme","")),"reason":"publish"})
	if app.online == null or not app.online.client.signed_in():
		app._notice("Sign in to publish this track to the cloud. Your draft remains saved locally.")
		return
	var original_scope: String = app.lifecycle.scope()
	var storage: TrackLibrary = app.library
	var navigation: int = app._navigation_generation
	var notice = app.PublicationPrompt.new()
	app._publication_dialog = notice
	notice.configure_publication(app.lifecycle,loaded,func() -> bool: return app.lifecycle.scope() == original_scope and app.library == storage and app._navigation_generation == navigation)
	app._own_dialog(notice)
	notice.publish_confirmed.connect(app._confirm_saved_publication.bind(id,loaded,original_scope,storage,navigation,notice))
	notice.confirmed.connect(app._close_publication_prompt.bind(loaded,original_scope,storage,navigation))
	notice.canceled.connect(app._close_publication_prompt.bind(loaded,original_scope,storage,navigation))
	notice.popup_message()

func run_close_publication_prompt(app: Node, source: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int) -> void:
	app._acknowledge_publication_dialog(source,original_scope)
	if app.lifecycle.scope() != original_scope or app.library != storage or app._navigation_generation != navigation: return
	var job: Dictionary = app.lifecycle.status_for(source)
	if job.get("state") not in ["finishing","published"] or not job.get("receipt") is Dictionary: return
	if not app.document.is_empty() and TrackLibrary.draft_fingerprint(app.document) == TrackLibrary.draft_fingerprint(source):
		app.document = {}
		app.editor_view.clear()
		app.history.clear()
		app.redo_history.clear()
	if app.screen == "create": app._open_published_track(job.receipt)

func run_confirm_saved_publication(app: Node, id: String, loaded: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int, notice: PublicationPrompt) -> void:
	if app.lifecycle.scope() != original_scope or app.library != storage or app._navigation_generation != navigation: return
	var current: Dictionary = app.library.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else app.library.load_document(id)
	if current.is_empty() or TrackLibrary.draft_fingerprint(current) != TrackLibrary.draft_fingerprint(loaded):
		notice.submission_finished(false,"This draft changed while confirmation was open. Review the latest version before publishing.")
		return
	app._publication_request_active = true
	var accepted_terms: bool = await preload("res://ui/community_safety_ui.gd").ensure_terms(notice,app.online.client)
	if app.lifecycle.scope() != original_scope or app.library != storage or app._navigation_generation != navigation:
		app._publication_request_active = false
		return
	if not accepted_terms:
		app._publication_request_active = false
		if is_instance_valid(notice): notice.submission_finished(false,"Public sharing rules must be accepted online before publishing. Your draft remains saved.")
		return
	current = app.library.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else app.library.load_document(id)
	if current.is_empty() or TrackLibrary.draft_fingerprint(current) != TrackLibrary.draft_fingerprint(loaded):
		app._publication_request_active = false
		if is_instance_valid(notice): notice.submission_finished(false,"This draft changed before publication. Review the latest version before publishing.")
		return
	var requested: bool = await app.lifecycle.request_publish(loaded)
	app._publication_request_active = false
	if app.lifecycle.scope() != original_scope: return
	if is_instance_valid(notice): notice.submission_finished(requested,app.lifecycle.last_error)

func run_open_published_track(app: Node, receipt: Dictionary) -> void:
	# Publishing is a direct navigation to the acknowledged public card.
	# Previous search/feed filters must not hide the track just published.
	app.browser_state.clear()
	app.browser_state.focus_track = "cloud_"+str(receipt.track_id)
	app.browser_state.pinned_version = str(receipt.get("version_id",""))
	if app.cloud.paged_discovery_available(): app.browser_state.feed = "new"
	app.race_area_mode = "free"
	app._show_screen("tracks")

func run_prepare_creator_test(app: Node, source: Dictionary, prepared: NativeTrack = null) -> bool:
	if app.lifecycle == null: return true
	var original_scope: String = app.lifecycle.scope()
	var fingerprint: String = TrackLibrary.draft_fingerprint(source)
	app.cloud_starting = true
	var exact: Dictionary = await app.lifecycle.prepare_test(source.duplicate(true),prepared)
	app.cloud_starting = false
	if app.lifecycle.scope() != original_scope or app.document.is_empty() or TrackLibrary.draft_fingerprint(app.document) != fingerprint: return false
	if exact.is_empty():
		app._notice(app.lifecycle.last_error)
		return false
	# Keep the canvas bound to the same dictionary throughout a practice loop.
	if app.document != exact: app.document = exact
	app.library.owner_name = str(exact.get("creator",app.library.owner_name))
	if prepared != null and is_instance_valid(app.canvas) and app._editor_copy_is_current(app.editor_wip_snapshot,app.editor_wip_store,"wip/"+str(app.document.id)+".json",app.editor_wip_disk_hash): return true
	return app.library.save_wip(app.document) == OK

func run_view_publication_notification(app: Node, item: Dictionary) -> void:
	if app.lifecycle.scope() != item.scope or is_instance_valid(app.game): return
	if not app.cloud.remember_publication(item.receipt):
		app._notice("Your track is published, but could not be opened on this device. Check available storage and try again.")
		return
	if not app.lifecycle.acknowledge_publication(str(item.version_id),str(item.scope)):
		app._notice(app.lifecycle.last_error)
		return
	app._open_published_track(item.receipt)

func run_confirm_delete_draft(app: Node, id: String, title: String) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.name = "DeleteDraftDialog"
	dialog.title = "Delete draft?"
	dialog.dialog_autowrap = true
	dialog.dialog_text = GameText.message('Delete "%s" and its autosave from this device?\nPublished versions stay available.\nThis cannot be undone.') % title
	dialog.ok_button_text = "Delete draft"
	dialog.confirmed.connect(func() -> void:
		app._flush_editor_writes()
		if app.lifecycle != null and not app.lifecycle.archive_draft(id):
			app._notice(app.lifecycle.last_error)
			return
		if app.library.delete_editable(id) != OK:
			app._notice(app.library.last_error)
			return
		if app.document.get("id","") == id:
			app.document = {}
			app.history.clear()
			app.redo_history.clear()
			app.editor_view.clear()
		if app.selected_track != null and app.selected_track.identity == "creator_"+id:
			app.selected_track = NativeTrack.read("res://resources/tracks/"+app.BUILTIN_IDS[0]+".json")
		var favorites: Array = app.records.settings.get("favorites",[]).duplicate()
		favorites.erase("creator_"+id)
		app.records.settings.favorites = favorites
		if app.records.settings.get("last_track","") == "creator_"+id: app.records.settings.last_track = app.selected_track.identity
		var settings_error: Error = app.records.save_records()
		app._show_screen("drafts")
		if settings_error != OK: app._notice("Draft deleted, but favorite settings could not be saved."))
	app._own_dialog(dialog)
	dialog.popup_centered(Vector2i(500,210))
	dialog.get_cancel_button().grab_focus()

func run_load_track_dialog(app: Node) -> void:
	app._open_drafts()

func run_load_saved_document(app: Node, id: String) -> void:
	var loaded: Dictionary = app._read_draft_for_action(id)
	if loaded.is_empty(): return
	app.document = loaded
	app.editor_pending_tools.clear()
	app.editor_saved_snapshot = app.library.load_document(str(loaded.id)) if id.begins_with("wip:") else loaded.duplicate(true)
	app.editor_saved_store = app.library
	app.editor_saved_disk_hash = "" # A recovered backup must be committed before it is acknowledged.
	app.canvas = null # Loading a different document must not capture the outgoing view.
	app.editor_view.clear()
	app.history.clear()
	app.redo_history.clear()
	app.editor_geometry = ""
	app._show_screen("create")
	app.editor_status.text = "Loaded "+str(app.document.name)+" for editing."

func run_editor_track_preview(app: Node) -> NativeTrack:
	app._finish_preview_thread()
	return app._compile_editor_preview(app.document)

func run_compile_editor_preview(app: Node, source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	# Only the single preview worker (or its joined foreground replacement)
	# accesses this bounded cache. Undo can reuse collision and route data too.
	for index: int in range(app.editor_compiled_cache.size()):
		var entry: Dictionary = app.editor_compiled_cache[index]
		if entry.document == source:
			app.editor_compiled_cache.remove_at(index); app.editor_compiled_cache.append(entry); return entry.track
	var result: NativeTrack = app._compile_editor_preview_uncached(source,cancelled)
	if result != null:
		var size: int = var_to_bytes(preload("res://editor/prepared_track_cache.gd").fields(result)).size()+var_to_bytes(source).size()+var_to_bytes(result.editor_winter_cover).size()
		if size <= app.EDITOR_COMPILED_BUDGET:
			var total: int = size
			for entry: Dictionary in app.editor_compiled_cache: total += int(entry.bytes)
			while not app.editor_compiled_cache.is_empty() and (app.editor_compiled_cache.size() >= 3 or total > app.EDITOR_COMPILED_BUDGET): total -= int(app.editor_compiled_cache.pop_front().bytes)
			app.editor_compiled_cache.append({"document":source.duplicate(true),"track":result,"bytes":size})
	return result

func run_compile_editor_preview_uncached(app: Node, source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	if TrackDocument.validate(source).is_empty(): return app._compile_editor_with_masks(source,cancelled)
	if not TrackDocument.validate(source,false).is_empty(): return null
	# A draft may have an unfinished lap. Render its actual map using a safe
	# preview-only route; never change the saved route or permit racing it.
	var preview_document: Dictionary = source.duplicate(true)
	var fallback: Dictionary = TrackDocument.create_default()
	for key: String in ["points","widths","corners"]: preview_document[key] = fallback[key]
	preview_document.route_override = true
	return app._compile_editor_with_masks(preview_document,cancelled)

func run_compile_editor_with_masks(app: Node, source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	var track: NativeTrack = TrackCompiler.compile(source,app.editor_raster_cache,cancelled)
	if track != null:
		CreatorPreviewMasks.prepare(track,source.paint,app.editor_raster_cache)
		track.editor_ground_key = preload("res://editor/preview_ground.gd").key_for(track)
		if source.theme == "winter": track.editor_winter_cover = WinterScenery.prepare_cover(track,app.editor_raster_cache,cancelled)
		if cancelled.is_valid() and cancelled.call(): return null
		# Planning roads are prepared separately, with a distinct cache identity
		# from final racing geometry. Never join road work in a draft-save handler.
	return track


func run_confirm_delete_track(app: Node, id: String, title: String) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.name = "DeleteTrackDialog"
	dialog.title = "Delete saved track?"
	dialog.dialog_text = GameText.message('Delete "%s" from this device?\nThis cannot be undone.') % title
	dialog.ok_button_text = "Delete track"
	dialog.confirmed.connect(app._delete_user_track.bind(id))
	app._own_dialog(dialog)
	dialog.popup_centered(Vector2i(480,190))
	dialog.get_cancel_button().grab_focus()

func run_delete_user_track(app: Node, id: String) -> void:
	app._flush_editor_writes()
	if app.library.delete_document(id) != OK:
		app._notice(app.library.last_error)
		return
	var identity: String = "creator_"+id
	if app.document.get("id","") == id:
		app.document = {}
		app.history.clear()
		app.redo_history.clear()
		app.editor_view.clear()
	if app.selected_track != null and app.selected_track.identity == identity:
		app.selected_track = NativeTrack.read("res://resources/tracks/"+app.BUILTIN_IDS[0]+".json")
	var favorites: Array = app.records.settings.get("favorites",[]).duplicate()
	favorites.erase(identity)
	app.records.settings["favorites"] = favorites
	if app.records.settings.get("last_track","") == identity: app.records.settings["last_track"] = app.selected_track.identity
	var settings_error: Error = app.records.save_records()
	app._show_screen("tracks")
	if settings_error != OK: app._notice("Track deleted, but favorite settings could not be saved.")

func run_choose_object(app: Node, kind: String) -> void:
	var family: Array = CreatorCatalog.family(kind)
	var same_family: bool = kind == app.canvas.stamp_kind or (not family.is_empty() and app.canvas.stamp_kind in family[3])
	if CreatorCatalog.JUMP_ASSETS.has(kind): same_family = same_family and app.canvas.stamp_jump_profile == str(CreatorCatalog.JUMP_ASSETS[kind])
	var placement: String = app.object_browser.placement if same_family else "single"
	app.canvas.cancel_gesture()
	var jump_profile: String = str(CreatorCatalog.JUMP_ASSETS.get(kind,""))
	app.canvas.multi_select = false
	app.canvas.stamp_kind="jump" if not jump_profile.is_empty() else kind
	if app.canvas.stamp_kind == "jump":
		app.canvas.stamp_jump_profile = jump_profile if not jump_profile.is_empty() else JumpProfiles.default_for(str(app.document.theme))
		app.object_browser.current = CreatorCatalog.jump_asset(app.canvas.stamp_jump_profile,str(app.document.theme))
	if is_instance_valid(app.editor_world): app.editor_world.warm_prop(app.canvas.stamp_kind,CreatorCatalog.default_scale(kind),app.canvas.stamp_container_color)
	if not same_family: app.canvas.stamp_scale=CreatorCatalog.default_scale(kind)
	app.object_browser.stamp_scale=app.canvas.stamp_scale
	app.canvas.selected_object=-1
	app._object_placement(placement)

func run_container_colour(app: Node, color: String) -> void:
	if not ContainerPaint.valid(color) or not is_instance_valid(app.canvas): return
	app.canvas.stamp_container_color = color
	if is_instance_valid(app.editor_world): app.editor_world.warm_prop("container",app.canvas.stamp_scale,color)
	if is_instance_valid(app.object_browser):
		app.object_browser.stamp_container_color = color
		app.object_browser.refresh()
	if app.canvas.selected_object < 0: return
	var object: Dictionary = app.document.objects[app.canvas.selected_object]
	if object.kind != "container" or ContainerPaint.value(object) == color: return
	app._remember()
	object["color"] = color
	app._commit_selection()

func run_open_object_population(app: Node) -> void:
	if is_instance_valid(app.object_population_panel) or not is_instance_valid(app.canvas): return
	if app._has_pending_editor_work():
		app._notice("Confirm or cancel the preview before populating.")
		return
	if app.document.objects.size() >= ObjectPopulation.MAX_OBJECTS:
		app._notice("Remove an object before adding more.")
		return
	var errors: Array[String] = TrackDocument.validate(app.document,false)
	if not errors.is_empty():
		app._notice(errors[0])
		return
	if app.editor_preview_thread != null or app.canvas.native_preview == null:
		app._editor_hint("The track is still being prepared. Try Populate again shortly.")
		return
	app.canvas.cancel_gesture()
	var preview = ObjectPopulationPanel.new()
	preview.source = app.document.duplicate(true)
	preview.terrain = app.canvas.native_preview
	preview.navigation_canvas = app.canvas
	preview.previous_mode = app.canvas.mode
	app.canvas.mode = "pan"
	app.object_population_panel = preview
	app.root_ui.add_child(preview)
	preview.preview_changed.connect(func(track: NativeTrack) -> void:
		if app.screen == "create" and is_instance_valid(app.editor_world): app.editor_world.show_track(track))
	preview.cancel_requested.connect(func() -> void: app._close_object_population(false))
	preview.apply_requested.connect(func(objects: Array) -> void:
		if app.document != preview.source:
			app._close_object_population(false)
			app._editor_hint("The track changed. Open Populate again.")
			return
		if objects.is_empty() or app.document.objects.size()+objects.size() > ObjectPopulation.MAX_OBJECTS: return
		var admission: String = preload("res://editor/creator_limits.gd").addition_error(app.document.objects,objects,str(app.document.theme))
		if not admission.is_empty(): app._editor_hint(admission); return
		if not app.canvas.admit("objects",app.document.objects+objects): return
		app._remember()
		app.document.objects.append_array(objects)
		app.document["automatic_scenery"] = false
		app.canvas.selected_object = -1
		app.canvas.mode = "objects"
		app._close_object_population(true)
		app._save_draft(true)
		app._build_editor_tools())

func run_close_object_population(app: Node, applied: bool) -> void:
	if not is_instance_valid(app.object_population_panel): return
	if is_instance_valid(app.canvas):
		app.canvas.cancel_gesture()
		app.canvas.mode = "objects" if applied else app.object_population_panel.previous_mode
	app.object_population_panel.queue_free()
	app.object_population_panel = null
	if not applied and is_instance_valid(app.editor_world) and is_instance_valid(app.canvas):
		app.editor_world.show_track(app.canvas.native_preview)

func run_object_placement(app: Node, value: String) -> void:
	app.canvas.cancel_gesture()
	app.canvas.run_start=Vector2.INF
	app.canvas.run_preview.clear()
	app.canvas.run_shape="curve" if value=="curve" else "line"
	app.canvas.free_run=value!="road edge"
	app.canvas.mode="place" if value=="single" else "run"
	app.object_browser.placement=value
	app._build_editor_tools()

func run_choose_hazard(app: Node, kind: String) -> void:
	app.canvas.cancel_gesture()
	app.canvas.ghost.clear()
	app.canvas.stamp_kind=kind
	app.canvas.stamp_scale=1.0
	app.canvas.selected_object=-1
	app.canvas.mode="place"
	app._build_editor_tools()
	app.editor_status.text=CreatorObjects.description(kind)+" / tap to place; Objects > Select to adjust"


func run_rename_track(app: Node) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.name="RenameDialog"
	dialog.borderless=true
	dialog.title="Name your track"
	dialog.ok_button_text="Apply name"
	dialog.add_theme_stylebox_override("panel",EditorStyle.box())
	EditorStyle.apply(dialog.get_ok_button())
	EditorStyle.apply(dialog.get_cancel_button())
	dialog.get_ok_button().custom_minimum_size=Vector2(130,44)
	dialog.get_cancel_button().custom_minimum_size=Vector2(110,44)
	var column = VBoxContainer.new()
	column.custom_minimum_size=Vector2(460,116)
	column.add_theme_constant_override("separation",12)
	dialog.add_child(column)
	column.add_child(MenuStyle.label("Give your track a name",22))
	var field = LineEdit.new()
	field.name="CircuitName"
	field.text=str(app.document.name)
	field.max_length=40
	field.custom_minimum_size=Vector2(440,52)
	field.virtual_keyboard_enabled=true
	EditorStyle.apply(field)
	field.add_theme_font_size_override("font_size",20)
	column.add_child(field)
	field.text_changed.connect(func(value: String) -> void: dialog.get_ok_button().disabled=value.strip_edges().is_empty())
	var apply_name: Callable=func() -> void:
		if field.text.strip_edges().is_empty(): return
		app.document.name=field.text.strip_edges()
		(app.root_ui.find_child("TrackName",true,false) as Label).text=app.document.name
		app._save_draft(true)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.hide(); dialog.queue_free()
	dialog.confirmed.connect(apply_name)
	field.text_submitted.connect(func(_value: String) -> void: apply_name.call())
	dialog.canceled.connect(func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.queue_free())
	app.root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(500,220))
	preload("res://ui/keyboard_dialog.gd").attach(dialog, field)
	field.grab_focus()
	field.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(field.text,field.get_viewport().get_screen_transform()*field.get_global_rect(),DisplayServer.KEYBOARD_TYPE_DEFAULT,40,0,field.text.length())

func run_build_surface_toolbar(app: Node) -> void:
	for child: Node in app.surface_actions.get_children():
		app.surface_actions.remove_child(child)
		child.queue_free()
	app.surface_actions.add_theme_constant_override("separation",12)
	var modes = VBoxContainer.new()
	app.surface_actions.add_child(modes)
	var heading = MenuStyle.label("Paint mode",18)
	heading.add_theme_color_override("font_color",Color("97dce1"))
	modes.add_child(heading)
	var segments = HBoxContainer.new()
	segments.name = "SurfacePlacementModes"
	segments.add_theme_constant_override("separation",0)
	modes.add_child(segments)
	for entry: Array in [["free","Free","paint_brush"],["area","Area","paint_area"],["line","Line","paint_line"]]:
		var value: String = entry[0]
		var chosen: bool = app.canvas.paint_mode == value
		var button: Button = EditorButton.make(entry[1],entry[2],func() -> void:
			app.canvas.cancel_gesture()
			app.canvas.paint_mode = value
			app.canvas.mode = "paint"
			app.canvas.queue_redraw()
			app._build_editor_tools(),chosen)
		button.name = "PaintMode_"+value
		button.custom_minimum_size = Vector2(78,68)
		for state: String in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat = EditorStyle.box(chosen or state in ["pressed","hover_pressed"],state=="hover",18)
			if chosen: style.bg_color = Color("087b8d")
			button.add_theme_stylebox_override(state,style)
		segments.add_child(button)
	if app.canvas.paint_mode == "area":
		app._surface_point_controls()
		return
	var brush = VBoxContainer.new()
	brush.custom_minimum_size.x = 178
	app.surface_actions.add_child(brush)
	var size_label = MenuStyle.label(GameText.message("Brush size  %.1f m") % app.canvas.brush_width,18)
	size_label.name = "BrushSizeReadout"
	size_label.add_theme_color_override("font_color",Color("97dce1"))
	brush.add_child(size_label)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",EditorStyle.box())
	brush.add_child(panel)
	var controls = HBoxContainer.new()
	panel.add_child(controls)
	var slider = HSlider.new()
	slider.name = "BrushSizeSlider"
	slider.min_value = 0.5
	slider.max_value = 40.0
	slider.step = 0.5
	slider.value = app.canvas.brush_width
	slider.custom_minimum_size = Vector2(112,48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rail = StyleBoxFlat.new()
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
		app.canvas.brush_width = value
		size_label.text = GameText.message("Brush size  %.1f m") % value
		app.canvas.queue_redraw())
	var smaller: Button = EditorStyle.button("-",func() -> void: slider.value -= 0.5)
	smaller.name = "BrushSmaller"
	smaller.custom_minimum_size = Vector2(36,48)
	controls.add_child(smaller)
	controls.add_child(slider)
	var bigger: Button = EditorStyle.button("+",func() -> void: slider.value += 0.5)
	bigger.name = "BrushBigger"
	bigger.custom_minimum_size = Vector2(36,48)
	controls.add_child(bigger)
	var options: Button = EditorButton.make("","options",func() -> void: app.editor_tools_panel.visible = not app.editor_tools_panel.visible)
	options.name = "SurfaceOptions"
	options.tooltip_text = "Brush shape, navigation and road protection"
	options.size_flags_vertical = Control.SIZE_SHRINK_END
	app.surface_actions.add_child(options)

func run_surface_point_controls(app: Node) -> void:
	var area = VBoxContainer.new()
	app.surface_actions.add_child(area)
	area.add_child(MenuStyle.label(GameText.message("Area · %d points") % app.canvas.paint_points.size(),18))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation",6); area.add_child(row)
	var remove: Button = EditorStyle.button("Undo point",func() -> void:
		if not app.canvas.paint_points.is_empty(): app.canvas.paint_points.pop_back()
		app._build_editor_tools())
	remove.name = "AreaRemovePoint"; remove.custom_minimum_size = Vector2(90,54)
	remove.disabled = app.canvas.paint_points.is_empty(); row.add_child(remove)
	var cancel: Button = EditorStyle.button("Cancel",func() -> void: app.canvas.cancel_gesture(); app._build_editor_tools())
	cancel.name = "AreaCancel"; cancel.custom_minimum_size = Vector2(72,54); row.add_child(cancel)
	var confirm: Button = EditorStyle.button("Place",func() -> void: app.canvas.confirm_paint(); app._build_editor_tools())
	confirm.name = "AreaConfirm"; confirm.custom_minimum_size = Vector2(72,54)
	confirm.disabled = app.canvas.paint_points.size() < 3; row.add_child(confirm)
	var options: Button = EditorButton.make("","options",func() -> void: app.editor_tools_panel.visible = not app.editor_tools_panel.visible)
	options.name = "SurfaceOptions"; options.size_flags_vertical = Control.SIZE_SHRINK_END; app.surface_actions.add_child(options)
func run_poll_editor_frame(app: Node) -> void:
	app.editor_commits.poll()
	app._apply_editor_commits()
	app.editor_writes.poll()
	app._apply_editor_writes()
	if is_instance_valid(app.editor_loading) and is_instance_valid(app.canvas):
		app.editor_loading.visible = app.editor_commits.unsettled() or app.editor_preview_thread != null or app.canvas.native_preview == null or app.editor_world._building
	if app.editor_preview_thread == null or app.editor_preview_thread.is_alive(): return
	# Finish the detailed scene between gestures, never underneath a finger.
	if is_instance_valid(app.canvas) and app.canvas.active_pointer != -99: return
	var result: NativeTrack = app.editor_preview_thread.wait_to_finish()
	app.editor_preview_thread = null
	if result != null and not app.editor_pending_road_bake.is_empty() and result.metadata.get("creator_document",{}) == app.editor_pending_road_bake:
		NativeTrackVisual.request_saved_road_bake.call_deferred(result,app.get_tree())
		app.editor_pending_road_bake.clear()
	if not is_instance_valid(app.canvas) or app.screen != "create":
		if result != null: result.editor_roads = {}
		return
	if app.document != app.editor_preview_document:
		if result != null: result.editor_roads = {}
		app._queue_editor_preview()
		return
	app.editor_preview_document = {}
	if result != null: app.canvas.show_native(result)
	app._update_editor_issues()

