extends "res://tests/analyze_shallow_collisions.gd"
## Behavioral regressions for racing-speed scrapes, actual blockers and feedback.

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",description)

func run() -> void:
	expect(PlaygroundData.CONTACT_STEP==VehicleSimulation.STEP,"contact alignment uses the pinned canonical tick duration")
	var ground := PlaygroundData.new()
	for vehicle: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(vehicle)
		for speed: float in [10.0,20.0,30.0,40.0]:
			for angle: float in [0.1,0.5,1.0,2.0,3.0,5.0]:
				var state := VehicleState.new()
				state.heading = deg_to_rad(angle)
				state.velocity = state.forward()*speed
				var before: Vector2 = state.velocity
				ground._bounce(state,Vector2.LEFT,config)
				var energy: float = config.mass*state.velocity.length_squared()+config.rotational_inertia*state.yaw_rate*state.yaw_rate
				expect(energy <= config.mass*speed*speed+0.01,"scrape cannot add linear/angular energy: "+vehicle)
				expect(state.velocity.y >= before.y*0.90,"strong 0.1-5 degree scrape keeps at least 90% tangent speed per contact: "+vehicle)
				expect(state.collision_impulse.length()<0.1 and state.scrape_strength>0.0,"shallow brush supplies scrape feedback, no crash impulse: "+vehicle)
				var mirror := VehicleState.new()
				mirror.heading = -deg_to_rad(angle)
				mirror.velocity = mirror.forward()*speed
				ground._bounce(mirror,Vector2.RIGHT,config)
				expect(is_equal_approx(mirror.velocity.x,-state.velocity.x) and is_equal_approx(mirror.velocity.y,state.velocity.y) and is_equal_approx(mirror.yaw_rate,-state.yaw_rate),"left/right response is mirrored")
		var head_on := VehicleState.new()
		head_on.velocity = Vector2(0,20)
		ground._bounce(head_on,Vector2.UP,config)
		expect(is_equal_approx(head_on.velocity.y,-20*config.restitution) and head_on.yaw_rate==0.0,"centered hard crash retains authored recoil without spin")
		expect(head_on.collision_impulse.length()>20.0 and head_on.scrape_strength==0.0,"hard crash supplies actual impact, no scrape")
	for cell_size: float in [0.25,0.5]:
		for rotation: float in [0.0,30.0,45.0,75.0]:
			var normal: Vector2 = Vector2.LEFT.rotated(deg_to_rad(rotation))
			var tangent := Vector2(normal.y,-normal.x)
			for offset: float in [0.0,cell_size*0.37]:
				var wall: NativeTrack = make_wall(normal,cell_size,offset)
				for vehicle: String in VehicleCatalog.IDS:
					for angle: float in [1.0,5.0]:
						var speed: float = minf(30.0,VehicleCatalog.config(vehicle).maximum_speed)
						var result: Dictionary = trace_wall(wall,normal,tangent,angle,false,vehicle,speed,60)
						var repeat: Dictionary = trace_wall(wall,normal,tangent,angle,false,vehicle,speed,60)
						expect(result==repeat,"translated/rotated contacts replay exactly: "+vehicle)
						# Considerably stronger owner-requested scrub replaces the old
						# cumulative-speed/travel target. Each tick must still move
						# consistently with its incoming momentum, never falsely freeze.
						var slides: bool = float(result.progress_m)>0.0 and float(result.minimum_travel_fraction)>0.5 and float(result.max_contact_speed_loss_percent)<20.0
						expect(slides,"sustained shallow scrape never snags: %s grid%.2f rotation%.0f phase%.3f angle%.0f" % [vehicle,cell_size,rotation,offset,angle])
						if not slides: print("BAD_SLIDE: ",JSON.stringify(result))
	# Assert the owner's requested outcome, not merely a larger coefficient.
	var reference_wall: NativeTrack = make_wall(Vector2.LEFT,0.5)
	for powered: bool in [false,true]:
		var result: Dictionary = trace_wall(reference_wall,Vector2.LEFT,Vector2.UP*-1.0,2.0,powered)
		expect(float(result.final_speed_kmh)<90.0 if not powered else float(result.final_speed_kmh)<120.0,"2 degree contact produces considerable slowdown while coasting or powered")
		expect(float(result.final_speed_kmh)>50.0 and float(result.minimum_travel_fraction)>0.5,"stronger scrub continues sliding rather than stopping")
	_blockers()
	await _feedback()
	print("SHALLOW_COLLISION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _blockers() -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var wall: NativeTrack = make_wall(Vector2.LEFT,0.5)
	# A transverse solid row is a genuine second obstacle, not a wall seam.
	for x: int in range(wall.grid_width): wall.cells[72*wall.grid_width+x] = 4
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(-config.collision_radius-0.002,0),deg_to_rad(2.0))
	sim.state.velocity = sim.state.forward()*30.0
	var frame := DriveFrame.sample(0,1,0)
	var safe: bool = true
	for tick: int in range(240):
		sim.step(frame,wall)
		safe = safe and wall._contact(sim.state.position,config.collision_radius,sim.state.track_elevated).z==0.0
	expect(safe and sim.state.position.y<=3.5-config.collision_radius,"closed corner blocks full footprint throughout powered sliding")
	var old_velocity: Vector2 = sim.state.velocity
	for x: int in range(wall.grid_width): wall.cells[72*wall.grid_width+x] = 0
	sim.step(frame,wall)
	expect(sim.state.velocity.length() <= old_velocity.length()+config.longitudinal_grip*VehicleSimulation.STEP+0.02,"blocked contact does not bank speed for release")
	var flat: NativeTrack = make_wall(Vector2.LEFT,0.5)
	sim.reset(Vector2(-config.collision_radius-0.002,0),deg_to_rad(2.0))
	sim.state.velocity = sim.state.forward()*20.0
	for tick: int in range(60): sim.step(DriveFrame.new(),flat)
	var x_before: float = sim.state.position.x
	for tick: int in range(30): sim.step(DriveFrame.sample(-1,0,0),flat)
	expect(sim.state.position.x<x_before-0.1,"steering away immediately leaves the wall")
	sim.reset(Vector2(-config.collision_radius-0.002,0),PI-deg_to_rad(2.0))
	sim.state.velocity = -sim.state.forward()*5.0
	for tick: int in range(90): sim.step(DriveFrame.sample(0,0,1),flat)
	expect(sim.state.position.y>2.0 and flat._contact(sim.state.position,config.collision_radius,false).z==0.0,"reverse scrape keeps travelling without overlap")
	# Incoming sprint must not cross even a single-cell wall.
	var state := VehicleState.new()
	state.position = Vector2(15,0)
	state.velocity = Vector2(120,0)
	flat.resolve(state,Vector2(-10,0),config)
	expect(state.position.x<= -config.collision_radius and flat._contact(state.position,config.collision_radius,false).z==0.0,"swept high-speed input cannot tunnel through solid wall")

func _feedback() -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var ground := PlaygroundData.new()
	var state := VehicleState.new()
	state.heading = deg_to_rad(2.0)
	state.velocity = state.forward()*30.0
	ground._bounce(state,Vector2.LEFT,config)
	var camera := FollowCamera.new()
	root.add_child(camera)
	camera.add_collision_impact(state.collision_impulse)
	expect(camera.trauma==0.0,"scrape does not create crash camera trauma")
	var car := CarVisual.new()
	root.add_child(car)
	car.add_scrape(state)
	expect(car.suspension_speed.length()>0.0 and car.suspension_speed.length()<0.01,"scrape adds small bounded body loading")
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",config)
	audio.present(state,DriveFrame.new(),null,0.016,false)
	var events_before: int = audio.event_count
	audio.scrape(state.scrape_strength,state.scrape_speed)
	audio.present(state,DriveFrame.new(),null,0.016,false)
	expect(float(audio.levels.scrape)>0.0 and audio.event_count==events_before,"recorded friction loop follows scrape without impact sound")
	for frame: int in range(30): audio.present(state,DriveFrame.new(),null,0.016,false)
	expect(float(audio.levels.scrape)<0.0001,"scrape sound decays after leaving the wall")
	audio.scrape(1.0,30.0)
	audio.present(state,DriveFrame.new(),null,0.016,true)
	expect(audio.pending_scrape==0.0 and float(audio.levels.scrape)==0.0,"pause clears queued scrape and suspends its sound")
	audio.reset()
	expect(float(audio.levels.scrape)==0.0 and audio.impact_count==0,"restart clears both contact channels")
	var sim := VehicleSimulation.new(config)
	sim.state = state
	sim.step(DriveFrame.new())
	expect(sim.state.collision_impulse==Vector2.ZERO and sim.state.scrape_strength==0.0,"contact output expires on the next clear step")
	state.velocity = Vector2(0,20)
	ground._bounce(state,Vector2.UP,config)
	camera.add_collision_impact(state.collision_impulse)
	expect(camera.trauma>0.0,"real head-on crash retains camera feedback")
	car.queue_free()
	camera.queue_free()
	audio.queue_free()
	await process_frame
	await process_frame
