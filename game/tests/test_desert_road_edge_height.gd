extends SceneTree

const RELIEF = preload("res://track/desert_road_relief.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var track := NativeTrack.new()
	track.metadata["theme"] = "desert"
	track.cell_size = 0.5
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(20,20)
	track.cells.resize(6400)
	track.cells.fill(2)
	track.deck_cells.resize(6400)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-10),Vector2(0,10)])
	# Four-metre-wide straight road, with its visible edge at x = 2 m.
	for y: int in range(80):
		for x: int in range(36,44): track.cells[y*80+x] = 0
	var original_cells := track.cells.duplicate()
	var relief = RELIEF.new(track)
	check(is_equal_approx(relief.height(Vector2.ZERO),-0.30),"road centre is recessed 30 cm")
	check(is_equal_approx(relief.height(Vector2(4,0)),0.0),"terrain returns to full height within two metres of road edge")
	check(relief.height(Vector2(3,0)) > -0.20,"terrain rises close to the road edge")
	check(track.cells == original_cells,"relief leaves canonical track cells unchanged")
	var bridge := BridgePresentation.new(track)
	check(is_equal_approx(bridge.visual_offset(Vector2.ZERO),relief.height(Vector2.ZERO)),"vehicle visual support follows road recess")
	check(is_zero_approx(bridge.height_at(Vector2.ZERO,0,0)),"canonical driving elevation is unchanged")
	var plane := PlaneMesh.new()
	plane.size = Vector2(12,12)
	var mesh: ArrayMesh = relief.deform(plane,Transform3D.IDENTITY,true)
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := INF
	var high := -INF
	for point: Vector3 in points:
		low = minf(low,point.y)
		high = maxf(high,point.y)
	check(absf(low+0.30) < 0.0001 and absf(high) < 0.0001,"actual refined mesh spans road and terrain elevations")
	check(relief.field.size()*4 <= RELIEF.MAX_FIELD_BYTES,"height field remains within its memory bound")
	print("DESERT_ROAD_EDGE_HEIGHT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
