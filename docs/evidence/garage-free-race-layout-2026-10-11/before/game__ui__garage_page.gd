class_name GaragePage
extends VBoxContainer
## Car discovery and selected-car tools share one local showroom.
signal vehicle_selected(index: int)
signal race_requested
signal circuit_requested
signal save_failed

const Carousel = preload("res://ui/track_carousel.gd")
const LIVERY_NAMES: Array[String] = ["Original", "Rally", "Midnight", "Sandstone"]
const LIVERY_COLORS: Array[Array] = [[], ["9a3e50", "e4b74c"], ["273b50", "ced7dc"], ["c3ac82", "463c35"]]

var records: LocalRecords
var showroom: CarShowroom
var draft: Dictionary
var pickers: Dictionary = {}
var vehicle_id: String = VehicleCatalog.selected
var circuit_title: String = ""
var wash_button: Button
var view_hint: Label
var section: String = "cars"
var gallery: ScrollContainer
var gallery_slot: Control
var gallery_content: Control
var cards: HBoxContainer
var preview: VBoxContainer
var heading: Label
var tools: VBoxContainer
var tile_stride: int = 280
var _condition_saved: Dictionary = {}
var _condition_presented: Dictionary = {}
var _livery_saved: Dictionary = {}
var _presets: OptionButton

func _ready() -> void:
	name = "GaragePage"
	resized.connect(queue_redraw)
	add_theme_constant_override("separation", 12)
	var hero := HBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", 20)
	add_child(hero)
	preview = VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_constant_override("separation", 8)
	hero.add_child(preview)
	heading = MenuStyle.label(VehicleCatalog.title(vehicle_id), 32)
	preview.add_child(heading)
	_create_showroom()
	_build_view_controls()
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	panel.add_theme_stylebox_override("panel", MenuStyle.card(16))
	hero.add_child(panel)
	tools = VBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	panel.add_child(tools)
	_build_carousel()
	_show_section("cars")
	visibility_changed.connect(_visibility_changed)

func _create_showroom() -> void:
	draft = VehicleLivery.for_car(records.settings, vehicle_id)
	_livery_saved = draft.duplicate(true)
	showroom = CarShowroom.new()
	showroom.name = "GarageShowroom"
	showroom.vehicle_id = vehicle_id
	showroom.livery = draft
	showroom.condition = VehicleCondition.read(records, vehicle_id)
	_condition_saved = showroom.condition.duplicate(true)
	showroom.condition_changed.connect(_save_condition)
	showroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(showroom)
	preview.move_child(showroom, 1)
	_condition_presented = showroom.weathering.snapshot()

func _build_view_controls() -> void:
	var row := HBoxContainer.new()
	row.name = "GarageViewControls"
	preview.add_child(row)
	view_hint = MenuStyle.label("Drag to rotate", 16, true)
	view_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(view_hint)
	for entry: Array in [["GarageZoomOut", "-", "Zoom out"], ["GarageZoomIn", "+", "Zoom in"], ["GarageResetView", "", "Reset view"]]:
		var button := MenuStyle.button(str(entry[1]), _view_action.bind(str(entry[0])))
		button.name = str(entry[0])
		button.tooltip_text = str(entry[2])
		button.custom_minimum_size = Vector2(48, 48)
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		if entry[0] == "GarageResetView": button.icon = MenuIcon.texture("restart")
		row.add_child(button)

func _view_action(action: String) -> void:
	match action:
		"GarageZoomOut": showroom.zoom_by(1.15)
		"GarageZoomIn": showroom.zoom_by(1.0 / 1.15)
		"GarageResetView": showroom.reset_view()

func _build_carousel() -> void:
	gallery_slot = Control.new()
	gallery_slot.name = "GarageCarouselSlot"
	gallery_slot.custom_minimum_size.y = 156
	gallery_slot.resized.connect(_layout_gallery)
	add_child(gallery_slot)
	gallery = Carousel.new()
	gallery.name = "CarCarousel"
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.scroll_deadzone = 12
	gallery.follow_focus = false
	gallery_slot.add_child(gallery)
	gallery_content = Control.new()
	gallery_content.custom_minimum_size.y = 156
	gallery.add_child(gallery_content)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	gallery_content.add_child(cards)
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		var card := MenuStyle.button("", open_car.bind(index))
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
		var art := TextureRect.new()
		art.texture = VehicleCatalog.artwork(id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size.y = 116
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)
		var caption := MenuStyle.label(VehicleCatalog.title(id), 20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.y = 40
		column.add_child(caption)
	_update_cards()

func _layout_gallery() -> void:
	if not is_instance_valid(cards) or gallery_slot.size.x <= 0: return
	var first: int = roundi(float(gallery.scroll_horizontal) / tile_stride)
	gallery.call("_stop_snap")
	var slots: int = clampi(floori((gallery_slot.size.x + 12.0) / 280.0), 1, 4)
	tile_stride = floori((gallery_slot.size.x + 12.0) / slots)
	gallery.position.x = (gallery_slot.size.x - (slots * tile_stride - 12)) * 0.5
	gallery.size = Vector2(slots * tile_stride - 12, 156)
	gallery.set("snap_stride", tile_stride)
	gallery_content.custom_minimum_size.x = VehicleCatalog.IDS.size() * tile_stride - 12
	for card: Control in cards.get_children(): card.custom_minimum_size = Vector2(tile_stride - 12, 156)
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
		_show_section("cars" if section == "car" else "car")
		get_viewport().set_input_as_handled()

func _update_cards() -> void:
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Button
		var chosen: bool = VehicleCatalog.IDS[index] == vehicle_id
		var style: StyleBoxFlat = MenuStyle.card(0)
		style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
		style.set_border_width_all(2 if chosen else 1)
		card.add_theme_stylebox_override("normal", style)
		(card.get_child(0).get_child(1) as Label).add_theme_color_override("font_color", MenuStyle.ACCENT if chosen else MenuStyle.TEXT)

func open_car(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	_finish_tools()
	var chosen: String = VehicleCatalog.IDS[index]
	if chosen != vehicle_id:
		preview.remove_child(showroom)
		showroom.queue_free()
		vehicle_id = chosen
		heading.text = VehicleCatalog.title(vehicle_id)
		_create_showroom()
	_show_section("car")
	_update_cards()
	vehicle_selected.emit(index)

func refresh_selection() -> void:
	# A warmed page may have been built before another page selected a car.
	if vehicle_id == VehicleCatalog.selected: return
	_finish_tools()
	preview.remove_child(showroom)
	showroom.queue_free()
	vehicle_id = VehicleCatalog.selected
	heading.text = VehicleCatalog.title(vehicle_id)
	_create_showroom()
	_show_section("cars")
	_update_cards()

func _show_section(next: String) -> void:
	if next not in ["cars", "car", "customise", "care", "tuning"]: return
	_finish_tools()
	section = next
	for child: Node in tools.get_children():
		tools.remove_child(child)
		child.queue_free()
	pickers.clear()
	wash_button = null
	_presets = null
	gallery_slot.visible = section == "cars"
	if section != "cars":
		var back := MenuStyle.button("Back to cars" if section == "car" else "Back to car", _show_section.bind("cars" if section == "car" else "car"))
		back.name = "GarageBack"
		back.custom_minimum_size.y = 48
		tools.add_child(back)
	if section == "cars":
		tools.add_child(MenuStyle.label("YOUR GARAGE", 26))
		_add_description()
		_add_specs()
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tools.add_child(spacer)
		var circuit := MenuFeature.new()
		circuit.name = "GarageCircuit"
		circuit.heading = circuit_title
		circuit.description = "Choose circuit"
		circuit.pressed.connect(func() -> void: circuit_requested.emit())
		tools.add_child(circuit)
		tools.add_child(MenuStyle.button("RACE", func() -> void: race_requested.emit(), true))
	elif section == "car":
		_add_description()
		for destination: String in ["customise", "care", "tuning"]:
			var button := MenuStyle.button(destination.capitalize(), _show_section.bind(destination), destination == "customise")
			button.name = "Garage" + destination.capitalize()
			tools.add_child(button)
	elif section == "customise":
		tools.add_child(MenuStyle.label("CUSTOMISE", 26))
		_build_customise()
	elif section == "care":
		tools.add_child(MenuStyle.label("CARE", 26))
		wash_button = MenuStyle.button("Wash", _toggle_wash, true)
		wash_button.name = "GarageWash"
		wash_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		wash_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		tools.add_child(wash_button)
	else:
		tools.add_child(MenuStyle.label("TUNING", 26))
		tools.add_child(MenuStyle.label("Coming later", 18, true))

func _add_description() -> void:
	var label := MenuStyle.label(VehicleCatalog.description(vehicle_id), 18, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(label)

func _add_specs() -> void:
	var config: HandlingConfig = VehicleCatalog.config(vehicle_id)
	for pair: Array in [["Mass", "%d kg" % roundi(config.mass)], ["Speed limit", "%d km/h" % roundi(config.maximum_speed * 3.6)]]:
		var row := HBoxContainer.new()
		tools.add_child(row)
		var label := MenuStyle.label(str(pair[0]), 17, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(MenuStyle.label(str(pair[1]), 20))

func _build_customise() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	scroll.add_child(controls)
	controls.add_child(MenuStyle.label("Livery", 18))
	_presets = OptionButton.new()
	_presets.name = "GarageLivery"
	_presets.custom_minimum_size.y = 48
	for title: String in LIVERY_NAMES: _presets.add_item(title)
	_presets.add_item("Custom")
	_presets.set_item_disabled(LIVERY_NAMES.size(), true)
	_presets.select(_preset_index())
	_presets.item_selected.connect(_select_livery)
	controls.add_child(_presets)
	for slot: String in VehicleLivery.SLOTS:
		var row := HBoxContainer.new()
		controls.add_child(row)
		var label := MenuStyle.label(slot.capitalize(), 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.name = "Livery" + slot.capitalize()
		picker.custom_minimum_size = Vector2(112, 48)
		picker.edit_alpha = false
		picker.color = Color(str(draft.colors[slot]))
		var color_picker: ColorPicker = picker.get_picker()
		color_picker.color_modes_visible = false
		color_picker.sliders_visible = false
		color_picker.sampler_visible = false
		color_picker.presets_visible = false
		picker.get_popup().add_theme_stylebox_override("panel", MenuStyle.card(12))
		picker.color_changed.connect(_preview_color.bind(slot))
		picker.popup_closed.connect(_save)
		row.add_child(picker)
		pickers[slot] = picker
	controls.add_child(MenuStyle.button("Reset paint", _reset))

func _preset_value(index: int) -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(vehicle_id)
	if index > 0 and index < LIVERY_NAMES.size():
		value.colors.body = LIVERY_COLORS[index][0]
		value.colors.accent = LIVERY_COLORS[index][1]
	return value

func _preset_index() -> int:
	for index: int in range(LIVERY_NAMES.size()):
		if draft == _preset_value(index): return index
	return LIVERY_NAMES.size()

func _select_livery(index: int) -> void:
	if index < 0 or index >= LIVERY_NAMES.size(): return
	draft = _preset_value(index)
	showroom.apply_livery(draft)
	_update_pickers()
	_save()

func _finish_tools() -> void:
	if showroom == null: return
	if draft != _livery_saved: _save()
	showroom.set_wash_mode(false)
	if is_instance_valid(wash_button): wash_button.text = "Wash"
	for picker: ColorPickerButton in pickers.values():
		if picker.get_popup().visible: picker.get_popup().hide()
	_save_condition()
	if view_hint != null: view_hint.text = "Drag to rotate"

func _visibility_changed() -> void:
	if not is_visible_in_tree(): _finish_tools()

func telemetry_exposures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if section != "cars" or not gallery.is_visible_in_tree(): return result
	var visible_rect: Rect2 = gallery.get_global_rect()
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Control
		if visible_rect.intersection(card.get_global_rect()).size.x >= card.size.x * 0.8:
			result.append({"car_id": VehicleCatalog.IDS[index], "position": index})
	return result

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111922"))

func _preview_color(color: Color, slot: String) -> void:
	draft.colors[slot] = Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1)).to_html(false)
	showroom.apply_livery(draft)
	if is_instance_valid(_presets): _presets.select(_preset_index())

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

func _update_pickers() -> void:
	for slot: String in VehicleLivery.SLOTS:
		if not pickers.has(slot): continue
		(pickers[slot] as ColorPickerButton).color = Color(str(draft.colors[slot]))

func _reset() -> void:
	draft = VehicleLivery.defaults(vehicle_id)
	showroom.apply_livery(draft)
	_update_pickers()
	_save()

func _toggle_wash() -> void:
	if section != "care": return
	showroom.set_wash_mode(not showroom.wash_mode)
	wash_button.text = "Done" if showroom.wash_mode else "Wash"
	view_hint.text = "Drag to wash / Two fingers to rotate" if showroom.wash_mode else "Drag to rotate"
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
