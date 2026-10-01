extends CanvasLayer
## Draft choices preview real catalog matches; only Show tracks commits them.
signal applied(filters: Dictionary)
signal closed

const DEFAULTS: Dictionary = {"section":"all","theme":"all","race_count":"any","minimum_rating":0.0,"sort":"recommended"}
var catalog: TrackCatalog
var discovery: TrackDiscoveryProvider
var records: LocalRecords
var draft: Dictionary = {}
var choices: Dictionary = {}
var panel: PanelContainer
var overlay: Control
var apply_button: Button
var active_label: Label
var sorting: OptionButton
var count_hint: Label
var rating_slider: HSlider
var rating_value: Label
var return_focus: Control
var motion: Tween
var rating_pointer: int = -1

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
	panel.name = "FilterDrawerPanel"
	var style := MenuStyle.box(Color("0b1c27"),20)
	style.border_color = MenuStyle.BORDER
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel",style)
	overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := MenuStyle.label("FILTER TRACKS",32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var exit_button := MenuStyle.button("",close)
	exit_button.name = "CloseFilters"
	exit_button.icon = MenuIcon.texture("close")
	exit_button.tooltip_text = "Close filters without applying"
	exit_button.custom_minimum_size = Vector2(48,48)
	exit_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	header.add_child(exit_button)
	var accent := ColorRect.new()
	accent.color = MenuStyle.ACCENT
	accent.custom_minimum_size = Vector2(38,3)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(accent)
	layout.add_child(MenuStyle.label("Find the perfect track for your next race",14,true))
	layout.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	layout.add_child(scroll)
	var groups := VBoxContainer.new()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("separation",8)
	scroll.add_child(groups)
	_group(groups,"SHOW","compass","section",3,[["all","Recommended","compass"],["favorites","Favorites","star"],["saved","My tracks","person"]])
	_group(groups,"BIOMES","biomes","theme",3,[["all","All","biomes"],["pine","Grass","leaf"],["desert","Desert","cactus"],["winter","Winter","snowflake"],["night_city","Night","night"],["storm","Storm","storm"]])
	_group(groups,"RACE COUNT","friends","race_count",4,[["any","Any",""],["low","Low",""],["medium","Medium",""],["high","High",""]])
	count_hint = MenuStyle.label("Race counts aren't available yet",12,true)
	groups.add_child(count_hint)
	var rating_group := VBoxContainer.new()
	rating_group.add_theme_constant_override("separation",4)
	groups.add_child(rating_group)
	var rating_header := HBoxContainer.new()
	rating_group.add_child(rating_header)
	_heading(rating_header,"MINIMUM RATING","star")
	var rating_space := Control.new()
	rating_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rating_header.add_child(rating_space)
	rating_value = MenuStyle.label("Any",20)
	rating_value.add_theme_color_override("font_color",MenuStyle.ACCENT)
	rating_header.add_child(rating_value)
	rating_slider = HSlider.new()
	rating_slider.name = "MinimumRating"
	rating_slider.min_value = 0.0
	rating_slider.max_value = 5.0
	rating_slider.step = 0.1
	rating_slider.tick_count = 6
	rating_slider.ticks_on_borders = true
	rating_slider.custom_minimum_size.y = 48
	var slider_track := MenuStyle.box(Color("29414e"),0)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	rating_slider.add_theme_stylebox_override("slider",slider_track)
	var slider_fill: StyleBoxFlat = slider_track.duplicate()
	slider_fill.bg_color = MenuStyle.ACCENT
	rating_slider.add_theme_stylebox_override("grabber_area",slider_fill)
	rating_slider.add_theme_stylebox_override("grabber_area_highlight",slider_fill)
	rating_slider.value_changed.connect(func(value: float) -> void: _choose("minimum_rating",snappedf(value,0.1)))
	rating_group.add_child(rating_slider)
	var sort_group := VBoxContainer.new()
	sort_group.add_theme_constant_override("separation",6)
	groups.add_child(sort_group)
	_heading(sort_group,"SORT BY","sort")
	sorting = OptionButton.new()
	sorting.name = "FilterSort"
	sorting.custom_minimum_size.y = 48
	sorting.add_theme_font_size_override("font_size",17)
	for caption: String in ["Recommended","Name A–Z","Highest rated","Most raced"]: sorting.add_item(caption)
	sorting.tooltip_text = "Recommended uses the default name order. Ratings match the values shown on the cards."
	sorting.item_selected.connect(func(index: int) -> void: _choose("sort",["recommended","name","score","plays"][index]))
	sort_group.add_child(sorting)
	layout.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",10)
	layout.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",4)
	footer.add_child(info)
	active_label = MenuStyle.label("0 filters active",17)
	info.add_child(active_label)
	var reset := MenuStyle.button("RESET",reset_choices)
	reset.name = "ResetFilters"
	reset.custom_minimum_size = Vector2(90,56)
	footer.add_child(reset)
	apply_button = MenuStyle.button("SHOW TRACKS",_apply,true)
	apply_button.name = "ApplyFilters"
	apply_button.custom_minimum_size = Vector2(174,56)
	apply_button.add_theme_font_size_override("font_size",22)
	footer.add_child(apply_button)
	overlay.resized.connect(_layout)
	_layout()
	hide()
	set_process_input(false)

func _layout() -> void:
	var viewport_size: Vector2 = overlay.size
	panel.position = Vector2(maxf(0,viewport_size.x-500),0)
	panel.size = Vector2(minf(500,viewport_size.x),viewport_size.y)

func _heading(parent: Control, caption: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	row.add_child(_icon(icon))
	row.add_child(MenuStyle.label(caption,19,true))

func _icon(kind: String) -> TextureRect:
	var view := TextureRect.new()
	view.texture = MenuIcon.texture(kind)
	view.custom_minimum_size = Vector2(20,20)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

func _group(parent: Control, caption: String, icon: String, key: String, columns: int, items: Array) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation",6)
	parent.add_child(group)
	_heading(group,caption,icon)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	group.add_child(grid)
	choices[key] = []
	for item: Array in items:
		var value: Variant = item[0]
		var button := MenuStyle.button(item[1],_choose.bind(key,value))
		button.name = "Choice_"+key+"_"+str(value).replace(".","_")
		button.custom_minimum_size = Vector2(0,48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_font_size_override("font_size",18)
		if not str(item[2]).is_empty():
			button.icon = MenuIcon.texture(item[2])
			button.add_theme_constant_override("icon_max_width",21)
		grid.add_child(button)
		choices[key].append({"value":value,"button":button})

func open_for(state: Dictionary, focus_owner: Control) -> void:
	draft = state.duplicate(true)
	for key: String in DEFAULTS:
		if not draft.has(key): draft[key] = DEFAULTS[key]
	draft.feed = "recommended"
	return_focus = focus_owner
	show()
	set_process_input(true)
	_layout()
	refresh_choices()
	if motion != null: motion.kill()
	var target_x: float = panel.position.x
	panel.position.x += 40
	motion = create_tween()
	motion.tween_property(panel,"position:x",target_x,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(choices.section[0].button as Button).grab_focus()
	# Keep keyboard traversal inside the modal drawer.
	var controls: Array[Control] = []
	for node: Node in panel.find_children("*","Control",true,false):
		if node is BaseButton and not node.disabled: controls.append(node)
		elif node is Slider: controls.append(node)
	for index: int in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index+1)%controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index-1,controls.size())])

func _choose(key: String, value: Variant) -> void:
	draft[key] = value
	refresh_choices()

func refresh_choices() -> void:
	var counts_available: bool = false
	for entry: Dictionary in catalog.entries:
		if discovery.track_stats.get(entry.id,{}).has("plays"): counts_available = true; break
	count_hint.visible = not counts_available
	sorting.set_item_disabled(3,not counts_available)
	for key: String in choices:
		for choice: Dictionary in choices[key]:
			var button: Button = choice.button
			var selected: bool = draft.get(key,DEFAULTS[key]) == choice.value
			button.disabled = key == "race_count" and choice.value != "any" and not counts_available
			var style := MenuStyle.box(MenuStyle.ACCENT if selected else Color("10232f"),10)
			style.border_color = MenuStyle.ACCENT if selected else MenuStyle.BORDER
			style.set_border_width_all(1)
			button.add_theme_stylebox_override("normal",style)
			button.add_theme_color_override("font_color",MenuStyle.INK if selected else MenuStyle.TEXT)
			button.add_theme_color_override("icon_normal_color",MenuStyle.INK if selected else MenuStyle.TEXT)
			button.add_theme_color_override("font_focus_color",MenuStyle.INK if selected else MenuStyle.TEXT)
			button.add_theme_color_override("icon_focus_color",MenuStyle.INK if selected else MenuStyle.TEXT)
			button.tooltip_text = "Race counts aren't available yet" if button.disabled else ("Low: 0–9 · Medium: 10–49 · High: 50+ completed races" if key == "race_count" else str(button.text))
	rating_slider.set_value_no_signal(float(draft.get("minimum_rating",0.0)))
	rating_value.text = "Any" if rating_slider.value == 0.0 else "%.1f+" % rating_slider.value
	rating_slider.tooltip_text = "Minimum rating: "+rating_value.text+" (0.1 steps)"
	sorting.selected = maxi(0,["recommended","name","score","plays"].find(draft.sort))
	var found: int = discovery.query(catalog,draft,records.settings.get("favorites",[]),records.settings.get("track_ratings",{})).size()
	apply_button.text = "SHOW %d TRACK%s" % [found,"" if found == 1 else "S"]
	active_label.text = "%d filter%s active" % [active_count(draft),"" if active_count(draft) == 1 else "s"]
	active_label.add_theme_color_override("font_color",MenuStyle.ACCENT if active_count(draft) > 0 else MenuStyle.TEXT)

static func active_count(filters: Dictionary) -> int:
	var count: int = 0
	for key: String in ["section","theme","race_count","minimum_rating"]:
		if filters.get(key,DEFAULTS[key]) != DEFAULTS[key]: count += 1
	return count

func reset_choices() -> void:
	for key: String in DEFAULTS: draft[key] = DEFAULTS[key]
	refresh_choices()

func _apply() -> void:
	var result: Dictionary = {}
	for key: String in DEFAULTS: result[key] = draft[key]
	result.feed = "recommended"
	applied.emit(result)
	close()

func close() -> void:
	rating_pointer = -1
	if motion != null: motion.kill()
	hide()
	set_process_input(false)
	closed.emit()
	if is_instance_valid(return_focus): return_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not panel.get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and rating_pointer == -1 and rating_slider.get_global_rect().has_point(event.position):
			rating_pointer = event.index
			rating_slider.grab_focus()
			_touch_rating(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == rating_pointer:
			rating_pointer = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == rating_pointer:
		_touch_rating(event.position)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _touch_rating(point: Vector2) -> void:
	var rect: Rect2 = rating_slider.get_global_rect()
	var inset: float = rating_slider.get_theme_icon("grabber").get_width()*0.5
	var ratio: float = clampf((point.x-rect.position.x-inset)/maxf(1.0,rect.size.x-inset*2.0),0.0,1.0)
	rating_slider.value = snappedf(ratio*5.0,0.1)
