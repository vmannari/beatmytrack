extends Node
## Editor controller. Live state belongs to this feature; App supplies navigation and services.
const EditorState = preload("res://editor/editor_state.gd")
var editor_state: EditorState
var storage: TrackLibrary
var publication: TrackLifecycle
signal notice_requested(message: String)
signal navigation_requested(screen: String)
const PublicationPrompt = preload("res://ui/publication_dialog.gd")
const LAYOUT = preload("res://editor/editor_layout.gd")

func run_queue_editor_preview(app: Node) -> void:
	if editor_state.preview_thread != null:
		if editor_state.preview_cancel != null and editor_state.document != editor_state.preview_document: editor_state.preview_cancel.cancel()
		return
	editor_state.preview_document = editor_state.document.duplicate(true)
	editor_state.preview_thread = Thread.new()
	editor_state.preview_cancel = preload("res://editor/work_job.gd").new()
	var error: Error = editor_state.preview_thread.start(app._compile_editor_preview.bind(editor_state.preview_document,editor_state.preview_cancel.cancelled))
	if error != OK:
		editor_state.preview_thread = null
		var track: NativeTrack = app._compile_editor_preview(editor_state.preview_document)
		editor_state.preview_document = {}
		if track != null: editor_state.canvas.show_native(track)
		run_update_editor_issues(app)

func run_objects_only_edit(app: Node) -> bool:
	if not is_instance_valid(editor_state.canvas) or editor_state.canvas.native_preview == null: return false
	var previous: Dictionary = editor_state.canvas.native_preview.metadata.get("creator_document",{})
	for key: Variant in editor_state.document:
		if key in ["objects","hidden_scenery"]: continue
		if not previous.has(key) or previous[key] != editor_state.document[key]: return false
	for key: Variant in previous:
		if key not in ["objects","hidden_scenery"] and not editor_state.document.has(key): return false
	return true


func run_editor(app: Node) -> void:
	app._stamp_creator()
	if editor_state.document.is_empty():
		editor_state.document = TrackDocument.create_blank()
		editor_state.document.id = TrackLibrary.unique_id()
		app._stamp_creator()
	if editor_state.pending_id != str(editor_state.document.id):
		editor_state.pending_tools.clear()
		editor_state.pending_id = str(editor_state.document.id)
		editor_state.save_error = OK
		editor_state.retry_original = false
		editor_state.save_message = ""
		editor_state.wip_saved = ""
		editor_state.wip_snapshot.clear()
		editor_state.wip_store = null
		editor_state.wip_disk_hash = ""
		editor_state.issue_cursor = -1
	editor_state.world = EditorWorld.new()
	editor_state.world._detail.enabled = not bool(editor_state.view.get("detailed_scenery",false))
	editor_state.session.prime(editor_state.document)
	editor_state.world.theme_id = str(editor_state.document.theme)
	app.root_ui.add_child(editor_state.world)
	MenuStyle.fill(editor_state.world)
	editor_state.canvas = EditorCanvas.new()
	editor_state.canvas.stamp_kind = "rock" if editor_state.document.theme == "desert" else "light" if editor_state.document.theme == "night_city" else "tree"
	editor_state.canvas.document = editor_state.document
	if not editor_state.view.is_empty():
		preload("res://editor/view_state.gd").restore(editor_state.canvas,editor_state.view)
	app.root_ui.add_child(editor_state.canvas)
	MenuStyle.fill(editor_state.canvas)
	editor_state.world.follow_canvas(editor_state.canvas)
	editor_state.canvas.native_changed.connect(editor_state.world.show_track)
	editor_state.canvas.edit_started.connect(func() -> void:
		editor_state.session.begin_gesture(editor_state.document)
		if editor_state.canvas.mode in ["move","add"]: editor_state.document.route_override = true)
	editor_state.canvas.document_changed.connect(func() -> void:
		editor_state.canvas.refresh()
		editor_state.test_button.disabled = true
		editor_state.publish_button.disabled = true
		editor_state.share_button.disabled = true)
	editor_state.canvas.edit_finished.connect(func() -> void:
		run_save_draft(app,true)
		editor_state.session.finish_gesture())
	editor_state.canvas.edit_cancelled.connect(func() -> void:
		editor_state.session.cancel_gesture()
		editor_state.canvas.selected_object = mini(editor_state.canvas.selected_object,editor_state.document.objects.size()-1)
		run_save_draft(app,true)
		run_update_editor_issues(app)
		run_build_editor_tools(app))
	editor_state.canvas.hint_changed.connect(app._editor_hint)
	var overlay = Control.new()
	overlay.name = "EditorOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.root_ui.add_child(overlay)
	MenuStyle.fill(overlay)
	var close: Button = EditorButton.make("","close",func() -> void:
		run_request_editor_exit(app))
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
	track_name.text=str(editor_state.document.name)
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
	editor_state.undo=EditorButton.make("","undo",app._undo)
	editor_state.undo.text="Undo"
	EditorStyle.integrated(editor_state.undo)
	editor_state.undo.tooltip_text="Undo"
	history.add_child(editor_state.undo)
	editor_state.redo=EditorButton.make("","redo",app._redo)
	editor_state.redo.text="Redo"
	EditorStyle.integrated(editor_state.redo)
	editor_state.redo.tooltip_text="Redo"
	history.add_child(editor_state.redo)
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
	editor_state.issue_button = EditorStyle.button("",app._focus_issue)
	editor_state.issue_button.custom_minimum_size = Vector2(112,52)
	top.add_child(editor_state.issue_button)
	var settings: Button = EditorButton.make("","more",func() -> void:
		editor_state.canvas.cancel_gesture(false)
		editor_state.map_panel.visible = not editor_state.map_panel.visible
		editor_state.tools_panel.hide())
	settings.text = "Map"
	settings.tooltip_text = "Map settings"
	top.add_child(settings)
	var save_action: Button = EditorStyle.button("Save",app._save_track_explicit)
	save_action.name = "EditorSaveAction"
	save_action.custom_minimum_size = Vector2(76,52)
	top.add_child(save_action)
	editor_state.test_button = EditorButton.action("Test","play",app._test_document)
	editor_state.test_button.custom_minimum_size=Vector2(104,52)
	top.add_child(editor_state.test_button)
	EditorStyle.apply(editor_state.test_button)
	var disabled_play: StyleBoxFlat=EditorStyle.box()
	disabled_play.bg_color=Color("252d30")
	disabled_play.border_color=Color("586369")
	disabled_play.shadow_size=0
	editor_state.test_button.add_theme_stylebox_override("disabled",disabled_play)
	for state: String in ["normal","hover","pressed","hover_pressed"]:
		var play_style: StyleBoxFlat=EditorStyle.box()
		play_style.bg_color=Color("29412e") if state=="hover" else Color(0.075,0.14,0.095,0.94)
		play_style.border_color=Color(0.65,0.82,0.43,0.45)
		play_style.set_border_width_all(1)
		editor_state.test_button.add_theme_stylebox_override(state,play_style)
	editor_state.publish_button = EditorButton.action("Publish","publish",app._publish_current_document,true)
	editor_state.publish_button.name = "PublishTrack"
	editor_state.publish_button.tooltip_text = "Complete a test drive before publishing this version."
	editor_state.publish_button.custom_minimum_size=Vector2(132,52)
	top.add_child(editor_state.publish_button)
	# Center history while keeping clear of the title and right-hand actions.
	var fit_header: Callable = app._fit_editor_header.bind(overlay,header_left,track_name,history_panel,top)
	overlay.resized.connect(fit_header)
	top.minimum_size_changed.connect(fit_header)
	editor_state.issue_button.visibility_changed.connect(fit_header)
	fit_header.call_deferred()
	var rail = VBoxContainer.new()
	rail.name = "EditorRail"
	var rail_panel = PanelContainer.new()
	rail_panel.name = "EditorRailPanel"
	rail_panel.anchor_top=0.5; rail_panel.anchor_bottom=0.5
	rail_panel.offset_left=16
	rail_panel.grow_vertical=Control.GROW_DIRECTION_BOTH
	rail_panel.resized.connect(func() -> void: LAYOUT.arrange.call_deferred(app))
	rail_panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(rail_panel)
	rail_panel.add_child(rail)
	rail.add_theme_constant_override("separation",6)
	editor_state.mode_buttons.clear()
	for pair: Array in [["road","Road","road"],["paint","Surfaces","surface"],["objects","Objects","objects"]]:
		var value: String = pair[0]
		var button: Button = EditorButton.make(pair[1],pair[2],app._editor_category.bind(value))
		button.name = "Editor"+({"road":"Road","paint":"Surface"}.get(value,pair[1]))
		button.custom_minimum_size=Vector2(86,76)
		button.toggle_mode = true
		EditorStyle.integrated(button)
		editor_state.mode_buttons[value] = button
		rail.add_child(button)
	var view_controls := VBoxContainer.new()
	view_controls.name = "EditorViewControls"
	overlay.add_child(view_controls)
	view_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_controls.offset_left = -100; view_controls.offset_right = -16
	view_controls.offset_top = -188; view_controls.offset_bottom = -40
	view_controls.add_theme_constant_override("separation",8)
	var move_view: Button = EditorButton.make("Move view","move",func() -> void:
		editor_state.canvas.cancel_gesture(false)
		editor_state.canvas.navigation_override = not editor_state.canvas.navigation_override
		run_build_editor_tools(app))
	move_view.name = "EditorMoveView"
	move_view.toggle_mode = true
	EditorStyle.apply(move_view)
	move_view.tooltip_text = "Move the view without editing. Two fingers also pan and zoom."
	view_controls.add_child(move_view)
	var fit: Button = EditorButton.make("Fit view","fit",func() -> void:
		editor_state.canvas.cancel_gesture(false)
		editor_state.map_panel.hide()
		editor_state.canvas.fit())
	fit.name = "EditorFitView"
	view_controls.add_child(fit)
	var bottom = CenterContainer.new()
	editor_state.palette = bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 108; bottom.offset_right = -112; bottom.offset_top = -98; bottom.offset_bottom = -16
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",run_editor_box(app))
	bottom.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360,68)
	panel.add_child(scroll)
	editor_state.context = HBoxContainer.new()
	editor_state.context.add_theme_constant_override("separation",6)
	scroll.add_child(editor_state.context)
	editor_state.surface_toolbar = PanelContainer.new()
	editor_state.surface_toolbar.name = "SurfacePlacementToolbar"
	editor_state.surface_toolbar.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(editor_state.surface_toolbar)
	editor_state.surface_toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	editor_state.surface_toolbar.offset_left = -270
	editor_state.surface_toolbar.offset_right = 270
	editor_state.surface_toolbar.offset_top = 78
	editor_state.surface_toolbar.offset_bottom = 180
	editor_state.surface_toolbar.resized.connect(app._layout_editor_surface_toolbar)
	editor_state.surface_actions = HBoxContainer.new()
	editor_state.surface_actions.add_theme_constant_override("separation",8)
	editor_state.surface_toolbar.add_child(editor_state.surface_actions)
	editor_state.hint_active = false
	editor_state.status = MenuStyle.label("",17)
	editor_state.status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(editor_state.status)
	editor_state.status.name = "EditorFeedback"
	editor_state.status.position = Vector2(16,128)
	editor_state.status.size = Vector2(320,80)
	editor_state.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_state.status.add_theme_font_size_override("font_size",15)
	editor_state.status.add_theme_stylebox_override("normal",EditorStyle.panel())
	editor_state.status.hide()
	editor_state.save_button = EditorStyle.button("Draft",app._retry_editor_save)
	editor_state.save_button.name = "EditorSaveState"
	editor_state.save_button.position = Vector2(16,78)
	editor_state.save_button.custom_minimum_size = Vector2(260,48)
	overlay.add_child(editor_state.save_button)
	var save_label := Label.new()
	save_label.name = "EditorSaveLabel"
	save_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_label.position = Vector2(24,80)
	save_label.custom_minimum_size = Vector2(260,32)
	save_label.add_theme_font_override("font",EditorStyle.FONT)
	save_label.add_theme_font_size_override("font_size",15)
	save_label.add_theme_color_override("font_color",EditorStyle.INK)
	var save_style: StyleBoxFlat = EditorStyle.panel()
	save_style.border_width_top = 1
	save_style.shadow_size = 0
	save_label.add_theme_stylebox_override("normal",save_style)
	overlay.add_child(save_label)
	run_update_editor_save_state(app)
	editor_state.loading = PanelContainer.new()
	editor_state.loading.name = "EditorPreparation"
	editor_state.loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_state.loading.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(editor_state.loading)
	editor_state.loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	editor_state.loading.offset_left = -110; editor_state.loading.offset_right = 110
	editor_state.loading.offset_top = 198; editor_state.loading.offset_bottom = 240
	var preparing: Label = MenuStyle.label("Preparing track…",17)
	preparing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_state.loading.add_child(preparing)
	editor_state.object_browser = ObjectBrowser.new()
	editor_state.object_browser.visible = false
	for key: String in editor_state.object_browser_state: editor_state.object_browser.set(key,editor_state.object_browser_state[key])
	editor_state.object_browser.current = CreatorCatalog.jump_asset(editor_state.canvas.stamp_jump_profile,str(editor_state.document.theme)) if editor_state.canvas.stamp_kind == "jump" else editor_state.canvas.stamp_kind
	editor_state.object_browser.stamp_span = editor_state.canvas.stamp_span
	editor_state.object_browser.stamp_container_color = editor_state.canvas.stamp_container_color
	editor_state.object_browser.biome = str(editor_state.document.get("biome",editor_state.document.theme))
	overlay.add_child(editor_state.object_browser)
	editor_state.object_browser.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	editor_state.object_browser.offset_left = 108; editor_state.object_browser.offset_right = -112
	editor_state.object_browser.offset_top = -174; editor_state.object_browser.offset_bottom = -16
	editor_state.object_browser.hide()
	editor_state.object_browser.asset_chosen.connect(app._choose_object)
	editor_state.object_browser.mode_chosen.connect(app._object_placement)
	editor_state.object_browser.size_chosen.connect(func(value: float) -> void: editor_state.canvas.stamp_scale=value)
	editor_state.object_browser.span_chosen.connect(func(value: float) -> void: editor_state.canvas.stamp_span=value)
	editor_state.object_browser.container_color_chosen.connect(app._container_colour)
	editor_state.object_browser.rotation_requested.connect(app._object_rotation_dialog)
	editor_state.object_browser.rotation_chosen.connect(app._set_object_rotation)
	editor_state.object_controls_panel = PanelContainer.new()
	editor_state.object_controls_panel.name = "ObjectControlStrip"
	editor_state.object_controls_panel.add_theme_stylebox_override("panel",EditorStyle.panel())
	overlay.add_child(editor_state.object_controls_panel)
	editor_state.object_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	editor_state.object_controls_panel.offset_left = 108
	editor_state.object_controls_panel.offset_right = -112
	var property_scroll = ScrollContainer.new()
	property_scroll.name = "ObjectControlScroll"
	# Keep the strip's height stable when its controls exceed the available
	# width; the row still supports horizontal dragging just like the palette.
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	property_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_state.object_controls_panel.add_child(property_scroll)
	editor_state.object_controls = editor_state.object_browser.options
	editor_state.object_controls.reparent(property_scroll)
	editor_state.object_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_state.object_controls.edited.connect(app._edit_object_control)
	editor_state.object_controls.editing_changed.connect(app._object_property_editing)
	editor_state.object_controls.fit_requested.connect(func() -> void: run_fit_speed_bump(app))
	editor_state.object_browser.snap_step = editor_state.canvas.object_snap
	editor_state.object_browser.snap_chosen.connect(func(step: float) -> void: editor_state.canvas.object_snap = step)
	editor_state.object_browser.select_requested.connect(func() -> void:
		editor_state.canvas.cancel_gesture(); editor_state.canvas.mode="objects"; run_build_editor_tools(app))
	editor_state.object_browser.populate_requested.connect(app._open_object_population)
	editor_state.tools_panel = run_editor_panel(app,overlay,"EditorTools")
	editor_state.inspector = VBoxContainer.new()
	editor_state.tools_panel.add_child(editor_state.inspector)
	editor_state.map_panel = run_editor_panel(app,overlay,"EditorMap")
	editor_state.map_panel.anchor_bottom=0
	editor_state.map_panel.offset_bottom=82
	editor_state.map_panel.offset_left=-268
	var map_scroll := ScrollContainer.new()
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	editor_state.map_panel.add_child(map_scroll)
	var metadata = VBoxContainer.new()
	metadata.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(metadata)
	var fit_map: Callable = _layout_map_panel.bind(overlay,editor_state.map_panel,map_scroll,metadata)
	metadata.minimum_size_changed.connect(fit_map)
	overlay.resized.connect(fit_map)
	fit_map.call_deferred()
	var biome_label: Label = MenuStyle.label(GameText.message("Biome")+": "+GameText.message(TrackTheme.title(str(editor_state.document.theme))),16)
	biome_label.name = "EditorBiomeLabel"
	biome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metadata.add_child(biome_label)
	for entry: Array in [["New",app._new_document],["Load",app._load_track_dialog],["Save",app._save_track_explicit]]:
		var command: Button=EditorStyle.button(entry[0],entry[1])
		command.name=entry[0]+"Track"
		metadata.add_child(command)
	editor_state.share_button=EditorStyle.button("Share",app._share_dialog)
	metadata.add_child(editor_state.share_button)
	metadata.add_child(EditorStyle.button("Help",app._editor_help))
	var detail: CheckButton = CheckButton.new()
	detail.name = "EditorDetailedScenery"
	detail.text = "Detailed scenery"
	detail.button_pressed = not editor_state.world._detail.enabled
	detail.custom_minimum_size.y = 48
	detail.toggled.connect(func(enabled: bool) -> void:
		editor_state.world._detail.enabled = not enabled)
	metadata.add_child(detail)
	if str(editor_state.document.theme) == "night_city":
		var lighting: Button = EditorStyle.button("Race lighting",func() -> void: pass)
		lighting.name = "EditorRaceLighting"
		lighting.toggle_mode = true
		lighting.toggled.connect(editor_state.world.set_race_lighting_preview)
		metadata.add_child(lighting)
	LAYOUT.install(app,overlay)
	editor_state.canvas.selection_changed.connect(LAYOUT.selection_changed.bind(app))
	editor_state.canvas.fit_area = app._editor_fit_area
	editor_state.surface_toolbar.resized.connect(app._layout_editor_feedback)
	run_restore_pending_tool(app,run_editor_tool(app))
	run_build_editor_tools(app)
	run_refresh_editor(app)
	run_update_editor_save_state(app)
	# Reuse an exact completed preview if the worker is idle; otherwise let the
	# existing single worker prepare the newest document while controls render.
	var cached_preview: NativeTrack
	if editor_state.preview_thread == null:
		for entry: Dictionary in editor_state.compiled_cache:
			if entry.document == editor_state.document: cached_preview = entry.track; break
	if cached_preview != null: editor_state.canvas.show_native(cached_preview)
	else: run_queue_editor_preview(app)
	run_update_editor_issues(app)
	if editor_state.view.is_empty(): editor_state.canvas.call_deferred("fit")
	run_apply_editor_safe_area(app,overlay)
	app.root_ui.resized.connect(app._apply_editor_safe_area.bind(overlay))
	app.root_ui.resized.connect(app._layout_editor_feedback)
	app.root_ui.resized.connect(app._layout_editor_surface_toolbar)

func _layout_map_panel(overlay: Control, panel: PanelContainer, scroll: ScrollContainer, metadata: VBoxContainer) -> void:
	if not is_instance_valid(overlay) or not is_instance_valid(panel) or not is_instance_valid(scroll) or not is_instance_valid(metadata): return
	LAYOUT.fit_menu_panel(overlay,panel,scroll,metadata)

func run_fit_editor_header(app: Node, overlay: Control, header: HBoxContainer, track_title: Label, history_panel: PanelContainer, actions: HBoxContainer) -> void:
	LAYOUT.arrange(app)


func run_editor_box(app: Node) -> StyleBoxFlat:
	return EditorStyle.panel()


func run_layout_editor_surface_toolbar(app: Node) -> void:
	LAYOUT.arrange(app)


func run_layout_editor_feedback(app: Node) -> void:
	LAYOUT.arrange(app)


func run_editor_fit_area(app: Node) -> Rect2:
	var view: Rect2 = editor_state.canvas.get_global_rect()
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	var bar: Control = app.root_ui.find_child("EditorTopBar",true,false)
	if dock != null and bar != null:
		var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false)
		var left_edge: float = rail.get_global_rect().end.x+12
		return Rect2(Vector2(left_edge,bar.get_global_rect().end.y+12)-view.position,Vector2(maxf(40,dock.get_global_rect().end.x-left_edge),maxf(40,dock.get_global_rect().position.y-bar.get_global_rect().end.y-24)))
	return Rect2(Vector2(16,16),view.size-Vector2(32,32))


func run_editor_panel(app: Node, parent: Control, node_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = node_name
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -322; panel.offset_right = -16
	panel.offset_top = 82; panel.offset_bottom = -146
	panel.add_theme_stylebox_override("panel",run_editor_box(app))
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
	if not is_instance_valid(editor_state.status): return
	editor_state.status.text = message
	editor_state.status.show()
	editor_state.hint_active = true
	LAYOUT.arrange.call_deferred(app)
	editor_state.hint_generation += 1
	var generation: int = editor_state.hint_generation
	var label_id: int = editor_state.status.get_instance_id()
	app.get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if generation == editor_state.hint_generation and is_instance_valid(editor_state.status) and editor_state.status.get_instance_id() == label_id:
			editor_state.hint_active = false
			if editor_state.save_error == OK:
				editor_state.status.text = editor_state.guidance
				editor_state.status.visible = not editor_state.guidance.is_empty()
			LAYOUT.arrange.call_deferred(app))

func run_update_editor_save_state(app: Node) -> void:
	if not is_instance_valid(editor_state.save_button): return
	editor_state.save_button.visible = editor_state.save_error != OK
	if editor_state.save_error != OK:
		editor_state.save_button.text = "Save failed · Retry"
		editor_state.save_button.disabled = false
		editor_state.save_button.tooltip_text = editor_state.save_message
		editor_state.save_button.add_theme_color_override("font_color",Color("ffbc8b"))
		if is_instance_valid(editor_state.status):
			editor_state.status.text = editor_state.save_message
			editor_state.status.show()
	elif editor_state.session.commits.unsettled() or editor_state.writes.unsettled(self.storage,str(editor_state.document.get("id",""))):
		editor_state.save_button.text = "Saving..."
		editor_state.save_button.disabled = true
		editor_state.save_button.tooltip_text = "Saving changes on this device."
	elif run_has_pending_editor_work(app):
		editor_state.save_button.text = "Preview pending"
		editor_state.save_button.disabled = true
		editor_state.save_button.tooltip_text = "Switching tools retains previews. Save confirms valid previews; Discard cancels them."
	elif not editor_state.saved_snapshot.is_empty() and editor_state.document == editor_state.saved_snapshot:
		editor_state.save_button.text = "Saved on device"
		editor_state.save_button.disabled = true
		editor_state.save_button.tooltip_text = "The saved original matches this document."
	else:
		editor_state.save_button.text = "Autosaved draft" if (editor_state.wip_store == self.storage and editor_state.document == editor_state.wip_snapshot) else "Unsaved draft"
		editor_state.save_button.disabled = true
		editor_state.save_button.tooltip_text = "Your draft is kept separately. Save updates the named track."
	var label: Label = app.root_ui.find_child("EditorSaveLabel",true,false) as Label
	if label != null:
		label.text = editor_state.save_button.text
		label.tooltip_text = editor_state.save_button.tooltip_text
		label.visible = editor_state.save_error == OK
	LAYOUT.arrange.call_deferred(app)
	# Availability is derived here as well as after commits: previews do not
	# create a document revision, but must still be cancellable with Undo.
	if is_instance_valid(editor_state.undo):
		editor_state.undo.disabled = editor_state.session.undo.is_empty() and not run_has_pending_editor_work(app) and (not is_instance_valid(editor_state.canvas) or editor_state.canvas.active_pointer == -99)
	if is_instance_valid(editor_state.redo): editor_state.redo.disabled = editor_state.session.redo.is_empty()

func run_retry_editor_save(app: Node) -> void:
	if editor_state.retry_original: run_save_track_now(app)
	else: run_save_draft(app,true)

func run_editor_tool(app: Node) -> String:
	if not is_instance_valid(editor_state.canvas): return "road"
	if editor_state.canvas.mode in ["paint","pan"] or (editor_state.canvas.mode == "place" and editor_state.canvas.stamp_kind in ["puddle","water","dirt"]): return "paint"
	return "objects" if editor_state.canvas.mode in ["objects","place","run"] else "road"

func run_capture_pending_tool(app: Node) -> Dictionary:
	var state: Dictionary = {"mode":editor_state.canvas.mode}
	var keys: Array = {"road":["ghost","piece_kind","snap_matched"],"paint":["paint_points","paint_mode","brush_surface","brush_width","brush_shape","protect_road","stamp_kind","stamp_scale"],"objects":["run_start","run_preview","run_draw","run_shape","free_run","stamp_kind","stamp_scale","stamp_span","stamp_length","stamp_jump_profile","stamp_rotation","stamp_container_color"]}[run_editor_tool(app)]
	for key: String in keys:
		var value: Variant = editor_state.canvas.get(key)
		state[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return state

func run_stash_pending_tool(app: Node) -> void:
	if is_instance_valid(editor_state.canvas): editor_state.pending_tools[run_editor_tool(app)] = run_capture_pending_tool(app)

func run_restore_pending_tool(app: Node, tool: String) -> void:
	editor_state.canvas.ghost = {}
	editor_state.canvas.paint_points = []
	editor_state.canvas.run_start = Vector2.INF
	editor_state.canvas.run_preview = []
	editor_state.canvas.run_draw = PackedVector2Array()
	editor_state.canvas.mode = tool
	for key: String in editor_state.pending_tools.get(tool,{}): editor_state.canvas.set(key,editor_state.pending_tools[tool][key])

func run_pending_state_has_work(app: Node, tool: String, state: Dictionary) -> bool:
	if tool == "road": return not state.get("ghost",{}).is_empty()
	if tool == "paint": return not state.get("paint_points",[]).is_empty()
	return state.get("run_start",Vector2.INF) != Vector2.INF or not state.get("run_preview",[]).is_empty() or state.get("run_draw",PackedVector2Array()).size() > 1

func run_has_pending_editor_work(app: Node) -> bool:
	var active: String = run_editor_tool(app)
	for tool: String in ["road","paint","objects"]:
		var state: Dictionary = run_capture_pending_tool(app) if is_instance_valid(editor_state.canvas) and active == tool else editor_state.pending_tools.get(tool,{})
		if run_pending_state_has_work(app,tool,state): return true
	return false

func run_discard_editor_previews(app: Node) -> void:
	editor_state.pending_tools.clear()
	if not is_instance_valid(editor_state.canvas): return
	editor_state.canvas.changed_in_gesture = false
	editor_state.canvas.cancel_gesture()
	run_restore_pending_tool(app,run_editor_tool(app))
	editor_state.canvas.queue_redraw()

func run_commit_editor_previews(app: Node) -> bool:
	run_stash_pending_tool(app)
	var active: String = run_editor_tool(app)
	for tool: String in ["road","paint","objects"]:
		if not run_pending_state_has_work(app,tool,editor_state.pending_tools.get(tool,{})): continue
		editor_state.canvas.changed_in_gesture = false
		editor_state.canvas.cancel_gesture()
		run_restore_pending_tool(app,tool)
		if tool == "road": editor_state.canvas.confirm_piece()
		elif tool == "paint": editor_state.canvas.confirm_paint()
		elif editor_state.canvas.run_preview.is_empty():
			run_editor_hint(app,"Finish the object run, or cancel it before saving.")
		else:
			var additions: Array = preload("res://editor/creator_limits.gd").take(editor_state.document.objects,editor_state.canvas.run_preview,str(editor_state.document.theme))
			if not editor_state.canvas.admit("objects",editor_state.document.objects+additions): return false
			run_remember(app)
			editor_state.document.objects.append_array(additions)
			editor_state.canvas.run_preview.clear(); editor_state.canvas.run_draw.clear(); editor_state.canvas.run_start = Vector2.INF
			run_save_draft(app,true)
		run_stash_pending_tool(app)
		if run_pending_state_has_work(app,tool,editor_state.pending_tools[tool]):
			run_build_editor_tools(app)
			notice_requested.emit("Complete or cancel this preview before saving. Your pending work is retained.")
			return false
	run_restore_pending_tool(app,active)
	run_build_editor_tools(app)
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
		if run_commit_editor_previews(app): after.call()
		dialog.queue_free())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			dialog.hide()
			run_discard_editor_previews(app)
			dialog.queue_free()
			after.call())
	dialog.canceled.connect(dialog.queue_free)
	app.root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(510,200))

func run_editor_category(app: Node, value: String) -> void:
	var previous: String = run_editor_tool(app)
	if value == "objects" and previous == "objects":
		LAYOUT.set_picker(app,true)
		return
	editor_state.canvas.cancel_gesture(false)
	editor_state.canvas.navigation_override = false
	run_stash_pending_tool(app)
	run_restore_pending_tool(app,value)
	editor_state.canvas.selected_piece = -1
	editor_state.canvas.selected_object = -1
	editor_state.canvas.selected = -1
	editor_state.geometry = ""
	editor_state.tools_panel.hide()
	editor_state.map_panel.hide()
	if value == "objects": LAYOUT.set_picker(app,true,false)
	run_build_editor_tools(app)
	editor_state.canvas.queue_redraw()

func run_context_button(app: Node, label: String, glyph: String, action: Callable, chosen: bool = false) -> Button:
	var button: Button = EditorButton.make(label,glyph,action,chosen)
	EditorStyle.card(button,chosen)
	editor_state.context.add_child(button)
	return button

func run_build_editor_tools(app: Node) -> void:
	var active_hint: String = editor_state.status.text if editor_state.hint_active and is_instance_valid(editor_state.status) else ""
	if not is_instance_valid(editor_state.context) or not is_instance_valid(editor_state.canvas): return
	run_update_test_access(app)
	run_update_editor_save_state(app)
	editor_state.canvas.road_action = editor_state.geometry if editor_state.geometry != "" else "move"
	for child: Node in editor_state.context.get_children():
		editor_state.context.remove_child(child)
		child.queue_free()
	for child: Node in editor_state.inspector.get_children():
		editor_state.inspector.remove_child(child)
		child.queue_free()
	var category: String = "objects" if editor_state.canvas.mode in ["objects","place","run"]  else "paint" if editor_state.canvas.mode in ["paint","pan"] else "road"
	if editor_state.canvas.mode == "place" and editor_state.canvas.stamp_kind in ["puddle","water","dirt"]: category="paint"
	var biome: String = str(editor_state.document.get("biome",editor_state.document.theme))
	if editor_state.object_browser.biome!=biome:
		editor_state.object_browser.biome=biome
		editor_state.object_browser.refresh()
	var browsing: bool = category=="objects" and not (editor_state.canvas.selected_object>=0 and editor_state.canvas.mode=="objects")
	editor_state.object_browser.visible = browsing
	editor_state.object_browser.set_stamp_rotation(editor_state.canvas.stamp_rotation)
	editor_state.palette.visible = not browsing
	for key: String in editor_state.mode_buttons: (editor_state.mode_buttons[key] as Button).set_pressed_no_signal(key == category)
	editor_state.surface_toolbar.visible = category == "paint"
	if category == "paint":
		if editor_state.canvas.brush_surface == 0: editor_state.canvas.brush_surface = 2
		run_build_surface_toolbar(app)
	if category == "road":
		var piece: Dictionary = editor_state.canvas.ghost if not editor_state.canvas.ghost.is_empty() else editor_state.document.pieces[editor_state.canvas.selected_piece] if editor_state.canvas.selected_piece >= 0 else {}
		if piece.is_empty():
			var start_action: Button = run_context_button(app,"Start line","race",editor_state.canvas.choose_start_line)
			start_action.disabled = editor_state.document.pieces.is_empty() and editor_state.document.layout.is_empty() and editor_state.document.base_track == "" and editor_state.document.paint.is_empty()
			for kind: String in RoadPieces.KINDS:
				run_context_button(app,preload("res://editor/road_piece_catalog.gd").title(kind),kind,editor_state.canvas.choose_piece.bind(kind))
			if editor_state.document.pieces.is_empty():
				editor_state.status.text = "Choose Straight or Curve to begin. Two fingers move the view."
			elif editor_state.canvas.prepared_joins().is_empty() and RoadPieces.connected_route(editor_state.document.pieces).ok:
				editor_state.status.text = "Road loop connected. Place the start line, then Test." if not editor_state.document.has("start_line") else "Road loop connected. Test your track, or keep building."
			else:
				editor_state.status.text = "Add sections to join the open ends. You can Test at any time."
		elif editor_state.geometry != "" and piece.kind == "bridge":
			run_context_button(app,"Back","back",func() -> void:
				editor_state.geometry = ""
				run_build_editor_tools(app))
			var key: String = "radius" if piece.kind == "s_bend" and editor_state.geometry == "length" else editor_state.geometry
			run_context_button(app,"- 5 deg" if key == "angle" else "- 1 m","minus",app._change_piece.bind(key,-5.0 if key == "angle" else -1.0))
			run_context_button(app,("Straight length" if key == "length" and piece.kind == "hairpin" else "Lead-in" if key == "length" and piece.kind not in ["straight","bridge"] else key.capitalize())+(" %.0f deg" if key == "angle" else " %.1f m") % (RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0))),"width",func() -> void: pass)
			run_context_button(app,"+ 5 deg" if key == "angle" else "+ 1 m","plus",app._change_piece.bind(key,5.0 if key == "angle" else 1.0))
			if key != "width" and piece.kind == "hairpin": run_context_button(app,"Radius" if key == "length" else "Straight length" if piece.kind == "hairpin" else "Lead-in","curve",func() -> void:
				editor_state.geometry = "radius" if key == "length" else "length"
				run_build_editor_tools(app))
			if piece.kind == "s_bend" and key != "height": run_context_button(app,"Height","width",func() -> void:
				editor_state.geometry = "height"
				run_build_editor_tools(app))
			if piece.kind == "curve" and key != "angle": run_context_button(app,"Angle","curve",func() -> void:
				editor_state.geometry = "angle"
				run_build_editor_tools(app))
			editor_state.status.text = "Both straight arms change equally; 0 m makes a plain U-turn. Radius stays separate." if piece.kind == "hairpin" and key == "length" else "Only this section changes. Reconnect any open ends afterwards."
		else:
			if piece.kind == "spline":
				run_context_button(app,GameText.message("Point %d/5") % (editor_state.canvas.spline_point+1),"spline",func() -> void:
					editor_state.canvas.spline_point = (editor_state.canvas.spline_point+1)%5
					run_build_editor_tools(app))
				run_context_button(app,"Width −","minus",app._change_piece.bind("point_width",-0.5))
				run_context_button(app,GameText.message("%.1f m") % float(piece.point_widths[editor_state.canvas.spline_point]),"width",func() -> void: pass)
				run_context_button(app,"Width +","plus",app._change_piece.bind("point_width",0.5))
			if piece.kind == "bridge":
				run_context_button(app,"Shape",piece.kind,func() -> void:
					editor_state.geometry = "length" if piece.kind in ["straight","bridge"] else "radius"
					run_build_editor_tools(app))
				if piece.kind == "hairpin": run_context_button(app,"Straight length","straight",func() -> void:
					editor_state.geometry = "length"
					run_build_editor_tools(app))
				run_context_button(app,"Width","width",func() -> void:
					editor_state.geometry = "width"
					run_build_editor_tools(app))
				run_context_button(app,"Rotate","rotate",app._change_piece.bind("heading",15.0))
			run_context_button(app,"Flip","flip",app._change_piece.bind("flip",1.0))
			if editor_state.document.theme in ["pine","storm"]:
				for surface: String in ["asphalt","gravel"]:
					var material_button: Button = run_context_button(app,surface.capitalize(),"terrain_road" if surface == "asphalt" else "terrain_dirt",app._set_piece_material.bind(surface),RoadPieces.material(piece,editor_state.document) == surface)
					material_button.name = "RoadMaterial_"+surface
					material_button.tooltip_text = "Road material for this section"
			run_context_button(app,"Snap on" if editor_state.canvas.snap_enabled else "Snap off","snap",func() -> void:
				editor_state.canvas.snap_enabled = not editor_state.canvas.snap_enabled
				editor_state.canvas.snap_matched = false
				run_build_editor_tools(app),editor_state.canvas.snap_enabled)
			run_context_button(app,"Cancel" if not editor_state.canvas.ghost.is_empty() else "Delete","delete",app._delete_piece)
			if editor_state.canvas.ghost.is_empty():
				run_context_button(app,"Connect","snap",editor_state.canvas.connect_nearby)
				run_context_button(app,"Layer","surface",editor_state.canvas.cycle_piece)
			editor_state.status.text = "Drag inside to move · end dots resize and turn · ✓ to place" if not editor_state.canvas.ghost.is_empty() else "Drag inside to move · drag end dots to reshape · Layer selects overlapping roads"
			if piece.kind == "bridge": editor_state.status.text = "Bridge: ramps at both ends · ground road passes beneath the middle"
			if piece.kind == "spline": editor_state.status.text = "Drag the five numbered points · select a point to set its width · ✓ to place"
	elif category == "paint":
		for pair: Array in [[1,"Grass"],[2,"Sand"],[3,"Water"]]:
			var surface_button: Button = run_context_button(app,preload("res://editor/surface_labels.gd").title(pair[0],biome),preload("res://editor/surface_labels.gd").glyph(pair[0],biome),func() -> void:
				editor_state.canvas.navigation_override = false
				editor_state.canvas.brush_surface = pair[0]
				editor_state.canvas.mode = "paint"
				run_build_editor_tools(app),editor_state.canvas.mode == "paint" and editor_state.canvas.brush_surface == pair[0])
			(surface_button as EditorButton).surface_tint = TrackTheme.palette(biome)[pair[0]]
		run_context_button(app,"Puddle","terrain_puddle",app._choose_hazard.bind("puddle"))
		run_build_paint_tools(app)
		editor_state.status.text = "Choose a paint mode to continue." if editor_state.canvas.mode == "pan" else "Drag to paint freely" if editor_state.canvas.paint_mode == "free" else "Tap to add points / drag dots to reshape / confirm to place"
	elif category == "objects":
		if editor_state.canvas.selected_object >= 0 and editor_state.canvas.mode == "objects":
			editor_state.status.text=CreatorObjects.description(editor_state.document.objects[editor_state.canvas.selected_object].kind)
			if editor_state.canvas.object_indices().size() > 1:
				editor_state.status.text = GameText.message("%d objects selected ? drag one to move the group") % editor_state.canvas.object_indices().size()
			if editor_state.canvas.multi_select and editor_state.canvas.object_indices().size() == 1: editor_state.status.text = "Multi-select: tap to add or remove; drag to move."
			run_context_button(app,"Copy","copy",app._duplicate_object)
			var multiple: Button = run_context_button(app,"Multi-select","multi_select",editor_state.canvas.toggle_multi_select,editor_state.canvas.multi_select)
			multiple.name = "MultiSelectObjects"
			run_context_button(app,"Next object","cycle_objects",editor_state.canvas.cycle_objects)
			run_context_button(app,"Delete","delete",app._delete_selection)
			if editor_state.canvas.issue_marker != Vector2.INF: run_context_button(app,"Move start","race",editor_state.canvas.choose_start_line)
			run_context_button(app,"Palette","more",func() -> void:
				editor_state.canvas.multi_select = false
				editor_state.canvas.selected_object = -1
				run_build_editor_tools(app))
		else:
			var stamp_label: String = CreatorCatalog.label(CreatorCatalog.jump_asset(editor_state.canvas.stamp_jump_profile,str(editor_state.document.theme))) if editor_state.canvas.stamp_kind == "jump" else CreatorCatalog.label(editor_state.canvas.stamp_kind)
			editor_state.status.text = GameText.message(stamp_label)+" / "+GameText.message(("Drag a curve; release to place" if editor_state.canvas.run_shape=="curve" else "Drag a line, or tap its two ends") if editor_state.canvas.mode=="run" else "Tap empty ground to place one object.")
			if editor_state.canvas.mode=="objects": editor_state.status.text="Tap an object to move, rotate or delete"
	run_build_object_controls(app,category == "objects",browsing)
	var move_view: Button = app.root_ui.find_child("EditorMoveView",true,false) as Button
	if move_view != null: move_view.set_pressed_no_signal(editor_state.canvas.navigation_override)
	if editor_state.canvas.navigation_override: editor_state.status.text = "Move view: drag to pan. Tap Move view again to keep editing."
	editor_state.guidance = editor_state.status.text
	if editor_state.hint_active: editor_state.status.text = active_hint
	editor_state.status.show()
	run_layout_editor_feedback(app)

	var context_width: float = 0
	for child: Control in editor_state.context.get_children(): context_width += child.get_combined_minimum_size().x+6
	(editor_state.context.get_parent() as ScrollContainer).custom_minimum_size.x = clampf(context_width,320,maxf(320,editor_state.canvas.size.x-260))
	run_update_editor_save_state(app)
	editor_state.canvas.refresh()
	LAYOUT.refresh(app,category)

func run_set_piece_material(app: Node, surface: String) -> void:
	if not is_instance_valid(editor_state.canvas) or editor_state.document.theme not in ["pine","storm"] or surface not in ["asphalt","gravel"]: return
	var is_ghost: bool = not editor_state.canvas.ghost.is_empty()
	if not is_ghost and (editor_state.canvas.selected_piece < 0 or editor_state.canvas.selected_piece >= editor_state.document.pieces.size()): return
	var piece: Dictionary = (editor_state.canvas.ghost if is_ghost else editor_state.document.pieces[editor_state.canvas.selected_piece]).duplicate(true)
	if RoadPieces.material(piece,editor_state.document) == surface:
		run_build_editor_tools(app)
		return
	piece.surface = surface
	if is_ghost: editor_state.canvas.ghost = piece
	else:
		run_remember(app)
		editor_state.document.pieces[editor_state.canvas.selected_piece] = piece
		run_save_draft(app,true)
	run_build_editor_tools(app)

func run_change_piece(app: Node, key: String, delta: float) -> void:
	var is_ghost: bool = not editor_state.canvas.ghost.is_empty()
	if not is_ghost and editor_state.canvas.selected_piece < 0: return
	var piece: Dictionary = (editor_state.canvas.ghost if is_ghost else editor_state.document.pieces[editor_state.canvas.selected_piece]).duplicate(true)
	var before: Dictionary = piece.duplicate(true)
	if piece.kind == "s_bend" and key == "length": return
	if key == "point_width" and piece.kind == "spline": piece = SplineRoad.with_width(piece,editor_state.canvas.spline_point,float(piece.point_widths[editor_state.canvas.spline_point])+delta)
	elif key == "flip": piece.flip = not piece.flip
	elif key == "heading": piece.heading = fposmod(float(piece.heading)+delta,360.0)
	else:
		var lower: float = 5.0 if key == "angle" else 6.0 if key == "width" else 2.0 if key == "height" else 3.0 if key == "radius" else 24.0 if piece.kind == "bridge" else 2.0 if piece.kind == "straight" else 0.0
		var upper: float = 270.0 if key == "angle" else 20.0 if key == "width" else 60.0 if key in ["radius","height"] else 120.0
		piece[key] = clampf((RoadPieces.height(piece) if key == "height" else float(piece.get(key,90.0)))+delta,lower,upper)
	piece = editor_state.canvas.anchored_change(before,piece,key)
	var errors: Array[String] = RoadPieces.validate(piece)
	if not errors.is_empty():
		run_editor_hint(app,errors[0])
		return
	if not editor_state.canvas._valid_bridge_edit(piece,editor_state.canvas.selected_piece): return
	if is_ghost:
		editor_state.canvas.ghost = piece
		editor_state.canvas.snap_matched = false
	else:
		var proposed: Array = editor_state.document.pieces.duplicate()
		proposed[editor_state.canvas.selected_piece] = piece
		if not editor_state.canvas.admit("pieces",proposed): return
		run_remember(app)
		editor_state.document.pieces[editor_state.canvas.selected_piece] = piece
		run_save_draft(app,true)
	run_build_editor_tools(app)

func run_delete_piece(app: Node) -> void:
	if not editor_state.canvas.ghost.is_empty(): editor_state.canvas.ghost.clear()
	elif editor_state.canvas.selected_piece >= 0:
		run_remember(app)
		editor_state.document.pieces.remove_at(editor_state.canvas.selected_piece)
		editor_state.canvas.selected_piece = -1
		run_save_draft(app,true)
	editor_state.geometry = ""
	run_build_editor_tools(app)

func run_practice_start(app: Node, track: NativeTrack) -> Vector2:
	if editor_state.document.has("start_line"): return Vector2(editor_state.document.start_line.position[0],editor_state.document.start_line.position[1])
	if editor_state.document.has("practice_start"): return Vector2(editor_state.document.practice_start.position[0],editor_state.document.practice_start.position[1])
	if editor_state.document.pieces.is_empty(): return track.spawn
	var samples: PackedVector2Array = RoadPieces.samples(editor_state.document.pieces[0])
	return samples[mini(6,samples.size()-1)]

func run_practice_heading(app: Node, track: NativeTrack) -> float:
	if editor_state.document.has("start_line"): return PI*0.5-deg_to_rad(float(editor_state.document.start_line.heading))
	if editor_state.document.has("practice_start"): return PI*0.5-deg_to_rad(float(editor_state.document.practice_start.heading))
	if editor_state.document.pieces.is_empty(): return track.spawn_heading
	var samples: PackedVector2Array = RoadPieces.samples(editor_state.document.pieces[0])
	var index: int = mini(6,samples.size()-1)
	var tangent: Vector2 = samples[mini(index+1,samples.size()-1)]-samples[maxi(0,index-1)]
	return atan2(tangent.x,tangent.y)

func run_update_editor_issues(app: Node) -> void:
	if not is_instance_valid(editor_state.canvas) or not is_instance_valid(editor_state.issue_button): return
	var previous: Dictionary = editor_state.issues[editor_state.issue_cursor] if editor_state.issue_cursor >= 0 and editor_state.issue_cursor < editor_state.issues.size() else {}
	editor_state.issues.clear()
	editor_state.canvas.issue_marker = Vector2.INF
	var track: NativeTrack = editor_state.canvas.native_preview
	if track != null:
		var start: Vector2 = run_practice_start(app,track)
		var config: HandlingConfig = HandlingSelection.config()
		var radius: float = config.collision_radius
		var elevated: bool = track.collision_elevated_at(start,track.nearest_route(start),radius)
		if track.overlaps_obstacle(start,radius,elevated):
			for i: int in range(editor_state.document.objects.size()):
				var object: Dictionary = editor_state.document.objects[i]
				if CreatorObjects.surface(object.kind) not in [3,4]: continue
				var local: Vector2 = (start-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
				var half: Vector2 = CreatorObjects.size_of(object)*0.5
				if local.distance_to(local.clamp(-half,half)) <= radius+track.cell_size*0.71:
					editor_state.issues.append({"message":GameText.message("%s blocks the start") % str(object.kind).capitalize(),"position":start,"object":i})
			if editor_state.issues.is_empty(): editor_state.issues.append({"message":"Obstacle overlaps the starting car","position":start,"object":-2})
	for join: Dictionary in RoadPieces.joins(editor_state.document.pieces):
		editor_state.issues.append({"message":join.message,"position":join.position,"object":-1,"index":join.index,"endpoint":join.endpoint})
	editor_state.issue_cursor = editor_state.issues.find(previous)
	editor_state.issue_button.text = GameText.message("Issue %d/%d") % [editor_state.issue_cursor+1,editor_state.issues.size()] if editor_state.issue_cursor >= 0 else GameText.plural("{count} issue","{count} issues",editor_state.issues.size())
	editor_state.issue_button.tooltip_text = "Tap to focus the next issue."
	editor_state.issue_button.visible = not editor_state.issues.is_empty()
	run_update_test_access(app)
	editor_state.canvas.queue_redraw()

func run_update_test_access(app: Node) -> void:
	if not is_instance_valid(editor_state.test_button) or not is_instance_valid(editor_state.canvas): return
	var has_road: bool = not editor_state.document.pieces.is_empty() or not editor_state.document.layout.is_empty() or not editor_state.document.paint.is_empty() or editor_state.document.base_track != ""
	editor_state.test_button.disabled = editor_state.session.commits.unsettled() or editor_state.preview_thread != null or not (editor_state.session.errors if editor_state.document == editor_state.session.validated else TrackDocument.validate(editor_state.document)).is_empty() or not has_road or run_has_pending_editor_work(app)
	for issue: Dictionary in editor_state.issues:
		if int(issue.object) != -1: editor_state.test_button.disabled = true

func run_focus_issue(app: Node) -> void:
	if editor_state.issues.is_empty(): return
	if run_has_pending_editor_work(app):
		run_resolve_editor_previews(app,app._focus_issue)
		return
	editor_state.issue_cursor = (editor_state.issue_cursor+1)%editor_state.issues.size()
	var issue: Dictionary = editor_state.issues[editor_state.issue_cursor]
	run_editor_category(app,"objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road")
	editor_state.canvas.mode = "objects" if int(issue.object) >= 0 else "paint" if int(issue.object) == -2 else "road"
	editor_state.canvas.issue_marker = issue.position
	editor_state.canvas.issue_text = issue.message
	editor_state.canvas.pan += editor_state.canvas.size*0.5-editor_state.canvas.to_screen(issue.position)
	if int(issue.object) >= 0: editor_state.canvas.selected_object = issue.object
	elif int(issue.object) == -1: editor_state.canvas.selected_piece = issue.index
	run_build_editor_tools(app)
	editor_state.issue_button.text = GameText.message("Issue %d/%d") % [editor_state.issue_cursor+1,editor_state.issues.size()]
	run_editor_hint(app,issue.message+" · paint Road over the obstacle, or place a Start line." if int(issue.object) == -2 else issue.message+" · drag to repair, or delete the selection.")
	editor_state.canvas.refresh()

func run_commit_selection(app: Node) -> void:
	var error: String = preload("res://editor/authoring_admission.gd").error(editor_state.document)
	if not error.is_empty():
		if not editor_state.session.undo.is_empty():
			editor_state.document = preload("res://editor/editor_history.gd").restore(editor_state.session.undo.pop_back())
			run_restore_editor_history(app)
		run_editor_hint(app,error)
		return
	if editor_state.canvas.mode in ["move","add"]: editor_state.document.route_override = true
	editor_state.canvas.refresh()
	run_save_draft(app,true)
	run_build_editor_tools(app)

func run_delete_selection(app: Node) -> void:
	if editor_state.canvas.mode in ["objects","place","run"]:
		if editor_state.canvas.selected_object < 0: return
		run_remember(app)
		var indices: Array[int] = editor_state.canvas.object_indices()
		indices.reverse()
		for index: int in indices: editor_state.document.objects.remove_at(index)
		editor_state.canvas.selected_object = -1
	else: return
	run_commit_selection(app)

func run_rotate_object(app: Node) -> void:
	run_set_object_rotation(app,preload("res://editor/object_rotation.gd").next_angle(run_object_rotation(app)))

func run_object_property_editing(app: Node, property: String) -> void:
	editor_state.object_property = property
	run_build_editor_tools(app)

func run_build_object_controls(app: Node, active: bool, browsing: bool) -> void:
	if not is_instance_valid(editor_state.object_controls): return
	editor_state.object_controls_panel.visible = active
	editor_state.object_controls.visible = active
	if not active: return
	var selected: bool = editor_state.canvas.mode == "objects" and editor_state.canvas.selected_object >= 0 and editor_state.canvas.selected_object < editor_state.document.objects.size()
	var state: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object].duplicate(true) if selected else {"kind":editor_state.canvas.stamp_kind,"scale":editor_state.canvas.stamp_scale,"rotation":editor_state.canvas.stamp_rotation,"span":editor_state.canvas.stamp_span,"placement":editor_state.object_browser.placement,"color":editor_state.canvas.stamp_container_color}
	state["multiple"] = selected and editor_state.canvas.object_indices().size() > 1
	state["mode"] = editor_state.canvas.mode
	if not selected and editor_state.canvas.stamp_length > 0: state["length"] = editor_state.canvas.stamp_length
	if selected: state["span"] = CreatorObjects.size_of(state).y
	if state.kind == "jump": state["jump_profile"] = JumpProfiles.id(state) if selected else editor_state.canvas.stamp_jump_profile
	var target: String = str(editor_state.document.id)+"/"+str(editor_state.canvas.selected_object if selected else -1)+"/"+str(state.kind)+"/"+str(state.multiple)
	if target != editor_state._object_controls_target:
		editor_state.object_property = ""
		editor_state._object_controls_target = target
	editor_state.object_controls.show_state(state,selected,editor_state.object_property)
	editor_state.object_browser.rotation_button = editor_state.object_controls.find_child("ObjectOrientation",true,false) as Button
	if editor_state.object_property == "scale": editor_state.status.text = GameText.message("Size")+" / "+editor_state.object_controls._dimensions()
	elif editor_state.object_property == "rotation": editor_state.status.text = "Use - / + or type an angle. Back returns to object controls."
	elif editor_state.object_property == "span": editor_state.status.text = "Set the width here, or drag the speed bump end dots."

func run_edit_object_control(app: Node, property: String, value: Variant) -> void:
	if not is_instance_valid(editor_state.canvas) or app.screen != "create" or editor_state.canvas.mode not in ["objects","place","run"]: return
	var selected: bool = editor_state.canvas.mode == "objects" and editor_state.canvas.selected_object >= 0
	match property:
		"mode":
			if (value == "objects" and editor_state.canvas.mode == "objects") or (value == "place" and editor_state.canvas.mode in ["place","run"]):
				run_build_editor_tools(app)
				return
			if value == "place" and selected:
				var source: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object]
				editor_state.canvas.stamp_kind = str(source.kind)
				editor_state.canvas.stamp_scale = float(source.get("scale",1.0))
				editor_state.canvas.stamp_rotation = float(source.rotation)
				editor_state.canvas.stamp_length = float(source.get("length",0.0))
				editor_state.canvas.stamp_span = float(source.get("span",CreatorObjects.dimensions("speed_bump").y)) if source.kind == "speed_bump" else editor_state.canvas.stamp_span
				editor_state.canvas.stamp_container_color = str(source.get("color",ContainerPaint.DEFAULT)) if source.kind == "container" else editor_state.canvas.stamp_container_color
				if source.kind == "jump": editor_state.canvas.stamp_jump_profile = JumpProfiles.id(source)
				editor_state.object_browser.current = CreatorCatalog.jump_asset(editor_state.canvas.stamp_jump_profile,str(editor_state.document.theme)) if source.kind == "jump" else str(source.kind)
				editor_state.object_browser.placement = "single"
				editor_state.object_browser.stamp_scale = editor_state.canvas.stamp_scale
				editor_state.object_browser.stamp_container_color = editor_state.canvas.stamp_container_color
			editor_state.canvas.cancel_gesture(false)
			editor_state.canvas.multi_select = false
			editor_state.canvas.selected_object = -1
			editor_state.canvas.mode = "objects" if value == "objects" else "place" if editor_state.object_browser.placement == "single" else "run"
			editor_state.object_property = ""
			LAYOUT.set_picker(app,false,false)
			run_build_editor_tools(app)
			return
		"kind": editor_state.object_browser.choose(str(value)); return
		"placement": run_object_placement(app,str(value)); return
		"rotation": run_set_object_rotation(app,float(value)); return
		"scale":
			if selected: run_scale_object(app,float(value)-float(editor_state.document.objects[editor_state.canvas.selected_object].get("scale",1.0))); return
			editor_state.canvas.stamp_scale = float(value)
			editor_state.object_browser.stamp_scale = float(value)
		"span":
			if selected: run_resize_speed_bump(app,float(value)-CreatorObjects.size_of(editor_state.document.objects[editor_state.canvas.selected_object]).y); return
			editor_state.canvas.stamp_span = float(value)
			editor_state.object_browser.stamp_span = float(value)
		"color": run_container_colour(app,str(value)); return
	run_build_editor_tools(app)

func run_object_rotation(app: Node) -> float:
	return float(editor_state.document.objects[editor_state.canvas.selected_object].rotation) if editor_state.canvas.mode == "objects" and editor_state.canvas.selected_object >= 0 else editor_state.canvas.stamp_rotation

func run_set_object_rotation(app: Node, value: float) -> void:
	if not is_finite(value): return
	var angle: float = fposmod(value,360.0)
	if editor_state.canvas.mode == "objects" and editor_state.canvas.selected_object >= 0 and not is_equal_approx(float(editor_state.document.objects[editor_state.canvas.selected_object].rotation),angle):
		var proposed: Array = preload("res://editor/object_editing.gd").rotated(editor_state.document.objects,editor_state.canvas.object_indices(),angle-float(editor_state.document.objects[editor_state.canvas.selected_object].rotation))
		if proposed.is_empty(): run_editor_hint(app,"Keep the whole selection inside the map."); return
		if not editor_state.canvas.admit("objects",proposed): return
		run_remember(app)
		editor_state.document.objects = proposed
		run_commit_selection(app)
	else:
		if editor_state.canvas.mode != "objects" or editor_state.canvas.selected_object < 0: editor_state.canvas.stamp_rotation = angle
		run_build_editor_tools(app)
	editor_state.object_browser.set_stamp_rotation(angle)

func run_object_rotation_dialog(app: Node) -> void:
	if app.root_ui.find_child("ObjectRotationDialog",true,false) != null: return
	if is_instance_valid(editor_state.object_browser.options): editor_state.object_browser.options.hide()
	editor_state.canvas.cancel_gesture()
	var dialog = preload("res://editor/object_rotation.gd").new()
	dialog.angle = run_object_rotation(app)
	var owner_canvas: EditorCanvas = editor_state.canvas
	var source: Dictionary = editor_state.document
	var selection: int = editor_state.canvas.selected_object
	var kind: String = editor_state.canvas.stamp_kind
	dialog.confirmed.connect(func() -> void:
		if not is_instance_valid(owner_canvas) or editor_state.canvas != owner_canvas or app.screen != "create": return
		if not is_same(editor_state.document,source) or editor_state.canvas.selected_object != selection or editor_state.canvas.stamp_kind != kind: return
		if dialog.free_rotation: dialog.field.apply()
		run_set_object_rotation(app,dialog.angle))
	app._own_dialog(dialog)
	dialog.popup_centered_clamped(Vector2i(410,360))

func run_scale_object(app: Node, delta: float) -> void:
	if editor_state.canvas.selected_object < 0: return
	if editor_state.document.objects[editor_state.canvas.selected_object].kind == "speed_bump":
		run_resize_speed_bump(app,delta*4.0)
		return
	run_remember(app)
	var object: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object]
	object.scale = clampf(float(object.get("scale",1.0))+delta,0.5,1.5 if object.kind in CreatorCatalog.DECORATIVE else 3.0)
	run_commit_selection(app)


func run_resize_speed_bump(app: Node, delta: float) -> void:
	if editor_state.canvas.selected_object < 0: return
	var object: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object]
	if object.kind != "speed_bump": return
	var span: float = clampf(CreatorObjects.size_of(object).y+delta,SpeedBumpEdit.MIN_SPAN,SpeedBumpEdit.MAX_SPAN)
	if is_equal_approx(span,CreatorObjects.size_of(object).y): return
	run_remember(app)
	object["span"] = span
	editor_state.document.objects[editor_state.canvas.selected_object] = SpeedBumpEdit.serialize_ready(object)
	run_commit_selection(app)


func run_fit_speed_bump(app: Node) -> void:
	if editor_state.canvas.selected_object < 0: return
	var object: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object]
	if object.kind != "speed_bump": return
	var fitted: Dictionary = SpeedBumpEdit.fit_road(editor_state.document,object,editor_state.canvas.native_preview)
	if fitted.is_empty():
		run_editor_hint(app,"Place the speed bump on a ground road first.")
		return
	if fitted == object: return
	run_remember(app)
	editor_state.document.objects[editor_state.canvas.selected_object] = fitted
	run_commit_selection(app)


func run_duplicate_object(app: Node) -> void:
	if editor_state.canvas.selected_object < 0: return
	if editor_state.document.objects.size() >= preload("res://editor/creator_limits.gd").MAX_OBJECTS:
		run_editor_hint(app,"Remove an object before adding more."); return
	var indices: Array[int] = editor_state.canvas.object_indices()
	var moved: Array = preload("res://editor/object_editing.gd").moved(editor_state.document.objects,indices,Vector2(4,4))
	var additions: Array = []
	for index: int in indices: additions.append(moved[index])
	var admission: String = preload("res://editor/creator_limits.gd").addition_error(editor_state.document.objects,additions,str(editor_state.document.theme))
	if not admission.is_empty(): run_editor_hint(app,admission); return
	if not editor_state.canvas.admit("objects",editor_state.document.objects+additions): return
	run_remember(app)
	var first: int = editor_state.document.objects.size()
	editor_state.document.objects.append_array(additions)
	editor_state.canvas.multi_select = additions.size() > 1 or editor_state.canvas.multi_select
	editor_state.canvas.selected_objects.clear()
	for index: int in range(first,editor_state.document.objects.size()): editor_state.canvas.selected_objects.append(index)
	editor_state.canvas.selected_object = editor_state.document.objects.size()-1
	editor_state.canvas.mode = "objects"
	run_commit_selection(app)

func run_remember(app: Node) -> void:
	editor_state.session.remember(editor_state.document)

func run_set_document_value(app: Node, key: String, value: Variant) -> void:
	if key in ["theme", "biome", "creator"]: return
	if not editor_state.canvas.admit(key,value): return
	run_remember(app)
	editor_state.document[key] = value
	run_save_draft(app,true)
	navigation_requested.emit("create")

func run_undo(app: Node) -> void:
	if is_instance_valid(editor_state.canvas):
		if editor_state.canvas.active_pointer != -99:
			editor_state.canvas.cancel_gesture(false)
			run_build_editor_tools(app)
			return
		if not editor_state.canvas.ghost.is_empty():
			run_delete_piece(app)
			return
		if not editor_state.canvas.paint_points.is_empty():
			editor_state.canvas.paint_points.pop_back()
			editor_state.canvas.paint_handle = -1
			run_build_editor_tools(app)
			return
		if editor_state.canvas.run_start != Vector2.INF or not editor_state.canvas.run_preview.is_empty():
			editor_state.canvas.cancel_gesture()
			run_build_editor_tools(app)
			return
		if run_has_pending_editor_work(app):
			run_resolve_editor_previews(app,app._undo,"Confirm or discard the pending previews before undoing earlier edits.")
			return
	if editor_state.session.undo.is_empty(): return
	editor_state.document = editor_state.session.restore(editor_state.document,true)
	run_restore_editor_history(app)

func run_redo(app: Node) -> void:
	if is_instance_valid(editor_state.canvas):
		if editor_state.canvas.active_pointer != -99:
			editor_state.canvas.cancel_gesture(false)
			run_build_editor_tools(app)
			return
		if run_has_pending_editor_work(app):
			run_editor_hint(app,"Confirm or cancel the preview before Redo.")
			return
	if editor_state.session.redo.is_empty(): return
	editor_state.document = editor_state.session.restore(editor_state.document,false)
	run_restore_editor_history(app)

func run_restore_editor_history(app: Node) -> void:
	# Keep the viewport, camera and controls alive; stale worker results are
	# discarded by _process, without waiting for them in the input handler.
	editor_state.canvas.changed_in_gesture = false
	editor_state.canvas.cancel_gesture()
	editor_state.canvas.ghost.clear()
	editor_state.canvas.selected_piece = -1
	editor_state.canvas.selected_object = -1
	editor_state.canvas.document = editor_state.document
	editor_state.canvas.road_approval_pending = false
	var title: Label = app.root_ui.find_child("TrackName",true,false) as Label
	if title != null: LAYOUT.update_document_name(app)
	editor_state.canvas.refresh()
	run_save_draft(app,true)
	run_build_editor_tools(app)

func run_refresh_editor(app: Node) -> void:
	if not is_instance_valid(editor_state.status): return
	var errors: Array[String] = TrackDocument.validate(editor_state.document)
	editor_state.status.text = editor_state.guidance if errors.is_empty() else errors[0]
	editor_state.test_button.disabled = not errors.is_empty()
	editor_state.publish_button.disabled = not errors.is_empty() or self.publication == null or not self.publication.ready_to_publish(editor_state.document)
	editor_state.share_button.disabled = not errors.is_empty()
	if is_instance_valid(editor_state.canvas): editor_state.canvas.refresh()

func run_editor_copy_is_current(app: Node, snapshot: Dictionary, storage: TrackLibrary, relative_path: String, disk_hash: String) -> bool:
	if storage != self.storage or editor_state.document != snapshot or disk_hash.is_empty(): return false
	var path: String = self.storage.directory.path_join(relative_path)
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path) == disk_hash

func run_apply_editor_writes(app: Node) -> void:
	for receipt: Dictionary in editor_state.writes.completed:
		var storage: TrackLibrary = receipt.storage
		if receipt.error == OK: storage.revision += 1
		if storage != self.storage: continue
		if receipt.document != editor_state.document:
			if receipt.error != OK and str(receipt.document.get("id","")) == str(editor_state.document.get("id","")):
				editor_state.save_error = receipt.error; editor_state.save_message = "Could not save: "+str(receipt.message)
				if not app._editor_exiting and app.is_inside_tree(): run_editor_hint(app,editor_state.save_message); run_update_editor_save_state(app)
			continue
		self.storage.last_error = receipt.message
		if receipt.error != OK or not editor_state.retry_original:
			editor_state.save_error = receipt.error
			editor_state.save_message = "Could not save: "+str(receipt.message) if receipt.error != OK else ""
		if receipt.error == OK:
			editor_state.wip_snapshot = receipt.document.duplicate(true); editor_state.wip_store = storage; editor_state.wip_disk_hash = receipt.digest
			editor_state.wip_saved = TrackLibrary.draft_fingerprint(receipt.document)
			if is_instance_valid(editor_state.status) and editor_state.status.text == "Saving...": editor_state.status.text = editor_state.guidance
		elif not app._editor_exiting and app.is_inside_tree(): run_editor_hint(app,editor_state.save_message)
		if not app._editor_exiting and app.is_inside_tree(): run_update_editor_save_state(app)
	editor_state.writes.completed.clear()

func run_apply_editor_commits(app: Node) -> void:
	for receipt: Dictionary in editor_state.session.commits.completed:
		# A newer in-progress gesture must not discard the preceding committed
		# revision's recovery write. Analysis and writes both preserve order.
		if not receipt.has("error"): editor_state.writes.enqueue(receipt.storage,receipt.document)
		if not editor_state.session.accept(receipt,self.storage,editor_state.document): continue
		if receipt.has("error"):
			editor_state.save_error = receipt.error; editor_state.save_message = "Could not prepare the draft for saving. Use Save to retry."
			if not app._editor_exiting and app.is_inside_tree(): run_editor_hint(app,editor_state.save_message)
			continue
		# Preserve the bound dictionary, selection and session identity.
		for key: String in ["points","widths","corners","route_override"]:
			editor_state.document[key] = receipt.document[key]
		if not editor_state.retry_original: editor_state.save_error = OK; editor_state.save_message = ""
		if not app._editor_exiting and app.is_inside_tree() and is_instance_valid(editor_state.canvas) and editor_state.canvas.is_inside_tree() and editor_state.canvas.document == editor_state.document:
			editor_state.canvas.refresh()
			if editor_state.canvas.native_preview != null and editor_state.canvas.native_preview.metadata.get("creator_document",{}) == editor_state.document:
				run_update_editor_issues(app)
			else:
				if run_objects_only_edit(app): editor_state.world.preview_objects(editor_state.document)
				run_queue_editor_preview(app)
			if is_instance_valid(editor_state.undo): editor_state.undo.disabled = editor_state.session.undo.is_empty()
			if is_instance_valid(editor_state.redo): editor_state.redo.disabled = editor_state.session.redo.is_empty()
			editor_state.publish_button.disabled = not editor_state.session.errors.is_empty() or self.publication == null or self.publication.no_publishing_slots() or not bool(editor_state.session.workflow.get("ready",false))
			editor_state.share_button.disabled = not editor_state.session.errors.is_empty()
		if not app._editor_exiting and app.is_inside_tree(): run_update_editor_save_state(app)
	editor_state.session.commits.completed.clear()

func run_flush_editor_writes(app: Node) -> void:
	editor_state.session.commits.flush(); run_apply_editor_commits(app)
	editor_state.writes.flush(); run_apply_editor_writes(app)

func run_save_draft(app: Node, background_preview: bool = false) -> Error:
	var deferred_write: bool = background_preview and is_instance_valid(editor_state.canvas) and self.storage.get_script() == preload("res://persistence/track_library.gd")
	if deferred_write:
		if editor_state.document.is_empty(): return ERR_INVALID_DATA
		app._stamp_creator()
		editor_state.session.enqueue(self.storage,editor_state.document,self.publication._root() if self.publication != null else "")
		editor_state.session.commits.poll()
		editor_state.test_button.disabled = true; editor_state.publish_button.disabled = true; editor_state.share_button.disabled = true
		if is_instance_valid(editor_state.status): editor_state.status.text = "Saving..."
		run_update_editor_save_state(app)
		return OK
	if not deferred_write: run_flush_editor_writes(app)
	if not background_preview: app._finish_preview_thread()
	if editor_state.document.is_empty(): return ERR_INVALID_DATA
	app._stamp_creator()
	if not editor_state.document.pieces.is_empty():
		if editor_state.document.pieces != editor_state.route_pieces or editor_state.route_fields.is_empty():
			var auto_route: Dictionary = RoadPieces.route_from_pieces(editor_state.document)
			if auto_route.ok:
				editor_state.route_pieces = editor_state.document.pieces.duplicate(true)
				editor_state.route_fields.clear()
				for key: String in ["points","widths","corners","route_override"]: editor_state.route_fields[key] = auto_route.document[key]
		if editor_state.document.pieces == editor_state.route_pieces:
			for key: String in editor_state.route_fields: editor_state.document[key] = editor_state.route_fields[key].duplicate(true) if editor_state.route_fields[key] is Array else editor_state.route_fields[key]
	var errors: Array[String] = TrackDocument.validate(editor_state.document)
	var message: String
	# A successful immutable snapshot belongs to this exact local library.
	# Missing primaries and failed writes still take the real recovery path.
	# A durable match can still be overwritten by an older in-flight revision.
	# Queue this final state after it; enqueue coalesces only unstarted writes.
	var wip_current: bool = not editor_state.writes.unsettled(self.storage,str(editor_state.document.id)) and (editor_state.save_error == OK or editor_state.retry_original) and run_editor_copy_is_current(app,editor_state.wip_snapshot,editor_state.wip_store,"wip/"+str(editor_state.document.id)+".json",editor_state.wip_disk_hash) and not self.storage.is_published(str(editor_state.document.id))
	var save_error: Error = OK if wip_current else editor_state.writes.enqueue(self.storage,editor_state.document) if deferred_write else self.storage.save_wip(editor_state.document)
	if wip_current: self.storage.last_error = ""
	if save_error != OK or not editor_state.retry_original:
		editor_state.save_error = save_error
		editor_state.save_message = "Could not save: "+self.storage.last_error if save_error != OK else ""
	if save_error == OK and not wip_current and not deferred_write:
		editor_state.wip_saved = TrackLibrary.draft_fingerprint(editor_state.document)
		editor_state.wip_snapshot = editor_state.document.duplicate(true)
		editor_state.wip_store = self.storage
		editor_state.wip_disk_hash = FileAccess.get_sha256(self.storage.directory.path_join("wip/"+str(editor_state.document.id)+".json"))
	if save_error != OK: message = "Could not save: " + self.storage.last_error
	elif deferred_write and not wip_current: message = "Saving..."
	elif not errors.is_empty(): message = "Draft saved. Before driving: " + errors[0]
	else: message = "WIP autosaved. Saved original unchanged."
	if is_instance_valid(editor_state.status):
		editor_state.status.text = message
		editor_state.test_button.disabled = not errors.is_empty()
		editor_state.publish_button.disabled = not errors.is_empty() or self.publication == null or not self.publication.ready_to_publish(editor_state.document)
		editor_state.share_button.disabled = not errors.is_empty()
	run_update_editor_save_state(app)
	if save_error != OK: run_editor_hint(app,editor_state.save_message)
	# Refresh action availability after each edit, without rebuilding under a finger.
	if is_instance_valid(editor_state.canvas):
		if is_instance_valid(editor_state.undo): editor_state.undo.disabled = editor_state.session.undo.is_empty()
		if is_instance_valid(editor_state.redo): editor_state.redo.disabled = editor_state.session.redo.is_empty()
		if background_preview:
			editor_state.canvas.queue_redraw()
			if editor_state.canvas.native_preview != null and editor_state.canvas.native_preview.metadata.get("creator_document",{}) == editor_state.document:
				run_update_editor_issues(app)
			else:
				if run_objects_only_edit(app): editor_state.world.preview_objects(editor_state.document)
				editor_state.test_button.disabled = true
				run_queue_editor_preview(app)
		else:
			var preview_track: NativeTrack = editor_state.canvas.native_preview if TrackLifecycle.prepared_test_matches(editor_state.document,editor_state.canvas.native_preview) else run_editor_track_preview(app)
			if preview_track != null and preview_track != editor_state.canvas.native_preview: editor_state.canvas.show_native(preview_track)
			run_update_editor_issues(app)
	return save_error

func run_test_document(app: Node) -> void:
	if is_instance_valid(editor_state.canvas) and editor_state.canvas.active_pointer != -99:
		run_editor_hint(app,"Release the track before testing.")
		return
	if run_has_pending_editor_work(app):
		notice_requested.emit("Confirm or cancel the pending previews before testing.")
		return
	if not editor_state.canvas.paint_points.is_empty():
		notice_requested.emit("Confirm or cancel the surface preview first.")
		return
	if not editor_state.canvas.ghost.is_empty():
		editor_state.status.text = "Confirm or cancel the preview before testing."
		return
	if run_save_draft(app) != OK: return
	var prepared: NativeTrack = editor_state.canvas.native_preview
	if not await run_prepare_creator_test(app,editor_state.document,prepared): return
	# Practice owns its mutable spawn/contact helpers. The editor's exact
	# compiled snapshot remains available for the next edit and test cycle.
	var track: NativeTrack = preload("res://editor/prepared_track_cache.gd").copy_track(prepared) if prepared != null else null
	if track != null and not editor_state.test_button.disabled:
		track.spawn = run_practice_start(app,track)
		track.spawn_heading = run_practice_heading(app,track)
		await app._start_race(track, true)

func run_publish_current_document(app: Node) -> void:
	if run_has_pending_editor_work(app):
		notice_requested.emit("Confirm or cancel the preview before publishing.")
		return
	if run_save_draft(app) != OK: return
	await run_publish_saved_draft(app,"wip:"+str(editor_state.document.id))

func run_share_dialog(app: Node) -> void:
	if run_has_pending_editor_work(app):
		run_resolve_editor_previews(app,app._share_dialog,"Confirm or discard the pending previews before sharing this circuit.")
		return
	if run_save_draft(app) != OK:
		notice_requested.emit("Could not save: "+self.storage.last_error)
		return
	var dialog = AcceptDialog.new()
	dialog.title = "Share your circuit"
	dialog.dialog_text = "Copy this circuit and send it to a friend. They can paste it into Import.\nLocal creation and racing shared circuits are free."
	dialog.ok_button_text = "Done"
	dialog.add_button("Copy circuit", false, "copy")
	dialog.add_button("Export file", false, "file")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"copy":
			DisplayServer.clipboard_set(JSON.stringify(editor_state.document))
			dialog.dialog_text = "Circuit copied. Your friend can paste it into Tracks > Import a circuit."
		else: run_export_file(app))
	app._own_dialog(dialog)
	dialog.popup_centered(Vector2i(650,220))

func run_export_file(app: Node) -> void:
	var dialog = FileDialog.new()
	dialog.title = "Export circuit"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Circuit file"])
	dialog.current_file = str(editor_state.document.id) + ".json"
	dialog.file_selected.connect(func(path: String) -> void:
		if self.storage.export_document(editor_state.document, path) == OK: notice_requested.emit("Circuit exported.")
		else: notice_requested.emit("Export failed: " + self.storage.last_error))
	app._own_dialog(dialog)
	_show_editor_file_dialog(app,dialog)

func run_import_dialog(app: Node) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Import a circuit"
	dialog.ok_button_text = "Import"
	var layout = VBoxContainer.new()
	dialog.add_child(layout)
	layout.add_child(MenuStyle.label("Paste a shared circuit below, or choose a circuit file.",18))
	var text = TextEdit.new()
	text.custom_minimum_size = Vector2(minf(620,app.root_ui.size.x-112),clampf(app.root_ui.size.y-420,96,220))
	text.placeholder_text = "Paste circuit data here"
	layout.add_child(text)
	layout.add_child(MenuStyle.button("Paste from clipboard", func() -> void:
		var copied: String = DisplayServer.clipboard_get()
		if copied.to_utf8_buffer().size() <= TrackDocument.MAX_BYTES: text.text = copied
		else: notice_requested.emit("That circuit is too large to import.")))
	layout.add_child(MenuStyle.button("Choose file", func() -> void:
		var picker = FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; Circuit file"])
		picker.file_selected.connect(func(path: String) -> void:
			var imported: Dictionary = self.storage.import_document(path)
			if imported.is_empty(): notice_requested.emit(self.storage.last_error)
			else: run_accept_import(app,imported))
		app._own_dialog(picker)
		_show_editor_file_dialog(app,picker)))
	dialog.confirmed.connect(func() -> void:
		if text.text.to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
			notice_requested.emit("That circuit is too large to import.")
			return
		var parsed: Variant = JSON.parse_string(text.text)
		var errors: Array[String] = TrackDocument.validate(parsed)
		if not errors.is_empty(): notice_requested.emit(errors[0])
		else: run_accept_import(app,parsed))
	app._own_dialog(dialog)
	dialog.popup_centered()

func _show_editor_file_dialog(app: Node, dialog: FileDialog) -> void:
	dialog.display_mode = FileDialog.DISPLAY_LIST
	var available: Vector2 = app.root_ui.get_viewport().get_visible_rect().size-Vector2(32,32)
	dialog.popup_centered(Vector2i(minf(1000,available.x),minf(700,available.y)))

func run_accept_import(app: Node, imported: Dictionary) -> void:
	if not editor_state.document.is_empty() and not TrackDocument.validate(editor_state.document).is_empty():
		notice_requested.emit("Fix or undo your unsaved route change before importing another circuit.")
		return
	run_save_draft(app)
	editor_state.view.clear()
	editor_state.canvas = null
	editor_state.document = imported.duplicate(true)
	# Import as a new local draft: never replace an existing author's work by ID.
	editor_state.document.id = TrackLibrary.unique_id()
	app._stamp_creator()
	editor_state.session.undo.clear()
	editor_state.session.redo.clear()
	run_save_draft(app)
	navigation_requested.emit("create")

func run_build_paint_tools(app: Node) -> void:
	editor_state.inspector.add_child(EditorStyle.button("Keep road" if editor_state.canvas.protect_road else "Paint all",func() -> void:
		editor_state.canvas.protect_road = not editor_state.canvas.protect_road
		run_build_editor_tools(app)))
	if editor_state.canvas.paint_mode != "free":
		editor_state.inspector.add_child(EditorStyle.button("Remove last point",func() -> void:
			if not editor_state.canvas.paint_points.is_empty(): editor_state.canvas.paint_points.pop_back()
			editor_state.canvas.queue_redraw()))
		editor_state.inspector.add_child(EditorStyle.button("Cancel surface",func() -> void:
			editor_state.canvas.cancel_gesture()
			editor_state.canvas.queue_redraw()))
	editor_state.inspector.add_child(MenuStyle.label("Surfaces",16))
	var materials = OptionButton.new()
	materials.name = "BrushMaterial"
	materials.custom_minimum_size.y = 54
	for surface: int in range(1,8):
		var label: String = preload("res://editor/surface_labels.gd").title(surface,str(editor_state.document.theme))
		materials.add_item(GameText.message(label)+(" / "+GameText.message("Erase") if surface == 1 else ""))
	materials.selected = editor_state.canvas.brush_surface-1
	materials.item_selected.connect(func(index: int) -> void:
		editor_state.canvas.brush_surface = index+1
		editor_state.canvas.mode = "paint"
		run_build_editor_tools(app))
	editor_state.inspector.add_child(materials)
	var actions = HBoxContainer.new()
	editor_state.inspector.add_child(actions)
	for entry: Array in [["paint","Paint"],["pan","Pan"]]:
		var value: String = entry[0]
		actions.add_child(EditorStyle.button(entry[1],func() -> void:
			editor_state.canvas.mode = value
			run_build_editor_tools(app),editor_state.canvas.mode == value))
	if editor_state.canvas.paint_mode != "area":
		editor_state.inspector.add_child(MenuStyle.label("Shape",16))
		var shapes = OptionButton.new()
		shapes.name = "BrushShape"
		shapes.custom_minimum_size.y = 54
		shapes.add_item("Round brush")
		shapes.add_item("Square brush")
		shapes.selected = 1 if editor_state.canvas.brush_shape == "square" else 0
		shapes.item_selected.connect(func(index: int) -> void: editor_state.canvas.brush_shape = "square" if index else "round")
		editor_state.inspector.add_child(shapes)
	var help = MenuStyle.label("Tap to add points; drag dots to reshape. Confirm to place. Free painting commits on release.",16,true)
	if editor_state.document.base_track != "": help.text += " Remix paints ground only."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_state.inspector.add_child(EditorStyle.button("Clear map",func() -> void:
		run_remember(app)
		editor_state.document.layout = {}
		editor_state.document.paint = []
		editor_state.document.pieces = []
		editor_state.document.objects = []
		editor_state.canvas.selected_object = -1
		editor_state.canvas.selected = -1
		editor_state.document.base_track = ""
		editor_state.document.route_override = true
		run_save_draft(app,true)
		run_build_editor_tools(app)))
	editor_state.inspector.add_child(help)

func run_editor_help(app: Node) -> void:
	notice_requested.emit("Changes autosave to a separate WIP. Load reopens the latest saved draft or autosave. Save (Ctrl+S) updates the saved original.\n\nDrag inside a road section to move it. Drag an end dot to resize and turn it; the other end stays fixed.\n\nPC: wheel zooms at the pointer. Middle/right drag or Space + left drag pans. F fits the map. Ctrl+Z / Ctrl+Shift+Z undo/redo. Enter confirms; Esc cancels. Delete removes the selection. 1–4 switch tools. Q/E rotate. Tab cycles overlapping roads.\n\nPhone: two fingers pan/zoom. Layer selects the other road at an overpass. Bridge spans include ramps at both ends; paint edits the ground underneath.")

func run_unhandled_key_input(app: Node, event: InputEvent) -> void:
	if is_instance_valid(editor_state.object_population_panel): return
	if app.screen != "create" or is_instance_valid(app.game) or not event is InputEventKey or not event.pressed or event.echo: return
	var focus: Control = app.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if editor_state.canvas.active_pointer != -99 and key in [KEY_DELETE,KEY_BACKSPACE,KEY_ENTER,KEY_KP_ENTER,KEY_Q,KEY_E]:
		editor_state.canvas.cancel_gesture(false)
		run_build_editor_tools(app)
		app.get_viewport().set_input_as_handled()
		return
	var handled: bool = true
	if event.ctrl_pressed or event.meta_pressed:
		match key:
			KEY_Z:
				if event.shift_pressed: run_redo(app)
				else: run_undo(app)
			KEY_Y: run_redo(app)
			KEY_S: run_save_track_explicit(app)
			_: handled = false
	else:
		match key:
			KEY_F: editor_state.canvas.fit()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: editor_state.canvas.zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT: editor_state.canvas.zoom_by(1.0/1.15)
			KEY_ENTER, KEY_KP_ENTER:
				if editor_state.canvas.mode == "road": editor_state.canvas.confirm_piece()
				elif editor_state.canvas.mode in ["paint","pan"]: editor_state.canvas.confirm_paint()
			KEY_ESCAPE:
				var had_pointer: bool = editor_state.canvas.active_pointer != -99
				editor_state.canvas.cancel_gesture(not had_pointer)
				if had_pointer:
					run_build_editor_tools(app)
					app.get_viewport().set_input_as_handled()
					return
				editor_state.canvas.ghost.clear()
				editor_state.canvas.selected_piece = -1
				editor_state.canvas.selected_object = -1
				editor_state.canvas.multi_select = false
				if editor_state.canvas.mode in ["place","run"]: editor_state.canvas.mode = "objects"
				elif editor_state.canvas.mode in ["start","start_line"]: editor_state.canvas.mode = "road"
				elif editor_state.canvas.mode == "paint": editor_state.canvas.mode = "pan"
				editor_state.geometry = ""
				editor_state.tools_panel.hide()
				editor_state.map_panel.hide()
				run_build_editor_tools(app)
			KEY_DELETE, KEY_BACKSPACE:
				if editor_state.canvas.mode == "paint" and not editor_state.canvas.paint_points.is_empty():
					editor_state.canvas.paint_points.pop_back()
					editor_state.canvas.paint_handle = -1
					editor_state.canvas.queue_redraw()
				elif editor_state.canvas.mode == "road": run_delete_piece(app)
				else: run_delete_selection(app)
			KEY_1: run_editor_category(app,"road")
			KEY_2: run_editor_category(app,"paint")
			KEY_3: run_editor_category(app,"objects")
			KEY_4:
				if run_editor_tool(app) != "road": run_editor_category(app,"road")
				editor_state.canvas.choose_start_line()
			KEY_Q:
				if editor_state.canvas.mode in ["objects","place"]: run_set_object_rotation(app,run_object_rotation(app)-22.5)
				else: run_change_piece(app,"heading",-15.0)
			KEY_E:
				if editor_state.canvas.mode in ["objects","place"]: run_set_object_rotation(app,run_object_rotation(app)+22.5)
				else: run_change_piece(app,"heading",15.0)
			KEY_TAB:
				if editor_state.canvas.mode == "objects": editor_state.canvas.cycle_objects()
				elif editor_state.canvas.mode == "road" and editor_state.canvas.ghost.is_empty(): editor_state.canvas.cycle_piece()
				else: handled = false
			_: handled = false
	if handled: app.get_viewport().set_input_as_handled()

func run_save_track_explicit(app: Node) -> void:
	if str(editor_state.document.get("name", "")).strip_edges().is_empty() or (str(editor_state.document.get("name", "")) == "My circuit" and editor_state.saved_snapshot.is_empty()):
		run_confirm_editor_departure(app,Callable(), false)
		return
	run_save_track_now(app)

func run_save_track_now(app: Node) -> bool:
	run_flush_editor_writes(app)
	if not run_commit_editor_previews(app): return false
	app._stamp_creator()
	var id: String = str(editor_state.document.id)
	if editor_state.save_error == OK and not editor_state.retry_original and run_editor_copy_is_current(app,editor_state.saved_snapshot,editor_state.saved_store,id+".json",editor_state.saved_disk_hash) and run_editor_copy_is_current(app,editor_state.wip_snapshot,editor_state.wip_store,"wip/"+id+".json",editor_state.wip_disk_hash) and not self.storage.is_published(id):
		self.storage.last_error = ""
		run_update_editor_save_state(app)
		return true
	if run_save_draft(app) != OK:
		notice_requested.emit("Could not save: "+self.storage.last_error)
		return false
	var original_current: bool = not editor_state.retry_original and run_editor_copy_is_current(app,editor_state.saved_snapshot,editor_state.saved_store,id+".json",editor_state.saved_disk_hash) and not self.storage.is_published(id)
	if not original_current and self.storage.save_document(editor_state.document) != OK:
		editor_state.retry_original = true
		editor_state.save_error = ERR_FILE_CANT_WRITE
		editor_state.save_message = "Could not save: "+self.storage.last_error
		run_update_editor_save_state(app)
		notice_requested.emit("Could not save: "+self.storage.last_error)
		return false
	elif not TrackDocument.validate(editor_state.document).is_empty():
		notice_requested.emit("Draft saved. Open Load track to edit it. Before testing: "+TrackDocument.validate(editor_state.document)[0])
	else:
		# Menus retain a compiled selection independently of the saved-track index.
		# Replace it after committing edits so Race cannot launch its old geometry.
		if app.selected_track != null and app.selected_track.identity == "creator_"+str(editor_state.document.id) and app.selected_track.metadata.get("creator_document",{}) != editor_state.document:
			var saved_track: NativeTrack = editor_state.canvas.native_preview if editor_state.canvas.native_preview != null and editor_state.canvas.native_preview.metadata.get("creator_document",{}) == editor_state.document else TrackCompiler.compile(editor_state.document)
			if saved_track != null: app.selected_track = saved_track
		notice_requested.emit("Saved on this device. Open Load track to edit or test it.")
		if not original_current:
			editor_state.pending_road_bake = editor_state.document.duplicate(true)
			if editor_state.canvas.native_preview != null and editor_state.canvas.native_preview.metadata.get("creator_document",{}) == editor_state.document:
				NativeTrackVisual.request_saved_road_bake.call_deferred(editor_state.canvas.native_preview,app.get_tree())
				editor_state.pending_road_bake.clear()
	var saved_title: Label = app.root_ui.find_child("TrackName",true,false) as Label
	if saved_title != null: LAYOUT.update_document_name(app)
	editor_state.saved_snapshot = editor_state.document.duplicate(true)
	editor_state.saved_store = self.storage
	if not original_current: editor_state.saved_disk_hash = FileAccess.get_sha256(self.storage.directory.path_join(id+".json"))
	editor_state.retry_original = false
	editor_state.save_error = OK
	editor_state.save_message = ""
	run_update_editor_save_state(app)
	return true

func run_editor_has_unsaved_changes(app: Node) -> bool:
	if editor_state.document.is_empty(): return false
	return editor_state.save_error != OK or run_has_pending_editor_work(app) or editor_state.saved_snapshot.is_empty() or TrackLibrary.draft_fingerprint(editor_state.document) != TrackLibrary.draft_fingerprint(editor_state.saved_snapshot)

func run_request_editor_exit(app: Node) -> void:
	# Apply final write errors before deciding whether departure needs a retry.
	run_flush_editor_writes(app)
	if not run_editor_has_unsaved_changes(app):
		run_return_from_editor(app)
		return
	run_confirm_editor_departure(app,app._return_from_editor)

func run_return_from_editor(app: Node) -> void:
	# Closing an editor reached through its own Load action must not create a Back loop.
	if editor_state.return_screen == "drafts": app.draft_return_screen = "biome"
	navigation_requested.emit(editor_state.return_screen)

func run_confirm_editor_departure(app: Node, after: Callable, allow_discard: bool = true) -> void:
	if app.root_ui.find_child("SaveChangesDialog", true, false) != null: return
	var dialog = ConfirmationDialog.new()
	dialog.name = "SaveChangesDialog"
	dialog.title = "Name your track" if not allow_discard else "Save this draft?"
	dialog.dialog_text = ""
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	var discard = dialog.add_button("Discard", true, "discard")
	discard.visible = allow_discard
	var field = LineEdit.new()
	field.name = "SaveDraftName"
	field.placeholder_text = "Track name"
	field.text = "" if str(editor_state.document.get("name", "")) == "My circuit" and editor_state.saved_snapshot.is_empty() else str(editor_state.document.get("name", ""))
	field.max_length = 40
	field.custom_minimum_size = Vector2(440, 52)
	field.virtual_keyboard_enabled = true
	dialog.add_child(field)
	var update_save = func(value: String) -> void: dialog.get_ok_button().disabled = value.strip_edges().is_empty()
	field.text_changed.connect(update_save)
	update_save.call(field.text)
	dialog.confirmed.connect(func() -> void:
		dialog.hide() # Saving can open its own success/failure notice.
		var title: String = field.text.strip_edges()
		if title != str(editor_state.document.name):
			run_remember(app)
			editor_state.document.name = title
		if not run_save_track_now(app):
			dialog.queue_free()
			return
		dialog.queue_free()
		if after.is_valid(): after.call())
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"discard": return
		dialog.hide() # A failed restore/deletion opens its own notice.
		if not run_discard_editor_document(app):
			dialog.queue_free()
			return
		dialog.queue_free()
		if after.is_valid(): after.call())
	app.root_ui.add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_clamped(Vector2i(520, 180))
	preload("res://ui/keyboard_dialog.gd").attach(dialog, field)
	field.text_submitted.connect(func(_value: String) -> void:
		if not dialog.get_ok_button().disabled: dialog.confirmed.emit())
	field.grab_focus()

func run_discard_editor_document(app: Node) -> bool:
	# Navigation flushes saves too. Drain them before deletion so no older
	# committed revision can recreate the recovery file after Discard.
	run_flush_editor_writes(app)
	var id: String = str(editor_state.document.get("id", ""))
	var original: Dictionary = {}
	if TrackDocument.valid_id(id):
		original = self.storage.load_document(id)
		if original.is_empty():
			var path: String = self.storage.directory.path_join(id+".json")
			for candidate: String in [path,path+".bak",path+".tmp"]:
				if FileAccess.file_exists(candidate):
					notice_requested.emit("Could not load this draft: " + self.storage.last_error)
					return false
		if self.storage.delete_wip(id) != OK:
			notice_requested.emit("Could not discard the recovery draft: " + self.storage.last_error)
			return false
	app._finish_preview_thread()
	run_discard_editor_previews(app)
	# A new session owns the restored document; rejected edits and gesture
	# snapshots must not be reachable through Back, Undo or Redo.
	editor_state.session = preload("res://editor/editor_session.gd").new()
	editor_state.document = original
	editor_state.canvas = null
	editor_state.view.clear()
	editor_state.object_browser_state.clear()
	editor_state.route_pieces.clear()
	editor_state.route_fields.clear()
	editor_state.pending_road_bake.clear()
	editor_state.saved_snapshot = original.duplicate(true)
	editor_state.saved_store = self.storage if not original.is_empty() else null
	editor_state.saved_disk_hash = "" # Recovered backups still require a verified write.
	editor_state.wip_snapshot = {}
	editor_state.wip_store = null
	editor_state.wip_disk_hash = ""
	editor_state.wip_saved = ""
	editor_state.pending_id = ""
	editor_state.save_error = OK
	editor_state.retry_original = false
	editor_state.save_message = ""
	return true

func run_prepare_editor_load(app: Node) -> bool:
	if not is_instance_valid(editor_state.canvas): return true
	if run_has_pending_editor_work(app): return run_commit_editor_previews(app)
	return true

func run_open_drafts(app: Node) -> void:
	if app.screen == "create" and run_editor_has_unsaved_changes(app):
		run_confirm_editor_departure(app,app._open_drafts_after_resolution)
		return
	run_open_drafts_after_resolution(app)

func run_open_drafts_after_resolution(app: Node) -> void:
	if not run_prepare_editor_load(app): return
	app.draft_return_screen = "create" if app.screen == "create" else "biome"
	navigation_requested.emit("drafts")

func run_drafts(app: Node) -> void:
	var browser: VBoxContainer = load("res://ui/draft_browser.gd").new()
	browser.name = "DraftBrowser"
	browser.set("library",self.storage)
	browser.set("lifecycle",self.publication)
	if editor_state.return_draft_view.get("directory","") == self.storage.directory:
		browser.set("restore_view",editor_state.return_draft_view.duplicate())
	editor_state.return_draft_view = {}
	browser.connect("fork_requested",app._fork_track_draft)
	browser.connect("edit_requested",app._load_saved_document)
	browser.connect("test_requested",app._test_saved_draft)
	browser.connect("publish_requested",app._publish_saved_draft)
	browser.connect("store_requested",app._navigate_menu_page.bind("store"))
	browser.connect("back_requested",func() -> void: navigation_requested.emit(app.draft_return_screen if not editor_state.document.is_empty() else "biome"))
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
	copy.name = str(copy.name).left(35).strip_edges()+" copy"
	copy["creator"] = self.storage.owner_name
	if self.storage.save_wip(copy) != OK:
		notice_requested.emit(self.storage.last_error)
		return
	editor_state.document = copy
	editor_state.view.clear()
	editor_state.session.undo.clear()
	editor_state.session.redo.clear()
	navigation_requested.emit("create")
	app._notify_creation_slots(str(editor_state.document.id))

func run_read_draft_for_action(app: Node, id: String) -> Dictionary:
	var loaded: Dictionary = self.storage.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else self.storage.load_document(id)
	if loaded.is_empty():
		notice_requested.emit("Could not load this draft: "+self.storage.last_error)
	elif self.storage.is_published(str(loaded.id)):
		notice_requested.emit("This track is published and locked against editing.")
		return {}
	return loaded

func run_test_saved_draft(app: Node, id: String) -> void:
	var loaded: Dictionary = run_read_draft_for_action(app,id)
	if loaded.is_empty(): return
	var route: Dictionary = RoadPieces.route_from_pieces(loaded)
	if not route.ok:
		notice_requested.emit("Edit this track before testing: "+str(route.errors[0]))
		return
	if not loaded.has("start_line"):
		notice_requested.emit("Place a start line in the editor before testing.")
		return
	loaded = route.document
	editor_state.document = loaded
	var track: NativeTrack = TrackCompiler.compile(loaded)
	if track == null:
		notice_requested.emit("This track needs repairs before testing. Open Edit track for details.")
		return
	if not await run_prepare_creator_test(app,loaded,track): return
	loaded = editor_state.document
	editor_state.document = loaded
	editor_state.view.clear()
	editor_state.session.undo.clear()
	editor_state.session.redo.clear()
	track.spawn = run_practice_start(app,track)
	track.spawn_heading = run_practice_heading(app,track)
	await app._start_race(track,true)

func run_complete_draft_test(app: Node) -> void:
	if not is_instance_valid(app.game) or not app.game.preparation_complete or app.test_document_snapshot.is_empty(): return
	var witness: TrackSession = app.game.get("practice_validation")
	if not witness.finished or not bool(app.game.get("practice_validation_eligible")): return
	if not run_draft_test_save_is_current(app,app._draft_test_save_context):
		run_clear_draft_test_save_recovery(app)
		app._draft_test_save_context = {"game":app.game.get_instance_id(),"witness":witness,
			"storage":app.test_library_snapshot if app.test_library_snapshot != null else self.storage,
			"scope":app.test_scope_snapshot,"vehicle":app.test_vehicle_snapshot,
			"document":app.test_document_snapshot.duplicate(true),"trajectory":app.game.race_proof.recording(witness),"was_paused":bool(app.game.get("paused"))}
	run_retry_draft_test_save(app,app._draft_test_save_context)

func run_draft_test_save_is_current(app: Node, context: Dictionary) -> bool:
	return not context.is_empty() and context==app._draft_test_save_context and is_instance_valid(app.game) and app.game.preparation_complete \
		and app.game.get_instance_id()==int(context.game) and app.game.get("practice_validation")==context.witness \
		and app.test_library_snapshot==context.storage and self.storage==context.storage \
		and self.publication!=null and self.publication.scope()==str(context.scope) \
		and app.test_vehicle_snapshot==str(context.vehicle) and app.test_document_snapshot==context.document

func run_retry_draft_test_save(app: Node, context: Dictionary) -> void:
	if not run_draft_test_save_is_current(app,context): return
	if context.trajectory.is_empty():
		context.error = "The test recording is incomplete. Restart the test drive to record a new lap."
		run_show_draft_test_save_recovery(app)
		return
	if not context.has("staged"):
		var staged: Dictionary = self.publication.stage(context.document.duplicate(true),[],str(context.vehicle),context.storage,str(context.scope),context.trajectory)
		if staged.is_empty():
			context.error = self.publication.last_error if not self.publication.last_error.is_empty() else "The completed test could not be saved. Free storage, then retry saving this recording."
			run_show_draft_test_save_recovery(app)
			return
		context.staged = staged
	var storage: TrackLibrary = context.storage
	var error: Error = storage.mark_tested(context.document.duplicate(true))
	if error != OK:
		var detail: String = storage.last_error if not storage.last_error.is_empty() else error_string(error)
		context.error = "The test recording is saved, but the test could not be marked complete. "+detail
		run_show_draft_test_save_recovery(app)
		return
	if not bool(context.was_paused) and bool(app.game.get("paused")): app.game.toggle_pause(false)
	run_clear_draft_test_save_recovery(app)
	app.pending_menu_notice = "Test lap saved on this device. Ready to publish."
	if app.test_return_to_drafts: app._leave_race()

func run_show_draft_test_save_recovery(app: Node) -> void:
	if not run_draft_test_save_is_current(app,app._draft_test_save_context): return
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
		if not run_draft_test_save_is_current(app,context): return
		if context.trajectory.is_empty():
			run_clear_draft_test_save_recovery(app)
			app.game.restart()
		else: app._retry_draft_test_save.call_deferred(context))
	recovery.return_requested.connect(func() -> void:
		app._return_from_draft_test_save.call_deferred(context))
	recovery.tree_exited.connect(func() -> void:
		if app._draft_test_save_dialog==recovery: app._draft_test_save_dialog = null)
	recovery.popup_message()

func run_return_from_draft_test_save(app: Node, context: Dictionary) -> void:
	if not run_draft_test_save_is_current(app,context): return
	run_clear_draft_test_save_recovery(app)
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
		notice_requested.emit("Publication is already in progress. Please wait for its status to update.")
		return
	var loaded: Dictionary = run_read_draft_for_action(app,id)
	if loaded.is_empty(): return
	app._telemetry_observe("publish_requested",{"biome":str(loaded.get("theme","")),"reason":"publish"})
	if app.online == null or not app.online.client.signed_in():
		notice_requested.emit("Sign in to publish this track to the cloud. Your draft remains saved locally.")
		return
	var original_scope: String = self.publication.scope()
	var storage: TrackLibrary = self.storage
	var navigation: int = app._navigation_generation
	var notice = app.PublicationPrompt.new()
	app._publication_dialog = notice
	notice.configure_publication(self.publication,loaded,func() -> bool: return self.publication.scope() == original_scope and self.storage == storage and app._navigation_generation == navigation)
	app._own_dialog(notice)
	notice.publish_confirmed.connect(app._confirm_saved_publication.bind(id,loaded,original_scope,storage,navigation,notice))
	notice.confirmed.connect(app._close_publication_prompt.bind(loaded,original_scope,storage,navigation))
	notice.canceled.connect(app._close_publication_prompt.bind(loaded,original_scope,storage,navigation))
	notice.popup_message()

func run_close_publication_prompt(app: Node, source: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int) -> void:
	app._acknowledge_publication_dialog(source,original_scope)
	if self.publication.scope() != original_scope or self.storage != storage or app._navigation_generation != navigation: return
	var job: Dictionary = self.publication.status_for(source)
	if job.get("state") not in ["finishing","published"] or not job.get("receipt") is Dictionary: return
	if not editor_state.document.is_empty() and TrackLibrary.draft_fingerprint(editor_state.document) == TrackLibrary.draft_fingerprint(source):
		editor_state.document = {}
		editor_state.view.clear()
		editor_state.session.undo.clear()
		editor_state.session.redo.clear()
	if app.screen == "create": run_open_published_track(app,job.receipt)

func run_confirm_saved_publication(app: Node, id: String, loaded: Dictionary, original_scope: String, storage: TrackLibrary, navigation: int, notice: PublicationPrompt) -> void:
	if self.publication.scope() != original_scope or self.storage != storage or app._navigation_generation != navigation: return
	var current: Dictionary = self.storage.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else self.storage.load_document(id)
	if current.is_empty() or TrackLibrary.draft_fingerprint(current) != TrackLibrary.draft_fingerprint(loaded):
		notice.submission_finished(false,"This draft changed while confirmation was open. Review the latest version before publishing.")
		return
	app._publication_request_active = true
	var accepted_terms: bool = await preload("res://ui/community_safety_ui.gd").ensure_terms(notice,app.online.client)
	if self.publication.scope() != original_scope or self.storage != storage or app._navigation_generation != navigation:
		app._publication_request_active = false
		return
	if not accepted_terms:
		app._publication_request_active = false
		if is_instance_valid(notice): notice.submission_finished(false,"Public sharing rules must be accepted online before publishing. Your draft remains saved.")
		return
	current = self.storage.load_wip(id.trim_prefix("wip:")) if id.begins_with("wip:") else self.storage.load_document(id)
	if current.is_empty() or TrackLibrary.draft_fingerprint(current) != TrackLibrary.draft_fingerprint(loaded):
		app._publication_request_active = false
		if is_instance_valid(notice): notice.submission_finished(false,"This draft changed before publication. Review the latest version before publishing.")
		return
	var requested: bool = await self.publication.request_publish(loaded)
	app._publication_request_active = false
	if self.publication.scope() != original_scope: return
	if is_instance_valid(notice): notice.submission_finished(requested,self.publication.last_error)

func run_open_published_track(app: Node, receipt: Dictionary) -> void:
	# Publishing is a direct navigation to the acknowledged public card.
	# Previous search/feed filters must not hide the track just published.
	app.browser_state.clear()
	app.browser_state.focus_track = "cloud_"+str(receipt.track_id)
	app.browser_state.pinned_version = str(receipt.get("version_id",""))
	if app.cloud.paged_discovery_available(): app.browser_state.feed = "new"
	app.race_area_mode = "free"
	navigation_requested.emit("tracks")

func run_prepare_creator_test(app: Node, source: Dictionary, prepared: NativeTrack = null) -> bool:
	if self.publication == null: return true
	var original_scope: String = self.publication.scope()
	var fingerprint: String = TrackLibrary.draft_fingerprint(source)
	app.cloud_starting = true
	var exact: Dictionary = await self.publication.prepare_test(source.duplicate(true),prepared)
	app.cloud_starting = false
	if self.publication.scope() != original_scope or editor_state.document.is_empty() or TrackLibrary.draft_fingerprint(editor_state.document) != fingerprint: return false
	if exact.is_empty():
		notice_requested.emit(self.publication.last_error)
		return false
	# Keep the canvas bound to the same dictionary throughout a practice loop.
	if editor_state.document != exact: editor_state.document = exact
	self.storage.owner_name = str(exact.get("creator",self.storage.owner_name))
	if prepared != null and is_instance_valid(editor_state.canvas) and run_editor_copy_is_current(app,editor_state.wip_snapshot,editor_state.wip_store,"wip/"+str(editor_state.document.id)+".json",editor_state.wip_disk_hash): return true
	return self.storage.save_wip(editor_state.document) == OK

func run_view_publication_notification(app: Node, item: Dictionary) -> void:
	if self.publication.scope() != item.scope or is_instance_valid(app.game): return
	if not app.cloud.remember_publication(item.receipt):
		notice_requested.emit("Your track is published, but could not be opened on this device. Check available storage and try again.")
		return
	if not self.publication.acknowledge_publication(str(item.version_id),str(item.scope)):
		notice_requested.emit(self.publication.last_error)
		return
	run_open_published_track(app,item.receipt)

func run_confirm_delete_draft(app: Node, id: String, title: String) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.name = "DeleteDraftDialog"
	dialog.title = "Delete draft?"
	dialog.dialog_autowrap = true
	dialog.dialog_text = GameText.message('Delete "%s" and its autosave from this device?\nPublished versions stay available.\nThis cannot be undone.') % title
	dialog.ok_button_text = "Delete draft"
	dialog.confirmed.connect(func() -> void:
		run_flush_editor_writes(app)
		if self.publication != null and not self.publication.archive_draft(id):
			notice_requested.emit(self.publication.last_error)
			return
		if self.storage.delete_editable(id) != OK:
			notice_requested.emit(self.storage.last_error)
			return
		if editor_state.document.get("id","") == id:
			editor_state.document = {}
			editor_state.session.undo.clear()
			editor_state.session.redo.clear()
			editor_state.view.clear()
		if app.selected_track != null and app.selected_track.identity == "creator_"+id:
			app.selected_track = NativeTrack.read("res://resources/tracks/"+app.BUILTIN_IDS[0]+".json")
		var favorites: Array = app.records.settings.get("favorites",[]).duplicate()
		favorites.erase("creator_"+id)
		app.records.settings.favorites = favorites
		if app.records.settings.get("last_track","") == "creator_"+id: app.records.settings.last_track = app.selected_track.identity
		var settings_error: Error = app.records.save_records()
		navigation_requested.emit("drafts")
		if settings_error != OK: notice_requested.emit("Draft deleted, but favorite settings could not be saved."))
	app._own_dialog(dialog)
	dialog.popup_centered(Vector2i(500,210))
	dialog.get_cancel_button().grab_focus()

func run_load_track_dialog(app: Node) -> void:
	run_open_drafts(app)

func run_load_saved_document(app: Node, id: String) -> void:
	var loaded: Dictionary = run_read_draft_for_action(app,id)
	if loaded.is_empty(): return
	editor_state.document = loaded
	editor_state.pending_tools.clear()
	editor_state.saved_snapshot = self.storage.load_document(str(loaded.id)) if id.begins_with("wip:") else loaded.duplicate(true)
	editor_state.saved_store = self.storage
	editor_state.saved_disk_hash = "" # A recovered backup must be committed before it is acknowledged.
	editor_state.canvas = null # Loading a different document must not capture the outgoing view.
	editor_state.view.clear()
	editor_state.session.undo.clear()
	editor_state.session.redo.clear()
	editor_state.geometry = ""
	navigation_requested.emit("create")
	editor_state.status.text = "Loaded "+str(editor_state.document.name)+" for editing."

func run_editor_track_preview(app: Node) -> NativeTrack:
	app._finish_preview_thread()
	return app._compile_editor_preview(editor_state.document)

func run_compile_editor_preview(app: Node, source: Dictionary, cancelled: Callable = Callable()) -> NativeTrack:
	# Only the single preview worker (or its joined foreground replacement)
	# accesses this bounded cache. Undo can reuse collision and route data too.
	for index: int in range(editor_state.compiled_cache.size()):
		var entry: Dictionary = editor_state.compiled_cache[index]
		if entry.document == source:
			editor_state.compiled_cache.remove_at(index); editor_state.compiled_cache.append(entry); return entry.track
	var result: NativeTrack = app._compile_editor_preview_uncached(source,cancelled)
	if result != null:
		var size: int = var_to_bytes(preload("res://editor/prepared_track_cache.gd").fields(result)).size()+var_to_bytes(source).size()+var_to_bytes(result.editor_winter_cover).size()
		if size <= app.EDITOR_COMPILED_BUDGET:
			var total: int = size
			for entry: Dictionary in editor_state.compiled_cache: total += int(entry.bytes)
			while not editor_state.compiled_cache.is_empty() and (editor_state.compiled_cache.size() >= 3 or total > app.EDITOR_COMPILED_BUDGET): total -= int(editor_state.compiled_cache.pop_front().bytes)
			editor_state.compiled_cache.append({"document":source.duplicate(true),"track":result,"bytes":size})
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
	var track: NativeTrack = TrackCompiler.compile(source,editor_state.raster_cache,cancelled)
	if track != null:
		CreatorPreviewMasks.prepare(track,source.paint,editor_state.raster_cache)
		track.editor_ground_key = preload("res://editor/preview_ground.gd").key_for(track)
		if source.theme == "winter": track.editor_winter_cover = WinterScenery.prepare_cover(track,editor_state.raster_cache,cancelled)
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
	run_flush_editor_writes(app)
	if self.storage.delete_document(id) != OK:
		notice_requested.emit(self.storage.last_error)
		return
	var identity: String = "creator_"+id
	if editor_state.document.get("id","") == id:
		editor_state.document = {}
		editor_state.session.undo.clear()
		editor_state.session.redo.clear()
		editor_state.view.clear()
	if app.selected_track != null and app.selected_track.identity == identity:
		app.selected_track = NativeTrack.read("res://resources/tracks/"+app.BUILTIN_IDS[0]+".json")
	var favorites: Array = app.records.settings.get("favorites",[]).duplicate()
	favorites.erase(identity)
	app.records.settings["favorites"] = favorites
	if app.records.settings.get("last_track","") == identity: app.records.settings["last_track"] = app.selected_track.identity
	var settings_error: Error = app.records.save_records()
	navigation_requested.emit("tracks")
	if settings_error != OK: notice_requested.emit("Track deleted, but favorite settings could not be saved.")

func run_choose_object(app: Node, kind: String) -> void:
	LAYOUT.set_picker(app,false,false)
	var family: Array = CreatorCatalog.family(kind)
	var same_family: bool = kind == editor_state.canvas.stamp_kind or (not family.is_empty() and editor_state.canvas.stamp_kind in family[3])
	if not same_family: editor_state.canvas.stamp_length = 0.0
	if CreatorCatalog.JUMP_ASSETS.has(kind): same_family = same_family and editor_state.canvas.stamp_jump_profile == str(CreatorCatalog.JUMP_ASSETS[kind])
	var placement: String = editor_state.object_browser.placement if same_family else "single"
	editor_state.canvas.cancel_gesture()
	var jump_profile: String = str(CreatorCatalog.JUMP_ASSETS.get(kind,""))
	editor_state.canvas.multi_select = false
	editor_state.canvas.stamp_kind="jump" if not jump_profile.is_empty() else kind
	if editor_state.canvas.stamp_kind == "jump":
		editor_state.canvas.stamp_jump_profile = jump_profile if not jump_profile.is_empty() else JumpProfiles.default_for(str(editor_state.document.theme))
		editor_state.object_browser.current = CreatorCatalog.jump_asset(editor_state.canvas.stamp_jump_profile,str(editor_state.document.theme))
	if is_instance_valid(editor_state.world): editor_state.world.warm_prop(editor_state.canvas.stamp_kind,CreatorCatalog.default_scale(kind),editor_state.canvas.stamp_container_color)
	if not same_family: editor_state.canvas.stamp_scale=CreatorCatalog.default_scale(kind)
	editor_state.object_browser.stamp_scale=editor_state.canvas.stamp_scale
	editor_state.canvas.selected_object=-1
	run_object_placement(app,placement)

func run_container_colour(app: Node, color: String) -> void:
	if not ContainerPaint.valid(color) or not is_instance_valid(editor_state.canvas): return
	editor_state.canvas.stamp_container_color = color
	if is_instance_valid(editor_state.world): editor_state.world.warm_prop("container",editor_state.canvas.stamp_scale,color)
	if is_instance_valid(editor_state.object_browser):
		editor_state.object_browser.stamp_container_color = color
		editor_state.object_browser.refresh()
	if editor_state.canvas.mode != "objects" or editor_state.canvas.selected_object < 0: return
	var object: Dictionary = editor_state.document.objects[editor_state.canvas.selected_object]
	if object.kind != "container" or ContainerPaint.value(object) == color: return
	run_remember(app)
	object["color"] = color
	run_commit_selection(app)

func run_open_object_population(app: Node) -> void:
	if is_instance_valid(editor_state.object_population_panel) or not is_instance_valid(editor_state.canvas): return
	if run_has_pending_editor_work(app):
		notice_requested.emit("Confirm or cancel the preview before populating.")
		return
	if editor_state.document.objects.size() >= ObjectPopulation.MAX_OBJECTS:
		notice_requested.emit("Remove an object before adding more.")
		return
	var errors: Array[String] = TrackDocument.validate(editor_state.document,false)
	if not errors.is_empty():
		notice_requested.emit(errors[0])
		return
	if editor_state.preview_thread != null or editor_state.canvas.native_preview == null:
		run_editor_hint(app,"The track is still being prepared. Try Populate again shortly.")
		return
	editor_state.canvas.cancel_gesture()
	var preview = ObjectPopulationPanel.new()
	preview.source = editor_state.document.duplicate(true)
	preview.terrain = editor_state.canvas.native_preview
	preview.navigation_canvas = editor_state.canvas
	preview.previous_mode = editor_state.canvas.mode
	editor_state.canvas.mode = "pan"
	editor_state.object_population_panel = preview
	app.root_ui.add_child(preview)
	preview.preview_changed.connect(func(track: NativeTrack) -> void:
		if app.screen == "create" and is_instance_valid(editor_state.world): editor_state.world.show_track(track))
	preview.cancel_requested.connect(func() -> void: run_close_object_population(app,false))
	preview.apply_requested.connect(func(objects: Array) -> void:
		if editor_state.document != preview.source:
			run_close_object_population(app,false)
			run_editor_hint(app,"The track changed. Open Populate again.")
			return
		if objects.is_empty() or editor_state.document.objects.size()+objects.size() > ObjectPopulation.MAX_OBJECTS: return
		var admission: String = preload("res://editor/creator_limits.gd").addition_error(editor_state.document.objects,objects,str(editor_state.document.theme))
		if not admission.is_empty(): run_editor_hint(app,admission); return
		if not editor_state.canvas.admit("objects",editor_state.document.objects+objects): return
		run_remember(app)
		editor_state.document.objects.append_array(objects)
		editor_state.document["automatic_scenery"] = false
		editor_state.canvas.selected_object = -1
		editor_state.canvas.mode = "objects"
		run_close_object_population(app,true)
		run_save_draft(app,true)
		run_build_editor_tools(app))

func run_close_object_population(app: Node, applied: bool) -> void:
	if not is_instance_valid(editor_state.object_population_panel): return
	if is_instance_valid(editor_state.canvas):
		editor_state.canvas.cancel_gesture()
		editor_state.canvas.mode = "objects" if applied else editor_state.object_population_panel.previous_mode
	editor_state.object_population_panel.queue_free()
	editor_state.object_population_panel = null
	if not applied and is_instance_valid(editor_state.world) and is_instance_valid(editor_state.canvas):
		editor_state.world.show_track(editor_state.canvas.native_preview)

func run_object_placement(app: Node, value: String) -> void:
	editor_state.canvas.cancel_gesture()
	editor_state.canvas.navigation_override = false
	editor_state.canvas.multi_select = false
	editor_state.canvas.selected_object = -1
	editor_state.canvas.run_start=Vector2.INF
	editor_state.canvas.run_preview.clear()
	editor_state.canvas.run_shape="curve" if value=="curve" else "line"
	editor_state.canvas.free_run=value!="road edge"
	editor_state.canvas.mode="place" if value=="single" else "run"
	editor_state.object_browser.placement=value
	run_build_editor_tools(app)

func run_choose_hazard(app: Node, kind: String) -> void:
	if not editor_state.canvas.paint_points.is_empty():
		run_resolve_editor_previews(app,func() -> void: run_choose_hazard(app,kind),"Confirm or discard the pending previews before changing tools.")
		return
	editor_state.canvas.cancel_gesture()
	editor_state.canvas.navigation_override = false
	editor_state.canvas.ghost.clear()
	editor_state.canvas.stamp_kind=kind
	editor_state.canvas.stamp_scale=1.0
	editor_state.canvas.selected_object=-1
	editor_state.canvas.mode="place"
	run_build_editor_tools(app)
	editor_state.status.text=CreatorObjects.description(kind)+" / tap to place; Objects > Select to adjust"


func run_rename_track(app: Node) -> void:
	if app.root_ui.find_child("RenameDialog",true,false) != null: return
	var dialog = ConfirmationDialog.new()
	dialog.name="RenameDialog"
	dialog.borderless=true
	dialog.title="Name your track"
	dialog.ok_button_text="Apply name"
	dialog.add_theme_stylebox_override("panel",EditorStyle.box())
	EditorStyle.apply(dialog.get_ok_button())
	EditorStyle.apply(dialog.get_cancel_button())
	dialog.get_ok_button().custom_minimum_size=Vector2(130,48)
	dialog.get_cancel_button().custom_minimum_size=Vector2(110,48)
	var column = VBoxContainer.new()
	column.custom_minimum_size=Vector2(460,64)
	column.add_theme_constant_override("separation",12)
	dialog.add_child(column)
	var field = LineEdit.new()
	field.name="CircuitName"
	field.text="" if str(editor_state.document.name) == "My circuit" and editor_state.saved_snapshot.is_empty() else str(editor_state.document.name)
	field.placeholder_text = "Track name"
	field.max_length=40
	field.custom_minimum_size=Vector2(440,52)
	field.virtual_keyboard_enabled=true
	EditorStyle.apply(field)
	field.add_theme_font_size_override("font_size",20)
	column.add_child(field)
	field.text_changed.connect(func(value: String) -> void: dialog.get_ok_button().disabled=value.strip_edges().is_empty())
	dialog.get_ok_button().disabled = field.text.strip_edges().is_empty()
	var apply_name: Callable=func() -> void:
		var title: String = field.text.strip_edges()
		if title.is_empty(): return
		if title != str(editor_state.document.name):
			run_remember(app)
			editor_state.document.name=title
			LAYOUT.update_document_name(app)
			run_save_draft(app,true)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.hide(); dialog.queue_free()
	dialog.confirmed.connect(apply_name)
	field.text_submitted.connect(func(_value: String) -> void: apply_name.call())
	dialog.canceled.connect(func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
		dialog.queue_free())
	app.root_ui.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(500,180))
	preload("res://ui/keyboard_dialog.gd").attach(dialog, field)
	field.grab_focus()
	field.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(field.text,field.get_viewport().get_screen_transform()*field.get_global_rect(),DisplayServer.KEYBOARD_TYPE_DEFAULT,40,0,field.text.length())

func run_choose_paint_mode(app: Node, value: String) -> void:
	editor_state.canvas.navigation_override = false
	if editor_state.canvas.mode == "paint" and editor_state.canvas.paint_mode == value:
		editor_state.canvas.cancel_gesture(false)
		run_build_editor_tools(app)
		return
	if not editor_state.canvas.paint_points.is_empty():
		run_resolve_editor_previews(app,func() -> void: run_choose_paint_mode(app,value),"Confirm or discard the pending previews before changing tools.")
		return
	editor_state.canvas.cancel_gesture(false)
	editor_state.canvas.paint_mode = value
	editor_state.canvas.mode = "paint"
	editor_state.canvas.queue_redraw()
	run_build_editor_tools(app)

func run_build_surface_toolbar(app: Node) -> void:
	for child: Node in editor_state.surface_actions.get_children():
		editor_state.surface_actions.remove_child(child)
		child.queue_free()
	editor_state.surface_actions.add_theme_constant_override("separation",8)
	var modes = VBoxContainer.new()
	editor_state.surface_actions.add_child(modes)
	var heading = MenuStyle.label("Paint mode",18)
	heading.add_theme_color_override("font_color",Color("97dce1"))
	modes.add_child(heading)
	heading.hide()
	var segments = HBoxContainer.new()
	segments.name = "SurfacePlacementModes"
	segments.add_theme_constant_override("separation",0)
	modes.add_child(segments)
	for entry: Array in [["free","Free","paint_brush"],["area","Area","paint_area"],["line","Line","paint_line"]]:
		var value: String = entry[0]
		var chosen: bool = editor_state.canvas.mode == "paint" and editor_state.canvas.paint_mode == value
		var button: Button = EditorButton.make(entry[1],entry[2],func() -> void:
			run_choose_paint_mode(app,value),chosen)
		button.name = "PaintMode_"+value
		button.custom_minimum_size = Vector2(56,56)
		EditorStyle.card(button,chosen)
		segments.add_child(button)
	if editor_state.canvas.paint_mode == "area":
		run_surface_point_controls(app)
		return
	var brush = HBoxContainer.new()
	brush.add_theme_constant_override("separation",6)
	brush.custom_minimum_size.x = 178
	editor_state.surface_actions.add_child(brush)
	var size_label = MenuStyle.label(GameText.message("Size")+"\n"+(GameText.message("%.1f m") % editor_state.canvas.brush_width),14)
	size_label.name = "BrushSizeReadout"
	size_label.custom_minimum_size.x = 48
	size_label.tooltip_text = GameText.message("Brush size  %.1f m") % editor_state.canvas.brush_width
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_label.add_theme_color_override("font_color",EditorStyle.MUTED)
	brush.add_child(size_label)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	brush.add_child(panel)
	var controls = HBoxContainer.new()
	panel.add_child(controls)
	var slider = HSlider.new()
	slider.name = "BrushSizeSlider"
	slider.min_value = 0.5
	slider.max_value = 40.0
	slider.step = 0.5
	slider.value = editor_state.canvas.brush_width
	slider.custom_minimum_size = Vector2(48,48)
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
		editor_state.canvas.brush_width = value
		size_label.text = GameText.message("Size")+"\n"+(GameText.message("%.1f m") % value)
		size_label.tooltip_text = GameText.message("Brush size  %.1f m") % value
		editor_state.canvas.queue_redraw())
	var smaller: Button = EditorStyle.button("-",func() -> void: slider.value -= 0.5)
	smaller.name = "BrushSmaller"
	smaller.custom_minimum_size = Vector2(48,48)
	EditorStyle.quiet(smaller)
	controls.add_child(smaller)
	controls.add_child(slider)
	var bigger: Button = EditorStyle.button("+",func() -> void: slider.value += 0.5)
	bigger.name = "BrushBigger"
	bigger.custom_minimum_size = Vector2(48,48)
	EditorStyle.quiet(bigger)
	controls.add_child(bigger)
	var options: Button = EditorButton.make("","options",func() -> void: editor_state.tools_panel.visible = not editor_state.tools_panel.visible)
	options.name = "SurfaceOptions"
	options.custom_minimum_size = Vector2(48,48)
	options.tooltip_text = "Brush shape, navigation and road protection"
	options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	editor_state.surface_actions.add_child(options)

func run_surface_point_controls(app: Node) -> void:
	var area = HBoxContainer.new()
	area.add_theme_constant_override("separation",8)
	editor_state.surface_actions.add_child(area)
	var readout: Label = MenuStyle.label((GameText.message("Area · %d points") % editor_state.canvas.paint_points.size()).replace(" · ","\n"),16)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	area.add_child(readout)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation",6); area.add_child(row)
	var remove: Button = EditorStyle.button("Undo point",func() -> void:
		if not editor_state.canvas.paint_points.is_empty(): editor_state.canvas.paint_points.pop_back()
		run_build_editor_tools(app))
	remove.name = "AreaRemovePoint"; remove.custom_minimum_size = Vector2(90,54)
	remove.disabled = editor_state.canvas.paint_points.is_empty(); row.add_child(remove)
	var cancel: Button = EditorStyle.button("Cancel",func() -> void: editor_state.canvas.cancel_gesture(); run_build_editor_tools(app))
	cancel.name = "AreaCancel"; cancel.custom_minimum_size = Vector2(72,54); row.add_child(cancel)
	var confirm: Button = EditorStyle.button("Place",func() -> void: editor_state.canvas.confirm_paint(); run_build_editor_tools(app))
	confirm.name = "AreaConfirm"; confirm.custom_minimum_size = Vector2(72,54)
	confirm.disabled = editor_state.canvas.paint_points.size() < 3; row.add_child(confirm)
	var options: Button = EditorButton.make("","options",func() -> void: editor_state.tools_panel.visible = not editor_state.tools_panel.visible)
	options.name = "SurfaceOptions"; options.size_flags_vertical = Control.SIZE_SHRINK_CENTER; editor_state.surface_actions.add_child(options)
func run_poll_editor_frame(app: Node) -> void:
	editor_state.session.commits.poll()
	run_apply_editor_commits(app)
	editor_state.writes.poll()
	run_apply_editor_writes(app)
	if is_instance_valid(editor_state.loading) and is_instance_valid(editor_state.canvas):
		editor_state.loading.visible = editor_state.session.commits.unsettled() or editor_state.preview_thread != null or editor_state.canvas.native_preview == null or editor_state.world._building
	if editor_state.preview_thread == null or editor_state.preview_thread.is_alive(): return
	# Finish the detailed scene between gestures, never underneath a finger.
	if is_instance_valid(editor_state.canvas) and editor_state.canvas.active_pointer != -99: return
	var result: NativeTrack = editor_state.preview_thread.wait_to_finish()
	editor_state.preview_thread = null
	if result != null and not editor_state.pending_road_bake.is_empty() and result.metadata.get("creator_document",{}) == editor_state.pending_road_bake:
		NativeTrackVisual.request_saved_road_bake.call_deferred(result,app.get_tree())
		editor_state.pending_road_bake.clear()
	if not is_instance_valid(editor_state.canvas) or app.screen != "create":
		if result != null: result.editor_roads = {}
		return
	if editor_state.document != editor_state.preview_document:
		if result != null: result.editor_roads = {}
		run_queue_editor_preview(app)
		return
	editor_state.preview_document = {}
	if result != null: editor_state.canvas.show_native(result)
	run_update_editor_issues(app)

