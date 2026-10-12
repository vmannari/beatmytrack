extends "res://tests/analyze_shallow_collisions.gd"
var audio_checks: int = 0
var audio_failures: int = 0

func expect(ok: bool, message: String) -> void:
	audio_checks += 1
	if not ok:
		audio_failures += 1
		print("FAIL: "+message)

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
		for initial_speed: float in [.35,.6]:
			var sim := VehicleSimulation.new(config)
			var plain := VehicleSimulation.new(config)
			sim.reset(Vector2(0,-front-.005),0)
			plain.reset(sim.state.position,0)
			sim.state.velocity = Vector2(0,initial_speed)
			plain.state.velocity = sim.state.velocity
			audio.reset()
			var touch: int = -1
			var eligible: int = -1
			var sound: int = -1
			var physical: int = -1
			var equivalent: bool = true
			var silent_soft_touch: bool = true
			for tick: int in range(360):
				var input: DriveFrame = DriveFrame.sample(0,1.0 if touch>=0 else 0.0,0)
				var incoming: Vector2 = sim.state.velocity
				sim.step(input,wall)
				plain.step(input,wall)
				audio.begin_physics_feedback()
				audio.resolved_contact(sim.state,wall,incoming)
				if audio.visible_contact.touching and touch<0: touch = sim.state.tick
				if audio.visible_contact.touching and incoming.y>1.2 and eligible<0: eligible = sim.state.tick
				if eligible<0 and audio.impact_count>0: silent_soft_touch = false
				if audio.impact_count>0 and sound<0: sound = sim.state.tick
				equivalent = equivalent and sim.state.snapshot()==plain.state.snapshot()
				if sim.state.collision_impulse!=Vector2.ZERO:
					physical = sim.state.tick
					break
			expect(touch>0 and eligible>touch,"fixture begins with a genuinely soft touch: "+id)
			expect(silent_soft_touch,"tiny-contact threshold remains: "+id)
			expect(sound==eligible,"escalating current contact sounds on its first eligible tick: "+id)
			expect(physical>sound and audio.impact_count==1,"later canonical wall hit is not a delayed second sound: "+id)
			expect(equivalent,"audio observer never changes driving snapshots: "+id)
			rows.append({"car":id,"initial_speed":initial_speed,"touch":touch,"eligible":eligible,"sound":sound,"physical":physical})
		# A meaningful cue blocked by another event's cooldown is not retried as
		# an old impact later. Canonical future impacts keep their normal path.
		audio.reset()
		audio.impact_cooldown = .05
		var state := VehicleState.new()
		state.position = Vector2(0,-front+.003)
		state.velocity = Vector2(0,4)
		audio.begin_physics_feedback()
		audio.resolved_contact(state,wall,state.velocity)
		expect(audio.impact_count==0 and audio.visible_contact.cue_requested,"cooldown rejects the first attempt: "+id)
		audio.impact_cooldown = 0.0
		audio.resolved_contact(state,wall,state.velocity)
		expect(audio.impact_count==0,"ongoing contact does not queue a late stale cue: "+id)
		# The canonical response can be audible before visual inward speed meets
		# its threshold. Its accepted cue must still own the whole episode.
		audio.reset()
		state.velocity = Vector2(0,.9)
		state.collision_impulse = Vector2(0,-2)
		audio.begin_physics_feedback()
		audio.resolved_contact(state,wall,state.velocity)
		state.collision_impulse = Vector2.ZERO
		state.velocity = Vector2(0,4)
		audio.impact_cooldown = 0.0
		audio.resolved_contact(state,wall,state.velocity)
		expect(audio.impact_count==1,"canonical-first cue also suppresses a later virtual duplicate: "+id)
		audio.free()
		car.free()
	await create_timer(.15).timeout
	print("CONTACT_ESCALATION_ROWS: ",JSON.stringify(rows))
	print("CONTACT_ESCALATION_AUDIO: %d checks, %d failures"%[audio_checks,audio_failures])
	quit(1 if audio_failures>0 else 0)
