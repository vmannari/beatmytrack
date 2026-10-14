class_name StickerPlacement
extends Control
## Direct mouse/touch placement on a real panel footprint; emits only cosmetics.
signal moved(point: Vector2)
signal committed
var vehicle_id: String = "compact"
var surface: String = "hood"
var livery: Dictionary
var dragging: bool = false
var pointer: int = -1
var _panel_paint: TextureRect
var _emblem: TextureRect
var _finish: ShaderMaterial

func _ready() -> void:
	custom_minimum_size = Vector2(160,104)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	gui_input.connect(_input_panel)
	resized.connect(queue_redraw)
	tooltip_text = "Drag to place sticker"
	_panel_paint = TextureRect.new()
	_panel_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_paint.clip_contents = true
	_panel_paint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_finish = ShaderMaterial.new()
	_finish.shader = preload("res://ui/sticker_panel.gdshader")
	_panel_paint.material = _finish
	add_child(_panel_paint)
	_emblem = TextureRect.new()
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_panel_paint.add_child(_emblem)

func panel_rect() -> Rect2:
	var panel: Vector4 = LiveryCatalog.projection(vehicle_id)[surface]
	var unit: float = minf((size.x-24)/panel.z,(size.y-30)/panel.w)
	var extent := Vector2(panel.z,panel.w)*unit
	return Rect2((size-extent-Vector2(0,16))*0.5,extent)

func _draw() -> void:
	if livery.is_empty(): return
	var rect: Rect2 = panel_rect()
	draw_style_box(MenuStyle.card(8),Rect2(Vector2.ZERO,size))
	draw_rect(rect.grow(1),MenuStyle.MUTED,false,1)
	draw_string(MenuStyle.BODY,Vector2(8,size.y-4),"Drag to place",HORIZONTAL_ALIGNMENT_CENTER,size.x-16,12,MenuStyle.MUTED)
	_panel_paint.position = rect.position
	_panel_paint.size = rect.size
	_panel_paint.texture = LiveryCatalog.texture(livery.pattern) if livery.pattern != "plain" else LiveryCatalog.texture("apex_twin")
	_finish.set_shader_parameter("patterned",livery.pattern != "plain")
	for slot: String in VehicleLivery.SLOTS: _finish.set_shader_parameter(slot+"_colour",Color(str(livery.colors[slot])))
	var projection: Dictionary = LiveryCatalog.projection(vehicle_id)
	_finish.set_shader_parameter("panel",projection[surface])
	_finish.set_shader_parameter("bounds",projection.bounds)
	var sticker: Dictionary = livery.stickers[surface]
	_emblem.visible = sticker.id != "none"
	if sticker.id == "none": return
	var centre: Vector2 = rect.size*Vector2(sticker.x,sticker.y)
	var extent: float = minf(rect.size.x,rect.size.y)*sticker.size
	_emblem.texture = LiveryCatalog.texture(sticker.id+"_sticker")
	_emblem.size = Vector2.ONE*extent
	_emblem.pivot_offset = _emblem.size*0.5
	_emblem.position = centre-_emblem.size*0.5
	_emblem.rotation_degrees = sticker.rotation

func _place(position: Vector2) -> void:
	var rect: Rect2 = panel_rect()
	moved.emit(((position-rect.position)/rect.size).clamp(Vector2.ZERO,Vector2.ONE))

func _input_panel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		dragging = event.pressed
		if dragging: _place(event.position)
		else: committed.emit()
		accept_event()
	elif event is InputEventMouseMotion and dragging and pointer < 0:
		_place(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and pointer < 0:
			pointer = event.index
			dragging = true
			_place(event.position)
		elif not event.pressed and pointer == event.index:
			pointer = -1
			dragging = false
			committed.emit()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer:
		_place(event.position)
		accept_event()
