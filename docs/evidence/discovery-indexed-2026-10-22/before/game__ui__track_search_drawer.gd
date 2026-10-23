extends CanvasLayer
## Metadata-only live search; the gallery changes only when results are applied.
signal applied(search: Dictionary)
signal selected(entry: Dictionary)
signal closed

var catalog: TrackCatalog
var discovery: TrackDiscoveryProvider
var records: LocalRecords
var draft: Dictionary = {}
var matches: Array[Dictionary] = []
var panel: PanelContainer
var overlay: Control
var edit: LineEdit
var results: VBoxContainer
var scroll: ScrollContainer
var count_label: Label
var apply_button: Button
var more_button: Button
var scopes: Array[Button] = []
var return_focus: Control
var motion: Tween
var shown: int = 4
var cloud: Node
var server_pages: Node
var search_delay: Timer
var keyboard_height: float = 0.0
var layout: VBoxContainer
var header: HBoxContainer
var subtitle: Label
var scope_label: Label
var choices: HBoxContainer
var clear_button: Button
var keyboard_done: Button

func _ready() -> void:
	search_delay = Timer.new()
	search_delay.one_shot = true
	search_delay.wait_time = 0.25
	search_delay.timeout.connect(_search_global)
	add_child(search_delay)
	layer = 40
	overlay = Control.new()
	overlay.theme = MenuStyle.theme()
	MenuStyle.fill(overlay)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = MenuStyle.POPUP_DIM
	MenuStyle.fill(dim)
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close())
	panel = PanelContainer.new()
	panel.name = "SearchDrawerPanel"
	var style := MenuStyle.box(Color("0b1c27"),20)
	style.border_color = MenuStyle.BORDER
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel",style)
	overlay.add_child(panel)
	preload("res://ui/popup_style.gd").decorate_panel(panel)
	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation",6)
	panel.add_child(layout)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation",14)
	layout.add_child(header)
	header.add_child(_icon("search",28))
	var title := MenuStyle.label("SEARCH TRACKS",30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var exit_button := MenuStyle.button("",close)
	exit_button.name = "CloseSearch"
	exit_button.icon = MenuIcon.texture("close")
	exit_button.tooltip_text = "Close search without applying"
	exit_button.custom_minimum_size = Vector2(52,52)
	exit_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	header.add_child(exit_button)
	subtitle = MenuStyle.label("Find tracks by name or creator",18,true)
	layout.add_child(subtitle)
	scope_label = MenuStyle.label("Search in",18,true)
	layout.add_child(scope_label)
	choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	layout.add_child(choices)
	for index: int in range(3):
		var button := MenuStyle.button(["Name or creator","Name","Creator"][index],_scope.bind(index))
		button.name = "SearchScope%d" % index
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0,48)
		button.add_theme_font_size_override("font_size",18)
		choices.add_child(button)
		scopes.append(button)
	var input_panel := PanelContainer.new()
	var input_style := MenuStyle.box(Color("071720"),10)
	input_style.border_color = MenuStyle.ACCENT
	input_style.set_border_width_all(1)
	input_panel.add_theme_stylebox_override("panel",input_style)
	layout.add_child(input_panel)
	var input_row := HBoxContainer.new()
	input_panel.add_child(input_row)
	input_row.add_child(_icon("search",26))
	edit = LineEdit.new()
	edit.name = "Search_search"
	edit.placeholder_text = "Track name or creator"
	edit.max_length = 80
	edit.clear_button_enabled = true
	edit.custom_minimum_size.y = 40
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,4))
	edit.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	edit.add_theme_font_size_override("font_size",20)
	edit.text_changed.connect(func(value: String) -> void:
		draft.search = value
		shown = 4
		scroll.scroll_vertical = 0
		refresh_results()
		_queue_search())
	edit.text_submitted.connect(func(_value: String) -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): _dismiss_keyboard()
		else: _apply())
	input_row.add_child(edit)
	keyboard_done = MenuStyle.button("Done",_dismiss_keyboard)
	keyboard_done.custom_minimum_size = Vector2(64,40)
	keyboard_done.add_theme_font_size_override("font_size",18)
	keyboard_done.name = "SearchKeyboardDone"
	input_row.add_child(keyboard_done)
	keyboard_done.hide()
	count_label = MenuStyle.label("",18)
	layout.add_child(count_label)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	layout.add_child(scroll)
	results = VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation",8)
	scroll.add_child(results)
	more_button = MenuStyle.button("",func() -> void:
		if is_instance_valid(server_pages) and server_pages.total > matches.size() and shown >= matches.size(): _apply(); return
		shown += 20
		refresh_results())
	more_button.name = "MoreSearchResults"
	more_button.add_theme_font_size_override("font_size",17)
	more_button.custom_minimum_size.y = 44
	layout.add_child(more_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",14)
	layout.add_child(footer)
	var clear := MenuStyle.button("Clear",clear_search)
	clear.name = "ClearSearch"
	clear_button = clear
	clear.icon = MenuIcon.texture("close")
	clear.custom_minimum_size = Vector2(120,56)
	footer.add_child(clear)
	apply_button = MenuStyle.button("SHOW TRACKS",_apply,true)
	apply_button.name = "ApplySearch"
	apply_button.icon = MenuIcon.texture("arrow")
	apply_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	apply_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	apply_button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.custom_minimum_size.y = 56
	footer.add_child(apply_button)
	overlay.resized.connect(_layout)
	_layout()
	hide()
	set_process_input(false)

func _icon(kind: String, width: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture(kind)
	icon.custom_minimum_size = Vector2(width,width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _process(_delta: float) -> void:
	if not visible: return
	var height: float = 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		height = DisplayServer.virtual_keyboard_get_height()*overlay.size.y/maxf(1.0,DisplayServer.window_get_size().y)
	if not is_equal_approx(height,keyboard_height): _update_keyboard_layout(height)

func _update_keyboard_layout(height: float) -> void:
	keyboard_height = maxf(0.0,height)
	if motion != null: motion.kill()
	_layout()
	_trap_focus()

func _layout() -> void:
	var typing: bool = keyboard_height > 0.0
	var available_height: float = maxf(1.0,overlay.size.y-keyboard_height)
	header.visible = not typing
	subtitle.visible = not typing
	scope_label.visible = not typing
	choices.visible = not typing or available_height >= 260
	keyboard_done.visible = typing
	more_button.visible = not typing and matches.size() > shown
	layout.add_theme_constant_override("separation",4 if typing else 6)
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.set_content_margin_all(8 if typing else 20)
	panel.add_theme_stylebox_override("panel",style)
	for button: Button in scopes: button.custom_minimum_size.y = 44 if typing else 48
	clear_button.custom_minimum_size.y = 48 if typing else 56
	apply_button.custom_minimum_size.y = 48 if typing else 56
	var width: float = minf(720 if typing else 500,overlay.size.x)
	panel.position = Vector2(maxf(0,overlay.size.x-width),0)
	panel.size = Vector2(width,available_height)

func _dismiss_keyboard() -> void:
	edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func open_for(state: Dictionary, focus_owner: Control) -> void:
	keyboard_height = 0.0
	draft = state.duplicate(true)
	return_focus = focus_owner
	edit.text = str(draft.get("search",""))
	shown = 4
	scroll.scroll_vertical = 0
	show()
	_queue_search()
	set_process_input(true)
	_layout()
	refresh_results()
	if motion != null: motion.kill()
	var target_x: float = panel.position.x
	panel.position.x += 40
	motion = create_tween()
	motion.tween_property(panel,"position:x",target_x,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	edit.grab_focus()
	edit.caret_column = edit.text.length()

func _scope(index: int) -> void:
	draft.search_kind = index
	shown = 4
	scroll.scroll_vertical = 0
	refresh_results()
	_queue_search()

func clear_search() -> void:
	edit.text = ""
	draft.search = ""
	shown = 4
	scroll.scroll_vertical = 0
	refresh_results()
	_queue_search()
	edit.grab_focus()

func refresh_results() -> void:
	matches = discovery.query(catalog,draft,records.settings.get("favorites",[]),records.settings.get("track_ratings",{}),records.settings.get("raced_tracks",[]))
	if is_instance_valid(server_pages) and server_pages.total >= 0 and server_pages.query_key == JSON.stringify(preload("res://backend/discovery_pages.gd").payload(draft,records.settings.get("favorites",[]),records.settings.get("raced_tracks",[]))):
		matches.clear()
		for metadata: Dictionary in server_pages.entries(): matches.append(cloud.entry_from_metadata(metadata))
	for index: int in range(scopes.size()):
		var active: bool = index == int(draft.get("search_kind",0))
		var style := MenuStyle.box(MenuStyle.ACCENT if active else Color("10232f"),10)
		style.border_color = MenuStyle.ACCENT if active else MenuStyle.BORDER
		style.set_border_width_all(1)
		scopes[index].add_theme_stylebox_override("normal",style)
		scopes[index].add_theme_color_override("font_color",MenuStyle.INK if active else MenuStyle.TEXT)
		scopes[index].add_theme_color_override("font_focus_color",MenuStyle.INK if active else MenuStyle.TEXT)
	count_label.text = "%d track%s found" % [matches.size(),"" if matches.size() == 1 else "s"]
	if is_instance_valid(server_pages) and server_pages.total >= 0:
		count_label.text = "%d track%s found" % [int(server_pages.total),"" if int(server_pages.total) == 1 else "s"]
		if server_pages.loading: count_label.text = "Searching…"
		if not server_pages.error.is_empty(): count_label.text = server_pages.error
	apply_button.text = "SHOW %d TRACK%s" % [matches.size(),"" if matches.size() == 1 else "S"]
	for child: Node in results.get_children():
		results.remove_child(child)
		child.queue_free()
	for entry: Dictionary in matches.slice(0,shown): _result(entry)
	if matches.is_empty():
		var empty := MenuStyle.label("No matching tracks.\nTry another name or creator, or change your filters.",18,true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		results.add_child(empty)
	more_button.visible = keyboard_height <= 0.0 and matches.size() > shown
	more_button.text = "+ %d more tracks" % maxi(0,matches.size()-shown)
	if is_instance_valid(server_pages) and server_pages.total > matches.size() and shown >= matches.size():
		more_button.visible = keyboard_height <= 0.0
		more_button.text = "BROWSE ALL %d MATCHES" % int(server_pages.total)
	_trap_focus()

func _result(entry: Dictionary) -> void:
	var button := MenuStyle.button("",func() -> void:
		applied.emit({"search":edit.text,"search_kind":int(draft.get("search_kind",0))})
		selected.emit(entry)
		close())
	button.custom_minimum_size.y = 72
	button.name = "SearchResult_"+str(entry.id)
	button.tooltip_text = str(entry.name)+" by "+str(entry.creator)
	button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,4))
	results.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	MenuStyle.fill(row)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(entry.get("theme","pine")))
	art.custom_minimum_size = Vector2(88,68)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation",2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := RichTextLabel.new()
	title.custom_minimum_size.y = 26
	title.scroll_active = false
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("normal_font",MenuStyle.DISPLAY)
	title.add_theme_font_size_override("normal_font_size",20)
	info.add_child(title)
	var text: String = str(entry.name).to_upper()
	var query: String = edit.text.strip_edges().to_upper()
	var offset: int = text.find(query) if not query.is_empty() else -1
	if offset < 0: title.add_text(text)
	else:
		title.add_text(text.left(offset))
		title.push_color(MenuStyle.ACCENT)
		title.add_text(text.substr(offset,query.length()))
		title.pop()
		title.add_text(text.substr(offset+query.length()))
	var creator := MenuStyle.label("by "+str(entry.creator),16,true)
	creator.clip_text = true
	creator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(creator)
	var theme_id: String = str(entry.get("theme","pine"))
	info.add_child(preload("res://ui/biome_badge.gd").view(theme_id,12))
	var outline := Control.new()
	outline.custom_minimum_size = Vector2(62,64)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(outline)
	var points := PackedVector2Array()
	for point: Array in entry.get("points",[]): points.append(Vector2(point[0],point[1]))
	outline.draw.connect(func() -> void:
		if points.size() < 2: return
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point: Vector2 in points: bounds = bounds.expand(point)
		var scale_factor: float = minf((outline.size.x-8)/maxf(1,bounds.size.x),(outline.size.y-12)/maxf(1,bounds.size.y))
		var path := PackedVector2Array()
		for point: Vector2 in points:
			var route_offset: Vector2 = (point-bounds.get_center())*scale_factor
			path.append(outline.size*0.5+Vector2(route_offset.x,-route_offset.y))
		path.append(path[0])
		outline.draw_polyline(path,MenuStyle.TEXT,2.5,true))
	outline.resized.connect(outline.queue_redraw)

func _trap_focus() -> void:
	var controls: Array[Control] = []
	for node: Node in panel.find_children("*","Control",true,false):
		if node is BaseButton and node.is_visible_in_tree() and not node.disabled: controls.append(node)
		elif node is LineEdit: controls.append(node)
	for index: int in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index+1)%controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index-1,controls.size())])

func _apply() -> void:
	applied.emit({"search":edit.text,"search_kind":int(draft.get("search_kind",0))})
	close()

func close() -> void:
	search_delay.stop()
	if is_instance_valid(server_pages):
		server_pages.generation += 1
		server_pages.loading = false
		cloud.client.cancel_public_reads(server_pages.get_instance_id())
	if motion != null: motion.kill()
	edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	hide()
	set_process_input(false)
	closed.emit()

func _queue_search() -> void:
	if cloud != null and cloud.paged_discovery_available() and visible: search_delay.start()

func _search_global() -> void:
	if cloud == null or not visible or not cloud.paged_discovery_available(): return
	if not is_instance_valid(server_pages):
		server_pages = preload("res://backend/discovery_pages.gd").new()
		server_pages.client = cloud.client
		add_child(server_pages)
		server_pages.changed.connect(func() -> void:
			if visible: refresh_results())
	await server_pages.begin(draft,records.settings.get("favorites",[]),records.settings.get("raced_tracks",[]))
	if is_instance_valid(return_focus): return_focus.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not panel.get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
