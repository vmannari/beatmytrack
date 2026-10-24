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
	custom_minimum_size = Vector2(256,190)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	accessibility_name = "LP collection"
	accessibility_description = "Swipe up or down, use the mouse wheel, or press the arrow keys to browse records."
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
	var compact: bool = size.y < 240
	var front_height: float = 26 if compact else 55
	var side: float = minf(width-56,size.y-front_height-(18 if compact else 20))
	var bottom: float = size.y-front_height-(8 if compact else 4)
	var left: float = (width-side)*0.5-13
	var right: float = width-left
	# A deep open walnut crate. The returns sit behind the sleeves; the front
	# overlaps their feet so a turning record stays physically inside the box.
	var shadow := MenuStyle.box(Color(0,0,0,0.25),0)
	shadow.set_corner_radius_all(12)
	draw_style_box(shadow,Rect2(left-2,bottom+front_height-36,right-left+6,47))
	draw_rect(Rect2(left+8,bottom-93,right-left-16,110),Color("172026"))
	wood_quad(PackedVector2Array([Vector2(left,bottom-66),Vector2(left+15,bottom-79),Vector2(left+15,bottom+front_height-28),Vector2(left,bottom+front_height-3)]),Color("94633e"),Color("4c3327"))
	wood_quad(PackedVector2Array([Vector2(right-15,bottom-79),Vector2(right,bottom-66),Vector2(right,bottom+front_height-3),Vector2(right-15,bottom+front_height-28)]),Color("ad7648"),Color("543828"))
	for index: int in range(Library.CATALOG.size()-1,-1,-1):
		var distance: float = index-display_position
		if distance < -1.0 or distance > (3.0 if compact else 5.5): continue
		var depth: float = maxf(0,distance)
		var card_side: float = side*(1.0-depth*0.018)
		var height: float = card_side
		var alpha: float = 1.0
		var top: float = bottom-card_side-depth*(4 if compact else 6)
		if distance<0:
			var fall: float = -distance
			height *= maxf(0.04,cos(fall*PI*0.5))
			top = bottom-height+fall*8
			alpha = 1.0-smoothstep(0.65,1.0,fall)
		var rect := Rect2((width-card_side)*0.5,top,card_side,height)
		draw_rect(Rect2(rect.position+Vector2(3,4),rect.size),Color(0,0,0,0.48*alpha))
		draw_rect(rect.grow(2),Color(0.73,0.73,0.66,alpha))
		draw_texture_rect(Library.cover(Library.CATALOG[index].id),rect,false,Color(1,1,1,alpha))
		draw_rect(rect.grow(-4),Color(0.76,0.82,0.81,0.30*alpha),false,1.0)
		# Restrained sleeve varnish and a seated paper edge, rather than a flat card.
		draw_polygon(PackedVector2Array([rect.position,rect.position+Vector2(card_side,0),rect.end]),PackedColorArray([Color(1,1,1,0.07*alpha),Color(1,1,1,0.025*alpha),Color(1,1,1,0)]))
		if distance>=0 and height>25:
			var title: String = Library.CATALOG[index].title.to_upper()
			var font_size: int = clampi(roundi(card_side*0.065),10,18)
			draw_string(MenuStyle.DISPLAY,rect.position+Vector2(11,font_size+10),title,HORIZONTAL_ALIGNMENT_LEFT,card_side-20,font_size,Color(0,0,0,0.6*alpha))
			draw_string(MenuStyle.DISPLAY,rect.position+Vector2(10,font_size+9),title,HORIZONTAL_ALIGNMENT_LEFT,card_side-20,font_size,Color(0.96,0.94,0.85,alpha))
			if distance<0.5 and not Library.playable(Library.CATALOG[index].id):
				var small_stamp: bool = card_side<120
				var caption: String = "COMING LATER" if small_stamp else "MUSIC COMING LATER"
				var stamp := Rect2(rect.position+Vector2(6,height-(23 if small_stamp else 29)),Vector2(card_side-12,15 if small_stamp else 21))
				draw_rect(stamp,Color(0.025,0.055,0.07,0.93*alpha))
				draw_string(MenuStyle.DISPLAY,stamp.position+Vector2(4,11 if small_stamp else 15),caption,HORIZONTAL_ALIGNMENT_LEFT,stamp.size.x-8,9 if small_stamp else 12,Color(0.78,0.81,0.78,alpha))
	var front := Rect2(left,bottom-3,right-left,front_height)
	wood_quad(PackedVector2Array([front.position,Vector2(right,bottom-3),front.end,Vector2(left,bottom+front_height-3)]),Color("94633f"),Color("65442f"))
	# Broad, quiet grain is authored deterministically, with no image or RNG work.
	for row: int in range(9):
		var y: float = bottom+2+row*(front_height-7)/9.0
		var points := PackedVector2Array()
		for column: int in range(13):
			points.append(Vector2(lerpf(left+4,right-4,column/12.0),y+sin(column*0.7+row*0.53)*0.8))
		draw_polyline(points,Color(0.16,0.08,0.035,0.12 if row%3 else 0.23),0.65,true)
	draw_line(Vector2(left,bottom-3),Vector2(right,bottom-3),Color("c29460"),2,true)
	draw_line(Vector2(left+1,bottom+front_height-4),Vector2(right-1,bottom+front_height-4),Color("3d2d25"),2,true)
	# Recessed handhold, with a warm lower bevel.
	var handle := Rect2(width*0.5-27,bottom+4,54,8 if compact else 12)
	draw_style_box(MenuStyle.box(Color("b48350"),0),Rect2(handle.position+Vector2(0,1),handle.size+Vector2(0,1)))
	draw_style_box(MenuStyle.box(Color("241e1a"),0),handle)
	for x: float in [left+7,right-7]:
		for y: float in [bottom+6,bottom+front_height-12]:
			draw_circle(Vector2(x,y),1.5,Color("382d25"),true,-1,true)
			draw_line(Vector2(x-0.7,y-0.4),Vector2(x+0.7,y+0.4),Color("a18560"),0.7,true)
	if not compact:
		draw_string(MenuStyle.DISPLAY,Vector2(left+15,bottom+front_height-14),"BMT / RECORDS",HORIZONTAL_ALIGNMENT_LEFT,right-left-30,13,Color("cead7e"))
	if has_focus():
		var focus := MenuStyle.box(Color.TRANSPARENT,0)
		focus.border_color = MenuStyle.ACCENT
		focus.set_border_width_all(1)
		draw_style_box(focus,Rect2(2,2,width-4,size.y-4))

func wood_quad(points: PackedVector2Array, top: Color, bottom: Color) -> void:
	draw_polygon(points,PackedColorArray([top,top,bottom,bottom]))
