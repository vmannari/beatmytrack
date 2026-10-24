extends SceneTree
const OUTPUT: String = "res://../docs/evidence/gameplay-f04-f05-2026-10-23/dense-profile.json"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var results: Dictionary = profile()
	await process_frame
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE); file.store_string(JSON.stringify(results,"\t",true)+"\n"); file.close()
	for name: String in results.samples: print("DENSE_PROFILE ",name," ",JSON.stringify(results.samples[name]))
	quit()
func clear(_p: Vector2,_r: float,_e: bool) -> Vector3: return Vector3.ZERO
func stats(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate(); sorted.sort()
	return {"unit":"us","median":sorted[sorted.size()/2],"min":sorted.front(),"max":sorted.back(),"samples":values}
func profile() -> Dictionary:
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f04_f05_before/loose_tyres.gd.txt").replace("\r\n","\n").replace("class_name LooseTyres\n","")
	assert(before.reload() == OK)
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var result: Dictionary = {"engine":Engine.get_version_info().string,"kind":"paired desktop stage timings; no Android/FPS/thermal claim","samples":{}}
	for scenario: String in ["96_coincident_resting","576_coincident_resting","576_authored_walls","96_dense_moving","576_separated_resting","96_coincident_grid","576_coincident_grid","576_overlapping_walls_grid"]:
		var count: int = 96 if scenario.begins_with("96_") else 576
		var origins := PackedVector2Array()
		if scenario == "576_authored_walls" or scenario == "576_overlapping_walls_grid":
			var objects: Array = []
			for index: int in range(96): objects.append({"kind":"tyre_wall","position":[0,0] if scenario.contains("overlapping") else [(index%12)*3-18,(index/12)*2.5-10],"rotation":0 if scenario.contains("overlapping") else (index%3)*30})
			origins = LooseTyres.positions({"objects":objects})
		else:
			for index: int in range(count): origins.append(Vector2((index%24)*2+20,(index/24)*2+20) if scenario.contains("separated") else Vector2.ZERO)
		var samples: Array = [[],[]]
		var world := NativeTrack.new(); world.grid_width = 128; world.grid_height = 128; world.cell_size = 0.5; world.half_extent = Vector2(32,32); world.cells.resize(128*128); world.cells.fill(1)
		var contact: Callable = world._contact if scenario.contains("grid") else clear
		var scratch_bytes: int = 0; var pair_count: int = 0
		var query_counts: Dictionary = {}
		for repeat: int in range(7):
			var snapshots: Array = [[],[]]
			for variant: int in ([0,1] if repeat%2 == 0 else [1,0]):
				var state := VehicleState.new(); state.position = Vector2(-30,-30)
				for index: int in range(count):
					var p: Vector2 = origins[index]
					state.loose_tyres.append([p.x,p.y,sin(index*0.31)*12 if scenario.contains("moving") else 0.0,cos(index*0.17)*12 if scenario.contains("moving") else 0.0,0.0])
				var start: int = Time.get_ticks_usec()
				if variant == 0: before.step(state,origins,contact,state.position,config,VehicleSimulation.STEP)
				else: LooseTyres.step(state,origins,contact,state.position,config,VehicleSimulation.STEP)
				samples[variant].append(Time.get_ticks_usec()-start)
				snapshots[variant] = state.snapshot()
				if variant == 1:
					var details: Dictionary = state.get_meta(&"native_tyre_contacts").work_stats()
					scratch_bytes = details.scratch_bytes; pair_count = details.pairs
					query_counts = {"clear":details.clear_queries,"full":details.full_queries}
			assert(var_to_bytes(snapshots[0]) == var_to_bytes(snapshots[1]))
		result.samples[scenario] = {"before":stats(samples[0]),"after":stats(samples[1]),"pairs":pair_count,"native_vector_capacity_bytes":scratch_bytes,"queries":query_counts}
	return result
