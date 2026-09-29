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
var lap: Label
var difference: Label
var window_label: Label
var play: Button
var speed_button: Button
var back: Button
var map: HUDRoadMap
var overlay: Control
var scene_camera: Camera3D
var history_labels: Array[Dictionary] = []
var selected_world := Vector3.ZERO
var selected_seconds: float = 0.0
var now_tick: int = 0
var playing: bool = false
var preview_speed: float = 0.25
var playback_credit: float = 0.0
var funded: bool = false
var busy: bool = false
var transport: Array[Button] = []

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

class TransportButton extends Button:
	var glyph: String = "play"
	var accent: bool = false
	func _draw() -> void:
		var c: Vector2 = size*0.5
		var ink: Color = Color("ffd15c") if accent else Color("eef0ea")
		if disabled: ink.a = 0.3
		if glyph in ["play","pause"]:
			draw_arc(c,30,0,TAU,64,ink,3,true)
			if glyph == "play": draw_colored_polygon(PackedVector2Array([c+Vector2(-6,-11),c+Vector2(11,0),c+Vector2(-6,11)]),ink)
			else:
				for x: float in [-7,3]: draw_rect(Rect2(c+Vector2(x,-10),Vector2(4,20)),ink)
		elif glyph == "back":
			draw_polyline(PackedVector2Array([c+Vector2(5,-12),c+Vector2(-7,0),c+Vector2(5,12)]),ink,3,true)
		else:
			var sign_value: float = -1.0 if glyph in ["earliest","previous"] else 1.0
			for offset: float in [-5,5]:
				draw_colored_polygon(PackedVector2Array([c+Vector2(offset+sign_value*5,0),c+Vector2(offset-sign_value*5,-8),c+Vector2(offset-sign_value*5,8)]),ink)
			if glyph in ["earliest","latest"]: draw_line(c+Vector2(sign_value*15,-9),c+Vector2(sign_value*15,9),ink,2,true)

class WorldLabels extends Control:
	var panel: CanvasLayer
	func _draw() -> void:
		if panel.scene_camera == null: return
		var forbidden := Rect2(Vector2(size.x-270,0),Vector2(270,size.y))
		for item: Dictionary in panel.history_labels:
			if panel.scene_camera.is_position_behind(item.world): continue
			var point: Vector2 = panel.scene_camera.unproject_position(item.world)+Vector2(-20,28)
			if point.x < 24 or point.y < 115 or point.y > size.y-200 or forbidden.has_point(point): continue
			var caption: String = "−%.1f s" % float(item.seconds)
			draw_string_outline(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color("071015"))
			draw_string(RaceHUDStyle.BODY,point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3ddeb"))
		var marker: Vector2 = panel.scene_camera.unproject_position(panel.selected_world)+Vector2(30,-36)
		if not forbidden.has_point(marker) and marker.y < size.y-210:
			draw_colored_polygon(PackedVector2Array([marker+Vector2(-3,8),marker+Vector2(5,8),marker+Vector2(1,16)]),Color("ffd15c"))
			var caption: String = "LIVE" if is_zero_approx(panel.selected_seconds) else "RESUME HERE"
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
	back = _transport(root,"back",func() -> void: cancelled.emit())
	back.position = Vector2(18,24)
	back.tooltip_text = "Cancel rewind (Esc)"
	heading = _label(root,"REWIND",58)
	heading.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	heading.position = Vector2(82,12)
	var subtitle := _label(root,"GO BACK. FIND A BETTER LINE.",15)
	subtitle.position = Vector2(86,80)
	subtitle.add_theme_color_override("font_color",Color("c0c9c9"))
	var stats: VBoxContainer = _card(Vector2(-238,18),Vector2(-24,153),Control.PRESET_TOP_RIGHT)
	lap = _label(stats,"LAP 1 / 5",21)
	lap.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	details = _label(stats,"0.00 s",37)
	details.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	difference = _label(stats,"Choose a moment",17)
	difference.add_theme_color_override("font_color",GOLD)
	var actions: VBoxContainer = _card(Vector2(-238,172),Vector2(-24,452),Control.PRESET_TOP_RIGHT)
	var mode := _label(actions,"≪   Rewind",26)
	mode.add_theme_color_override("font_color",GOLD)
	_label(actions,"Go back in time",15)
	confirm = _button(actions,"Resume here",func() -> void: playing = false; confirmed.emit())
	confirm.name = "ResumeHere"
	confirm.add_theme_stylebox_override("normal",_style(Color("ffd15c"),GOLD,16))
	confirm.add_theme_color_override("font_color",RaceHUDStyle.INK)
	confirm.disabled = true
	cancel = _button(actions,"Cancel",func() -> void: playing = false; cancelled.emit())
	credits = _label(actions,"Checking resumes…",15)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status = _label(actions,"Cancel returns to live. No resume spent.",14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lower := PanelContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_left = 72; lower.offset_right = -72
	lower.offset_top = -190; lower.offset_bottom = -18
	lower.add_theme_stylebox_override("panel",_style(INK,Color("34404499"),26))
	root.add_child(lower)
	var box := VBoxContainer.new()
	lower.add_child(box)
	var timeline_row := HBoxContainer.new()
	timeline_row.add_theme_constant_override("separation",16)
	box.add_child(timeline_row)
	window_label = _label(timeline_row,"−20 s",17)
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
	var live := _button(timeline_row,"LIVE",func() -> void: playing = false; slider.value = slider.max_value)
	live.custom_minimum_size = Vector2(66,44)
	live.size_flags_vertical = Control.SIZE_SHRINK_END
	transport.append(live)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",18)
	box.add_child(controls)
	speed_button = _button(controls,"¼×",_cycle_speed)
	speed_button.custom_minimum_size.x = 82
	transport.append(speed_button)
	_space(controls)
	_transport(controls,"earliest",func() -> void: playing = false; slider.value = 0).tooltip_text = "Oldest available moment"
	_transport(controls,"previous",func() -> void: playing = false; slider.value -= 10).tooltip_text = "Back one second"
	play = _transport(controls,"play",_toggle_play)
	play.accent = true
	play.custom_minimum_size = Vector2(68,68)
	play.tooltip_text = "Play / pause recorded preview"
	_transport(controls,"next",func() -> void: playing = false; slider.value += 10).tooltip_text = "Forward one second"
	_transport(controls,"latest",func() -> void: playing = false; slider.value = slider.max_value).tooltip_text = "Live position"
	_space(controls)
	var legend := _label(controls,"●  This attempt",15)
	legend.add_theme_color_override("font_color",Color("71b9de"))
	legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map = HUDRoadMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	map.position = Vector2(26,-326)
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
	lap.text = "LAP %d / %d" % [session.completed_laps+1,session.target_laps]
	details.text = "%.2f s" % session.race_time_seconds()
	difference.text = "LIVE POSITION" if live else "−%.1f s   SELECTED" % selected_seconds
	slider.caption = "LIVE" if live else "−%.1f s" % selected_seconds
	slider.queue_redraw()
	history_labels = labels
	selected_world = world
	map.player = state.position
	map.queue_redraw()
	confirm.disabled = busy or not funded or live
	overlay.queue_redraw()

func _process(delta: float) -> void:
	if playing and not busy:
		playback_credit += delta*preview_speed*10.0
		if playback_credit >= 1.0:
			var steps: int = int(playback_credit)
			playback_credit -= steps
			slider.value = minf(slider.max_value,slider.value+steps)
		if slider.value >= slider.max_value: playing = false
	play.glyph = "pause" if playing else "play"
	play.queue_redraw()
	overlay.queue_redraw()

func _toggle_play() -> void:
	if slider.value >= slider.max_value: slider.value = 0
	playing = not playing
	playback_credit = 0.0

func _cycle_speed() -> void:
	preview_speed = 0.5 if preview_speed == 0.25 else 1.0 if preview_speed == 0.5 else 0.25
	speed_button.text = "¼×" if preview_speed == 0.25 else "½×" if preview_speed == 0.5 else "1×"

func show_balance(wallet: Dictionary, used: int) -> void:
	credits.text = "%d / 3 used this race\n%d free today · %d saved" % [used,int(wallet.get("free",0)),int(wallet.get("balance",0))]
	funded = used < 3 and int(wallet.get("free",0))+int(wallet.get("balance",0)) > 0
	confirm.disabled = busy or not funded or slider.value >= slider.max_value
	if not funded: status.text = "No resumes left. Daily reset 00:00 UTC. Ads and packs unavailable."

func set_busy(value: bool) -> void:
	busy = value
	playing = false
	confirm.disabled = value or slider.value >= slider.max_value
	cancel.disabled = value
	back.disabled = value
	slider.editable = not value
	for button: Button in transport: button.disabled = value

func lock_pending() -> void:
	slider.editable = false
	for button: Button in transport: button.disabled = true
	playing = false

func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = color
	value.border_color = border
	value.set_border_width_all(1)
	value.set_corner_radius_all(radius)
	value.set_content_margin_all(16)
	return value

func _card(start: Vector2, end: Vector2, preset: Control.LayoutPreset) -> VBoxContainer:
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(preset)
	card.offset_left = start.x; card.offset_top = start.y
	card.offset_right = end.x; card.offset_bottom = end.y
	card.add_theme_stylebox_override("panel",_style(INK,Color("53606688"),20))
	root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	card.add_child(box)
	return box

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

func _transport(parent: Node, glyph: String, action: Callable) -> Button:
	var button := TransportButton.new()
	button.glyph = glyph
	button.custom_minimum_size = Vector2(52,56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state: String in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.pressed.connect(action)
	parent.add_child(button)
	transport.append(button)
	return button

func _space(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
