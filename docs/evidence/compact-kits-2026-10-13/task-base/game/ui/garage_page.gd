class_name GaragePage
extends HBoxContainer
## Car discovery and selected-car tools share one local showroom.
signal vehicle_selected(index: int)
signal race_requested
signal circuit_requested
signal save_failed

const Carousel = preload("res://ui/track_carousel.gd")
const RailIcons = preload("res://ui/garage_mode_icons.gd")
const LIVERY_NAMES: Array[String] = ["Original", "Rally", "Midnight", "Sandstone"]
const LIVERY_COLORS: Array[Array] = [[], ["9a3e50", "e4b74c"], ["273b50", "ced7dc"], ["c3ac82", "463c35"]]

var records: LocalRecords
var showroom: CarShowroom
var draft: Dictionary
var pickers: Dictionary = {}
var vehicle_id: String = VehicleCatalog.selected
var _selected_vehicle_id: String = VehicleCatalog.selected
var circuit_title: String = ""
var wash_button: Button
var view_hint: Label
var section: String = "cars"
var _car_menu_open: bool = false
var gallery: ScrollContainer
var gallery_slot: Control
var gallery_content: Control
var cards: HBoxContainer
var preview: Control
var heading: Label
var tools: VBoxContainer
var rail: VBoxContainer
var main: VBoxContainer
var tools_panel: PanelContainer
var actions: HBoxContainer
var select_button: Button
var thumbnails: Dictionary = {}
var tile_stride: int = 240
var _condition_saved: Dictionary = {}
var _condition_presented: Dictionary = {}
var _livery_saved: Dictionary = {}
var _presets: OptionButton
var _customise_tab: String = "livery"
var _sticker_surface: String = "hood"
var _sticker_board: StickerPlacement
var _sticker_choice: OptionButton
var _sticker_sliders: Dictionary = {}
var livery_menu: GarageLiveryMenu
var customise_layout: HBoxContainer
var sticker_overlay: PanelContainer
var _colour_slot: String = "body"
var _sticker_values: Dictionary = {}

func _ready() -> void:
	name = "GaragePage"
	add_theme_constant_override("separation", 12)
	rail = VBoxContainer.new()
	rail.name = "GarageModes"
	rail.custom_minimum_size.x = 60
	rail.add_theme_constant_override("separation", 12)
	add_child(rail)
	main = VBoxContainer.new()
	main.name = "GarageMain"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)
	preview = Control.new()
	preview.name = "GaragePreview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = 250
	preview.clip_contents = true
	main.add_child(preview)
	_create_showroom()
	var shade := TextureRect.new()
	shade.name = "ShowroomHeaderShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025,0.055,0.075,0.45), Color(0.025,0.055,0.075,0)])
	var shading := GradientTexture2D.new()
	shading.gradient = gradient
	shading.fill_from = Vector2(0,0)
	shading.fill_to = Vector2(0,1)
	shade.texture = shading
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 80
	heading = MenuStyle.label(VehicleCatalog.title(vehicle_id), 36)
	heading.name = "GarageCarTitle"
	preview.add_child(heading)
	heading.position = Vector2(24, 14)
	heading.size = Vector2(520, 46)
	_build_view_controls()
	tools_panel = PanelContainer.new()
	tools_panel.name = "GarageTools"
	tools_panel.add_theme_stylebox_override("panel", MenuStyle.card(12))
	main.add_child(tools_panel)
	tools = VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools_panel.add_child(tools)
	_build_carousel()
	actions = HBoxContainer.new()
	actions.name = "GarageActions"
	main.add_child(actions)
	_show_section("cars")
	visibility_changed.connect(_visibility_changed)

func _build_rail() -> void:
	for child: Node in rail.get_children():
		rail.remove_child(child)
		child.queue_free()
	var destinations: Array = [["cars", "Select car"], ["trophies", "Trophy wall"]] if not _car_menu_open else [["customise", "Customise"], ["care", "Care"], ["tuning", "Tuning"], ["trophies", "Trophy wall"]]
	for entry: Array in destinations:
		var destination: String = entry[0]
		var active: bool = destination == section
		var button := MenuStyle.button("", _show_section.bind(destination), active)
		button.name = "Garage" + ("Browse" if destination == "cars" else destination.capitalize())
		button.icon = RailIcons.texture(destination)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_color_override("icon_normal_color", MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_focus_color", MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_hover_color", MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_pressed_color", MenuStyle.INK)
		var style := MenuStyle.box(MenuStyle.ACCENT if active else Color("10212c"), 10)
		style.border_color = Color("ffe792") if active else Color("2a4655")
		style.set_border_width_all(1)
		button.add_theme_stylebox_override("normal", style)
		button.custom_minimum_size = Vector2(60, 60)
		button.tooltip_text = entry[1]
		rail.add_child(button)

func _create_showroom() -> void:
	draft = VehicleLivery.for_car(records.settings, vehicle_id)
	_livery_saved = draft.duplicate(true)
	showroom = CarShowroom.new()
	showroom.name = "GarageShowroom"
	showroom.vehicle_id = vehicle_id
	showroom.garage_mode = true
	showroom.interaction_inset_top = 68
	showroom.interaction_inset_bottom = 58
	showroom.framing_scale = 0.96
	showroom.livery = draft
	showroom.condition = VehicleCondition.read(records, vehicle_id)
	_condition_saved = showroom.condition.duplicate(true)
	showroom.condition_changed.connect(_save_condition)
	showroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(showroom)
	preview.move_child(showroom, 0)
	MenuStyle.fill(showroom)
	_condition_presented = showroom.weathering.snapshot()

func _build_view_controls() -> void:
	var row := HBoxContainer.new()
	row.name = "GarageViewControls"
	preview.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 24
	row.offset_right = -16
	row.offset_top = -60
	row.offset_bottom = -12
	view_hint = MenuStyle.label("Drag to turn", 16, true)
	view_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(view_hint)
	for entry: Array in [["GarageTopView", "Top view", "View the hood and roof"], ["GarageZoomOut", "-", "Zoom out"], ["GarageZoomIn", "+", "Zoom in"], ["GarageResetView", "", "Reset view"]]:
		var button := MenuStyle.button(str(entry[1]), _view_action.bind(str(entry[0])))
		button.name = str(entry[0])
		button.name = str(entry[0])
		button.tooltip_text = str(entry[2])
		button.custom_minimum_size = Vector2(48, 48)
		if entry[0] == "GarageTopView": button.add_theme_font_size_override("font_size",18)
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		if entry[0] == "GarageResetView": button.icon = MenuIcon.texture("restart")
		row.add_child(button)

func _view_action(action: String) -> void:
	match action:
		"GarageTopView":
			showroom.elevation = 0.93
			showroom._orbit()
		"GarageZoomOut": showroom.zoom_by(1.15)
		"GarageZoomIn": showroom.zoom_by(1.0 / 1.15)
		"GarageResetView": showroom.reset_view()

func _build_carousel() -> void:
	gallery_slot = Control.new()
	gallery_slot.name = "GarageCarouselSlot"
	gallery_slot.custom_minimum_size.y = 140
	gallery_slot.resized.connect(_layout_gallery)
	main.add_child(gallery_slot)
	gallery = Carousel.new()
	gallery.name = "CarCarousel"
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.scroll_deadzone = 12
	gallery.follow_focus = false
	gallery_slot.add_child(gallery)
	gallery_content = Control.new()
	gallery_content.custom_minimum_size.y = 140
	gallery.add_child(gallery_content)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	gallery_content.add_child(cards)
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		var card := MenuStyle.button("", preview_car.bind(index))
		card.name = "GarageCar_" + id
		card.tooltip_text = VehicleCatalog.title(id)
		card.clip_contents = true
		card.focus_entered.connect(_focus_card.bind(index))
		cards.add_child(card)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)
		MenuStyle.fill(column)
		var model := CarShowroom.new()
		model.name = "CarModel_" + id
		model.vehicle_id = id
		model.livery = VehicleLivery.for_car(records.settings, id)
		model.condition = VehicleCondition.read(records, id)
		model.read_only = true
		model.garage_mode = true
		model.framing_scale = 0.94
		model.custom_minimum_size.y = 104
		model.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(model)
		thumbnails[id] = model
		var footer := MarginContainer.new()
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_theme_constant_override("margin_left", 14)
		footer.add_theme_constant_override("margin_right", 14)
		footer.custom_minimum_size.y = 36
		column.add_child(footer)
		var caption := MenuStyle.label(VehicleCatalog.title(id), 22)
		caption.name = "CarCardTitle_" + id
		caption.add_theme_font_override("font", MenuStyle.DISPLAY)
		footer.add_child(caption)
	_update_cards()

func _layout_gallery() -> void:
	if not is_instance_valid(cards) or gallery_slot.size.x <= 0: return
	var first: int = roundi(float(gallery.scroll_horizontal) / tile_stride)
	gallery.call("_stop_snap")
	var slots: int = clampi(floori((gallery_slot.size.x + 12.0) / 240.0), 1, 5)
	tile_stride = floori((gallery_slot.size.x + 12.0) / slots)
	gallery.position.x = (gallery_slot.size.x - (slots * tile_stride - 12)) * 0.5
	gallery.size = Vector2(slots * tile_stride - 12, 140)
	gallery.set("snap_stride", tile_stride)
	gallery_content.custom_minimum_size.x = VehicleCatalog.IDS.size() * tile_stride - 12
	for card: Control in cards.get_children(): card.custom_minimum_size = Vector2(tile_stride - 12, 140)
	gallery.scroll_horizontal = first * tile_stride

func _focus_card(index: int) -> void:
	if section != "cars": return
	var card := cards.get_child(index) as Control
	if gallery.get_global_rect().encloses(card.get_global_rect()): return
	gallery.call("_stop_snap")
	gallery.scroll_horizontal = index * tile_stride

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or section == "cars": return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		_show_section("cars")
		get_viewport().set_input_as_handled()

func _update_cards() -> void:
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Button
		var chosen: bool = VehicleCatalog.IDS[index] == vehicle_id
		var style: StyleBoxFlat = MenuStyle.card(0)
		style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
		style.set_border_width_all(2 if chosen else 1)
		card.add_theme_stylebox_override("normal", style)
		(card.find_child("CarCardTitle_" + VehicleCatalog.IDS[index], true, false) as Label).add_theme_color_override("font_color", MenuStyle.ACCENT if chosen else MenuStyle.TEXT)

func preview_car(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	_finish_tools()
	var chosen: String = VehicleCatalog.IDS[index]
	if chosen != vehicle_id:
		vehicle_id = chosen
		heading.text = VehicleCatalog.title(vehicle_id)
		_replace_showroom_car()
	_update_cards()

func _replace_showroom_car() -> void:
	draft = VehicleLivery.for_car(records.settings,vehicle_id)
	_livery_saved = draft.duplicate(true)
	var wear: Dictionary = VehicleCondition.read(records,vehicle_id)
	showroom.replace_car(vehicle_id,draft,wear)
	_condition_saved = wear.duplicate(true)
	_condition_presented = showroom.weathering.snapshot()

func _confirm_car() -> void:
	open_car(VehicleCatalog.IDS.find(vehicle_id))

func open_car(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	preview_car(index)
	_selected_vehicle_id = vehicle_id
	_show_section("customise")
	vehicle_selected.emit(index)

func _refresh_thumbnails() -> void:
	for id: String in thumbnails:
		var model: CarShowroom = thumbnails[id]
		var paint: Dictionary = VehicleLivery.for_car(records.settings, id)
		var condition: Dictionary = VehicleCondition.read(records, id)
		if model.livery != paint: model.apply_livery(paint)
		if model.condition != condition:
			model.condition = condition
			model.weathering.restore(condition)
			model.refresh_thumbnail()

func refresh_selection() -> void:
	# A warmed page may have been built before another page selected a car.
	if _selected_vehicle_id == VehicleCatalog.selected: return
	_finish_tools()
	vehicle_id = VehicleCatalog.selected
	_selected_vehicle_id = vehicle_id
	heading.text = VehicleCatalog.title(vehicle_id)
	_replace_showroom_car()
	_show_section("cars")
	_update_cards()

func _show_section(next: String) -> void:
	if next == "car": next = "customise"
	if next not in ["cars", "customise", "care", "tuning", "trophies"]: return
	_finish_tools()
	_set_customise_layout(next == "customise")
	section = next
	if next == "cars": _car_menu_open = false
	elif next != "trophies": _car_menu_open = true
	showroom.set_trophy_view(next == "trophies")
	heading.text = "TROPHY WALL" if next == "trophies" else VehicleCatalog.title(vehicle_id)
	preview.get_node("GarageViewControls").visible = next != "trophies"
	preview.get_node("GarageViewControls/GarageTopView").visible = next == "customise"
	for container: Control in [tools, actions]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	pickers.clear()
	wash_button = null
	_presets = null
	_sticker_board = null
	_sticker_choice = null
	_sticker_sliders.clear()
	_sticker_values.clear()
	livery_menu = null
	if is_instance_valid(sticker_overlay):
		preview.remove_child(sticker_overlay)
		sticker_overlay.queue_free()
	sticker_overlay = null
	select_button = null
	gallery_slot.visible = section == "cars"
	tools_panel.visible = section not in ["cars", "care", "trophies"]
	_build_rail()
	if section == "cars":
		_refresh_thumbnails()
		select_button = MenuStyle.button("Select car", _confirm_car, true)
		select_button.name = "GarageSelectCar"
		select_button.icon = MenuIcon.texture("arrow")
		select_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
			select_button.add_theme_color_override(state, MenuStyle.INK)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.custom_minimum_size.y = 60
		select_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		select_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(select_button)
		return
	if section != "customise": tools.add_child(MenuStyle.label(section.to_upper(), 20))
	var back := MenuStyle.button("Back to cars", _show_section.bind("cars"))
	back.name = "GarageBack"
	back.custom_minimum_size = Vector2(240, 60)
	actions.add_child(back)
	if section == "customise":
		_build_customise()
	elif section == "care":
		wash_button = MenuStyle.button("Wash", _toggle_wash, true)
		wash_button.name = "GarageWash"
		wash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wash_button.custom_minimum_size.y = 60
		wash_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		wash_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(wash_button)
	elif section == "trophies":
		var empty := MenuStyle.label("No trophies yet",18,true)
		empty.name = "TrophyEmptyState"
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		actions.add_child(empty)
	else:
		tools.add_child(MenuStyle.label("Coming later", 18, true))

func _set_customise_layout(active: bool) -> void:
	if active and not is_instance_valid(customise_layout):
		customise_layout = HBoxContainer.new()
		customise_layout.name = "GarageCustomiseLayout"
		customise_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		customise_layout.add_theme_constant_override("separation",16)
		main.add_child(customise_layout)
		main.move_child(customise_layout,0)
		preview.reparent(customise_layout)
		tools_panel.reparent(customise_layout)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools_panel.custom_minimum_size.x = 344
		tools_panel.size_flags_horizontal = Control.SIZE_FILL
		tools_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif not active and is_instance_valid(customise_layout):
		preview.reparent(main)
		main.move_child(preview,0)
		tools_panel.reparent(main)
		main.move_child(tools_panel,1)
		tools_panel.custom_minimum_size.x = 0
		tools_panel.size_flags_vertical = Control.SIZE_FILL
		main.remove_child(customise_layout)
		customise_layout.queue_free()
		customise_layout = null

func _build_customise() -> void:
	livery_menu = GarageLiveryMenu.new()
	livery_menu.page = self
	tools.add_child(livery_menu)

func _set_customise_tab(tab: String) -> void:
	if tab not in ["livery","colours","stickers"]: return
	_customise_tab = tab
	_show_section("customise")

func _preset_count() -> int:
	return LIVERY_NAMES.size()+LiveryCatalog.patterns.size()

func _preset_value(index: int) -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(vehicle_id)
	if index > 0 and index < LIVERY_NAMES.size():
		value.colors.body = LIVERY_COLORS[index][0]
		value.colors.accent = LIVERY_COLORS[index][1]
	elif index >= LIVERY_NAMES.size() and index < _preset_count():
		var pattern: Dictionary = LiveryCatalog.patterns[index-LIVERY_NAMES.size()]
		value.pattern = pattern.id
		for slot: int in range(VehicleLivery.SLOTS.size()): value.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
	return value

func _preset_index() -> int:
	for index: int in range(_preset_count()):
		var value: Dictionary = _preset_value(index)
		if draft.colors == value.colors and draft.pattern == value.pattern: return index
	return _preset_count()

func _select_livery(index: int) -> void:
	if index < 0 or index >= _preset_count(): return
	var stickers: Dictionary = draft.stickers.duplicate(true)
	draft = _preset_value(index)
	draft.stickers = stickers
	showroom.apply_livery(draft)
	_update_pickers()
	_save()
	if _customise_tab == "livery": _refresh_pattern_selection()

func _refresh_pattern_selection() -> void:
	if is_instance_valid(livery_menu): livery_menu.refresh()

func _build_sticker_overlay() -> void:
	sticker_overlay = PanelContainer.new()
	sticker_overlay.name = "StickerTransformTools"
	var surface_style := MenuStyle.card(12)
	surface_style.bg_color = Color(0.035,0.075,0.105,0.95)
	surface_style.set_corner_radius_all(12)
	sticker_overlay.add_theme_stylebox_override("panel",surface_style)
	preview.add_child(sticker_overlay)
	sticker_overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sticker_overlay.offset_left = 20
	sticker_overlay.offset_top = -244
	sticker_overlay.offset_right = 344
	sticker_overlay.offset_bottom = -76
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	sticker_overlay.add_child(row)
	_sticker_board = StickerPlacement.new()
	_sticker_board.name = "StickerPlacement"
	_sticker_board.custom_minimum_size = Vector2(142,136)
	_sticker_board.vehicle_id = vehicle_id
	_sticker_board.surface = _sticker_surface
	_sticker_board.livery = draft
	_sticker_board.moved.connect(_move_sticker)
	_sticker_board.committed.connect(_save)
	row.add_child(_sticker_board)
	var transforms := VBoxContainer.new()
	transforms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transforms.add_theme_constant_override("separation",0)
	row.add_child(transforms)
	for property: String in ["size","rotation"]:
		var title_row := HBoxContainer.new()
		transforms.add_child(title_row)
		var title: Label = MenuStyle.label(property.capitalize(),14,true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var value := MenuStyle.label("",14)
		title_row.add_child(value)
		_sticker_values[property] = value
		var slider := HSlider.new()
		slider.name = "Sticker"+property.capitalize()
		slider.custom_minimum_size = Vector2(112,36)
		slider.min_value = 0.2 if property == "size" else -180
		slider.max_value = 0.95 if property == "size" else 180
		slider.step = 0.01 if property == "size" else 1
		slider.value = draft.stickers[_sticker_surface][property]
		slider.value_changed.connect(_sticker_property.bind(property))
		slider.drag_ended.connect(func(_changed: bool) -> void: _save())
		slider.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey and not event.pressed: _save())
		transforms.add_child(slider)
		_sticker_sliders[property] = slider
	var centre := MenuStyle.button("Centre",_centre_sticker)
	centre.custom_minimum_size = Vector2(112,40)
	centre.add_theme_font_size_override("font_size",18)
	transforms.add_child(centre)
	_refresh_sticker_values()

func _refresh_sticker_values() -> void:
	for property: String in _sticker_values:
		var value: float = draft.stickers[_sticker_surface][property]
		_sticker_values[property].text = ("%d%%" % roundi(value*100)) if property == "size" else ("%d°" % roundi(value))

func _choose_sticker_surface(panel: String) -> void:
	_sticker_surface = panel
	_show_section("customise")

func _choose_sticker(index: int) -> void:
	if index < 0 or index > LiveryCatalog.stickers.size(): return
	draft.stickers[_sticker_surface].id = "none" if index == 0 else LiveryCatalog.stickers[index-1].id
	_preview_sticker()
	_save()

func _move_sticker(point: Vector2) -> void:
	draft.stickers[_sticker_surface].x = point.x
	draft.stickers[_sticker_surface].y = point.y
	_preview_sticker()

func _sticker_property(value: float, property: String) -> void:
	draft.stickers[_sticker_surface][property] = value
	_preview_sticker()

func _centre_sticker() -> void:
	draft.stickers[_sticker_surface].x = 0.5
	draft.stickers[_sticker_surface].y = 0.5
	_preview_sticker()
	_save()

func _preview_sticker() -> void:
	showroom.apply_livery(draft)
	if is_instance_valid(_sticker_board):
		_sticker_board.livery = draft
		_sticker_board.queue_redraw()
	_refresh_sticker_values()

func _finish_tools() -> void:
	if showroom == null: return
	if draft != _livery_saved: _save()
	showroom.set_wash_mode(false)
	if is_instance_valid(wash_button): wash_button.text = "Wash"
	for picker: ColorPickerButton in pickers.values():
		if picker.get_popup().visible: picker.get_popup().hide()
	_save_condition()
	if view_hint != null: view_hint.text = "Drag to turn"

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_finish_tools()
		showroom.finish_car_transition()

func telemetry_exposures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if section != "cars" or not gallery.is_visible_in_tree(): return result
	var visible_rect: Rect2 = gallery.get_global_rect()
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Control
		if visible_rect.intersection(card.get_global_rect()).size.x >= card.size.x * 0.8:
			result.append({"car_id": VehicleCatalog.IDS[index], "position": index})
	return result

func _preview_color(color: Color, slot: String) -> void:
	draft.colors[slot] = Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1)).to_html(false)
	showroom.apply_livery(draft)
	if is_instance_valid(_presets): _presets.select(_preset_index())
	_refresh_pattern_selection()

func _save() -> void:
	var colors: Dictionary = records.settings.get("vehicle_liveries", {}).duplicate(true)
	colors[vehicle_id] = draft.duplicate(true)
	records.settings.vehicle_liveries = colors
	if records.save_records() != OK:
		draft = VehicleLivery.for_car(records.settings, vehicle_id)
		showroom.apply_livery(draft)
		_update_pickers()
		save_failed.emit()
	else:
		_livery_saved = draft.duplicate(true)
	if is_instance_valid(_presets): _presets.select(_preset_index())
	_refresh_pattern_selection()

func _update_pickers() -> void:
	for slot: String in VehicleLivery.SLOTS:
		if not pickers.has(slot): continue
		(pickers[slot] as ColorPickerButton).color = Color(str(draft.colors[slot]))
	if is_instance_valid(_sticker_choice): _sticker_choice.select(LiveryCatalog.sticker_index(draft.stickers[_sticker_surface].id)+1)
	for property: String in _sticker_sliders: _sticker_sliders[property].set_value_no_signal(draft.stickers[_sticker_surface][property])
	if is_instance_valid(_sticker_board):
		_sticker_board.livery = draft
		_sticker_board.queue_redraw()
	_refresh_sticker_values()
	_refresh_pattern_selection()

func _reset() -> void:
	draft = VehicleLivery.defaults(vehicle_id)
	showroom.apply_livery(draft)
	_update_pickers()
	_save()

func _toggle_wash() -> void:
	if section != "care": return
	showroom.set_wash_mode(not showroom.wash_mode)
	wash_button.text = "Done" if showroom.wash_mode else "Wash"
	view_hint.text = "Drag to wash / Two fingers to turn" if showroom.wash_mode else "Drag to turn"
	if not showroom.wash_mode: _save_condition()

func _save_condition() -> void:
	if showroom == null: return
	var current: Dictionary = VehicleCondition.read(records, vehicle_id)
	# Prepared/outgoing garage pages must never overwrite newer race wear.
	if current != _condition_saved:
		showroom.weathering.restore(current)
		_condition_saved = current.duplicate(true)
		_condition_presented = showroom.weathering.snapshot()
		return
	var value: Dictionary = showroom.weathering.snapshot()
	# Preparing an untouched clean car must not create a cosmetic save.
	if value == _condition_saved or value == _condition_presented: return
	if VehicleCondition.save(records, vehicle_id, value) != OK:
		save_failed.emit()
	else:
		_condition_saved = value.duplicate(true)
		_condition_presented = value.duplicate(true)

func _process(_delta: float) -> void:
	if showroom == null or not is_visible_in_tree(): return
	var current: Dictionary = VehicleCondition.read(records, vehicle_id)
	if current != _condition_saved:
		showroom.weathering.restore(current)
		_condition_saved = current.duplicate(true)
		_condition_presented = showroom.weathering.snapshot()

func _exit_tree() -> void:
	_finish_tools()
