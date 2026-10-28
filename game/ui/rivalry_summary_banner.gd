extends Control
## Original checkerboard and trophy geometry for the results sheet.
var tier: int = 0
var kind: String = "banner"
var empty_week: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if kind == "comparison":
		draw_line(Vector2(0,19),Vector2(size.x,19),MenuStyle.MUTED,1,true)
		var badge := PackedVector2Array([Vector2(33,3),Vector2(188,3),Vector2(181,35),Vector2(26,35)])
		draw_colored_polygon(badge,Color("06141c"))
		badge.append(badge[0])
		draw_polyline(badge,MenuStyle.POSITIVE,1,true)
		return
	var faint := Color("87a5b6",0.13)
	for side: int in range(2):
		for row: int in range(7):
			for column: int in range(2):
				if (row+column)%2 != 0: continue
				var x: float = (18 if side == 0 else size.x-41)+column*24-row*5
				var y: float = row*28+5
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+24,y),Vector2(x+19,y+28),Vector2(x-5,y+28)]),faint)
	draw_line(Vector2(103,126),Vector2(516,126),Color(MenuStyle.ACCENT,0.8),1.3,true)
	if empty_week: return
	draw_line(Vector2(565,17),Vector2(532,178),Color(MenuStyle.ACCENT,0.5),1,true)
	if tier > 0: _trophy(Rect2(739,37,68,79),MenuStyle.ACCENT if tier >= 2 else Color("b8cbd5"))
	else: draw_texture_rect(MenuIcon.texture("flag",true),Rect2(743,47,59,59),false,MenuStyle.MUTED)
	for row: int in range(2):
		for column: int in range(8):
			if (row+column)%2 != 0: continue
			var x: float = 723+column*11-row*3
			var y: float = 128+row*11
			draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+11,y),Vector2(x+8,y+11),Vector2(x-3,y+11)]),Color("a4bac7",0.5))

func _trophy(rect: Rect2, color: Color) -> void:
	draw_set_transform(rect.position,0,rect.size/Vector2(68,79))
	draw_colored_polygon(PackedVector2Array([Vector2(13,5),Vector2(55,5),Vector2(55,27),Vector2(51,39),Vector2(42,47),Vector2(38,48),Vector2(38,65),Vector2(48,67),Vector2(48,73),Vector2(20,73),Vector2(20,67),Vector2(30,65),Vector2(30,48),Vector2(25,47),Vector2(16,39),Vector2(13,27)]),color)
	draw_polyline(PackedVector2Array([Vector2(13,13),Vector2(2,13),Vector2(3,29),Vector2(10,39),Vector2(22,43)]),color,4,true)
	draw_polyline(PackedVector2Array([Vector2(55,13),Vector2(66,13),Vector2(65,29),Vector2(58,39),Vector2(46,43)]),color,4,true)
	var star := PackedVector2Array()
	for index: int in range(10):
		var angle: float = -PI*0.5+index*PI/5
		star.append(Vector2(34,25)+Vector2(cos(angle),sin(angle))*(12 if index%2 == 0 else 5))
	draw_colored_polygon(star,Color("06141c"))
	draw_set_transform(Vector2.ZERO)
