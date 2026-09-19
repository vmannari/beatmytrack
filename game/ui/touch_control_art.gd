class_name TouchControlArt
extends Control
## Retained vector commands for one button state; prepared during countdown.
var vehicle_id: String = "compact"
var button_index: int = 0
var pressed: bool = false
var draw_count: int = 0
var artwork_rect := Rect2()

func _draw() -> void:
	draw_count += 1
	draw_set_transform(artwork_rect.position,0.0,artwork_rect.size/Vector2(100,100))
	_draw_control(button_index,pressed)


func _plate(rect: Rect2, color: Color, radius: int, edge: Color, width: int = 2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)


func _draw_control(index: int, pressed: bool) -> void:
	var ink := Color("0b1820")
	var metal := Color("a7b5b7")
	var accent := Color("749aa8")
	var radius: int = 14
	match vehicle_id:
		"pickup":
			metal = Color("929c8f")
			accent = Color("b5b78c")
			radius = 5
		"classic":
			metal = Color("c5b99c")
			accent = Color("c59a69")
			radius = 22
		"formula":
			metal = Color("b2bec4")
			accent = Color("b88778")
			radius = 6
		"kart":
			metal = Color("b5bbb0")
			accent = Color("95ad83")
			radius = 28
	var steering: bool = index < 2
	if not steering:
		_draw_pedal(index, pressed, metal, accent)
		return
	var bounds := Rect2(3,3,94,91)
	if vehicle_id == "kart" and not steering: bounds = Rect2(16,3,68,91)
	if vehicle_id == "classic" and index == 3: bounds = Rect2(14,3,72,91)
	_plate(Rect2(bounds.position + Vector2(0,5),bounds.size), Color("06101899"),radius,Color("06101899"))
	_plate(bounds, ink, radius, ink)
	var face: Rect2 = bounds.grow(-4)
	face.position.y += 3 if pressed else 0
	face.size.y -= 5
	_plate(face, Color("33434a") if steering else metal, radius-3, RaceHUDStyle.GOLD if pressed else metal.darkened(0.3))
	# A single light edge and deep lower bevel create the same inked planes as the cars.
	draw_line(face.position+Vector2(12,3),Vector2(face.end.x-12,face.position.y+3),metal.lightened(0.22),2,true)
	var center: Vector2 = face.get_center()
	if steering:
		var rim: Color = accent if not pressed else RaceHUDStyle.GOLD
		if vehicle_id in ["classic","kart","compact"]:
			draw_arc(center,30,0.25,PI*2-0.25,40,ink,9,true)
			draw_arc(center,30,0.25,PI*2-0.25,40,rim,4,true)
			draw_line(center+Vector2(0,16),center+Vector2(0,28),rim,4,true)
		elif vehicle_id == "formula":
			_plate(Rect2(center-Vector2(35,24),Vector2(13,48)),ink,5,accent)
			_plate(Rect2(center+Vector2(22,-24),Vector2(13,48)),ink,5,accent)
		else:
			for x: float in [18.0,82.0]:
				for y: float in [19.0,66.0]:
					draw_circle(Vector2(x,y),3,metal)
		var direction: float = -1.0 if index == 0 else 1.0
		var points := PackedVector2Array([center+Vector2(-6*direction,-12),center+Vector2(7*direction,0),center+Vector2(-6*direction,12)])
		draw_polyline(points,ink,10,true)
		draw_polyline(points,RaceHUDStyle.GOLD if pressed else RaceHUDStyle.TEXT,5,true)
	# Gold foot / thumb witness remains readable without relying on colour alone.
	var marker: Color = RaceHUDStyle.GOLD if pressed else accent
	_plate(Rect2(center.x-12,bounds.end.y-5,24,4),marker,2,marker,1)

func _pedal_contour(rect: Rect2, taper: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position+Vector2(taper+5,0), Vector2(rect.end.x-taper-5,rect.position.y),
		Vector2(rect.end.x-taper,rect.position.y+5), Vector2(rect.end.x,rect.end.y-7),
		rect.end-Vector2(7,0), Vector2(rect.position.x+7,rect.end.y),
		Vector2(rect.position.x,rect.end.y-7), rect.position+Vector2(taper,5)])


func _pedal_shape(rect: Rect2, taper: float, fill: Color, edge: Color) -> void:
	var points: PackedVector2Array = _pedal_contour(rect,taper)
	draw_colored_polygon(points,fill)
	points.append(points[0])
	draw_polyline(points,edge,2,true)


func _fastener(point: Vector2, metal: Color) -> void:
	draw_circle(point+Vector2(0,1),3.8,Color("142027"))
	draw_circle(point,2.7,metal.lightened(0.18))
	draw_arc(point,2.7,PI,TAU,10,metal.lightened(0.4),1,true)
	draw_line(point-Vector2(1.4,0),point+Vector2(1.4,0),Color("26343a"),1.2,true)


func _draw_pedal(index: int, pressed: bool, metal: Color, accent: Color) -> void:
	var ink := Color("0b171d")
	var gas: bool = index == 3
	var racing: bool = vehicle_id in ["classic","formula","kart"]
	var width: float = 59.0 if gas else 84.0
	if vehicle_id == "kart": width = 48.0 if gas else 60.0
	var top: float = 9.0 if gas else 17.0
	var rect := Rect2(50-width/2,top,width,78-top)
	var taper: float = 5.0 if gas else 2.0
	# Exposed bent steel arm and pivot: the face reads as a pedal, not a UI tile.
	_plate(Rect2(42,1,16,92),ink,4,ink)
	_plate(Rect2(46,2,9,88),metal.darkened(0.55),2,ink,1)
	draw_line(Vector2(48,4),Vector2(48,87),metal.darkened(0.05),2,true)
	_plate(Rect2(37,86,26,8),metal.darkened(0.45),3,ink)
	_fastener(Vector2(42,90),metal)
	_fastener(Vector2(58,90),metal)
	if pressed: rect.position.y += 4
	var shadow: Rect2 = rect
	shadow.position += Vector2(3,7 if not pressed else 3)
	_pedal_shape(shadow,taper,Color("06101488"),Color("06101488"))
	var thickness: Rect2 = rect
	thickness.position.y += 5 if not pressed else 2
	_pedal_shape(thickness,taper,metal.darkened(0.6),ink)
	_pedal_shape(rect,taper,metal, RaceHUDStyle.GOLD if pressed else ink)
	# Broad, hard cel planes establish curvature without glossy gradients.
	var points: PackedVector2Array = _pedal_contour(rect,taper)
	draw_colored_polygon(PackedVector2Array([points[1],points[2],points[3],points[4],points[4]-Vector2(8,0),points[1]-Vector2(6,0)]),metal.darkened(0.22))
	draw_polyline(PackedVector2Array([points[7],points[0],points[1]]),metal.lightened(0.32),2,true)
	var grip: Rect2 = rect.grow(-9)
	if racing:
		# Countersunk holes: a dark bore, lower inner wall and bright machined lip.
		var columns: int = 2 if gas or vehicle_id == "kart" else 3
		for row: int in range(3):
			for col: int in range(columns):
				var point: Vector2 = grip.position+Vector2((col+0.5)*grip.size.x/columns,(row+0.5)*grip.size.y/3)
				draw_circle(point,5,metal.darkened(0.38))
				draw_circle(point+Vector2(0,-0.7),3.4,ink)
				draw_arc(point,4.7,0.15,PI-0.15,12,metal.lightened(0.32),1.3,true)
	else:
		_pedal_shape(grip.grow(2),1,Color("26302f"),ink)
		for row: int in range(5):
			var y: float = grip.position.y+2+row*(grip.size.y-3)/5
			# Rubber ribs have raised shoulders and polished contact centres.
			var rib := Rect2(grip.position.x+2,y,grip.size.x-4,5)
			_plate(rib,Color("434b46"),1,ink,1)
			draw_line(rib.position+Vector2(2,0),Vector2(rib.end.x-3,y),Color("697069"),1.3,true)
			if row in [1,2,3]:
				draw_line(Vector2(47,y+1),Vector2(56 if gas else 62,y+1),Color("8b8f7e"),1.4,true)
	# Two mounting screws, offset wear on contact edges, no random/noisy texture.
	_fastener(Vector2(rect.get_center().x,rect.position.y+4),metal)
	_fastener(Vector2(rect.get_center().x,rect.end.y-4),metal)
	for offset: float in [0.0,5.0,11.0]:
		var point := Vector2(rect.position.x+4+offset,rect.end.y-5)
		draw_line(point,point+Vector2(3,-1),metal.lightened(0.38),1.4,true)
	if racing:
		draw_line(rect.position+Vector2(12,15),rect.position+Vector2(16,12),metal.lightened(0.27),1,true)
		draw_line(rect.position+Vector2(14,18),rect.position+Vector2(19,14),metal.lightened(0.27),1,true)
	# Caption belongs to the HUD, not printed across the shoe-contact surface.
	var label: String = "GAS" if gas else "BRAKE"
	var font: Font = RaceHUDStyle.DISPLAY
	var text_width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var baseline := Vector2(50-text_width/2,99)
	draw_string_outline(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,ink)
	draw_string(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,RaceHUDStyle.GOLD if pressed else RaceHUDStyle.TEXT)
	draw_line(Vector2(36,82),Vector2(64,82),RaceHUDStyle.GOLD if pressed else accent,2,true)
