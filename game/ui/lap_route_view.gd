class_name LapRouteView
extends Control
## Crisp vector centreline, no per-race raster assets. Geometry fits on resize only.
signal point_selected(index: int)
var route := PackedVector2Array()
var lap: Dictionary = {}
var reference: Dictionary = {}
var boundaries := PackedFloat32Array([0.0,1.0/3.0,2.0/3.0,1.0])
var mode: String = "Speed"
var miniature: bool = false
var selected_point: int = -1
var fitted := PackedVector2Array()
var bounds := Rect2()
var factor: float = 1.0
var origin := Vector2.ZERO
var dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if miniature else Control.MOUSE_FILTER_STOP
	resized.connect(_fit)
	_fit()

func show_lap(value: Dictionary, comparison: Dictionary) -> void:
	lap = value
	reference = comparison
	selected_point = -1
	_fit()

func _fit() -> void:
	fitted.clear()
	if route.size() < 2: return
	bounds = Rect2(Vector2(route[0].x,-route[0].y),Vector2.ZERO)
	for p: Vector2 in route: bounds = bounds.expand(Vector2(p.x,-p.y))
	for event: Dictionary in lap.get("events", []):
		var p: Vector2 = event.position
		bounds = bounds.expand(Vector2(p.x,-p.y))
	# A dedicated left gutter keeps the route stroke out of the stacked legend.
	var area := Rect2(Vector2(10,10),size-Vector2(20,20)) if miniature else Rect2(Vector2(_legend_rect().end.x+18,16),size-Vector2(_legend_rect().end.x+83,66))
	factor = maxf(0.001,minf(area.size.x/maxf(bounds.size.x,0.1),area.size.y/maxf(bounds.size.y,0.1)))
	origin = area.position+(area.size-bounds.size*factor)*0.5
	for p: Vector2 in route: fitted.append(_screen(p))
	if miniature and fitted[0].distance_to(fitted[-1]) > 0.01: fitted.append(fitted[0])
	queue_redraw()

func _screen(p: Vector2) -> Vector2:
	return origin+(Vector2(p.x,-p.y)-bounds.position)*factor

static func speed_color(value: float) -> Color:
	var colors: Array[Color] = [Color("3886ef"),Color("27d7e0"),Color("54e394"),Color("e4ee59"),Color("ffbc40"),Color("f36a44")]
	var t: float = clampf(value,0.0,1.0)*(colors.size()-1)
	return colors[mini(int(t),colors.size()-2)].lerp(colors[mini(int(t)+1,colors.size()-1)],t-floorf(t)) if t < colors.size()-1 else colors[-1]

func _segment_color(progress: float, low: float, high: float) -> Color:
	if lap.get("samples",[]).is_empty(): return MenuStyle.MUTED
	if mode == "Time diff":
		if reference.get("samples",[]).is_empty(): return MenuStyle.MUTED
		var delta: float = LapTelemetry.at(lap,progress)-LapTelemetry.at(reference,progress)
		return Color("9bb6c5").lerp(Color("ed8056") if delta > 0 else Color("55dbaa"),clampf(absf(delta)/0.6,0.0,1.0))
	if mode == "Sectors":
		for i: int in range(boundaries.size()-1):
			if progress <= boundaries[i+1]: return _sector_color(i)
	return speed_color((LapTelemetry.at(lap,progress,"speed")-low)/maxf(high-low,1.0))

func _sector_color(index: int) -> Color:
	if reference.get("samples",[]).is_empty(): return MenuStyle.MUTED
	var sectors: Array[Dictionary] = LapTelemetry.sectors(lap,boundaries)
	var fastest_sectors: Array[Dictionary] = LapTelemetry.sectors(reference,boundaries)
	if index < 0 or index >= sectors.size() or index >= fastest_sectors.size(): return MenuStyle.MUTED
	var delta: float = float(sectors[index].time)-float(fastest_sectors[index].time)
	return Color("ed8056") if delta > 0.0005 else (Color("55dbaa") if delta < -0.0005 else Color("9bb6c5"))

func _draw() -> void:
	if fitted.size() < 2: return
	if miniature:
		draw_polyline(fitted,Color("8baabd"),2.5,true)
		return
	draw_polyline(fitted,Color(0.32,0.43,0.47,0.24),22,true)
	draw_polyline(fitted,Color("08141e"),17,true)
	var low: float = INF
	var high: float = 0.0
	for p: Dictionary in lap.get("samples",[]):
		low = minf(low,float(p.speed))
		high = maxf(high,float(p.speed))
	for i: int in range(fitted.size()-1):
		var color: Color = _segment_color(float(i)/(fitted.size()-1),low,high)
		draw_line(fitted[i],fitted[i+1],color,7,true)
		draw_circle(fitted[i],3.5,color,true,-1,true)
	if mode == "Sectors": _draw_sector_ends()
	# Start/finish chequered flag.
	var start: Vector2 = fitted[0]
	for x: int in range(4):
		for y: int in range(3): draw_rect(Rect2(start+Vector2(x*4-8,y*4-6),Vector2(4,4)),Color.WHITE if (x+y)%2 == 0 else Color("111e27"))
	var sectors: Array[Dictionary] = LapTelemetry.sectors(lap,boundaries)
	var occupied: Array[Rect2] = [_legend_rect()]
	for event: Dictionary in lap.get("events", []):
		occupied.append(Rect2(_screen(event.position)-Vector2(10,10),Vector2(20,20)))
	if selected_point >= 0: occupied.append(_tooltip_rect())
	for i: int in range(sectors.size()):
		var middle: int = clampi(roundi((float(sectors[i].start)+float(sectors[i].end))*0.5*(fitted.size()-1)),0,fitted.size()-1)
		var p: Vector2 = fitted[middle]
		var label_rect: Rect2 = _sector_label_rect(p,occupied)
		occupied.append(label_rect)
		var label_pos: Vector2 = label_rect.position+Vector2(0,14)
		draw_line(p,_leader_end(p,label_rect),Color("56707e"),1,true)
		draw_string(MenuStyle.BODY,label_pos,"Sector %d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.TEXT)
		draw_string(MenuStyle.BODY,label_pos+Vector2(0,18),("%.2f s" % sectors[i].time) if not lap.get("samples",[]).is_empty() else "\u2014",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)
	for event: Dictionary in lap.get("events", []):
		_draw_incident(_screen(event.position), str(event.kind))
	_draw_legend()
	if selected_point >= 0: _draw_tooltip()
	elif lap.get("samples",[]).is_empty():
		draw_string(MenuStyle.BODY,Vector2(12,20),"Telemetry unavailable for this lap",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MenuStyle.MUTED)

func _draw_sector_ends() -> void:
	# A transverse line keeps boundaries visible when adjacent sectors share a colour.
	for i: int in range(1,boundaries.size()):
		var point_index: int = clampi(roundi(boundaries[i]*(fitted.size()-1)),0,fitted.size()-1)
		var before: Vector2 = fitted[maxi(0,point_index-1)]
		var after: Vector2 = fitted[mini(fitted.size()-1,point_index+1)]
		var tangent: Vector2 = (after-before).normalized()
		if tangent.is_zero_approx(): continue
		var normal := Vector2(-tangent.y,tangent.x)
		var center: Vector2 = fitted[point_index]
		draw_line(center-normal*7.0,center+normal*7.0,Color("07121a"),4.0,true)
		draw_line(center-normal*6.0,center+normal*6.0,Color("f3f7f5"),2.0,true)

func _sector_label_rect(anchor: Vector2, occupied: Array[Rect2]) -> Rect2:
	var best := Rect2(Vector2(8,8),Vector2(84,36))
	var best_score: float = INF
	var outward: float = (anchor-(size-Vector2(0,34))*0.5).angle()
	# Find nearby clear space without assuming any particular track shape.
	for ring: float in [52.0,80.0,110.0]:
		for step: int in range(12):
			var offset: Vector2 = Vector2.from_angle(outward+step*TAU/12.0)*ring
			var position: Vector2 = anchor+offset-Vector2(42,18)
			position.x = clampf(position.x,8,size.x-92)
			position.y = clampf(position.y,4,size.y-76)
			var candidate := Rect2(position,Vector2(84,36))
			var score: float = candidate.get_center().distance_to(anchor)+step*0.05
			for point: Vector2 in fitted:
				if candidate.grow(8).has_point(point): score += 1000.0
			for other: Rect2 in occupied:
				if candidate.grow(4).intersects(other): score += 10000.0
			if score < best_score:
				best = candidate
				best_score = score
	return best

func _legend_rect() -> Rect2:
	var width: float = maxf(MenuStyle.BODY.get_string_size("Off track",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x,MenuStyle.BODY.get_string_size("Collision",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)
	return Rect2(Vector2(8,4),Vector2(31+width-8,48))

static func _leader_end(anchor: Vector2, label_rect: Rect2) -> Vector2:
	# Stop at the label edge so the leader never runs beneath either text row.
	var center: Vector2 = label_rect.get_center()
	var toward_anchor: Vector2 = anchor-center
	if toward_anchor.is_zero_approx():
		return center
	var half: Vector2 = label_rect.size*0.5
	var scale: float = minf(
		half.x/maxf(absf(toward_anchor.x),0.0001),
		half.y/maxf(absf(toward_anchor.y),0.0001)
	)
	return center+toward_anchor*scale

func _draw_legend() -> void:
	_draw_incident(Vector2(18,16), "collision")
	draw_string(MenuStyle.BODY,Vector2(31,21),"Collision",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)
	_draw_incident(Vector2(18,40), "off_track")
	draw_string(MenuStyle.BODY,Vector2(31,45),"Off track",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)
	var left: float = size.x*0.5-110
	var y: float = size.y-16
	if mode == "Sectors":
		draw_string(MenuStyle.BODY,Vector2(size.x*0.5-145,y+4),"Green gains  •  grey matches  •  orange loses",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)
		return
	for i: int in range(100):
		var t: float = i/99.0
		var color: Color = speed_color(t) if mode == "Speed" else (Color("55dbaa").lerp(Color("9bb6c5"),t*2) if t < 0.5 else Color("9bb6c5").lerp(Color("ed8056"),(t-0.5)*2))
		draw_rect(Rect2(left+i*2.2,y-7,2.3,8),color)
	draw_string(MenuStyle.BODY,Vector2(left-58,y+2),"Slower" if mode == "Speed" else "Gaining",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)
	draw_string(MenuStyle.BODY,Vector2(left+232,y+2),"Faster" if mode == "Speed" else "Losing",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MenuStyle.MUTED)

func _draw_incident(at: Vector2, kind: String) -> void:
	draw_circle(at,9,Color("08141e"),true,-1,true)
	if kind == "collision":
		draw_line(at-Vector2(4,4),at+Vector2(4,4),Color("ff796c"),3,true)
		draw_line(at+Vector2(-4,4),at+Vector2(4,-4),Color("ff796c"),3,true)
	else:
		draw_polyline(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,0),at+Vector2(0,6),at+Vector2(-6,0),at+Vector2(0,-6)]),Color("ffcf61"),2,true)

func _draw_tooltip() -> void:
	var p: Dictionary = lap.samples[selected_point]
	var at: Vector2 = _screen(p.position)
	draw_circle(at,8,MenuStyle.ACCENT,false,2,true)
	draw_circle(at,3,Color.WHITE,true,-1,true)
	var tooltip_box: Rect2 = _tooltip_rect()
	var box_pos: Vector2 = tooltip_box.position
	draw_style_box(MenuStyle.card(8),tooltip_box)
	draw_string(MenuStyle.DISPLAY,box_pos+Vector2(10,23),"%d km/h" % roundi(float(p.speed)*3.6),HORIZONTAL_ALIGNMENT_LEFT,-1,23,MenuStyle.TEXT)
	draw_string(MenuStyle.BODY,box_pos+Vector2(10,44),"%d:%05.2f" % [int(float(p.elapsed)/60),fmod(float(p.elapsed),60)],HORIZONTAL_ALIGNMENT_LEFT,-1,16,MenuStyle.MUTED)

func _tooltip_rect() -> Rect2:
	var at: Vector2 = _screen(lap.samples[selected_point].position)
	var box_pos: Vector2 = at+Vector2(15,-62)
	box_pos.x = clampf(box_pos.x,4,size.x-134)
	box_pos.y = clampf(box_pos.y,4,size.y-90)
	return Rect2(box_pos,Vector2(130,55))

func select_nearest(position: Vector2) -> void:
	var nearest: float = INF
	selected_point = -1
	for i: int in range(lap.get("samples",[]).size()):
		var distance: float = _screen(lap.samples[i].position).distance_squared_to(position)
		if distance < nearest:
			nearest = distance
			selected_point = i
	queue_redraw()
	point_selected.emit(selected_point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging: select_nearest(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging: select_nearest(event.position)
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		if dragging: select_nearest(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		select_nearest(event.position)
		accept_event()
