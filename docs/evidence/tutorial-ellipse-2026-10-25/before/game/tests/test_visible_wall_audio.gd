extends "res://tests/analyze_shallow_collisions.gd"
## The visual-wall delay is measurable independently of audio hardware.
var wall_checks: int = 0
var wall_failures: int = 0

func expect(ok: bool, message: String) -> void:
	wall_checks += 1
	if not ok:
		wall_failures += 1
		print("FAIL: "+message)

func run() -> void:
	var rows: Array[Dictionary] = []
	var cost_us: Array[int] = []
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var config: HandlingConfig = VehicleCatalog.config(id)
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure(id,config,car)
		expect(audio.visible_contact.outline.size()>=4,"real mesh supplies the footprint: "+id)
		var front: float = 0.0
		for point: Vector2 in audio.visible_contact.outline: front = maxf(front,point.y)
		var guard_wall: NativeTrack = make_wall(Vector2(0,-1),.5)
		var guard := VehicleState.new()
		guard.position = Vector2(0,-front+.02)
		guard.velocity = Vector2(0,-4)
		audio.reset()
		audio.begin_physics_feedback()
		audio.resolved_contact(guard,guard_wall,guard.velocity)
		expect(audio.impact_count==0,"backing out of visible wall contact cannot invent a crash: "+id)
		guard.position = Vector2(0,2)
		audio.reset()
		audio.begin_physics_feedback()
		audio.resolved_contact(guard,guard_wall,guard.velocity)
		expect(audio.impact_count==0,"deep startup overlap has no guessed impact: "+id)
		for speed: float in [3.0,4.0,5.0,10.0,25.0]:
			var wall: NativeTrack = make_wall(Vector2(0,-1),.5)
			var sim := VehicleSimulation.new(config)
			var plain := VehicleSimulation.new(config)
			var start := Vector2(0,-maxf(4.0,front+1.0))
			sim.reset(start,0)
			plain.reset(start,0)
			sim.state.velocity = Vector2(0,speed)
			plain.state.velocity = Vector2(0,speed)
			audio.reset()
			var visible: int = -1
			var heard: int = -1
			var canonical: int = -1
			var snapshot_at_hit: Array = []
			for tick: int in range(360):
				var incoming: Vector2 = sim.state.velocity
				sim.step(DriveFrame.new(),wall)
				plain.step(DriveFrame.new(),wall)
				if visible<0 and sim.state.position.y+front>=0.0: visible = sim.state.tick
				audio.begin_physics_feedback()
				var start_us: int = Time.get_ticks_usec()
				audio.resolved_contact(sim.state,wall,incoming)
				cost_us.append(Time.get_ticks_usec()-start_us)
				if heard<0 and audio.impact_count>0: heard = sim.state.tick
				if canonical<0 and sim.state.collision_impulse!=Vector2.ZERO:
					canonical = sim.state.tick
					snapshot_at_hit = sim.state.snapshot()
				if canonical>=0: break
			var geometry_leads: bool = front>config.collision_radius+.05
			expect(canonical>=0 and heard>=0,"actual wall/feedback present: %s %.1f"%[id,speed])
			if geometry_leads:
				var aligned: bool = absi(heard-visible)<=1
				expect(aligned,"sound begins with visible bumper contact: %s %.1f ticks %d/%d"%[id,speed,visible,heard])
			expect(audio.impact_count==1,"later circle response cannot duplicate the same wall cue: "+id)
			expect(sim.state.snapshot()==plain.state.snapshot() and snapshot_at_hit==plain.state.snapshot(),"body-footprint audio never changes canonical wall resolution: "+id)
			rows.append({"car":id,"speed":speed,"front_m":front,"radius_m":config.collision_radius,"visible_tick":visible,"sound_tick":heard,"canonical_tick":canonical,"old_gap_ms":float(canonical-visible)/120.0*1000.0,"new_gap_ms":float(heard-visible)/120.0*1000.0})
		for angle: float in [PI*.5,-PI*.5,PI,PI*.25,-PI*.25]:
			var forward := Vector2(sin(angle),cos(angle))
			var wall: NativeTrack = make_wall(-forward,.5)
			var sim := VehicleSimulation.new(config)
			sim.reset(-forward*maxf(4.0,front+1),angle)
			sim.state.velocity = forward*4
			audio.reset()
			var first_overlap: int = -1
			var first_sound: int = -1
			for tick: int in range(240):
				var incoming: Vector2 = sim.state.velocity
				sim.step(DriveFrame.new(),wall)
				audio.begin_physics_feedback()
				audio.resolved_contact(sim.state,wall,incoming)
				if first_overlap<0 and audio.visible_contact.touching: first_overlap = sim.state.tick
				if first_sound<0 and audio.impact_count>0: first_sound = sim.state.tick
				if sim.state.collision_impulse!=Vector2.ZERO: break
			expect(first_overlap>0 and first_sound==first_overlap,"rotated wall touch sounds immediately: %s angle%.2f"%[id,angle])
			expect(audio.impact_count==1,"rotated wall episode remains a single cue: "+id)
		car.free()
		audio.free()
	# Execute the actual composition-root callback with rendering disabled.
	var game: Node = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.production_mode = false
	var real_wall: NativeTrack = make_wall(Vector2(0,-1),.5)
	game.native_track = real_wall
	game.yard = real_wall
	game.sim.reset(Vector2(0,-4),0)
	game.sim.state.velocity = Vector2(0,4)
	game.vehicle_audio.reset()
	var front: float = 0.0
	for point: Vector2 in game.vehicle_audio.visible_contact.outline: front = maxf(front,point.y)
	var first_visual: int = -1
	var first_audio: int = -1
	var first_physical: int = -1
	for tick: int in range(240):
		game._physics_process(VehicleSimulation.STEP)
		if first_visual<0 and game.sim.state.position.y+front>=0: first_visual = game.sim.state.tick
		if first_audio<0 and game.vehicle_audio.impact_count>0: first_audio = game.sim.state.tick
		if game.sim.state.collision_impulse!=Vector2.ZERO:
			first_physical = game.sim.state.tick
			break
	expect(first_audio==first_visual and first_audio>0,"real Game callback sounds on the visible wall-contact tick without a render")
	expect(first_physical>first_audio and game.vehicle_audio.impact_count==1,"real Game keeps physical response and suppresses delayed duplicate audio")
	print("REAL_GAME_WALL_AUDIO: ",JSON.stringify({"visual_tick":first_visual,"audio_tick":first_audio,"physical_tick":first_physical}))
	game.free()
	await create_timer(.2).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/collision-attack-2026-10-08"))
	var report: FileAccess = FileAccess.open("res://../docs/evidence/collision-attack-2026-10-08/wall-contact-comparison.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	cost_us.sort()
	var sum_us: int = 0
	for value: int in cost_us: sum_us += value
	print("WALL_AUDIO_COST_US: ",JSON.stringify({"samples":cost_us.size(),"mean":float(sum_us)/cost_us.size(),"p95":cost_us[mini(cost_us.size()-1,int(cost_us.size()*.95))]}))
	print("VISIBLE_WALL_ROWS: ",JSON.stringify(rows))
	print("VISIBLE_WALL_AUDIO: %d checks, %d failures"%[wall_checks,wall_failures])
	quit(1 if wall_failures>0 else 0)
