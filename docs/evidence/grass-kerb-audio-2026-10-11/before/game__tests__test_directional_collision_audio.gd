extends "res://tests/analyze_shallow_collisions.gd"
## Actual resolved contacts, directional mixing, lifecycle and native PCM previews.
const OUT: String = "res://../docs/evidence/directional-collision-audio-2026-10-10"
var audio_checks: int = 0
var audio_failures: int = 0

class ObservedAudio extends VehicleAudio:
	var emitted: Array[Dictionary] = []
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		emitted.append({"clip":clip,"amplitude":amplitude,"pitch":pitch})
		super._event(clip,amplitude,pitch,debris)

func expect(ok: bool, message: String) -> void:
	audio_checks += 1
	if not ok:
		audio_failures += 1
		print("FAIL: "+message)

func run() -> void:
	var audio := ObservedAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var response := PlaygroundData.new()
	var frame := DriveFrame.new()
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		audio.configure(id,VehicleCatalog.config(id))
		for elevated: bool in [false,true]:
			for speed: float in [3.0,12.0,30.0]:
				for angle: float in [2.0,20.0,45.0,90.0]:
					audio.reset()
					audio.emitted.clear()
					var state := VehicleState.new()
					state.track_elevated = elevated
					state.heading = deg_to_rad(angle)
					state.velocity = state.forward()*speed
					var incoming: Vector2 = state.velocity
					response._bounce(state,Vector2.LEFT,VehicleCatalog.config(id))
					var before: Array = state.snapshot()
					audio.begin_physics_feedback()
					audio.resolved_contact(state,null,incoming)
					# First physics tick is audible without a prior render latch.
					var rubbing: float = audio.pending_scrape
					for render: int in range(8):
						if angle==2.0: audio.scrape(state.scrape_strength,state.scrape_speed)
						audio.present(state,frame,null,.016,false)
					expect(state.snapshot()==before,"contact observer preserves canonical state: "+id)
					if angle==2.0:
						expect(audio.impact_count==0 and rubbing>0.0 and float(audio.levels.scrape)>0.0,"shallow contact uses sustained screech without crash: "+id)
					if angle==90.0:
						var meaningful: bool = state.collision_impulse.length()>1.2
						expect(audio.impact_count==(1 if meaningful else 0) and rubbing<.001,"direct collision follows retained tiny-contact threshold without sideways screech: "+id)
						if speed==30.0: expect(audio.emitted[0].clip=="impact_2" and float(audio.emitted[0].amplitude)>.9,"fast direct hit is strong heavy crash: "+id)
					rows.append({"car":id,"elevated":elevated,"speed":speed,"angle":angle,"scrape":rubbing,"events":audio.emitted.duplicate(true)})
					await process_frame
	await live_wall_cases(audio)
	# Compare identical impulse magnitudes with different closing directions.
	var gains: Array[float] = []
	for incoming: Vector2 in [Vector2(4,28),Vector2(28,4)]:
		audio.reset()
		audio.emitted.clear()
		audio.begin_physics_feedback()
		audio.collision(Vector2(-20,0),incoming,Vector2.LEFT)
		gains.append(float(audio.emitted[0].amplitude))
	expect(gains[1]>gains[0]*2.0,"head-on crash is substantially stronger than same-impulse glancing hit")
	expect((audio.layers.scrape as AudioStreamPlayer).stream!=audio.layers.loose.stream,"barrier friction has its own cleared screech recording")
	var state := VehicleState.new()
	state.velocity = Vector2(0,30)
	audio.reset()
	audio.begin_physics_feedback()
	for render: int in range(12):
		audio.scrape(.2,30)
		audio.present(state,frame,null,.016,false)
	var moving_level: float = float(audio.levels.scrape)
	expect(moving_level>.20,"light high-speed scrape is clearly audible")
	for render: int in range(30): audio.present(state,frame,null,.016,false)
	expect(float(audio.levels.scrape)<.0001,"screech releases promptly after leaving barrier")
	audio.scrape(1,0)
	audio.present(state,frame,null,.1,false)
	expect(float(audio.levels.scrape)<.0001,"stationary barrier pressure cannot screech")
	for mode: String in ["pause","countdown","air","roll"]:
		audio.reset()
		audio.begin_physics_feedback()
		audio.scrape(1,30)
		state.jump_height = 1.0 if mode=="air" else 0.0
		state.roll_ticks = 1 if mode=="roll" else 0
		audio.present(state,frame,null,.016,mode=="pause",mode=="countdown")
		expect(float(audio.levels.scrape)==0.0 and audio.pending_scrape==0.0,"silent contact lifecycle: "+mode)
	state.jump_height = 0
	state.roll_ticks = 0
	audio.reset()
	expect(audio.impact_count==0 and audio.pending_scrape==0 and float(audio.levels.scrape)==0,"retry/rewind clears contact history")
	expect(audio.get_child_count()==22,"dedicated recording retains bounded voice count")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report := FileAccess.open(OUT.path_join("contact-matrix.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	if DisplayServer.get_name()!="headless": await capture(audio)
	audio.free()
	await create_timer(.15).timeout
	print("DIRECTIONAL_COLLISION_AUDIO: %d checks, %d failures"%[audio_checks,audio_failures])
	quit(1 if audio_failures else 0)

func live_wall_cases(audio: ObservedAudio) -> void:
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		for elevated: bool in [false,true]:
			var wall: NativeTrack = make_wall(Vector2.LEFT,.5)
			if elevated:
				wall.deck_cells = wall.cells.duplicate()
				wall.cells.fill(0)
				wall.bridge_height = 2.0
				wall.bridge_axis = Vector2(0,1)
			var sim := VehicleSimulation.new(config)
			var plain := VehicleSimulation.new(config)
			var start := Vector2(-config.collision_radius-.002,0)
			sim.reset(start,deg_to_rad(2.0))
			plain.reset(start,deg_to_rad(2.0))
			sim.state.velocity = sim.state.forward()*30.0
			plain.state.velocity = sim.state.velocity
			audio.reset()
			var rubbing: int = 0
			var peak_level: float = 0.0
			var equivalent: bool = true
			var layer_correct: bool = true
			for tick: int in range(90):
				var incoming: Vector2 = sim.state.velocity
				var frame := DriveFrame.sample(0,1,0)
				sim.step(frame,wall)
				plain.step(frame,wall)
				audio.begin_physics_feedback()
				audio.resolved_contact(sim.state,wall,incoming)
				if audio.pending_scrape>0: rubbing += 1
				audio.present(sim.state,frame,wall,VehicleSimulation.STEP,false)
				peak_level = maxf(peak_level,float(audio.levels.scrape))
				equivalent = equivalent and sim.state.snapshot()==plain.state.snapshot()
				layer_correct = layer_correct and sim.state.track_elevated==elevated
				if tick%15==0: await process_frame
			print("LIVE_WALL_AUDIO: ",JSON.stringify({"car":id,"elevated":elevated,"rubbing_ticks":rubbing,"peak_level":peak_level,"end_level":audio.levels.scrape,"end_scrape":sim.state.scrape_strength}))
			expect(rubbing>30 and peak_level>.05,"actual continuous fence/deck scrape produces sustained screech during contact: "+id+str(elevated))
			expect(audio.impact_count==0,"actual shallow fence/deck slide produces no repeated crashes: "+id+str(elevated))
			expect(layer_correct and equivalent,"actual correct ground/deck collisions preserve every driving snapshot: "+id+str(elevated))

func capture(audio: ObservedAudio) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Tires"),true)
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder)
	for kind: String in ["fence-scrape","bridge-scrape","oblique-impact","head-on-crash"]:
		audio.reset()
		await create_timer(.15).timeout
		recorder.set_recording_active(true)
		var state := VehicleState.new()
		var response := PlaygroundData.new()
		var clock: float = 0.0
		var hit: bool = false
		while clock<3.0:
			await process_frame
			var delta: float = minf(root.get_process_delta_time(),.1)
			clock += delta
			audio.begin_physics_feedback()
			var scraping: bool = kind.ends_with("scrape")
			if clock>.25 and clock<2.25 and (scraping or not hit):
				state = VehicleState.new()
				state.track_elevated = kind=="bridge-scrape"
				state.heading = deg_to_rad(2.0 if scraping else (35.0 if kind=="oblique-impact" else 90.0))
				state.velocity = state.forward()*(12.0+clock*6.0 if scraping else 30.0)
				var incoming: Vector2 = state.velocity
				response._bounce(state,Vector2.LEFT,VehicleCatalog.config("compact"))
				audio.resolved_contact(state,null,incoming)
				hit = true
			audio.present(state,DriveFrame.new(),null,delta,clock>2.7)
			# Isolate contact channels, leaving the real bus ceilings in place.
			for key: String in audio.layers:
				if key!="scrape": (audio.layers[key] as AudioStreamPlayer).volume_linear = 0.0
		recorder.set_recording_active(false)
		var sample: AudioStreamWAV = recorder.get_recording()
		expect(sample.save_to_wav(OUT.path_join(kind+".wav"))==OK,"native PCM saved: "+kind)
		var peak: int = 0
		for offset: int in range(0,sample.data.size(),2): peak = maxi(peak,absi(sample.data.decode_s16(offset)))
		expect(peak>1000 and peak<30000,"audible contact with output headroom: "+kind)
		var tail_peak: int = 0
		for offset: int in range(maxi(0,sample.data.size()-sample.mix_rate/2),sample.data.size(),2): tail_peak = maxi(tail_peak,absi(sample.data.decode_s16(offset)))
		expect(tail_peak==0,"paused native contact tail is silent: "+kind)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Tires"),false)
