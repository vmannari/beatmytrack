extends SceneTree
## Actual editor placements and captures, using isolated player storage.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func settle() -> void:
	await process_frame
	await process_frame
	var deadline: int = Time.get_ticks_msec()+20000
	while not settled() and Time.get_ticks_msec()<deadline: await process_frame
	check(settled(),"editor collision and scenery finish with latest objects")

func settled() -> bool:
	return app.editor_preview_thread == null and not app.editor_world._building and app.editor_world._visual_track != null and app.editor_world._visual_track.metadata.get("creator_document",{}).get("objects",[]) == app.document.objects

func fixture() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "continuous_fence"; doc.name = "Continuous roadside fences"; doc.theme = "pine"
	var position := Vector2(-45,-22)
	var heading: float = 0.0
	for kind: String in ["straight","curve","straight"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 40.0 if kind == "straight" else 0.0
		piece.radius = 20.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	doc["start_line"] = {"position":[-30,-22],"heading":0.0}
	return doc

func run() -> void:
	root.size = Vector2i(1280,720)
	var before: bool = OS.get_environment("BMT_BARRIERS_BEFORE") == "1"
	if DisplayServer.get_name() != "headless":
		evidence = ProjectSettings.globalize_path("res://../docs/evidence/continuous-barriers-2026-10-07/"+("before" if before else "after"))
		DirAccess.make_dir_recursive_absolute(evidence)
	var directory: String = "user://continuous_barriers_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	await process_frame
	app.document = fixture()
	check(TrackDocument.validate(app.document,false).is_empty(),"fixture is a valid editable document: "+str(TrackDocument.validate(app.document,false))+" keys="+str(app.document.keys()))
	app.canvas = null
	app.call("_show_screen","create")
	await process_frame
	await settle()
	app.call("_editor_category","objects")
	app.call("_choose_object","fence")
	app.call("_object_placement","road edge")
	app.object_browser.current = "fence"
	app.object_browser.category = "Barriers"
	app.object_browser.refresh()
	var canvas: EditorCanvas = app.canvas
	canvas.mode = "run"; canvas.free_run = false
	canvas.zoom = 0.82; canvas.pan = Vector2(5,-3)
	if before:
		var legacy := GDScript.new()
		legacy.source_code = FileAccess.get_file_as_string("res://../docs/evidence/continuous-barriers-2026-10-07/before/game/editor/road_pieces.gd").replace("class_name RoadPieces\n","").replace("class_name RoadPieces\r\n","")
		check(legacy.reload() == OK,"load archived placement source for before capture")
		canvas.run_preview = legacy.barrier_run(app.document,Vector2(-40,-31),Vector2(24,32),"fence")
		canvas.drawing_run = true
		canvas.active_pointer = -1
		canvas._end(-1)
	else:
		canvas._place(canvas.to_screen(Vector2(-40,-31)))
		canvas._place(canvas.to_screen(Vector2(24,32)))
	await settle()
	await capture("road-edge-fence")
	canvas.zoom = 1.8; canvas.pan = Vector2(-120,-200)
	await capture("road-edge-fence-bend")
	if not before:
		geometry_checks()
		await editor_checks()
	app.queue_free()
	await process_frame
	print("CONTINUOUS_BARRIERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(label: String) -> void:
	if evidence.is_empty(): return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"save actual editor "+label)

func editor_checks() -> void:
	check(not app.document.objects.is_empty(),"two taps place a roadside fence")
	var roadside: Dictionary = app.document.duplicate(true)
	check_run(roadside.objects,"editor Road edge")
	check(app.history.size() == 1,"whole roadside run is one undo operation")
	check(app.library.load_wip(roadside.id) == JSON.parse_string(JSON.stringify(roadside)),"fitted lengths survive real autosave")
	var track: NativeTrack = app.canvas.native_preview
	check(track != null,"roadside native collision preview exists")
	if track != null:
		for object: Dictionary in roadside.objects:
			var ends: PackedVector2Array = endpoints(object)
			for blend: float in [0.0,0.25,0.5,0.75,1.0]:
				check(track.overlaps_obstacle(ends[0].lerp(ends[1],blend),0.4,false),"compiled fence collision covers its visible path")
	app.call("_undo")
	await settle()
	check(app.document.objects.is_empty(),"Undo removes the complete fitted run")
	app.call("_redo")
	await settle()
	check(app.document == roadside,"Redo restores identical fitted fence and length data")
	for mode: String in ["line","curve"]:
		app.call("_undo")
		await settle()
		app.call("_choose_object","fence")
		app.call("_object_placement",mode)
		var canvas: EditorCanvas = app.canvas
		canvas.stamp_scale = 1.5
		canvas.zoom = 1.15; canvas.pan = Vector2.ZERO
		var gesture := PackedVector2Array([Vector2(-25,5),Vector2(-10,12),Vector2(5,15),Vector2(20,12),Vector2(35,5)]) if mode == "curve" else PackedVector2Array([Vector2(-25,5),Vector2(35,5)])
		canvas._begin(canvas.to_screen(gesture[0]),31)
		for i: int in range(1,gesture.size()): canvas._move(canvas.to_screen(gesture[i]))
		check(not canvas.run_preview.is_empty() and app.document.objects.is_empty(),mode+" gesture previews without committing")
		canvas._end(31)
		await settle()
		check_run(app.document.objects,"editor "+mode)
		check(app.history.size() == 1,mode+" commits one undo operation")
		check(endpoints(app.document.objects[0])[0].distance_to(gesture[0]) < 0.001 and endpoints(app.document.objects[-1])[1].distance_to(gesture[-1]) < 0.001,mode+" fits both chosen endpoints")
		for object: Dictionary in app.document.objects: check(is_equal_approx(CreatorObjects.size_of(object).y,0.75),mode+" applies size preset without varying thickness")
		await capture(mode+"-fence")
		app.library.save_wip(app.document)
		check(app.library.load_wip(app.document.id) == JSON.parse_string(JSON.stringify(app.document)),mode+" lengths survive save/reload")
	app.call("_undo")
	await settle()
	check(app.document.objects.is_empty(),"final undo removes all sections")

func endpoints(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var arm: Vector2 = Vector2.from_angle(deg_to_rad(float(object.rotation)))*CreatorObjects.size_of(object).x*0.5
	return PackedVector2Array([center-arm,center+arm])

func check_run(objects: Array, label: String) -> void:
	check(not objects.is_empty(),label+" produces sections")
	for i: int in range(objects.size()):
		check(objects[i].has("length"),label+" fits section length")
		if i > 0: check(endpoints(objects[i-1])[1].distance_to(endpoints(objects[i])[0]) < 0.001,label+" adjacent rails meet exactly")
		var ends: PackedVector2Array = endpoints(objects[i])
		for blend: float in [0.0,0.25,0.5,0.75,1.0]: check(CreatorObjects.contains(objects[i],ends[0].lerp(ends[1],blend)),label+" collision footprint covers rail")

func geometry_checks() -> void:
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-13,0),Vector2(14,0)]),PackedVector2Array([Vector2(-5,0),Vector2(-4.6,0)]),PackedVector2Array([Vector2(-8,0),Vector2.ZERO,Vector2(0,8)]),PackedVector2Array([Vector2.ZERO,Vector2(10,0),Vector2.ZERO])]
	var bend := PackedVector2Array()
	for i: int in range(33): bend.append(Vector2.from_angle(float(i)*PI/64.0)*24.0)
	paths.append(bend)
	for kind: String in ObjectRuns.CONTINUOUS:
		for scale: float in [0.75,1.0,1.5]:
			for path: PackedVector2Array in paths:
				var run: Array = ObjectRuns.build(path,kind,scale,96)
				check_run(run,kind+" "+str(scale))
				check(endpoints(run[0])[0].distance_to(path[0]) < 0.001 and endpoints(run[-1])[1].distance_to(path[-1]) < 0.001,"fitted run ends at selected endpoints")
				check(run == ObjectRuns.build(path,kind,scale,96),"run generation is deterministic")
				var doc: Dictionary = TrackDocument.create_blank(); doc.objects = run
				check(TrackDocument.validate(doc,false).is_empty(),"all fitted runs obey saved document contract")
				for object: Dictionary in run: check(is_equal_approx(CreatorObjects.size_of(object).y,CreatorObjects.dimensions(kind).y*scale),"fitted length preserves selected thickness")
			var doc: Dictionary = fixture()
			for side: float in [-1.0,1.0]:
				var roadside: Array = RoadPieces.barrier_run(doc,Vector2(-40,-22+side*9),Vector2(15+side*9,32),kind,scale)
				check_run(roadside,kind+" road edge "+str(side))
				var road: Dictionary = RoadPieces._paths(doc.pieces)[0]
				for object: Dictionary in roadside:
					var nearest: Dictionary = RoadPieces._nearest(road,Vector2(object.position[0],object.position[1]))
					var sample: Dictionary = RoadPieces._at(road,float(nearest.along))
					check(float(nearest.distance) >= float(sample.width)*0.5+CreatorObjects.size_of(object).y*0.5+0.6,"fitted roadside section stays outside the driving lane")
				check(RoadPieces.barrier_run(doc,Vector2(15+side*9,32),Vector2(-40,-22+side*9),kind,scale).size() > 1,"reversed road-edge run remains usable")
	check(ObjectRuns.build(paths[0],"fence",1.0,2).size() == 2,"remaining object budget truncates a continuous prefix")
	check(ObjectRuns.build(paths[0],"fence",1.0,0).is_empty(),"full object budget produces no sections")
	check(ObjectRuns.build(PackedVector2Array([Vector2.ZERO,Vector2.ZERO]),"fence",1.0,96).is_empty(),"zero-length free run creates no degenerate mesh")
	var tyres: Array = ObjectRuns.build(PackedVector2Array([Vector2(40,-50),Vector2(58,-50)]),"tyre_wall",1.5,96)
	check(tyres.size() == 3 and tyres[0].position == [43.0,-50.0] and not tyres[0].has("length") and not tyres[0].has("scale"),"loose tyre runs keep physical sizes and existing spacing")
	var invalid: Dictionary = TrackDocument.create_blank()
	invalid.objects = [{"kind":"tree","position":[0,0],"rotation":0.0,"length":2.0}]
	check(not TrackDocument.validate(invalid,false).is_empty(),"length is rejected on unrelated objects")
	for value: float in [-1.0,0.0,19.0,INF]:
		invalid.objects[0].kind = "fence"; invalid.objects[0].length = value
		check(not TrackDocument.validate(invalid,false).is_empty(),"invalid section length rejects: "+str(value))
	var dense := PackedVector2Array()
	for i: int in range(512): dense.append(Vector2(-80.0+float(i)*0.3,sin(float(i)*0.025)*12.0))
	var started: int = Time.get_ticks_usec()
	var stress: Array = ObjectRuns.build(ObjectRuns.smooth(dense),"fence",1.0,96)
	print("BARRIER_DENSE_CURVE points=512 sections=",stress.size()," elapsed_ms=",float(Time.get_ticks_usec()-started)/1000.0)
	check_run(stress,"dense curve")
	# Runtime mesh extents must match saved collision lengths and unchanged height.
	var kit := NativeTrackVisual.new()
	for kind: String in ObjectRuns.CONTINUOUS:
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		check(CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1.5,0.0,2.25),"fitted wall uses shared runtime mesh")
		tool.generate_normals()
		var bounds: AABB = tool.commit().get_aabb()
		check(absf(bounds.size.x-2.25) < 0.31,"visual section length matches collision extent")
		check(bounds.size.y > 1.2,"shortening section preserves fence/barrier height")
	kit.free()
	var native_doc: Dictionary = TrackDocument.create_blank()
	native_doc.id = "continuous_barrier_native"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		native_doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	native_doc = RoadPieces.route_from_pieces(native_doc).document
	native_doc["start_line"] = {"position":[0,-18],"heading":0.0}
	native_doc.objects = RoadPieces.barrier_run(native_doc,Vector2(-24,-28),Vector2(35,18),"fence")
	check(TrackDocument.validate(native_doc).is_empty() and not native_doc.objects.is_empty(),"native verification fixture has a complete lap and fitted fence")
	var output := FileAccess.open("res://../build/continuous-barriers-native-document.json",FileAccess.WRITE)
	check(output != null,"native verification fixture can be exported")
	if output != null: output.store_string(JSON.stringify(native_doc)); output.close()
