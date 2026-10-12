extends SceneTree
## Geometry, compiler and real editor input checks with isolated track saves.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "spline_test"; doc.name = "Five point spline"
	doc["start_line"] = {"position":[-24.0,-18.0],"heading":0.0}
	var position := Vector2(-24,-18)
	var heading: float = 0.0
	for kind: String in ["spline","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		if kind == "spline":
			piece.point_widths = [10.0,6.0,20.0,7.0,12.0]; piece.width = 20.0
		else: piece.length = 48.0 if kind == "straight" else 0.0
		piece.radius = 18.0; doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func geometry_checks() -> void:
	var piece: Dictionary = RoadPieces.create("spline",Vector2(-24,-18))
	piece.point_widths = [10.0,6.0,20.0,7.0,12.0]; piece.width = 20.0
	check(RoadPieces.validate(piece).is_empty(),"valid five-point spline")
	var geometry: Dictionary = SplineRoad.geometry(piece)
	var nodes: PackedVector2Array = SplineRoad.points(piece)
	for i: int in range(5):
		var index: int = geometry.node_indices[i]
		check(Vector2(geometry.points[index]).is_equal_approx(nodes[i]),"fitted centreline passes through point %d" % i)
		check(is_equal_approx(float(geometry.widths[index]),float(piece.point_widths[i])),"width is exact at point %d" % i)
	for span: int in range(4):
		var begin: int = geometry.node_indices[span]
		var end: int = geometry.node_indices[span+1]
		var distance: float = 0.0
		for i: int in range(begin+1,end+1): distance += Vector2(geometry.points[i]).distance_to(geometry.points[i-1])
		var along: float = 0.0
		for i: int in range(begin+1,end+1):
			along += Vector2(geometry.points[i]).distance_to(geometry.points[i-1])
			check(absf(float(geometry.widths[i])-lerpf(piece.point_widths[span],piece.point_widths[span+1],along/distance)) < 0.00002,"width interpolates by distance within fitted span")
	for i: int in range(1,4):
		var index: int = geometry.node_indices[i]
		var incoming: Vector2 = geometry.points[index]-geometry.points[index-1]
		var outgoing: Vector2 = geometry.points[index+1]-geometry.points[index]
		check(absf(incoming.angle_to(outgoing)) < 0.1,"smooth tangent at internal point %d" % i)
	check(SplineRoad.geometry(JSON.parse_string(JSON.stringify(piece))) == geometry,"JSON roundtrip preserves exact samples and widths")
	var moved: Dictionary = SplineRoad.move_point(piece,2,Vector2(0,2))
	check(not moved.is_empty() and Vector2(SplineRoad.points(moved)[2]).is_equal_approx(Vector2(0,2)),"interior point moves independently")
	for i: int in [0,1,3,4]: check(Vector2(SplineRoad.points(moved)[i]).is_equal_approx(nodes[i]),"other control point stays fixed")
	moved = SplineRoad.move_point(piece,0,nodes[0]+Vector2(-4,3))
	for i: int in range(1,5): check(Vector2(SplineRoad.points(moved)[i]).is_equal_approx(nodes[i]),"moving origin keeps remaining points fixed")
	var mirrored: Dictionary = piece.duplicate(true); mirrored.flip = true
	check(SplineRoad.points(mirrored)[2].is_equal_approx(Vector2(0,-26)),"flip mirrors spline shape")
	var rotated: Dictionary = piece.duplicate(true); rotated.heading = 90.0
	check(SplineRoad.points(rotated)[4].is_equal_approx(Vector2(-24,30)),"rigid rotation preserves fitted shape")
	for field: String in ["spline_points","point_widths"]:
		var invalid: Dictionary = piece.duplicate(true); invalid[field].pop_back()
		check(not RoadPieces.validate(invalid).is_empty(),"reject fewer than five "+field)
		invalid = piece.duplicate(true); invalid[field].append(invalid[field][0])
		check(not RoadPieces.validate(invalid).is_empty(),"reject more than five "+field)
	var bad: Dictionary = piece.duplicate(true); bad.spline_points[2] = bad.spline_points[1]
	check(not RoadPieces.validate(bad).is_empty(),"reject coincident adjacent points before spline fitting")
	bad = piece.duplicate(true); bad.point_widths[2] = NAN
	check(not RoadPieces.validate(bad).is_empty(),"reject nonfinite width")
	bad = piece.duplicate(true); bad.spline_points[1] = ["bad",0]
	check(not RoadPieces.validate(bad).is_empty(),"reject nonnumeric point without conversion")
	bad = piece.duplicate(true); bad.point_widths[2] = 21.0
	check(not RoadPieces.validate(bad).is_empty(),"reject out-of-range width")
	var neighbour: Dictionary = RoadPieces.create("straight",RoadPieces.end_pose(piece).position,0.0,8.0)
	var own: Dictionary = RoadPieces.section_geometry([piece,neighbour],0)
	var other: Dictionary = RoadPieces.section_geometry([piece,neighbour],1)
	check(is_equal_approx(float(own.widths[-1]),10.0) and own.widths[-1] == other.widths[0],"join averages actual endpoint widths instead of widest bound")
	for i: int in range(1,4): check(is_equal_approx(float(own.widths[geometry.node_indices[i]]),float(piece.point_widths[i])),"joining preserves internal point widths")
	for width: float in own.widths: check(width >= 6.0 and width <= 20.0,"joined widths stay bounded")
	neighbour.heading = 180.0; neighbour.position = [48.0,-18.0]; neighbour.length = 24.0
	other = RoadPieces.section_geometry([piece,neighbour],1)
	check(is_equal_approx(float(other.widths[-1]),10.0),"reversed endpoint join uses spline exit width")
	var doc: Dictionary = circuit()
	var fixture: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://../docs/evidence/spline-road-2026-10-06/spline-circuit.json"),FileAccess.WRITE)
	if fixture != null: fixture.store_string(JSON.stringify(doc,"",true)); fixture.close()
	check(TrackDocument.validate(doc).is_empty(),"automatic route accepts connected spline circuit: "+str(TrackDocument.validate(doc)))
	var native: NativeTrack = TrackCompiler.compile(doc)
	check(native != null and native.route.size() > 20,"compile spline into drivable surface and ordered automatic route")
	if native == null: return
	check(native.metadata.creator_document.pieces[0].point_widths == piece.point_widths,"compiled content retains authored point widths")
	var roundtrip: NativeTrack = TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc)))
	check(native.content_hash == roundtrip.content_hash and native.cells == roundtrip.cells,"saved document recompiles exact geometry/hash")
	check(native.cell_at(Vector2(0,-10)) == 0 and native.cell_at(Vector2(0,-2)) == 0,"wide spline point has a drivable cross-section")
	check(native.cell_at(Vector2(0,2)) != 0,"outside spline width remains off road")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var simulation := VehicleSimulation.new(config)
	simulation.reset(native.spawn,native.spawn_heading)
	simulation.state.route_index = native.nearest_route(native.spawn)
	var session := TrackSession.new(120,5)
	var driver := RouteDriver.new()
	var frames: Array = []
	for tick: int in range(24000):
		var input: DriveFrame = driver.sample(simulation.state,native,config)
		frames.append(input.packed())
		var previous: Vector2 = simulation.state.position
		simulation.step(input,native)
		session.advance(native,previous,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated)
		if session.finished: break
	check(session.finished and session.completed_laps == 5,"spline circuit finishes five ordered laps")
	print("SPLINE_RACE laps=",session.completed_laps," ticks=",frames.size()," contacts=",simulation.state.collision_count)
	var replay := VehicleSimulation.new(config)
	replay.reset(native.spawn,native.spawn_heading); replay.state.route_index = native.nearest_route(native.spawn)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new()
		input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		if values.size() > 3: input.handbrake = int(values[3])
		replay.step(input,native)
	check(replay.state.snapshot() == simulation.state.snapshot(),"five-lap spline recording replays exactly")

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+20000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"editor geometry and scenery build completes")
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"save screenshot "+name)

func press(canvas: EditorCanvas, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new(); event.index = 0; event.position = at; event.pressed = down
	canvas._gui_input(event)

func run() -> void:
	geometry_checks()
	root.size = Vector2i(1280,720)
	folder = "user://spline_road_test_"+TrackLibrary.unique_id()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/spline-road-2026-10-06").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = circuit(); app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	var canvas: EditorCanvas = app.canvas
	canvas.snap_enabled = false; canvas.selected_piece = 0; app.call("_build_editor_tools")
	var first: Vector2 = canvas.to_screen(SplineRoad.points(app.document.pieces[0])[0])
	press(canvas,first,true)
	check(canvas.spline_point_drag == 0 and not canvas.start_drag,"selected spline origin can be edited when it coincides with the start line")
	press(canvas,first,false)
	var before: Dictionary = app.document.duplicate(true)
	var nodes: PackedVector2Array = SplineRoad.points(app.document.pieces[0])
	var at: Vector2 = canvas.to_screen(nodes[2])
	press(canvas,at,true)
	check(canvas.spline_point == 2 and canvas.spline_point_drag == 2,"touch selects third numbered point")
	var drag := InputEventScreenDrag.new(); drag.index = 0; drag.position = at+Vector2(0,-24)
	canvas._gui_input(drag); press(canvas,drag.position,false)
	check(app.document.pieces[0] != before.pieces[0] and app.history.size() == 1,"point drag changes geometry in one undo operation")
	var after: Dictionary = app.document.duplicate(true)
	app.call("_undo")
	check(app.document.pieces == before.pieces,"undo restores all spline points and widths")
	app.call("_redo")
	check(app.document.pieces == after.pieces,"redo restores exact spline edit")
	await settle()
	canvas.selected_piece = 0; canvas.spline_point = 1; app.call("_build_editor_tools")
	app.call("_change_piece","point_width",1.0)
	check(is_equal_approx(float(app.document.pieces[0].point_widths[1]),7.0),"toolbar edits the selected width")
	check(app.document.pieces[0].point_widths[2] == 20.0,"toolbar leaves other widths untouched")
	canvas.spline_point = 3
	at = canvas.spline_width_handle(app.document.pieces[0])
	press(canvas,at,true)
	check(canvas.geometry_drag == "point_width","width handle has a real touch hit target")
	nodes = SplineRoad.points(app.document.pieces[0])
	var normal: Vector2 = SplineRoad.tangent(nodes,3).normalized().orthogonal()
	drag.position = at+canvas.to_screen(nodes[3]+normal*2.0)-canvas.to_screen(nodes[3])
	canvas._gui_input(drag); press(canvas,drag.position,false)
	check(is_equal_approx(float(app.document.pieces[0].point_widths[3]),11.0),"width drag changes full cross-section width")
	await settle()
	var saved: Dictionary = app.document.duplicate(true)
	check(app.library.save_document(saved) == OK,"save spline document")
	check(app.library.load_document(saved.id).pieces == JSON.parse_string(JSON.stringify(saved)).pieces,"load retains all five points and widths at saved JSON precision")
	# A second finger rolls back a partial spline point edit and its history.
	var history: Array = app.history.duplicate(true)
	at = canvas.to_screen(SplineRoad.points(saved.pieces[0])[2]); press(canvas,at,true)
	drag.position = at+Vector2(15,0); canvas._gui_input(drag)
	var second := InputEventScreenTouch.new(); second.index = 1; second.position = at+Vector2(100,60); second.pressed = true
	canvas._gui_input(second)
	check(app.document.pieces == saved.pieces and app.history == history,"pinch rolls back spline geometry and undo")
	second.pressed = false; canvas._gui_input(second); press(canvas,at,false)
	for physical: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = physical; await process_frame
		canvas.selected_piece = 0; canvas.spline_point = 2; canvas.fit(); app.call("_build_editor_tools")
		await settle(); await shot("spline-%dx%d" % [physical.x,physical.y])
	canvas.confirm_piece(); app.call("_build_editor_tools"); await shot("palette")
	canvas.choose_piece("spline")
	check(canvas.ghost.kind == "spline" and canvas.ghost.spline_points.size() == 5,"palette creates a five-point ghost")
	canvas.snap_enabled = false; canvas.ghost.position = [-24.0,-55.0]
	canvas.confirm_piece()
	check(app.document.pieces.size() == 5 and app.document.pieces[-1].kind == "spline","confirm places spline as an ordinary road block")
	await settle()
	app.queue_free(); await process_frame
	cleanup(folder)
	print("SPLINE_ROAD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
