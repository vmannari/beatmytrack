extends Button
## Numbered Parts option, or a paint option led by a profile-style car.
var number: Label
var title: Label
var description: Label
var price: Label
var status: Label
var checkmark: TextureRect
var selected: bool = false
var car_icon: TextureRect
var icon_key: String = ""
var _row: HBoxContainer
var _separator: VSeparator
var _value: VBoxContainer

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 82
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var padding := MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge: String in ["left","right"]: padding.add_theme_constant_override("margin_"+edge,12)
	for edge: String in ["top","bottom"]: padding.add_theme_constant_override("margin_"+edge,12)
	add_child(padding)
	MenuStyle.fill(padding)
	var row := HBoxContainer.new()
	_row = row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",12)
	padding.add_child(row)
	number = _label("",28,true)
	number.custom_minimum_size.x = 30
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)
	var separator := VSeparator.new()
	_separator = separator
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(separator)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation",3)
	row.add_child(copy)
	title = _label("",23)
	title.name = "KitOptionTitle"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	description = _label("",14,true,false)
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(description)
	var value := VBoxContainer.new()
	_value = value
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.custom_minimum_size.x = 82
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_theme_constant_override("separation",4)
	row.add_child(value)
	var cost := HBoxContainer.new()
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.alignment = BoxContainer.ALIGNMENT_END
	value.add_child(cost)
	checkmark = TextureRect.new()
	checkmark.name = "EquippedCheck"
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkmark.texture = MenuIcon.texture("check")
	checkmark.modulate = Color("66c78b")
	checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checkmark.custom_minimum_size = Vector2(20,20)
	checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost.add_child(checkmark)
	price = _label("",23)
	price.add_theme_color_override("font_color",MenuStyle.ACCENT)
	cost.add_child(price)
	status = _label("",13)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_child(status)
	resized.connect(_layout)

func _label(copy: String, size: int, muted: bool = false, display: bool = true) -> Label:
	var label: Label = MenuStyle.label(copy,size,muted)
	if display: label.add_theme_font_override("font",MenuStyle.DISPLAY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func setup(index: int, option: Array, detail: String, action: Callable) -> void:
	name = "KitOption_"+str(option[0])
	number.text = "%02d" % (index+1)
	GameText.bind_upper(title,str(option[1]))
	GameText.bind(description,detail)
	accessibility_name = GameText.message(str(option[1]))+". "+GameText.message(detail)
	tooltip_text = accessibility_name
	pressed.connect(action)

func present(chosen: bool, equipped: bool, owned: bool, cost: int, previewing: bool = false) -> void:
	set_selected(chosen)
	checkmark.visible = equipped
	price.visible = not equipped and not owned
	price.text = "%s" % cost
	status.visible = equipped or owned or chosen
	GameText.bind_upper(status,"Previewing" if previewing else "Equipped" if equipped else "Previewing" if chosen else "Owned")
	status.add_theme_color_override("font_color",MenuStyle.ACCENT if previewing else Color("66c78b") if equipped else MenuStyle.ACCENT if chosen else MenuStyle.MUTED)
	accessibility_description = status.text+" "+(GameText.message("%d coins") % cost if price.visible else "")

func add_car_icon() -> void:
	car_icon = TextureRect.new()
	car_icon.name = "PaintCarIcon"
	car_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	car_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	car_icon.custom_minimum_size = Vector2(112,76)
	car_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	car_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var composite := ShaderMaterial.new()
	composite.shader = preload("res://ui/rivalry_car_composite.gdshader")
	composite.set_shader_parameter("linear_resolve",RenderingServer.get_current_rendering_method()!="gl_compatibility")
	car_icon.material = composite
	_row.add_child(car_icon)
	_row.move_child(car_icon,1)
	_row.add_theme_constant_override("separation",8)
	_separator.hide()
	number.hide()
	_value.custom_minimum_size.x = 64

func set_selected(chosen: bool) -> void:
	selected = chosen
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style: StyleBoxFlat = MenuStyle.box(Color("12212a") if state in ["hover","pressed","hover_pressed"] else Color.TRANSPARENT,0)
		style.set_corner_radius_all(5)
		style.border_color = MenuStyle.ACCENT if selected or state=="focus" else Color("344750")
		if selected or state=="focus": style.set_border_width_all(1)
		else: style.border_width_bottom = 1
		add_theme_stylebox_override(state,style)

func _layout() -> void:
	if not is_inside_tree(): return
	var compact: bool = get_viewport_rect().size.y<650 or size.x<410
	# Paint rows always reserve 100px; changing 100 -> 82 -> 100 on each
	# narrow layout pass repeatedly invalidates the surrounding containers.
	custom_minimum_size.y = 100 if car_icon != null or not compact else 82
	_set_font_size(title,20 if compact else 25)
	_set_font_size(description,13 if compact else 15)
	_set_font_size(number,25 if compact else 31)
	_set_font_size(price,21 if compact else 27)
	if car_icon!=null:
		car_icon.custom_minimum_size = Vector2(96,72) if compact else Vector2(112,76)


func _set_font_size(label: Label, value: int) -> void:
	if not label.has_theme_font_size_override("font_size") or label.get_theme_font_size("font_size") != value:
		label.add_theme_font_size_override("font_size",value)
