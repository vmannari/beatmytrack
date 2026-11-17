extends SceneTree
## Whole-layout equality against the task-start implementation, without caches.
var checks: int = 0
var failures: int = 0
var rows: Array = []
const ACCEL = preload("res://track/geometry_acceleration.gd")
var original: Script
var original_corridor: Script
var original_coverage: Script
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("EFFICIENCY_FAIL ",label)
func run() -> void:
	var base: String = OS.get_environment("BMT_ALGORITHM_REFERENCE")
	if base.is_empty(): base = "res://../docs/evidence/road-checkpoint-efficiency-2026-11-17/before/game/race"
	var corridor := GDScript.new()
	corridor.source_code = FileAccess.get_file_as_string(base+"/spline_gate_corridor.gd").replace("class_name SplineGateCorridor","")
	check(corridor.reload() == OK,"independent original corridor compiles")
	original_corridor = corridor
	original_coverage = GDScript.new()
	original_coverage.source_code = FileAccess.get_file_as_string(base+"/road_gate_coverage.gd").replace("class_name RoadGateCoverage","")
	check(original_coverage.reload() == OK,"independent original road coverage compiles")
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string(base+"/track_session.gd").replace("class_name TrackSession","").replace("SplineGateCorridor.","_reference_corridor.").replace('preload("res://race/road_gate_coverage.gd")',"_reference_coverage")+"\nvar _reference_corridor: Script\nvar _reference_coverage: Script\n"
	reference.source_code = reference.source_code.replace("var coverage := _reference_coverage.new(track)","var coverage: RefCounted = _reference_coverage.new(track)")
	check(reference.reload() == OK,"independent original session compiles")
	original = reference
	check(ACCEL.checkpoints() != null,"native checkpoint implementation is loaded")
	if ACCEL.checkpoints() == null: quit(1); return
	kernel_cases()
	var fixture_names: PackedStringArray = ["star_spline_lap"]
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("--fixtures="): fixture_names = option.trim_prefix("--fixtures=").split(",")
	var cache: Script = load("res://race/checkpoint_layout_cache.gd")
	load("res://race/checkpoint_layout_disk_cache.gd").directory = ""
	for fixture: String in fixture_names:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
		var track: Resource = load("res://editor/track_compiler.gd").compile(doc)
		check(track != null,fixture+" compiles")
		if track == null: continue
		compare_layout(track,fixture)
		if "--reversed" in OS.get_cmdline_user_args() and doc.has("start_line"):
			doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
			track = load("res://editor/track_compiler.gd").compile(doc)
			check(track != null,fixture+" reversed compiles")
			if track != null: compare_layout(track,fixture+" reversed")
	for variable: bool in [false,true]:
		var piece: Dictionary = RoadPieces.create("spline",Vector2(-20,-20),0.0,8.0)
		piece.spline_points = [[0.0,0.0],[40.0,0.0],[40.0,40.0],[0.0,40.0],[0.0,0.0]]
		piece.point_widths = [6.0,8.0,12.0,8.0,6.0] if variable else [8.0,8.0,8.0,8.0,8.0]
		piece.width = piece.point_widths.max()
		var doc: Dictionary = TrackDocument.create_blank(); doc.pieces = [piece]
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,"closed variable-width spline compiles")
		if track != null: compare_layout(track,"variable" if variable else "uniform")
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"checks":checks,"failures":failures},"  "))
	print("ALGORITHM_EQUIVALENCE ",checks," checks, ",failures," failures")
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for frame: int in range(14): await process_frame
	quit(1 if failures else 0)

func compare_layout(track: NativeTrack, label: String) -> void:
	var cache: Script = load("res://race/checkpoint_layout_cache.gd")
	cache.trim_to(); track._race_gates = {}
	var old: RefCounted = original.new()
	old._reference_corridor = original_corridor; old._reference_coverage = original_coverage
	var began: int = Time.get_ticks_usec(); old._configure(track)
	var before_us: int = Time.get_ticks_usec()-began
	var expected: PackedByteArray = var_to_bytes(track._race_gates)
	cache.trim_to(); track._race_gates = {}
	var current := TrackSession.new()
	began = Time.get_ticks_usec(); current._configure(track)
	var after_us: int = Time.get_ticks_usec()-began
	check(var_to_bytes(track._race_gates) == expected,label+" complete encoded geometry, order, widths and notices exact")
	rows.append({"fixture":label,"before_us":before_us,"after_us":after_us,"gates":current.checkpoint_count(),"bytes":expected.size()})
	print("EFFICIENCY_ROW ",JSON.stringify(rows[-1]))
	cache.trim_to(); track._race_gates = {}
	ACCEL.checkpoints_enabled = false
	TrackSession.new()._configure(track)
	check(var_to_bytes(track._race_gates) == expected,label+" optional scalar fallback is exact")
	ACCEL.checkpoints_enabled = true

func kernel_cases() -> void:
	var native: RefCounted = ACCEL.checkpoints()
	for variant: int in range(12):
		var session := TrackSession.new()
		for index: int in range(13):
			session._centers.append(Vector2(index*8.0-48.000001,variant*0.003))
			session._directions.append(Vector2.RIGHT.rotated(index*0.37))
			session._widths.append(Vector2(index%4,variant+1))
		var path := PackedVector2Array()
		for index: int in range(180):
			path.append(Vector2(sin(index*0.34)*64.0,cos(index*0.17)*24.0))
			if index%11 == 0: path.append(path[-1])
		var expected: PackedFloat64Array = original_corridor._crossings(session,path)
		check(expected.to_byte_array() == native.checkpoint_crossings(session._centers,session._directions,PackedVector2Array(session._widths),path).to_byte_array(),"exact crossings, nearest tie order and zero-length segments "+str(variant))
	for sparse: bool in [false,true]:
		var track := NativeTrack.new()
		for index: int in range(80):
			track.route.append(Vector2(sin(index*0.15)*30.0,cos(index*0.15)*30.0)*(20.0 if sparse else 1.0))
			track.route_widths.append(6.0+index%7)
			track.route_cumulative.append(0.0 if index == 0 else track.route_cumulative[-1]+track.route[index].distance_to(track.route[index-1]))
		track.route_length = track.route_cumulative[-1]+track.route[-1].distance_to(track.route[0])
		var bins: Dictionary = {}
		for index: int in range(track.route.size()):
			var key := Vector2i((track.route[index]/8.0).floor())
			if not bins.has(key): bins[key] = []
			bins[key].append(index)
		check(native.checkpoint_prepare(track.route,PackedFloat64Array(Array(track.route_cumulative))),"private route index prepares")
		for index: int in range(300):
			var point := Vector2(index%30*8.0-120.00001,index/30*8.0-40.0)
			check(original_corridor._projection(track,point,bins) == native.checkpoint_projection(point),"exact route projection, negative cells and sparse global fallback "+str(index))
		var basis: Dictionary = original_corridor._lane_basis(track)
		for fraction: float in [-1.0,-0.8928571428571429,-0.5,0.0,0.5,0.8928571428571429,1.0]:
			for constant_width: bool in [false,true]:
				for rejoin: bool in [false,true]:
					var expected: PackedVector2Array = original_corridor.lane(track,fraction,constant_width,rejoin,RaceRules.CHECKPOINT_RECOVERY_M,basis)
					var actual: PackedVector2Array = native.checkpoint_lane(track.route,basis,fraction,constant_width,rejoin,RaceRules.CHECKPOINT_RECOVERY_M,Geometry2D)
					check(expected.to_byte_array() == actual.to_byte_array(),"exact lane rounding, widths and loop removal")
	check(native.checkpoint_crossings(PackedVector2Array(),PackedVector2Array([Vector2.ZERO]),PackedVector2Array(),PackedVector2Array()).is_empty(),"unsupported crossings return scalar fallback sentinel")
	check(not native.checkpoint_prepare(PackedVector2Array(),PackedFloat64Array()),"invalid route preparation clears prior job")
	check(is_nan(native.checkpoint_projection(Vector2.ZERO)),"invalid route index returns scalar fallback sentinel")
