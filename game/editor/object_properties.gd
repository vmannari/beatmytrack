extends HBoxContainer
## Road-style, nonmodal object controls. The map stays available while editing.
signal edited(property: String, value: Variant)
signal editing_changed(property: String)
signal fit_requested

var state: Dictionary = {}
var selected: bool = false
var editing: String = ""
var field: SpinBox
var _revision: int = 0

func show_state(values: Dictionary, is_selected: bool, property: String) -> void:
	_revision += 1
	state = values
	selected = is_selected
	editing = property
	field = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation",6)
	if editing in ["scale","rotation","span"]: _adjustment()
	else: _overview()

func _action(caption: String, glyph: String, action: Callable, node_name: String, chosen: bool = false) -> Button:
	var revision: int = _revision
	var button: Button = EditorButton.make(caption,glyph,func() -> void:
		if revision == _revision: action.call(),chosen)
	button.name = node_name
	button.focus_mode = Control.FOCUS_ALL
	EditorStyle.card(button,chosen)
	add_child(button)
	return button

func _edit(property: String, value: Variant) -> void:
	if state.get(property) == value: return
	edited.emit(property,value)

func _overview() -> void:
	var kind: String = str(state.kind)
	var multiple: bool = bool(state.get("multiple",false))
	var family: Array = CreatorCatalog.family(str(state.get("display_kind",kind)))
	if not selected and not family.is_empty() and family[3].size() > 1:
		var variant := OptionButton.new()
		variant.name = "ObjectVariant"
		variant.custom_minimum_size = Vector2(110,68)
		EditorStyle.apply(variant)
		for choice: String in family[3]: variant.add_item(CreatorCatalog.label(choice))
		variant.select(maxi(0,family[3].find(kind)))
		var revision: int = _revision
		variant.item_selected.connect(func(index: int) -> void:
			if revision == _revision: _edit("kind",family[3][index]))
		add_child(variant)
	if not multiple:
		if kind == "speed_bump":
			var width: Button = _action(GameText.message("%.1f m") % float(state.get("span",8.0)),"width",func() -> void: editing_changed.emit("span"),"ObjectWidth")
			width.tooltip_text = "Width"
		elif (selected and kind not in ["tyre_wall","tyre_stack"]) or (not selected and kind not in CreatorCatalog.LINES):
			var size_button: Button = _action(GameText.message("%.2f×") % float(state.get("scale",1.0)),"size",func() -> void: editing_changed.emit("scale"),"ObjectSizeControl")
			size_button.tooltip_text = GameText.message("Size")+" / "+_dimensions()
	var automatic: bool = not selected and state.get("placement","single") != "single"
	var orientation: Button = _action("Auto" if automatic else preload("res://editor/object_rotation.gd").angle_text(float(state.rotation)),"rotate",func() -> void: editing_changed.emit("rotation"),"ObjectOrientation")
	orientation.disabled = automatic
	orientation.tooltip_text = "Orientation follows the run automatically." if automatic else "Orientation"
	if not selected and kind in CreatorCatalog.LINES:
		for pair: Array in [["single","Single","place_single"],["line","Line","place_line"],["curve","Curve","place_curve"],["road edge","Road edge","place_edge"]]:
			var value: String = pair[0]
			_action(pair[1],pair[2],func() -> void: _edit("placement",value),"Placement_"+value.replace(" ","_"),state.get("placement","single") == value)
	if selected and kind == "speed_bump" and not multiple:
		_action("Fit road","snap",func() -> void: fit_requested.emit(),"FitRoadWidth")
	if kind == "container" and not multiple:
		var revision: int = _revision
		add_child(ContainerColorButton.make(str(state.get("color",ContainerPaint.DEFAULT)),func(value: String) -> void:
			if revision == _revision: _edit("color",value)))

func _adjustment() -> void:
	_action("Back","back",_finish,"ObjectControlsBack")
	var step: float = 22.5 if editing == "rotation" else 0.25
	var value: float = float(state.get(editing,1.0))
	var minimum: float = 0.0 if editing == "rotation" else SpeedBumpEdit.MIN_SPAN if editing == "span" else 0.5
	var maximum: float = 360.0 if editing == "rotation" else SpeedBumpEdit.MAX_SPAN if editing == "span" else 1.5 if state.kind in CreatorCatalog.DECORATIVE else 3.0
	var decrement: Button = _action("−22.5°" if editing == "rotation" else "−0.25 m" if editing == "span" else "−0.25×","minus",func() -> void: _step(-step,minimum,maximum),"ObjectDecrease")
	decrement.custom_minimum_size.x = 76
	decrement.disabled = editing != "rotation" and value <= minimum
	var group := VBoxContainer.new()
	group.custom_minimum_size.x = 142
	group.add_theme_constant_override("separation",1)
	add_child(group)
	var title: Label = MenuStyle.label("Orientation" if editing == "rotation" else "Width" if editing == "span" else "Size",14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(title)
	field = SpinBox.new()
	field.name = "RotationAngle" if editing == "rotation" else "SpeedBumpWidth" if editing == "span" else "ObjectSize"
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.01 if editing == "rotation" else step
	field.value = value
	field.suffix = "°" if editing == "rotation" else "m" if editing == "span" else "×"
	field.custom_minimum_size = Vector2(142,48)
	EditorStyle.apply(field.get_line_edit())
	group.add_child(field)
	var revision: int = _revision
	var property: String = editing
	field.value_changed.connect(func(number: float) -> void:
		if revision == _revision: _edit(property,fposmod(number,360.0) if property == "rotation" else number))
	var increment: Button = _action("+22.5°" if editing == "rotation" else "+0.25 m" if editing == "span" else "+0.25×","plus",func() -> void: _step(step,minimum,maximum),"ObjectIncrease")
	increment.custom_minimum_size.x = 76
	increment.disabled = editing != "rotation" and value >= maximum
	if editing == "rotation":
		for number: int in [0,90,180,270]:
			_action(str(number)+"°","rotate",func() -> void: _edit("rotation",float(number)),"Face_"+str(number),is_equal_approx(value,float(number)))
	elif editing == "scale":
		var presets: Array[float] = CreatorCatalog.size_presets(str(state.kind))
		for index: int in range(presets.size()):
			var caption: String = str(int(presets[index]*8))+" m" if state.kind == "cliff" else ["Small","Medium","Large"][index]
			_action(caption,"size",func() -> void: _edit("scale",presets[index]),"ObjectSize_"+str(index),is_equal_approx(value,presets[index]))
	elif editing == "span" and selected:
		_action("Fit road","snap",func() -> void: fit_requested.emit(),"FitRoadWidth")

func _dimensions() -> String:
	var dimensions: Vector2 = CreatorObjects.size_of(state)
	return GameText.message("%.1f × %.1f m") % [dimensions.x,dimensions.y]

func _step(delta: float, minimum: float, maximum: float) -> void:
	var number: float = float(state.get(editing,1.0))+delta
	_edit(editing,fposmod(number,360.0) if editing == "rotation" else clampf(number,minimum,maximum))

func _finish() -> void:
	if is_instance_valid(field): field.apply()
	editing_changed.emit("")
