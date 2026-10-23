extends Control
## A static, inexpensive presentation mount for the shared original medal art.
var metal: Color = AchievementBadge.METALS[1]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center: Vector2 = size*0.5
	var radius: float = minf(size.x,size.y)*0.46
	draw_circle(center+Vector2(0,3),radius,Color(0,0,0,0.18))
	draw_circle(center,radius,Color("172833"))
	draw_arc(center,radius,0,TAU,80,Color(metal,0.18),1,true)
	draw_arc(center,radius-5,-PI*0.83,-PI*0.17,40,Color(metal,0.3),1,true)
	for side: float in [-1.0,1.0]:
		var point: Vector2 = center+Vector2(side*(radius+5),0)
		draw_line(point-Vector2(0,3),point+Vector2(0,3),Color(metal,0.45),1,true)
