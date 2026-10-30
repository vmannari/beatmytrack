extends ConfirmationDialog
## Rotation is staged here; Apply creates one ordinary editor undo step.

const STEP: float = 22.5
var angle: float = 0.0
var free_rotation: bool = false
var presets: Array[Button] = []
var free_button: Button
var slider: HSlider
var field: SpinBox
var _syncing_field: bool = false

static func next_angle(current: float) -> float:
	return fposmod((floorf(fposmod(current,360.0)/STEP)+1.0)*STEP,360.0)

static func angle_text(value: float) -> String:
	return String.num(fposmod(value,360.0),2).trim_suffix(".0")+"°"

func _ready() -> void:
	name = "ObjectRotationDialog"
	title = "Object rotation"
	ok_button_text = "Apply"
	angle = fposmod(angle,360.0)
	free_rotation = not is_equal_approx(angle,snappedf(angle,STEP))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	add_child(content)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	content.add_child(grid)
	for index: int in range(16):
		var value: float = index*STEP
		var button: Button = EditorStyle.button(angle_text(value),func() -> void:
			free_rotation = false
			_set_angle(value))
		button.name = "Orientation_"+str(index)
		button.toggle_mode = true
		EditorStyle.apply(button)
		button.custom_minimum_size = Vector2(84,44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		presets.append(button)
	free_button = EditorStyle.button("Free rotation",func() -> void:
		free_rotation = true
		_refresh())
	free_button.name = "FreeRotation"
	free_button.toggle_mode = true
	EditorStyle.apply(free_button)
	free_button.custom_minimum_size.y = 44
	content.add_child(free_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	content.add_child(row)
	slider = HSlider.new()
	slider.name = "RotationSlider"
	slider.max_value = 360.0
	slider.step = 0.0
	slider.custom_minimum_size = Vector2(180,48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_set_angle)
	row.add_child(slider)
	field = SpinBox.new()
	field.name = "RotationAngle"
	field.max_value = 360.0
	field.step = 0.01
	field.suffix = "°"
	field.custom_minimum_size = Vector2(130,48)
	field.value_changed.connect(func(value: float) -> void:
		if not _syncing_field: _set_angle(value))
	row.add_child(field)
	_refresh()

func _set_angle(value: float) -> void:
	angle = fposmod(value,360.0)
	_refresh()

func _refresh() -> void:
	for index: int in range(presets.size()):
		var chosen: bool = not free_rotation and is_equal_approx(angle,index*STEP)
		presets[index].set_pressed_no_signal(chosen)
	free_button.set_pressed_no_signal(free_rotation)
	slider.editable = free_rotation
	field.editable = free_rotation
	slider.set_value_no_signal(angle)
	_syncing_field = true
	field.value = angle
	# SpinBox retains its edit buffer while focused; slider/preset changes must
	# also replace that buffer so Apply cannot restore the previous angle.
	field.get_line_edit().text = String.num(angle,2)+" "+field.suffix
	_syncing_field = false
