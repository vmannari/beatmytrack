extends Control
## Small native vector accents for the track rank and verified weekly progress.
var rank_plate: bool = false
var states: PackedInt32Array = PackedInt32Array():
	set(value):
		if states == value: return
		states = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if rank_plate:
		draw_colored_polygon(PackedVector2Array([Vector2(8,0),Vector2(size.x,0),Vector2(size.x-8,size.y),Vector2(0,size.y)]),Color("18314080"))
		return
	if states.is_empty(): return
	var width: float = (size.x-2.0*(states.size()-1))/states.size()
	for index: int in range(states.size()):
		var x: float = index*(width+2.0)
		var color: Color = MenuStyle.POSITIVE if states[index] == 2 else MenuStyle.ACCENT if states[index] == 1 else Color("29424f")
		draw_colored_polygon(PackedVector2Array([Vector2(x+3,0),Vector2(x+width,0),Vector2(x+width-3,size.y),Vector2(x,size.y)]),color)
