class_name EditorCanvas
extends Control
## One finger drags handles or pans; two fingers pan/zoom. No precision gestures required.

signal edit_started
signal document_changed
signal edit_finished
signal edit_cancelled
signal hint_changed(text: String)
signal selection_changed
signal native_changed(track: NativeTrack)

const PLANNING_PITCH: float = 70.0

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
var road_approval_pending: bool = false
var endpoint_drag: int = -1
var spline_point: int = 2
var spline_point_drag: int = -1
var _spline_preview_cache: Array[Dictionary] = []
var piece_before_drag: Dictionary = {}
var desktop_pan: bool = false
var pending_road_tap: bool = false
var pending_piece_accept: bool = false
var start_drag: bool = false
var pending_start_flip: bool = false
var protect_road: bool = true
var free_run: bool = false
var run_shape: String = "line"
var run_draw: PackedVector2Array = []
var drawing_run: bool = false
var stamp_scale: float = 1.0
var stamp_span: float = 8.0
var stamp_container_color: String = ContainerPaint.DEFAULT
var bump_end_drag: int = -1
var bump_before_drag: Dictionary = {}
var run_start := Vector2.INF
var run_preview: Array = []
var issue_marker := Vector2.INF
var issue_text: String = ""
var brush_surface: int = 2
var brush_width: float = 10.0
var brush_shape: String = "round"
var paint_points: Array = []
var paint_mode: String = "free"
var pending_paint_accept: bool = false
var paint_handle: int = -1
var paint_before_gesture: Array = []
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
var fit_pending_native: bool = false
var native_preview: NativeTrack
var visual_preview: NativeTrack
var _gesture_document: Dictionary = {}
var _gesture_ghost: Dictionary = {}
var _run_edge_hint: bool = false

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
	return size * 0.5 + pan + Vector2(point.x, -point.y*(sin(deg_to_rad(PLANNING_PITCH)) if world_backdrop else 1.0)) * scale_factor()

func to_world(point: Vector2) -> Vector2:
	var local: Vector2 = (point - size * 0.5 - pan) / scale_factor()
	return Vector2(local.x, -local.y/(sin(deg_to_rad(PLANNING_PITCH)) if world_backdrop else 1.0))

func fit() -> void:
	if size.x < 10 or size.y < 10: return
	fit_pending_native = native_preview == null and document.get("base_track","") != ""
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
		pan += size*0.5-to_screen(bounds.get_center())
	queue_redraw()

func zoom_by(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	fit_pending_native = false
	if anchor == Vector2.INF: anchor = size*0.5
	var before: Vector2 = to_world(anchor)
	zoom = clampf(zoom * factor, 0.25, 16.0)
	pan += anchor-to_screen(before)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func show_native(track: NativeTrack) -> void:
	native_preview = track
	if fit_pending_native:
		fit_pending_native = false
		fit()
	# The 3D editor never draws this legacy CPU-rasterized map texture.
	if not world_backdrop: preview.show_track(track)
	native_changed.emit(track)
	queue_redraw()

func cancel_gesture() -> void:
	pending_paint_accept = false
	run_draw.clear()
	drawing_run=false
	run_preview.clear()
	run_start=Vector2.INF
	if dragging and changed_in_gesture: edit_finished.emit()
	paint_points.clear()
	pending_stamp = false
	dragging = false
	panning = false
	active_pointer = -99
	touches.clear()
	desktop_pan = false
	pending_road_tap = false
	pending_piece_accept = false
	start_drag = false
	pending_start_flip = false
	bump_end_drag = -1

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
				var draft: Array = paint_points.duplicate(true)
				cancel_gesture()
				if paint_mode != "free": paint_points = draft
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
				_rollback_navigation_edit()
				pending_road_tap = false
				pending_piece_accept = false
				pending_start_flip = false
				start_drag = false
				pending_paint_accept = false
				paint_handle = -1
				drawing_run=false
				run_draw.clear()
				run_preview.clear()
				if paint_mode == "free": paint_points.clear()
				elif mode == "paint": paint_points = paint_before_gesture.duplicate(true)
				pending_stamp = false
				dragging = false
		else:
			var was_pinching: bool = touches.size() >= 2
			touches.erase(event.index)
			if event.canceled:
				pending_paint_accept = false
				paint_handle = -1
				drawing_run=false
				run_draw.clear()
				run_preview.clear()
				pending_road_tap = false
				pending_piece_accept = false
				pending_start_flip = false
				start_drag = false
				pending_stamp = false
				if paint_mode == "free": paint_points.clear()
				elif mode == "paint": paint_points = paint_before_gesture.duplicate(true)
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

func _rollback_navigation_edit() -> void:
	bump_end_drag = -1
	if not changed_in_gesture: return
	if not _gesture_document.is_empty() and document != _gesture_document:
		document.clear()
		document.merge(_gesture_document.duplicate(true),true)
		document_changed.emit()
		edit_cancelled.emit()
	ghost = _gesture_ghost.duplicate(true)
	changed_in_gesture = false
	selection_changed.emit()

func _begin(point: Vector2, pointer: int) -> void:
	fit_pending_native = false
	active_pointer = pointer
	previous_pointer = point
	press_position = point
	pointer_origin = to_world(point)
	changed_in_gesture = false
	_gesture_document = document.duplicate(true)
	_gesture_ghost = ghost.duplicate(true)
	_run_edge_hint = false
	bump_end_drag = -1
	if mode == "objects" and selected_object >= 0 and selected_object < document.objects.size() and document.objects[selected_object].kind == "speed_bump":
		var ends: PackedVector2Array = SpeedBumpEdit.endpoints(document.objects[selected_object])
		var nearest: float = 24.0
		for end: int in range(2):
			var distance: float = to_screen(ends[end]).distance_to(point)
			if distance < nearest: nearest = distance; bump_end_drag = end
		if bump_end_drag >= 0:
			bump_before_drag = document.objects[selected_object].duplicate(true)
			dragging = true
			return
	if mode=="place":
		for object: Dictionary in document.objects:
			if CreatorObjects.contains(object,to_world(point)):
				mode="objects"
				break
	start_drag = false
	pending_start_flip = false
	if mode == "road" and ghost.is_empty() and document.has("start_line") and not editing_spline():
		var controls: Dictionary = start_controls()
		if Vector2(controls.flip).distance_to(point) <= 28:
			pending_start_flip = true
			return
		if Geometry2D.get_closest_point_to_segment(point,controls.left,controls.right).distance_to(point) <= 18:
			start_drag = true
			dragging = true
			selected_piece = -1
			return
	if mode == "road":
		_begin_road(point)
		return
	if mode in ["run","start","start_line"]:
		run_draw=PackedVector2Array([to_world(point)])
		drawing_run=false
		pending_stamp = true
		return
	if mode == "paint":
		if paint_mode != "free":
			paint_before_gesture = paint_points.duplicate(true)
			if paint_accept_rect().has_point(point):
				pending_paint_accept = true
				return
			paint_handle = -1
			for i: int in range(paint_points.size()):
				if to_screen(Vector2(paint_points[i][0],paint_points[i][1])).distance_to(point) <= 24:
					paint_handle = i
					break
			if paint_handle < 0 and paint_points.size() < 64:
				paint_points.append(_paint_position(point))
				paint_handle = paint_points.size()-1
			queue_redraw()
			return
		paint_points = [_paint_position(point)]
		queue_redraw()
		return
	if mode in ["pan","waypoints","move","add"]:
		panning = true
		return
	pending_stamp = mode == "place"
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
	selection_changed.emit()
	if selected_object >= 0:
		var value: Array = document.objects[selected_object].position
		drag_origin = Vector2(value[0],value[1])
		dragging = true
	else: panning = true
	queue_redraw()

func _move(point: Vector2) -> void:
	if bump_end_drag >= 0:
		if press_position.distance_to(point) < 3.0 and not changed_in_gesture: return
		var changed: Dictionary = SpeedBumpEdit.move_end(bump_before_drag,bump_end_drag,to_world(point))
		if changed == document.objects[selected_object]: return
		if not changed_in_gesture: edit_started.emit(); changed_in_gesture = true
		document.objects[selected_object] = changed
		document_changed.emit()
		queue_redraw()
		return
	if pending_paint_accept:
		if press_position.distance_to(point) > 12:
			pending_paint_accept = false
			panning = true
		else: return
	if pending_start_flip:
		if press_position.distance_to(point) > 8: pending_start_flip = false
		return
	if start_drag:
		if press_position.distance_to(point) < 3 and not changed_in_gesture: return
		var pose: Dictionary = CreatorStartLine.place(document,to_world(point),native_preview)
		if pose.is_empty(): return
		if not changed_in_gesture: edit_started.emit()
		changed_in_gesture = true
		document["start_line"] = pose
		document_changed.emit()
		queue_redraw()
		return
	if desktop_pan:
		pan += point-previous_pointer
		previous_pointer = point
		queue_redraw()
		return
	if pending_road_tap and press_position.distance_to(point) > 8:
		pending_road_tap = false
		pending_piece_accept = false
		panning = true
	if mode == "road" and dragging:
		_move_road(point)
		previous_pointer = point
		return
	if mode == "run" and (drawing_run or press_position.distance_to(point)>12):
		drawing_run=true
		pending_stamp=false
		var target: Vector2 = to_world(point).clamp(Vector2(-110,-110),Vector2(110,110))
		if run_shape=="curve":
			if run_draw[-1].distance_to(target)>0.3 and run_draw.size()<512: run_draw.append(target)
			run_preview=_path_run(run_draw)
		else:
			run_preview=_object_run(to_world(press_position) if run_start==Vector2.INF else run_start,target)
		queue_redraw()
		return
	if mode == "paint" and paint_mode != "free" and paint_handle >= 0:
		paint_points[paint_handle] = _paint_position(point)
		queue_redraw()
		return
	if mode == "paint" and not paint_points.is_empty() and paint_mode == "free":
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
			if selected_object >= 0: document.objects[selected_object].position = [position.x,position.y]
			document_changed.emit()
	elif panning: pan += point-previous_pointer
	previous_pointer = point
	queue_redraw()

func _place(point: Vector2) -> void:
	var position: Vector2 = to_world(point).snapped(Vector2.ONE).clamp(Vector2(-110,-110),Vector2(110,110))
	if mode == "start_line":
		var pose: Dictionary = CreatorStartLine.place(document,to_world(point),native_preview)
		if pose.is_empty():
			hint_changed.emit("Place the start line on a road.")
			return
		edit_started.emit()
		document["start_line"] = pose
		mode = "road"
		document_changed.emit()
		edit_finished.emit()
		selection_changed.emit()
		queue_redraw()
		return
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
		mode = "road"
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
		var object: Dictionary = {"kind":stamp_kind,"position":[position.x,position.y],"rotation":stamp_rotation}
		if stamp_scale != 1.0: object["scale"]=stamp_scale
		if stamp_kind == "speed_bump": object["span"] = stamp_span
		if stamp_kind == "container": object["color"] = stamp_container_color
		document.objects.append(object)
		selected_object = document.objects.size()-1
		selected = -1
	else: return
	document_changed.emit()
	edit_finished.emit()
	selection_changed.emit()
	queue_redraw()

func _end(pointer: int) -> void:
	if pointer != active_pointer: return
	if pending_paint_accept:
		pending_paint_accept = false
		confirm_paint()
	if pending_start_flip:
		pending_start_flip = false
		flip_start_line()
	start_drag = false
	if pending_piece_accept:
		pending_piece_accept = false
		dragging = false
		confirm_piece()
	if drawing_run:
		if not run_preview.is_empty():
			edit_started.emit()
			document.objects.append_array(run_preview)
			document_changed.emit()
			edit_finished.emit()
			hint_changed.emit("%d objects placed / Undo removes the whole run" % run_preview.size())
		drawing_run=false
		run_draw.clear()
		run_preview.clear()
		run_start=Vector2.INF
	if pending_road_tap and not ghost.is_empty():
		var target: Vector2 = to_world(press_position)
		var trial: Dictionary = ghost.duplicate(true)
		trial.position = [target.x,target.y]
		if RoadPieces.validate(trial).is_empty():
			ghost = trial
			_snap_ghost()
		selection_changed.emit()
	pending_road_tap = false
	pending_piece_accept = false
	if paint_mode == "free": confirm_paint()
	paint_handle = -1
	if pending_stamp: _place(press_position)
	if dragging and changed_in_gesture:
		edit_finished.emit()
		if geometry_drag != "" or spline_point_drag >= 0 or bump_end_drag >= 0: selection_changed.emit()
	bump_end_drag = -1
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
	if mode=="road":
		for x: float in range(ceili(size.x / spacing) + 1):
			var xx: float = fposmod(origin.x, spacing) + x * spacing
			draw_line(Vector2(xx,0),Vector2(xx,size.y),Color(1,1,1,0.035))
		for y: float in range(ceili(size.y / spacing) + 1):
			var yy: float = fposmod(origin.y, spacing) + y * spacing
			draw_line(Vector2(0,yy),Vector2(size.x,yy),Color(1,1,1,0.035))
	var sampled: Dictionary = TrackDocument.route_data(document)
	var route: PackedVector2Array = sampled.points
	if native_preview == null and not world_backdrop:
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
	if mode == "waypoints":
		var line := PackedVector2Array()
		for p: Vector2 in route: line.append(to_screen(p))
		line.append(line[0])
		draw_polyline(line,Color(1,0.85,0.35,0.9),2,true)
	if route.size() > 1 and mode == "waypoints":
		var start: Vector2 = to_screen(route[0])
		var across: Vector2 = Vector2((route[1]-route[0]).y,(route[1]-route[0]).x).normalized() * TrackDocument.node_width(document,0) * scale_factor() * 0.5
		draw_line(start-across,start+across,Color("e0e7dd"),3,true)
		var direction: Vector2 = (to_screen(route[1])-start).normalized()
		var arrow: Vector2 = start + direction * 24
		draw_line(arrow-direction.rotated(0.65)*12,arrow,Color("edf1f3"),3,true)
		draw_line(arrow-direction.rotated(-0.65)*12,arrow,Color("edf1f3"),3,true)
	for i: int in range(document.points.size() if mode == "waypoints" else 0):
		var p: Array = document.points[i]
		var center: Vector2 = to_screen(Vector2(p[0],p[1]))
		draw_circle(center,4,Color("f3c644"))
		if i == 0:
			draw_string(ThemeDB.fallback_font,center+Vector2(-23,-18),"START",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	for piece: Dictionary in pending_road_pieces(): _draw_piece(piece,false,false)
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
		if not world_backdrop: draw_string(ThemeDB.fallback_font,center+Vector2(-5,5),object.kind.left(1).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("edf1f3"))
		if i == selected_object and mode == "objects" and object.kind == "speed_bump":
			for end: Vector2 in SpeedBumpEdit.endpoints(object):
				var at: Vector2 = to_screen(end)
				draw_circle(at,11,Color("182533"))
				draw_circle(at,8,Color("f3c644"))
	if not paint_points.is_empty():
		var color: Color = palette[brush_surface]
		color.a = 0.7
		var path: PackedVector2Array = SurfacePaint.contour(paint_points,paint_mode)
		var screen_path := PackedVector2Array()
		for p: Vector2 in path: screen_path.append(to_screen(p))
		if paint_mode == "area" and screen_path.size() >= 3:
			if not Geometry2D.triangulate_polygon(screen_path).is_empty(): draw_colored_polygon(screen_path,color)
			screen_path.append(screen_path[0])
		if screen_path.size() > 1: draw_polyline(screen_path,color,2.0 if paint_mode == "area" else brush_width*scale_factor(),true)
		if paint_mode != "area":
			for p: Vector2 in screen_path: draw_circle(p,brush_width*scale_factor()*0.5,color)
		if paint_mode != "free":
			for p: Array in paint_points:
				var at: Vector2 = to_screen(Vector2(p[0],p[1]))
				draw_circle(at,10,Color("f5c842"))
				draw_circle(at,5,Color("182533"))
		var accept: Rect2 = paint_accept_rect()
		if accept.has_area():
			draw_style_box(MenuStyle.box(Color("f3c644"),14),accept)
			var center: Vector2 = accept.get_center()
			draw_polyline(PackedVector2Array([center+Vector2(-12,0),center+Vector2(-3,9),center+Vector2(14,-10)]),Color("142331"),4,true)
	if mode == "road":
		for i: int in range(document.get("pieces",[]).size()):
			if i == selected_piece: _draw_piece(document.pieces[i],false)
		if not ghost.is_empty(): _draw_piece(ghost,true)
		for join: Dictionary in RoadPieces.joins(document.get("pieces",[])):
			draw_circle(to_screen(join.position),5,Color("e2efec"),false,2,true)
	if document.has("practice_start") and mode in ["waypoints","move","add","start"]:
		var start: Vector2 = to_screen(Vector2(document.practice_start.position[0],document.practice_start.position[1]))
		draw_circle(start,14,Color("16c2cf"),false,3,true)
		draw_string(ThemeDB.fallback_font,start+Vector2(20,5),"Practice start",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	if document.has("start_line") and mode in ["road","start_line"] and not editing_spline(): _draw_start_line()
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
		ghost = RoadPieces.create(kind,end.position,end.heading,RoadPieces.endpoint_width(document.pieces[-1],1))
	spline_point = 2
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
		road_approval_pending = true
		edit_finished.emit()
		road_approval_pending = false
	selection_changed.emit()
	queue_redraw()

func _begin_road(point: Vector2) -> void:
	geometry_drag = ""
	endpoint_drag = -1
	spline_point_drag = -1
	pending_road_tap = false
	pending_piece_accept = false
	var current: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece] if selected_piece >= 0 else {}
	if not current.is_empty() and current.kind == "spline" and _begin_spline(current,point): return
	if not current.is_empty():
		for key: String in geometry_keys(current):
			if to_screen(_geometry_handle(current,key)).distance_to(point) <= 24:
				geometry_drag = key
				geometry_origin = RoadPieces.height(current) if key == "height" else float(current.get(key,0.0 if key == "curvature" else 90.0))
				piece_before_drag = current.duplicate(true)
				dragging = true
				queue_redraw()
				return
		for end: int in range(0 if current.kind == "spline" else 2):
			var handle: Vector2 = Vector2(current.position[0],current.position[1]) if end == 0 else RoadPieces.end_pose(current).position
			if to_screen(handle).distance_to(point) <= 26:
				endpoint_drag = end
				piece_before_drag = current.duplicate(true)
				dragging = true
				return
	if not current.is_empty() and piece_accept_rect(current).has_point(point):
		pending_piece_accept = true
		drag_origin = Vector2(current.position[0],current.position[1])
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
			if piece.kind == "spline" and _begin_spline(piece,point): return
			piece_before_drag = piece.duplicate(true)
			for end: int in range(0 if piece.kind == "spline" else 2):
				var handle: Vector2 = Vector2(piece.position[0],piece.position[1]) if end == 0 else RoadPieces.end_pose(piece).position
				if to_screen(handle).distance_to(point) <= 26: endpoint_drag = end
			drag_origin = Vector2(piece.position[0],piece.position[1])
			dragging = true
		else: panning = true
	selection_changed.emit()
	queue_redraw()

func _attached_end(piece: Dictionary) -> int:
	return RoadPieces.attached_end(piece,document.pieces,selected_piece if ghost.is_empty() else -1)

func editing_spline() -> bool:
	if mode != "road": return false
	var piece: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece] if selected_piece >= 0 else {}
	return piece.get("kind","") == "spline"

func spline_width_handle(piece: Dictionary) -> Vector2:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	var normal: Vector2 = SplineRoad.tangent(nodes,spline_point).normalized().orthogonal()
	var reach: float = maxf(float(piece.point_widths[spline_point])*0.5+2.0,48.0/scale_factor())
	return to_screen(nodes[spline_point]+normal*reach)

func _begin_spline(piece: Dictionary, point: Vector2) -> bool:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	var closest: int = -1
	var distance: float = 26.0
	for i: int in range(nodes.size()):
		var candidate: float = to_screen(nodes[i]).distance_to(point)
		if candidate < distance: closest = i; distance = candidate
	if closest >= 0:
		spline_point = closest
		spline_point_drag = closest
	elif spline_width_handle(piece).distance_to(point) <= 24:
		geometry_drag = "point_width"
		geometry_origin = float(piece.point_widths[spline_point])
	else: return false
	piece_before_drag = piece.duplicate(true)
	dragging = true
	selection_changed.emit()
	queue_redraw()
	return true

func _move_spline(point: Vector2) -> void:
	var trial: Dictionary
	var nodes: PackedVector2Array = SplineRoad.points(piece_before_drag)
	if spline_point_drag >= 0:
		var target: Vector2 = nodes[spline_point_drag]+to_world(point)-pointer_origin
		if snap_enabled and spline_point_drag in [0,4]: target = RoadPieces.snap_endpoint(target,document.pieces,selected_piece if ghost.is_empty() else -1)
		trial = SplineRoad.move_point(piece_before_drag,spline_point_drag,target)
	else:
		var normal: Vector2 = SplineRoad.tangent(nodes,spline_point).normalized().orthogonal()
		var delta: float = (to_world(point)-pointer_origin).dot(normal)*2.0
		trial = SplineRoad.with_width(piece_before_drag,spline_point,snappedf(geometry_origin+delta,0.5))
	if trial.is_empty() or not RoadPieces.validate(trial).is_empty():
		hint_changed.emit("Keep spline points inside the map and at least 2 m apart.")
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

func _draw_spline_controls(piece: Dictionary) -> void:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	for i: int in range(nodes.size()):
		var at: Vector2 = to_screen(nodes[i])
		draw_circle(at,15,Color("ffdd80") if i == spline_point else Color("f2f6f7"))
		draw_circle(at,15,Color("163541"),false,2,true)
		draw_string(ThemeDB.fallback_font,at+Vector2(-5,6),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("163541"))
	var handle: Vector2 = spline_width_handle(piece)
	var normal: Vector2 = SplineRoad.tangent(nodes,spline_point).normalized().orthogonal()
	draw_line(to_screen(nodes[spline_point]),handle,Color("b9faff"),1.5,true)
	_draw_geometry_glyph(handle,"width",(to_screen(nodes[spline_point]+normal)-to_screen(nodes[spline_point])).normalized(),geometry_drag == "point_width" and dragging)

func anchored_change(before: Dictionary, changed: Dictionary, key: String) -> Dictionary:
	return RoadPieces.keep_attachment(before,changed,_attached_end(before),key != "heading")

func _move_road(point: Vector2) -> void:
	var piece: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece]
	if pending_piece_accept:
		if press_position.distance_to(point) <= 8: return
		pending_piece_accept = false
	if press_position.distance_to(point) < 3 and not changed_in_gesture: return
	if piece.kind == "spline" and (spline_point_drag >= 0 or geometry_drag == "point_width"):
		_move_spline(point)
		return
	if endpoint_drag >= 0:
		var target: Vector2 = to_world(point)
		var moving_end: int = endpoint_drag
		var attached: int = _attached_end(piece_before_drag)
		if moving_end == attached:
			moving_end = 1-attached
			target = Vector2(RoadPieces._pose(piece_before_drag,moving_end).position)+to_world(point)-pointer_origin
		if snap_enabled: target = RoadPieces.snap_endpoint(target,document.pieces,selected_piece if ghost.is_empty() else -1)
		var trial: Dictionary = RoadPieces.move_endpoint(piece_before_drag,moving_end,target)
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
		var increased: Dictionary = piece_before_drag.duplicate(true)
		increased[geometry_drag] = geometry_origin+1.0
		if piece.kind == "s_bend" and geometry_drag == "radius": increased.height = RoadPieces.height(piece_before_drag)
		increased = anchored_change(piece_before_drag,increased,geometry_drag)
		var axis: Vector2 = _geometry_anchor(increased,geometry_drag)-_geometry_anchor(piece_before_drag,geometry_drag)
		var delta: float = (to_world(point)-pointer_origin).dot(axis)/maxf(0.01,axis.length_squared())
		if piece.kind == "curve" and geometry_drag == "angle":
			var side: float = -1.0 if piece.flip else 1.0
			var center: Vector2 = Vector2(piece_before_drag.position[0],piece_before_drag.position[1])+Vector2(0,side*float(piece_before_drag.radius)).rotated(deg_to_rad(float(piece_before_drag.heading)))
			var anchor: Vector2 = _geometry_anchor(piece_before_drag,"angle")
			delta = rad_to_deg((anchor-center).angle_to(anchor+to_world(point)-pointer_origin-center))/( -0.8 if _attached_end(piece_before_drag) == 1 else 0.8)*side
		var trial: Dictionary = piece_before_drag.duplicate(true)
		trial[geometry_drag] = snappedf(geometry_origin+delta,0.01 if geometry_drag == "curvature" else 0.5)
		if geometry_drag == "curvature": trial.curvature = clampf(float(trial.curvature),-0.3,0.3)
		elif geometry_drag == "heading": trial.heading = fposmod(float(trial.heading),360.0)
		else:
			var lower: float = 6.0 if geometry_drag == "width" else 3.0 if geometry_drag == "radius" else 2.0 if geometry_drag == "height" else 5.0 if geometry_drag == "angle" else 24.0 if piece.kind == "bridge" else 2.0 if piece.kind == "straight" else 0.0
			var upper: float = 20.0 if geometry_drag == "width" else 60.0 if geometry_drag in ["radius","height"] else 270.0 if geometry_drag == "angle" else 120.0
			trial[geometry_drag] = clampf(float(trial[geometry_drag]),lower,upper)
		if piece.kind == "s_bend" and geometry_drag == "radius": trial.height = RoadPieces.height(piece_before_drag)
		trial = anchored_change(piece_before_drag,trial,geometry_drag)
		if not RoadPieces.validate(trial).is_empty(): return
		if not _valid_bridge_edit(trial,selected_piece): return
		if ghost.is_empty() and not changed_in_gesture: edit_started.emit()
		changed_in_gesture = true
		if ghost.is_empty(): document.pieces[selected_piece] = trial
		else: ghost = trial
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

func pending_road_pieces() -> Array:
	var pending: Array = []
	if not world_backdrop: return pending
	if native_preview == null: return document.pieces
	var displayed: NativeTrack = visual_preview if visual_preview != null else native_preview
	var compiled: Array = displayed.metadata.get("creator_document",{}).get("pieces",[])
	for index: int in range(document.pieces.size()):
		if index >= compiled.size() or document.pieces[index] != compiled[index]: pending.append(document.pieces[index])
	return pending

func _spline_preview(piece: Dictionary) -> Dictionary:
	for entry: Dictionary in _spline_preview_cache:
		if entry.piece == piece: return entry
	var contours: Array[PackedVector2Array] = RoadEdges.section_contours([piece],0)
	var entry: Dictionary = {"piece":piece.duplicate(true),"contours":contours,"surface":SplineBorders.surface(contours)}
	if _spline_preview_cache.size() >= 4: _spline_preview_cache.pop_front()
	_spline_preview_cache.append(entry)
	return entry

func _draw_piece(piece: Dictionary, is_ghost: bool, controls: bool = true) -> void:
	var geometry: Dictionary = RoadPieces.section_geometry([piece],0)
	var points: PackedVector2Array = geometry.points
	var widths: PackedFloat32Array = geometry.widths
	var line := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in range(points.size()):
		var direction: Vector2 = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		if piece.kind == "taper": direction = Vector2.RIGHT.rotated(deg_to_rad(float(piece.heading)))
		var normal := Vector2(-direction.y,direction.x)*widths[i]*0.5
		line.append(to_screen(points[i]))
		left.append(to_screen(points[i]+normal))
		right.append(to_screen(points[i]-normal))
	# Individual triangles also handle a deliberately tight bend whose inner
	# edge folds over itself; a single outline is not a simple polygon there.
	var tint: Color = Color(0.01,0.76,0.85,0.4 if is_ghost else 0.23) if controls else Color("61533e") if document.surface == "dirt" else Color("45494c")
	if piece.kind == "spline":
		var border: Dictionary = _spline_preview(piece)
		for patch: PackedVector2Array in border.surface:
			var screen_patch := PackedVector2Array()
			for vertex: Vector2 in patch: screen_patch.append(to_screen(vertex))
			if not Geometry2D.triangulate_polygon(screen_patch).is_empty(): draw_colored_polygon(screen_patch,tint)
		for contour: PackedVector2Array in border.contours:
			var screen_contour := PackedVector2Array()
			for vertex: Vector2 in contour: screen_contour.append(to_screen(vertex))
			screen_contour.append(screen_contour[0])
			draw_polyline(screen_contour,Color("b9faff") if controls else Color("dce1dc"),2,true)
	else:
		for i: int in range(left.size()-1):
			draw_primitive(PackedVector2Array([left[i],right[i],left[i+1]]),PackedColorArray([tint]),PackedVector2Array())
			draw_primitive(PackedVector2Array([right[i],right[i+1],left[i+1]]),PackedColorArray([tint]),PackedVector2Array())
		draw_polyline(left,Color("b9faff") if controls else Color("dce1dc"),2,true)
		draw_polyline(right,Color("b9faff") if controls else Color("dce1dc"),2,true)
	if not controls: return
	if dragging and geometry_drag != "":
		if geometry_drag == "width":
			draw_polyline(left,Color("76ddeb"),4,true)
			draw_polyline(right,Color("76ddeb"),4,true)
		else:
			draw_polyline(line,Color("f6bf69"),3,true)

	for endpoint: int in ([] if piece.kind == "spline" else [0,points.size()-1]):
		draw_line(left[endpoint],right[endpoint],Color.WHITE,2,true)
		draw_circle(line[endpoint],13,Color("f2f6f7"))
		draw_circle(line[endpoint],13,Color("163541"),false,2,true)
		if _attached_end(piece) == (0 if endpoint == 0 else 1):
			draw_rect(Rect2(line[endpoint]-Vector2(5,1),Vector2(10,8)),Color("163541"),false,2)
			draw_arc(line[endpoint]+Vector2(0,-1),4,PI,TAU,10,Color("163541"),2,true)
		else:
			for axis: Vector2 in [Vector2.RIGHT,Vector2.DOWN]:
				_draw_handle_arrow(line[endpoint],axis,7,Color("163541"))
	if piece.kind == "spline": _draw_spline_controls(piece)
	for key: String in geometry_keys(piece):
		var handle: Vector2 = to_screen(_geometry_handle(piece,key))
		if piece.kind == "bridge": draw_line(to_screen(_geometry_anchor(piece,key)),handle,Color("b9faff"),1.5,true)
		var increased: Dictionary = piece.duplicate(true)
		increased[key] = (RoadPieces.height(piece) if key == "height" else float(piece.get(key,0.0 if key == "curvature" else 90.0)))+1.0
		if piece.kind == "s_bend" and key == "radius": increased.height = RoadPieces.height(piece)
		increased = anchored_change(piece,increased,key)
		var axis: Vector2 = (to_screen(_geometry_anchor(increased,key))-to_screen(_geometry_anchor(piece,key))).normalized()
		_draw_geometry_glyph(handle,"span" if key == "radius" and piece.kind == "s_bend" else key,axis,geometry_drag == key and dragging)
		if piece.kind != "bridge": continue
		var caption: String = geometry_caption(piece,key)
		var label_size := Vector2(ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+12,24)
		var label_pos: Vector2 = handle+Vector2(-label_size.x*0.5,24)
		draw_style_box(MenuStyle.box(Color("142331"),5),Rect2(label_pos,label_size))
		draw_string(ThemeDB.fallback_font,label_pos+Vector2(6,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)


	var accept_rect: Rect2 = piece_accept_rect(piece)
	draw_style_box(MenuStyle.box(Color("f3c644"),14),accept_rect)
	var c: Vector2 = accept_rect.get_center()
	draw_polyline(PackedVector2Array([c+Vector2(-12,0),c+Vector2(-3,9),c+Vector2(14,-10)]),Color("142331"),4,true)

func _draw_geometry_glyph(center: Vector2, key: String, axis: Vector2, active: bool) -> void:
	var ink := Color("142331")
	var fill := Color("76ddeb") if key == "width" else Color("f6bf69")
	if active:
		draw_circle(center,23,Color(1,0.85,0.4,0.25))
		fill = Color("ffdd80")
		_draw_handle_arrow(center,axis,34,Color("fff5cd"))
	if key == "width":
		draw_style_box(MenuStyle.box(fill,6),Rect2(center-Vector2(17,17),Vector2(34,34)))
		var normal := axis.orthogonal()
		for sign_value: float in [-1.0,1.0]:
			var edge: Vector2 = center+axis*11*sign_value
			draw_line(edge-normal*9,edge+normal*9,ink,2,true)
		_draw_handle_arrow(center,axis,7,ink)
	else:
		draw_circle(center,17,fill)
		if key in ["angle","heading"]:
			draw_arc(center,10,-PI*0.8,PI*0.15,16,ink,2,true)
			var tip: Vector2 = center+Vector2.from_angle(PI*0.15)*10
			draw_polyline(PackedVector2Array([tip+Vector2(-5,-1),tip,tip+Vector2(1,-5)]),ink,2,true)
			if key == "angle":
				draw_line(center,center+Vector2(0,-7),ink,2,true)
				draw_line(center,center+Vector2(7,0),ink,2,true)
		elif key in ["curvature","radius"]:
			var normal := axis.orthogonal()
			var curve := PackedVector2Array()
			for i: int in range(17):
				var t: float = float(i)/16.0
				curve.append(center+normal*lerpf(-11,11,t)+axis*(sin(PI*t)*7-5))
			draw_polyline(curve,ink,2.5,true)
			_draw_handle_arrow(center+axis*6,axis,5,ink)
		elif key in ["height","span"]:
			var wave := PackedVector2Array()
			for i: int in range(17):
				var t: float = float(i)/16.0
				var point := Vector2(-5+sin(t*TAU)*4,lerpf(-10,10,t))
				wave.append(center+(point if key == "height" else Vector2(point.y,point.x)))
			draw_polyline(wave,ink,2,true)
			_draw_handle_arrow(center+(Vector2(7,0) if key == "height" else Vector2(0,7)),Vector2.UP if key == "height" else Vector2.RIGHT,9,ink)
		else: # Straight-arm length: parallel arms with extension arrows.
			var normal := axis.orthogonal()
			for side: float in [-1.0,1.0]:
				draw_line(center-axis*10+normal*7*side,center+axis*10+normal*7*side,ink,2,true)
			_draw_handle_arrow(center,axis,8,ink)

func _draw_handle_arrow(center: Vector2, axis: Vector2, reach: float, color: Color) -> void:
	var normal := axis.orthogonal()
	draw_line(center-axis*reach,center+axis*reach,color,2,true)
	for side: float in [-1.0,1.0]:
		var tip: Vector2 = center+axis*reach*side
		draw_polyline(PackedVector2Array([tip-axis*3*side+normal*3,tip,tip-axis*3*side-normal*3]),color,2,true)

func piece_accept_rect(piece: Dictionary) -> Rect2:
	var points: PackedVector2Array = RoadPieces.samples(piece)
	if piece.kind == "spline":
		var nodes: PackedVector2Array = SplineRoad.points(piece)
		var tangent: Vector2 = SplineRoad.tangent(nodes,2).normalized()
		return Rect2(to_screen(nodes[2]-tangent.orthogonal()*(float(piece.width)*0.5+6.0))-Vector2(28,28),Vector2(56,56))
	return Rect2(to_screen(points[points.size()/4 if piece.kind != "bridge" else points.size()/2])-Vector2(28,28),Vector2(56,56))

func geometry_keys(piece: Dictionary) -> Array[String]:
	if piece.kind == "spline": return []
	if piece.kind == "straight": return ["width"]
	if piece.kind == "taper": return ["width","narrow_width","length"]
	if piece.kind == "curve": return ["width","curvature","angle"]
	if piece.kind == "s_bend": return ["width","radius","height"]
	if piece.kind == "hairpin": return ["width","radius","length"]
	var keys: Array[String] = ["width"]
	if piece.kind != "s_bend": keys.push_front("length")
	if piece.kind not in ["straight","bridge"]: keys.append("radius")
	if piece.kind == "s_bend": keys.append("height")
	if piece.kind == "curve": keys.append("angle")
	keys.append("heading")
	return keys

func geometry_caption(piece: Dictionary, key: String) -> String:
	var title: String = "Rotate" if key == "heading" else "Narrow width" if key == "narrow_width" else "Straight" if key == "length" and piece.kind not in ["straight","taper","bridge"] else key.capitalize()
	var value: float = RoadPieces.height(piece) if key == "height" else float(piece.get(key,0.0 if key == "curvature" else 90.0))
	return ("%s %.0f deg" if key in ["angle","heading"] else "%s %.1f m") % [title,value]

func _geometry_handle(piece: Dictionary, key: String) -> Vector2:
	return to_world(geometry_controls(piece)[key])

func geometry_controls(piece: Dictionary) -> Dictionary:
	var controls: Dictionary = {}
	if piece.kind != "bridge":
		var occupied: Array[Vector2] = [to_screen(Vector2(piece.position[0],piece.position[1])),to_screen(RoadPieces.end_pose(piece).position)]
		for key: String in geometry_keys(piece):
			var anchor: Vector2 = to_screen(_geometry_anchor(piece,key))
			var candidate: Vector2 = anchor
			if key != "width":
				for step: int in range(97):
					candidate = anchor+Vector2.LEFT.rotated(float(step%8)*TAU/8.0)*float((step+7)/8)*12.0
					var clear: bool = not piece_accept_rect(piece).grow(20).has_point(candidate)
					for other: Vector2 in occupied:
						if candidate.distance_to(other) < 48: clear = false; break
					if clear: break
			controls[key] = candidate
			occupied.append(candidate)
		return controls
	var blocked: Array[Rect2] = [piece_accept_rect(piece).grow(20)]
	for endpoint: Vector2 in [Vector2(piece.position[0],piece.position[1]),Vector2(RoadPieces.end_pose(piece).position)]:
		blocked.append(Rect2(to_screen(endpoint)-Vector2(40,40),Vector2(80,80)))
	for key: String in geometry_keys(piece):
		var anchor: Vector2 = to_screen(_geometry_anchor(piece,key))
		var candidate: Vector2 = anchor
		for step: int in range(81):
			var ring: int = (step+7)/8
			var offset: Vector2 = Vector2.UP.rotated(float(step%8)*TAU/8.0)*float(ring)*64.0
			candidate = anchor+offset
			var area := Rect2(candidate-Vector2(70,26),Vector2(140,78))
			var overlaps: bool = false
			for rect: Rect2 in blocked:
				if rect.intersects(area): overlaps = true; break
			if not overlaps: break
		controls[key] = candidate
		blocked.append(Rect2(candidate-Vector2(70,26),Vector2(140,78)))
	return controls

func _geometry_anchor(piece: Dictionary, key: String) -> Vector2:
	var points: PackedVector2Array = RoadPieces.samples(piece)
	var forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(piece.heading)))
	if piece.kind == "curve" and key in ["width","angle","curvature"]:
		var side: float = -1.0 if piece.flip else 1.0
		var fraction: float = (0.2 if _attached_end(piece) == 1 else 0.8) if key == "angle" else 0.5
		var turn: float = deg_to_rad(float(piece.get("angle",90.0)))*fraction
		var radius: float = float(piece.radius)
		var bulge: float = float(piece.get("curvature",0.0))*RoadPieces.curve_bulge_scale(piece)*pow(sin(PI*fraction),2)
		var reach: float = radius+bulge+float(piece.width)*0.5 if key == "width" else maxf(1.0,radius+bulge-float(piece.width)*0.5-2.0)
		return points[0]+Vector2(reach*sin(turn),side*(radius-reach*cos(turn))).rotated(deg_to_rad(float(piece.heading)))
	if piece.kind == "hairpin":
		var side: float = -1.0 if piece.flip else 1.0
		var radius: float = float(piece.radius)
		var half: float = float(piece.width)*0.5
		var reach: float = radius+half if key == "width" else maxf(1.0,radius-half-2.0)
		var turn: float = PI*0.25 if key == "radius" else PI*0.5
		return points[0]+Vector2(float(piece.length)+reach*sin(turn),side*(radius-reach*cos(turn))).rotated(deg_to_rad(float(piece.heading)))
	if piece.kind == "s_bend" and key in ["radius","height"]:
		var radius: float = float(piece.radius)
		var side: float = -1.0 if piece.flip else 1.0
		var vertical: float = RoadPieces.height(piece)/(2.0*(1.0-cos(PI*0.25)))
		var turn: float = PI*0.125
		var local := Vector2(RoadPieces.S_END_LENGTH+radius*sin(turn),side*vertical*(1.0-cos(turn)))
		var tangent := Vector2(radius*cos(turn),side*vertical*sin(turn)).normalized()
		var normal := Vector2(-tangent.y,tangent.x)*side
		if key == "height":
			local = Vector2(2.0*RoadPieces.S_END_LENGTH+2.0*radius*sin(PI*0.25),side*RoadPieces.height(piece))-local
			normal = -normal
		local += normal*(float(piece.width)*0.5+2.0)
		return points[0]+local.rotated(deg_to_rad(float(piece.heading)))
	if key == "heading": return points[0]+forward*maxf(12.0,float(piece.length))
	if key == "length": return points[0]+forward*float(piece.length)
	if key == "narrow_width":
		var end_forward: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(piece.heading)))
		var end_normal := Vector2(-end_forward.y,end_forward.x)*(-1.0 if piece.flip else 1.0)
		return points[-1]-end_normal*float(piece.narrow_width)*0.5
	if key == "height": return points[-1]
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
	if not free_run:
		var result: Array = RoadPieces.barrier_run(document,start,finish,stamp_kind,stamp_scale)
		if result.is_empty() and not _run_edge_hint:
			_run_edge_hint = true
			hint_changed.emit("Object limit reached. Remove an object to continue." if document.objects.size() >= 96 else "Road edge needs a road section, layout or painted road line. Choose Line for a free run.")
		return result
	return _path_run(PackedVector2Array([start,finish]))

func _path_run(path: PackedVector2Array) -> Array:
	var fitted: PackedVector2Array = ObjectRuns.smooth(path) if run_shape == "curve" else path
	return ObjectRuns.build(fitted,stamp_kind,stamp_scale,96-document.objects.size())


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

func choose_start_line() -> void:
	cancel_gesture()
	ghost.clear()
	selected_piece = -1
	mode = "start_line"
	selection_changed.emit()
	hint_changed.emit("Tap a road to place the start line. Tap its direction arrow to reverse racing direction.")
	queue_redraw()

func flip_start_line() -> void:
	if not document.has("start_line"): return
	edit_started.emit()
	document.start_line.heading = fposmod(float(document.start_line.heading)+180.0,360.0)
	document_changed.emit()
	edit_finished.emit()
	queue_redraw()

func start_controls() -> Dictionary:
	var pose: Dictionary = document.start_line
	var center := Vector2(pose.position[0],pose.position[1])
	var forward := Vector2.RIGHT.rotated(deg_to_rad(float(pose.heading)))
	var width: float = float(document.width)
	var frame: Dictionary = RoadPieces.road_frame(document.pieces,center,forward)
	if not frame.is_empty(): width = float(frame.width)
	var normal := Vector2(-forward.y,forward.x)*width*0.5
	var screen_forward: Vector2 = (to_screen(center+forward)-to_screen(center)).normalized()
	return {"center":to_screen(center),"left":to_screen(center-normal),"right":to_screen(center+normal),"forward":screen_forward,"flip":to_screen(center)+screen_forward*72}

func _draw_start_line() -> void:
	var controls: Dictionary = start_controls()
	var a: Vector2 = controls.left
	var b: Vector2 = controls.right
	for i: int in range(12):
		draw_line(a.lerp(b,float(i)/12),a.lerp(b,float(i+1)/12),Color.WHITE if i%2 == 0 else Color("142331"),9,true)
	draw_circle(controls.center,12,Color("16c2cf"))
	draw_circle(controls.center,12,Color.WHITE,false,2,true)
	var button: Vector2 = controls.flip
	var axis: Vector2 = controls.forward
	var normal := Vector2(-axis.y,axis.x)
	draw_line(controls.center,button,Color("f3c644"),2,true)
	draw_circle(button,26,Color("f3c644"))
	draw_line(button-axis*12,button+axis*12,Color("142331"),3,true)
	draw_polyline(PackedVector2Array([button+axis*4+normal*8,button+axis*12,button+axis*4-normal*8]),Color("142331"),3,true)
	var text_pos: Vector2 = button+Vector2(-61,36)
	draw_style_box(MenuStyle.box(Color("142331"),5),Rect2(text_pos-Vector2(6,17),Vector2(138,27)))
	draw_string(ThemeDB.fallback_font,text_pos,"Tap to reverse",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

func confirm_paint() -> void:
	if paint_points.is_empty(): return
	var minimum: int = 3 if paint_mode == "area" else 2 if paint_mode == "line" else 1
	if paint_points.size() < minimum:
		hint_changed.emit("Place at least %d points, then confirm." % minimum)
		return
	if paint_mode == "area" and not SurfacePaint.valid_area(paint_points):
		hint_changed.emit("Move the points to make a simple enclosed area.")
		return
	if document.paint.size() >= 256:
		hint_changed.emit("Paint limit reached. Undo a stroke to keep editing.")
		return
	edit_started.emit()
	document.paint.append({"surface":brush_surface,"width":brush_width,"shape":brush_shape,"points":paint_points.duplicate(true),"protect_road":protect_road and brush_surface != 0,"mode":paint_mode})
	paint_points.clear()
	paint_handle = -1
	document_changed.emit()
	edit_finished.emit()
	queue_redraw()

func paint_accept_rect() -> Rect2:
	if mode != "paint" or paint_mode == "free" or paint_points.size() < (3 if paint_mode == "area" else 2): return Rect2()
	var path: PackedVector2Array = SurfacePaint.contour(paint_points,paint_mode)
	var candidate := Vector2.ZERO
	if paint_mode == "area":
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(path)
		var largest: float = -1.0
		for i: int in range(0,triangles.size(),3):
			var a: Vector2 = path[triangles[i]]
			var b: Vector2 = path[triangles[i+1]]
			var c: Vector2 = path[triangles[i+2]]
			var area: float = absf((b-a).cross(c-a))
			if area > largest:
				largest = area
				candidate = (a+b+c)/3.0
		if largest < 0.01: return Rect2()
	else:
		# Choose a point on the smoothed line away from its editable dots.
		var best: float = -1.0
		for i: int in range(path.size()-1):
			var at: Vector2 = (path[i]+path[i+1])*0.5
			var distance: float = INF
			for p: Array in paint_points: distance = minf(distance,at.distance_to(Vector2(p[0],p[1])))
			if distance > best:
				best = distance
				candidate = at
	return Rect2(to_screen(candidate)-Vector2(28,28),Vector2(56,56))
