class_name LiveryColourChip
extends Button
var colour: Color = Color.WHITE
var selected: bool = false

func _draw() -> void:
	var centre := size*0.5
	var radius: float = minf(size.x,size.y)*0.31
	draw_circle(centre,radius+1,Color("a0adb4"))
	draw_circle(centre,radius,colour)
	# A restrained upper reflection makes the pigment easier to distinguish.
	draw_arc(centre,radius-2,PI*1.06,PI*1.78,16,colour.lightened(0.24),1.0,true)
	if selected:
		draw_arc(centre,radius+5,0,TAU,40,MenuStyle.ACCENT,2.0,true)
