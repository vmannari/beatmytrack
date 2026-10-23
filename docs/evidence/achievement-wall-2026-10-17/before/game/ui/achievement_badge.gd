class_name AchievementBadge
extends Control
## Original static medal geometry; no textures, live viewports or animation.
var tier: int = 0
var prestige: bool = false
var motif: int = 0
var mark: String = ""
const METALS: Array[Color] = [Color("475760"),Color("b98759"),Color("bdcbd0"),Color("e3be67"),Color("d4eee8")]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72,88)

func _draw() -> void:
	var center: Vector2 = size*Vector2(0.5,0.43)
	var radius: float = minf(size.x*0.39,size.y*0.34)
	var metal: Color = METALS[3 if prestige and tier > 0 else clampi(tier,0,4)]
	var points := PackedVector2Array()
	var sides: int = 16 if prestige else 8
	for i: int in range(sides):
		var angle: float = TAU*i/sides-PI*0.5
		var reach: float = radius*(0.82 if prestige and i%2 else 1.0)
		points.append(center+Vector2(cos(angle),sin(angle))*reach)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-radius*0.65,radius*0.45),center+Vector2(-radius*0.75,radius*1.4),center+Vector2(0,radius),center+Vector2(radius*0.75,radius*1.4),center+Vector2(radius*0.65,radius*0.45)]),Color("304c5b"))
	draw_colored_polygon(points,metal.darkened(0.35))
	points.append(points[0])
	draw_polyline(points,metal,2.0,true)
	draw_circle(center,radius*0.69,MenuStyle.PANEL)
	var r: float = radius*0.40
	if not mark.is_empty():
		var font_size: int = roundi(radius*0.90)
		var width: float = MenuStyle.DISPLAY.get_string_size(mark,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(MenuStyle.DISPLAY,center+Vector2(-width*0.5,font_size*0.33),mark,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,metal)
	elif motif%3 == 0:
		draw_polyline(PackedVector2Array([center+Vector2(-r,-r*0.6),center+Vector2(-r*0.65,r*0.25),center+Vector2(0,r*0.6),center+Vector2(r*0.65,r*0.25),center+Vector2(r,-r*0.6)]),metal,2.5,true)
		draw_line(center+Vector2(0,r*0.6),center+Vector2(0,r),metal,2.5,true)
		draw_line(center+Vector2(-r*0.6,r),center+Vector2(r*0.6,r),metal,2.5,true)
	elif motif%3 == 1:
		draw_arc(center,r,0,TAU,24,metal,2.5,true)
		draw_line(center,center+Vector2(0,-r*0.7),metal,2.5,true)
		draw_line(center,center+Vector2(r*0.5,r*0.3),metal,2.5,true)
	else:
		for i: int in range(3):
			draw_line(center+Vector2(-r,(i-1)*r*0.65),center+Vector2(r,(i-1)*r*0.65),metal,2.5,true)
