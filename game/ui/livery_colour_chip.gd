class_name LiveryColourChip
extends Button
var colour: Color = Color.WHITE
var selected: bool = false

func _draw() -> void:
	var centre := size*0.5
	var radius: float = minf(size.x,size.y)*0.33
	draw_circle(centre+Vector2(0,2),radius+2,Color("02070b"),true,-1.0,true)
	draw_circle(centre,radius+1,Color("a0adb4"),true,-1.0,true)
	draw_circle(centre,radius,colour,true,-1.0,true)
	# A broad pigment highlight keeps dark paints readable without a wet gloss.
	draw_arc(centre,radius-3,PI*1.08,PI*1.82,24,colour.lightened(0.32),2.0,true)
	if selected:
		draw_arc(centre,radius+5,0,TAU,40,MenuStyle.ACCENT,2.0,true)
