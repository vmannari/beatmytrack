extends SceneTree
## Real app, real native scenery, and touch-oriented authoring through the
## wireframe workflow. Captures are engine output, not mockups.

var checks: int = 0
var failures: int = 0
var app: Node
var test_directory: String
var capture_directory: String = ""


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func run() -> void:
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-workflow="):
			capture_directory = argument.trim_prefix("--capture-workflow=")
		elif argument == "--capture-workflow":
			capture_directory = ProjectSettings.globalize_path("res://").path_join("../build").simplify_path()
	if not capture_directory.is_empty():
		check(capture_directory.is_absolute_path() and DisplayServer.get_name() != "headless", "workflow captures use an absolute path and actual graphical renderer")
		check(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "workflow evidence directory is writable")
		if failures > 0:
			_finish()
			return
	test_directory = "user://editor_workflow_tests_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(test_directory)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.set("library",TrackLibrary.new(test_directory))
	app.set("records",LocalRecords.new(test_directory.path_join("records.json")))
	root.add_child(app)
	await process_frame
	await _show_document(TrackDocument.create_blank())
	await _blank_and_connect()
	_ghost_snap_feedback()
	await _local_geometry()
	await _geometry_handles()
	await _world_and_touch()
	_pinch_handoff()
	await _move_start_tangent()
	await _practice_spawn_checks()
	await _objects_and_issues()
	app.queue_free()
	await process_frame
	_finish()


func _show_document(doc: Dictionary) -> void:
	doc.id = "workflow_track"
	app.set("document",doc)
	app.set("editor_view",{})
	app.set("history",[])
	app.set("redo_history",[])
	app.call("_show_screen","create")
	await process_frame
	await process_frame


func _blank_and_connect() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	var doc: Dictionary = app.get("document")
	check(doc.layout.is_empty() and doc.pieces.is_empty() and doc.paint.is_empty(), "blank creation begins with editable terrain and no imposed road loop")
	check(canvas.get_global_rect().size.is_equal_approx(root.get_visible_rect().size), "the editing canvas fills the landscape viewport")
	check(canvas.mode == "road", "blank creation opens the Road workflow")
	for text: String in ["Track","Surfaces","Objects","Race"]:
		check(_button(app.get("root_ui"),text) != null, "category rail exposes " + text)
	var before: Dictionary = doc.duplicate(true)
	canvas.choose_piece("straight")
	check(not canvas.ghost.is_empty() and canvas.ghost.kind == "straight" and doc == before, "choosing a straight previews it without mutating the saved map")
	check((app.get("history") as Array).is_empty(), "uncommitted placement creates no undo entry")
	canvas.ghost.position = [-28.0,-18.0]
	canvas.ghost.length = 56.0
	canvas.zoom = 1.12
	canvas.pan = Vector2.ZERO
	canvas.queue_redraw()
	app.call("_build_editor_tools")
	await _capture("start")
	canvas.confirm_piece()
	check(doc.pieces.size() == 1 and canvas.ghost.is_empty(), "confirming the ghost commits one road section")
	check(canvas.selected_piece == -1 and _button(app.get("root_ui"),"Straight") != null and _button(app.get("root_ui"),"Curve") != null,"confirming a section immediately returns to the road palette for the next placement")
	check((app.get("history") as Array).size() == 1, "confirmed placement creates exactly one undo entry")
	var stored: Dictionary = (app.get("library") as TrackLibrary).load_document(doc.id)
	check(stored == doc, "a placed open road is saved as an editable draft")
	canvas.choose_piece("curve")
	check(canvas.snap_matched, "next section previews an aligned endpoint join")
	check(Vector2(canvas.ghost.position[0],canvas.ghost.position[1]).is_equal_approx(RoadPieces.end_pose(doc.pieces[0]).position), "connection preview aligns to the existing end")
	check(canvas.ghost.heading == doc.pieces[0].heading and canvas.ghost.width == doc.pieces[0].width, "connection preview matches direction and road width")
	app.call("_build_editor_tools")
	await _capture("connect")
	canvas.confirm_piece()
	check(doc.pieces.size() == 2 and RoadPieces.joins(doc.pieces).size() == 2, "committed straight and curve expose only their two free ends")
	check((app.get("history") as Array).size() == 2, "second section is a separate reversible edit")


func _local_geometry() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	var doc: Dictionary = app.get("document")
	var before: Dictionary = doc.duplicate(true)
	canvas.selected_piece = 1
	canvas.ghost.clear()
	app.call("_change_piece","width",2.0)
	check(doc.pieces[1].width == float(before.pieces[1].width) + 2.0, "selected section has its own editable width")
	check(doc.pieces[0] == before.pieces[0] and doc.points == before.points, "local width editing preserves other sections and the separate lap route")
	var width_changed: Dictionary = doc.duplicate(true)
	app.call("_change_piece","radius",4.0)
	check(doc.pieces[1].radius == float(before.pieces[1].radius) + 4.0 and doc.pieces[0] == before.pieces[0], "radius editing changes only the selected section")
	app.call("_undo")
	await process_frame
	await process_frame
	check(app.get("document") == width_changed, "Undo restores the exact preceding local geometry")
	app.call("_redo")
	await process_frame
	await process_frame
	check(float((app.get("document") as Dictionary).pieces[1].radius) == float(before.pieces[1].radius) + 4.0, "Redo restores the local radius edit")


func _ghost_snap_feedback() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	var before: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	canvas.choose_piece("straight")
	check(canvas.snap_matched,"new ghost starts with accurate matched feedback")
	app.call("_change_piece","heading",15.0)
	check(not canvas.snap_matched,"rotating a ghost clears the stale Join aligned claim")
	canvas.choose_piece("straight")
	app.set("editor_geometry","width")
	app.call("_build_editor_tools")
	var handle: Vector2 = canvas._geometry_handle(canvas.ghost,"width")
	var widened: Dictionary = canvas.ghost.duplicate(true)
	widened.width = float(widened.width)+2.0
	var target: Vector2 = canvas._geometry_handle(widened,"width")
	_touch(canvas,74,canvas.to_screen(handle),true)
	_drag(canvas,74,canvas.to_screen(target))
	_touch(canvas,74,canvas.to_screen(target),false)
	check(canvas.ghost.width == widened.width and not canvas.snap_matched,"dragging ghost width clears unmatched-width feedback")
	check(app.get("document") == before,"editing a ghost does not alter committed roads")
	canvas.ghost.clear()
	app.set("editor_geometry","")


func _world_and_touch() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	var editor_world: EditorWorld = _find_type(app.get("root_ui"),"EditorWorld") as EditorWorld
	check(editor_world != null and canvas.world_backdrop, "the creator draws shared native 3D scenery behind the touch canvas")
	if editor_world == null:
		return
	check(editor_world.track == canvas.native_preview and editor_world.visual is NativeTrackVisual, "world and editing overlay share the exact compiled track")
	check(editor_world.mouse_filter == Control.MOUSE_FILTER_IGNORE and editor_world.viewport.gui_disable_input, "background scenery cannot intercept editing touches")
	canvas.zoom = 1.5
	canvas.pan = Vector2(37,-24)
	editor_world.call("_sync_camera")
	await process_frame
	await process_frame
	for point: Vector2 in [Vector2.ZERO,Vector2(-20,12),Vector2(34,-18)]:
		var projected: Vector2 = editor_world.camera.unproject_position(Vector3(point.x,0,-point.y))
		check(projected.distance_to(canvas.to_screen(point)) < 1.0, "3D road and touch coordinates align after zoom and pan: " + str(point))
	canvas.ghost.clear()
	canvas.selected_piece = -1
	app.call("_editor_category","road")
	var doc: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var a := Vector2(480,150)
	var b := Vector2(740,150)
	var initial_zoom: float = canvas.zoom
	var initial_pan: Vector2 = canvas.pan
	_touch(canvas,31,a,true)
	_touch(canvas,32,b,true)
	_drag(canvas,31,a+Vector2(-20,20))
	_drag(canvas,32,b+Vector2(35,20))
	_touch(canvas,32,b+Vector2(35,20),false)
	_touch(canvas,31,a+Vector2(-20,20),false)
	check(canvas.zoom > initial_zoom and canvas.pan != initial_pan, "two fingers navigate the scene while the road tool is active")
	check(app.get("document") == doc and canvas.touches.is_empty() and not canvas.dragging, "pinch navigation does not alter road sections or leave a captured finger")
	for text: String in ["Track","Surfaces","Objects","Race"]:
		var button: Button = _button(app.get("root_ui"),text)
		if button == null:
			continue
		check(button.get_global_rect().size.x >= 48 and button.get_global_rect().size.y >= 48 and root.get_visible_rect().encloses(button.get_global_rect()), text + " has a visible touch-sized target inside the landscape viewport")
	var surface_button: Button = _button(app.get("root_ui"),"Surface")
	if surface_button != null:
		await _viewport_tap(surface_button.get_global_rect().get_center())
		check(canvas.mode == "paint", "viewport-dispatched finger tap opens the Surface tools")
		check(app.get("document") == doc, "tapping a category does not paint through the overlay")


func _geometry_handles() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	var doc: Dictionary = app.get("document")
	canvas.mode = "road"
	canvas.selected_piece = 1
	canvas.ghost.clear()
	app.set("editor_geometry","radius")
	app.call("_build_editor_tools")
	var before: Dictionary = doc.duplicate(true)
	var history_size: int = (app.get("history") as Array).size()
	var handle: Vector2 = canvas._geometry_handle(doc.pieces[1],"radius")
	var position: Vector2 = canvas.to_screen(handle)
	_touch(canvas,41,position,true)
	check(canvas.geometry_drag == "radius" and doc == before, "touching a radius handle selects it without changing or moving the road")
	_drag(canvas,41,canvas.to_screen(handle+Vector2(2,2)))
	_drag(canvas,41,canvas.to_screen(handle+Vector2(4,4)))
	_touch(canvas,41,canvas.to_screen(handle+Vector2(4,4)),false)
	check(doc.pieces[1].radius == float(before.pieces[1].radius)+4.0, "continuous radius drag measures total displacement from the original touch")
	check(doc.pieces[1].position == before.pieces[1].position and doc.pieces[0] == before.pieces[0] and doc.points == before.points, "radius handle leaves the section anchor, neighboring road and lap route unchanged")
	check((app.get("history") as Array).size() == history_size+1, "a multi-motion radius gesture creates one undo step")
	check(_button(app.get("root_ui"),"Radius %.1f m" % float(doc.pieces[1].radius)) != null, "released radius edit refreshes the visible dimension caption")
	canvas.selected_piece = 0
	app.set("editor_geometry","width")
	app.call("_build_editor_tools")
	before = doc.duplicate(true)
	history_size = (app.get("history") as Array).size()
	handle = canvas._geometry_handle(doc.pieces[0],"width")
	position = canvas.to_screen(handle)
	_touch(canvas,42,position,true)
	check(canvas.geometry_drag == "width" and doc == before, "touching the width handle does not jump the road under the finger")
	_drag(canvas,42,canvas.to_screen(handle+Vector2(0,1)))
	_drag(canvas,42,canvas.to_screen(handle+Vector2(0,1.5)))
	_touch(canvas,42,canvas.to_screen(handle+Vector2(0,1.5)),false)
	check(doc.pieces[0].width == float(before.pieces[0].width)+3.0 and doc.pieces[1] == before.pieces[1], "dragging one road edge widens only that section by the actual full width")
	check((app.get("history") as Array).size() == history_size+1 and doc.pieces[0].position == before.pieces[0].position, "width gesture preserves placement and creates one undo step")
	check(_button(app.get("root_ui"),"Width %.1f m" % float(doc.pieces[0].width)) != null, "released width edit refreshes its dimension caption")
	before = doc.duplicate(true)
	handle = canvas._geometry_handle(doc.pieces[0],"width")
	position = canvas.to_screen(handle)
	_touch(canvas,43,position,true)
	canvas.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_drag(canvas,43,position+Vector2(0,40))
	check(doc == before and not canvas.dragging and canvas.touches.is_empty(), "focus cancellation releases a geometry handle and ignores stale motion")
	_touch(canvas,44,position,true)
	_touch(canvas,45,position+Vector2(80,0),true)
	_drag(canvas,45,position+Vector2(120,20))
	_touch(canvas,45,position+Vector2(120,20),false)
	_touch(canvas,44,position,false)
	check(doc == before and not canvas.dragging and canvas.touches.is_empty(), "a second finger converts a pending geometry edit to navigation without changing dimensions")


func _oval_document() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.name = "Forest Workshop"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading,10.0)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var end: Dictionary = RoadPieces.end_pose(piece)
		position = end.position
		heading = end.heading
	var routed: Dictionary = RoadPieces.route_from_pieces(doc)
	check(routed.ok, "four workflow sections form a closed drivable oval")
	for decoration: Vector2 in [Vector2(-37,32),Vector2(-31,35),Vector2(-25,31),Vector2(12,34),Vector2(18,37),Vector2(25,32),Vector2(-30,-34),Vector2(-24,-37),Vector2(35,-32),Vector2(42,-28),Vector2(-12,3),Vector2(-6,6),Vector2(16,-3)]:
		doc.objects.append({"kind":"tree","position":[decoration.x,decoration.y],"rotation":0.0})
	for decoration: Vector2 in [Vector2(-43,23),Vector2(41,27),Vector2(-6,-30),Vector2(6,5)]:
		doc.objects.append({"kind":"rock","position":[decoration.x,decoration.y],"rotation":45.0})
	return doc


func _pinch_handoff() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	app.call("_editor_category","road")
	var before: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var history_size: int = (app.get("history") as Array).size()
	for canceled: bool in [false,true]:
		for first_lifts: bool in [false,true]:
			var points: PackedVector2Array = RoadPieces.samples(canvas.document.pieces[0])
			var a: Vector2 = canvas.to_screen(points[points.size()/2])
			var b: Vector2 = a+Vector2(120,-60)
			_touch(canvas,71,a,true)
			_touch(canvas,72,b,true)
			b += Vector2(40,-10)
			_drag(canvas,72,b)
			_touch(canvas,71 if first_lifts else 72,a if first_lifts else b,false,canceled)
			var survivor: int = 72 if first_lifts else 71
			var position: Vector2 = b if first_lifts else a
			var pan_before: Vector2 = canvas.pan
			check(canvas.active_pointer == survivor and canvas.panning and not canvas.dragging,"either pinch release order hands navigation to the remaining finger (canceled=%s, first=%s)" % [canceled,first_lifts])
			_drag(canvas,survivor,position+Vector2(24,18))
			check(canvas.pan.is_equal_approx(pan_before+Vector2(24,18)),"the surviving finger continues panning after pinch release")
			_touch(canvas,survivor,position+Vector2(24,18),false)
	check(app.get("document") == before and (app.get("history") as Array).size() == history_size and canvas.touches.is_empty(),"pinch handoffs from a road selection create no geometry edits or stale touches")


func _move_start_tangent() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	var curve: Dictionary = RoadPieces.create("curve",Vector2.ZERO)
	curve.length = 0.0
	curve.radius = 10.0
	doc.pieces = [curve]
	await _show_document(doc)
	var canvas: EditorCanvas = app.get("canvas")
	var route_before: Array = doc.points.duplicate(true)
	app.call("_move_practice_start")
	var position: Vector2 = canvas.to_screen(Vector2(7,3))
	_touch(canvas,73,position,true)
	_touch(canvas,73,position,false)
	check(doc.has("practice_start") and Vector2(doc.practice_start.position[0],doc.practice_start.position[1]) == Vector2(7,3),"Move start commits the tapped road location")
	check(absf(wrapf(float(doc.practice_start.heading)-45.0,-180.0,180.0)) < 3.0,"start placed halfway round a quarter-circle faces its nearest tangent, not the last nearby sample")
	check(doc.points == route_before,"moving the practice start preserves the separate lap route")


func _practice_spawn_checks() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	var curve: Dictionary = RoadPieces.create("curve",Vector2.ZERO,0.0,6.0)
	curve.length = 0.0
	curve.radius = 3.0
	doc.pieces = [curve]
	await _show_document(doc)
	(app.get("test_button") as Button).pressed.emit()
	await process_frame
	var game: Node = app.get("game")
	check(game != null,"zero-lead-in tight bend can enter untimed practice")
	if game != null:
		game.set_physics_process(false)
		var samples: PackedVector2Array = RoadPieces.samples(curve)
		var tangent: Vector2 = (samples[7]-samples[5]).normalized()
		check((game.get("sim") as VehicleSimulation).state.forward().dot(tangent) > 0.999,"practice on a radius-three bend faces the local spawn tangent")
		app.call("_leave_race")
		await process_frame
	doc = TrackDocument.create_blank()
	doc.pieces = [RoadPieces.create("straight",Vector2.ZERO)]
	var start: Vector2 = RoadPieces.samples(doc.pieces[0])[6]
	doc.objects = [{"kind":"barrier","position":[start.x,1.5],"rotation":0.0}]
	await _show_document(doc)
	var canvas: EditorCanvas = app.get("canvas")
	check(not CreatorObjects.contains(doc.objects[0],start) and canvas.native_preview.cell_at(start) == 0,"offset-obstacle fixture leaves the practice center on clear asphalt")
	check((app.get("test_button") as Button).disabled and not (app.get("editor_issues") as Array).is_empty(),"a barrier overlapping the car radius still blocks practice when the center is clear")
	doc["practice_start"] = {"position":[0.0,0.0],"heading":0.0}
	doc.objects = [{"kind":"barrier","position":[0.0,0.0],"rotation":0.0}]
	app.call("_save_draft")
	check((app.get("test_button") as Button).disabled,"a start centered inside a symmetric obstacle remains blocked even if contact normals cancel")


func _objects_and_issues() -> void:
	await _show_document(_oval_document())
	var canvas: EditorCanvas = app.get("canvas")
	var doc: Dictionary = app.get("document")
	var old_route: Array = doc.points.duplicate(true)
	var road_geometry: Array = doc.pieces.duplicate(true)
	app.call("_editor_category","move")
	var use_roads: Button = _button(app.get("root_ui"),"Use roads")
	check(use_roads != null, "Race tools expose explicit route creation from connected roads")
	if use_roads != null: use_roads.pressed.emit()
	check(doc.points != old_route and doc.pieces == road_geometry and doc.route_override, "Use roads creates a separate lap route while preserving the authored road sections")
	var route_track: NativeTrack = TrackCompiler.compile(doc)
	var route_on_road: bool = route_track != null
	if route_track != null:
		for point: Vector2 in route_track.route: route_on_road = route_on_road and route_track.cell_at(point) == 0
	check(route_on_road, "the derived native lap remains on the actual section road surfaces")
	canvas.zoom = 1.04
	canvas.pan = Vector2(0,12)
	canvas.mode = "road"
	canvas.selected_piece = 1
	app.call("_build_editor_tools")
	var shape: Button = _button(app.get("root_ui"),"Shape")
	check(shape != null, "selected bend exposes a direct Shape action")
	if shape != null: shape.pressed.emit()
	check(str(app.get("editor_geometry")) == "radius", "Shape opens local bend radius controls")
	await _capture("geometry")
	app.call("_editor_category","objects")
	canvas.mode = "run"
	canvas.stamp_kind = "barrier"
	app.call("_build_editor_tools")
	var count: int = doc.objects.size()
	var history_before: int = (app.get("history") as Array).size()
	canvas._place(canvas.to_screen(Vector2(8,-26)))
	check(canvas.run_start != Vector2.INF and doc.objects.size() == count, "first barrier tap previews a run without prematurely adding objects")
	canvas._place(canvas.to_screen(Vector2(51,10)))
	check(doc.objects.size() >= count + 4 and canvas.run_start == Vector2.INF, "second barrier tap places a run following the road edge")
	check((app.get("history") as Array).size() == history_before + 1, "a complete barrier run is one undo operation")
	var turns: bool = false
	for i: int in range(count,doc.objects.size()):
		turns = turns or absf(float(doc.objects[i].rotation)) > 10.0
	check(turns, "barriers rotate with the curved road instead of forming a straight stamp line")
	app.call("_build_editor_tools")
	await _capture("objects")
	var library: TrackLibrary = app.get("library")
	check(library.load_document(doc.id) == JSON.parse_string(JSON.stringify(doc)), "section roads and barrier runs persist together in the actual JSON contract")
	var native: NativeTrack = TrackCompiler.compile(doc)
	check(native != null and native.cells == canvas.native_preview.cells, "visible editor scenery uses the same updated collision and surface content")
	# Controlled obstruction fixture exercises real validation and recovery UI.
	var first_road: PackedVector2Array = RoadPieces.samples(doc.pieces[0])
	var spawn: Vector2 = first_road[0] + (first_road[1]-first_road[0]).normalized()*4.0
	doc.objects.append({"kind":"barrier","position":[spawn.x,spawn.y],"rotation":0.0})
	app.call("_save_draft")
	app.call("_editor_category","move")
	await process_frame
	await process_frame
	var issues: Array = app.get("editor_issues")
	check(not issues.is_empty() and (app.get("test_button") as Button).disabled, "a barrier blocking the start creates a visible issue and disables Test")
	app.call("_focus_issue")
	await process_frame
	await process_frame
	check(canvas.selected_object == doc.objects.size()-1 and canvas.issue_marker.distance_to(spawn) < 2.0, "issue action locates and selects the actual blocking object")
	await _capture("issue")
	var blocked_document: Dictionary = doc.duplicate(true)
	var move_start: Button = _button(app.get("root_ui"),"Move start")
	check(move_start != null, "a blocked start offers a direct Move start recovery action")
	if move_start != null: move_start.pressed.emit()
	check(canvas.mode == "start", "Move start requests a placement tap on the actual map")
	var clear_start := Vector2(-4,-18)
	var start_touch: Vector2 = canvas.to_screen(clear_start)
	_touch(canvas,51,start_touch,true)
	_touch(canvas,51,start_touch,false)
	check(doc.has("practice_start") and Vector2(doc.practice_start.position[0],doc.practice_start.position[1]) == clear_start, "a map tap stores the selected practice start position")
	check(doc.objects == blocked_document.objects and not (app.get("test_button") as Button).disabled and TrackDocument.validate(doc).is_empty(), "moving the start resolves the issue while preserving the obstacle and a valid document")
	check(library.load_document(doc.id) == JSON.parse_string(JSON.stringify(doc)), "the alternative practice start is saved with the map")
	app.call("_undo")
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	doc = app.get("document")
	check(doc == blocked_document and (app.get("test_button") as Button).disabled, "Undo restores the original blocked start and its issue")
	app.call("_focus_issue")
	var blocked_count: int = doc.objects.size()
	app.call("_delete_selection")
	check(doc.objects.size() == blocked_count-1 and not (app.get("test_button") as Button).disabled, "deleting the selected obstruction directly restores practice access")
	var before_practice: Dictionary = doc.duplicate(true)
	var compiled_before: NativeTrack = TrackCompiler.compile(doc)
	(app.get("test_button") as Button).pressed.emit()
	await process_frame
	var game: Node = app.get("game")
	check(game != null and bool(game.get("editor_test")), "a closed section circuit launches actual editor practice")
	if game != null:
		game.set_physics_process(false)
		var driven: NativeTrack = game.get("native_track")
		var sim: VehicleSimulation = game.get("sim")
		check(driven.content_hash == compiled_before.content_hash and driven.cells == compiled_before.cells, "practice preserves the exact authored section and barrier collision content")
		check(sim.state.forward().dot((first_road[1]-first_road[0]).normalized()) > 0.999, "the practice car starts facing along the first road section")
		game.set("ai_enabled",true)
		for tick: int in range(600): game.call("_physics_process",1.0/120.0)
		var position: Vector2 = sim.state.position
		check(sim.state.tick >= 600 and not bool(game.get("paused")), "section practice drives continuously without an automatic result")
		var hud: PlaygroundHUD = game.get("hud")
		(hud.find_child("EditHere",true,false) as Button).pressed.emit()
		await process_frame
		await process_frame
		canvas = app.get("canvas")
		check(app.get("game") == null and app.get("document") == before_practice and canvas.to_screen(position).distance_to(canvas.size*0.5) < 2.0, "Edit here returns to the same section map at the actual driven location")
		check((app.get("records") as LocalRecords).records.is_empty(), "section practice cannot create a personal best")


func _capture(stage: String) -> void:
	if capture_directory.is_empty(): return
	await process_frame
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var path: String = capture_directory.path_join("editor-workflow-" + stage + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "engine workflow capture saved: " + stage)
	print("WORKFLOW_CAPTURE_SAVED: " + path)


func _find_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and str(node.get_script().get_global_name()) == type_name: return node
	for child: Node in node.get_children():
		var found: Node = _find_type(child,type_name)
		if found != null: return found
	return null


func _button(node: Node, text: String) -> Button:
	if node is Button and (node.text == text or node.text.ends_with("\n"+text)): return node
	for child: Node in node.get_children():
		var found: Button = _button(child,text)
		if found != null: return found
	return null


func _touch(canvas: EditorCanvas, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	canvas._gui_input(event)


func _drag(canvas: EditorCanvas, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	canvas._gui_input(event)


func _viewport_tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _finish() -> void:
	if test_directory.begins_with("user://editor_workflow_tests_track_"):
		var directory := DirAccess.open(test_directory)
		if directory != null:
			for filename: String in directory.get_files():
				DirAccess.remove_absolute(test_directory.path_join(filename))
			DirAccess.remove_absolute(test_directory)
	print("EDITOR_WORKFLOW_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
