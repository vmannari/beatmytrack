extends SceneTree
## NRG01/NRG02: compare native road kernels with retained scalar algorithms.
const ACCEL = preload("res://track/geometry_acceleration.gd")
const ROADS = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var samples: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAILED ",label)

func compare(expected: Array, actual: Array, label: String) -> void:
	check(expected == actual,label+" exact streams")
	if expected == actual: return
	for slot: int in range(mini(expected.size(),actual.size())):
		if expected[slot] == actual[slot]: continue
		var a: Variant = expected[slot]
		var b: Variant = actual[slot]
		print("STREAM_DIFFERENCE ",label," slot=",slot," types=",typeof(a),"/",typeof(b))
		if a is PackedVector2Array or a is PackedVector3Array or a is PackedColorArray or a is PackedInt32Array:
			if b == null: continue
			print("sizes ",a.size(),"/",b.size())
			for i: int in range(mini(a.size(),b.size())):
				if a[i] != b[i]:
					print("first difference ",i," expected=",a[i]," actual=",b[i])
					break

func clear_cache() -> void:
	ROADS.entries.clear(); ROADS.bytes = 0; ROADS.account_gpu([])
	NativeTrackVisual._road_mesh_cache.clear()
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""

func edges(native: RefCounted) -> void:
	var visual := NativeTrackVisual.new()
	var pieces: Array = [RoadPieces.create("straight",Vector2(-28,0)),RoadPieces.create("straight",Vector2.ZERO,30.0)]
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		var polygon: PackedVector2Array = RoadPieces.section_outline(pieces,index,0.0,topology)
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		outlines.append({"index":index,"polygon":polygon,"bounds":bounds,"hole":false})
	for theme: String in ["pine","winter"]:
		visual.theme_id = theme
		for swept: bool in [false,true]:
			var contours: Array[PackedVector2Array] = [RoadPieces.section_outline(pieces,0,-0.2,topology)]
			var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,0,topology)
			ACCEL.roads_enabled = false
			var expected: PackedVector2Array = await visual._road_border_samples(contours,cuts,swept,pieces,0,outlines,topology)
			ACCEL.roads_enabled = true
			var actual: PackedVector2Array = await visual._road_border_samples(contours,cuts,swept,pieces,0,outlines,topology)
			check(expected == actual,theme+" joined edge samples, normals and exposure "+str(swept))
			contours[0].reverse()
			ACCEL.roads_enabled = false
			expected = await visual._road_border_samples(contours,[],true,pieces,0,outlines,topology)
			ACCEL.roads_enabled = true
			actual = await visual._road_border_samples(contours,[],true,pieces,0,outlines,topology)
			check(expected == actual,theme+" hole-contour edge samples "+str(swept))
			check(native.call("road_edges",contours,cuts,outlines,[],0,swept,theme == "winter",Geometry2D,func() -> bool: return true).is_empty(),"edge preparation cancellation")
	visual.free()

func clipping(native: RefCounted) -> void:
	for variant: int in range(4):
		var shoulder := ShoulderMesh.new()
		for i: int in range(30):
			var angle: float = i*0.19
			var a := Vector2(cos(angle)*5.0,sin(angle)*5.0)
			var b := Vector2(cos(angle+0.3)*5.0,sin(angle+0.3)*5.0)
			shoulder.add_quad(a,b,a*1.8,b*1.8)
		if variant == 1: shoulder.add_quad(Vector2(-8,0),Vector2(8,0),Vector2(-8,2),Vector2(8,2))
		if variant == 2:
			for triangle: Dictionary in shoulder.triangles:
				triangle.height_gradient = Vector2(0.003,-0.002); triangle.height_offset = 0.015
		if variant == 3: shoulder.add_quad(Vector2(-2,-1),Vector2(2,-0.999999),Vector2(-2,1),Vector2(2,1))
		var expected: Dictionary = shoulder._collect_range(0,shoulder.triangles.size())
		var actual: Dictionary = native.call("road_collect",shoulder.triangles,false,Geometry2D,Callable())
		check(expected == actual,"overlap clipping preserves order, ties and UVs "+str(variant))
		if expected != actual:
			compare([expected.get("points"),expected.get("uv")],[actual.get("points"),actual.get("uv")],"clipping "+str(variant))
		check(native.call("road_collect",shoulder.triangles,false,Geometry2D,func() -> bool: return true).is_empty(),"clipping cancels before output "+str(variant))
		var state: Dictionary = {"calls":0}
		var cancelled: Dictionary = native.call("road_collect",shoulder.triangles,false,Geometry2D,func() -> bool:
			state.calls += 1
			return state.calls >= 4)
		check(cancelled.is_empty() and state.calls >= 4,"clipping discards mid-job output "+str(variant))
	check(native.call("road_collect",[{}],false,Geometry2D,Callable()).is_empty(),"malformed clipping input rejected")
	check(native.call("road_finish",[],{},Callable()).is_empty(),"malformed mesh input rejected")

func packet(track: NativeTrack) -> Dictionary:
	var builder := NativeTrackVisual.new()
	builder.theme_id = track.metadata.get("theme","pine"); builder.colors = TrackTheme.palette(builder.theme_id)
	builder.cache_road_meshes = false; builder.persist_road_meshes = false; builder._capture_road_arrays = true
	await builder._build_creator_roads(track)
	var metadata: Dictionary = {}
	for name: String in ["winter_smooth_sections","winter_deposits","desert_clod_count","desert_bank_sections"]:
		if builder.has_meta(name): metadata[name] = builder.get_meta(name)
	var result: Dictionary = {"parts":builder._prepared_road_parts,"metadata":metadata}
	builder.free()
	return result

func packet_case(theme: String, fixture: String) -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture))
	document.theme = theme
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track != null,theme+" compiles")
	if track == null: return
	var canonical: PackedByteArray = var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route,track.kerbs.triangles])
	clear_cache(); ACCEL.roads_enabled = false
	var began: int = Time.get_ticks_usec()
	var expected: Dictionary = await packet(track)
	var scalar_ms: float = (Time.get_ticks_usec()-began)/1000.0
	clear_cache(); ACCEL.roads_enabled = true
	began = Time.get_ticks_usec()
	var actual: Dictionary = await packet(track)
	var native_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(not expected.get("parts",[]).is_empty(),theme+" scalar packet contains roads")
	check(expected.get("parts",[]).size() == actual.get("parts",[]).size(),theme+" native part count")
	for i: int in range(mini(expected.parts.size(),actual.parts.size())):
		check(expected.parts[i].role == actual.parts[i].role,theme+" part role "+str(i))
		compare(expected.parts[i].arrays,actual.parts[i].arrays,theme+" "+str(i))
	check(expected.metadata == actual.metadata,theme+" diagnostic geometry counts")
	check(canonical == var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route,track.kerbs.triangles]),theme+" canonical data unchanged")
	samples.append({"theme":theme,"fixture":fixture,"scalar_ms":scalar_ms,"native_ms":native_ms})
	print("NATIVE_ROAD_TIMING ",JSON.stringify(samples[-1]))

func run() -> void:
	var native: RefCounted = ACCEL.roads()
	check(native != null,"native road implementation available")
	if native == null: quit(1); return
	clipping(native)
	await edges(native)
	for theme: String in (["pine"] if "--pine-only" in OS.get_cmdline_user_args() else ["pine","desert","winter","storm","night_city"]):
		await packet_case(theme,"star_spline_lap.json")
	if not "--pine-only" in OS.get_cmdline_user_args(): await packet_case("desert","knit_bridge_regression.json")
	ACCEL.roads_enabled = true
	clear_cache()
	var folder: String = ProjectSettings.globalize_path("res://../build/native-road-loading")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("kernel-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); file.close()
	print("NATIVE_ROAD_GEOMETRY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
