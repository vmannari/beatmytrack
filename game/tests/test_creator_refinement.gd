extends SceneTree
var checks: int = 0
var failures: int = 0
var capture: bool = false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func run() -> void:
	capture = "--capture-refinement" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var config: HandlingConfig = load("res://resources/balanced.tres")
	for kind: String in ["tree","rock"]:
		var doc: Dictionary = TrackDocument.create_blank()
		doc.objects = [{"kind":kind,"position":[0,0],"rotation":0}]
		var track: NativeTrack = TrackCompiler.compile(doc)
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(0,-6))
		var drive := DriveFrame.new(); drive.throttle = 255
		for i: int in range(160): sim.step(drive,track)
		check(track.cell_at(Vector2.ZERO) == 4 and sim.state.collision_count > 0 and sim.state.position.y < -1,kind+" stops an approaching car")
	var road: Dictionary = TrackDocument.create_blank()
	var curve: Dictionary = RoadPieces.create("curve",Vector2(-24,-20))
	curve.length = 0.0
	curve.radius = 20.0
	for angle: float in [30.0,60.0,120.0,210.0]:
		curve.angle = angle
		var end: Dictionary = RoadPieces.end_pose(curve)
		check(RoadPieces.validate(curve).is_empty() and is_equal_approx(end.heading,angle),"curve accepts variable sweep "+str(angle))
		check(RoadPieces.samples(curve)[-1].distance_to(end.position)<0.001,"curve mesh and endpoint agree")
	curve.angle = 120.0
	road.pieces = [curve]
	var point: Vector2 = RoadPieces.samples(curve)[20]
	road.paint = [{"surface":2,"width":40.0,"shape":"round","points":[[point.x,point.y]],"protect_road":true}]
	var protected: NativeTrack = TrackCompiler.compile(road)
	check(protected.cell_at(point)==0 and protected.cells.count(2)>0,"sand paints around curve without covering asphalt")
	var erase: Dictionary = road.duplicate(true)
	var grass: Dictionary = road.paint[0].duplicate(true); grass.surface = 1
	erase.paint.append(grass)
	var erased: NativeTrack = TrackCompiler.compile(erase)
	check(erased.cell_at(point)==0 and erased.cells.count(2)==0,"Keep road permits erasing off-road sand without erasing asphalt")
	var visual := NativeTrackVisual.new()
	var mask: Image = visual._creator_overlay_mask(protected,road.paint)
	var cell := Vector2i(floori((point.x+protected.half_extent.x)/protected.cell_size),floori((protected.half_extent.y-point.y)/protected.cell_size))
	check(mask.get_pixelv(cell).r>0.5,"protected stroke preserves smooth road overlay")
	visual.free()
	road.paint[0].protect_road = false
	check(TrackCompiler.compile(road).cell_at(point)==2,"Paint all intentionally resurfaces a road")
	road.paint[0].protect_road = true
	var tyres: Dictionary = TrackDocument.create_blank()
	tyres.objects = [{"kind":"tyre_wall","position":[0,0],"rotation":0}]
	var tyre_track: NativeTrack = TrackCompiler.compile(tyres)
	check(tyre_track.cell_at(Vector2.ZERO)!=4 and tyre_track.tyre_origins.size()==6,"tyres are loose stacks instead of baked barriers")
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(0,-8))
	var frames: Array[DriveFrame] = []
	for i: int in range(360):
		var input := DriveFrame.new(); input.throttle = 255 if i<130 else 0
		frames.append(input)
		sim.step(input,tyre_track)
	var moved: int = 0
	for i: int in range(sim.state.loose_tyres.size()):
		var tyre: Array = sim.state.loose_tyres[i]
		if Vector2(tyre[0],tyre[1]).distance_to(tyre_track.tyre_origins[i])>0.5: moved+=1
	check(moved>0 and sim.state.collision_count>0,"car impact moves tyre stacks")
	print("LOOSE_TYRES moved=",moved," contacts=",sim.state.collision_count)
	var replay := VehicleSimulation.new(config)
	replay.reset(Vector2(0,-8))
	for input: DriveFrame in frames:
		var values: Array = JSON.parse_string(JSON.stringify(input.packed()))
		var decoded := DriveFrame.new(); decoded.steer=values[0]; decoded.throttle=values[1]; decoded.brake=values[2]
		replay.step(decoded,tyre_track)
	check(replay.state.snapshot()==sim.state.snapshot(),"tyre motion and car replay exactly from JSON inputs on the same track")
	sim.reset(Vector2(0,-8)); sim.step(DriveFrame.new(),tyre_track)
	check(Vector2(sim.state.loose_tyres[0][0],sim.state.loose_tyres[0][1])==tyre_track.tyre_origins[0],"restart restores tyre positions")
	var folder: String = "user://refinement_"+str(Time.get_ticks_usec())
	var library := TrackLibrary.new(folder)
	var invalid: Dictionary = TrackDocument.create_default()
	invalid.id = "incomplete"
	invalid.points[1] = invalid.points[0].duplicate()
	check(not TrackDocument.validate(invalid).is_empty() and library.save_document(invalid)==OK,"incomplete lap can be saved as a draft")
	check(library.load_document("incomplete").points==invalid.points,"incomplete draft reload preserves edits")
	var app: Node = load("res://core/app.gd").new()
	app.set("library",library)
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	app.set("document",road)
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	var canvas: EditorCanvas = app.get("canvas")
	canvas.mode = "road"; canvas.selected_piece = 0
	app.set("editor_geometry","angle"); app.call("_build_editor_tools")
	app.call("_change_piece","angle",5.0)
	check(canvas.document.pieces[0].angle==125.0,"angle toolbar edits the curve without changing radius")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/refinement-curve.png"))==OK,"curve controls screenshot")
	canvas.free_run = true; canvas.stamp_kind = "tyre_wall"
	var line: Array = canvas._object_run(Vector2(40,-50),Vector2(58,-50))
	check(line.size()==3 and line[0].position==[43.0,-50.0],"free tyre line is independent of roads and lap")
	var joined: Dictionary = TrackDocument.create_blank()
	joined.pieces = [RoadPieces.create("straight",Vector2.ZERO),RoadPieces.create("straight",Vector2(32,0))]
	app.set("document",joined); canvas.document=joined; canvas.selected_piece=0
	canvas.connect_nearby()
	check(RoadPieces.end_pose(joined.pieces[0]).position==Vector2(32,0) and joined.pieces[0].position==[0.0,0.0],"Connect closes a nearby gap while fixing the opposite end")
	app.call("_undo")
	canvas=app.get("canvas")
	check(RoadPieces.end_pose(canvas.document.pieces[0]).position==Vector2(28,0),"Connect is one undo operation")
	canvas.choose_piece("curve")
	app.call("_save_track_explicit")
	check(canvas.ghost.is_empty() and library.load_document(str(canvas.document.id)).pieces.size()==3,"explicit Save includes the pending road preview")
	for node: Node in app.find_children("*", "AcceptDialog", true, false):
		node.queue_free()
	await process_frame
	app.set("document",road); canvas.document=road
	var previous_document: Dictionary = road.duplicate(true)
	previous_document.pieces[0].angle = 90.0
	check(library.save_document(previous_document)==OK,"save original circuit before editing")
	app.set("selected_track",TrackCompiler.compile(previous_document))
	# WIP autosave no longer overwrites the saved original. This scenario races
	# the edited saved circuit, so use the current explicit Save action.
	app.call("_save_track_explicit")
	for node: Node in app.find_children("*", "AcceptDialog", true, false):
		node.queue_free()
	await process_frame
	var saved_expected: NativeTrack = TrackCompiler.compile(library.load_document(str(road.id)))
	check((app.get("selected_track") as NativeTrack).content_hash==saved_expected.content_hash,"Save refreshes the selected circuit without reselecting it")
	app.call("_show_screen","play")
	await process_frame
	var race_button: Button = app.get("root_ui").find_child("StartRace",true,false)
	race_button.pressed.emit()
	await process_frame
	var immediate_game: Node = app.get("game")
	check(immediate_game!=null and (immediate_game.get("native_track") as NativeTrack).content_hash==saved_expected.content_hash,"immediate Home Race uses saved geometry")
	app.call("_leave_race")
	app.call("_show_screen","create")
	await process_frame
	app.call("_open_saved_tracks")
	for i: int in range(40): await process_frame
	check(app.get("browser_state").section=="saved","My circuits opens the saved-only library")
	var catalog := TrackCatalog.new(library)
	catalog.add_local(str(road.id))
	var entry: Dictionary = catalog.entries[0]
	var loaded: NativeTrack = catalog.resolve(entry)
	check(loaded!=null and loaded.metadata.creator_document.pieces[0].angle==125.0,"saved local circuit resolves with authored geometry for driving")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/refinement-library.png"))==OK,"saved circuits screenshot")
	app.call("_start_race",loaded,false)
	await process_frame
	check(app.get("game")!=null,"saved local circuit starts an ordinary race")
	app.call("_leave_race")
	app.call("_start_race",tyre_track,true)
	await process_frame
	var game: Node = app.get("game")
	game.set_physics_process(false)
	var actual: VehicleSimulation = game.get("sim")
	actual.reset(Vector2(0,-8))
	for input: DriveFrame in frames: actual.step(input,tyre_track)
	game.set("previous_position",actual.state.position)
	game.set("previous_heading",actual.state.heading)
	for i: int in range(4): await process_frame
	var ground: NativeTrackVisual = game.get("track_ground")
	check(ground.tyre_instances.multimesh.instance_count==6,"tyre presentation contains one instance per stack")
	# Dummy headless rendering returns zero instance transforms; verify the GPU transform in CaptureRefinement.
	if capture:
		check(ground.tyre_instances.multimesh.instance_count==6 and ground.tyre_instances.multimesh.get_instance_transform(2).origin.distance_to(VisualGeometry.world(Vector2(actual.state.loose_tyres[2][0],actual.state.loose_tyres[2][1]))+Vector3.UP*0.014)<0.01,"rendered tyres follow actual simulation positions")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/refinement-tyres.png"))==OK,"displaced tyres screenshot")
		ground.update_tyres(VehicleState.new(),tyre_track.tyre_origins)
		var restored: bool = true
		for index: int in range(tyre_track.tyre_origins.size()):
			var expected := Transform3D(Basis.IDENTITY,VisualGeometry.world(tyre_track.tyre_origins[index])+Vector3.UP*0.014)
			restored = restored and ground.tyre_instances.multimesh.get_instance_transform(index).is_equal_approx(expected)
		check(restored,"cached tyre presentation restores every original transform on reset")
	app.call("_leave_race")
	app.queue_free()
	await process_frame
	var dir := DirAccess.open(folder)
	for file: String in dir.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("REFINEMENT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
