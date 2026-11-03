extends Control
## Inexpensive 2D loading art. Retained draw commands; motion lives in the shader.
enum Kind { CAR, STANDINGS, IDENTITY }
var kind: Kind = Kind.CAR
var phase: float = 0.0
var vehicle_id: String = "compact"
var podium_color := Color("c0d4e3")
const CAR_IDS: Array[String] = ["compact","kart","forklift","electric","hovercraft"]
const TILE := Vector2(384,256)
const SILHOUETTES: Texture2D = preload("res://assets/menu/rivalry_loading_cars_v1.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/rivalry_loading_visual.gdshader")
	finish.set_shader_parameter("vehicle",kind == Kind.CAR)
	finish.set_shader_parameter("phase_offset",phase)
	finish.set_shader_parameter("silhouette_color",podium_color)
	material = finish
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
		var index: int = maxi(0,CAR_IDS.find(vehicle_id))
		var aspect: float = TILE.x/TILE.y
		var width: float = minf(size.x-12.0,size.y*aspect)
		var dimensions := Vector2(maxf(1.0,width),maxf(1.0,width/aspect))
		draw_texture_rect_region(SILHOUETTES,Rect2((size-dimensions)*0.5,dimensions),Rect2(Vector2(index*TILE.x,0),TILE))
	elif kind == Kind.IDENTITY:
		_bar(Rect2(size.x*0.19,7,size.x*0.62,9),Color(podium_color,0.22))
		_bar(Rect2(size.x*0.34,26,size.x*0.32,12),Color(podium_color,0.30))
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
