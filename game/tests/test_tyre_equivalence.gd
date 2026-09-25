extends SceneTree
## Frozen pre-optimization solver, exact whole-state comparison across contacts.
func _initialize() -> void:
	var reference = load("res://tests/legacy_tyres_reference.gd")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var random := RandomNumberGenerator.new()
	random.seed = 9182026
	var checks: int = 0
	for scenario: int in range(110):
		var origins := PackedVector2Array()
		var a := VehicleState.new()
		var b := VehicleState.new()
		for index: int in range(85 if scenario >= 100 else 24):
			var p := Vector2(random.randf_range(-4,4),random.randf_range(-4,4))
			if scenario >= 100: p = Vector2((index%10)*2.0-10.0,(index/10)*2.0)
			origins.append(p)
			var v := Vector2.ZERO if scenario%3 == 0 or scenario >= 100 else Vector2(random.randf_range(-20,20),random.randf_range(-20,20))
			a.loose_tyres.append([p.x,p.y,v.x,v.y,0.0])
		b.loose_tyres = a.loose_tyres.duplicate(true)
		a.position = Vector2(0,-5)
		b.position = a.position
		a.track_elevated = scenario%7 == 0
		b.track_elevated = a.track_elevated
		var wall: Callable = func(p: Vector2,r: float,_e: bool) -> Vector3:
			return Vector3(1,0,1) if absf(p.x)+r>4.5 else Vector3.ZERO
		for tick: int in range(120):
			var from: Vector2 = a.position
			a.velocity = Vector2(sin(tick*0.1)*5,12)
			b.velocity = a.velocity
			a.position += a.velocity*VehicleSimulation.STEP
			b.position += b.velocity*VehicleSimulation.STEP
			reference.step(a,origins,wall,from,config,VehicleSimulation.STEP)
			LooseTyres.step(b,origins,wall,from,config,VehicleSimulation.STEP)
			checks += 1
			if a.snapshot() != b.snapshot():
				push_error("Tyre mismatch scenario %d tick %d" % [scenario,tick])
				quit(1)
				return
	print("TYRE_EQUIVALENCE: %d exact whole-state comparisons passed" % checks)
	var baseline_path: String = "res://../build/knot-tyres-before.gd"
	if FileAccess.file_exists(baseline_path):
		var baseline := GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string(baseline_path).replace("class_name LooseTyres", "")
		if baseline.reload() != OK:
			quit(1)
			return
		for solver: GDScript in [baseline,load("res://vehicle/loose_tyres.gd")]:
			var origins := PackedVector2Array()
			for index: int in range(85): origins.append(Vector2((index%10)*2.0,(index/10)*2.0))
			var state := VehicleState.new()
			state.position = Vector2(-10,-10)
			var times: Array[int] = []
			var clear_world: Callable = func(_p: Vector2,_r: float,_e: bool) -> Vector3: return Vector3.ZERO
			for repeat: int in range(5):
				var start: int = Time.get_ticks_usec()
				for tick: int in range(1200): solver.step(state,origins,clear_world,state.position,config,VehicleSimulation.STEP)
				times.append(Time.get_ticks_usec()-start)
			times.sort()
			print("STATIONARY_85_TYRES_US ","before" if solver == baseline else "after"," ",times[2]/1200.0)
	quit()
