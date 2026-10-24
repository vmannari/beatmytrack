extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func reference(name: String, declaration: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f01_f03_before/"+name+".gd.txt").replace("\r\n","\n").replace("class_name "+declaration+"\n","")
	check(script.reload() == OK,"original reference compiles: "+name)
	return script
func grid_track(cells: PackedInt32Array, width: int = 64) -> NativeTrack:
	var track := NativeTrack.new()
	track.grid_width = width; track.grid_height = width; track.cell_size = 0.5
	track.half_extent = Vector2.ONE*float(width)*0.25
	track.cells = cells
	return track
func run() -> void:
	var old_compiler: GDScript = reference("track_compiler","TrackCompiler")
	var old_kerbs: GDScript = reference("road_kerbs","RoadKerbs")
	var acceleration = preload("res://track/geometry_acceleration.gd")
	var original_native: bool = acceleration.raster_enabled
	for mode: String in ["free","line","area"]:
		for shape: String in ["round","square"]:
			for protected: bool in [false,true]:
				var strokes: Array = []
				for surface: int in range(8):
					var points: Array = [[-10.25+surface*0.25,-8],[9,7],[5,10.25]]
					if mode == "area": points = [[-10,-8],[9,-8],[9,8],[-10,8]]
					strokes.append({"surface":surface,"width":float(surface+1),"shape":shape,"mode":mode,"protect_road":protected if surface%2 == 0 else not protected,"points":points})
				strokes.append(strokes[-1].duplicate(true))
				var initial := PackedInt32Array(); initial.resize(64*64); initial.fill(1)
				for y: int in range(64):
					for x: int in range(29,35): initial[y*64+x] = 0
				var expected: PackedInt32Array = initial.duplicate()
				var expected_road: PackedInt32Array = initial.duplicate()
				acceleration.raster_enabled = false
				old_compiler._paint(strokes,expected,Vector2i(64,64),Vector2(16,16),0.5,expected_road)
				var expected_mask: PackedByteArray = old_kerbs.exclusion_mask(grid_track(expected),strokes)
				for native: bool in [false,true]:
					acceleration.raster_enabled = native
					var actual: PackedInt32Array = initial.duplicate()
					var actual_road: PackedInt32Array = initial.duplicate()
					var mask: PackedByteArray = TrackCompiler._paint(strokes,actual,Vector2i(64,64),Vector2(16,16),0.5,actual_road)
					check(actual == expected and actual_road == expected_road,"ordered paint/protection exact: "+mode+shape+str(protected)+str(native))
					for index: int in range(actual.size()):
						if actual[index] in [4,7]: mask[index] = 1
					check(mask == expected_mask,"reused exclusion matches original coverage: "+mode+shape+str(protected)+str(native))
	var initial := PackedInt32Array(); initial.resize(4096); initial.fill(1)
	var cancelled: Array[int] = [0]
	var paint: Array = [{"surface":2,"width":40.0,"shape":"round","points":[[-16,-16],[16,16]],"mode":"free"}]
	var mask: PackedByteArray = RoadKerbs.exclusion_mask(grid_track(initial),paint,func() -> bool: cancelled[0] += 1; return cancelled[0] >= 25)
	check(mask.is_empty() and cancelled[0] == 25,"fallback cancellation is observed inside exclusion rows")
	for native: bool in [false,true]:
		acceleration.raster_enabled = native
		cancelled[0] = 0
		var cells: PackedInt32Array = initial.duplicate(); var road: PackedInt32Array = initial.duplicate()
		mask = TrackCompiler._paint(paint,cells,Vector2i(64,64),Vector2(16,16),0.5,road,func() -> bool: cancelled[0] += 1; return cancelled[0] >= 2)
		check(mask.is_empty(),"cancelled paint never publishes a prepared exclusion mask: "+str(native))
	acceleration.raster_enabled = original_native
	var doc: Dictionary = TrackDocument.create_default()
	var points: Array = []
	for index: int in range(512): points.append([-110,-110] if index%2 == 0 else [110,110])
	var stroke: Dictionary = {"surface":1,"width":40.0,"shape":"round","mode":"free","points":points}
	for index: int in range(32): doc.paint.append(stroke.duplicate(true))
	check(TrackDocument.validate(doc).is_empty(),"stress case respects 512 points/stroke and 16384 total points")
	var start: int = Time.get_ticks_usec()
	var compiled: NativeTrack = TrackCompiler.compile(doc)
	var stress_us: int = Time.get_ticks_usec()-start
	check(compiled != null,"maximum repeated-paint document completes")
	var reduced: Dictionary = doc.duplicate(true)
	reduced.paint = [stroke.duplicate(true)]; reduced.paint[0].points = points.slice(0,3)
	var equivalent: NativeTrack = TrackCompiler.compile(reduced)
	check(compiled.cells == equivalent.cells and compiled.kerbs.blocked == equivalent.kerbs.blocked,"idempotent stroke reduction retains exact complete cells and kerb exclusions")
	var cache: Dictionary = {"enabled":true}
	var first: NativeTrack = TrackCompiler.compile(reduced,cache)
	var restored: NativeTrack = TrackCompiler.compile(reduced,cache)
	check(first.cells == restored.cells and first.kerbs.blocked == restored.kerbs.blocked,"prepared cache restores exact shared paint coverage")
	cancelled[0] = 0
	check(NativeTrack.from_data(equivalent.metadata,equivalent.content_hash,equivalent.cells,equivalent.deck_cells,equivalent.kerbs.blocked,func() -> bool: cancelled[0] += 1; return cancelled[0] >= 5) == null,"from_data fences partial cancelled contact preparation")
	var large_cells := PackedInt32Array(); large_cells.resize(640*640); large_cells.fill(1)
	var large_track: NativeTrack = grid_track(large_cells,640)
	var entered := Semaphore.new()
	var observed: Array[int] = [0]
	var large_paint: Array = [{"surface":2,"width":40.0,"shape":"round","mode":"free","points":[[-110,-110],[110,110]]}]
	var job = preload("res://editor/work_job.gd").start(func(stop: Callable) -> PackedByteArray:
		return RoadKerbs.exclusion_mask(large_track,large_paint,func() -> bool:
			observed[0] += 1
			if observed[0] == 1610: entered.post()
			return stop.call()),self)
	var deadline: int = Time.get_ticks_msec()+5000
	var started: bool = false
	while not job.done and Time.get_ticks_msec() < deadline:
		if entered.try_wait(): started = true; break
		await process_frame
	job.cancel()
	var cancel_start: int = Time.get_ticks_usec()
	while not job.done and Time.get_ticks_msec() < deadline: await process_frame
	check(started and job.done and job.result.is_empty(),"real owned worker cancels inside mask without publishing partial output")
	print("PAINT_CANCEL_JOIN_MS: ",(Time.get_ticks_usec()-cancel_start)/1000.0)
	print("PAINT_PREPARATION checks=%d failures=%d stress_16384_points_ms=%.3f" % [checks,failures,stress_us/1000.0])
	quit(1 if failures else 0)
