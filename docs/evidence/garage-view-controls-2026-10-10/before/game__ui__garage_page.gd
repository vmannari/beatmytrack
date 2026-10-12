class_name GaragePage
extends HBoxContainer
signal vehicle_selected(index: int)
signal race_requested
signal circuit_requested
signal save_failed

var records: LocalRecords
var showroom: CarShowroom
var draft: Dictionary
var pickers: Dictionary = {}
var vehicle_id: String = VehicleCatalog.selected
var circuit_title: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", 20)
	draft = VehicleLivery.for_car(records.settings, vehicle_id)
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(preview)
	preview.add_child(MenuStyle.label("YOUR GARAGE", 36))
	showroom = CarShowroom.new()
	showroom.name = "GarageShowroom"
	showroom.vehicle_id = vehicle_id
	showroom.livery = draft
	showroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(showroom)
	preview.add_child(MenuStyle.label("Drag to rotate", 16, true))
	var circuit := MenuFeature.new()
	circuit.name = "GarageCircuit"
	circuit.heading = circuit_title
	circuit.description = "Choose circuit"
	circuit.pressed.connect(func() -> void: circuit_requested.emit())
	preview.add_child(circuit)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	panel.add_theme_stylebox_override("panel", MenuStyle.card(16))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	scroll.add_child(controls)
	controls.add_child(MenuStyle.label(VehicleCatalog.title(vehicle_id), 28))
	var selector := OptionButton.new()
	selector.name = "VehicleSelector"
	selector.custom_minimum_size.y = 48
	for title: String in VehicleCatalog.CLASSES: selector.add_item(title)
	selector.select(VehicleCatalog.IDS.find(vehicle_id))
	selector.item_selected.connect(func(index: int) -> void: vehicle_selected.emit(index))
	controls.add_child(selector)
	var description := MenuStyle.label(VehicleCatalog.description(vehicle_id), 17, true)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(description)
	controls.add_child(HSeparator.new())
	controls.add_child(MenuStyle.label("LIVERY", 20))
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
		# Compact touch picker: hue/saturation/value and exact hex, no duplicated sliders.
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
	controls.add_child(HSeparator.new())
	var handling: HandlingConfig = HandlingSelection.config()
	for pair: Array in [["Mass", "%d kg" % roundi(handling.mass)], ["Speed limit", "%d km/h" % roundi(handling.maximum_speed*3.6)]]:
		var row := HBoxContainer.new()
		controls.add_child(row)
		var label := MenuStyle.label(str(pair[0]), 17, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(MenuStyle.label(str(pair[1]), 20))
	var race := MenuStyle.button("RACE", func() -> void: race_requested.emit(), true)
	race.custom_minimum_size.y = 52
	column.add_child(race)

func _preview_color(color: Color, slot: String) -> void:
	draft.colors[slot] = Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1)).to_html(false)
	showroom.apply_livery(draft)

func _save() -> void:
	var colors: Dictionary = records.settings.get("vehicle_liveries", {}).duplicate(true)
	colors[vehicle_id] = draft.duplicate(true)
	records.settings.vehicle_liveries = colors
	if records.save_records() != OK:
		draft = VehicleLivery.for_car(records.settings, vehicle_id)
		showroom.apply_livery(draft)
		_update_pickers()
		save_failed.emit()

func _update_pickers() -> void:
	for slot: String in VehicleLivery.SLOTS:
		(pickers[slot] as ColorPickerButton).color = Color(str(draft.colors[slot]))

func _reset() -> void:
	draft = VehicleLivery.defaults(vehicle_id)
	showroom.apply_livery(draft)
	_update_pickers()
	_save()
