class_name ChallengeGraphic
extends Control
## Original native competition diagrams, with no illustration textures or worlds.
var kind: String = "find"
var accent: Color = MenuStyle.ACCENT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_design(self,Rect2(Vector2.ZERO,size),kind,accent)

static func biome_accent(id: String) -> Color:
	return {"pine":Color("a8b795"),"desert":Color("c7a57b"),"winter":Color("88b5c3"),"night_city":Color("879eb1"),"storm":Color("b2aac4")}.get(id,Color("a8b795"))

static func draw_map_background(canvas: CanvasItem, area: Rect2, tone: Color) -> void:
	canvas.draw_rect(area,Color("10202b"))
	var grid := Color(tone,0.065)
	for x: int in range(1,mini(96,ceili(area.size.x/24.0))):
		var offset: float = area.position.x+x*24
		canvas.draw_line(Vector2(offset,area.position.y),Vector2(offset,area.end.y),grid,1)
	for y: int in range(1,mini(96,ceili(area.size.y/24.0))):
		var offset: float = area.position.y+y*24
		canvas.draw_line(Vector2(area.position.x,offset),Vector2(area.end.x,offset),grid,1)
	canvas.draw_line(area.position,Vector2(area.end.x,area.position.y),Color(tone,0.3),1)

static func draw_design(canvas: CanvasItem, area: Rect2, mode: String, tone: Color, tint: Color = Color.WHITE) -> void:
	if area.size.x < 1 or area.size.y < 1: return
	draw_map_background(canvas,area,tone)
	if mode == "map": return
	var scale: float = minf(area.size.x/640.0,area.size.y/360.0)
	var origin: Vector2 = area.get_center()-Vector2(320,180)*scale
	var ink := Color("08151e")*tint
	var line := Color("77919f")*tint
	var light := Color("e3e9e7")*tint
	var gold: Color = tone*tint
	if mode == "create":
		for index: int in range(3):
			var center: Vector2 = origin+Vector2(140+180*index,180)*scale
			var tile := Rect2(center-Vector2(56,56)*scale,Vector2(112,112)*scale)
			canvas.draw_rect(tile,Color("162c39"))
			canvas.draw_rect(tile,Color(line,0.7),false,maxf(1,scale))
			var icon: String = ["target","compass","car"][index]
			canvas.draw_texture_rect(MenuIcon.texture(icon,true),Rect2(center-Vector2(27,27)*scale,Vector2(54,54)*scale),false,gold if index == 2 else light)
			if index < 2:
				var arrow: Vector2 = center+Vector2(78,0)*scale
				canvas.draw_line(arrow-Vector2(12,0)*scale,arrow+Vector2(12,0)*scale,line,maxf(1,2*scale),true)
				canvas.draw_line(arrow+Vector2(12,0)*scale,arrow+Vector2(4,-8)*scale,line,maxf(1,2*scale),true)
				canvas.draw_line(arrow+Vector2(12,0)*scale,arrow+Vector2(4,8)*scale,line,maxf(1,2*scale),true)
			if area.size.y >= 120:
				_text(canvas,center+Vector2(0,-76)*scale,"0"+str(index+1),16,scale,line)
				_text(canvas,center+Vector2(0,88)*scale,["FORMAT","TRACK","CAR"][index],18,scale,light)
	elif mode == "find":
		for index: int in range(3):
			var tile := Rect2(origin+Vector2(112+index*20,65+index*78)*scale,Vector2(292,68)*scale)
			canvas.draw_rect(tile,Color("172e3b"))
			canvas.draw_rect(tile,Color(line,0.7),false,maxf(1,scale))
			_circuit(canvas,Rect2(tile.position+Vector2(14,12)*scale,Vector2(82,44)*scale),index,light,maxf(1,2*scale))
			canvas.draw_line(tile.position+Vector2(122,23)*scale,tile.position+Vector2(263,23)*scale,line,maxf(1,2*scale),true)
			canvas.draw_line(tile.position+Vector2(122,45)*scale,tile.position+Vector2(214,45)*scale,Color(line,0.45),maxf(1,2*scale),true)
		var lens: Vector2 = origin+Vector2(430,155)*scale
		canvas.draw_circle(lens,66*scale,ink,true,-1,true)
		canvas.draw_arc(lens,66*scale,0,TAU,56,gold,maxf(2,5*scale),true)
		_circuit(canvas,Rect2(lens-Vector2(41,30)*scale,Vector2(82,60)*scale),1,light,maxf(1,2*scale))
		canvas.draw_line(lens+Vector2(48,49)*scale,lens+Vector2(103,105)*scale,gold,maxf(3,12*scale),true)
	elif mode == "duel":
		for index: int in range(2):
			var y: float = 116+index*116
			var a: Vector2 = origin+Vector2(95,y)*scale
			var b: Vector2 = origin+Vector2(520,y)*scale
			canvas.draw_line(a,b,Color(line,0.4),maxf(1,2*scale),true)
			canvas.draw_line(a+Vector2(80,0)*scale,a+Vector2(300,0)*scale,gold if index == 1 else light,maxf(2,5*scale),true)
			_token(canvas,origin+Vector2(190+index*70,y)*scale,30*scale,gold if index == 1 else light)
			_flag(canvas,origin+Vector2(490,y-25)*scale,scale)
		if area.size.y >= 120: _text(canvas,origin+Vector2(320,188)*scale,"VS",32,scale,line)
	elif mode == "group":
		for column: int in range(3):
			for row: int in range(2):
				var center: Vector2 = origin+Vector2(154+column*143+row*22,110+row*112)*scale
				canvas.draw_line(center-Vector2(36,0)*scale,center+Vector2(64,0)*scale,Color(line,0.4),maxf(1,2*scale),true)
				_token(canvas,center,27*scale,gold if column == 0 and row == 1 else light)
		if area.size.y >= 120: _text(canvas,origin+Vector2(320,305)*scale,"UP TO 20 DRIVERS",18,scale,line)
	else:
		for index: int in range(3):
			var center: Vector2 = origin+Vector2(116+204*index,174)*scale
			_circuit(canvas,Rect2(center-Vector2(72,57)*scale,Vector2(144,114)*scale),index,light,maxf(1,3*scale))
			for attempt: int in range(3): canvas.draw_circle(center+Vector2((attempt-1)*18,89)*scale,4*scale,gold,true,-1,true)
			if area.size.y >= 120: _text(canvas,center-Vector2(0,88)*scale,"0"+str(index+1),18,scale,line)

static func _token(canvas: CanvasItem, center: Vector2, radius: float, tone: Color) -> void:
	canvas.draw_circle(center,radius,Color("142936"),true,-1,true)
	canvas.draw_arc(center,radius,0,TAU,32,tone,maxf(1,radius/15),true)
	canvas.draw_circle(center-Vector2(0,radius*0.23),radius*0.23,tone,true,-1,true)
	canvas.draw_arc(center+Vector2(0,radius*0.51),radius*0.47,PI,TAU,16,tone,maxf(1,radius/9),true)

static func _flag(canvas: CanvasItem, origin: Vector2, scale: float) -> void:
	for row: int in range(4):
		for column: int in range(2):
			canvas.draw_rect(Rect2(origin+Vector2(column*10,row*12)*scale,Vector2(10,12)*scale),Color("c5d0d2") if (row+column)%2 == 0 else Color("172b36"))

static func _text(canvas: CanvasItem, center: Vector2, text: String, pixels: int, scale: float, tone: Color) -> void:
	var font_size: int = maxi(10,roundi(pixels*scale))
	var width: float = MenuStyle.DISPLAY.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	canvas.draw_string(MenuStyle.DISPLAY,center-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tone)

static func _circuit(canvas: CanvasItem, area: Rect2, index: int, tone: Color, width: float) -> void:
	var variants: Array = [PackedVector2Array([Vector2(0.1,0.75),Vector2(0.2,0.18),Vector2(0.64,0.1),Vector2(0.9,0.4),Vector2(0.72,0.86),Vector2(0.1,0.75)]),PackedVector2Array([Vector2(0.1,0.1),Vector2(0.85,0.1),Vector2(0.9,0.6),Vector2(0.58,0.6),Vector2(0.58,0.9),Vector2(0.16,0.86),Vector2(0.1,0.1)]),PackedVector2Array([Vector2(0.1,0.55),Vector2(0.24,0.12),Vector2(0.53,0.32),Vector2(0.82,0.1),Vector2(0.92,0.67),Vector2(0.62,0.9),Vector2(0.3,0.74),Vector2(0.1,0.55)])]
	var points: PackedVector2Array = variants[index%3]
	for point: int in range(points.size()): points[point] = area.position+points[point]*area.size
	canvas.draw_polyline(points,tone,width,true)
