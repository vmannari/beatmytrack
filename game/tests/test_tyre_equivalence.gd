extends SceneTree
## Frozen pre-optimization solver, exact whole-state comparison across contacts.
func _initialize() -> void:
	var reference = load("res://tests/legacy_tyres_reference.gd")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var random := RandomNumberGenerator.new()
	random.seed = 9182026
	var checks: int = 0
	for scenario: int in range(100):
		var origins := PackedVector2Array()
		var a := VehicleState.new()
		var b := VehicleState.new()
		for index: int in range(24):
			var p := Vector2(random.randf_range(-4,4),random.randf_range(-4,4))
			origins.append(p)
			var v := Vector2.ZERO if scenario%3 == 0 else Vector2(random.randf_range(-20,20),random.randf_range(-20,20))
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
	quit()
