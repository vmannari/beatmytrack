extends Control
## Stationary desk, paper and circuit ink; no processing or animated noise.
const MARKER_TEXTURE: Texture2D = preload("res://assets/news/race_marker_handdrawn_v2.png")
var kind: String = "paper"
var points := PackedVector2Array()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "marker": texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
func _draw() -> void:
	if kind == "paper":
		draw_rect(Rect2(Vector2.ZERO,size),Color("eee7d4"))
		for row: int in range(int(size.y/4)):
			draw_line(Vector2(0,row*4),Vector2(size.x,row*4),Color(0.40,0.31,0.18,0.018),1)
		var fold: float = size.x*0.625
		draw_rect(Rect2(fold-3,0,3,size.y),Color(0.28,0.21,0.12,0.025))
		draw_line(Vector2(fold,0),Vector2(fold,size.y),Color(1,0.98,0.9,0.23),1)
	elif kind == "marker":
		# Fit the ink itself behind the lettering, leaving its rough edges intact.
		var source := Rect2(Vector2(98,121)/Vector2(2172,724)*MARKER_TEXTURE.get_size(),Vector2(1998,439)/Vector2(2172,724)*MARKER_TEXTURE.get_size())
		draw_texture_rect_region(MARKER_TEXTURE,Rect2(Vector2(6,10),size-Vector2(12,20)),source,Color(1,1,1,0.78))
	elif kind == "circuit" and points.size() >= 2:
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point: Vector2 in points: bounds = bounds.expand(point)
		var scale_factor: float = minf(maxf(1,size.x-38)/maxf(1,bounds.size.x),maxf(1,size.y-32)/maxf(1,bounds.size.y))
		var path := PackedVector2Array()
		for point: Vector2 in points:
			var offset: Vector2 = (point-bounds.get_center())*scale_factor
			path.append(size*0.5+Vector2(offset.x,-offset.y))
		path.append(path[0])
		draw_polyline(path,Color(0.26,0.25,0.20,0.12),8,true)
		draw_polyline(path,Color("303832"),4,true)
		draw_circle(path[0],5,Color("a34330"),true,-1,true)
		draw_circle(path[0],2,Color("eee7d4"),true,-1,true)

