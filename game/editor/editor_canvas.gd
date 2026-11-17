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
const OBJECT_DRAG_THRESHOLD: float = 6.0

var document: Dictionary
var mode: String = "road"
var selected_piece: int = -1
var ghost: Dictionary = {}
var piece_kind: String = "straight"
var snap_enabled: bool = true
var snap_matched: bool = false
var road_action: String = "move"
var geometry_drag: String = ""
var geometry_origin: float = 0.0
var road_approval_pending: bool = false
var preparing: bool = false
## Camera intent is independent of the active tool and its pending previews.
var navigation_override: bool = false
var endpoint_drag: int = -1
var spline_point: int = 2
var spline_point_drag: int = -1
var _spline_preview_cache: Array[Dictionary] = []
var _prepared_geometry: Dictionary = {}
var preparation_counts: Dictionary = {}
const CANVAS_CACHE_BUDGET: int = 4 * 1024 * 1024

func _prepared(key: String, source: Array, build: Callable) -> Variant:
	var entry: Dictionary = _prepared_geometry.get(key,{})
	if not entry.is_empty() and entry.source == source: return entry.value
	var value: Variant = build.call()
	var saved_source: Array = source.duplicate(true)
	var bytes: int = var_to_bytes([saved_source,value]).size()+128
	_prepared_geometry.erase(key)
	var total: int = bytes
	for old: Dictionary in _prepared_geometry.values(): total += int(old.bytes)
	while not _prepared_geometry.is_empty() and total > CANVAS_CACHE_BUDGET:
		var expired: String = _prepared_geometry.keys()[0]; total -= int(_prepared_geometry[expired].bytes); _prepared_geometry.erase(expired)
	if bytes <= CANVAS_CACHE_BUDGET: _prepared_geometry[key] = {"source":saved_source,"value":value,"bytes":bytes}
	preparation_counts[key] = int(preparation_counts.get(key,0))+1
	return value

func cache_bytes() -> int:
	var total: int = 0
	for entry: Dictionary in _prepared_geometry.values(): total += int(entry.bytes)
	for entry: Dictionary in _spline_preview_cache: total += int(entry.bytes)
	return total

func trim_cache() -> void:
	_prepared_geometry.clear(); _spline_preview_cache.clear()

func prepared_joins() -> Array:
	return _prepared("joins",[document.pieces],RoadPieces.joins.bind(document.pieces))

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
var stamp_length: float = 0.0
var stamp_jump_profile: String = ""
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
var selected_objects: Array[int] = []
var multi_select: bool = false
var object_snap: float = 1.0
var selected_object: int = -1:
	set(value):
		selected_object = value
		if value < 0: selected_objects.clear()
		elif not multi_select: selected_objects.assign([value])
var _selection_toggle: int = -1
var _object_pick_world := Vector2.INF
var stamp_kind: String = "tree"
var stamp_rotation: float = 0.0
var pending_stamp: bool = false
var pending_object_selection: int = -1
var press_position := Vector2.ZERO
var drag_origin := Vector2.ZERO
var pointer_origin := Vector2.ZERO
var changed_in_gesture: bool = false
var active_pointer: int = -99
var touches: Dictionary = {}
var dragging: bool = false
var panning: bool = false
var previous_pointer := Vector2.ZERO
var fitted: bool = false
var fit_pending_native: bool = false
## Optional available area in canvas coordinates, supplied by the editor UI.
var fit_area: Callable
var native_preview: NativeTrack
var visual_preview: NativeTrack
var gesture = preload("res://editor/editor_gesture.gd").new()
var _gesture_document: Dictionary:
	get: return gesture.before
var _gesture_absent: Array[String]:
	get: return gesture.absent
var _gesture_ghost: Dictionary:
	get: return gesture.ghost
var _navigation_only: bool:
	get: return gesture.phase == gesture.Phase.NAVIGATION
	set(value): gesture.phase = gesture.Phase.NAVIGATION if value else gesture.Phase.IDLE
var _run_edge_hint: bool = false

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		if not fitted: fit()
		queue_redraw())

func scale_factor() -> float:
	return maxf(0.01, minf(size.x / 110.0, size.y / 90.0)) * zoom

func to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + pan + Vector2(point.x, -point.y*sin(deg_to_rad(PLANNING_PITCH))) * scale_factor()

func to_world(point: Vector2) -> Vector2:
	var local: Vector2 = (point - size * 0.5 - pan) / scale_factor()
	return Vector2(local.x, -local.y/sin(deg_to_rad(PLANNING_PITCH)))

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
		if fit_area.is_valid():
			var available: Rect2 = fit_area.call()
			if available.size.x >= 40 and available.size.y >= 40:
				var projected_height: float = (bounds.size.y+24)*sin(deg_to_rad(PLANNING_PITCH))
				zoom = clampf(minf(available.size.x/(bounds.size.x+24),available.size.y/projected_height)/base,0.05,16.0)
				pan += available.get_center()-to_screen(bounds.get_center())
			else:
				zoom = clampf(minf((size.x-24)/(bounds.size.x+24),(size.y-156)/(bounds.size.y+24))/base,0.25,16.0)
				pan += size*0.5-to_screen(bounds.get_center())
		else:
			zoom = clampf(minf((size.x-24)/(bounds.size.x+24),(size.y-156)/(bounds.size.y+24))/base,0.25,16.0)
			pan += size*0.5-to_screen(bounds.get_center())
	queue_redraw()

func zoom_by(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	fit_pending_native = false
	if anchor == Vector2.INF: anchor = size*0.5
	var before: Vector2 = to_world(anchor)
	zoom = clampf(zoom * factor, 0.05 if fit_area.is_valid() else 0.25, 16.0)
	pan += anchor-to_screen(before)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func show_native(track: NativeTrack) -> void:
	native_preview = track
	if fit_pending_native:
		fit_pending_native = false
		fit()
	native_changed.emit(track)
	queue_redraw()

func object_indices() -> Array[int]:
	var result: Array[int] = []
	for index: int in selected_objects:
		if index >= 0 and index < document.objects.size() and index not in result: result.append(index)
	if selected_object >= 0 and selected_object < document.objects.size() and selected_object not in result: result.append(selected_object)
	result.sort()
	return result

func object_position(point: Vector2) -> Vector2:
	return point.snapped(Vector2.ONE*object_snap).clamp(Vector2(-110,-110),Vector2(110,110)) if object_snap > 0.0 else point.clamp(Vector2(-110,-110),Vector2(110,110))

func cycle_objects() -> void:
	if selected_object < 0: return
	var at: Vector2 = _object_pick_world if _object_pick_world != Vector2.INF else Vector2(document.objects[selected_object].position[0],document.objects[selected_object].position[1])
	var hits: Array[int] = preload("res://editor/object_editing.gd").candidates(document.objects,to_screen(at),at,to_screen)
	if hits.size() < 2: hint_changed.emit("Only one object is under this point."); return
	multi_select = false
	selected_object = hits[(hits.find(selected_object)+1)%hits.size()]
	selection_changed.emit(); queue_redraw()

func toggle_multi_select() -> void:
	multi_select = not multi_select
	if not multi_select: selected_objects.assign([selected_object] if selected_object >= 0 else [])
	selection_changed.emit(); queue_redraw()

func cancel_gesture(discard_previews: bool = true) -> void:
	# Passive UI/navigation cancels the pointer transaction while keeping
	# completed previews. Explicit Cancel/Discard still clears those previews.
	var had_pointer: bool = active_pointer != -99
	_rollback_navigation_edit()
	_selection_toggle = -1
	pending_paint_accept = false
	if discard_previews or drawing_run:
		run_draw.clear()
		run_preview.clear()
	drawing_run=false
	if discard_previews:
		run_start=Vector2.INF
		paint_points.clear()
	elif had_pointer and mode == "paint":
		paint_points = paint_before_gesture.duplicate(true) if paint_mode != "free" else []
	paint_handle = -1
	pending_stamp = false
	pending_object_selection = -1
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
	_navigation_only = false
	gesture.clear()

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
			else:
				_prepare_release(event.position,-1)
				_end(-1)
	elif event is InputEventMouseMotion and active_pointer < 0 and active_pointer != -99:
		_move(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
			if touches.size() == 1: _begin(event.position, event.index)
			else:
				_rollback_navigation_edit()
				_navigation_only = true
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
				pending_object_selection = -1
				dragging = false
		else:
			var was_pinching: bool = touches.size() >= 2
			touches.erase(event.index)
			if event.canceled:
				if event.index == active_pointer: _rollback_navigation_edit()
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
				pending_object_selection = -1
				if paint_mode == "free": paint_points.clear()
				elif mode == "paint": paint_points = paint_before_gesture.duplicate(true)
			if not event.canceled: _prepare_release(event.position,event.index)
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

func _prepare_release(point: Vector2, pointer: int) -> void:
	if pointer != active_pointer: return
	# A captured pointer can be released outside the canvas or its confirm
	# target without a final drag event. Releasing there must not activate it.
	if not Rect2(Vector2.ZERO,size).has_point(point):
		cancel_gesture(false)
		return
	if pending_piece_accept:
		var piece: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece] if selected_piece >= 0 else {}
		if piece.is_empty() or not piece_accept_rect(piece).has_point(point): pending_piece_accept = false
	if pending_paint_accept and not paint_accept_rect().has_point(point): pending_paint_accept = false
	if pending_start_flip and Vector2(start_controls().flip).distance_to(point) > 28: pending_start_flip = false
	if pending_stamp and mode == "place":
		if fit_area.is_valid() and not Rect2(fit_area.call()).has_point(point):
			cancel_gesture(false)
			return
		previous_pointer = point
	if press_position.distance_to(point) > 12:
		if mode != "place": pending_stamp = false
		pending_object_selection = -1
		pending_road_tap = false

func _rollback_navigation_edit() -> void:
	bump_end_drag = -1
	if not changed_in_gesture: return
	if gesture.rollback(document):
		document_changed.emit()
		edit_cancelled.emit()
	ghost = _gesture_ghost.duplicate(true)
	changed_in_gesture = false
	selection_changed.emit()

func _start_edit() -> void:
	gesture.capture(document,mode)
	edit_started.emit()

func admit(field: String, value: Variant) -> bool:
	var error: String = preload("res://editor/authoring_admission.gd").replacement(document,field,value)
	if error.is_empty(): return true
	hint_changed.emit(error)
	return false

func _begin(point: Vector2, pointer: int) -> void:
	fit_pending_native = false
	active_pointer = pointer
	previous_pointer = point
	press_position = point
	pointer_origin = to_world(point)
	changed_in_gesture = false
	_selection_toggle = -1
	pending_object_selection = -1
	gesture.begin(ghost,preparing or navigation_override)
	if _navigation_only:
		panning = true; dragging = false
		return
	_run_edge_hint = false
	bump_end_drag = -1
	if mode == "objects" and selected_object >= 0 and object_indices().size() == 1 and selected_object < document.objects.size() and document.objects[selected_object].kind == "speed_bump":
		var ends: PackedVector2Array = SpeedBumpEdit.endpoints(document.objects[selected_object])
		var nearest: float = 24.0
		for end: int in range(2):
			var distance: float = to_screen(ends[end]).distance_to(point)
			if distance < nearest: nearest = distance; bump_end_drag = end
		if bump_end_drag >= 0:
			bump_before_drag = document.objects[selected_object].duplicate(true)
			dragging = true
			return
	if mode == "place":
		var hits: Array[int] = preload("res://editor/object_editing.gd").candidates(document.objects,point,to_world(point),to_screen)
		if not hits.is_empty():
			pending_stamp = false
			pending_object_selection = hits[0]
			return
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
	if mode == "pan":
		panning = true
		return
	pending_stamp = mode == "place"
	if pending_stamp: return
	selected = -1
	var hit: int = -1
	if mode == "objects":
		_object_pick_world = to_world(point)
		var hits: Array[int] = preload("res://editor/object_editing.gd").candidates(document.objects,point,_object_pick_world,to_screen)
		if not hits.is_empty(): hit = hits[0]
		if not multi_select: selected_object = hit
		elif hit >= 0:
			if hit in selected_objects: _selection_toggle = hit
			else: selected_objects.append(hit)
			selected_object = hit
		if hit < 0 and native_preview != null and document.objects.size() < preload("res://editor/creator_limits.gd").MAX_OBJECTS:
			for object: Dictionary in native_preview.metadata.get("scenery_objects",[]):
				if CreatorObjects.contains(object,to_world(point)) or to_screen(Vector2(object.position[0],object.position[1])).distance_to(point) < 24:
					var admission: String = preload("res://editor/creator_limits.gd").addition_error(document.objects,[object],str(document.theme))
					if not admission.is_empty(): hint_changed.emit(admission); break
					var proposed: Dictionary = document.duplicate()
					proposed.objects = document.objects+[object]
					proposed.hidden_scenery = document.get("hidden_scenery",[])+[CreatorScenery.key(object)]
					admission = preload("res://editor/authoring_admission.gd").error(proposed,"objects")
					if not admission.is_empty(): hint_changed.emit(admission); break
					_start_edit()
					if not document.has("hidden_scenery"): document["hidden_scenery"] = []
					document.hidden_scenery.append(CreatorScenery.key(object))
					document.objects.append(object.duplicate(true))
					changed_in_gesture = true
					selected_object = document.objects.size()-1
					hit = selected_object
					if multi_select and hit not in selected_objects: selected_objects.append(hit)
					document_changed.emit()
					break
	selection_changed.emit()
	if hit >= 0:
		var value: Array = document.objects[selected_object].position
		drag_origin = Vector2(value[0],value[1])
		dragging = true
	else: panning = true
	queue_redraw()

func _move(point: Vector2) -> void:
	if _navigation_only:
		pan += point-previous_pointer; previous_pointer = point; queue_redraw()
		return
	if pending_object_selection >= 0:
		if press_position.distance_to(point) < OBJECT_DRAG_THRESHOLD: return
		pending_object_selection = -1
		panning = true
	if bump_end_drag >= 0:
		if press_position.distance_to(point) < 3.0 and not changed_in_gesture: return
		var changed: Dictionary = SpeedBumpEdit.move_end(bump_before_drag,bump_end_drag,to_world(point))
		if changed == document.objects[selected_object]: return
		if not changed_in_gesture: _start_edit(); changed_in_gesture = true
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
		if pose.is_empty() or pose == document.get("start_line",{}): return
		if not changed_in_gesture: _start_edit()
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
		if mode == "place":
			previous_pointer = point
			queue_redraw()
			return
		if press_position.distance_to(point) > 12:
			pending_stamp = false
			panning = true
	if dragging:
		if press_position.distance_to(point) < OBJECT_DRAG_THRESHOLD and not changed_in_gesture: return
		if selected_object < 0: return
		var delta: Vector2 = to_world(point)-pointer_origin
		if object_snap > 0.0: delta = delta.snapped(Vector2.ONE*object_snap)
		if delta.is_zero_approx() and not changed_in_gesture: return
		var original: Array = gesture.before.get("objects",document.objects)
		var moved: Array = preload("res://editor/object_editing.gd").moved(original,object_indices(),delta)
		if moved == document.objects: return
		if not changed_in_gesture:
			_start_edit()
			changed_in_gesture = true
		document.objects = moved
		document_changed.emit()
	elif panning: pan += point-previous_pointer
	previous_pointer = point
	queue_redraw()

func _place(point: Vector2) -> void:
	if preparing: return
	if mode in ["place","run"] and not _stamp_available():
		hint_changed.emit("Choose an object from this biome's object collection.")
		return
	var position: Vector2 = object_position(to_world(point))
	if mode == "start_line":
		var pose: Dictionary = CreatorStartLine.place(document,to_world(point),native_preview)
		if pose.is_empty():
			hint_changed.emit("Place the start line on a road.")
			return
		if not admit("start_line",pose): return
		_start_edit()
		document["start_line"] = pose
		mode = "road"
		document_changed.emit()
		edit_finished.emit()
		selection_changed.emit()
		queue_redraw()
		return
	if mode == "start":
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
		var pose: Dictionary = {"position":[position.x,position.y],"heading":heading}
		if not admit("practice_start",pose): return
		_start_edit()
		document["practice_start"] = pose
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
			run_preview = preload("res://editor/creator_limits.gd").take(document.objects,run_preview,str(document.theme))
			if not run_preview.is_empty():
				if not admit("objects",document.objects+run_preview): return
				_start_edit()
				document.objects.append_array(run_preview)
				document_changed.emit()
				edit_finished.emit()
				hint_changed.emit("%d objects placed." % run_preview.size())
			run_start = Vector2.INF
			run_preview.clear()
		queue_redraw()
		return
	if mode == "place":
		if document.objects.size() >= preload("res://editor/creator_limits.gd").MAX_OBJECTS:
			hint_changed.emit("Use up to %d objects. Select one to move or remove it." % preload("res://editor/creator_limits.gd").MAX_OBJECTS)
			return
		var object: Dictionary = placement_object(point)
		var admission: String = preload("res://editor/creator_limits.gd").addition_error(document.objects,[object],str(document.theme))
		if not admission.is_empty(): hint_changed.emit(admission); return
		if not admit("objects",document.objects+[object]): return
		_start_edit()
		document.objects.append(object)
		selected_object = -1
		selected = -1
	else: return
	document_changed.emit()
	edit_finished.emit()
	selection_changed.emit()
	queue_redraw()

func placement_object(point: Vector2) -> Dictionary:
	var position: Vector2 = object_position(to_world(point))
	var object: Dictionary = {"kind":stamp_kind,"position":[position.x,position.y],"rotation":stamp_rotation}
	if stamp_scale != 1.0: object["scale"] = stamp_scale
	if stamp_kind == "speed_bump": object["span"] = stamp_span
	if stamp_kind == "jump" and stamp_jump_profile != "legacy": object["jump_profile"] = stamp_jump_profile if stamp_jump_profile in JumpProfiles.IDS else JumpProfiles.default_for(str(document.theme))
	if stamp_kind == "container": object["color"] = stamp_container_color
	if stamp_kind in ObjectRuns.CONTINUOUS and stamp_length > 0: object["length"] = stamp_length
	return object

func _end(pointer: int) -> void:
	if pointer != active_pointer: return
	if _navigation_only:
		gesture.clear(); dragging = false; panning = false; active_pointer = -99
		return
	if pending_object_selection >= 0:
		if pending_object_selection < document.objects.size():
			mode = "objects"
			multi_select = false
			selected_object = pending_object_selection
			_object_pick_world = to_world(press_position)
			selection_changed.emit()
		pending_object_selection = -1
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
		run_preview = preload("res://editor/creator_limits.gd").take(document.objects,run_preview,str(document.theme))
		if not run_preview.is_empty():
			if not admit("objects",document.objects+run_preview):
				drawing_run = false; active_pointer = -99
				return
			_start_edit()
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
	if pending_stamp: _place(previous_pointer if mode == "place" else press_position)
	if _selection_toggle >= 0 and not changed_in_gesture:
		selected_objects.erase(_selection_toggle)
		selected_object = selected_objects.back() if not selected_objects.is_empty() else -1
		if selected_objects.is_empty(): multi_select = false
		_selection_toggle = -1
		selection_changed.emit()
	if dragging and changed_in_gesture:
		var error: String = preload("res://editor/authoring_admission.gd").error(document,"pieces" if mode == "road" else "objects" if mode == "objects" else mode)
		if not error.is_empty():
			_rollback_navigation_edit()
			hint_changed.emit(error)
		else: edit_finished.emit()
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
	gesture.clear()
	if mode == "paint" and paint_mode != "free": selection_changed.emit()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: cancel_gesture(false)

func _draw() -> void:
	if document.is_empty() or size.x < 10 or size.y < 10: return
	var palette: Array[Color] = TrackTheme.palette(str(document.theme))
	if native_preview != null and document.base_track == "" and (document.layout.is_empty() or not document.pieces.is_empty()):
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
	for piece: Dictionary in pending_road_pieces(): _draw_piece(piece,false,false)
	var selected_indices: Array[int] = object_indices()
	for i: int in range(document.get("objects",[]).size()):
		if mode not in ["objects","place","run"] or i not in selected_indices: continue
		var object: Dictionary = document.objects[i]
		var outline := PackedVector2Array()
		for point: Vector2 in CreatorObjects.outline(object): outline.append(to_screen(point))
		outline.append(outline[0])
		draw_polyline(outline,Color("edf1f3") if selected_object == i else Color("70d9df"),3,true)
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
		for join: Dictionary in prepared_joins():
			draw_circle(to_screen(join.position),5,Color("e2efec"),false,2,true)
	if document.has("start_line") and mode in ["road","start_line"] and not editing_spline(): _draw_start_line()
	if run_start != Vector2.INF: draw_circle(to_screen(run_start),10,Color("16c2cf"),false,3,true)
	for object: Dictionary in run_preview:
		var outline := PackedVector2Array()
		for p: Vector2 in CreatorObjects.outline(object): outline.append(to_screen(p))
		draw_colored_polygon(outline,Color(0.05,0.8,0.86,0.6))
	if pending_stamp and mode == "place" and _stamp_available():
		var outline := PackedVector2Array()
		for point: Vector2 in CreatorObjects.outline(placement_object(previous_pointer)): outline.append(to_screen(point))
		if outline.size() >= 3:
			draw_colored_polygon(outline,Color(0.1,0.78,0.84,0.35))
			outline.append(outline[0])
			draw_polyline(outline,EditorStyle.ACCENT,2,true)
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
	if fit_area.is_valid(): base = Rect2(fit_area.call()).end-Vector2(16,8)
	draw_line(base-Vector2(ruler*scale_factor(),0),base,Color("e5ece8"),2,true)
	draw_string(ThemeDB.fallback_font,base-Vector2(42,9),"%.1f m" % ruler,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e5ece8"))

func choose_piece(kind: String) -> void:
	cancel_gesture()
	navigation_override = false
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
		if not admit("pieces",document.pieces+[ghost]): return
		if not _valid_bridge_edit(ghost,-1): return
		_start_edit()
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
	var candidates: Array[int] = []
	if ghost.is_empty(): candidates = road_candidates(point)
	var other_body: bool = false
	var other_distance: float = INF
	if not candidates.is_empty() and candidates[0] != selected_piece:
		var geometries: Array = _prepared("road_picking",[document.pieces],_road_pick_geometry)
		other_body = Geometry2D.is_point_in_polygon(to_world(point),geometries[candidates[0]].outline)
		if other_body: other_distance = _road_center_distance(geometries[candidates[0]].points,point)
	if not current.is_empty() and current.kind == "spline" and _begin_spline(current,point,other_distance): return
	if not current.is_empty():
		for key: String in geometry_keys(current):
			if to_screen(_geometry_handle(current,key)).distance_to(point) <= minf(24.0,other_distance+0.001):
				geometry_drag = key
				geometry_origin = RoadPieces.height(current) if key == "height" else float(current.get(key,0.0 if key == "curvature" else 90.0))
				piece_before_drag = current.duplicate(true)
				dragging = true
				queue_redraw()
				return
		for end: int in range(0 if current.kind == "spline" else 2):
			var handle: Vector2 = Vector2(current.position[0],current.position[1]) if end == 0 else RoadPieces.end_pose(current).position
			if to_screen(handle).distance_to(point) <= minf(26.0,other_distance+0.001):
				endpoint_drag = end
				piece_before_drag = current.duplicate(true)
				dragging = true
				return
	if not current.is_empty() and piece_accept_rect(current).has_point(point) and piece_accept_rect(current).get_center().distance_to(point) <= other_distance+0.001:
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
		selected_piece = candidates[0] if not candidates.is_empty() else -1
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
	var others: Array = document.pieces.duplicate()
	if ghost.is_empty() and selected_piece >= 0 and selected_piece < others.size(): others.remove_at(selected_piece)
	var topology: Dictionary = _prepared("endpoints",[others],RoadPieces.prepare_endpoints.bind(others))
	# The topology cache already owns the immutable neighbour snapshot. Use its
	# revision here rather than deep-copying every neighbour for each trial pose.
	return _prepared("attachment",[piece,int(preparation_counts.get("endpoints",0))],RoadPieces.attached_end.bind(piece,others,-1,topology))

func editing_spline() -> bool:
	if mode != "road": return false
	var piece: Dictionary = ghost if not ghost.is_empty() else document.pieces[selected_piece] if selected_piece >= 0 else {}
	return piece.get("kind","") == "spline"

func spline_width_handle(piece: Dictionary) -> Vector2:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	var normal: Vector2 = SplineRoad.tangent(nodes,spline_point).normalized().orthogonal()
	var reach: float = maxf(float(piece.point_widths[spline_point])*0.5+2.0,48.0/scale_factor())
	return to_screen(nodes[spline_point]+normal*reach)

func _begin_spline(piece: Dictionary, point: Vector2, hit_limit: float = INF) -> bool:
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	var closest: int = -1
	var distance: float = minf(26.0,hit_limit+0.001)
	for i: int in range(nodes.size()):
		var candidate: float = to_screen(nodes[i]).distance_to(point)
		if candidate < distance: closest = i; distance = candidate
	if closest >= 0:
		spline_point = closest
		spline_point_drag = closest
	elif spline_width_handle(piece).distance_to(point) <= minf(24.0,hit_limit+0.001):
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
	if ghost.is_empty() and not changed_in_gesture: _start_edit()
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
	if press_position.distance_to(point) < OBJECT_DRAG_THRESHOLD and not changed_in_gesture: return
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
		if trial == piece: return
		if trial.is_empty():
			hint_changed.emit("Keep the section inside the map and within its size limits.")
			return
		if trial == piece or not _valid_bridge_edit(trial,selected_piece): return
		if ghost.is_empty() and not changed_in_gesture: _start_edit()
		changed_in_gesture = true
		if ghost.is_empty():
			document.pieces[selected_piece] = trial
			document_changed.emit()
		else: ghost = trial
		snap_matched = false
		queue_redraw()
		return
	if geometry_drag != "":
		var control: Dictionary = _handle_geometry(piece_before_drag,true)[geometry_drag]
		var axis: Vector2 = control.increased-control.anchor
		var delta: float = (to_world(point)-pointer_origin).dot(axis)/maxf(0.01,axis.length_squared())
		if piece.kind == "curve" and geometry_drag == "angle":
			var side: float = -1.0 if piece.flip else 1.0
			var center: Vector2 = Vector2(piece_before_drag.position[0],piece_before_drag.position[1])+Vector2(0,side*float(piece_before_drag.radius)).rotated(deg_to_rad(float(piece_before_drag.heading)))
			var anchor: Vector2 = control.anchor
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
		var errors: Array[String] = RoadPieces.validate(trial)
		if not errors.is_empty(): hint_changed.emit(errors[0]); return
		if trial == piece or not _valid_bridge_edit(trial,selected_piece): return
		if ghost.is_empty() and not changed_in_gesture: _start_edit()
		changed_in_gesture = true
		if ghost.is_empty(): document.pieces[selected_piece] = trial
		else: ghost = trial
		snap_matched = false
		if ghost.is_empty(): document_changed.emit()
		queue_redraw()
		return
	var displacement: Vector2 = (to_world(point)-pointer_origin).snapped(Vector2.ONE*0.5)
	var original_position: Array = (_gesture_ghost if not ghost.is_empty() else piece_before_drag).get("position",[drag_origin.x,drag_origin.y])
	var moved: Dictionary = piece.duplicate(true)
	# Preserve untouched encoded coordinates instead of round-tripping them
	# through Vector2's single-precision components.
	moved.position = [float(original_position[0])+displacement.x,float(original_position[1])+displacement.y]
	if not RoadPieces.validate(moved).is_empty():
		hint_changed.emit("Keep the whole section inside the map.")
		return
	if moved == piece or not _valid_bridge_edit(moved,selected_piece): return
	if ghost.is_empty() and not changed_in_gesture: _start_edit()
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
	var bytes: int = var_to_bytes(entry).size()+64
	entry["bytes"] = bytes
	var total: int = bytes
	for old: Dictionary in _spline_preview_cache: total += int(old.bytes)
	while not _spline_preview_cache.is_empty() and (_spline_preview_cache.size() >= 4 or total > CANVAS_CACHE_BUDGET): total -= int(_spline_preview_cache.pop_front().bytes)
	if bytes <= CANVAS_CACHE_BUDGET: _spline_preview_cache.append(entry)
	return entry

func _draw_piece(piece: Dictionary, is_ghost: bool, controls: bool = true) -> void:
	var geometry: Dictionary = _prepared("controls",[piece],RoadPieces.section_geometry.bind([piece],0))
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
	var tint: Color = Color(0.01,0.76,0.85,0.4 if is_ghost else 0.23) if controls else Color("8b8070") if RoadPieces.material(piece,document) == "gravel" else Color("45494c")
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
	var layout: Dictionary = geometry_controls(piece)
	var handle_geometry: Dictionary = _handle_geometry(piece)
	for key: String in geometry_keys(piece):
		var handle: Vector2 = layout[key]
		if piece.kind == "bridge": draw_line(to_screen(handle_geometry[key].anchor),handle,Color("b9faff"),1.5,true)
		var axis: Vector2 = (to_screen(handle_geometry[key].increased)-to_screen(handle_geometry[key].anchor)).normalized()
		_draw_geometry_glyph(handle,"span" if key == "radius" and piece.kind == "s_bend" else key,axis,geometry_drag == key and dragging)
	var captions: Dictionary = geometry_caption_rects(piece)
	for key: String in geometry_keys(piece):
		var label_rect: Rect2 = captions[key]
		var handle: Vector2 = layout[key]
		var edge: Vector2 = handle.clamp(label_rect.position,label_rect.end)
		if handle.distance_to(edge) > 25: draw_line(handle,edge,Color("b9faff"),1.5,true)
		draw_style_box(MenuStyle.box(Color("142331"),5),label_rect)
		draw_string(ThemeDB.fallback_font,label_rect.position+Vector2(6,17),geometry_caption(piece,key),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)


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
	var center: Vector2 = to_screen(points[points.size()/4 if piece.kind != "bridge" else points.size()/2])
	if document.has("start_line"):
		var controls: Dictionary = start_controls()
		var away: Vector2 = Vector2(controls.forward).orthogonal()
		# The complete square and finger-sized arrow circle stay disjoint at
		# every zoom. The same rectangle owns both drawing and input.
		if Rect2(center-Vector2(28,28),Vector2(56,56)).grow(34).has_point(controls.flip):
			center = Vector2(controls.flip)+away*80.0
	return Rect2(center-Vector2(28,28),Vector2(56,56))

func geometry_keys(piece: Dictionary) -> Array[String]:
	return preload("res://editor/road_piece_catalog.gd").handles(str(piece.kind))


func geometry_caption(piece: Dictionary, key: String) -> String:
	var title: String = "Rotate" if key == "heading" else "Narrow width" if key == "narrow_width" else "Straight" if key == "length" and piece.kind not in ["straight","taper","bridge"] else key.capitalize()
	var value: float = RoadPieces.height(piece) if key == "height" else float(piece.get(key,0.0 if key == "curvature" else 90.0))
	return GameText.message(title)+" "+(GameText.message("%.0f deg") if key in ["angle","heading"] else GameText.message("%.1f m")) % value

## Caption boxes avoid every control and one another while remaining near their
## own handles. The handle positions and touch targets themselves do not move.
func geometry_caption_rects(piece: Dictionary) -> Dictionary:
	var layout: Dictionary = geometry_controls(piece)
	var available := Rect2(Vector2.ZERO,size)
	if fit_area.is_valid():
		var visible: Rect2 = fit_area.call()
		if visible.size.x >= 40 and visible.size.y >= 40: available = visible.intersection(available)
	return _prepared("caption_layout",[piece,layout,size,pan,scale_factor(),document.get("start_line",{}),TranslationServer.get_locale(),available],_layout_geometry_caption_rects.bind(piece,layout,available))

func _layout_geometry_caption_rects(piece: Dictionary, layout: Dictionary, available: Rect2) -> Dictionary:
	var blocked: Array[Rect2] = [piece_accept_rect(piece).grow(4)]
	for value: Vector2 in layout.values(): blocked.append(Rect2(value-Vector2(20,20),Vector2(40,40)))
	for endpoint: Vector2 in [Vector2(piece.position[0],piece.position[1]),Vector2(RoadPieces.end_pose(piece).position)]:
		blocked.append(Rect2(to_screen(endpoint)-Vector2(17,17),Vector2(34,34)))
	if document.has("start_line"):
		var start: Dictionary = start_controls()
		blocked.append(Rect2(Vector2(start.flip)-Vector2(28,28),Vector2(56,56)))
		blocked.append(Rect2(Vector2(start.flip)+Vector2(-67,19),Vector2(138,27)))
		blocked.append(Rect2(Vector2(start.center)-Vector2(14,14),Vector2(28,28)))
	var result: Dictionary = {}
	for key: String in geometry_keys(piece):
		var caption: String = geometry_caption(piece,key)
		var label_size := Vector2(ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+12,24)
		var handle: Vector2 = layout[key]
		var chosen := Rect2(handle+Vector2(-label_size.x*0.5,24),label_size)
		var best_score: float = INF
		for ring: int in range(7):
			for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				var center: Vector2 = handle+direction*(Vector2(label_size.x*0.5+24,label_size.y*0.5+24)+Vector2.ONE*ring*18)
				var candidate := Rect2(center-label_size*0.5,label_size)
				var outside: float = maxf(0,available.position.x-candidate.position.x)+maxf(0,available.position.y-candidate.position.y)+maxf(0,candidate.end.x-available.end.x)+maxf(0,candidate.end.y-available.end.y)
				var collisions: int = 0
				for rect: Rect2 in blocked:
					if rect.intersects(candidate): collisions += 1
				var score: float = collisions*100000.0+outside*1000.0+center.distance_squared_to(handle)
				if score < best_score:
					best_score = score
					chosen = candidate
		result[key] = chosen
		blocked.append(chosen.grow(2))
	return result

func _geometry_handle(piece: Dictionary, key: String) -> Vector2:
	return to_world(geometry_controls(piece)[key])

func geometry_controls(piece: Dictionary) -> Dictionary:
	var geometry: Dictionary = _handle_geometry(piece)
	return _prepared("handle_layout",[piece,geometry,size,pan,scale_factor(),document.get("start_line",{})],_layout_geometry_controls.bind(piece,geometry))

func _handle_geometry(piece: Dictionary, gesture_origin: bool = false) -> Dictionary:
	return _prepared("drag_handle_geometry" if gesture_origin else "handle_geometry",[piece,_attached_end(piece)],_build_handle_geometry.bind(piece))

func _build_handle_geometry(piece: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in geometry_keys(piece):
		var increased: Dictionary = piece.duplicate(true)
		increased[key] = (RoadPieces.height(piece) if key == "height" else float(piece.get(key,0.0 if key == "curvature" else 90.0)))+1.0
		if piece.kind == "s_bend" and key == "radius": increased.height = RoadPieces.height(piece)
		increased = anchored_change(piece,increased,key)
		result[key] = {"anchor":_geometry_anchor(piece,key),"increased":_geometry_anchor(increased,key)}
	return result

func _layout_geometry_controls(piece: Dictionary, geometry: Dictionary) -> Dictionary:
	var controls: Dictionary = {}
	var accept: Rect2 = piece_accept_rect(piece).grow(20)
	if piece.kind != "bridge":
		var occupied: Array[Vector2] = [to_screen(Vector2(piece.position[0],piece.position[1])),to_screen(RoadPieces.end_pose(piece).position)]
		for key: String in geometry_keys(piece):
			var anchor: Vector2 = to_screen(geometry[key].anchor)
			var candidate: Vector2 = anchor
			if key != "width":
				for step: int in range(97):
					candidate = anchor+Vector2.LEFT.rotated(float(step%8)*TAU/8.0)*float((step+7)/8)*12.0
					var clear: bool = not accept.has_point(candidate)
					for other: Vector2 in occupied:
						if candidate.distance_to(other) < 48: clear = false; break
					if clear: break
			controls[key] = candidate
			occupied.append(candidate)
		return controls
	var blocked: Array[Rect2] = [accept]
	for endpoint: Vector2 in [Vector2(piece.position[0],piece.position[1]),Vector2(RoadPieces.end_pose(piece).position)]:
		blocked.append(Rect2(to_screen(endpoint)-Vector2(40,40),Vector2(80,80)))
	for key: String in geometry_keys(piece):
		var anchor: Vector2 = to_screen(geometry[key].anchor)
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

func _road_pick_geometry() -> Array:
	var result: Array = []
	var topology: Dictionary = RoadPieces.prepare_endpoints(document.pieces)
	for index: int in range(document.pieces.size()):
		var geometry: Dictionary = RoadPieces.section_geometry(document.pieces,index,topology)
		result.append({"points":geometry.points,"outline":RoadPieces.section_outline(document.pieces,index,0.0,topology)})
	return result

func _road_center_distance(points: PackedVector2Array, point: Vector2) -> float:
	var distance: float = INF
	for sample_index: int in range(points.size()-1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point,to_screen(points[sample_index]),to_screen(points[sample_index+1]))
		distance = minf(distance,closest.distance_to(point))
	return distance

func road_candidates(point: Vector2) -> Array[int]:
	var hits: Array[Dictionary] = []
	var geometries: Array = _prepared("road_picking",[document.pieces],_road_pick_geometry)
	var world_point: Vector2 = to_world(point)
	for index: int in range(geometries.size()):
		var geometry: Dictionary = geometries[index]
		var inside: bool = Geometry2D.is_point_in_polygon(world_point,geometry.outline)
		var distance: float = _road_center_distance(geometry.points,point)
		if inside or distance <= 24.0: hits.append({"index":index,"inside":inside,"distance":distance})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.inside != b.inside: return a.inside
		if not is_equal_approx(a.distance,b.distance): return a.distance < b.distance
		return a.index > b.index)
	var result: Array[int] = []
	for hit: Dictionary in hits: result.append(hit.index)
	return result

func cycle_piece() -> void:
	if mode != "road" or not ghost.is_empty(): return
	var hits: Array[int] = road_candidates(press_position)
	if hits.is_empty(): return
	selected_piece = hits[(hits.find(selected_piece)+1)%hits.size()]
	selection_changed.emit()
	queue_redraw()

func _valid_bridge_edit(piece: Dictionary, index: int) -> bool:
	# Ordinary roads cannot introduce a bridge constraint into a bridge-free
	# document. Keep the complete validator for every actual bridge dependency.
	if piece.kind != "bridge":
		var others: Array = document.pieces.duplicate()
		if ghost.is_empty() and index >= 0 and index < others.size(): others.remove_at(index)
		if not _prepared("has_bridges",[others],func() -> bool: return others.any(func(item: Dictionary) -> bool: return item.kind == "bridge")): return true
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
	if not _stamp_available(): return []
	if not free_run:
		var paths: Array = _prepared("runs",[document.pieces,document.layout,document.paint],RoadPieces.prepare_run.bind(document))
		var result: Array = RoadPieces.barrier_run(document,start,finish,stamp_kind,stamp_scale,paths)
		if result.is_empty() and not _run_edge_hint:
			_run_edge_hint = true
			var candidate: Dictionary = {"kind":stamp_kind,"position":[start.x,start.y],"rotation":stamp_rotation}
			var admission: String = preload("res://editor/creator_limits.gd").addition_error(document.objects,[candidate],str(document.theme))
			hint_changed.emit(admission if not admission.is_empty() else "Road edge needs a road section, layout or painted road line. Choose Line for a free run.")
		return result
	return _path_run(PackedVector2Array([start,finish]))

func _path_run(path: PackedVector2Array) -> Array:
	if not _stamp_available(): return []
	var fitted: PackedVector2Array = ObjectRuns.smooth(path) if run_shape == "curve" else path
	return preload("res://editor/creator_limits.gd").take(document.objects,ObjectRuns.build(fitted,stamp_kind,stamp_scale,preload("res://editor/creator_limits.gd").remaining(document.objects,stamp_kind)),str(document.theme))

func _stamp_available() -> bool:
	var biome: String = str(document.get("theme","pine"))
	return biome not in CreatorCatalog.BIOME_ASSETS or CreatorCatalog.family(stamp_kind).is_empty() or CreatorCatalog.available(stamp_kind,biome)


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
	_start_edit()
	document.pieces[selected_piece] = result
	document_changed.emit()
	edit_finished.emit()
	selection_changed.emit()
	queue_redraw()

func choose_start_line() -> void:
	navigation_override = false
	cancel_gesture()
	ghost.clear()
	selected_piece = -1
	mode = "start_line"
	selection_changed.emit()
	hint_changed.emit("Tap a road to place the start line. Tap its direction arrow to reverse racing direction.")
	queue_redraw()

func flip_start_line() -> void:
	if not document.has("start_line"): return
	var pose: Dictionary = document.start_line.duplicate(true)
	pose.heading = fposmod(float(pose.heading)+180.0,360.0)
	if not admit("start_line",pose): return
	_start_edit()
	document.start_line = pose
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
	var stroke: Dictionary = {"surface":brush_surface,"width":brush_width,"shape":brush_shape,"points":paint_points.duplicate(true),"protect_road":protect_road and brush_surface != 0,"mode":paint_mode}
	if not admit("paint",document.paint+[stroke]): return
	_start_edit()
	document.paint.append(stroke)
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
