extends "res://tests/analyze_shallow_collisions.gd"
## Distinguish rendered nose/canonical contact/observer dispatch in an actual wall case.

func run() -> void:
	var wall: NativeTrack = make_wall(Vector2(0,-1),0.5)
	var car := CarVisual.new()
	root.add_child(car)
	var bounds := AABB()
	var has_bounds: bool = false
	for node: Node in car.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh==null: continue
		var box: AABB = car.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		bounds = bounds.merge(box) if has_bounds else box
		has_bounds = true
	var front: float = -bounds.position.z*car.scale.z
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var rows: Array[Dictionary] = []
	for speed: float in [3.0,4.0,5.0,10.0,25.0]:
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(0,-3.0),0)
		sim.state.velocity = Vector2(0,speed)
		var visible_tick: int = -1
		var collision_tick: int = -1
		var velocity_at_touch: float = 0.0
		for tick: int in range(240):
			sim.step(DriveFrame.new(),wall)
			if visible_tick<0 and sim.state.position.y+front>=0.0:
				visible_tick = sim.state.tick
				velocity_at_touch = sim.state.velocity.length()
			if sim.state.collision_impulse!=Vector2.ZERO:
				collision_tick = sim.state.tick
				break
		rows.append({"initial_speed":speed,"front_extent_m":front,"collision_radius_m":config.collision_radius,"visible_tick":visible_tick,"canonical_tick":collision_tick,"speed_at_visible_touch":velocity_at_touch,"gap_ms":float(collision_tick-visible_tick)/120.0*1000.0})
	car.free()
	print("WALL_AUDIO_GAP: ",JSON.stringify(rows))
	quit()
