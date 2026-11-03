extends Control
## Project a restrained, non-interactive callout onto the modified part.
var showroom: CarShowroom
var category: String = ""
var _at := Vector2.INF

func _init() -> void:
	name = "GaragePartIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(showroom): return
	var point: Vector3 = {"hood":Vector3(0.45,1.0,-1.35),"aero":Vector3(0,1.4,1.84),"rims":Vector3(0.83,0.4,-1.28),"body":Vector3(0.9,0.35,-0.3)}.get(category,Vector3.ZERO)
	if showroom.car.vehicle_id=="kart":
		point = {"hood":Vector3(0,0.38,-1.2),"aero":Vector3(0,0.23,1.3),"rims":Vector3(0.61,0.22,-0.88),"body":Vector3(0.65,0.3,-0.1)}.get(category,Vector3.ZERO)
	if showroom.car.vehicle_id=="hovercraft":
		point = {"hood":Vector3(0,0.8,-1.6),"aero":Vector3(0,1.4,1.68),"rims":Vector3(0.52,1.03,1.0),"body":Vector3(0.91,0.65,0)}.get(category,Vector3.ZERO)
	if showroom.car.vehicle_id=="forklift":
		point = {"hood":Vector3(0.3,1.58,1.05),"aero":Vector3(0.55,0.72,1.73),"rims":Vector3(0.84,0.43,-0.93),"body":Vector3(0.71,2.65,0.05)}.get(category,Vector3.ZERO)
	point = showroom.car.global_transform*(point*HandlingConfig.BODY_SCALE)
	var projected := Vector2.INF
	if not showroom.camera.is_position_behind(point): projected = showroom.camera.unproject_position(point)*size/Vector2(showroom.showroom_viewport.size)
	if projected!=_at:
		_at = projected
		queue_redraw()

func _draw() -> void:
	if not Rect2(Vector2(12,88),size-Vector2(24,152)).has_point(_at): return
	var caption: String = GameText.message("Previewing").to_upper()+" · "+GameText.message(VehicleCustomisation.label(category,showroom.car.vehicle_id)).to_upper()
	var font: Font = MenuStyle.DISPLAY
	var font_size: int = 15
	var width: float = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var right: bool = _at.x+width+68<size.x-16
	var elbow: Vector2 = _at+Vector2(46 if right else -46,-60)
	elbow.y = maxf(102,elbow.y)
	var end: Vector2 = elbow+Vector2(12 if right else -12,0)
	draw_line(_at,elbow,MenuStyle.ACCENT,1.5,true)
	draw_line(elbow,end,MenuStyle.ACCENT,1.5,true)
	draw_circle(_at,4,MenuStyle.ACCENT,true,-1,true)
	var label_at: Vector2 = end+Vector2(4 if right else -width-4,5)
	draw_rect(Rect2(label_at+Vector2(-4,-font_size),Vector2(width+8,font_size+6)),Color("0c1921e6"))
	draw_string(font,label_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,MenuStyle.ACCENT)
