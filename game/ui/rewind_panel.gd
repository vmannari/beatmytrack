extends CanvasLayer
signal selected(index: int)
signal confirmed
signal cancelled
const GOLD := Color("ffd15c")
const INK := Color("091316ee")
var slider: HSlider
var heading: Label
var details: Label
var status: Label
var confirm: Button
var cancel: Button
var race_uses: Control
var root: Control
var window_label: Label
var map: HUDRoadMap
var overlay: Control
var scene_camera: Camera3D
var history_labels: Array[Dictionary] = []
var selected_world := Vector3.ZERO
var selected_seconds: float = 0.0
var now_tick: int = 0
var funded: bool = false
var busy: bool = false
var entry_ticks: Array[int] = []

class Timeline extends HSlider:
	var caption: String = ""
	var earliest_seconds: float = -10.0
	func _draw() -> void:
		var left: float = 12.0
		var right: float = size.x-12.0
		var y: float = size.y*0.5
		var position_x: float = lerpf(left,right,(value-min_value)/(max_value-min_value))
		draw_line(Vector2(left,y),Vector2(right,y),Color("364145"),8,true)
		var available_x: float = lerpf(left,right,(earliest_seconds-min_value)/(max_value-min_value))
		draw_line(Vector2(left,y),Vector2(available_x,y),Color("1e282c"),8,true)
		draw_line(Vector2(position_x,y),Vector2(right,y),Color("b78e3b"),8,true)
		for i: int in range(11):
			var x: float = lerpf(left,right,i/10.0)
			draw_line(Vector2(x,y-12),Vector2(x,y+12),Color("72808855"),1,true)
			if i > 0 and i < 10: draw_line(Vector2(x,y-4),Vector2(x,y+4),Color("5596b3"),4,true)
		draw_line(Vector2(position_x,y-15),Vector2(position_x,y+20),Color("ffd15c"),2,true)
		draw_circle(Vector2(position_x,y),8,Color("ffd15c"))
		var width: float = 74
		var bubble := Rect2(Vector2(clampf(position_x-width*0.5,0,size.x-width),y-47),Vector2(width,28))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0c171cee")
		style.border_color = Color("748186")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		draw_style_box(style,bubble)
		var text_width: float = RaceHUDStyle.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(RaceHUDStyle.BODY,Vector2(bubble.get_center().x-text_width*0.5,bubble.position.y+20),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

class ResumeButton extends Button:
	const AD_ICON: Texture2D = preload("res://ui/icons/rewarded_ad.svg")
	var count: int = 0
	var use_ad: bool = true
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var c: Vector2 = size*0.5
		var ink := Color("ffd15c")
		if disabled: ink.a = 0.3
		draw_arc(c,30,0,TAU,64,ink,3,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-6,-11),c+Vector2(11,0),c+Vector2(-6,11)]),ink)
		var badge_center: Vector2 = c+Vector2(22,23)
		if use_ad:
			draw_texture_rect(AD_ICON,Rect2(badge_center-Vector2(18,15),Vector2(36,30)),false,Color(1,1,1,0.35 if disabled else 1.0))
		else:
			var caption: String = str(count)
			var width: float = RaceHUDStyle.DISPLAY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
			var badge := StyleBoxFlat.new()
			badge.bg_color = Color("092438")
			badge.border_color = ink
			badge.set_border_width_all(1)
			badge.set_corner_radius_all(14)
			draw_style_box(badge,Rect2(badge_center-Vector2(maxf(28,width+12)*0.5,14),Vector2(maxf(28,width+12),28)))
			draw_string(RaceHUDStyle.DISPLAY,badge_center+Vector2(-width*0.5,7),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20,ink)

class RaceUses extends Control:
	var remaining: int = 3
	func _draw() -> void:
		for i: int in range(3):
			var center := Vector2(12+i*29,size.y*0.5)
			if i < remaining: draw_circle(center,8,Color("24bceb"))
			draw_arc(center,8,0,TAU,32,Color("69c8e5"),1.5,true)
		var caption: String = "%d left this race" % remaining if remaining > 0 else "Race limit reached"
		draw_string(RaceHUDStyle.BODY,Vector2(99,size.y*0.5+6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d2e2e7"))

class WorldLabels extends Control:
	var panel: CanvasLayer
	func _draw() -> void:
		if panel.scene_camera == null: return
		var forbidden := Rect2(Vector2(0,size.y-205),Vector2(size.x,205))
		for item: Dictionary in panel.history_labels:
			if panel.scene_camera.is_position_behind(item.world): continue
			var point: Vector2 = panel.scene_camera.unproject_position(item.world)+Vector2(-20,28)
			if point.x < 24 or point.x > size.x-70 or point.y < 115 or point.y > size.y-205 or forbidden.has_point(point): continue
			var caption: String = "−%.1f s" % float(item.seconds)
			draw_string_outline(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color("071015"))
			draw_string(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3ddeb"))

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = RaceHUDStyle.theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float edge=0.48*pow(abs(UV.x-0.5)*2.0,6.0)+0.65*pow(UV.y,5.0)+0.20*pow(1.0-UV.y,5.0); COLOR=vec4(0.015,0.025,0.025,edge); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	root.add_child(shade)
	overlay = WorldLabels.new()
	overlay.panel = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	heading = _label(root,"REWIND",58)
	heading.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	heading.position = Vector2(30,18)
	var lower := PanelContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_left = 40; lower.offset_right = -40
	lower.offset_top = -194; lower.offset_bottom = -18
	lower.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lower.add_theme_stylebox_override("panel",_style(INK,Color("34404499"),26))
	root.add_child(lower)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",18)
	lower.add_child(columns)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(box)
	var information := HBoxContainer.new()
	box.add_child(information)
	details = _label(information,"",16)
	_space(information)

	var timeline_row := HBoxContainer.new()
	timeline_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_row.add_theme_constant_override("separation",10)
	box.add_child(timeline_row)
	cancel = _button(timeline_row,"Cancel",func() -> void: cancelled.emit())
	cancel.custom_minimum_size.x = 90
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window_label = _label(timeline_row,"−10 s",17)
	window_label.custom_minimum_size.x = 58
	window_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider = Timeline.new()
	slider.name = "RewindTimeline"
	slider.custom_minimum_size = Vector2(0,96)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_FILL
	slider.min_value = -10.0
	slider.max_value = 0.0
	slider.step = 0.001
	for key: String in ["slider","grabber_area","grabber_area_highlight"]: slider.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	var empty := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	empty.gradient = gradient
	empty.width = 24; empty.height = 24
	for key: String in ["grabber","grabber_highlight","grabber_disabled"]: slider.add_theme_icon_override(key,empty)
	slider.add_theme_constant_override("grabber_offset",0)
	slider.value_changed.connect(_select_seconds)
	timeline_row.add_child(slider)
	_label(timeline_row,"0 s",17).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm = ResumeButton.new()
	confirm.name = "ResumeHere"
	# Keep the drawn circle centered in a wider hit area, with breathing room
	# between the time label, resource badge and right-side divider.
	confirm.custom_minimum_size = Vector2(116,64)
	confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm.tooltip_text = "Resume from selected position"
	for state: String in ["normal","hover","pressed"]: confirm.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	confirm.pressed.connect(func() -> void: confirmed.emit())
	confirm.disabled = true
	timeline_row.add_child(confirm)
	var divider := VSeparator.new()
	columns.add_child(divider)
	var resources := VBoxContainer.new()
	resources.custom_minimum_size.x = 270
	resources.add_theme_constant_override("separation",8)
	columns.add_child(resources)
	var resource_title := _label(resources,"RESUMES",22)
	resource_title.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	race_uses = RaceUses.new()
	race_uses.custom_minimum_size = Vector2(0,28)
	race_uses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resources.add_child(race_uses)
	status = _label(box,"",14)
	status.hide()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map = HUDRoadMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	map.position = Vector2(26,-330)
	map.size = Vector2(164,124)
	root.add_child(map)

func configure(entries: Array[Dictionary], tick: int, camera: Camera3D, track: NativeTrack) -> void:
	now_tick = tick
	scene_camera = camera
	entry_ticks.clear()
	for entry: Dictionary in entries: entry_ticks.append(int(entry.tick))
	slider.earliest_seconds = (entry_ticks[0]-now_tick)/120.0
	window_label.text = "−10 s"
	map.configure(track,track.metadata.has("creator_document"))

func select_index(index: int) -> void:
	var tick: int = entry_ticks[index] if index < entry_ticks.size() else now_tick
	slider.set_value_no_signal((tick-now_tick)/120.0)
	slider.queue_redraw()

func _select_seconds(seconds: float) -> void:
	var target_tick: float = now_tick+seconds*120.0
	var nearest: int = entry_ticks.size()
	var distance: float = absf(target_tick-now_tick)
	for index: int in range(entry_ticks.size()):
		var candidate: float = absf(target_tick-entry_ticks[index])
		if candidate < distance:
			distance = candidate
			nearest = index
	select_index(nearest)
	selected.emit(nearest)

func show_moment(state: VehicleState, session: TrackSession, labels: Array[Dictionary], world: Vector3, live: bool) -> void:
	selected_seconds = (now_tick-state.tick)/120.0
	details.text = "LAP %d / %d   ·   %.2f s" % [session.completed_laps+1,session.target_laps,session.race_time_seconds()]
	slider.caption = "0.0 s" if live else "−%.1f s" % selected_seconds
	slider.queue_redraw()
	history_labels = labels
	selected_world = world
	map.player = state.position
	map.queue_redraw()
	confirm.disabled = busy or not funded or live
	overlay.queue_redraw()

func _process(_delta: float) -> void:
	status.visible = not status.text.is_empty()
	confirm.queue_redraw()
	overlay.queue_redraw()

func show_balance(wallet: Dictionary, used: int) -> void:
	var banked: int = int(wallet.get("balance",0))
	var daily: int = int(wallet.get("free",0))
	var preview: bool = bool(wallet.get("ad_preview_available",false))
	confirm.count = banked
	confirm.use_ad = banked == 0
	race_uses.remaining = maxi(0,3-used)
	race_uses.queue_redraw()
	funded = used < 3 and (banked+daily > 0 or preview)
	confirm.disabled = busy or not funded or slider.value >= slider.max_value
	if not funded: status.text = "Three resumes used this race." if used >= 3 else "No resumes available."

func set_busy(value: bool) -> void:
	busy = value
	confirm.disabled = value or slider.value >= slider.max_value
	cancel.disabled = value
	slider.editable = not value

func lock_pending() -> void:
	slider.editable = false

func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = color
	value.border_color = border
	value.set_border_width_all(1)
	value.set_corner_radius_all(radius)
	value.set_content_margin_all(16)
	return value

func _label(parent: Node, text: String, font_size: int) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_color_override("font_color",RaceHUDStyle.TEXT)
	value.add_theme_font_size_override("font_size",font_size)
	parent.add_child(value)
	return value

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,48)
	button.add_theme_stylebox_override("normal",_style(Color("101b20bb"),Color("67717499"),24))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _space(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
