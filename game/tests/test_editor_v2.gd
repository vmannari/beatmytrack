extends SceneTree
## Owner-requested sharp corners, per-node widths and mobile object gestures.

var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-editor="): capture_directory = arg.trim_prefix("--capture-editor=")
	var doc: Dictionary = TrackDocument.create_default()
	doc.name = "Switchback workshop"
	doc.points = [[-35,-25],[35,-25],[35,25],[-35,25]]
	doc.widths = [8.0,8.0,16.0,16.0]
	doc.corners = ["sharp","sharp","sharp","sharp"]
	doc.layout = TrackDocument.road_layout(doc)
	check(TrackDocument.validate(doc).is_empty(),"90-degree nodes with mixed widths are valid")
	var track: NativeTrack = TrackCompiler.compile(doc)
	var exact_corners: bool = true
	for p: Array in doc.points: exact_corners = exact_corners and track.route.has(Vector2(p[0],p[1]))
	check(exact_corners,"sharp vertices survive resampling exactly")
	check(track.cell_at(Vector2(0,-21.25)) == 0 and track.cell_at(Vector2(0,-19)) != 0,"8 m road has the requested footprint")
	check(track.cell_at(Vector2(0,32.5)) == 0 and track.cell_at(Vector2(0,34.5)) != 0,"16 m road has the requested footprint")
	var wider: Dictionary = doc.duplicate(true)
	wider.widths[0] = 14.0
	wider.layout = TrackDocument.road_layout(wider)
	var revised: NativeTrack = TrackCompiler.compile(wider)
	check(revised.content_hash != track.content_hash and revised.cells != track.cells,"one node width changes content and physical road")
	check(revised.cell_at(Vector2(0,32.5)) == track.cell_at(Vector2(0,32.5)),"distant segment retains its independent width")
	var legacy: Dictionary = TrackDocument.create_default()
	legacy.schema = "creator-track-v1"
	for field: String in ["widths","corners","objects"]: legacy.erase(field)
	check(not TrackDocument.validate(legacy).is_empty(),"old creator format is unsupported per owner request")
	for patch: Dictionary in [{"widths":[8]},{"corners":["sharp"]},{"objects":[{"kind":"res://bad.gd","position":[0,0],"rotation":0}]},{"objects":[{"kind":"tree","position":[NAN,0],"rotation":0}]},{"objects":[{"kind":"tree","position":[0,0],"rotation":INF}]},{"objects":[{"kind":"tree","position":[0,0],"rotation":0,"script":"bad"}]}]:
		var bad: Dictionary = doc.duplicate(true)
		bad.merge(patch,true)
		check(not TrackDocument.validate(bad).is_empty(),"hostile v2 property rejected: "+str(patch.keys()))
	var crossing: Dictionary = doc.duplicate(true)
	crossing.points = [[-35,-25],[35,25],[-35,25],[35,-25]]
	check(TrackDocument.validate(crossing).is_empty(),"at-grade route crossings are now supported")
	doc.objects = [{"kind":"barrier","position":[0,0],"rotation":0},{"kind":"tree","position":[-15,0],"rotation":0},{"kind":"rock","position":[15,0],"rotation":0},{"kind":"water","position":[0,25],"rotation":0},{"kind":"dirt","position":[0,-10],"rotation":45}]
	var stamped: NativeTrack = TrackCompiler.compile(doc)
	check(stamped.cell_at(Vector2.ZERO) == 4 and stamped.cell_at(Vector2(2,0)) == 4 and stamped.cell_at(Vector2(0,2)) != 4,"barrier cells match the long footprint")
	check(stamped.cell_at(Vector2(-15,0)) == 7 and stamped.cell_at(Vector2(15,0)) == 7,"trees and rocks use the native soft-obstacle surface")
	check(stamped.cell_at(Vector2(0,25)) == 0,"road is retained over an underlying pond stamp")
	check(stamped.cell_at(Vector2(0,-10)) == 2,"rotated dirt stamp reaches native surfaces")
	var turned: Dictionary = doc.duplicate(true)
	turned.objects[0].rotation = 90
	var turned_track: NativeTrack = TrackCompiler.compile(turned)
	check(turned_track.cell_at(Vector2(0,2)) == 4 and turned_track.cell_at(Vector2(2,0)) != 4,"rotating a barrier rotates collision footprint")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(0,-5),0)
	for i: int in range(500): sim.step(DriveFrame.sample(0,1,0),stamped)
	check(sim.state.collision_count > 0,"authored barrier participates in real vehicle collision")
	_drive_replay(track)
	await _ui(doc)
	print("EDITOR_V2_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _drive_replay(track: NativeTrack) -> void:
	var handling: HandlingConfig = load("res://resources/balanced.tres")
	var sim := VehicleSimulation.new(handling)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	var driver := RouteDriver.new()
	var session := TrackSession.new(120, 3)
	var inputs: Array = []
	for i: int in range(18000):
		var frame: DriveFrame = driver.sample(sim.state,track,handling)
		inputs.append([frame.steer,frame.throttle,frame.brake])
		var previous: Vector2 = sim.state.position
		sim.step(frame,track)
		session.advance(track,previous,sim.state.position,sim.state.route_index)
		if session.finished: break
	check(session.completed_laps == 3,"variable-width sharp-corner circuit completes three AI laps")
	print("SHARP_RACE laps=",session.completed_laps," times=",session.lap_times," contacts=",sim.state.collision_count," state=",sim.state.position," checkpoint=",session.next_checkpoint)
	var replay := VehicleSimulation.new(handling)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	var decoded: Array = JSON.parse_string(JSON.stringify(inputs))
	for batch: int in range(0,decoded.size(),8):
		for i: int in range(batch,mini(batch+8,decoded.size())):
			var frame := DriveFrame.new()
			frame.steer = int(decoded[i][0]); frame.throttle = int(decoded[i][1]); frame.brake = int(decoded[i][2])
			replay.step(frame,track)
	check(replay.state.snapshot() == sim.state.snapshot(),"sharp variable-width race replays exactly through JSON")

func _ui(doc: Dictionary) -> void:
	var folder: String = "user://editor_v2_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	(app.get("records") as LocalRecords).path = folder+"/records.json"
	root.add_child(app)
	app.set("document",doc.duplicate(true))
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	var canvas: EditorCanvas = app.get("canvas")
	canvas.mode = "move"
	var start: Vector2 = canvas.to_screen(Vector2(-35,-25))
	var down := InputEventScreenTouch.new()
	down.pressed = true; down.position = start+Vector2(10,0); down.index = 1
	canvas._gui_input(down)
	var old: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	down.pressed = false
	canvas._gui_input(down)
	check(app.get("document") == old and canvas.selected == 0,"selecting near a node does not move it or create undo history")
	app.call("_change_node_width",1.0)
	check((app.get("document") as Dictionary).widths == [9.0,8.0,16.0,16.0],"selected-node inspector edits only its own width")
	check(canvas.native_preview.cells == TrackCompiler.compile(app.get("document")).cells,"inspector edit refreshes exact native preview")
	canvas.mode = "add"
	down.position = canvas.to_screen(Vector2(0,-30)); down.pressed = true
	canvas._gui_input(down)
	down.pressed = false; canvas._gui_input(down)
	check(canvas.document.points.size() == 5 and canvas.document.widths.size() == 5 and canvas.document.corners[canvas.selected] == "sharp","adding a bend creates matched width and sharp-corner data")
	app.call("_set_start_node")
	check(canvas.document.points[0] == [0.0,-30.0] and canvas.document.widths[0] == 8.5,"setting start rotates all node properties together")
	app.call("_undo")
	app.call("_undo")
	app.call("_redo")
	check((app.get("document") as Dictionary).points.size() == 5,"redo restores added node properties")
	app.call("_undo")
	await process_frame
	canvas = app.get("canvas")
	canvas.selected = 0
	app.call("_build_editor_tools")
	await _capture("editor-v2-node")
	canvas.mode = "place"; canvas.stamp_kind = "tree"
	var count: int = (app.get("document") as Dictionary).objects.size()
	down.position = canvas.to_screen(Vector2(-20,10)); down.pressed = true
	canvas._gui_input(down)
	down.canceled = true
	canvas._gui_input(down)
	check((app.get("document") as Dictionary).objects.size() == count,"canceling a stamp creates no object")
	down.canceled = false; down.pressed = true
	canvas._gui_input(down)
	var second := InputEventScreenTouch.new()
	second.index = 2; second.position = down.position+Vector2(100,0); second.pressed = true
	canvas._gui_input(second)
	second.pressed = false; canvas._gui_input(second)
	down.pressed = false; canvas._gui_input(down)
	check((app.get("document") as Dictionary).objects.size() == count,"starting a pinch in stamp mode creates no object")
	down.pressed = true; canvas._gui_input(down)
	down.pressed = false; canvas._gui_input(down)
	check((app.get("document") as Dictionary).objects.size() == count+1,"single touch stamps one object on release")
	app.call("_rotate_object")
	check((app.get("document") as Dictionary).objects[-1].rotation == 45,"selected object rotates 45 degrees")
	app.call("_duplicate_object")
	check((app.get("document") as Dictionary).objects.size() == count+2,"copy adds an independently positioned object")
	app.call("_delete_selection")
	check((app.get("document") as Dictionary).objects.size() == count+1,"delete removes only selected object")
	canvas.mode = "objects"
	down.position = canvas.to_screen(Vector2(-20,10)); down.pressed = true
	canvas._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = down.index; drag.position = down.position+Vector2(20,0)
	canvas._gui_input(drag)
	down.pressed = false; canvas._gui_input(down)
	check(Vector2(canvas.document.objects[-1].position[0],canvas.document.objects[-1].position[1]).x > -20,"touch dragging moves selected object")
	await _capture("editor-v2-objects")
	app.call("_preview_document")
	await _capture("editor-v2-preview")
	var saved: Dictionary = (app.get("library") as TrackLibrary).load_document(doc.id)
	check(JSON.stringify(saved,"",true) == JSON.stringify(JSON.parse_string(JSON.stringify(app.get("document"))),"",true),"widths, corners, objects and transforms persist together")
	var local: TrackLibrary = app.get("library")
	check(local.export_document(saved,folder+"/export.json") == OK,"v2 object track exports")
	check(TrackCompiler.compile(local.import_document(folder+"/export.json")).content_hash == canvas.native_preview.content_hash,"v4 export/import retains exact physical identity")
	var exact: NativeTrack = TrackCompiler.compile(saved)
	check(exact.content_hash == canvas.native_preview.content_hash,"saved object track retains immutable compiled identity")
	app.queue_free()
	await process_frame
	var directory := DirAccess.open(folder)
	for file: String in directory.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)

func _capture(name: String) -> void:
	if capture_directory.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path: String = capture_directory.path_join(name+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"graphical evidence saved: "+name)
