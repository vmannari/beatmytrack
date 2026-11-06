extends SceneTree
## Byte-exact comparison against the archived pre-optimization implementation.
const CACHE = preload("res://race/checkpoint_layout_cache.gd")
const BEFORE := "res://../docs/evidence/checkpoint-preparation-2026-11-05/before/game/race/"
var checks: int = 0
var failures: int = 0
var rows: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var corridor := GDScript.new()
	corridor.source_code = FileAccess.get_file_as_string(BEFORE+"spline_gate_corridor.gd").replace("class_name SplineGateCorridor", "")
	check(corridor.reload() == OK,"reference corridor compiles")
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string(BEFORE+"track_session.gd").replace("class_name TrackSession", "").replace("SplineGateCorridor.select(self,track)","_reference_corridor.select(self,track)")+"\nvar _reference_corridor: GDScript\n"
	check(reference.reload() == OK,"reference session compiles")
	for fixture: String in ["star_spline_lap","silmukka","dust_cloud","over_and_under","knot"]:
		for reverse: bool in [false,true]:
			var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
			if reverse and not doc.has("start_line"): continue
			if reverse: doc.start_line.heading = fposmod(float(doc.start_line.heading)+180.0,360.0)
			var track: NativeTrack = TrackCompiler.compile(doc)
			var old: RefCounted = reference.new()
			old._reference_corridor = corridor
			var began: int = Time.get_ticks_usec()
			old._configure(track)
			var old_us: int = Time.get_ticks_usec()-began
			var expected: PackedByteArray = var_to_bytes(track._race_gates)
			track._race_gates = {}; CACHE.trim_to()
			var current := TrackSession.new()
			began = Time.get_ticks_usec()
			current._configure(track)
			var fresh_us: int = Time.get_ticks_usec()-began
			check(var_to_bytes(track._race_gates) == expected,fixture+str(reverse)+" full prepared layout is byte-exact")
			var again := TrackSession.new()
			began = Time.get_ticks_usec(); again._configure(track)
			var same_us: int = Time.get_ticks_usec()-began
			var clone: NativeTrack = TrackCompiler.compile(doc)
			began = Time.get_ticks_usec(); TrackSession.new()._configure(clone)
			var shared_us: int = Time.get_ticks_usec()-began
			check(var_to_bytes(clone._race_gates) == expected,"independently compiled track has exact shared layout")
			check(CACHE.count() == 1,"identical compiled geometry shares one cache entry")
			for fraction: float in [-1.0,-0.375,0.0,0.625,1.0]:
				for constant: bool in [false,true]:
					for rejoin: bool in [false,true]:
						for margin: float in [0.5,RaceRules.CHECKPOINT_RECOVERY_M]:
							check(var_to_bytes(corridor.lane(track,fraction,constant,rejoin,margin)) == var_to_bytes(SplineGateCorridor.lane(track,fraction,constant,rejoin,margin)),"exact lane points and ordering")
			var row := {"fixture":fixture,"reverse":reverse,"before_us":old_us,"fresh_us":fresh_us,"same_track_us":same_us,"shared_us":shared_us,"gates":current.checkpoint_count(),"layout_bytes":expected.size(),"cache_estimate":CACHE.bytes_used()}
			rows.append(row); print("CHECKPOINT_PREPARATION_ROW ",JSON.stringify(row))
			var versions: Array = [RaceRules.KEY,TrackSession.NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]
			var key: String = CACHE.key_for(track,versions)
			check(key != CACHE.key_for(track,["different"]),"versions fence reuse")
			clone.finish_center += Vector2(0.25,0)
			check(key != CACHE.key_for(clone,versions),"actual finish inputs fence stale content hash")
			clone.finish_center = track.finish_center
			clone.route[0] += Vector2(0.25,0)
			check(key != CACHE.key_for(clone,versions),"actual route inputs fence stale content hash")
			track._race_gates._notice_route_bins[Vector2i(-999,-999)] = [123]
			check(var_to_bytes(CACHE.read(key).layout) == expected,"nested mutation cannot contaminate shared layout")
			await process_frame
	cache_contracts()
	var file := FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  ")); file.close()
	print("CHECKPOINT_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cache_contracts() -> void:
	CACHE.trim_to()
	var ticket: Dictionary = CACHE.read("a")
	var value := {"nested":[{"x":1}]}
	CACHE.store("a",value,ticket.generation)
	value.nested[0].x = 2
	check(CACHE.read("a").layout.nested[0].x == 1,"store owns nested values")
	var found: Dictionary = CACHE.read("a").layout
	found.nested[0].x = 3
	check(CACHE.read("a").layout.nested[0].x == 1,"read owns nested values")
	for key: String in ["b","c","d"]: CACHE.store(key,value,ticket.generation)
	CACHE.read("a"); CACHE.store("e",value,ticket.generation)
	check(CACHE.count() == 4 and CACHE.read("b").layout.is_empty() and not CACHE.read("a").layout.is_empty(),"bounded LRU keeps recently used entry")
	var large := PackedByteArray(); large.resize(CACHE.MAX_BYTES)
	CACHE.store("too_large",{"payload":large},ticket.generation)
	check(CACHE.read("too_large").layout.is_empty() and CACHE.bytes_used() <= CACHE.MAX_BYTES,"oversized layout bypasses bounded cache")
	CACHE.trim_to()
	CACHE.store("late",value,ticket.generation)
	check(CACHE.count() == 0 and CACHE.bytes_used() == 0,"pressure epoch rejects late worker insertion")
	check(CACHE.read("late").layout.is_empty(),"pressure leaves no retained layouts")
	var ready := Semaphore.new()
	var resume := Semaphore.new()
	var worker := Thread.new()
	check(worker.start(func() -> void:
		var pending: Dictionary = CACHE.read("worker")
		ready.post(); resume.wait()
		CACHE.store("worker",{"nested":[{"x":9}]},pending.generation)
	) == OK,"worker starts")
	ready.wait(); CACHE.trim_to(); resume.post(); worker.wait_to_finish()
	check(CACHE.count() == 0,"real worker cannot restore cache after pressure")
	var payload := PackedByteArray(); payload.resize(180000)
	for index: int in range(8): CACHE.store(str(index),{"payload":payload},CACHE.read("").generation)
	check(CACHE.count() < CACHE.MAX_ENTRIES and CACHE.bytes_used() <= CACHE.MAX_BYTES,"byte budget evicts before entry cap")
	var memory = preload("res://editor/editor_memory.gd")
	var owner = preload("res://tests/test_race_loading_optimisation.gd").MemoryOwner.new()
	root.add_child(owner)
	check(memory.retained(owner).other.checkpoint_layout_bytes == CACHE.bytes_used(),"App accounts bounded numeric layouts")
	var active: Dictionary = CACHE.read("7").layout
	var manager: RefCounted = memory.new()
	manager.pressure_requested = true; manager.tick(owner)
	check(CACHE.bytes_used() == 0 and not active.is_empty(),"App pressure clears optional cache while active copies survive")
	owner.free()
	CACHE.trim_to()
