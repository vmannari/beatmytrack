extends SceneTree
const OUT: String = "res://../docs/evidence/speed-bump-width-2026-10-12"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func document(width: float = 16.0, turn: float = 0.0) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-30,0).rotated(deg_to_rad(turn)),turn,width)
	road.length = 60.0
	doc.pieces = [road]
	doc.objects = [{"kind":"speed_bump","position":[0,1],"rotation":45}]
	return doc

func run() -> void:
	root.size = Vector2i(1280,720)
	var capture: bool = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for scale: float in [0.5,1.0,3.0]:
		var object: Dictionary = {"kind":"speed_bump","position":[0,0],"rotation":0,"scale":scale}
		check(CreatorObjects.size_of(object) == Vector2(2,8)*scale,"legacy scaled dimensions retained")
		for span: float in [0.5,3.0,8.0,16.0,40.0]:
			object["span"] = span
			check(CreatorObjects.size_of(object).x == 2.0*scale and CreatorObjects.size_of(object).y == span,"span changes transverse width only")
			check(is_equal_approx(SpeedBumps.height(Vector2.ZERO,[object]),SpeedBumps.HEIGHT*scale),"span never enlarges crown height")
			check(SpeedBumps.height(Vector2(0,span*0.5+0.01),[object]) == 0.0,"partial span has actual clear road outside")
			var doc: Dictionary = document(); doc.objects = [object]
			check(TrackDocument.validate(doc).is_empty(),"span validates and bounded object compiles")
	for bad: Variant in [0.0,0.49,40.01,"10",null]:
		var doc: Dictionary = document(); doc.objects[0]["span"] = bad
		check(not TrackDocument.validate(doc).is_empty(),"invalid span rejected")
	var invalid: Dictionary = document(); invalid.objects[0].kind = "jump"; invalid.objects[0]["span"] = 4.0
	check(not TrackDocument.validate(invalid).is_empty(),"span cannot be smuggled onto another object kind")
	for turn: float in [0.0,37.0,90.0,195.0]:
		for width: float in [6.0,10.0,16.0,20.0]:
			var doc: Dictionary = document(width,turn)
			var fitted: Dictionary = SpeedBumpEdit.fit_road(doc,doc.objects[0])
			check(not fitted.is_empty() and is_equal_approx(float(fitted.span),width),"fit reaches both rotated road edges")
			check(Vector2(fitted.position[0],fitted.position[1]).distance_to(Vector2.ZERO)<1.01,"fit centers bump on road")
			var travel: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(turn))
			var ends: PackedVector2Array = SpeedBumpEdit.endpoints(fitted)
			check(absf((ends[1]-ends[0]).normalized().dot(travel)) < 0.00001,"fit aligns bump across road")
			var old: Dictionary = fitted.duplicate(true); old["scale"] = 1.5
			var refit: Dictionary = SpeedBumpEdit.fit_road(doc,old)
			check(refit.scale == 1.5 and CreatorObjects.size_of(refit).x == 3.0,"fit preserves old crown and travel thickness")
			var short: Dictionary = SpeedBumpEdit.move_end(fitted,0,ends[0].lerp(ends[1],0.5))
			check(is_equal_approx(float(short.span),width*0.5) and SpeedBumpEdit.endpoints(short)[1].distance_to(ends[1]) < 0.00001,"one-end shortening anchors the opposite edge")
	var taper: Dictionary = document(); taper.pieces[0].kind = "taper"; taper.pieces[0]["narrow_width"] = 8.0
	var tapered: Dictionary = SpeedBumpEdit.fit_road(taper,taper.objects[0])
	check(float(tapered.span) > 8.0 and float(tapered.span) < 16.0,"fit uses actual width inside a taper")
	var offroad: Dictionary = document(); offroad.objects[0].position = [0,30]
	check(SpeedBumpEdit.fit_road(offroad,offroad.objects[0]).is_empty(),"fit refuses distant road snapping")
	var bridge: Dictionary = document(); bridge.pieces[0].kind = "bridge"
	check(SpeedBumpEdit.fit_road(bridge,bridge.objects[0]).is_empty(),"fit refuses elevated bridge-only authoring")
	for kind: String in ["curve","spline"]:
		var curved: Dictionary = document()
		curved.pieces = [RoadPieces.create(kind,Vector2(-10,-10),20,12)]
		var geometry: Dictionary = RoadPieces.section_geometry(curved.pieces,0)
		var point: Vector2 = geometry.points[geometry.points.size()/2]
		curved.objects[0].position = [point.x,point.y]
		var fitted: Dictionary = SpeedBumpEdit.fit_road(curved,curved.objects[0])
		check(not fitted.is_empty() and float(fitted.span) >= 6.0,"fit works on "+kind+" using actual road sections")
	var painted: Dictionary = TrackDocument.create_blank()
	painted.paint = [{"surface":0,"width":10.0,"shape":"square","points":[[-25,0],[25,0]]}]
	painted.objects = [{"kind":"speed_bump","position":[0,0],"rotation":0}]
	var painted_track: NativeTrack = TrackCompiler.compile(painted)
	painted_track.route = PackedVector2Array([Vector2(-25,0),Vector2(25,0)])
	var painted_fit: Dictionary = SpeedBumpEdit.fit_road(painted,painted.objects[0],painted_track)
	check(not painted_fit.is_empty() and absf(float(painted_fit.span)-10.0) <= painted_track.cell_size,"painted road fit uses its real ground edges")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var narrow: Dictionary = {"kind":"speed_bump","position":[0.0,0.0],"rotation":0.0,"span":3.0}
	var wide: Dictionary = narrow.duplicate(true); wide.span = 16.0
	for along: float in [-1.0,-0.75,-0.25,0.0,0.25,0.75,1.0]:
		check(is_equal_approx(SpeedBumps.height(Vector2(along,0),[narrow]),SpeedBumps.height(Vector2(along,0),[wide])),"crown profile identical across widths")
	check(SpeedBumps.contacts(Vector2(0,4),PI*0.5,config,[narrow]) == Vector4.ZERO,"car can take uncovered lane past partial bump")
	var narrow_doc: Dictionary = document(); narrow_doc.objects = [narrow]
	var wide_doc: Dictionary = document(); wide_doc.objects = [wide]
	var empty_doc: Dictionary = document(); empty_doc.objects = []
	var narrow_track: NativeTrack = TrackCompiler.compile(narrow_doc)
	var wide_track: NativeTrack = TrackCompiler.compile(wide_doc)
	var empty_track: NativeTrack = TrackCompiler.compile(empty_doc)
	var near := VehicleSimulation.new(config); var broad := VehicleSimulation.new(config)
	near.reset(Vector2(-5,0),PI*0.5); broad.reset(Vector2(-5,0),PI*0.5)
	near.state.velocity = Vector2(18,0); broad.state.velocity = Vector2(18,0)
	var bypass := VehicleSimulation.new(config); var plain := VehicleSimulation.new(config)
	bypass.reset(Vector2(-5,4),PI*0.5); plain.reset(Vector2(-5,4),PI*0.5)
	bypass.state.velocity = Vector2(18,0); plain.state.velocity = Vector2(18,0)
	var power := DriveFrame.new(); power.throttle = 255
	for tick: int in range(90):
		near.step(power,narrow_track); broad.step(power,wide_track)
		bypass.step(power,narrow_track); plain.step(power,empty_track)
		check(near.state.snapshot() == broad.state.snapshot(),"width preserves identical centre crossing behavior")
		check(bypass.state.position == plain.state.position and bypass.state.velocity == plain.state.velocity,"uncovered lane has no hidden bump slowdown")
	var restored_track: NativeTrack = TrackCompiler.compile(JSON.parse_string(JSON.stringify(narrow_doc)))
	if restored_track.content_hash != narrow_track.content_hash or restored_track.speed_bump_objects != narrow_track.speed_bump_objects: print("WIDTH_PIN_DIAGNOSTIC ",restored_track.content_hash," ",narrow_track.content_hash," original=",narrow_track.speed_bump_objects," restored=",restored_track.speed_bump_objects)
	check(restored_track.content_hash == narrow_track.content_hash and restored_track.speed_bump_objects == narrow_track.speed_bump_objects,"span survives JSON with exactly pinned identity")
	var world := Node3D.new(); root.add_child(world)
	HazardVisual.build(world,narrow); HazardVisual.build(world,wide)
	var first: MeshInstance3D = world.get_child(0); var second: MeshInstance3D = world.get_child(1)
	check(is_equal_approx(first.mesh.get_aabb().size.y,second.mesh.get_aabb().size.y) and is_equal_approx(first.mesh.get_aabb().size.x,second.mesh.get_aabb().size.x),"actual wide mesh preserves height and front-to-back size")
	check(is_equal_approx(first.mesh.get_aabb().size.z,3.0) and is_equal_approx(second.mesh.get_aabb().size.z,16.0),"actual meshes match independent width")
	world.queue_free(); await process_frame
	await editor(capture)
	print("SPEED_BUMP_WIDTH: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func button_text(node: Node, title: String) -> Button:
	for child: Node in node.get_children():
		if child is Button and child.text == title: return child
		var found: Button = button_text(child,title)
		if found != null: return found
	return null

func editor(capture: bool) -> void:
	var folder: String = "user://bump_width_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(folder)); app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app); await process_frame
	app.set("document",document()); app.call("_show_screen","create")
	await process_frame; await process_frame
	app.call("_editor_category","objects")
	app.canvas.mode = "objects"; app.canvas.selected_object = 0; app.call("_build_editor_tools")
	var fit: Button = button_text(app.editor_context,"Fit road")
	check(fit != null and button_text(app.editor_context,"Size +") == null and button_text(app.editor_context,"Width +") != null,"selected bump shows width actions and Fit road")
	fit.pressed.emit()
	check(is_equal_approx(float(app.document.objects[0].span),16.0) and CreatorObjects.size_of(app.document.objects[0]).x == 2.0,"actual Fit road button fills road without enlargement")
	if capture: await screenshot(app,"full-width.png")
	var whole: Dictionary = app.document.objects[0].duplicate(true)
	var ends: PackedVector2Array = SpeedBumpEdit.endpoints(whole)
	var canvas: EditorCanvas = app.canvas
	var history_count: int = app.history.size()
	# Real native touch route; the fixed end stays on the road's opposite edge.
	var touch := InputEventScreenTouch.new(); touch.index = 0; touch.pressed = true; touch.position = canvas.to_screen(ends[0]); canvas._gui_input(touch)
	for fraction: float in [0.2,0.4,0.6]:
		var drag := InputEventScreenDrag.new(); drag.index = 0; drag.position = canvas.to_screen(ends[0].lerp(ends[1],fraction)); canvas._gui_input(drag)
	touch.pressed = false; touch.position = canvas.to_screen(ends[0].lerp(ends[1],0.6)); canvas._gui_input(touch)
	check(is_equal_approx(float(app.document.objects[0].span),6.4),"touch end handle creates a partial-width bump")
	check(SpeedBumpEdit.endpoints(app.document.objects[0])[1].distance_to(ends[1]) < 0.00001,"touch resizing keeps opposite edge fixed")
	check(app.history.size() == history_count+1,"many touch samples make one undo operation")
	var partial: Dictionary = app.document.objects[0].duplicate(true)
	if capture: await screenshot(app,"partial-width.png")
	app.call("_undo"); check(app.document.objects[0] == whole,"one Undo restores full-width fit")
	app.call("_redo"); check(app.document.objects[0] == partial,"one Redo restores partial bump")
	canvas = app.canvas; canvas.mode = "objects"; canvas.selected_object = 0
	ends = SpeedBumpEdit.endpoints(partial)
	canvas._begin(canvas.to_screen(ends[0]),-1); canvas._move(canvas.to_screen(ends[0]-Vector2(0,1))); canvas._end(-1)
	check(not is_equal_approx(float(app.document.objects[0].span),float(partial.span)),"mouse end handle also edits span")
	canvas.selected_object = 0; canvas.mode = "objects"
	app.call("_resize_speed_bump",0.5)
	check(not app.document.objects[0].has("scale"),"Width buttons never add scale")
	var before_pinch: Dictionary = app.document.duplicate(true)
	ends = SpeedBumpEdit.endpoints(app.document.objects[0])
	canvas = app.canvas; canvas.selected_object = 0; canvas.mode = "objects"
	touch.pressed = true; touch.position = canvas.to_screen(ends[0]); canvas._gui_input(touch)
	var pinch_drag := InputEventScreenDrag.new(); pinch_drag.index = 0; pinch_drag.position = touch.position+Vector2(0,20); canvas._gui_input(pinch_drag)
	var other := InputEventScreenTouch.new(); other.index = 1; other.pressed = true; other.position = touch.position+Vector2(80,0); canvas._gui_input(other)
	check(app.document == before_pinch and canvas.bump_end_drag == -1,"second-finger navigation rolls back pending width edit")
	touch.pressed = false; canvas._gui_input(touch); other.pressed = false; canvas._gui_input(other)
	canvas.selected_object = 0; canvas.mode = "objects"
	var stored: Dictionary = app.document.objects[0].duplicate(true)
	var saved: Error = app.library.save_document(app.document)
	var loaded: Dictionary = app.library.load_document(app.document.id)
	if saved != OK or loaded.is_empty() or loaded.objects[0] != stored: print("WIDTH_SAVE_DIAGNOSTIC ",saved," ",app.library.last_error," stored=",stored," loaded=",loaded.get("objects",[]))
	check(saved == OK and not loaded.is_empty() and loaded.objects[0] == stored,"edited partial width saves and reloads exactly")
	app.call("_duplicate_object")
	check(app.document.objects.size()==2 and app.document.objects[1].span == stored.span,"Copy preserves partial width")
	app.canvas.selected_object = -1; app.call("_build_editor_tools")
	app.object_browser.category = "Props"; app.object_browser.choose("speed_bump"); app.object_browser.refresh()
	check(app.object_browser.details.find_child("ObjectSize",true,false) == null,"bump options remove uniform size presets")
	var slider: HSlider = app.object_browser.details.find_child("SpeedBumpWidth",true,false)
	check(slider != null and slider.step == 0.25,"new-placement width slider uses metre increments")
	slider.value = 3.0
	check(app.canvas.stamp_span == 3.0,"width option reaches actual placement tool")
	app.canvas._place(app.canvas.to_screen(Vector2(15,0)))
	check(app.document.objects[-1].span == 3.0 and not app.document.objects[-1].has("scale"),"new narrow placement has independent width")
	if capture:
		app.canvas.selected_object = -1; app.call("_build_editor_tools")
		app.object_browser._activate_asset("speed_bump")
		await screenshot(app,"width-options.png")
	app.queue_free(); await process_frame
	var files := DirAccess.open(folder)
	for file: String in files.get_files(): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)

func screenshot(app: Node, name_value: String) -> void:
	var expected: String = TrackCompiler.compile(app.document).content_hash
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.canvas.native_preview == null or app.canvas.native_preview.content_hash != expected or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.editor_world._building and app.canvas.native_preview.content_hash == expected,"actual resized object preview is ready")
	for i: int in range(6): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(name_value)))==OK,"capture "+name_value)
