extends Control
## Inexpensive 2D loading art. Retained draw commands; motion lives in the shader.
enum Kind { CAR, STANDINGS, IDENTITY, TRACK }
var kind: Kind = Kind.CAR
var phase: float = 0.0
var vehicle_id: String = "compact"
var podium_color := Color("c0d4e3")
var track_slot: int = 0
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
	elif kind == Kind.TRACK:
		_draw_track()
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

func _draw_track() -> void:
	# Match the populated row's thumbnail/copy/time layout. This neutral schematic
	# is deliberately shared by all slots; it does not preview an unknown route.
	var thumbnail := Rect2(6,4,110,size.y-8)
	_bar(thumbnail,Color("173341cc"),2)
	var center := thumbnail.position+Vector2(68,thumbnail.size.y*0.5)
	var extent := Vector2(31,minf(21,thumbnail.size.y*0.32))
	var circuit := PackedVector2Array()
	for step: int in range(49):
		var angle: float = TAU*step/48.0
		circuit.append(center+Vector2(cos(angle)*extent.x,sin(angle)*extent.y))
	draw_polyline(circuit,Color("365563bb"),7.0,true)
	draw_polyline(circuit,Color("7d9caa88"),2.0,true)
	# Quiet surveying marks keep the thumbnail recognisable as loading artwork.
	draw_line(center-Vector2(6,0),center+Vector2(6,0),Color("55758455"),1.0,true)
	draw_line(center-Vector2(0,5),center+Vector2(0,5),Color("55758455"),1.0,true)
	var middle: float = size.y*0.5
	var copy_left: float = 126.0
	var stats_left: float = size.x-105.0
	var copy_width: float = maxf(12,stats_left-copy_left-22.0)
	_bar(Rect2(copy_left,middle-15,copy_width*[0.82,0.64,0.92,0.72,0.86][track_slot%5],10),Color("7b98a788"))
	_bar(Rect2(copy_left,middle+5,12,12),Color("557d8c77"),3)
	_bar(Rect2(copy_left+19,middle+8,minf(64,copy_width-19),6),Color("63859466"),3)
	_bar(Rect2(stats_left,middle-11,20,20),Color("496b7d66"),5)
	_bar(Rect2(size.x-70,middle-9,62,8),Color("7895a477"))
	_bar(Rect2(size.x-48,middle+7,40,6),Color("56778766"),3)
	draw_line(Vector2(6,size.y-1),Vector2(size.x-6,size.y-1),Color("31566a88"),1.0)
