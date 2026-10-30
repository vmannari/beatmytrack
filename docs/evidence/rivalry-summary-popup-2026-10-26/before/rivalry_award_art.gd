extends Control
## Original vector laurels and crown, with a bounded menu-only confetti flourish.
var tier: int = 0
var badge: bool = false
var elapsed: float = 0.0
var crown_center_y: float = 0.0
const LAUREL: Texture2D = preload("res://assets/ui/awards/laurel_left.svg")
const CROWN: Texture2D = preload("res://assets/ui/awards/crown.svg")
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

func laurel_geometry() -> Dictionary:
	var branch_width: float = 18 if badge else minf(44,size.y*0.5625)
	var top: float = 16 if badge else 0
	var height: float = size.y-top
	return {"left_rect":Rect2(0,top,branch_width,height),"right_rect":Rect2(size.x-branch_width,top,branch_width,height)}

func crown_rect() -> Rect2:
	return Rect2(size.x*0.5-13,1,26,17.3333) if badge else Rect2(size.x*0.5-24,crown_center_y-12,48,32)

func crown_geometry() -> PackedVector2Array:
	var rect: Rect2 = crown_rect()
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _draw() -> void:
	if tier == 0: return
	var geometry: Dictionary = laurel_geometry()
	draw_texture_rect(LAUREL,geometry.left_rect,false)
	draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
	draw_texture_rect(LAUREL,geometry.left_rect,false)
	draw_set_transform(Vector2.ZERO)
	if tier >= 2: draw_texture_rect(CROWN,crown_rect(),false)
	if not badge and tier >= 2:
		var count: int = 34 if tier == 3 else 16
		for index: int in range(count):
			var x: float = fposmod(index*73.71+sin(index*3.3+elapsed)*8,size.x)
			var y: float = fposmod(index*37.23+elapsed*(7+index%8),size.y)
			var color := Color(LIGHT if index%3 == 0 else GOLD,0.25+float(index%4)*0.08)
			draw_set_transform(Vector2(x,y),index*0.7+elapsed*0.3)
			draw_rect(Rect2(-2,-4,3,6),color)
		draw_set_transform(Vector2.ZERO)

