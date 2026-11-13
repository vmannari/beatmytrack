extends Control
## Engraved round medals share the menu palette and existing award laurels.
var tier: int = 0
var earned: bool = true
var selected: bool = false
const COLORS: Array[Color] = [Color("344e5b"),Color("bf805a"),Color("c4ced4"),Color("e9b63e"),Color("b6ecf5")]
const LAUREL: Texture2D = preload("res://assets/ui/awards/laurel_left.svg")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center: Vector2 = size*0.5
	var radius: float = minf(size.x,size.y)*0.39
	var metal: Color = COLORS[clampi(tier,0,4)]
	if not earned or tier == 0:
		draw_arc(center,radius,0,TAU,64,metal.darkened(0.15),1.5,true)
		return
	draw_circle(center+Vector2(0,2),radius+1,Color("02080bcc"))
	if selected: draw_arc(center,radius+3.5,0,TAU,64,COLORS[4] if tier == 4 else Color("e9eef2"),1.4,true)
	for ring: int in range(14):
		var amount: float = float(ring)/13
		var color: Color = metal.lightened(0.32).lerp(metal.darkened(0.42),amount)
		draw_circle(center,radius*(1.0-amount*0.2),color)
	draw_circle(center,radius*0.78,metal.darkened(0.15))
	draw_arc(center,radius*0.71,0,TAU,64,metal.lightened(0.23),0.8,true)
	draw_arc(center,radius*0.93,PI,TAU,32,metal.lightened(0.6),1.3,true)
	for side: int in [-1,1]:
		var points := PackedVector2Array()
		for index: int in range(15):
			var angle: float = lerpf(0.35,2.5,float(index)/14)
			points.append(center+Vector2(side*sin(angle)*radius*0.52,cos(angle)*radius*0.55))
		draw_polyline(points,metal.lightened(0.28),0.9,true)
		for index: int in range(5):
			var angle: float = 0.5+index*0.32
			var at: Vector2 = center+Vector2(side*sin(angle)*radius*0.52,cos(angle)*radius*0.55)
			draw_line(at,at+Vector2(side*radius*0.15,-radius*0.12),metal.lightened(0.4),1.1,true)
	var star := PackedVector2Array()
	for index: int in range(10):
		var angle: float = -PI/2+index*PI/5
		star.append(center+Vector2(cos(angle),sin(angle))*radius*(0.34 if index%2 == 0 else 0.15))
	draw_colored_polygon(star,metal.lightened(0.5))
	if tier == 4:
		var branch := Rect2(center.x-radius*1.4,center.y-radius, radius*0.4,radius*2)
		draw_texture_rect(LAUREL,branch,false,COLORS[4])
		draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
		draw_texture_rect(LAUREL,branch,false,COLORS[4])
		draw_set_transform(Vector2.ZERO)
