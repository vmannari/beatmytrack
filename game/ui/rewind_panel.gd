extends CanvasLayer
signal selected(index: int)
signal confirmed
signal cancelled
const GOLD := Color("ffd15c")
const INK := Color("091316ee")
var slider: HSlider
var heading: Label
var details: Label
var credits: Label
var status: Label
var confirm: Button
var cancel: Button
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

class Timeline extends HSlider:
	var caption: String = ""
	func _draw() -> void:
		var left: float = 12.0
		var right: float = size.x-12.0
		var y: float = size.y-17.0
		var position_x: float = lerpf(left,right,float(value)/maxf(1.0,max_value))
		draw_line(Vector2(left,y),Vector2(right,y),Color("364145"),8,true)
		draw_line(Vector2(position_x,y),Vector2(right,y),Color("b78e3b"),8,true)
		for i: int in range(11):
			var x: float = lerpf(left,right,i/10.0)
			draw_line(Vector2(x,y-12),Vector2(x,y+12),Color("72808855"),1,true)
			if i > 0 and i < 10: draw_line(Vector2(x,y-4),Vector2(x,y+4),Color("5596b3"),4,true)
		draw_line(Vector2(position_x,y-15),Vector2(position_x,y+20),Color("ffd15c"),2,true)
		draw_circle(Vector2(position_x,y),8,Color("ffd15c"))
		var width: float = 74
		var bubble := Rect2(Vector2(clampf(position_x-width*0.5,0,size.x-width),0),Vector2(width,28))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0c171cee")
		style.border_color = Color("748186")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		draw_style_box(style,bubble)
		var text_width: float = RaceHUDStyle.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(RaceHUDStyle.BODY,Vector2(bubble.get_center().x-text_width*0.5,20),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

class ResumeButton extends Button:
	func _draw() -> void:
		var c: Vector2 = size*0.5
		var ink := Color("ffd15c")
		if disabled: ink.a = 0.3
		draw_arc(c,30,0,TAU,64,ink,3,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-6,-11),c+Vector2(11,0),c+Vector2(-6,11)]),ink)

class WorldLabels extends Control:
	var panel: CanvasLayer
	func _draw() -> void:
		if panel.scene_camera == null: return
		var forbidden := Rect2(Vector2(0,size.y-145),Vector2(size.x,145))
		for item: Dictionary in panel.history_labels:
			if panel.scene_camera.is_position_behind(item.world): continue
			var point: Vector2 = panel.scene_camera.unproject_position(item.world)+Vector2(-20,28)
			if point.x < 24 or point.x > size.x-70 or point.y < 115 or point.y > size.y-145 or forbidden.has_point(point): continue
			var caption: String = "−%.1f s" % float(item.seconds)
			draw_string_outline(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color("071015"))
			draw_string(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3ddeb"))
		var marker: Vector2 = panel.scene_camera.unproject_position(panel.selected_world)+Vector2(30,-36)
		if not forbidden.has_point(marker) and marker.y < size.y-145:
			draw_colored_polygon(PackedVector2Array([marker+Vector2(-3,8),marker+Vector2(5,8),marker+Vector2(1,16)]),Color("ffd15c"))
			var caption: String = "CURRENT" if is_zero_approx(panel.selected_seconds) else "RESUME HERE"
			draw_string_outline(RaceHUDStyle.DISPLAY,marker,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,19,3,Color("071015"))
			draw_string(RaceHUDStyle.DISPLAY,marker,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("ffd15c"))

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
	lower.offset_top = -138; lower.offset_bottom = -18
	lower.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lower.add_theme_stylebox_override("panel",_style(INK,Color("34404499"),26))
	root.add_child(lower)
	var box := VBoxContainer.new()
	lower.add_child(box)
	var information := HBoxContainer.new()
	box.add_child(information)
	details = _label(information,"",16)
	_space(information)
	credits = _label(information,"Checking resumes...",15)
	var timeline_row := HBoxContainer.new()
	timeline_row.add_theme_constant_override("separation",16)
	box.add_child(timeline_row)
	cancel = _button(timeline_row,"Cancel",func() -> void: cancelled.emit())
	cancel.custom_minimum_size.x = 90
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window_label = _label(timeline_row,"−10 s",17)
	window_label.custom_minimum_size.x = 58
	window_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slider = Timeline.new()
	slider.name = "RewindTimeline"
	slider.custom_minimum_size = Vector2(0,64)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.step = 1
	for key: String in ["slider","grabber_area","grabber_area_highlight"]: slider.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	var empty := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	empty.gradient = gradient
	empty.width = 24; empty.height = 24
	for key: String in ["grabber","grabber_highlight","grabber_disabled"]: slider.add_theme_icon_override(key,empty)
	slider.add_theme_constant_override("grabber_offset",14)
	slider.value_changed.connect(func(value: float) -> void: selected.emit(int(value)); slider.queue_redraw())
	timeline_row.add_child(slider)
	_label(timeline_row,"0 s",17).vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	confirm = ResumeButton.new()
	confirm.name = "ResumeHere"
	confirm.custom_minimum_size = Vector2(68,64)
	confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm.tooltip_text = "Resume from selected position"
	for state: String in ["normal","hover","pressed"]: confirm.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	confirm.pressed.connect(func() -> void: confirmed.emit())
	confirm.disabled = true
	timeline_row.add_child(confirm)
	status = _label(box,"",14)
	status.hide()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map = HUDRoadMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	map.position = Vector2(26,-285)
	map.size = Vector2(164,124)
	root.add_child(map)

func configure(entries: Array[Dictionary], tick: int, camera: Camera3D, track: NativeTrack) -> void:
	now_tick = tick
	scene_camera = camera
	slider.max_value = entries.size()
	window_label.text = "−%.1f s" % ((tick-int(entries[0].tick))/120.0)
	map.configure(track,track.metadata.has("creator_document"))

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
	credits.text = "%d / 3 used   ·   %d free today   ·   %d saved" % [used,int(wallet.get("free",0)),int(wallet.get("balance",0))]
	funded = used < 3 and int(wallet.get("free",0))+int(wallet.get("balance",0)) > 0
	confirm.disabled = busy or not funded or slider.value >= slider.max_value
	if not funded: status.text = "No resumes left. Daily reset 00:00 UTC. Ads and packs unavailable."

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
