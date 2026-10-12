extends SceneTree
## Owner's tight spline fence fold: no intersections or solid rails on asphalt.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = ""
var before: bool = false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func road(width: float = 12.0) -> Dictionary:
	var piece: Dictionary = RoadPieces.create("spline",Vector2(-42,-12),0.0,width)
	piece.spline_points = [[0.0,0.0],[42.0,-26.0],[39.0,29.0],[58.0,-7.0],[70.0,68.0]]
	return piece

func endpoints(object: Dictionary) -> PackedVector2Array:
	var center := Vector2(object.position[0],object.position[1])
	var arm: Vector2 = Vector2.from_angle(deg_to_rad(float(object.rotation)))*CreatorObjects.size_of(object).x*0.5
	return PackedVector2Array([center-arm,center+arm])

func crossings(objects: Array) -> int:
	var count: int = 0
	for i: int in range(objects.size()):
		var a: PackedVector2Array = endpoints(objects[i])
		for j: int in range(i+2,objects.size()):
			var b: PackedVector2Array = endpoints(objects[j])
			var hit: Variant = Geometry2D.segment_intersects_segment(a[0],a[1],b[0],b[1])
			if hit is Vector2 and minf(minf(hit.distance_to(a[0]),hit.distance_to(a[1])),minf(hit.distance_to(b[0]),hit.distance_to(b[1]))) > 0.001: count += 1
	return count

func polygon_crossings(polygon: PackedVector2Array) -> int:
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

func taps(piece: Dictionary, side: float) -> PackedVector2Array:
	var geometry: Dictionary = SplineRoad.geometry(piece)
	var points: PackedVector2Array = geometry.points
	var a: Vector2 = (points[1]-points[0]).normalized()
	var b: Vector2 = (points[-1]-points[-2]).normalized()
	return PackedVector2Array([points[0]+Vector2(-a.y,a.x)*side*(float(geometry.widths[0])*0.5+1.5),points[-1]+Vector2(-b.y,b.x)*side*(float(geometry.widths[-1])*0.5+1.5)])

func run() -> void:
	before = OS.get_environment("BMT_SPLINE_BARRIERS_BEFORE") == "1"
	root.size = Vector2i(1280,720)
	var piece: Dictionary = road()
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "spline_fence_fold"; doc.name = "Steep spline fences"; doc.pieces = [piece]
	check(TrackDocument.validate(doc,false).is_empty(),"steep spline is a valid draft")
	var affected: float = 1.0
	var old: GDScript = GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/spline-barriers-2026-10-07/before/game/editor/road_pieces.gd").replace("\r\n","\n").replace("class_name RoadPieces\n","")
	check(old.reload() == OK,"task-start placement source loads")
	for side: float in [-1.0,1.0]:
		var ends: PackedVector2Array = taps(piece,side)
		var legacy: Array = old.barrier_run(doc,ends[0],ends[1],"fence")
		print("SPLINE_FENCE_BEFORE side=",side," sections=",legacy.size()," crossings=",crossings(legacy))
		if crossings(legacy)>0: affected = side
		if not before:
			var current: Array = RoadPieces.barrier_run(doc,ends[0],ends[1],"fence")
			check(not current.is_empty(),"steep spline side creates a fence")
			check(crossings(current) == 0,"steep spline fences cannot cross each other")
			var asphalt: Array[PackedVector2Array] = RoadEdges.section_contours([piece],0)
			var on_road: int = 0
			for object: Dictionary in current:
				var rail: PackedVector2Array = endpoints(object)
				for blend: float in [0.0,0.25,0.5,0.75,1.0]:
					var point: Vector2 = rail[0].lerp(rail[1],blend)
					var covered: int = 0
					for polygon: PackedVector2Array in asphalt:
						if Geometry2D.is_point_in_polygon(point,polygon): covered += -1 if Geometry2D.is_polygon_clockwise(polygon) else 1
					if covered > 0: on_road += 1
			print("SPLINE_FENCE_AFTER side=",side," sections=",current.size()," crossings=",crossings(current)," on_road=",on_road)
			check(on_road == 0,"no fitted fence segment crosses the actual spline asphalt")
	if not before: geometry_cases()
	if DisplayServer.get_name() != "headless":
		evidence = ProjectSettings.globalize_path("res://../docs/evidence/spline-barriers-2026-10-07/"+("before" if before else "after"))
		DirAccess.make_dir_recursive_absolute(evidence)
		await capture_editor(doc,piece,affected,old)
	print("SPLINE_BARRIERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func audit(objects: Array, contours: Array[PackedVector2Array], label: String) -> void:
	check(not objects.is_empty(),label+" keeps an exposed run")
	check(crossings(objects) == 0,label+" has no crossed rails")
	for i: int in range(objects.size()):
		var rail: PackedVector2Array = endpoints(objects[i])
		if i > 0: check(endpoints(objects[i-1])[1].distance_to(rail[0]) < 0.001,label+" keeps exact continuous endpoints")
		var tangent: Vector2 = (rail[1]-rail[0]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)*CreatorObjects.size_of(objects[i]).y*0.5
		var clear: bool = true
		for blend: float in [0.0,0.25,0.5,0.75,1.0]:
			for lateral: float in [-1.0,0.0,1.0]:
				var point: Vector2 = rail[0].lerp(rail[1],blend)+normal*lateral
				var covered: int = 0
				for polygon: PackedVector2Array in contours:
					if Geometry2D.is_point_in_polygon(point,polygon): covered += -1 if Geometry2D.is_polygon_clockwise(polygon) else 1
				if covered > 0:
					if clear: print("SPLINE_FENCE_ON_ROAD ",label," section=",i," point=",point)
					clear = false
		check(clear,label+" entire fence footprint stays off asphalt")

func geometry_cases() -> void:
	var fixtures: Array[Dictionary] = [road(),road(20.0),road(),road()]
	fixtures[2].flip = true
	fixtures[3].heading = 35.0; fixtures[3].point_widths = [6.0,20.0,8.0,16.0,12.0]; fixtures[3].width = 20.0
	var warm: Array[float] = []
	var first_build: Array[float] = []
	for variant: int in range(fixtures.size()):
		var piece: Dictionary = fixtures[variant]
		var document: Dictionary = TrackDocument.create_blank(); document.pieces = [piece]
		var contours: Array[PackedVector2Array] = RoadEdges.section_contours([piece],0)
		var unchanged: Dictionary = piece.duplicate(true)
		check(RoadPieces.validate(piece).is_empty(),"tight spline fixture remains valid")
		RoadsideBoundary._cache.clear()
		for kind: String in ["fence","guardrail","wire_fence","barrier"]:
			for scale: float in [0.75,1.5]:
				for side: float in [-1.0,1.0]:
					var ends: PackedVector2Array = taps(piece,side)
					var started: int = Time.get_ticks_usec()
					var run: Array = RoadPieces.barrier_run(document,ends[0],ends[1],kind,scale)
					if kind == "fence" and scale == 0.75 and side == -1.0: first_build.append(float(Time.get_ticks_usec()-started)/1000.0)
					audit(run,contours,"variant%d %s %.2f side%.0f" % [variant,kind,scale,side])
					document.objects = run
					check(TrackDocument.validate(document,false).is_empty(),"fitted spline run obeys saved contract")
					document.objects = []
					var reverse: Array = RoadPieces.barrier_run(document,ends[1],ends[0],kind,scale)
					check(not reverse.is_empty() and crossings(reverse) == 0,"reverse selection follows clean boundary")
					if not run.is_empty() and not reverse.is_empty():
						check(endpoints(run[0])[0].distance_to(endpoints(reverse[-1])[1]) < 0.01 and endpoints(run[-1])[1].distance_to(endpoints(reverse[0])[0]) < 0.01,"reversing taps reverses the same exposed perimeter arc")
		var ends: PackedVector2Array = taps(piece,1.0)
		var uncapped: Array = RoadPieces.barrier_run(document,ends[0],ends[1],"fence")
		document.objects.resize(94)
		var capped: Array = RoadPieces.barrier_run(document,ends[0],ends[1],"fence")
		check(capped.size() == 2 and capped == uncapped.slice(0,2),"object capacity preserves a continuous perimeter prefix")
		document.objects = []
		var started: int = Time.get_ticks_usec()
		var cached: Array = RoadPieces.barrier_run(document,ends[0],ends[1],"fence")
		warm.append(float(Time.get_ticks_usec()-started)/1000.0)
		RoadsideBoundary._cache.clear()
		var fresh: Array = RoadPieces.barrier_run(document,ends[0],ends[1],"fence")
		check(cached == fresh,"cached and fresh perimeter placement are identical")
		check(cached == uncapped,"repeat placement is deterministic")
		for polygon: PackedVector2Array in RoadsideBoundary._cache[-1].offsets[1.05]: check(polygon_crossings(polygon) == 0,"expanded fence perimeter is simple")
		check(piece == unchanged,"placement preserves all authored spline geometry")
		var route: Dictionary = RoadPieces._paths(document.pieces)[0]
		var sample: Dictionary = RoadPieces._at(route,RoadPieces._path_length(route)*0.36)
		var tap: Vector2 = Vector2(sample.point)+Vector2(-sample.tangent.y,sample.tangent.x)*(float(sample.width)*0.5+1.5)
		audit(RoadPieces.barrier_run(document,tap,tap,"fence"),contours,"coincident tap on tight spline")
	# A real closed sweep has an inner grass island; never bridge it to the exterior.
	var loop: Dictionary = RoadPieces.create("spline",Vector2(-20,-20),0.0,8.0)
	loop.spline_points = [[0.0,0.0],[40.0,0.0],[40.0,40.0],[0.0,40.0],[0.0,0.0]]
	var loop_doc: Dictionary = TrackDocument.create_blank(); loop_doc.pieces = [loop]
	var path: Dictionary = RoadPieces._paths(loop_doc.pieces)[0]
	var total: float = RoadPieces._path_length(path)
	var a: Dictionary = RoadPieces._at(path,total*0.15)
	var b: Dictionary = RoadPieces._at(path,total*0.65)
	var start: Vector2 = Vector2(a.point)+Vector2(-a.tangent.y,a.tangent.x)*5.5
	var finish: Vector2 = Vector2(b.point)+Vector2(-b.tangent.y,b.tangent.x)*5.5
	var island_run: Array = RoadPieces.barrier_run(loop_doc,start,finish,"fence")
	var canonical: Array[PackedVector2Array] = RoadEdges.section_contours([loop],0)
	check(canonical == RoadsideBoundary._cache[-1].road,"placement uses the same forced-knot sweep as rendered spline")
	audit(island_run,canonical,"inner grass island")
	var joined: Dictionary = TrackDocument.create_blank()
	var spline: Dictionary = road()
	var end: Dictionary = RoadPieces.end_pose(spline)
	var next: Dictionary = RoadPieces.create("straight",end.position,float(end.heading),12.0)
	next.length = 20.0
	joined.pieces = [spline,next]
	var joined_contours: Array[PackedVector2Array] = []
	var topology: Dictionary = RoadPieces.prepare_endpoints(joined.pieces)
	for i: int in range(2): joined_contours.append_array(RoadEdges.section_contours(joined.pieces,i,0.0,topology))
	for side: float in [-1.0,1.0]:
		var ends: PackedVector2Array = taps(spline,side)
		var pose: Dictionary = RoadPieces.end_pose(next)
		var forward := Vector2.from_angle(deg_to_rad(float(pose.heading)))
		var target: Vector2 = Vector2(pose.position)+Vector2(-forward.y,forward.x)*side*7.5
		audit(RoadPieces.barrier_run(joined,ends[0],target,"fence"),joined_contours,"spline-to-straight joined edge")
		# Opening the chain at its other end must not change exposure checks.
		joined.pieces.reverse()
		audit(RoadPieces.barrier_run(joined,target,ends[0],"fence"),joined_contours,"reversed connected edge")
		joined.pieces.reverse()
	check(RoadsideBoundary._cache.size() <= 4,"perimeter cache is bounded")
	print("SPLINE_FENCE_FIRST_BUILD_MS ",first_build)
	print("SPLINE_FENCE_WARM_MS ",warm)

func settle() -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec()+20000
	while (app.editor_preview_thread != null or app.editor_world._building or app.editor_world._visual_track == null or app.editor_world._visual_track.metadata.get("creator_document",{}).get("objects",[]) != app.document.objects) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"latest editor fence scenery completes")

func capture_editor(doc: Dictionary, piece: Dictionary, side: float, old: GDScript) -> void:
	var directory: String = "user://spline_barriers_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory); app.records = LocalRecords.new(directory.path_join("records.json")); app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = doc; app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	app.call("_editor_category","objects"); app.call("_choose_object","fence"); app.call("_object_placement","road edge")
	app.object_browser.current = "fence"; app.object_browser.category = "Barriers"; app.object_browser.refresh()
	var canvas: EditorCanvas = app.canvas
	var ends: PackedVector2Array = taps(piece,side)
	if before:
		canvas.run_preview = old.barrier_run(doc,ends[0],ends[1],"fence")
		canvas.drawing_run = true; canvas.active_pointer = -1; canvas._end(-1)
	else:
		canvas._place(canvas.to_screen(ends[0])); canvas._place(canvas.to_screen(ends[1]))
	await settle()
	if not before:
		var placed: Dictionary = app.document.duplicate(true)
		check(app.history.size() == 1,"spline perimeter run is one undo operation")
		check(app.library.load_wip(doc.id) == JSON.parse_string(JSON.stringify(placed)),"spline perimeter sections survive autosave")
		check(crossings(placed.objects) == 0,"actual editor gestures place no crossing fence")
		app.call("_undo"); await settle()
		check(app.document.objects.is_empty(),"Undo removes every fitted spline fence section")
		app.call("_redo"); await settle()
		check(app.document == placed,"Redo restores the exact clean spline run")
	canvas.fit()
	await shot("steep-spline-fence")
	canvas.zoom_by(1.8,canvas.to_screen(Vector2(7,-5)))
	await shot("steep-spline-fence-closeup")
	app.queue_free(); await process_frame

func shot(label: String) -> void:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"save actual editor "+label)
