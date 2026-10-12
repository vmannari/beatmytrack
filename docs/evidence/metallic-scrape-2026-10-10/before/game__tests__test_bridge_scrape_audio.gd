extends SceneTree
## Real creator rail geometry, parallel contact, separation and full native mix.
const OUT: String = "res://../docs/evidence/bridge-screech-2026-10-10"
var checks: int = 0
var failures: int = 0
var baseline: bool = false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func rail_position(track: NativeTrack, span: Dictionary, config: HandlingConfig, side: float) -> Vector2:
	var origin := Vector2(span.position[0],span.position[1])
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	var normal: Vector2 = axis.orthogonal()*side
	var center: Vector2 = origin+axis*float(span.length)*.5
	var lo: float = 0.0
	var hi: float = float(span.width)*.5
	for iteration: int in range(24):
		var mid: float = (lo+hi)*.5
		if track.overlaps_obstacle(center+normal*mid,config.collision_radius,true): hi = mid
		else: lo = mid
	return center+normal*(lo-.001)

func run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var span: Dictionary = track.creator_bridges[0]
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		for side: float in [-1.0,1.0]:
			var away: Vector2 = -axis.orthogonal()*side
			for reverse: bool in [false,true]:
				for speed: float in [4.0,10.0,24.0]:
					audio.reset()
					var state := VehicleState.new()
					state.position = rail_position(track,span,config,side)
					state.heading = atan2(axis.x,axis.y)
					state.track_elevated = true
					state.velocity = axis*speed*(-1.0 if reverse else 1.0)
					var snapshot: Array = state.snapshot()
					for frame: int in range(12):
						audio.begin_physics_feedback()
						audio.resolved_contact(state,track,state.velocity)
						audio.present(state,DriveFrame.sample(0,1,0),track,1.0/60.0,false)
					var level: float = float(audio.levels.scrape)
					check(level>.30,"parallel creator bridge rail has clear screech: "+id+str(side)+str(reverse)+str(speed))
					check(audio.impact_count==0 and state.snapshot()==snapshot,"parallel screech creates no crash or canonical mutation")
					var face: Vector2 = track.collision_normal(state.position,config.collision_radius+.025,true)
					rows.append({"car":id,"side":side,"reverse":reverse,"speed":speed,"level":level,"normal":[face.x,face.y],"outward":state.velocity.dot(face)})
					# Moving away, even while still in contact range, stops rubbing.
					state.velocity += away*2.0
					for frame: int in range(36):
						audio.begin_physics_feedback()
						audio.resolved_contact(state,track,state.velocity)
						audio.present(state,DriveFrame.new(),track,1.0/60.0,false)
					check(float(audio.levels.scrape)<.0001,"steering away releases screech")
					# A nearby pass and a crossing below the deck are silent.
					for context: String in ["nearby","underpass","stationary","air","roll","countdown","pause"]:
						audio.reset()
						state.position = rail_position(track,span,config,side)+away*(.12 if context=="nearby" else 0.0)
						state.track_elevated = context!="underpass"
						state.velocity = Vector2.ZERO if context=="stationary" else axis*speed
						state.jump_height = 1.0 if context=="air" else 0.0
						state.roll_ticks = 1 if context=="roll" else 0
						audio.begin_physics_feedback()
						audio.resolved_contact(state,track,state.velocity)
						audio.present(state,DriveFrame.new(),track,.016,context=="pause",context=="countdown")
						check(float(audio.levels.scrape)==0.0,"no false bridge screech: "+context)
					await process_frame
	var report := FileAccess.open(OUT.path_join("baseline-matrix.json" if baseline else "contact-matrix.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	if DisplayServer.get_name()!="headless": await capture(audio,track,span)
	# Capture the vehicle mix before Game exit can resume the unrelated menu music.
	await game_bridge_slide(track,span)
	audio.free()
	await create_timer(.15).timeout
	print("BRIDGE_SCRAPE_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func game_bridge_slide(track: NativeTrack, span: Dictionary) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = track
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.production_mode = false
	game.vehicle_audio.use_windows_impacts = false
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	game.sim.reset(rail_position(track,span,game.handling,1),atan2(axis.x,axis.y))
	game.sim.state.track_elevated = true
	game.sim.state.velocity = axis*12.0
	game.previous_position = game.sim.state.position
	game.previous_heading = game.sim.state.heading
	var audible_ticks: int = 0
	var peak: float = 0.0
	for tick: int in range(48):
		game._physics_process(VehicleSimulation.STEP)
		game._process(VehicleSimulation.STEP)
		peak = maxf(peak,float(game.vehicle_audio.levels.scrape))
		if float(game.vehicle_audio.levels.scrape)>.20: audible_ticks += 1
		if tick%6==0: await process_frame
	check(peak>.30 and audible_ticks>20,"actual Game callbacks keep parallel bridge contact audible")
	check(game.sim.state.track_elevated,"real drive remains above the bridge")
	print("GAME_BRIDGE_SCRAPE: ",JSON.stringify({"peak":peak,"audible_ticks":audible_ticks,"position":[game.sim.state.position.x,game.sim.state.position.y]}))
	game.free()
	await process_frame

func capture(audio: VehicleAudio, track: NativeTrack, span: Dictionary) -> void:
	var friction_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(friction_bus,"ScrapeReview")
	AudioServer.set_bus_send(friction_bus,"Vehicle")
	(audio.layers.scrape as AudioStreamPlayer).bus = "ScrapeReview"
	var records: Array[AudioEffectRecord] = []
	for bus: int in [0,AudioServer.get_bus_index("Engine"),friction_bus]:
		var record := AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,record)
		records.append(record)
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	for speed: float in [4.0,12.0,24.0]:
		audio.configure("compact",VehicleCatalog.config("compact"))
		var state := VehicleState.new()
		state.position = rail_position(track,span,VehicleCatalog.config("compact"),1)
		state.velocity = axis*speed
		state.heading = atan2(axis.x,axis.y)
		state.track_elevated = true
		for warm: int in range(30):
			audio.begin_physics_feedback()
			audio.resolved_contact(state,track,state.velocity)
			audio.present(state,DriveFrame.sample(0,1,0),track,.05,false)
		await create_timer(.15).timeout
		for record: AudioEffectRecord in records: record.set_recording_active(true)
		var elapsed: float = 0.0
		var last_us: int = Time.get_ticks_usec()
		while elapsed<3.0:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var delta: float = minf(float(now-last_us)/1000000.0,.1)
			last_us = now
			elapsed += delta
			audio.begin_physics_feedback()
			audio.resolved_contact(state,track,state.velocity)
			audio.present(state,DriveFrame.sample(0,1,0),track,delta,elapsed>2.6)
		for index: int in range(3):
			records[index].set_recording_active(false)
			var sample: AudioStreamWAV = records[index].get_recording()
			var name: String = "%s-%d-%s.wav"%["before" if baseline else "after",int(speed),["mix","engine","scrape"][index]]
			check(sample.save_to_wav(OUT.path_join(name))==OK,"native full-mix recording saved: "+name)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	var engine_bus: int = AudioServer.get_bus_index("Engine")
	AudioServer.remove_bus_effect(engine_bus,AudioServer.get_bus_effect_count(engine_bus)-1)
	AudioServer.remove_bus(friction_bus)
