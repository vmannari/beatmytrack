class_name TouchControlArt
extends Control
## Supplied artwork, retained per-button draw lists and separate touch geometry.
const STEERING: Texture2D = preload("res://assets/hud/steering.png")
const BRAKE: Texture2D = preload("res://assets/hud/brake.png")
const GAS: Texture2D = preload("res://assets/hud/gas.png")
var vehicle_id: String = "compact"
var button_index: int = 0
var pressed: bool = false
var draw_count: int = 0
var artwork_rect := Rect2()

func _draw() -> void:
	draw_count += 1
	var rect: Rect2 = artwork_rect
	if pressed and button_index < 2: rect.position.y += 3
	var tint := Color(1.16,1.12,0.86) if pressed and button_index < 2 else Color.WHITE
	if button_index < 2:
		var diameter: float = minf(rect.size.x,rect.size.y)
		var face := Rect2(rect.get_center()-Vector2.ONE*diameter*0.5,Vector2.ONE*diameter)
		draw_texture_rect_region(STEERING,face,Rect2(356 if button_index == 0 else 946,220,474,456),tint)
		if pressed: draw_arc(face.get_center(),diameter*0.47,0,TAU,64,RaceHUDStyle.GOLD,2,true)
	else:
		var gas: bool = button_index == 3
		var height: float = rect.size.y-19
		var width: float = height*(0.61 if gas else 0.69)
		var face := Rect2(Vector2(rect.get_center().x-width*0.5,rect.position.y),Vector2(width,height))
		var recess := StyleBoxFlat.new()
		recess.bg_color = Color("09121188")
		recess.set_corner_radius_all(9)
		draw_style_box(recess,face.grow(2))
		if pressed:
			# Tilt the face away into its fixed mounting recess. Captions stay still.
			face.position += Vector2(width*0.035,height*0.18)
			face.size *= Vector2(0.93,0.82)
		draw_texture_rect_region(GAS if gas else BRAKE,face,Rect2(274,326,504,850) if gas else Rect2(266,354,494,718),tint)
		var label: String = "GAS" if gas else "BRAKE"
		var font: Font = RaceHUDStyle.DISPLAY
		var width_text: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		var baseline := Vector2(rect.get_center().x-width_text*0.5,rect.end.y)
		draw_string_outline(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("142021aa"))
		draw_string(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,RaceHUDStyle.TEXT)
