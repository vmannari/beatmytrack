extends PopupPanel
## Shared, contextual inspector for placement defaults and placed objects.
## Each edit is a discrete action; opening or closing never resets defaults.
signal edited(property: String, value: Variant)
signal fit_requested

const MUTED := Color("a8bdc4")
const MODES: Array[String] = ["single","line","curve","road edge"]
const MODE_LABELS: Array[String] = ["Single","Straight line","Curve","Road edge"]
const MODE_HELP: Array[String] = ["Tap empty ground to place one object.","Drag a straight run, or tap its two ends.","Draw a curve. Release to place the whole run.","Drag beside a road to follow its edge. A road is required."]
var state: Dictionary = {}
var selected: bool = false
var body: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var size_readout: Label
var placement_hint: Label
var angle_field: SpinBox
var size_field: SpinBox
var width_field: SpinBox
var diagram: OrientationDiagram
var size_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var orientation_controls: VBoxContainer
var orientation_help: Label
var orientation_section: VBoxContainer
var _syncing: bool = false

class OrientationDiagram extends Control:
	var angle: float = 0.0
	func _draw() -> void:
		var center: Vector2 = size*0.5
		draw_circle(center,34,Color("12242d"))
		draw_circle(center,34,Color("47606b"),false,1,true)
		for index: int in range(16):
			var axis := Vector2(cos(index*TAU/16),-sin(index*TAU/16))
			draw_line(center+axis*29,center+axis*34,Color("6c8792"),2 if index%4 == 0 else 1,true)
		var forward := Vector2(cos(deg_to_rad(angle)),-sin(deg_to_rad(angle)))
		var normal := Vector2(-forward.y,forward.x)
		draw_line(center-forward*19,center+forward*19,EditorStyle.ACCENT,4,true)
		draw_colored_polygon(PackedVector2Array([center+forward*25,center+forward*10+normal*8,center+forward*10-normal*8]),EditorStyle.INK)
		draw_circle(center,4,EditorStyle.INK)

class PlacementDiagram extends Control:
	var mode: String
	func _draw() -> void:
		var center: Vector2 = size*0.5
		var ink: Color = EditorStyle.ACCENT
		if mode == "single":
			draw_rect(Rect2(center-Vector2(7,6),Vector2(14,12)),ink,false,2)
			return
		var points := PackedVector2Array()
		for index: int in range(7):
			var x: float = -32+index*10.6667
			points.append(center+Vector2(x,8*sin(float(index)/6*PI) if mode in ["curve","road edge"] else 0.0))
		if mode == "road edge":
			draw_polyline(points,Color("4a626c"),13,true)
			for index: int in range(points.size()): points[index].y -= 12
		draw_polyline(points,ink,2,true)
		for point: Vector2 in points: draw_circle(point,3,EditorStyle.INK)

func _ready() -> void:
	name = "ObjectOptionsPopup"
	# Keep the editor's restrained surfaces instead of the general scenic dialog.
	set_meta("menu_popup_custom",true)
	var surface: StyleBoxFlat = EditorStyle.panel()
	surface.bg_color = Color("101e27")
	surface.set_content_margin_all(16)
	surface.border_color = Color("425b67")
	add_theme_stylebox_override("panel",surface)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var overline: Label = _label("Selected object" if selected else "Placement properties",15,true)
	overline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(overline)
	var close: Button = _button("×",_finish)
	close.name = "CloseProperties"
	close.tooltip_text = "Close properties"
	close.custom_minimum_size = Vector2(44,44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size",24)
	top.add_child(close)
	var display_kind: String = str(state.get("display_kind",state.kind))
	var family: Array = CreatorCatalog.family(display_kind)
	var object_title: String = str(family[1]) if not family.is_empty() and family[3].size() == 1 else CreatorCatalog.label(display_kind)
	heading = _label(object_title,26)
	heading.name = "ObjectPropertiesTitle"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var behavior: Label = _label(CreatorCatalog.behavior(str(state.kind)),15,true)
	behavior.name = "ObjectBehavior"
	if state.kind == "jump": behavior.text = JumpProfiles.description(str(state.jump_profile))
	behavior.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(behavior)
	scroll = ScrollContainer.new()
	scroll.name = "PropertyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	_build_fields()
	var done: Button = _button("Done",_finish)
	done.name = "DoneProperties"
	EditorStyle.apply(done,true)
	column.add_child(done)
	popup_hide.connect(_commit_fields)
	get_parent().get_viewport().size_changed.connect(_layout)

func _label(caption: String, font_size: int, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font",EditorStyle.FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",MUTED if muted else EditorStyle.INK)
	return label

func _button(caption: String, action: Callable) -> Button:
	var button: Button = EditorStyle.button(caption,action)
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _section(caption: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = EditorStyle.box()
	style.bg_color = Color("192d37")
	style.shadow_size = 0
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	body.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	content.add_child(_label(caption,18))
	return content

func _number(parent: Node, value: float, minimum: float, maximum: float, step: float, suffix: String, node_name: String) -> SpinBox:
	var field := SpinBox.new()
	field.name = node_name
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.suffix = suffix
	field.value = value
	field.custom_minimum_size = Vector2(110,48)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_override("font",EditorStyle.FONT)
	field.add_theme_font_size_override("font_size",18)
	EditorStyle.apply(field.get_line_edit())
	parent.add_child(field)
	return field

func _build_fields() -> void:
	var kind: String = str(state.kind)
	var family: Array = CreatorCatalog.family(kind)
	if not selected and not family.is_empty() and family[3].size()>1:
		var variant_section: VBoxContainer = _section("Variant")
		var variants := OptionButton.new()
		variants.name = "ObjectVariant"
		variants.custom_minimum_size.y = 48
		EditorStyle.apply(variants)
		for variant: String in family[3]: variants.add_item(CreatorCatalog.label(variant))
		variants.select(family[3].find(kind))
		variants.item_selected.connect(func(index: int) -> void: edited.emit("kind",family[3][index]))
		variant_section.add_child(variants)
	if not selected and kind in CreatorCatalog.LINES:
		var placement: VBoxContainer = _section("Placement mode")
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		placement.add_child(grid)
		for index: int in range(MODES.size()):
			var button: Button = _button("",func() -> void: _change_mode(MODES[index]))
			button.name = "Placement_"+MODES[index].replace(" ","_")
			button.tooltip_text = MODE_HELP[index]
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(0,84)
			var illustration := PlacementDiagram.new()
			illustration.mode = MODES[index]
			illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
			illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			illustration.offset_bottom = -28
			button.add_child(illustration)
			var caption: Label = _label(MODE_LABELS[index],16)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(caption)
			caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			caption.offset_top = -29
			caption.offset_bottom = -5
			grid.add_child(button)
			mode_buttons.append(button)
		placement_hint = _label("",15,true)
		placement_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placement.add_child(placement_hint)
	if kind == "speed_bump":
		var width: VBoxContainer = _section("Width")
		width_field = _number(width,float(state.get("span",8.0)),SpeedBumpEdit.MIN_SPAN,SpeedBumpEdit.MAX_SPAN,0.25,"m","SpeedBumpWidth")
		width_field.value_changed.connect(func(value: float) -> void: _edit("span",value))
		if selected:
			var fit: Button = _button("Fit road width",func() -> void: fit_requested.emit())
			fit.name = "FitRoadWidth"
			width.add_child(fit)
	elif (selected and kind not in ["tyre_wall","tyre_stack"]) or (not selected and kind not in CreatorCatalog.LINES):
		var sizing: VBoxContainer = _section("Size")
		var sizes := HBoxContainer.new()
		sizes.add_theme_constant_override("separation",6)
		sizing.add_child(sizes)
		var presets: Array[float] = CreatorCatalog.size_presets(kind)
		for index: int in range(3):
			var button: Button = _button(["Small","Medium","Large"][index],func() -> void: _edit("scale",presets[index]))
			button.name = "ObjectSize_"+str(index)
			button.toggle_mode = true
			sizes.add_child(button)
			size_buttons.append(button)
		if selected:
			size_field = _number(sizing,float(state.get("scale",1.0)),0.5,1.5 if kind in CreatorCatalog.DECORATIVE else 3.0,0.25,"×","ObjectSize")
			size_field.value_changed.connect(func(value: float) -> void: _edit("scale",value))
		size_readout = _label("",15,true)
		size_readout.name = "ObjectDimensions"
		sizing.add_child(size_readout)
	var orientation: VBoxContainer = _section("Orientation")
	orientation_section = orientation
	orientation_controls = VBoxContainer.new()
	orientation_controls.add_theme_constant_override("separation",10)
	orientation.add_child(orientation_controls)
	var orientation_row := HBoxContainer.new()
	orientation_row.add_theme_constant_override("separation",8)
	orientation_controls.add_child(orientation_row)
	diagram = OrientationDiagram.new()
	diagram.name = "OrientationPreview"
	diagram.custom_minimum_size = Vector2(76,76)
	diagram.tooltip_text = "Top view: 0° points right; 90° points up."
	orientation_row.add_child(diagram)
	var left: Button = _button("−",func() -> void: _edit("rotation",fposmod(float(state.rotation)-22.5,360.0)))
	left.name = "TurnLeft"
	left.tooltip_text = "Turn by −22.5°"
	left.custom_minimum_size.x = 44
	left.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orientation_row.add_child(left)
	angle_field = _number(orientation_row,float(state.rotation),0,360,0.01,"°","RotationAngle")
	angle_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	angle_field.value_changed.connect(func(value: float) -> void: _edit("rotation",fposmod(value,360.0)))
	var right: Button = _button("+",func() -> void: _edit("rotation",fposmod(float(state.rotation)+22.5,360.0)))
	right.name = "TurnRight"
	right.tooltip_text = "Turn by +22.5°"
	right.custom_minimum_size.x = 44
	right.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orientation_row.add_child(right)
	var cardinals := HBoxContainer.new()
	cardinals.add_theme_constant_override("separation",6)
	orientation_controls.add_child(cardinals)
	for value: int in [0,90,180,270]:
		var cardinal: Button = _button(str(value)+"°",func() -> void: _edit("rotation",float(value)))
		cardinal.name = "Face_"+str(value)
		cardinals.add_child(cardinal)
	orientation_help = _label("Use − / + for 22.5° steps, or type any angle.",15,true)
	orientation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orientation.add_child(orientation_help)
	if kind == "container":
		var paint: VBoxContainer = _section("Paint colour")
		paint.add_child(ContainerColorButton.make(str(state.get("color",ContainerPaint.DEFAULT)),func(value: String) -> void: _edit("color",value)))
	_sync()

func _change_mode(mode: String) -> void:
	_edit("placement",mode)

func _edit(property: String, value: Variant) -> void:
	if _syncing or state.get(property) == value: return
	state[property] = value
	_sync()
	edited.emit(property,value)

func _sync() -> void:
	_syncing = true
	if is_instance_valid(size_readout):
		var dimensions: Vector2 = CreatorObjects.size_of(state)
		size_readout.text = GameText.message("%.2f× · %.1f × %.1f m") % [float(state.get("scale",1.0)),dimensions.x,dimensions.y]
	var presets: Array[float] = CreatorCatalog.size_presets(str(state.kind))
	for index: int in range(size_buttons.size()):
		var chosen: bool = is_equal_approx(float(state.get("scale",1.0)),presets[index])
		size_buttons[index].set_pressed_no_signal(chosen)
		EditorStyle.apply(size_buttons[index],chosen)
	for index: int in range(mode_buttons.size()):
		var chosen: bool = state.get("placement","single") == MODES[index]
		mode_buttons[index].set_pressed_no_signal(chosen)
		EditorStyle.apply(mode_buttons[index],chosen)
	if is_instance_valid(placement_hint): placement_hint.text = GameText.message(MODE_HELP[maxi(0,MODES.find(str(state.get("placement","single"))))])
	if is_instance_valid(angle_field):
		angle_field.set_value_no_signal(float(state.rotation))
		diagram.angle = float(state.rotation)
		diagram.queue_redraw()
		var along_run: bool = not selected and state.get("placement","single") != "single"
		angle_field.editable = not along_run
		orientation_controls.visible = not along_run
		orientation_section.get_parent().visible = not along_run
		orientation_help.text = "Orientation follows the run automatically." if along_run else "Use − / + for 22.5° steps, or type any angle."
		for node_name: String in ["TurnLeft","TurnRight","Face_0","Face_90","Face_180","Face_270"]:
			(find_child(node_name,true,false) as Button).disabled = along_run
		if along_run: placement_hint.text += "\n"+GameText.message("Orientation follows the run automatically.")
	if is_instance_valid(size_field): size_field.set_value_no_signal(float(state.get("scale",1.0)))
	if is_instance_valid(width_field): width_field.set_value_no_signal(float(state.get("span",8.0)))
	_syncing = false
	_layout.call_deferred()

func _commit_fields() -> void:
	for field: SpinBox in [angle_field,size_field,width_field]:
		if is_instance_valid(field) and field.editable: field.apply()

func _finish() -> void:
	_commit_fields()
	hide()

func open(anchor: Rect2) -> void:
	set_meta("anchor",anchor)
	_layout()
	popup()
	_layout.call_deferred()
	(find_child("CloseProperties",true,false) as Button).grab_focus.call_deferred()

func _layout() -> void:
	if not is_inside_tree(): return
	var extent: Vector2 = get_parent().get_viewport().get_visible_rect().size
	var width: float = minf(420,extent.x-24)
	var chrome_height: float = (scroll.get_parent() as Control).get_combined_minimum_size().y+32
	var height: float = minf(minf(650,extent.y-40),chrome_height+body.get_combined_minimum_size().y)
	# Fixed chrome, flexible body: short landscape screens scroll only the fields.
	scroll.custom_minimum_size = Vector2(width-32,0)
	size = Vector2i(int(width),int(height))
	var anchor: Rect2 = get_meta("anchor",Rect2(extent,Vector2.ZERO))
	position = Vector2i(int(clampf(anchor.end.x-size.x,12,maxf(12,extent.x-size.x-12))),int(clampf(anchor.position.y-size.y-10,20,maxf(20,extent.y-size.y-20))))
