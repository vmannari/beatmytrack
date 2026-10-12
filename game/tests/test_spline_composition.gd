extends SceneTree
## Reproduce the one-piece/multiple-piece kerb renderer transition.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func spline() -> Dictionary:
	var piece: Dictionary = RoadPieces.create("spline",Vector2(-42,-12),0.0,12.0)
	piece.spline_points = [[0.0,0.0],[42.0,-26.0],[39.0,29.0],[58.0,-7.0],[70.0,68.0]]
	return piece

func document(pieces: Array) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "spline_composition"; doc.name = "Spline with other roads"; doc.pieces = pieces
	return doc

func mesh_signature(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()): result.append(node.mesh.surface_get_arrays(surface))
	for child: Node in node.get_children(): result.append_array(mesh_signature(child))
	return result

func rendered_kerbs(native: NativeTrack) -> Array:
	var visual := NativeTrackVisual.new()
	root.add_child(visual)
	await visual._build_kerbs(native)
	var result: Array = mesh_signature(visual)
	visual.free()
	return result

func geometry_checks() -> void:
	var road: Dictionary = spline()
	var other: Dictionary = RoadPieces.create("straight",Vector2(60,55),0.0,12.0)
	var alone: Dictionary = document([road])
	var together: Dictionary = document([road,other])
	var first: NativeTrack = TrackCompiler.compile(alone)
	var second: NativeTrack = TrackCompiler.compile(together)
	check(first != null and second != null,"standalone and separate-road fixtures compile")
	check(first.kerbs.triangles == second.kerbs.triangles,"unrelated road leaves canonical spline kerbs identical")
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://../docs/evidence/spline-composition-2026-10-06/before/game/track/road_kerbs.gd").replace("\r\n","\n").replace("class_name RoadKerbs\n","")
	check(baseline.reload() == OK,"task-start physical kerb builder compiles")
	var original_contacts: RefCounted = baseline.new()
	original_contacts.call("build",second)
	check(original_contacts.get("triangles") == second.kerbs.triangles and original_contacts.get("blocked") == second.kerbs.blocked,"rendering fix preserves exact task-start physical kerb triangles and masks")
	var visual_triangles: Array[Dictionary] = await VisualRoadJoin.kerb_triangles(together)
	print("SPLINE_COMPOSITION_TRIANGLES canonical=",second.kerbs.triangles.size()," decorative=",visual_triangles.size())
	check(visual_triangles == second.kerbs.triangles,"multiple-piece renderer keeps exact clean spline triangles")
	check(await rendered_kerbs(first) == await rendered_kerbs(second),"adding a separate road preserves every rendered spline kerb vertex/normal/UV")
	var reordered: Dictionary = document([other,road])
	check(await VisualRoadJoin.kerb_triangles(reordered) == first.kerbs.triangles,"spline appearance is independent of piece order")
	var native_order: NativeTrack = TrackCompiler.compile(reordered)
	check(await rendered_kerbs(native_order) == await rendered_kerbs(first),"spline-last scene renders the same clean kerbs")
	# Connected mouths and mixed curved pieces use clean contour construction.
	var pose: Dictionary = RoadPieces.end_pose(road)
	for kind: String in ["straight","curve","hairpin","spline"]:
		var piece: Dictionary = RoadPieces.create(kind,pose.position,pose.heading,12.0)
		if kind in ["straight","hairpin"]: piece.length = 12.0 if kind == "straight" else 0.0
		var mixed: Dictionary = document([road,piece])
		var native: NativeTrack = TrackCompiler.compile(mixed)
		check(native != null,"connected "+kind+" fixture compiles")
		if native == null: continue
		var clean: Array[Dictionary] = await VisualRoadJoin.kerb_triangles(mixed)
		check(not clean.is_empty(),"connected "+kind+" retains visible smooth kerbs")
		var finite: bool = true
		for triangle: Dictionary in clean:
			for point: Vector2 in triangle.points: finite = finite and point.is_finite()
		check(finite,"all mixed-road kerb coordinates remain finite")
		check(mixed.pieces[0] == road,"adding "+kind+" preserves all five spline points and widths")
	# Crossing a straight road suppresses covered spline kerbs using the same
	# full-map exposure checks as contacts, rather than restoring old folds.
	var crossing: Dictionary = RoadPieces.create("straight",Vector2(-22,21),0.0,12.0)
	crossing.length = 64.0
	var crossed: Dictionary = document([road,crossing])
	var crossed_native: NativeTrack = TrackCompiler.compile(crossed)
	var crossed_visual: Array[Dictionary] = await VisualRoadJoin.kerb_triangles(crossed)
	check(crossed_visual == crossed_native.kerbs.triangles,"crossing another road uses the same exposed spline kerbs as contacts")
	check(crossed_visual.size() < first.kerbs.triangles.size(),"covered kerbs are removed at the actual crossing")

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"real editor finishes rebuilding the mixed-road scene")
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"save "+name)

func run() -> void:
	await geometry_checks()
	root.size = Vector2i(1280,720)
	folder = "user://spline_composition_test_"+TrackLibrary.unique_id()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/spline-composition-2026-10-06").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = document([spline()]); app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	app.canvas.fit(); app.canvas.zoom_by(1.35,app.canvas.to_screen(Vector2(3,-7)))
	await shot("one-spline")
	var original: Dictionary = app.document.pieces[0].duplicate(true)
	app.canvas.choose_piece("straight")
	app.canvas.snap_enabled = false; app.canvas.ghost.position = [60.0,55.0]; app.canvas.ghost.heading = 0.0
	app.canvas.confirm_piece()
	await settle()
	check(app.document.pieces.size() == 2 and app.document.pieces[0] == original,"placing an unrelated second block preserves authored spline")
	await shot("separate-road")
	app.call("_undo"); await settle(); await shot("undo-second-road")
	check(app.document.pieces.size() == 1,"undo returns to the one-spline scene")
	app.call("_redo"); await settle(); await shot("redo-second-road")
	check(app.document.pieces.size() == 2,"redo restores the mixed-road scene")
	app.call("_undo"); await settle()
	app.canvas.snap_enabled = true; app.canvas.choose_piece("straight"); app.canvas.ghost.length = 12.0; app.canvas.confirm_piece()
	await settle(); await shot("connected-road")
	check(app.document.pieces[0] == original,"connecting a second road preserves authored spline")
	root.size = Vector2i(960,540); await process_frame; app.canvas.fit(); await shot("connected-960x540")
	app.queue_free(); await process_frame
	cleanup(folder)
	print("SPLINE_COMPOSITION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
