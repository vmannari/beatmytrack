extends Control
## Original vector laurels and crown, with a bounded menu-only confetti flourish.
var tier: int = 0
var badge: bool = false
var elapsed: float = 0.0
const GOLD := Color("e7b83d")
const LIGHT := Color("fff1b0")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(tier >= 2 and not badge)

func _process(delta: float) -> void:
	elapsed = minf(6.0,elapsed+delta)
	queue_redraw()
	if elapsed >= 6.0: set_process(false)

func _draw() -> void:
	if tier == 0: return
	var center := Vector2(size.x*0.5,0)
	var span: float = size.x*0.49
	for side: int in [-1,1]:
		var stem := PackedVector2Array()
		for step: int in range(17):
			var phase: float = step/16.0
			stem.append(center+Vector2(side*span*(0.99-0.04*sin(phase*PI)),size.y*lerpf(0.89,0.20,phase)))
		draw_polyline(stem,Color(GOLD,0.65),1.7,true)
		for step: int in range(9):
			var phase: float = step/8.0
			var point: Vector2 = center+Vector2(side*span*(0.99-0.04*sin(phase*PI)),size.y*lerpf(0.89,0.20,phase))
			var leaf := PackedVector2Array()
			var length: float = 6 if badge else minf(17,size.y*0.13)
			var axis := Vector2(side*0.66,-0.74).rotated(side*(phase-0.5)*0.5)
			for corner: int in range(14):
				var leaf_phase: float = corner*TAU/14.0
				leaf.append(point+axis*length*cos(leaf_phase)+axis.orthogonal()*length*0.3*sin(leaf_phase))
			draw_colored_polygon(leaf,LIGHT.lerp(GOLD,step/10.0))
	if tier >= 2:
		var crown_center := Vector2(size.x*0.5,6 if badge else 0)
		var width: float = 19 if badge else 23
		var crown := PackedVector2Array([Vector2(-width,-2),Vector2(-width*0.68,14),Vector2(width*0.68,14),Vector2(width,-2),Vector2(width*0.40,4),Vector2(0,-12),Vector2(-width*0.40,4)])
		for index: int in range(crown.size()): crown[index] += crown_center
		draw_colored_polygon(crown,LIGHT)
		draw_line(crown_center+Vector2(-width*0.62,18),crown_center+Vector2(width*0.62,18),GOLD,3,true)
	if not badge and tier >= 2:
		var count: int = 34 if tier == 3 else 16
		for index: int in range(count):
			var x: float = fposmod(index*73.71+sin(index*3.3+elapsed)*8,size.x)
			var y: float = fposmod(index*37.23+elapsed*(7+index%8),size.y)
			var color := Color(LIGHT if index%3 == 0 else GOLD,0.25+float(index%4)*0.08)
			draw_set_transform(Vector2(x,y),index*0.7+elapsed*0.3)
			draw_rect(Rect2(-2,-4,3,6),color)
		draw_set_transform(Vector2.ZERO)
