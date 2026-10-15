extends Control
## One bounded sleeve stack with direct mouse/touch scrubbing and eased flips.
const Library = preload("res://soundtrack/record_library.gd")
signal browsed(index: int)
signal activated(id: String)
signal flipping(position: float)
var browse_index: int = 0
var display_position: float = 0.0:
	set(value):
		display_position = clampf(value,0,Library.CATALOG.size()-1)
		queue_redraw()
		if is_node_ready(): flipping.emit(display_position)
var motion: Tween
var pointer: int = -2
var press_position := Vector2.ZERO
var press_display: float = 0.0
var moved: bool = false

func _ready() -> void:
	name = "GarageLPBox"
	custom_minimum_size = Vector2(280,250)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(_visibility_changed)
	display_position = browse_index

func flip_by(direction: int) -> void:
	flip_to(browse_index+direction)

func flip_to(index: int) -> void:
	if motion != null: motion.kill()
	pointer = -2
	browse_index = clampi(index,0,Library.CATALOG.size()-1)
	browsed.emit(browse_index)
	motion = create_tween()
	motion.tween_property(self,"display_position",float(browse_index),0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_callback(_settled)

func _settled() -> void:
	motion = null

func finish() -> void:
	if motion != null: motion.kill()
	motion = null
	pointer = -2
	display_position = browse_index

func _visibility_changed() -> void:
	if not is_visible_in_tree(): finish()

func _press(location: Vector2, id: int) -> void:
	if pointer != -2: return
	if motion != null: motion.kill()
	motion = null
	pointer = id
	press_position = location
	press_display = display_position
	moved = false
	grab_focus()

func _move(location: Vector2, id: int) -> void:
	if pointer != id: return
	var travel: float = location.y-press_position.y
	if absf(travel)>6: moved = true
	display_position = press_display-travel/90.0

func _release(id: int, canceled: bool = false) -> void:
	if pointer != id: return
	pointer = -2
	if canceled:
		flip_to(browse_index)
	elif moved:
		flip_to(roundi(display_position))
	else:
		activated.emit(Library.CATALOG[browse_index].id)
		flip_to(browse_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			flip_by(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position,-1)
			else: _release(-1)
		else: return
	elif event is InputEventMouseMotion and pointer == -1:
		_move(event.position,-1)
	elif event is InputEventScreenTouch:
		if event.pressed: _press(event.position,event.index)
		else: _release(event.index,event.canceled)
	elif event is InputEventScreenDrag:
		_move(event.position,event.index)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_DOWN,KEY_RIGHT]: flip_by(1)
		elif event.keycode in [KEY_UP,KEY_LEFT]: flip_by(-1)
		elif event.keycode in [KEY_ENTER,KEY_SPACE]: activated.emit(Library.CATALOG[browse_index].id)
		else: return
	else: return
	accept_event()

func _draw() -> void:
	var width: float = size.x
	var side: float = minf(width-48,size.y-67)
	var bottom: float = size.y-56
	# Rear rail and side returns make a real open crate around the sleeve stack.
	draw_style_box(MenuStyle.box(Color("0b1820"),0),Rect2(8,bottom-78,width-16,130))
	draw_polygon(PackedVector2Array([Vector2(8,bottom-77),Vector2(21,bottom-64),Vector2(21,bottom+45),Vector2(8,bottom+52)]),PackedColorArray([Color("6e5039")]))
	draw_polygon(PackedVector2Array([Vector2(width-8,bottom-77),Vector2(width-21,bottom-64),Vector2(width-21,bottom+45),Vector2(width-8,bottom+52)]),PackedColorArray([Color("59422f")]))
	for index: int in range(Library.CATALOG.size()-1,-1,-1):
		var distance: float = index-display_position
		if distance < -1.0 or distance > 5.5: continue
		var depth: float = maxf(0,distance)
		var card_side: float = side*(1.0-depth*0.026)
		var height: float = card_side
		var alpha: float = 1.0
		var top: float = bottom-card_side-depth*10
		if distance<0:
			var fall: float = -distance
			height *= maxf(0.04,cos(fall*PI*0.5))
			top = bottom-height+fall*8
			alpha = 1.0-smoothstep(0.65,1.0,fall)
		var rect := Rect2((width-card_side)*0.5,top,card_side,height)
		draw_rect(Rect2(rect.position+Vector2(3,3),rect.size),Color(0,0,0,0.3*alpha))
		draw_texture_rect(Library.cover(Library.CATALOG[index].id),rect,false,Color(1,1,1,alpha))
		draw_rect(rect,Color(0.83,0.81,0.73,alpha),false,1.0)
		if distance>=0 and height>25:
			var title: String = Library.CATALOG[index].title.to_upper()
			draw_string(MenuStyle.DISPLAY,rect.position+Vector2(12,19),title,HORIZONTAL_ALIGNMENT_LEFT,card_side-24,15,Color(0.96,0.94,0.85,alpha))
	# Low front slats overlap the sleeve bottoms, including the hinged outgoing LP.
	draw_rect(Rect2(8,bottom-5,width-16,57),Color("73543c"))
	draw_line(Vector2(8,bottom-5),Vector2(width-8,bottom-5),Color("ac8863"),3)
	draw_line(Vector2(10,bottom+18),Vector2(width-10,bottom+18),Color("5d4432"),1)
	draw_line(Vector2(10,bottom+41),Vector2(width-10,bottom+41),Color("896747"),1)
	draw_style_box(MenuStyle.box(Color("2c241f"),3),Rect2(width*0.5-28,bottom+5,56,11))
	draw_string(MenuStyle.DISPLAY,Vector2(20,bottom+38),"BMT / RECORDS",HORIZONTAL_ALIGNMENT_LEFT,width-40,15,Color("dfc6a2"))
	if has_focus(): draw_rect(Rect2(2,2,width-4,size.y-4),MenuStyle.ACCENT,false,1.0)
