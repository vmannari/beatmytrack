extends SceneTree

var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func button(node: Node, title: String) -> Button:
	if node is Button and (node.text == title or node.text.ends_with("\n"+title)): return node
	for child: Node in node.get_children():
		var found: Button = button(child,title)
		if found != null: return found
	return null

func touch(canvas: EditorCanvas, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point; event.index = 0; event.pressed = pressed; event.canceled = canceled
	canvas._gui_input(event)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var folder: String = "user://start_line_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "start_line_test"
	var position := Vector2(-28,-18)
	var heading: float = 0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	app.set("document",doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	check(button(app.get("root_ui"),"Waypoints") == null,"waypoints rail is removed")
	var start_button: Button = button(app.get("root_ui"),"Start line")
	check(start_button != null,"Track palette exposes Start line")
	var canvas: EditorCanvas = app.get("canvas")
	start_button.pressed.emit()
	var location: Vector2 = canvas.to_screen(Vector2(0,-16))
	touch(canvas,location,true); touch(canvas,location,false)
	check(doc.has("start_line") and Vector2(doc.start_line.position[0],doc.start_line.position[1]).distance_to(Vector2(0,-18))<0.01,"placed start snaps onto the road centreline")
	check(canvas.mode == "road","placement returns to Track")
	check(doc.points == RoadPieces.route_from_pieces(doc).document.points,"route generates without a waypoints menu or extra action")
	for invalid: Variant in [{}, {"position":[0,0],"heading":360}, {"position":[111,0],"heading":0}, {"position":[0,0],"heading":NAN}]:
		var bad: Dictionary = doc.duplicate(true)
		bad["start_line"] = invalid
		check(not TrackDocument.validate(bad).is_empty(),"invalid start-line pose is rejected")
	var original: NativeTrack = TrackCompiler.compile(doc)
	check(original.finish_center.distance_to(Vector2(0,-18))<0.2,"timed finish uses placed start position")
	check((original.route[1]-original.route[0]).x>0,"forward start follows the road chain")
	await screenshot("forward")
	var before: Dictionary = doc.duplicate(true)
	var history: int = app.get("history").size()
	var flip: Vector2 = canvas.start_controls().flip
	touch(canvas,flip,true); touch(canvas,flip,false,true)
	check(doc == before,"canceled direction press does not reverse")
	touch(canvas,flip,true); touch(canvas,flip,false)
	check(is_equal_approx(float(doc.start_line.heading),180.0),"one tap on start arrow reverses direction")
	check(app.get("history").size() == history+1,"direction reversal is one undo step")
	var reversed: NativeTrack = TrackCompiler.compile(doc)
	check((reversed.route[1]-reversed.route[0]).x<0 and reversed.finish_forward.x<0,"compiled route and timing gate face reversed direction")
	check(reversed.cells == original.cells,"direction reversal preserves physical roads")
	check(reversed.content_hash != original.content_hash,"reverse direction has its own immutable content identity")
	check(TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc))).content_hash == reversed.content_hash,"start line survives exact JSON round trip")
	await screenshot("reverse")
	for track: NativeTrack in [original,reversed]:
		var config := HandlingConfig.new()
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn,track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		var session := TrackSession.new(120,5)
		var driver := RouteDriver.new()
		var frames: Array = []
		for tick: int in range(24000):
			var input: DriveFrame = driver.sample(sim.state,track,config)
			frames.append(input.packed())
			var previous: Vector2 = sim.state.position
			sim.step(input,track)
			session.advance(track,previous,sim.state.position,sim.state.route_index,sim.state.track_elevated)
			if session.finished: break
		check(session.finished and sim.state.collision_count==0 and session.shortcut_count==0,"five laps finish cleanly in each selected direction")
		var replay := VehicleSimulation.new(config)
		replay.reset(track.spawn,track.spawn_heading)
		for values: Array in JSON.parse_string(JSON.stringify(frames)):
			var input := DriveFrame.new()
			input.steer=values[0]; input.throttle=values[1]; input.brake=values[2]
			replay.step(input,track)
		check(replay.state.snapshot()==sim.state.snapshot(),"both start directions replay exactly")
	app.call("_undo")
	canvas = app.get("canvas")
	check(is_zero_approx(float(canvas.document.start_line.heading)),"undo restores forward direction")
	app.call("_redo")
	canvas = app.get("canvas")
	var center: Vector2 = canvas.start_controls().center
	canvas._begin(center,-1)
	canvas._move(canvas.to_screen(Vector2(12,-18)))
	canvas._end(-1)
	check(Vector2(canvas.document.start_line.position[0],canvas.document.start_line.position[1]).distance_to(Vector2(12,-18))<0.01,"dragging the line moves its position")
	check(is_equal_approx(float(canvas.document.start_line.heading),180.0),"dragging preserves reversed direction")
	check(TrackCompiler.compile(canvas.document).finish_center.distance_to(Vector2(12,-18))<0.2,"moved line updates actual finish")
	var saved: Dictionary = app.get("library").load_wip(doc.id)
	check(saved.start_line == JSON.parse_string(JSON.stringify(canvas.document.start_line)),"position and direction autosave")
	app.queue_free()
	await process_frame
	for name: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("START_LINE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func screenshot(stage: String) -> void:
	if not capture: return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../build/start-line-"+stage+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture saved: "+stage)
