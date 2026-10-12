extends SceneTree
## Tight S shapes reproduce the owner's folded borders; real editor captures.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func road(width: float = 12.0) -> Dictionary:
	var piece: Dictionary = RoadPieces.create("spline",Vector2(-42,-12),0,width)
	piece.spline_points = [[0.0,0.0],[42.0,-26.0],[39.0,29.0],[58.0,-7.0],[70.0,68.0]]
	return piece

func crossings(polygon: PackedVector2Array) -> int:
	var result: int = 0
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		for j: int in range(i+2,polygon.size()):
			if i == 0 and j == polygon.size()-1: continue
			var c: Vector2 = polygon[j]
			var d: Vector2 = polygon[(j+1)%polygon.size()]
			var hit: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
			if hit is Vector2 and minf(minf(hit.distance_to(a),hit.distance_to(b)),minf(hit.distance_to(c),hit.distance_to(d))) > 0.001: result += 1
	return result

func shape_checks() -> void:
	var piece: Dictionary = road()
	check(RoadPieces.validate(piece).is_empty(),"reference-like steep spline is valid authoring")
	check(crossings(RoadPieces.section_outline([piece],0)) > 0,"fixture reproduces crossed raw offset borders")
	var before: Dictionary = piece.duplicate(true)
	var started: int = Time.get_ticks_usec()
	var contours: Array[PackedVector2Array] = RoadEdges.section_contours([piece],0)
	print("SPLINE_BORDER_BUILD_MS ",(Time.get_ticks_usec()-started)/1000.0," vertices=",contours[0].size())
	check(piece == before,"border correction preserves all five points and widths")
	for polygon: PackedVector2Array in contours:
		check(crossings(polygon) == 0,"exposed border has no crossed edges")
		check(not Geometry2D.triangulate_polygon(polygon).is_empty(),"clean boundary can be triangulated")
	var doc: Dictionary = TrackDocument.create_blank(); doc.pieces = [piece]
	var segments: Array[Dictionary] = RoadKerbs.creator_segments(doc)
	check(segments.size() > 100,"steep spline keeps continuous physical curved kerbs instead of isolated tips")
	var folded_kerbs: int = 0
	for segment: Dictionary in segments:
		check(Vector2(segment.a).is_finite() and Vector2(segment.outer_a).is_finite(),"kerb edge is finite")
		check(Vector2(segment.a).distance_to(segment.b) <= 0.21,"kerbs follow closely sampled border")
		folded_kerbs += crossings(PackedVector2Array([segment.a,segment.b,segment.outer_b,segment.outer_a]))
	check(folded_kerbs == 0,"kerb strips do not fold across themselves on tight inward corners")
	# Tessellation respects holes rather than covering an enclosed grass island.
	var outer := PackedVector2Array([Vector2(-10,-10),Vector2(10,-10),Vector2(10,10),Vector2(-10,10)])
	var hole := PackedVector2Array([Vector2(-3,-3),Vector2(-3,3),Vector2(3,3),Vector2(3,-3)])
	var patches: Array[PackedVector2Array] = SplineBorders.surface([outer,hole])
	var covered: bool = false
	var area: float = 0.0
	for polygon: PackedVector2Array in patches:
		covered = covered or Geometry2D.is_point_in_polygon(Vector2.ZERO,polygon)
		for i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])*0.5
	check(not covered and absf(area-364.0)<0.001,"surface tessellation preserves real holes and road area")
	var loop: Dictionary = RoadPieces.create("spline",Vector2(-20,-20),0.0,8.0)
	loop.spline_points = [[0.0,0.0],[30.0,0.0],[30.0,30.0],[0.0,30.0],[0.0,2.0]]
	var loop_contours: Array[PackedVector2Array] = RoadEdges.section_contours([loop],0)
	var hole_count: int = 0
	for polygon: PackedVector2Array in loop_contours:
		if Geometry2D.is_polygon_clockwise(polygon): hole_count += 1
		check(crossings(polygon) == 0,"loop boundary remains simple")
	check(hole_count == 1,"overlapping return retains one genuine central island")
	covered = false
	for polygon: PackedVector2Array in SplineBorders.surface(loop_contours): covered = covered or Geometry2D.is_point_in_polygon(Vector2(-5,-5),polygon)
	check(not covered,"real spline island is not covered by the asphalt surface")
	# Joining remains open and shares the existing cross-section.
	var next: Dictionary = RoadPieces.create("straight",RoadPieces.end_pose(piece).position,RoadPieces.end_pose(piece).heading)
	var topology: Dictionary = RoadPieces.prepare_endpoints([piece,next])
	var cuts: Array[Dictionary] = RoadEdges._join_cuts([piece,next],0,topology)
	contours = RoadEdges.section_contours([piece,next],0,0.0,topology)
	var found: bool = false
	for polygon: PackedVector2Array in contours:
		for i: int in range(polygon.size()): found = found or RoadEdges._on_join_cut(polygon[i],polygon[(i+1)%polygon.size()],cuts)
	check(found,"joined spline mouth has no cap or crossing border")
	# Width changes and mirroring also retain simple borders.
	for flip: bool in [false,true]:
		piece.flip = flip
		piece.point_widths = [6.0,20.0,8.0,16.0,10.0]; piece.width = 20.0
		for polygon: PackedVector2Array in RoadEdges.section_contours([piece],0): check(crossings(polygon) == 0,"variable-width mirrored spline border is simple")

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"editor builds steep spline and kerbs")
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"save "+name)

func mesh_signature(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()): result.append([node.transform,node.mesh.surface_get_arrays(surface)])
	for child: Node in node.get_children(): result.append_array(mesh_signature(child))
	return result

func legacy_equivalence() -> void:
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://../docs/evidence/spline-borders-2026-10-06/before/game/track/native_track_visual.gd").replace("\r\n","\n").replace("class_name NativeTrackVisual\n","")
	check(baseline.reload() == OK,"task-start renderer snapshot compiles for equivalence")
	for theme: String in ["pine","desert","winter","night_city"]:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = theme
		doc.pieces = [RoadPieces.create("straight",Vector2(-28,0)),RoadPieces.create("curve",Vector2.ZERO),RoadPieces.create("hairpin",Vector2(10,-20)),RoadPieces.create("bridge",Vector2(-20,30))]
		var native: NativeTrack = TrackCompiler.compile(doc)
		var expected: Array = []
		for previous: bool in [true,false]:
			var visual: Node3D = baseline.new() if previous else NativeTrackVisual.new()
			visual.set("cache_road_meshes",false); visual.set("theme_id",theme); visual.set("colors",TrackTheme.palette(theme))
			root.add_child(visual)
			await visual.call("_build_creator_roads",native)
			if previous: expected = mesh_signature(visual)
			else: check(mesh_signature(visual) == expected,"legacy "+theme+" road meshes remain byte-identical to task-start renderer")
			visual.free()
		await process_frame

func run() -> void:
	print("SPLINE_BORDER_DEFAULT_GOLDEN ",TrackCompiler.compile(TrackDocument.create_default()).content_hash)
	shape_checks()
	await legacy_equivalence()
	root.size = Vector2i(1280,720)
	folder = "user://spline_border_test_"+TrackLibrary.unique_id()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/spline-borders-2026-10-06").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "steep_spline"; doc.name = "Smooth spline borders"; doc.pieces = [road()]
	app.document = doc; app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	app.canvas.fit(); app.canvas.selected_piece = -1; app.call("_build_editor_tools")
	await shot("steep-1280x720")
	app.canvas.zoom_by(1.7,app.canvas.to_screen(Vector2(3,-7)))
	await shot("bends-closeup")
	app.canvas.fit()
	app.canvas.selected_piece = 0; app.call("_build_editor_tools"); await shot("selected-1280x720")
	root.size = Vector2i(960,540); await process_frame; app.canvas.fit(); app.canvas.selected_piece = -1
	app.call("_build_editor_tools"); await shot("steep-960x540")
	app.queue_free(); await process_frame
	cleanup(folder)
	print("SPLINE_BORDER_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
