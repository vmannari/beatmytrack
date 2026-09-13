extends SceneTree

var checks: int = 0
var failures: int = 0
var capture: bool = false
var app: Node
var folder: String

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func segment(a: Vector2, b: Vector2, kind: String = "straight") -> Dictionary:
	var piece: Dictionary = RoadPieces.create(kind,a,rad_to_deg((b-a).angle()),14)
	piece.heading = fposmod(piece.heading,360)
	piece.length = a.distance_to(b)
	return piece

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "construction_test"
	doc.name = "Overpass workshop"
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()): doc.pieces.append(segment(points[i],points[(i+1)%points.size()],"bridge" if i == 1 else "straight"))
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	check(result.ok,"crossing piece chain generates one ordered lap")
	return result.document

func run() -> void:
	capture = "--capture-construction" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	for kind: String in RoadPieces.KINDS:
		var piece: Dictionary = RoadPieces.create(kind,Vector2(-20,-10),25)
		var end: Vector2 = RoadPieces.end_pose(piece).position
		var start := Vector2(piece.position[0],piece.position[1])
		for endpoint: int in range(2):
			var target: Vector2 = (end if endpoint == 1 else start)+Vector2(4,3)
			var edited: Dictionary = RoadPieces.move_endpoint(piece,endpoint,target)
			check(not edited.is_empty(),kind+" endpoint accepts a free target")
			if edited.is_empty(): continue
			check((RoadPieces.end_pose(edited).position if endpoint == 1 else Vector2(edited.position[0],edited.position[1])).distance_to(target) < 0.001,kind+" dragged endpoint follows the target")
			check((Vector2(edited.position[0],edited.position[1]) if endpoint == 1 else RoadPieces.end_pose(edited).position).distance_to(start if endpoint == 1 else end) < 0.001,kind+" opposite endpoint remains fixed")
			check(edited.width == piece.width,kind+" endpoint keeps independent width")
	var doc: Dictionary = circuit()
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"bridge circuit compiles")
	if track == null: quit(1); return
	check(track.cell_at(Vector2.ZERO) == 0 and track.cell_at(Vector2.ZERO,true) == 0,"crossing contains independent drivable ground and deck")
	check(track.cell_at(Vector2(0,7.25),true) == 4,"bridge rails compile as upper-layer obstacles")
	check(track.cell_at(Vector2(0,7.25)) == 0,"upper rail does not block the lower crossing")
	var water: Dictionary = doc.duplicate(true)
	water.paint = [{"surface":3,"width":12.0,"shape":"square","points":[[0,0]]}]
	var wet: NativeTrack = TrackCompiler.compile(water)
	check(wet.cell_at(Vector2.ZERO) == 3 and wet.cell_at(Vector2.ZERO,true) == 0,"painting ground water preserves the upper road")
	var bridge := BridgePresentation.new(track)
	check(is_equal_approx(bridge.height_at(Vector2.ZERO,0,1),3.5) and bridge.height_at(Vector2.ZERO,0,0) == 0,"same crossing has distinct top and bottom visual heights")
	check(CreatorBridges.height(doc.pieces[1],Vector2(-30,0)) == 0 and CreatorBridges.height(doc.pieces[1],Vector2(30,0)) == 0,"both ramp ends meet ground")
	check(CreatorBridges.height(doc.pieces[1],Vector2(-26,0)) > 0 and CreatorBridges.height(doc.pieces[1],Vector2(-26,0)) < 3.5,"ramp has continuous intermediate elevation")
	check(not track.collision_elevated_at(Vector2.ZERO,0,1.364,0) and track.collision_elevated_at(Vector2.ZERO,0,1.364,1),"crossing preserves actual driving layer independently of lap tangent")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var impact := VehicleState.new()
	impact.position = Vector2(0,9)
	impact.velocity = Vector2(0,20)
	impact.track_elevated = true
	track.resolve(impact,Vector2.ZERO,config)
	check(impact.position.y < 7 and impact.collision_count > 0 and impact.track_elevated,"upper rail stops a car from leaving the deck")
	var under := VehicleState.new()
	under.position = Vector2(0,9)
	under.velocity = Vector2(0,20)
	under.track_elevated = false
	track.resolve(under,Vector2.ZERO,config)
	check(under.position.y > 8 and under.collision_count == 0 and not under.track_elevated,"lower car passes beneath the same rail")
	var diagonal: Dictionary = RoadPieces.create("bridge",Vector2(-60,-60),45,10)
	check(CreatorBridges.validate([doc.pieces[1],diagonal]).is_empty(),"separated diagonal bridge spans are allowed")
	var duplicate: Dictionary = doc.duplicate(true)
	duplicate.pieces.append(doc.pieces[1].duplicate(true))
	check(not TrackDocument.validate(duplicate).is_empty(),"overlapping elevated spans are rejected")
	check(TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc))).content_hash == track.content_hash,"bridge JSON round trip keeps identity")
	_drive(track)
	folder = "user://construction_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	app.set("document",doc)
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	await _interaction()
	app.queue_free()
	await process_frame
	var dir := DirAccess.open(folder)
	for file: String in dir.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("CONSTRUCTION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _drive(track: NativeTrack) -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	sim.state.track_elevated = track.elevated_at(track.spawn,sim.state.route_index)
	var session := TrackSession.new(120,5)
	var driver := RouteDriver.new()
	var frames: Array = []
	var upper: int = 0
	var lower: int = 0
	for tick: int in range(32000):
		var input: DriveFrame = driver.sample(sim.state,track,config)
		frames.append(input.packed())
		var before: Vector2 = sim.state.position
		sim.step(input,track)
		session.advance(track,before,sim.state.position,sim.state.route_index)
		if sim.state.position.length() < 8:
			if sim.state.track_elevated: upper += 1
			else: lower += 1
		if session.finished: break
	print("BRIDGE_RACE laps=",session.completed_laps," contacts=",sim.state.collision_count," upper=",upper," lower=",lower," ticks=",frames.size())
	check(session.finished and session.completed_laps == 5,"authored overpass completes five ordered laps")
	check(upper > 50 and lower > 50,"race drives both over and under the same crossing")
	check(sim.state.collision_count == 0,"fixture drives through both bridge ramps without rail contacts")
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	replay.state.track_elevated = track.elevated_at(track.spawn,replay.state.route_index)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new()
		input.steer = values[0]; input.throttle = values[1]; input.brake = values[2]
		replay.step(input,track)
	check(replay.state.snapshot() == sim.state.snapshot(),"bridge layer state replays exactly after JSON input round trip")

func _interaction() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	canvas.snap_enabled = false
	canvas.selected_piece = 1
	canvas._begin(canvas.to_screen(Vector2.ZERO),-1)
	check(canvas.selected_piece == 1,"dragging an already selected bridge at a crossing preserves selection")
	canvas._end(-1)
	var touch := InputEventScreenTouch.new()
	touch.index = 0; touch.pressed = true; touch.position = canvas.to_screen(Vector2(30,0))
	canvas._gui_input(touch)
	check(canvas.endpoint_drag == 1,"native touch on the end dot selects endpoint editing")
	touch.pressed = false; canvas._gui_input(touch)
	var original: Dictionary = canvas.document.pieces[1].duplicate(true)
	var inside: Vector2 = canvas.to_screen(Vector2(-10,0))
	canvas._begin(inside,-1)
	canvas._move(inside+Vector2(3,-2)*canvas.scale_factor())
	canvas._end(-1)
	check(canvas.document.pieces[1].position == [-27.0,2.0] and canvas.document.pieces[1].length == original.length,"dragging inside translates the whole bridge without resizing")
	app.call("_undo")
	await process_frame
	canvas = app.get("canvas")
	canvas.snap_enabled = false
	canvas.selected_piece = 1
	var end: Vector2 = RoadPieces.end_pose(canvas.document.pieces[1]).position
	canvas._begin(canvas.to_screen(end),-1)
	check(canvas.endpoint_drag == 1,"end dot selects endpoint editing rather than whole-piece movement")
	canvas._move(canvas.to_screen(end+Vector2(6,4)))
	canvas._end(-1)
	check(Vector2(canvas.document.pieces[1].position[0],canvas.document.pieces[1].position[1]).distance_to(Vector2(-30,0)) < 0.001,"endpoint drag fixes opposite bridge end")
	check(RoadPieces.end_pose(canvas.document.pieces[1]).position.distance_to(end+Vector2(6,4)) < 0.001,"endpoint dot reaches pointer position")
	check((app.get("history") as Array).size() == 1,"endpoint gesture creates one undo step")
	app.call("_undo")
	await process_frame
	canvas = app.get("canvas")
	canvas.mode = "paint"
	var doc_before: Dictionary = canvas.document.duplicate(true)
	var pan_before: Vector2 = canvas.pan
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE; mouse.pressed = true; mouse.position = Vector2(600,350)
	canvas._gui_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.position = mouse.position+Vector2(20,30)
	canvas._gui_input(motion)
	mouse.pressed = false; canvas._gui_input(mouse)
	check(canvas.pan == pan_before+Vector2(20,30) and canvas.document == doc_before,"middle-button pan works in Paint without a stroke")
	var anchor := Vector2(430,270)
	var before: Vector2 = canvas.to_world(anchor)
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP; mouse.pressed = true; mouse.position = anchor
	var zoom: float = canvas.zoom
	canvas._gui_input(mouse)
	check(canvas.zoom > zoom and canvas.to_world(anchor).distance_to(before) < 0.001,"mouse wheel zoom preserves the point under the cursor")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1; key.pressed = true
	Input.parse_input_event(key.duplicate())
	await process_frame
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	check(canvas.mode == "road","PC number shortcut chooses Road")
	for button: int in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_LEFT]:
		var space := InputEventKey.new()
		space.physical_keycode = KEY_SPACE; space.pressed = true
		if button == MOUSE_BUTTON_LEFT: Input.parse_input_event(space.duplicate())
		var old_pan: Vector2 = canvas.pan
		mouse.button_index = button; mouse.pressed = true; mouse.position = Vector2(600,350)
		canvas._gui_input(mouse)
		motion.position = mouse.position+Vector2(12,8)
		canvas._gui_input(motion)
		mouse.pressed = false; canvas._gui_input(mouse)
		space.pressed = false; Input.parse_input_event(space.duplicate())
		check(canvas.pan == old_pan+Vector2(12,8),"right/Space-left drag pans without editing")
	canvas.selected_piece = 1
	canvas.press_position = canvas.to_screen(Vector2.ZERO)
	key.physical_keycode = KEY_TAB; key.pressed = true
	Input.parse_input_event(key.duplicate())
	await process_frame
	key.pressed = false; Input.parse_input_event(key.duplicate())
	check(canvas.selected_piece != 1,"real Tab input cycles roads at an overpass")
	canvas.fit()
	canvas.selected_piece = 1
	app.call("_build_editor_tools")
	if capture:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/construction-editor.png")) == OK,"editor overpass screenshot")
	app.call("_test_document")
	await process_frame
	var game: Node = app.get("game")
	check(game != null,"overpass can be tested in actual practice")
	if game != null and capture:
		game.set_physics_process(false)
		var sim: VehicleSimulation = game.get("sim")
		sim.reset(Vector2(-8,0),PI*0.5)
		sim.state.track_elevated = true
		game.set("previous_position",sim.state.position)
		game.set("previous_heading",sim.state.heading)
		(game.get("camera") as FollowCamera).follow(sim.state.position,Vector2.ZERO,sim.state.heading,0,true)
		for i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/construction-practice.png")) == OK,"bridge driving screenshot")
	if game != null: app.call("_leave_race")
