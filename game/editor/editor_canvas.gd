class_name EditorCanvas
extends Control
## One finger drags handles or pans; two fingers pan/zoom. No precision gestures required.

signal edit_started
signal document_changed
signal edit_finished
signal hint_changed(text: String)
signal selection_changed
signal native_changed(track: NativeTrack)

var document: Dictionary
var mode: String = "road"
var world_backdrop: bool = false
var selected_piece: int = -1
var ghost: Dictionary = {}
var piece_kind: String = "straight"
var snap_enabled: bool = true
var snap_matched: bool = false
var road_action: String = "move"
var geometry_drag: String = ""
var geometry_origin: float = 0.0
var endpoint_drag: int = -1
var piece_before_drag: Dictionary = {}
var desktop_pan: bool = false
var pending_road_tap: bool = false
var protect_road: bool = true
var free_run: bool = false
var run_start := Vector2.INF
var run_preview: Array = []
var issue_marker := Vector2.INF
var issue_text: String = ""
var brush_surface: int = 0
var brush_width: float = 10.0
var brush_shape: String = "round"
var paint_points: Array = []
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		for p: Array in document.layout.get("points",[]): bounds = bounds.expand(Vector2(p[0],p[1]))
		for piece: Dictionary in document.get("pieces",[]):
			for p: Vector2 in RoadPieces.samples(piece):
				bounds = bounds.expand(p-Vector2.ONE*float(piece.width)*0.5).expand(p+Vector2.ONE*float(piece.width)*0.5)
		for stroke: Dictionary in document.paint:
			for p: Array in stroke.points:
				var center := Vector2(p[0],p[1])
				var radius: Vector2 = Vector2.ONE*float(stroke.width)*0.5
				bounds = bounds.expand(center-radius).expand(center+radius)
		for object: Dictionary in document.objects:
			for p: Vector2 in CreatorObjects.outline(object): bounds = bounds.expand(p)
		if document.base_track != "" and native_preview != null: bounds = Rect2(-native_preview.half_extent,native_preview.half_extent*2)
		var base: float = scale_factor()
		zoom = clampf(minf((size.x-24) / (bounds.size.x + 24), (size.y-156) / (bounds.size.y + 24)) / base, 0.25, 16.0)
		pan = -Vector2(bounds.get_center().x, -bounds.get_center().y) * scale_factor()
	queue_redraw()

func zoom_by(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	if anchor == Vector2.INF: anchor = size*0.5
	var before: Vector2 = to_world(anchor)
	zoom = clampf(zoom * factor, 0.25, 16.0)
	pan += anchor-to_screen(before)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func show_native(track: NativeTrack) -> void:
	native_preview = track
	preview.show_track(track)
	native_changed.emit(track)
	queue_redraw()

func cancel_gesture() -> void:
	if dragging and changed_in_gesture: edit_finished.emit()
	paint_points.clear()
	pending_stamp = false
	dragging = false
	panning = false
	active_pointer = -99
	touches.clear()
	desktop_pan = false
	pending_road_tap = false

func _gui_input(event: InputEvent) -> void:
	if document.is_empty(): return
	if event is InputEventKey: return
	# Menus/text fields use Godot mouse emulation; this canvas handles every
	# native finger itself, so ignore the duplicate synthesized mouse stream.
	if event is InputEventMouse and event.device == -1:
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(1.15,event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1.0 / 1.15,event.position)
		elif event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT] or (event.button_index == MOUSE_BUTTON_LEFT and (desktop_pan or Input.is_physical_key_pressed(KEY_SPACE))):
			if event.pressed:
				cancel_gesture()
				desktop_pan = true
				active_pointer = -int(event.button_index)
				previous_pointer = event.position
			else:
				desktop_pan = false
				active_pointer = -99
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(event.position, -1)
			else: _end(-1)
	elif event is InputEventMouseMotion and active_pointer < 0 and active_pointer != -99:
		_move(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
			if touches.size() == 1: _begin(event.position, event.index)
			else:
				pending_road_tap = false
				paint_points.clear()
				pending_stamp = false
				if dragging and changed_in_gesture: edit_finished.emit()
				dragging = false
		else:
			var was_pinching: bool = touches.size() >= 2
			touches.erase(event.index)
			if event.canceled:
				pending_road_tap = false
				pending_stamp = false
				paint_points.clear()
			_end(event.index)
			if was_pinching and touches.size() == 1:
				# Either finger may lift first. The remaining finger continues
				# navigation, including after a platform cancellation event.
				active_pointer = int(touches.keys()[0])
				previous_pointer = touches[active_pointer]
				dragging = false
				panning = true
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
			zoom_by(next_a.distance_to(next_b) / maxf(20.0, a.distance_to(b)),(next_a+next_b)*0.5)
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
	if mode == "road":
		_begin_road(point)
		return
	if mode in ["run","start"]:
		pending_stamp = true
		return
	if mode == "paint":
		paint_points = [_paint_position(point)]
		queue_redraw()
		return
	if mode == "pan":
		panning = true
		return
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
		if selected_object < 0 and native_preview != null and document.objects.size() < 96:
			for object: Dictionary in native_preview.metadata.get("scenery_objects",[]):
				if CreatorObjects.contains(object,to_world(point)) or to_screen(Vector2(object.position[0],object.position[1])).distance_to(point) < 24:
					edit_started.emit()
					if not document.has("hidden_scenery"): document["hidden_scenery"] = []
					document.hidden_scenery.append(CreatorScenery.key(object))
					document.objects.append(object.duplicate(true))
					changed_in_gesture = true
					selected_object = document.objects.size()-1
					document_changed.emit()
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
	if desktop_pan:
		pan += point-previous_pointer
		previous_pointer = point
		queue_redraw()
		return
	if pending_road_tap and press_position.distance_to(point) > 8:
		pending_road_tap = false
		panning = true
	if mode == "road" and dragging:
		_move_road(point)
		previous_pointer = point
		return
	if mode == "run" and run_start != Vector2.INF:
		run_preview = _object_run(run_start,to_world(point))
	if not paint_points.is_empty():
		var p: Array = _paint_position(point)
		if Vector2(p[0],p[1]).distance_to(Vector2(paint_points[-1][0],paint_points[-1][1])) >= 0.5 and paint_points.size() < 512:
			paint_points.append(p)
		queue_redraw()
		return
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
	if mode == "start":
		edit_started.emit()
		var heading: float = 0.0
		if native_preview != null:
			var nearest_route: float = INF
			for i: int in range(native_preview.route.size()):
				var a: Vector2 = native_preview.route[i]
				var b: Vector2 = native_preview.route[(i+1)%native_preview.route.size()]
				var distance: float = Geometry2D.get_closest_point_to_segment(position,a,b).distance_squared_to(position)
				if distance < nearest_route:
					nearest_route = distance
					heading = fposmod(rad_to_deg((b-a).angle()),360)
		var nearest_piece: float = INF
		for piece: Dictionary in document.pieces:
			var samples: PackedVector2Array = RoadPieces.samples(piece)
			for i: int in range(samples.size()-1):
				var distance: float = Geometry2D.get_closest_point_to_segment(position,samples[i],samples[i+1]).distance_squared_to(position)
				if distance < nearest_piece and distance <= float(piece.width)*float(piece.width)*0.25:
					nearest_piece = distance
					heading = fposmod(rad_to_deg((samples[i+1]-samples[i]).angle()),360)
		document["practice_start"] = {"position":[position.x,position.y],"heading":heading}
		mode = "move"
		document_changed.emit()
		edit_finished.emit()
		selection_changed.emit()
		queue_redraw()
		return
	if mode == "run":
		if run_start == Vector2.INF:
			run_start = position
			hint_changed.emit("Tap the end of the free wall line." if free_run else "Tap the end of the run. Barriers follow the nearest road edge.")
		else:
			run_preview = _object_run(run_start,position)
			if not run_preview.is_empty():
				edit_started.emit()
				document.objects.append_array(run_preview)
				document_changed.emit()
				edit_finished.emit()
				hint_changed.emit("%d objects placed." % run_preview.size())
			run_start = Vector2.INF
			run_preview.clear()
		queue_redraw()
		return
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
			hint_changed.emit("Use up to 96 route nodes.")
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
	if pending_road_tap and not ghost.is_empty():
		var target: Vector2 = to_world(press_position)
		var trial: Dictionary = ghost.duplicate(true)
		trial.position = [target.x,target.y]
		if RoadPieces.validate(trial).is_empty():
			ghost = trial
			_snap_ghost()
		selection_changed.emit()
	pending_road_tap = false
	if not paint_points.is_empty():
		if document.paint.size() < 256:
			edit_started.emit()
			document.paint.append({"surface":brush_surface,"width":brush_width,"shape":brush_shape,"points":paint_points.duplicate(true),"protect_road":protect_road and brush_surface != 0})
			document_changed.emit()
			edit_finished.emit()
		else: hint_changed.emit("Paint limit reached. Undo a stroke to keep editing.")
		paint_points.clear()
	if pending_stamp: _place(press_position)
	if dragging and changed_in_gesture:
		edit_finished.emit()
		if geometry_drag != "": selection_changed.emit()
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
	if not world_backdrop: draw_style_box(MenuStyle.box(palette[1].darkened(0.2)), Rect2(Vector2.ZERO, size))
	if not world_backdrop and native_preview != null and preview.surface_texture != null:
		var corner: Vector2 = to_screen(Vector2(-native_preview.half_extent.x,native_preview.half_extent.y))
		draw_texture_rect(preview.surface_texture, Rect2(corner,native_preview.half_extent * 2.0 * scale_factor()), false)
	if world_backdrop and native_preview != null and document.base_track == "" and (document.layout.is_empty() or not document.pieces.is_empty()):
		var extent: Vector2 = native_preview.half_extent-Vector2.ONE*native_preview.cell_size
		var corners: Array[Vector2] = [to_screen(Vector2(-extent.x,extent.y)),to_screen(extent),to_screen(Vector2(extent.x,-extent.y)),to_screen(-extent)]
		for i: int in range(4): draw_dashed_line(corners[i],corners[(i+1)%4],Color(0.85,0.92,0.85,0.28),1.0,8.0,true)
	var grid_metres: float = 0.5 if scale_factor() > 40 else 1.0 if scale_factor() > 14 else 5.0 if scale_factor() > 6 else 10.0
	var spacing: float = grid_metres * scale_factor()
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
	if mode in ["move","add"]:
		var line := PackedVector2Array()
		for p: Vector2 in route: line.append(to_screen(p))
		line.append(line[0])
		draw_polyline(line,Color(1,0.85,0.35,0.9),2,true)
	if route.size() > 1 and mode in ["move","add"]:
		var start: Vector2 = to_screen(route[0])
		var across: Vector2 = Vector2((route[1]-route[0]).y,(route[1]-route[0]).x).normalized() * TrackDocument.node_width(document,0) * scale_factor() * 0.5
		draw_line(start-across,start+across,Color("e0e7dd"),3,true)
		var direction: Vector2 = (to_screen(route[1])-start).normalized()
		var arrow: Vector2 = start + direction * 24
		draw_line(arrow-direction.rotated(0.65)*12,arrow,Color("edf1f3"),3,true)
		draw_line(arrow-direction.rotated(-0.65)*12,arrow,Color("edf1f3"),3,true)
	for i: int in range(document.points.size() if mode in ["move","add"] else 0):
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
		if world_backdrop and (mode not in ["objects","place","run"] or i != selected_object): continue
		var object: Dictionary = document.objects[i]
		var outline := PackedVector2Array()
		for point: Vector2 in CreatorObjects.outline(object): outline.append(to_screen(point))
		var color: Color = palette[CreatorObjects.surface(object.kind)]
		if not world_backdrop: draw_colored_polygon(outline,color.lightened(0.12))
		outline.append(outline[0])
		draw_polyline(outline,Color("edf1f3") if selected_object == i else Color("26342f"),3,true)
		var center: Vector2 = to_screen(Vector2(object.position[0],object.position[1]))
		draw_string(ThemeDB.fallback_font,center+Vector2(-5,5),object.kind.left(1).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("edf1f3"))
	if not paint_points.is_empty():
		var color: Color = palette[brush_surface]
		for i: int in range(paint_points.size()):
			var a: Vector2 = to_screen(Vector2(paint_points[i][0],paint_points[i][1]))
			var b: Vector2 = to_screen(Vector2(paint_points[maxi(0,i-1)][0],paint_points[maxi(0,i-1)][1]))
			var width: float = brush_width*scale_factor()
			draw_line(a,b,color,width,true)
			if brush_shape == "round": draw_circle(a,width*0.5,color)
			else: draw_rect(Rect2(a-Vector2.ONE*width*0.5,Vector2.ONE*width),color)
	if mode == "road":
		for i: int in range(document.get("pieces",[]).size()):
			if i == selected_piece: _draw_piece(document.pieces[i],false)
		if not ghost.is_empty(): _draw_piece(ghost,true)
		for join: Dictionary in RoadPieces.joins(document.get("pieces",[])):
			draw_circle(to_screen(join.position),5,Color("e2efec"),false,2,true)
	if document.has("practice_start") and mode in ["move","add","start"]:
		var start: Vector2 = to_screen(Vector2(document.practice_start.position[0],document.practice_start.position[1]))
		draw_circle(start,14,Color("16c2cf"),false,3,true)
		draw_string(ThemeDB.fallback_font,start+Vector2(20,5),"Practice start",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	if run_start != Vector2.INF: draw_circle(to_screen(run_start),10,Color("16c2cf"),false,3,true)
	for object: Dictionary in run_preview:
		var outline := PackedVector2Array()
		for p: Vector2 in CreatorObjects.outline(object): outline.append(to_screen(p))
		draw_colored_polygon(outline,Color(0.05,0.8,0.86,0.6))
	if issue_marker != Vector2.INF:
		var marker: Vector2 = to_screen(issue_marker)
		draw_circle(marker,22,Color("ec4659"),false,3,true)
		draw_string(ThemeDB.fallback_font,marker+Vector2(-4,6),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		if not issue_text.is_empty():
			var callout: Vector2 = (marker+Vector2(35,-42)).clamp(Vector2(110,90),size-Vector2(305,140))
			var box := StyleBoxFlat.new()
			box.bg_color = Color("25191e")
			box.border_color = Color("ec4659")
			box.set_border_width_all(1)
			box.set_corner_radius_all(6)
			draw_style_box(box,Rect2(callout-Vector2(10,24),Vector2(290,38)))
			draw_string(ThemeDB.fallback_font,callout,issue_text,HORIZONTAL_ALIGNMENT_LEFT,270,16,Color("ffadb5"))
	var ruler: float = 10.0 if scale_factor() < 15 else 2.0
	var base := Vector2(size.x-32,size.y-26)
	draw_line(base-Vector2(ruler*scale_factor(),0),base,Color("e5ece8"),2,true)
	draw_string(ThemeDB.fallback_font,base-Vector2(42,9),"%.1f m" % ruler,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e5ece8"))

func choose_piece(kind: String) -> void:
	cancel_gesture()
	mode = "road"
	selected_piece = -1
	piece_kind = kind
	ghost = RoadPieces.create(kind,to_world(size*0.5)-Vector2(14,0))
	if not document.pieces.is_empty():
		var end: Dictionary = RoadPieces.end_pose(document.pieces[-1])
		ghost = RoadPieces.create(kind,end.position,end.heading,document.pieces[-1].width)
	_snap_ghost()
	selection_changed.emit()
	queue_redraw()

func _snap_ghost() -> void:
	snap_matched = false
	if snap_enabled:
		var match_result: Dictionary = RoadPieces.snap(ghost,document.pieces,selected_piece)
		if RoadPieces.validate(match_result.piece).is_empty() and _valid_bridge_edit(match_result.piece,selected_piece):
			ghost = match_result.piece
			snap_matched = match_result.matched

func confirm_piece() -> void:
	if ghost.is_empty():
		selected_piece = -1
	else:
		var errors: Array[String] = RoadPieces.validate(ghost)
		if not errors.is_empty():
			hint_changed.emit(errors[0])
			return
		if document.pieces.size() >= RoadPieces.MAX_PIECES: return
		if not _valid_bridge_edit(ghost,-1): return
		edit_started.emit()
		document.pieces.append(ghost.duplicate(true))
		ghost.clear()
		selected_piece = -1
		document_changed.emit()
		edit_finished.emit()
	selection_changed.emit()
	queue_redraw()

func _begin_road(point: Vector2) -> void:
	geometry_drag = ""
	endpoint_drag = -1
	pending_road_tap = false
	var current: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece] if selected_piece >= 0 else {}
	if not current.is_empty() and road_action == "move":
		for end: int in range(2):
			var handle: Vector2 = Vector2(current.position[0],current.position[1]) if end == 0 else RoadPieces.end_pose(current).position
			if to_screen(handle).distance_to(point) <= 26:
				endpoint_drag = end
				piece_before_drag = current.duplicate(true)
				dragging = true
				return
	if not current.is_empty() and road_action in ["width","radius","length","angle"] and to_screen(_geometry_handle(current,road_action)).distance_to(point) <= 32:
		geometry_drag = road_action
		geometry_origin = float(current.get(geometry_drag,90.0))
		dragging = true
		return
	if not ghost.is_empty():
		var samples: PackedVector2Array = RoadPieces.samples(ghost)
		var hit: bool = false
		for p: Vector2 in samples:
			if to_screen(p).distance_to(point) < maxf(28,float(ghost.width)*scale_factor()*0.5): hit = true
		if not hit:
			pending_road_tap = true
			return
		drag_origin = Vector2(ghost.position[0],ghost.position[1])
		dragging = true
	else:
		var candidates: Array[int] = []
		if selected_piece >= 0: candidates.append(selected_piece)
		for i: int in range(document.pieces.size()-1,-1,-1):
			if i != selected_piece: candidates.append(i)
		selected_piece = -1
		for i: int in candidates:
			for p: Vector2 in RoadPieces.samples(document.pieces[i]):
				if to_screen(p).distance_to(point) < maxf(24,float(document.pieces[i].width)*scale_factor()*0.5):
					selected_piece = i
					break
			if selected_piece >= 0: break
		if selected_piece >= 0:
			var piece: Dictionary = document.pieces[selected_piece]
			piece_before_drag = piece.duplicate(true)
			for end: int in range(2):
				var handle: Vector2 = Vector2(piece.position[0],piece.position[1]) if end == 0 else RoadPieces.end_pose(piece).position
				if to_screen(handle).distance_to(point) <= 26: endpoint_drag = end
			drag_origin = Vector2(piece.position[0],piece.position[1])
			dragging = true
		else: panning = true
	selection_changed.emit()
	queue_redraw()

func _move_road(point: Vector2) -> void:
	var piece: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece]
	if press_position.distance_to(point) < 3 and not changed_in_gesture: return
	if endpoint_drag >= 0:
		var target: Vector2 = to_world(point)
		if snap_enabled: target = RoadPieces.snap_endpoint(target,document.pieces,selected_piece)
		var trial: Dictionary = RoadPieces.move_endpoint(piece_before_drag,endpoint_drag,target)
		if trial.is_empty():
			hint_changed.emit("Keep the section inside the map and within its size limits.")
			return
		if not _valid_bridge_edit(trial,selected_piece): return
		if ghost.is_empty() and not changed_in_gesture: edit_started.emit()
		changed_in_gesture = true
		if ghost.is_empty():
			document.pieces[selected_piece] = trial
			document_changed.emit()
		else: ghost = trial
		snap_matched = false
		queue_redraw()
		return
	if geometry_drag != "":
		var increased: Dictionary = piece.duplicate(true)
		increased[geometry_drag] = float(piece.get(geometry_drag,90.0))+1.0
		var axis: Vector2 = _geometry_handle(increased,geometry_drag)-_geometry_handle(piece,geometry_drag)
		var delta: float = (to_world(point)-pointer_origin).dot(axis)/maxf(0.01,axis.length_squared())
		var trial: Dictionary = piece.duplicate(true)
		trial[geometry_drag] = snappedf(geometry_origin+delta,0.5)
		if not RoadPieces.validate(trial).is_empty(): return
		if not _valid_bridge_edit(trial,selected_piece): return
		if ghost.is_empty() and not changed_in_gesture: edit_started.emit()
		changed_in_gesture = true
		piece[geometry_drag] = trial[geometry_drag]
		snap_matched = false
		if ghost.is_empty(): document_changed.emit()
		queue_redraw()
		return
	var target: Vector2 = (drag_origin+to_world(point)-pointer_origin).snapped(Vector2.ONE*0.5)
	var moved: Dictionary = piece.duplicate(true)
	moved.position = [target.x,target.y]
	if not RoadPieces.validate(moved).is_empty():
		hint_changed.emit("Keep the whole section inside the map.")
		return
	if not _valid_bridge_edit(moved,selected_piece): return
	if ghost.is_empty() and not changed_in_gesture: edit_started.emit()
	changed_in_gesture = true
	if not ghost.is_empty():
		ghost = moved
		_snap_ghost()
	else:
		document.pieces[selected_piece] = moved
		if snap_enabled:
			var result: Dictionary = RoadPieces.snap(moved,document.pieces,selected_piece)
			if RoadPieces.validate(result.piece).is_empty() and _valid_bridge_edit(result.piece,selected_piece):
				document.pieces[selected_piece] = result.piece
		document_changed.emit()
	queue_redraw()

func _draw_piece(piece: Dictionary, is_ghost: bool) -> void:
	var points: PackedVector2Array = RoadPieces.samples(piece)
	var line := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in range(points.size()):
		var direction: Vector2 = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var normal := Vector2(-direction.y,direction.x)*float(piece.width)*0.5
		line.append(to_screen(points[i]))
		left.append(to_screen(points[i]+normal))
		right.append(to_screen(points[i]-normal))
	# Individual triangles also handle a deliberately tight bend whose inner
	# edge folds over itself; a single outline is not a simple polygon there.
	var tint := Color(0.01,0.76,0.85,0.4 if is_ghost else 0.23)
	for i: int in range(left.size()-1):
		draw_primitive(PackedVector2Array([left[i],right[i],left[i+1]]),PackedColorArray([tint]),PackedVector2Array())
		draw_primitive(PackedVector2Array([right[i],right[i+1],left[i+1]]),PackedColorArray([tint]),PackedVector2Array())
	draw_polyline(left,Color("b9faff"),2,true)
	draw_polyline(right,Color("b9faff"),2,true)
	for endpoint: int in [0,points.size()-1]:
		draw_line(left[endpoint],right[endpoint],Color.WHITE,2,true)
		draw_circle(line[endpoint],13,Color("16c2cf"))
		draw_circle(line[endpoint],13,Color.WHITE,false,2,true)
	var label: String = "Join aligned" if is_ghost and snap_matched else ("Tap to place · drag to position" if is_ghost else "Selected section")
	if not is_ghost: label += "  /  %.1f m wide" % float(piece.width)
	var anchor: Vector2 = line[line.size()/2]+Vector2(0,-float(piece.width)*scale_factor()*0.5-24)
	anchor = anchor.clamp(Vector2(110,90),size-Vector2(280,120))
	draw_style_box(MenuStyle.box(Color(0.035,0.09,0.11,0.94),8),Rect2(anchor-Vector2(10,22),Vector2(260,34)))
	draw_string(ThemeDB.fallback_font,anchor,label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	if road_action in ["width","radius","length","angle"]:
		var handle: Vector2 = to_screen(_geometry_handle(piece,road_action))
		draw_circle(handle,16,Color("16c2cf"))
		draw_circle(handle,16,Color.WHITE,false,2,true)
		draw_line(handle-Vector2(7,0),handle+Vector2(7,0),Color.WHITE,2,true)
		draw_line(handle-Vector2(0,7),handle+Vector2(0,7),Color.WHITE,2,true)
		draw_string(ThemeDB.fallback_font,handle+Vector2(22,6),("%s %.0f deg" if road_action == "angle" else "%s %.1f m") % [road_action.capitalize(),float(piece.get(road_action,90.0))],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)

func _geometry_handle(piece: Dictionary, key: String) -> Vector2:
	var points: PackedVector2Array = RoadPieces.samples(piece)
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(piece.heading)))
	if key == "length": return points[0]+forward*float(piece.length)
	if key in ["radius","angle"]: return points[-1]
	var middle: int = points.size()/2
	var direction: Vector2 = (points[mini(middle+1,points.size()-1)]-points[maxi(0,middle-1)]).normalized()
	return points[middle]+Vector2(-direction.y,direction.x)*float(piece.width)*0.5

func cycle_piece() -> void:
	var hits: Array[int] = []
	for i: int in range(document.pieces.size()):
		for p: Vector2 in RoadPieces.samples(document.pieces[i]):
			if to_screen(p).distance_to(press_position) <= maxf(24,float(document.pieces[i].width)*scale_factor()*0.5):
				hits.append(i)
				break
	if hits.is_empty(): return
	selected_piece = hits[(hits.find(selected_piece)+1)%hits.size()]
	ghost.clear()
	mode = "road"
	selection_changed.emit()
	queue_redraw()

func _valid_bridge_edit(piece: Dictionary, index: int) -> bool:
	var pieces: Array = document.pieces.duplicate(true)
	if index >= 0 and ghost.is_empty(): pieces[index] = piece
	else: pieces.append(piece)
	var errors: Array[String] = CreatorBridges.validate(pieces,document.base_track)
	if errors.is_empty(): return true
	hint_changed.emit(errors[0])
	return false


func _paint_position(point: Vector2) -> Array:
	var p: Vector2 = to_world(point).snapped(Vector2.ONE*0.5).clamp(Vector2(-110,-110),Vector2(110,110))
	if document.base_track != "" and native_preview != null: p = p.clamp(-native_preview.half_extent+Vector2.ONE,native_preview.half_extent-Vector2.ONE)
	if native_preview != null and brush_width <= native_preview.cell_size:
		var cell: float = native_preview.cell_size
		var extent: Vector2 = native_preview.half_extent
		p.x = (floorf((p.x+extent.x)/cell)+0.5)*cell-extent.x
		p.y = extent.y-(floorf((extent.y-p.y)/cell)+0.5)*cell
	return [p.x,p.y]

func _object_run(start: Vector2, finish: Vector2) -> Array:
	if not free_run: return RoadPieces.barrier_run(document,start,finish,stamp_kind)
	var result: Array = []
	var count: int = mini(96-document.objects.size(),maxi(1,ceili(start.distance_to(finish)/6.0)))
	var heading: float = fposmod(rad_to_deg((finish-start).angle()),360.0)
	for i: int in range(count):
		var p: Vector2 = start.lerp(finish,(float(i)+0.5)/count)
		result.append({"kind":stamp_kind,"position":[p.x,p.y],"rotation":heading})
	return result

func connect_nearby() -> void:
	if selected_piece < 0 or not ghost.is_empty(): return
	var piece: Dictionary = document.pieces[selected_piece]
	var best: float = RoadPieces.SNAP_DISTANCE
	var result: Dictionary = {}
	for endpoint: int in range(2):
		if not RoadPieces._partner(document.pieces,selected_piece,endpoint).is_empty(): continue
		var origin: Vector2 = RoadPieces._pose(piece,endpoint).position
		var target: Vector2 = RoadPieces.snap_endpoint(origin,document.pieces,selected_piece)
		var distance: float = origin.distance_to(target)
		if distance < 0.001 or distance > best: continue
		var trial: Dictionary = RoadPieces.move_endpoint(piece,endpoint,target)
		if not trial.is_empty() and _valid_bridge_edit(trial,selected_piece):
			best = distance
			result = trial
	if result.is_empty():
		hint_changed.emit("Move an open end within 8 m of another open end, then Connect.")
		return
	edit_started.emit()
	document.pieces[selected_piece] = result
	document_changed.emit()
	edit_finished.emit()
	selection_changed.emit()
	queue_redraw()
