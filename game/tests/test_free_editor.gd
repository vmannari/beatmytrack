extends SceneTree

var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-free-editor="): capture_directory = arg.trim_prefix("--capture-free-editor=")
	var doc: Dictionary = TrackDocument.create_default()
	var original: NativeTrack = TrackCompiler.compile(doc)
	var moved: Dictionary = doc.duplicate(true)
	moved.points[1][0] += 8
	var rerouted: NativeTrack = TrackCompiler.compile(moved)
	check(rerouted.cells == original.cells and rerouted.route != original.route,"route edits preserve the painted road")
	doc.paint = [stroke(0,30,[[0,0]],"square"),stroke(1,8,[[0,0]],"square"),stroke(2,8,[[-30,0],[30,0]]),stroke(3,8,[[20,15]]),stroke(4,4,[[-20,0],[-20,15]])]
	var painted: NativeTrack = TrackCompiler.compile(doc)
	check(painted.cell_at(Vector2(10,10)) == 0,"square brush creates an open paved area")
	check(painted.cell_at(Vector2(0,0)) == 2,"later strokes overwrite earlier surfaces")
	check(painted.cell_at(Vector2(0,3.5)) == 2 and painted.cell_at(Vector2(0,5)) == 0,"continuous road stroke has consistent width")
	check(painted.cell_at(Vector2(20,15)) == 3 and painted.cell_at(Vector2(-20,10)) == 4,"water and barrier strokes reach collision cells")
	var cut: Dictionary = doc.duplicate(true)
	cut.paint.append(stroke(1,4,[[0,0]],"square"))
	check(TrackCompiler.compile(cut).cell_at(Vector2.ZERO) == 1,"grass erases painted road to make an island")
	check(TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc))).content_hash == painted.content_hash,"painted document JSON round trip preserves identity")
	for patch: Dictionary in [{"paint":[stroke(99,10,[[0,0]])]},{"paint":[stroke(0,INF,[[0,0]])]},{"paint":[stroke(0,10,[[NAN,0]])]},{"paint":[stroke(0,10,[[0,0]],"script")]},{"base_track":"../bad"},{"layout":{"script":"run"}},{"route_override":"yes"}]:
		var bad: Dictionary = doc.duplicate(true)
		bad.merge(patch,true)
		check(not TrackDocument.validate(bad).is_empty(),"invalid free-map payload rejected: "+str(patch.keys()))
	for id: String in ["slicks_freeway_test","slicks_1way_test","slicks_66_test","slicks_offroad_test"]:
		var native: NativeTrack = NativeTrack.read("res://resources/tracks/"+id+".json")
		var remix: Dictionary = TrackDocument.from_builtin(native)
		check(TrackDocument.validate(remix).is_empty(),id+" opens as an editable remix: "+str(TrackDocument.validate(remix)))
		var compiled: NativeTrack = TrackCompiler.compile(remix)
		if compiled == null: continue
		check(compiled.cells == native.cells and compiled.deck_cells == native.deck_cells,id+" original ground and bridge layers retained exactly")
		check(compiled.route == native.route and compiled.checkpoints == native.checkpoints and compiled.finish_center == native.finish_center,id+" exact race route and gates retained")
		remix.paint.append(stroke(2,4,[[0,0]]))
		var revised: NativeTrack = TrackCompiler.compile(remix)
		check(revised.content_hash != compiled.content_hash and revised.deck_cells == compiled.deck_cells,id+" ground edits create a new identity without changing bridges")
	var eight: Dictionary = TrackDocument.create_default()
	eight.name = "Crossroads workshop"
	eight.points = [[-35,-25],[35,25],[45,0],[35,-25],[-35,25],[-45,0]]
	eight.widths = [12.0,12.0,12.0,12.0,12.0,12.0]
	eight.corners = ["sharp","sharp","sharp","sharp","sharp","sharp"]
	eight.layout = TrackDocument.road_layout(eight)
	check(TrackDocument.validate(eight).is_empty(),"figure-eight circuit allows a ground-level junction")
	_race(TrackCompiler.compile(eight))
	await _ui(eight)
	print("FREE_EDITOR_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func stroke(surface: int, width: float, points: Array, shape: String = "round") -> Dictionary:
	return {"surface":surface,"width":width,"points":points,"shape":shape}

func _race(track: NativeTrack) -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	var session := TrackSession.new(120,5)
	var driver := RouteDriver.new()
	var frames: Array = []
	for i: int in range(24000):
		var input: DriveFrame = driver.sample(sim.state,track,config)
		frames.append(input.packed())
		var before: Vector2 = sim.state.position
		sim.step(input,track)
		session.advance(track,before,sim.state.position,sim.state.route_index)
		if session.finished: break
	check(session.finished and session.completed_laps == 5,"figure-eight junction completes five ordered laps")
	print("FREE_EDITOR_RACE laps=",session.completed_laps," times=",session.lap_times," contacts=",sim.state.collision_count)
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new()
		input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		replay.step(input,track)
	check(replay.state.snapshot() == sim.state.snapshot(),"crossing race replays exactly")

func _ui(doc: Dictionary) -> void:
	var folder: String = "user://free_editor_tests_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	(app.get("records") as LocalRecords).path = folder+"/records.json"
	root.add_child(app)
	app.set("document",doc.duplicate(true))
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	var canvas: EditorCanvas = app.get("canvas")
	check(canvas.mode == "paint","creator opens in free painting mode")
	canvas.brush_surface = 2; canvas.brush_width = 8
	var touch := InputEventScreenTouch.new()
	touch.index = 1; touch.pressed = true; touch.position = canvas.to_screen(Vector2(-25,-5))
	canvas._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 1; drag.position = canvas.to_screen(Vector2(25,-5))
	canvas._gui_input(drag)
	check(canvas.document.paint.is_empty(),"brush gesture stays transient until release")
	touch.pressed = false; canvas._gui_input(touch)
	check(canvas.document.paint.size() == 1 and canvas.native_preview.cell_at(Vector2(0,-5)) == 2,"one finger paints a continuous physical stroke")
	check((app.get("history") as Array).size() == 1,"a full brush gesture creates one undo entry")
	app.call("_undo")
	check((app.get("document") as Dictionary).paint.is_empty(),"undo removes a complete stroke")
	app.call("_redo")
	await process_frame
	canvas = app.get("canvas")
	check(canvas.document.paint.size() == 1,"redo restores a complete stroke")
	touch.pressed = true; canvas._gui_input(touch)
	touch.canceled = true; canvas._gui_input(touch)
	check(canvas.document.paint.size() == 1 and canvas.paint_points.is_empty(),"canceled paint does not alter map")
	touch.canceled = false; touch.pressed = true; canvas._gui_input(touch)
	var second := InputEventScreenTouch.new()
	second.index = 2; second.pressed = true; second.position = touch.position+Vector2(100,0)
	canvas._gui_input(second)
	second.pressed = false; canvas._gui_input(second)
	touch.pressed = false; canvas._gui_input(touch)
	check(canvas.document.paint.size() == 1 and canvas.paint_points.is_empty(),"pinch cancels tentative painting")
	await _capture("free-editor-paint")
	canvas.mode = "move"
	app.call("_build_editor_tools")
	await _capture("free-editor-route")
	var library: TrackLibrary = app.get("library")
	check(library.export_document(canvas.document,folder+"/exchange.json") == OK,"free-painted map exports")
	check(TrackCompiler.compile(library.import_document(folder+"/exchange.json")).content_hash == canvas.native_preview.content_hash,"export/import preserves physical painted map")
	app.call("_preview_document")
	await _capture("free-editor-preview")
	app.call("_show_screen","tracks")
	await process_frame
	await process_frame
	var browser: TrackBrowser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	(browser.find_child("RemixTrack",true,false) as Button).pressed.emit()
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	check(canvas != null and canvas.document.base_track == "slicks_freeway_test","library Remix opens selected native circuit in free editor")
	check(canvas.native_preview.cells == NativeTrack.read("res://resources/tracks/slicks_freeway_test.json").cells,"Remix UI preserves native map geometry")
	# The preview dialog is owned by root app; close it before remix evidence.
	for child: Node in app.get_children():
		if child is Window: child.queue_free()
	await process_frame
	await _capture("free-editor-remix")
	app.queue_free()
	await process_frame
	var dir := DirAccess.open(folder)
	for file: String in dir.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)

func _capture(name: String) -> void:
	if capture_directory.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(name+".png")) == OK,"screenshot "+name)
