extends SceneTree
func _initialize() -> void:
	var reference_script = load("res://tests/reference_grid_contact.gd")
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var checks: int = 0
	for scenario: int in range(4):
		var ground := NativeTrack.new()
		ground.cell_size = 0.5
		ground.grid_width = 128
		ground.grid_height = 96
		ground.half_extent = Vector2(32,24)
		ground.cells.resize(128*96)
		ground.deck_cells.resize(128*96)
		ground.deck_cells.fill(-1)
		ground.route = PackedVector2Array([Vector2(0,-20),Vector2(0,20)])
		for y: int in range(5):
			for x: int in range(17): ground.tyre_origins.append(Vector2(x-8,y))
		if scenario == 3:
			for x: int in range(40,88): ground.cells[36*128+x] = 4
		var reference: NativeTrack = reference_script.new()
		for property: Dictionary in ground.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: reference.set(property.name,ground.get(property.name))
		var a := VehicleSimulation.new(config)
		var b := VehicleSimulation.new(config)
		for sim: VehicleSimulation in [a,b]:
			sim.reset(Vector2(scenario-2,-4),0.12*scenario)
			sim.state.velocity = sim.state.forward()*24
		for tick: int in range(600):
			var frame: DriveFrame = DriveFrame.sample(0.25*sin(tick*0.04) if scenario == 2 else 0,1,0)
			a.step(frame,reference)
			b.step(frame,ground)
			checks += 1
			if a.state.snapshot() != b.state.snapshot():
				push_error("Pile state mismatch scenario %d tick %d"%[scenario,tick])
				quit(1)
				return
	print("PILE_CONTACT_EQUIVALENCE: %d exact full simulation states passed"%checks)
	quit()
