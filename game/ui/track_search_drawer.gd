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

func _ready() -> void:
	layer = 40
	overlay = Control.new()
	overlay.theme = MenuStyle.theme()
	MenuStyle.fill(overlay)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.025,0.035,0.65)
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
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",6)
	panel.add_child(layout)
	var header := HBoxContainer.new()
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
	exit_button.custom_minimum_size = Vector2(48,48)
	exit_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	header.add_child(exit_button)
	layout.add_child(MenuStyle.label("Find tracks by name or creator",18,true))
	layout.add_child(MenuStyle.label("Search in",18,true))
	var choices := HBoxContainer.new()
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
		refresh_results())
	edit.text_submitted.connect(func(_value: String) -> void: _apply())
	input_row.add_child(edit)
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

func _layout() -> void:
	panel.position = Vector2(maxf(0,overlay.size.x-500),0)
	panel.size = Vector2(minf(500,overlay.size.x),overlay.size.y)

func open_for(state: Dictionary, focus_owner: Control) -> void:
	draft = state.duplicate(true)
	return_focus = focus_owner
	edit.text = str(draft.get("search",""))
	shown = 4
	scroll.scroll_vertical = 0
	show()
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

func clear_search() -> void:
	edit.text = ""
	draft.search = ""
	shown = 4
	scroll.scroll_vertical = 0
	refresh_results()
	edit.grab_focus()

func refresh_results() -> void:
	matches = discovery.query(catalog,draft,records.settings.get("favorites",[]),records.settings.get("track_ratings",{}))
	for index: int in range(scopes.size()):
		var active: bool = index == int(draft.get("search_kind",0))
		var style := MenuStyle.box(MenuStyle.ACCENT if active else Color("10232f"),10)
		style.border_color = MenuStyle.ACCENT if active else MenuStyle.BORDER
		style.set_border_width_all(1)
		scopes[index].add_theme_stylebox_override("normal",style)
		scopes[index].add_theme_color_override("font_color",MenuStyle.INK if active else MenuStyle.TEXT)
		scopes[index].add_theme_color_override("font_focus_color",MenuStyle.INK if active else MenuStyle.TEXT)
	count_label.text = "%d track%s found" % [matches.size(),"" if matches.size() == 1 else "s"]
	apply_button.text = "SHOW %d TRACK%s" % [matches.size(),"" if matches.size() == 1 else "S"]
	for child: Node in results.get_children():
		results.remove_child(child)
		child.queue_free()
	for entry: Dictionary in matches.slice(0,shown): _result(entry)
	if matches.is_empty():
		var empty := MenuStyle.label("No matching tracks.\nTry another name or creator, or change your filters.",18,true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		results.add_child(empty)
	more_button.visible = matches.size() > shown
	more_button.text = "+ %d more tracks" % maxi(0,matches.size()-shown)
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
	var biome := HBoxContainer.new()
	biome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(biome)
	var theme_id: String = str(entry.get("theme","pine"))
	biome.add_child(_icon({"pine":"leaf","desert":"cactus","winter":"snowflake","night_city":"night","storm":"storm"}.get(theme_id,"leaf"),16))
	var tag := MenuStyle.label(TrackTheme.title(theme_id),14,true)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biome.add_child(tag)
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
	if motion != null: motion.kill()
	edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	hide()
	set_process_input(false)
	closed.emit()
	if is_instance_valid(return_focus): return_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not panel.get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
