class_name EditorCanvas
extends Control
## One finger drags handles or pans; two fingers pan/zoom. No precision gestures required.

signal edit_started
signal document_changed
signal edit_finished
signal hint_changed(text: String)
signal selection_changed

var document: Dictionary
var mode: String = "move"
var zoom: float = 1.0
var pan := Vector2.ZERO
var selected: int = -1
var selected_object: int = -1
var stamp_kind: String = "tree"
var stamp_rotation: float = 0.0
var pending_stamp: bool = false
var press_position := Vector2.ZERO
var drag_origin := Vector2.ZERO
var pointer_origin := Vector2.ZERO
var changed_in_gesture: bool = false
var active_pointer: int = -99
var touches: Dictionary = {}
var dragging: bool = false
var panning: bool = false
var previous_pointer := Vector2.ZERO
var preview: TrackMap
var fitted: bool = false
var native_preview: NativeTrack

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		if not fitted: fit()
		queue_redraw())
	preview = TrackMap.new()
	preview.visible = false
	add_child(preview)

func scale_factor() -> float:
	return maxf(0.01, minf(size.x / 110.0, size.y / 90.0)) * zoom

func to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + pan + Vector2(point.x, -point.y) * scale_factor()

func to_world(point: Vector2) -> Vector2:
	var local: Vector2 = (point - size * 0.5 - pan) / scale_factor()
	return Vector2(local.x, -local.y)

func fit() -> void:
	if size.x < 10 or size.y < 10: return
	fitted = true
	zoom = 1.0
	pan = Vector2.ZERO
	if not document.is_empty():
		var bounds := Rect2(Vector2(document.points[0][0], document.points[0][1]), Vector2.ZERO)
		for p: Array in document.points: bounds = bounds.expand(Vector2(p[0], p[1]))
		var base: float = scale_factor()
		zoom = clampf(minf(size.x / (bounds.size.x + 24), size.y / (bounds.size.y + 24)) / base, 0.4, 3.0)
		pan = -Vector2(bounds.get_center().x, -bounds.get_center().y) * scale_factor()
	queue_redraw()

func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.4, 3.0)
	queue_redraw()

func refresh() -> void:
	native_preview = null
	queue_redraw()

func show_native(track: NativeTrack) -> void:
	native_preview = track
	preview.show_track(track)
	queue_redraw()

func cancel_gesture() -> void:
	if dragging and changed_in_gesture: edit_finished.emit()
	pending_stamp = false
	dragging = false
	panning = false
	active_pointer = -99
	touches.clear()

func _gui_input(event: InputEvent) -> void:
	if document.is_empty(): return
	# Menus/text fields use Godot mouse emulation; this canvas handles every
	# native finger itself, so ignore the duplicate synthesized mouse stream.
	if event is InputEventMouse and event.device == -1:
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(event.position, -1)
			else: _end(-1)
	elif event is InputEventMouseMotion and active_pointer == -1:
		_move(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
			if touches.size() == 1: _begin(event.position, event.index)
			else:
				pending_stamp = false
				if dragging and changed_in_gesture: edit_finished.emit()
				dragging = false
		else:
			touches.erase(event.index)
			if event.canceled: pending_stamp = false
			_end(event.index)
	elif event is InputEventScreenDrag:
		if not touches.has(event.index): return
		if touches.size() >= 2:
			var keys: Array = touches.keys()
			var a: Vector2 = touches[keys[0]]
			var b: Vector2 = touches[keys[1]]
			touches[event.index] = event.position
			var next_a: Vector2 = touches[keys[0]]
			var next_b: Vector2 = touches[keys[1]]
			pan += (next_a + next_b - a - b) * 0.5
			zoom_by(next_a.distance_to(next_b) / maxf(20.0, a.distance_to(b)))
			if touches.has(active_pointer): previous_pointer = touches[active_pointer]
		else:
			touches[event.index] = event.position
			if active_pointer == event.index: _move(event.position)
	accept_event()

func _begin(point: Vector2, pointer: int) -> void:
	active_pointer = pointer
	previous_pointer = point
	press_position = point
	pointer_origin = to_world(point)
	changed_in_gesture = false
	pending_stamp = mode in ["add","place"]
	if pending_stamp: return
	selected = -1
	selected_object = -1
	var nearest: float = 30.0
	if mode == "objects":
		for i: int in range(document.objects.size()-1,-1,-1):
			var object: Dictionary = document.objects[i]
			var center: Vector2 = to_screen(Vector2(object.position[0],object.position[1]))
			if center.distance_to(point) < nearest or CreatorObjects.contains(object,to_world(point)):
				selected_object = i
				break
	else:
		for i: int in range(document.points.size()):
			var p: Array = document.points[i]
			var distance: float = to_screen(Vector2(p[0],p[1])).distance_to(point)
			if distance < nearest:
				nearest = distance
				selected = i
	selection_changed.emit()
	if selected >= 0 or selected_object >= 0:
		var value: Array = document.points[selected] if selected >= 0 else document.objects[selected_object].position
		drag_origin = Vector2(value[0],value[1])
		dragging = true
	else: panning = true
	queue_redraw()

func _move(point: Vector2) -> void:
	if pending_stamp:
		if press_position.distance_to(point) > 12:
			pending_stamp = false
			panning = true
	if dragging:
		var position: Vector2 = (drag_origin+to_world(point)-pointer_origin).snapped(Vector2.ONE).clamp(Vector2(-110,-110),Vector2(110,110))
		if position.distance_to(drag_origin) > 0.1 and not changed_in_gesture:
			edit_started.emit()
			changed_in_gesture = true
		if changed_in_gesture:
			if selected >= 0: document.points[selected] = [position.x,position.y]
			elif selected_object >= 0: document.objects[selected_object].position = [position.x,position.y]
			document_changed.emit()
	elif panning: pan += point-previous_pointer
	previous_pointer = point
	queue_redraw()

func _place(point: Vector2) -> void:
	var position: Vector2 = to_world(point).snapped(Vector2.ONE).clamp(Vector2(-110,-110),Vector2(110,110))
	if mode == "place":
		if document.objects.size() >= 96:
			hint_changed.emit("Use up to 96 objects. Select one to move or remove it.")
			return
		edit_started.emit()
		document.objects.append({"kind":stamp_kind,"position":[position.x,position.y],"rotation":stamp_rotation})
		selected_object = document.objects.size()-1
		selected = -1
	else:
		if document.points.size() >= TrackDocument.MAX_POINTS:
			hint_changed.emit("Use up to 24 road nodes.")
			return
		var index: int = 0
		var distance: float = INF
		for i: int in range(document.points.size()):
			var a: Array = document.points[i]
			var b: Array = document.points[(i+1)%document.points.size()]
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point,to_screen(Vector2(a[0],a[1])),to_screen(Vector2(b[0],b[1])))
			if closest.distance_to(point) < distance:
				distance = closest.distance_to(point)
				index = i+1
		edit_started.emit()
		var width: float = (float(document.widths[index-1])+float(document.widths[index%document.widths.size()]))*0.5
		document.points.insert(index,[position.x,position.y])
		document.widths.insert(index,width)
		document.corners.insert(index,"sharp")
		selected = index
		selected_object = -1
		mode = "move" # New node is immediately ready to drag and adjust.
	document_changed.emit()
	edit_finished.emit()
	selection_changed.emit()
	queue_redraw()

func _end(pointer: int) -> void:
	if pointer != active_pointer: return
	if pending_stamp: _place(press_position)
	if dragging and changed_in_gesture: edit_finished.emit()
	pending_stamp = false
	dragging = false
	panning = false
	active_pointer = -99
	if not touches.is_empty():
		active_pointer = int(touches.keys()[0])
		previous_pointer = touches[active_pointer]
		panning = true
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: cancel_gesture()

func _draw() -> void:
	if document.is_empty() or size.x < 10 or size.y < 10: return
	var palette: Array[Color] = TrackTheme.palette(str(document.theme))
	draw_style_box(MenuStyle.box(palette[1].darkened(0.2)), Rect2(Vector2.ZERO, size))
	if native_preview != null and preview.surface_texture != null:
		var corner: Vector2 = to_screen(Vector2(-native_preview.half_extent.x,native_preview.half_extent.y))
		draw_texture_rect(preview.surface_texture, Rect2(corner,native_preview.half_extent * 2.0 * scale_factor()), false)
	var spacing: float = 10.0 * scale_factor()
	var origin: Vector2 = to_screen(Vector2.ZERO)
	for x: float in range(ceili(size.x / spacing) + 1):
		var xx: float = fposmod(origin.x, spacing) + x * spacing
		draw_line(Vector2(xx,0),Vector2(xx,size.y),Color(1,1,1,0.035))
	for y: float in range(ceili(size.y / spacing) + 1):
		var yy: float = fposmod(origin.y, spacing) + y * spacing
		draw_line(Vector2(0,yy),Vector2(size.x,yy),Color(1,1,1,0.035))
	var sampled: Dictionary = TrackDocument.route_data(document)
	var route: PackedVector2Array = sampled.points
	if native_preview == null:
		for i: int in range(route.size()):
			var a: Vector2 = to_screen(route[i])
			var b: Vector2 = to_screen(route[(i+1)%route.size()])
			var width: float = float(sampled.widths[i])*scale_factor()
			draw_line(a,b,palette[5],width+2*scale_factor(),true)
			draw_circle(a,width*0.5+scale_factor(),palette[5])
		for i: int in range(route.size()):
			var a: Vector2 = to_screen(route[i])
			var b: Vector2 = to_screen(route[(i+1)%route.size()])
			var width: float = float(sampled.widths[i])*scale_factor()
			var color: Color = palette[2] if document.surface == "dirt" else palette[0]
			draw_line(a,b,color,width,true)
			draw_circle(a,width*0.5,color)
	if route.size() > 1:
		var start: Vector2 = to_screen(route[0])
		var across: Vector2 = Vector2((route[1]-route[0]).y,(route[1]-route[0]).x).normalized() * TrackDocument.node_width(document,0) * scale_factor() * 0.5
		draw_line(start-across,start+across,Color("e0e7dd"),3,true)
		var direction: Vector2 = (to_screen(route[1])-start).normalized()
		var arrow: Vector2 = start + direction * 24
		draw_line(arrow-direction.rotated(0.65)*12,arrow,Color("edf1f3"),3,true)
		draw_line(arrow-direction.rotated(-0.65)*12,arrow,Color("edf1f3"),3,true)
	for i: int in range(document.points.size()):
		var p: Array = document.points[i]
		var center: Vector2 = to_screen(Vector2(p[0],p[1]))
		draw_circle(center, 25, Color(0.07,0.11,0.13,0.75))
		draw_arc(center, 24, 0, TAU, 32, Color("d9e3e2") if selected == i else Color("90a59d"), 2, true)
		draw_string(ThemeDB.fallback_font,center+Vector2(-6,6),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("edf1f3"))
		if i == selected:
			draw_string(ThemeDB.fallback_font,center+Vector2(30,6),"%.1f m" % TrackDocument.node_width(document,i),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("edf1f3"))
		if i == 0:
			draw_string(ThemeDB.fallback_font, center + Vector2(-23,-34), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("edf1f3"))
	for i: int in range(document.get("objects",[]).size()):
		var object: Dictionary = document.objects[i]
		var outline := PackedVector2Array()
		for point: Vector2 in CreatorObjects.outline(object): outline.append(to_screen(point))
		var color: Color = palette[CreatorObjects.surface(object.kind)]
		draw_colored_polygon(outline,color.lightened(0.12))
		outline.append(outline[0])
		draw_polyline(outline,Color("edf1f3") if selected_object == i else Color("26342f"),3,true)
		var center: Vector2 = to_screen(Vector2(object.position[0],object.position[1]))
		draw_string(ThemeDB.fallback_font,center+Vector2(-5,5),object.kind.left(1).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("edf1f3"))
	draw_string(ThemeDB.fallback_font, Vector2(18,size.y-18), "10 m grid  /  %d handles" % document.points.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d0d9d4"))
