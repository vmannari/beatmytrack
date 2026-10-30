extends "res://tests/test_spline_barriers.gd"
# Original assertions; fill current capacity with valid low-cost objects.
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
		document.objects = []
		for fill: int in range(preload("res://editor/creator_limits.gd").MAX_OBJECTS-2): document.objects.append({"kind":"tyre_stack","position":[0.0,0.0],"rotation":0.0})
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

