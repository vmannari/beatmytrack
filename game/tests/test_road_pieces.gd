extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)


func run() -> void:
	_geometry()
	_roadside_visuals()
	_snapping()
	_contract()
	_compiler()
	_barriers()
	_wall_palette()
	_practice_start()
	print("ROAD_PIECES_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


func _geometry() -> void:
	for kind: String in RoadPieces.KINDS:
		var piece: Dictionary = RoadPieces.create(kind,Vector2(-20,-20))
		check(RoadPieces.validate(piece).is_empty(),kind+" default is valid")
		var points: PackedVector2Array = RoadPieces.samples(piece)
		check(points[0] == Vector2(-20,-20),kind+" starts exactly at anchor")
		check(points[-1] == RoadPieces.end_pose(piece).position,kind+" reports exact ending position")
		var gap: float = 0.0
		for i: int in range(1,points.size()): gap = maxf(gap,points[i].distance_to(points[i-1]))
		check(gap <= 0.751,kind+" road samples remain sub-metre")
		var mirrored: Dictionary = piece.duplicate(true)
		mirrored.flip = true
		var mirror_points: PackedVector2Array = RoadPieces.samples(mirrored)
		check(is_equal_approx(points[-1].x,mirror_points[-1].x) and is_equal_approx(points[-1].y+mirror_points[-1].y,-40.0),kind+" mirror preserves forward extent")
	var curve: Dictionary = RoadPieces.create("curve",Vector2.ZERO)
	curve.length = 0.0
	curve.radius = 20.0
	check(Vector2(RoadPieces.end_pose(curve).position).is_equal_approx(Vector2(20,20)),"quarter circle endpoint is analytic")
	check(is_equal_approx(float(RoadPieces.end_pose(curve).heading),90.0),"quarter circle exits at ninety degrees")
	curve.heading = 90.0
	check(Vector2(RoadPieces.end_pose(curve).position).is_equal_approx(Vector2(-20,20)),"rotation preserves curve geometry")


func _snapping() -> void:
	var base: Dictionary = RoadPieces.create("straight",Vector2(-30,-20),0.0,14.0)
	var next: Dictionary = RoadPieces.create("curve",Vector2(-1,-18),30.0,8.0)
	var result: Dictionary = RoadPieces.snap(next,[base])
	check(result.matched,"nearby piece snaps to a free endpoint")
	check(Vector2(result.piece.position[0],result.piece.position[1]).is_equal_approx(RoadPieces.end_pose(base).position),"snap aligns section start exactly")
	check(result.piece.width == 8.0 and result.piece.heading == 0.0,"snap matches tangent and preserves authored width")
	check(next.heading == 30.0 and next.width == 8.0,"snap does not mutate author input")
	var far: Dictionary = RoadPieces.create("straight",Vector2(60,60))
	check(not RoadPieces.snap(far,[base]).matched,"far sections remain freely placeable")
	check(RoadPieces.joins([base,result.piece]).size() == 2,"joined pair exposes exactly two open ends")
	check(not RoadPieces.snap(RoadPieces.create("straight",Vector2(-2,-20)),[base,result.piece]).matched,"occupied endpoints do not attract a third road section")
	check(not RoadPieces.connected_route([base,result.piece]).ok,"open road cannot silently become a racing loop")
	var tail: Dictionary = RoadPieces.create("straight",Vector2(-57,-21))
	var tail_snap: Dictionary = RoadPieces.snap(tail,[base])
	check(tail_snap.matched,"moving end can snap to another section start")
	check(Vector2(RoadPieces.end_pose(tail_snap.piece).position).is_equal_approx(Vector2(-30,-20)),"end snapping aligns exactly")
	var reverse: Dictionary = RoadPieces.create("straight",Vector2(-2,-20),180.0)
	var reverse_snap: Dictionary = RoadPieces.snap(reverse,[base],-1)
	check(reverse_snap.matched,"reverse endpoint placement aligns a continuous join")
	var first: Dictionary = RoadPieces.create("straight",Vector2.ZERO)
	var replacement: Dictionary = first.duplicate(true)
	check(not RoadPieces.snap(replacement,[first],0).matched,"selected piece does not snap to itself")


func _contract() -> void:
	var doc: Dictionary = TrackDocument.create_default()
	check(doc.schema == "creator-track-v5" and doc.pieces.is_empty(),"v5 defaults include independent road sections")
	for invalid: Variant in [null,[],{}, {"kind":"straight"}]:
		check(not RoadPieces.validate(invalid).is_empty(),"incomplete pieces rejected")
	for field: String in ["heading","length","radius","width"]:
		var piece: Dictionary = RoadPieces.create("curve",Vector2.ZERO)
		piece[field] = NAN
		check(not RoadPieces.validate(piece).is_empty(),field+" rejects nonfinite numbers")
	var outside: Dictionary = RoadPieces.create("straight",Vector2(110,0))
	check(not RoadPieces.validate(outside).is_empty(),"whole section geometry must stay within bounds")
	var hostile: Dictionary = RoadPieces.create("straight",Vector2.ZERO)
	hostile.script = "res://untrusted.gd"
	check(not RoadPieces.validate(hostile).is_empty(),"section rejects unsupported executable data")
	doc.pieces = [RoadPieces.create("straight",Vector2.ZERO)]
	check(TrackDocument.validate(doc).is_empty(),"open sections remain valid saveable drafts")
	doc.pieces.resize(97)
	check(not TrackDocument.validate(doc).is_empty(),"piece count bounded before compilation")
	doc = TrackDocument.create_default()
	doc.schema = "creator-track-v3"
	check(not TrackDocument.validate(doc).is_empty(),"legacy creator format explicitly unsupported")


func _loop() -> Array:
	var pieces: Array = []
	var position := Vector2(-20,-20)
	var heading: float = 0.0
	for index: int in range(4):
		var piece: Dictionary = RoadPieces.create("curve",position,heading)
		piece.length = 0.0
		piece.radius = 20.0
		pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	return pieces


func _compiler() -> void:
	var doc: Dictionary = TrackDocument.create_default()
	var golden: NativeTrack = TrackCompiler.compile(doc)
	check(golden != null and golden.grid_width == 228 and golden.grid_height == 188 and golden.route.size() == 219 and golden.cells.count(0) == 8715,"v4 default preserves established native geometry")
	print("CREATOR_V4_GOLDEN ",golden.content_hash)
	var isolated: Dictionary = TrackDocument.create_blank()
	var quarter: Dictionary = RoadPieces.create("curve",Vector2.ZERO,0.0,6.0)
	quarter.length = 0.0
	quarter.radius = 20.0
	isolated.pieces = [quarter]
	var open_road: NativeTrack = TrackCompiler.compile(isolated)
	check(open_road.cell_at(Vector2(10,10)) == 1,"an open curve does not acquire a phantom closing chord")
	doc.layout = {}
	doc.pieces = _loop()
	check(RoadPieces.joins(doc.pieces).is_empty(),"four quarter circles join into a closed road")
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	check(result.ok,"closed piece chain creates an independent lap route")
	if not result.ok: return
	doc = result.document
	check(doc.points.size() <= 96 and doc.points.size() >= 4,"derived route respects document limits")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"closed piece map compiles to native surface cells")
	if track == null: return
	var on_road: bool = true
	for point: Vector2 in track.route: on_road = on_road and track.cell_at(point) == 0
	check(on_road,"derived lap stays on compiled piece roads")
	_race(track)
	check(track.cell_at(Vector2(-20,0)) == 1,"closed road does not fill its inner island")
	var imported: Dictionary = JSON.parse_string(JSON.stringify(doc))
	var again: NativeTrack = TrackCompiler.compile(imported)
	check(again.content_hash == track.content_hash and again.cells == track.cells and again.route == track.route,"section JSON round trip is deterministic")
	var before: Array = doc.pieces.duplicate(true)
	doc.pieces[0].radius = 24.0
	check(doc.pieces[1] == before[1] and doc.pieces[2] == before[2],"local radius edit leaves distant section data untouched")
	check(not RoadPieces.joins(doc.pieces).is_empty(),"local edit exposes its disconnected endpoint")
	doc = result.document.duplicate(true)
	doc.pieces = _loop()
	doc.paint = [{"surface":0,"width":10.0,"shape":"square","points":[[-20,0]]}]
	var painted: NativeTrack = TrackCompiler.compile(doc)
	check(painted.cell_at(Vector2(-20,0)) == 0,"free paint can add roads away from road sections")
	doc.paint[0].surface = 3
	var water: NativeTrack = TrackCompiler.compile(doc)
	check(water.cell_at(Vector2(-20,0)) == 3,"terrain editing remains independent of route and pieces")
	doc.paint = []
	doc.pieces.append(RoadPieces.create("straight",Vector2(-45,0),0.0,8.0))
	var intersection: NativeTrack = TrackCompiler.compile(doc)
	check(intersection.cell_at(Vector2(-25,0)) == 0,"independent piece can form an at-grade intersection")
	check(intersection.route == track.route,"additional road geometry does not silently change lap route")


func _barriers() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	check(doc.layout.is_empty() and doc.pieces.is_empty() and TrackDocument.validate(doc).is_empty(),"blank creator is a saveable draft with no prepainted road")
	var straight: Dictionary = RoadPieces.create("straight",Vector2(-30,0))
	straight.length = 40.0
	doc.pieces = [straight]
	var run: Array = RoadPieces.barrier_run(doc,Vector2(-25,8),Vector2(5,8))
	check(run.size() >= 4,"two taps build a barrier run")
	var above: bool = true
	for object: Dictionary in run: above = above and float(object.position[1]) > 5.0
	check(above,"first tap chooses a consistent side outside the road")
	var below: Array = RoadPieces.barrier_run(doc,Vector2(-25,-8),Vector2(5,-8))
	check(not below.is_empty() and float(below[0].position[1]) < -5.0,"opposite side tap mirrors the road offset")
	var single: Array = RoadPieces.barrier_run(doc,Vector2(-25,8),Vector2(-25,8))
	check(single.size() == 1 and is_equal_approx(float(single[0].rotation),0.0) and float(single[0].position[1]) > 5.0,"coincident run taps create one aligned roadside barrier")
	var curve: Dictionary = RoadPieces.create("curve",Vector2(10,0))
	curve.length = 0.0
	curve.radius = 20.0
	doc.pieces.append(curve)
	var bends: Array = RoadPieces.barrier_run(doc,Vector2(0,-8),Vector2(38,20))
	check(bends.size() > 4,"barrier run traverses connected straight and bend")
	var turned: bool = false
	for object: Dictionary in bends: turned = turned or absf(float(object.rotation)) > 10.0
	check(turned,"barrier rotations follow local road tangent")
	doc.objects.resize(94)
	check(RoadPieces.barrier_run(doc,Vector2(0,-8),Vector2(38,20)).size() <= 2,"barrier runs respect the remaining object budget")


func _race(track: NativeTrack) -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var simulation := VehicleSimulation.new(config)
	simulation.reset(track.spawn,track.spawn_heading)
	simulation.state.route_index = track.nearest_route(track.spawn)
	var session := TrackSession.new(120,5)
	var driver := RouteDriver.new()
	var frames: Array = []
	for i: int in range(18000):
		var input: DriveFrame = driver.sample(simulation.state,track,config)
		frames.append(input.packed())
		var before: Vector2 = simulation.state.position
		simulation.step(input,track)
		session.advance(track,before,simulation.state.position,simulation.state.route_index)
		if session.finished: break
	check(session.finished and session.completed_laps == 5,"piece-derived circuit completes five ordered laps")
	print("ROAD_PIECES_RACE laps=",session.completed_laps," times=",session.lap_times," contacts=",simulation.state.collision_count)
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new()
		input.steer = int(values[0])
		input.throttle = int(values[1])
		input.brake = int(values[2])
		replay.step(input,track)
	check(replay.state.snapshot() == simulation.state.snapshot(),"five-lap piece circuit replays exactly")


func _wall_palette() -> void:
	for kind: String in ["tyre_wall","fence"]:
		var doc: Dictionary = TrackDocument.create_blank()
		doc.objects = [{"kind":kind,"position":[0.0,0.0],"rotation":0.0}]
		check(TrackDocument.validate(doc).is_empty(),kind+" is an allowed built-in object")
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track.overlaps_obstacle(Vector2.ZERO,0.1,false),kind+" has a physical blocking footprint")
		check(CreatorObjects.contains(doc.objects[0],Vector2(2.5,0.0)) and not CreatorObjects.contains(doc.objects[0],Vector2(0.0,2.5)),kind+" footprint matches its long axis")
		doc.objects[0].rotation = 90.0
		var rotated: NativeTrack = TrackCompiler.compile(doc)
		check(CreatorObjects.contains(doc.objects[0],Vector2(0.0,2.5)) and not CreatorObjects.contains(doc.objects[0],Vector2(2.5,0.0)),kind+" rotation turns its physical footprint")
		check(rotated.overlaps_obstacle(Vector2(0.0,2.5),0.1,false) and not rotated.overlaps_obstacle(Vector2(2.5,0.0),0.1,false),kind+" rotated footprint reaches physical collisions")


func _practice_start() -> void:
	var doc: Dictionary = TrackDocument.create_default()
	check(not doc.has("practice_start"),"practice start override is optional and absent from the default golden")
	var original: NativeTrack = TrackCompiler.compile(doc)
	doc["practice_start"] = {"position":[-20.0,10.0],"heading":135.0}
	check(TrackDocument.validate(doc).is_empty(),"finite bounded practice start validates")
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(doc))
	check(TrackDocument.validate(round_trip).is_empty() and round_trip.practice_start == doc.practice_start,"practice start survives creator JSON persistence")
	var compiled: NativeTrack = TrackCompiler.compile(round_trip)
	check(compiled.metadata.creator_document.practice_start == doc.practice_start,"compiled metadata retains practice start for editor preview")
	check(compiled.cells == original.cells and compiled.route == original.route and compiled.spawn == original.spawn and compiled.spawn_heading == original.spawn_heading,"practice start override preserves canonical map and timed-race start")
	for invalid: Variant in [null,[],{}, {"position":[0,0]}, {"position":[0,0],"heading":0,"script":"run"}, {"position":[0],"heading":0}, {"position":[NAN,0],"heading":0}, {"position":[0,110.1],"heading":0}, {"position":[0,0],"heading":INF}, {"position":[0,0],"heading":-1}, {"position":[0,0],"heading":360}]:
		doc.practice_start = invalid
		check(not TrackDocument.validate(doc).is_empty(),"invalid practice start rejected: "+str(invalid))
	var native: NativeTrack = NativeTrack.read("res://resources/tracks/slicks_freeway_test.json")
	check(not TrackDocument.from_builtin(native).has("practice_start"),"native remix preserves its original start until explicitly moved")


func _roadside_visuals() -> void:
	var cleanup := NativeTrackVisual.new()
	var rotated := PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(10.00001,0.00001),Vector2(10,4),Vector2(0,4)])
	for i: int in range(rotated.size()): rotated[i] = rotated[i].rotated(deg_to_rad(179.464))
	var clean: PackedVector2Array = cleanup.call("_clean_outline",rotated)
	check(clean.size() == 4,"microscopic offset edges on rotated straights are removed before extrusion")
	var stable: bool = true
	for i: int in range(clean.size()):
		var normal: Vector2 = cleanup.call("_edge_miter",clean,i)
		stable = stable and normal.is_finite() and normal.length() <= 2.0
	check(stable,"cleaned rotated outline produces bounded finite miters")
	cleanup.free()
	for radius: float in [8.0,16.0,30.0]:
		for flipped: bool in [false,true]:
			var document: Dictionary = TrackDocument.create_blank()
			var piece: Dictionary = RoadPieces.create("hairpin",Vector2(-30,0),0,6.0)
			piece.radius = radius
			piece.length = 0.0
			piece.flip = flipped
			document.pieces = [piece]
			var track: NativeTrack = TrackCompiler.compile(document)
			var original: PackedInt32Array = track.cells.duplicate()
			var visual := NativeTrackVisual.new()
			visual.colors = TrackTheme.palette("pine")
			visual.call("_build_creator_roads",track)
			var measured: bool = false
			var correct: bool = true
			var closed_seams: bool = true
			var upward: bool = true
			var bounded_runs: bool = true
			for node: Node in visual.get_children():
				var mesh: MeshInstance3D = node as MeshInstance3D
				var material: ShaderMaterial = mesh.material_override as ShaderMaterial
				var arrays: Array = mesh.mesh.surface_get_arrays(0)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for normal: Vector3 in normals: upward = upward and normal.distance_to(Vector3.UP) < 0.0001 # Packed mesh normals have quantization error.
				if not material.get_shader_parameter("kerb"): continue
				measured = true
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				for coordinate: Vector2 in uv:
					bounded_runs = bounded_runs and coordinate.y > 0.0 and coordinate.x >= -0.0001 and coordinate.x <= coordinate.y+0.0001
				var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null:
					indices = arrays[Mesh.ARRAY_INDEX]
				else:
					for vertex: int in range(vertices.size()): indices.append(vertex)
				var previous_end := PackedVector3Array()
				var previous_u: float = -1.0
				for i: int in range(0,indices.size(),6):
					var low: float = INF
					var high: float = -INF
					for j: int in range(6):
						low = minf(low,uv[indices[i+j]].x)
						high = maxf(high,uv[indices[i+j]].x)
					var start := PackedVector3Array()
					var end := PackedVector3Array()
					for j: int in range(6):
						var vertex: int = indices[i+j]
						if absf(uv[vertex].x-low) < 0.00001 and not start.has(vertices[vertex]): start.append(vertices[vertex])
						if absf(uv[vertex].x-high) < 0.00001 and not end.has(vertices[vertex]): end.append(vertices[vertex])
					if start.size() != 2 or end.size() != 2:
						correct = false
						continue
					var length: float = ((start[0]+start[1])*0.5).distance_to((end[0]+end[1])*0.5)
					correct = correct and absf(high-low-length) < 0.0001
					if absf(previous_u-low) < 0.0001:
						for vertex: Vector3 in start:
							closed_seams = closed_seams and minf(vertex.distance_to(previous_end[0]),vertex.distance_to(previous_end[1])) < 0.0001
					previous_u = high
					previous_end = end
			check(upward,"all road/grass/sand/paint triangles use upward normals")
			check(bounded_runs,"kerb coordinates restart per run and stay within the declared complete-block length")
			check(measured and correct,"kerb UVs measure physical midline metres at radius %s mirrored %s" % [radius,flipped])
			check(closed_seams,"kerb adjacent quads share inside and outside corners")
			check(track.cells == original,"roadside presentation preserves collision/surface cells")
			visual.free()
