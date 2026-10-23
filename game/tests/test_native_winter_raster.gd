extends SceneTree
## NWR03/NWR04: independent scalar/native equality, cancellation and integration.
const ACCEL = preload("res://track/geometry_acceleration.gd")
const MASKS = preload("res://editor/creator_preview_masks.gd")
const ROADS = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var samples: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAILED ",label)

func raster_cases() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 978011
	for variant: int in range(60):
		var grid := Vector2i(87+variant%3,73)
		var step: float = [0.2,0.5,0.75][variant%3]
		var extent := Vector2(grid)*step*0.5
		var route := PackedVector2Array()
		var widths := PackedFloat32Array()
		for i: int in range(6):
			route.append(Vector2(rng.randf_range(-extent.x*1.2,extent.x*1.2),rng.randf_range(-extent.y*1.2,extent.y*1.2)))
			widths.append(rng.randf_range(0.01,12.0))
		if variant%5 == 0: route[1] = route[0]
		var expected := PackedInt32Array(); expected.resize(grid.x*grid.y)
		for i: int in range(expected.size()): expected[i] = i%7-1
		var mask: PackedInt32Array = expected.duplicate() if variant%2 == 0 else PackedInt32Array()
		var actual: PackedInt32Array = expected.duplicate(); var other_mask: PackedInt32Array = mask.duplicate()
		ACCEL.raster_enabled = false
		TrackCompiler._raster_road(route,widths,variant%3,expected,grid,extent,step,variant%2 == 0,mask)
		ACCEL.raster_enabled = true
		TrackCompiler._raster_road(route,widths,variant%3,actual,grid,extent,step,variant%2 == 0,other_mask)
		check(expected == actual,"raster varied widths/overlap/bounds "+str(variant))
		check(mask == other_mask,"road protection mask "+str(variant))
		var strokes: Array = []
		for i: int in range(4):
			strokes.append({"points":[[-12.13+i,-11.37],[14.16-i,12.01],[-8.25,9.31]],"surface":i%3,"width":3.33+i,"shape":"round" if i%2 == 0 else "square","mode":["free","line","area"][i%3],"protect_road":i%2 == 0})
		if mask.is_empty(): mask = expected.duplicate(); other_mask = mask.duplicate()
		ACCEL.raster_enabled = false; TrackCompiler._paint(strokes,expected,grid,extent,step,mask)
		ACCEL.raster_enabled = true; TrackCompiler._paint(strokes,actual,grid,extent,step,other_mask)
		check(expected == actual,"paint smoothed area/brush/protection "+str(variant))
		check(mask == other_mask,"paint mask ordering "+str(variant))
	var native: RefCounted = ACCEL.raster()
	var cells := PackedInt32Array(); cells.resize(256*256); cells.fill(1)
	var data: Dictionary = {"cells":cells,"mask":cells,"grid":Vector2i(256,256),"extent":Vector2(64,64),"cell_size":0.5,"route":PackedVector2Array([Vector2(-50,0),Vector2(50,0)]),"widths":PackedFloat32Array([8,12])}
	check(native.call("raster_road",data,Geometry2D,func() -> bool: return true).is_empty(),"road cancellation discards output")
	var calls: Dictionary = {"count":0}
	check(native.call("raster_paint",[{"points":PackedVector2Array([Vector2(-50,-50),Vector2(50,50)]),"width":50.0}],data,Geometry2D,func() -> bool:
		calls.count += 1
		return calls.count >= 2).is_empty() and calls.count >= 2,"paint cancellation during cell loop discards output")
	check(cells.count(1) == cells.size(),"cancelled kernels retain caller arrays")
	check(native.call("raster_road",{},Geometry2D,Callable()).is_empty(),"invalid grid rejected")
	check(native.call("raster_pixels",cells,PackedByteArray(),true).is_empty(),"invalid mask rejected")

func winter_rows() -> void:
	var visual := NativeTrackVisual.new()
	var points := PackedVector2Array([Vector2(-12.3,0),Vector2(0.7,0.2),Vector2(13.7,4),Vector2(21,12)])
	for i: int in range(60):
		var a := Vector2(-12.3+i*0.51,-5.1+i*0.13)
		var b: Vector2 = a+Vector2(0.4,0.16)
		var n: Vector2 = Vector2.UP.rotated(i*0.173)
		var original_cache: Dictionary = {"bridge_fade_start":i%3 == 0,"bridge_fade_end":i%4 == 0,"bridge_fade_length":35.8}
		var native_cache: Dictionary = original_cache.duplicate(true)
		ACCEL.winter_enabled = false
		var expected: Dictionary = visual._winter_bank_row(a,n,points,original_cache)
		ACCEL.winter_enabled = true
		var actual: Dictionary = visual._winter_bank_row(a,n,points,native_cache)
		check(expected == actual,"snow profile/normals/UVs/fade "+str(i))
		if expected != actual:
			for key: String in expected:
				if expected[key] != actual.get(key): print("ROW_DIFFERENCE ",key," expected=",expected[key]," actual=",actual.get(key)); break
		check(original_cache == native_cache,"piece-local row cache "+str(i))
		var scalar := SurfaceTool.new(); scalar.begin(Mesh.PRIMITIVE_TRIANGLES)
		var accelerated := SurfaceTool.new(); accelerated.begin(Mesh.PRIMITIVE_TRIANGLES)
		ACCEL.winter_enabled = false; visual._winter_bank_section(scalar,a,b,n,n,points,{})
		ACCEL.winter_enabled = true; visual._winter_bank_section(accelerated,a,b,n,n,points,{})
		check(scalar.commit_to_arrays() == accelerated.commit_to_arrays(),"snow section winding and every stream "+str(i))
	visual.free()

func fingerprint(track: NativeTrack) -> PackedByteArray:
	return var_to_bytes([track.metadata,track.cells,track.deck_cells,track.route,track.route_widths,track.route_radii,track.route_cut_radii,track.kerbs.triangles,track.kerbs.blocked,track.snow_banks.triangles,track.content_hash])

func packet(track: NativeTrack) -> Array:
	ROADS.entries.clear(); ROADS.bytes = 0; ROADS.account_gpu([]); NativeTrackVisual._road_mesh_cache.clear()
	var visual := NativeTrackVisual.new(); visual.theme_id = "winter"; visual.colors = TrackTheme.palette("winter")
	visual.cache_road_meshes = false; visual.persist_road_meshes = false; visual._capture_road_arrays = true
	await visual._build_creator_roads(track)
	var parts: Array = visual._prepared_road_parts
	visual.free()
	return parts

func integration() -> void:
	for fixture: String in ["star_spline_lap.json","knit_bridge_regression.json"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture))
		for theme: String in ["pine","winter","desert","storm","night_city"]:
			var document: Dictionary = source.duplicate(true); document.theme = theme
			document.paint = [{"points":[[-30,-20],[25,-20],[5,25]],"mode":"area","shape":"round","width":8,"surface":2,"protect_road":true},{"points":[[-25,12],[20,-3]],"mode":"line","shape":"square","width":5,"surface":1}]
			ACCEL.raster_enabled = false
			var began: int = Time.get_ticks_usec()
			var original: NativeTrack = TrackCompiler.compile(document)
			var original_ms: float = (Time.get_ticks_usec()-began)/1000.0
			ACCEL.raster_enabled = true; began = Time.get_ticks_usec()
			var actual: NativeTrack = TrackCompiler.compile(document)
			var native_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(original != null and actual != null,theme+" compiler valid "+fixture)
			if original == null or actual == null: continue
			check(fingerprint(original) == fingerprint(actual),theme+" full canonical compiler equality "+fixture)
			ACCEL.raster_enabled = false
			var overlay: PackedByteArray = MASKS.overlay(original,document.paint).get_data()
			var road: PackedByteArray = MASKS.road(original).get_data()
			ACCEL.raster_enabled = true
			check(overlay == MASKS.overlay(actual,document.paint).get_data(),theme+" RGB paint bytes "+fixture)
			check(road == MASKS.road(actual).get_data(),theme+" road mask bytes "+fixture)
			samples.append({"kernel":"compile","theme":theme,"fixture":fixture,"scalar_ms":original_ms,"native_ms":native_ms})
			if theme != "winter": continue
			ACCEL.winter_enabled = false; began = Time.get_ticks_usec()
			var markers: Array = WinterScenery.marker_sites(original)
			original_ms = (Time.get_ticks_usec()-began)/1000.0
			ACCEL.winter_enabled = true; began = Time.get_ticks_usec()
			var accelerated: Array = WinterScenery.marker_sites(actual)
			native_ms = (Time.get_ticks_usec()-began)/1000.0
			check(not markers.is_empty(),"Winter marker fixture nonempty "+fixture)
			check(markers == accelerated,"Winter marker order/spacing/bridge exclusion "+fixture)
			samples.append({"kernel":"markers","fixture":fixture,"scalar_ms":original_ms,"native_ms":native_ms})
			check(ACCEL.winter().call("winter_markers",actual.snow_banks.triangles,actual.route,actual.creator_bridges,func() -> bool: return true).is_empty(),"marker cancellation")
			ACCEL.winter_enabled = false; began = Time.get_ticks_usec()
			var before: Array = await packet(original)
			original_ms = (Time.get_ticks_usec()-began)/1000.0
			ACCEL.winter_enabled = true; began = Time.get_ticks_usec()
			var after: Array = await packet(actual)
			native_ms = (Time.get_ticks_usec()-began)/1000.0
			check(not before.is_empty(),"Winter road packet nonempty "+fixture)
			check(before == after,"complete Winter packet exact attributes/deposits "+fixture)
			samples.append({"kernel":"winter_roads","fixture":fixture,"scalar_ms":original_ms,"native_ms":native_ms})
			check(fingerprint(original) == fingerprint(actual),"Winter preparation preserves canonical data "+fixture)

func benchmark() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); document.theme = "winter"
	document.paint = [{"points":[[-30,-20],[25,-20],[5,25]],"mode":"area","shape":"round","width":8,"surface":2,"protect_road":true},{"points":[[-25,12],[20,-3]],"mode":"line","shape":"square","width":5,"surface":1}]
	var track: NativeTrack = TrackCompiler.compile(document)
	var expected_masks: PackedByteArray = MASKS.overlay(track,document.paint).get_data()+MASKS.road(track).get_data()
	# Warm both paths, then alternate order to reduce first-use/cache bias.
	for enabled: bool in [false,true]:
		ACCEL.raster_enabled = enabled; TrackCompiler.compile(document)
		ACCEL.winter_enabled = enabled; WinterScenery.marker_sites(track)
		await packet(track)
	for repetition: int in range(3):
		for enabled: bool in ([false,true] if repetition%2 == 0 else [true,false]):
			ACCEL.raster_enabled = enabled; ACCEL.winter_enabled = enabled
			var began: int = Time.get_ticks_usec(); var compiled: NativeTrack = TrackCompiler.compile(document)
			var compile_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(fingerprint(track) == fingerprint(compiled),"benchmark canonical equality")
			began = Time.get_ticks_usec(); var markers: Array = WinterScenery.marker_sites(track)
			var marker_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(not markers.is_empty(),"benchmark marker fixture")
			began = Time.get_ticks_usec(); var masks: PackedByteArray = MASKS.overlay(track,document.paint).get_data()+MASKS.road(track).get_data()
			var mask_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(masks == expected_masks,"benchmark mask equality")
			began = Time.get_ticks_usec(); var parts: Array = await packet(track)
			var road_ms: float = (Time.get_ticks_usec()-began)/1000.0
			check(not parts.is_empty(),"benchmark road fixture")
			samples.append({"native":enabled,"repetition":repetition,"compile_ms":compile_ms,"marker_ms":marker_ms,"mask_ms":mask_ms,"winter_road_ms":road_ms})

func fallback_contract() -> void:
	ACCEL.enabled = false
	check(ACCEL.winter() == null and ACCEL.raster() == null,"unsupported device feature fallback")
	var document: Dictionary = TrackDocument.create_default(); document.theme = "winter"
	var scalar: NativeTrack = TrackCompiler.compile(document)
	var mask: PackedByteArray = MASKS.overlay(scalar,[]).get_data()
	var markers: Array = WinterScenery.marker_sites(scalar)
	ACCEL.enabled = true
	var actual: NativeTrack = TrackCompiler.compile(document)
	check(fingerprint(scalar) == fingerprint(actual),"extension-disabled canonical fallback")
	check(mask == MASKS.overlay(actual,[]).get_data(),"extension-disabled mask fallback")
	check(markers == WinterScenery.marker_sites(actual),"extension-disabled marker fallback")

func run() -> void:
	check(ACCEL.winter() != null and ACCEL.raster() != null,"native features available")
	if ACCEL.winter() == null or ACCEL.raster() == null: quit(1); return
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark()
	else:
		raster_cases(); winter_rows(); fallback_contract()
		if failures == 0: await integration()
	ACCEL.winter_enabled = true; ACCEL.raster_enabled = true
	var output: String = ProjectSettings.globalize_path("res://../build/native-winter-raster/kernel-report.json")
	if "--benchmark" in OS.get_cmdline_user_args(): output = output.replace("kernel-report.json","benchmark-report.json")
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t")); file.close()
	for sample: Dictionary in samples: print("NATIVE_WINTER_RASTER_TIMING ",JSON.stringify(sample))
	print("NATIVE_WINTER_RASTER: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
