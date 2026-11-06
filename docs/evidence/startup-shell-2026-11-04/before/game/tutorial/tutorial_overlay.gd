extends Control
## Only the instruction card owns input. Floor markers and control outlines pass through.
signal primary_pressed
signal secondary_pressed
signal skip_pressed
var card: PanelContainer
var heading: Label
var copy: Label
var warning: Label
var primary: Button
var secondary: Button
var skip_button: Button
var shade: ColorRect
var mode: String = "welcome"
var key: String = ""
var outlines: Array[Rect2] = []
var camera: Camera3D
var floor_target := Vector2.INF
var floor_radius: float = 4.0
var safe_override := Rect2()
var avoid_rects: Array[Rect2] = []
var bottom_limit: float = INF
var _outline_style: StyleBoxFlat

func _ready() -> void:
	name = "TutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = MenuStyle.theme()
	shade = ColorRect.new()
	shade.color = Color("07121bb8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	card = PanelContainer.new()
	card.name = "TutorialCard"
	var surface: StyleBoxFlat = MenuStyle.box(Color("10232bf5"), 14)
	surface.border_color = MenuStyle.ACCENT
	surface.set_border_width_all(1)
	surface.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel",surface)
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	card.add_child(column)
	heading = MenuStyle.label("",22)
	heading.name = "TutorialHeading"
	heading.add_theme_color_override("font_color",MenuStyle.ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	copy = MenuStyle.label("",20)
	copy.name = "TutorialInstruction"
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(copy)
	warning = MenuStyle.label("Progress could not be saved. You can keep playing.",15,true)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(warning)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	column.add_child(actions)
	primary = MenuStyle.button("",func() -> void: primary_pressed.emit(),true)
	primary.name = "TutorialPrimary"
	secondary = MenuStyle.button("",func() -> void: secondary_pressed.emit())
	secondary.name = "TutorialSecondary"
	skip_button = MenuStyle.button("Skip tutorial",func() -> void: skip_pressed.emit())
	skip_button.name = "SkipTutorial"
	for button: Button in [primary,secondary,skip_button]:
		button.custom_minimum_size = Vector2(0,48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",17)
		actions.add_child(button)
	_outline_style = MenuStyle.box(Color.TRANSPARENT,8)
	_outline_style.border_color = MenuStyle.ACCENT
	_outline_style.set_border_width_all(3)
	resized.connect(_layout)
	card.minimum_size_changed.connect(_layout)
	hide()

func present(id: String, title: String, instruction: String, action: String = "", alternative: String = "", placement: String = "hall", skippable: bool = true, save_failed: bool = false) -> void:
	key = id
	mode = placement
	heading.text = title
	heading.visible = not title.is_empty()
	copy.text = instruction
	copy.visible = not instruction.is_empty()
	primary.text = action
	primary.visible = not action.is_empty()
	secondary.text = alternative
	secondary.visible = not alternative.is_empty()
	skip_button.visible = skippable
	warning.visible = save_failed
	shade.visible = placement == "welcome"
	show()
	_layout()
	_layout.call_deferred()

func clear() -> void:
	hide()
	key = ""
	outlines.clear()
	floor_target = Vector2.INF
	camera = null
	queue_redraw()

func _layout() -> void:
	if card == null: return
	var safe: Rect2 = safe_area()
	var width: float = minf(440,safe.size.x-32)
	card.size.x = width
	card.size.y = card.get_combined_minimum_size().y
	var top: float = safe.position.y+(106 if mode == "hall" else 162)
	var left: float = safe.position.x+(safe.size.x-width)*0.5
	if mode == "welcome": top = safe.position.y+(safe.size.y-card.size.y)*0.5
	elif mode == "context": top = safe.end.y-card.size.y-100
	elif mode == "results": left = safe.end.x-width-24
	if mode in ["hall","race"] and not avoid_rects.is_empty():
		var best := Vector2(left,top)
		var cost: float = _overlap(Rect2(best,card.size))
		for candidate_y: float in [safe.position.y+16,top,safe.get_center().y-card.size.y*0.5,safe.end.y-card.size.y-16]:
			for candidate_x: float in [left,safe.position.x+16,safe.end.x-width-16]:
				var candidate := Vector2(candidate_x,clampf(candidate_y,safe.position.y+16,maxf(safe.position.y+16,safe.end.y-card.size.y-16)))
				var overlap: float = _overlap(Rect2(candidate,card.size))
				if overlap < cost:
					cost = overlap
					best = candidate
		left = best.x
		top = best.y
	if mode == "results":
		var available_bottom: float = minf(safe.end.y-100,bottom_limit)
		for forbidden: Rect2 in avoid_rects:
			if Rect2(Vector2(left,top),card.size).intersects(forbidden):
				if forbidden.end.y+16+card.size.y <= available_bottom: top = forbidden.end.y+16
				else:
					left = safe.position.x+24
					top = minf(safe.position.y+280,available_bottom-card.size.y)
	card.position = Vector2(left,clampf(top,safe.position.y+16,maxf(safe.position.y+16,safe.end.y-card.size.y-16)))

func _overlap(rect: Rect2) -> float:
	var area: float = 0
	for forbidden: Rect2 in avoid_rects:
		var intersection: Rect2 = rect.intersection(forbidden.grow(8))
		if intersection.has_area(): area += intersection.get_area()
	return area

func safe_area() -> Rect2:
	var area := Rect2(Vector2.ZERO,size)
	if safe_override.has_area(): return area.intersection(safe_override)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var transform: Transform2D = (get_viewport().get_screen_transform()*get_global_transform_with_canvas()).affine_inverse()
		if physical.has_area(): area = area.intersection(transform*physical)
	return area

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	if not visible: return
	for rect: Rect2 in outlines:
		if rect.has_area(): draw_style_box(_outline_style,rect.grow(5))

func draw_floor(canvas: Control) -> void:
	if not visible: return
	if not is_instance_valid(camera) or not floor_target.is_finite(): return
	var world: Vector3 = VisualGeometry.world(floor_target)+Vector3(0,0.08,0)
	if camera.is_position_behind(world): return
	var center: Vector2 = camera.unproject_position(world)
	var bounds: Rect2 = safe_area().grow(-28)
	bounds.position.y = maxf(bounds.position.y,184)
	bounds.size.y = maxf(30,safe_area().end.y-160-bounds.position.y)
	if not bounds.has_point(center):
		var edge: Vector2 = center.clamp(bounds.position,bounds.end)
		if card.get_rect().grow(24).has_point(edge):
			edge.x = card.position.x-24 if center.x < size.x*0.5 else card.get_rect().end.x+24
		var direction: Vector2 = (center-size*0.5).normalized()
		canvas.draw_polyline(PackedVector2Array([edge-direction.rotated(0.6)*18,edge,edge-direction.rotated(-0.6)*18]),MenuStyle.ACCENT,4,true)
		return
	var points := PackedVector2Array()
	for index: int in range(41):
		var angle: float = TAU*index/40.0
		points.append(camera.unproject_position(world+Vector3(cos(angle)*floor_radius,0,sin(angle)*floor_radius)))
	canvas.draw_colored_polygon(points,Color(1,0.79,0.23,0.08))
	canvas.draw_polyline(points,MenuStyle.ACCENT,3,true)
	canvas.draw_circle(center,5,MenuStyle.ACCENT)
