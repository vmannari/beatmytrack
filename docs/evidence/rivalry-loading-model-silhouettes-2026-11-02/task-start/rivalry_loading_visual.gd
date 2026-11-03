extends Control
## Inexpensive 2D loading art. Retained draw commands; motion lives in the shader.
enum Kind { CAR, STANDINGS, IDENTITY }
var kind: Kind = Kind.CAR
var phase: float = 0.0
static var _white: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/rivalry_loading_visual.gdshader")
	finish.set_shader_parameter("vehicle",kind == Kind.CAR)
	finish.set_shader_parameter("phase_offset",phase)
	material = finish
	resized.connect(queue_redraw)
	set_process(false)

func _bar(rect: Rect2, color: Color, radius: int = 4) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0: return
	if kind == Kind.CAR:
		if _white == null:
			var pixel := Image.create(1,1,false,Image.FORMAT_RGBA8)
			pixel.fill(Color.WHITE)
			_white = ImageTexture.create_from_image(pixel)
		var width: float = minf(size.x-12.0,size.y*2.5)
		var dimensions := Vector2(maxf(1.0,width),maxf(1.0,width/2.5))
		draw_texture_rect(_white,Rect2((size-dimensions)*0.5,dimensions),false)
	elif kind == Kind.IDENTITY:
		_bar(Rect2(size.x*0.19,7,size.x*0.62,9),Color("5b768966"))
		_bar(Rect2(size.x*0.34,26,size.x*0.32,12),Color("6d87916b"))
	else:
		var rows: int = clampi(floori((size.y+5.0)/35.0),2,9)
		var stride: float = minf(39.0,size.y/rows)
		for index: int in range(rows):
			var top: float = index*stride
			_bar(Rect2(0,top,size.x,stride-3.0),Color("263e4b48"),5)
			_bar(Rect2(7,top+8,19,stride-19),Color("58718066"))
			var name_width: float = maxf(18.0,(size.x-124.0)*[0.70,0.92,0.58,0.80,0.64][index%5])
			_bar(Rect2(37,top+12,name_width,8),Color("67849473"))
			_bar(Rect2(size.x-67,top+12,22,8),Color("607d8e66"))
			_bar(Rect2(size.x-28,top+12,20,8),Color("526c7b55"))
