extends SceneTree
## Desktop paired stage timings; not a phone/FPS/thermal certification.
const OUTPUT: String = "res://../docs/evidence/gameplay-f01-f03-2026-10-23/paired-profile.json"
var results: Dictionary = {"kind":"paired desktop microbenchmarks","engine":Engine.get_version_info().string,"platform":OS.get_name(),"samples":{}}
func _initialize() -> void: run.call_deferred()
func reference(name: String, declaration: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f01_f03_before/"+name+".gd.txt").replace("\r\n","\n").replace("class_name "+declaration+"\n","")
	assert(script.reload() == OK)
	return script
func stats(samples: Array) -> Dictionary:
	var ordered: Array = samples.duplicate(); ordered.sort()
	return {"unit":"us","median":ordered[ordered.size()/2],"min":ordered.front(),"max":ordered.back(),"samples":samples}
func condition(dirt: float) -> Dictionary:
	var value: Dictionary = VehicleWeathering.new().snapshot(); value.dirt = dirt
	return value
func clear(_p: Vector2,_r: float,_e: bool) -> Vector3: return Vector3.ZERO
func run() -> void:
	var old_records: GDScript = reference("local_records","LocalRecords")
	var folder: String = "user://gameplay_profile_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	for count: int in [1000,10000]:
		var before: RefCounted = old_records.new(folder.path_join("before_%d.json" % count))
		var after := LocalRecords.new(folder.path_join("after_%d.json" % count))
		for index: int in range(count): before.records[str(index).sha256_text()] = {"race_ms":100000,"flying_ms":20000}
		after.records = before.records.duplicate(true)
		before.settings.vehicle_conditions = {"compact":condition(0.0)}
		after.settings.vehicle_conditions = {"compact":condition(0.0)}
		assert(before.save_records() == OK and after.save_records() == OK)
		VehicleCondition.read(after,"compact")
		var original_hash: String = FileAccess.get_sha256(after.path)
		var full: Array = []; var queue: Array = []; var barrier: Array = []
		for index: int in range(15):
			var value: Dictionary = condition(float(index+1)/20.0)
			before.settings.vehicle_conditions.compact = value
			var begin: int = Time.get_ticks_usec()
			assert(before.save_records() == OK)
			full.append(Time.get_ticks_usec()-begin)
			begin = Time.get_ticks_usec()
			assert(VehicleCondition.save(after,"compact",value,true) == OK)
			queue.append(Time.get_ticks_usec()-begin)
			begin = Time.get_ticks_usec()
			assert(after._condition_store.flush() == OK)
			barrier.append(Time.get_ticks_usec()-begin)
		assert(FileAccess.get_sha256(after.path) == original_hash)
		results.samples["condition_%d_records" % count] = {"before_full_main_thread":stats(full),"after_main_thread_enqueue":stats(queue),"after_explicit_barrier_separate":stats(barrier)}
		before = null; after = null
		for frame: int in range(3): await process_frame
	var old_tyres: GDScript = reference("loose_tyres","LooseTyres")
	var old_props: GDScript = reference("light_props","LightProps")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	for count: int in [96,576]:
		var origins := PackedVector2Array()
		for index: int in range(count): origins.append(Vector2(20+(index%24)*2,20+(index/24)*2))
		var states: Array = [VehicleState.new(),VehicleState.new()]
		for state: VehicleState in states: state.position = Vector2(-20,-20)
		var samples: Array = [[],[]]
		for batch: int in range(5):
			for variant: int in ([0,1] if batch%2 == 0 else [1,0]):
				var implementation: GDScript = old_tyres if variant == 0 else LooseTyres
				var state: VehicleState = states[variant]
				for warm: int in range(5): implementation.step(state,origins,clear,state.position,config,VehicleSimulation.STEP)
				var begin: int = Time.get_ticks_usec()
				for tick: int in range(120): implementation.step(state,origins,clear,state.position,config,VehicleSimulation.STEP)
				samples[variant].append(float(Time.get_ticks_usec()-begin)/120.0)
		assert(var_to_bytes(states[0].snapshot()) == var_to_bytes(states[1].snapshot()))
		results.samples["resting_tyres_%d_per_tick" % count] = {"before":stats(samples[0]),"after":stats(samples[1])}
	var objects: Array = []
	for index: int in range(96): objects.append({"kind":"cone","position":[20+(index%12)*3,20+(index/12)*3],"rotation":0})
	var states: Array = [VehicleState.new(),VehicleState.new()]
	for state: VehicleState in states: state.position = Vector2(-20,-20)
	var samples: Array = [[],[]]
	for batch: int in range(5):
		for variant: int in ([0,1] if batch%2 == 0 else [1,0]):
			var implementation: GDScript = old_props if variant == 0 else LightProps
			var state: VehicleState = states[variant]
			for warm: int in range(5): implementation.step(state,objects,clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			var begin: int = Time.get_ticks_usec()
			for tick: int in range(600): implementation.step(state,objects,clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			samples[variant].append(float(Time.get_ticks_usec()-begin)/600.0)
	assert(var_to_bytes(states[0].snapshot()) == var_to_bytes(states[1].snapshot()))
	results.samples.resting_cones_96_per_tick = {"before":stats(samples[0]),"after":stats(samples[1])}
	var old_kerbs: GDScript = reference("road_kerbs","RoadKerbs")
	var track := NativeTrack.new(); track.grid_width = 128; track.grid_height = 128; track.half_extent = Vector2(32,32); track.cell_size = 0.5; track.cells.resize(128*128); track.cells.fill(1)
	var points: Array = []
	for index: int in range(32): points.append([-25,-25] if index%2 == 0 else [25,25])
	var paint: Array = []
	for index: int in range(4): paint.append({"surface":1,"width":12.0,"shape":"round","mode":"free","points":points.duplicate(true)})
	samples = [[],[]]
	var masks: Array = [PackedByteArray(),PackedByteArray()]
	for batch: int in range(5):
		for variant: int in ([0,1] if batch%2 == 0 else [1,0]):
			var implementation: GDScript = old_kerbs if variant == 0 else RoadKerbs
			var begin: int = Time.get_ticks_usec()
			masks[variant] = implementation.exclusion_mask(track,paint)
			samples[variant].append(Time.get_ticks_usec()-begin)
	assert(masks[0] == masks[1])
	results.samples.exclusion_fallback_128_points = {"before":stats(samples[0]),"after":stats(samples[1]),"note":"Fallback-only comparison. Normal new compiler reuses its paint mask, avoiding this second raster entirely."}
	var doc: Dictionary = TrackDocument.create_default(); points.clear()
	for index: int in range(512): points.append([-110,-110] if index%2 == 0 else [110,110])
	for index: int in range(32): doc.paint.append({"surface":1,"width":40.0,"shape":"round","mode":"free","points":points.duplicate(true)})
	var stress: Array = []
	for batch: int in range(5):
		var begin: int = Time.get_ticks_usec()
		assert(TrackCompiler.compile(doc) != null)
		stress.append(Time.get_ticks_usec()-begin)
	results.samples.full_compile_16384_repeated_points_after = stats(stress)
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE); file.store_string(JSON.stringify(results,"\t",true)+"\n"); file.close()
	for key: String in results.samples: print(key,": ",JSON.stringify(results.samples[key]))
	quit()
