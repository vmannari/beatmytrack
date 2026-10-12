extends "res://tests/analyze_shallow_collisions.gd"

func run() -> void:
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var config: HandlingConfig = VehicleCatalog.config(id)
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure(id,config,car)
		var front: float = 0.0
		for point: Vector2 in audio.visible_contact.outline: front = maxf(front,point.y)
		var wall: NativeTrack = make_wall(Vector2(0,-1),.5)
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(0,-front-.005),0)
		sim.state.velocity = Vector2(0,.35)
		var touch: int = -1
		var eligible: int = -1
		var sound: int = -1
		var physical: int = -1
		for tick: int in range(360):
			var input: DriveFrame = DriveFrame.sample(0,1.0 if touch>=0 else 0.0,0)
			var incoming: Vector2 = sim.state.velocity
			sim.step(input,wall)
			audio.begin_physics_feedback()
			audio.resolved_contact(sim.state,wall,incoming)
			if audio.visible_contact.touching and touch<0: touch = sim.state.tick
			if audio.visible_contact.touching and incoming.y>1.2 and eligible<0: eligible = sim.state.tick
			if audio.impact_count>0 and sound<0: sound = sim.state.tick
			if sim.state.collision_impulse!=Vector2.ZERO:
				physical = sim.state.tick
				break
		rows.append({"car":id,"soft_touch_tick":touch,"audible_contact_tick":eligible,"sound_tick":sound,"physical_tick":physical,"extra_dispatch_delay_ms":float(sound-eligible)*VehicleSimulation.STEP*1000.0 if sound>=0 and eligible>=0 else null})
		audio.free()
		car.free()
	print("SLOW_WALL_AUDIO: ",JSON.stringify(rows))
	await create_timer(.15).timeout
	quit()
