extends SceneTree
## First-contact grass onset, real kerb geometry, swept crossings and lifecycle.
var OUT: String = "res://../docs/evidence/grass-kerb-audio-2026-10-11"
var checks: int = 0
var failures: int = 0
var baseline: bool = false
class ObservedAudio extends VehicleAudio:
	var emitted: Array[String] = []
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		emitted.append(clip)
		super._event(clip,amplitude,pitch,debris)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+text)

func make_track(with_kerb: bool) -> NativeTrack:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "pine"
	track.metadata.erase("creator_document")
	track.cells.fill(0)
	track.hazard_objects.clear()
	track.creator_bridges.clear()
	track.kerbs = RoadKerbs.new()
	track.kerbs.extent = track.half_extent
	track.kerbs.grid = Vector2i(track.grid_width,track.grid_height)
	track.kerbs.cell_size = track.cell_size
	track.kerbs.blocked.resize(track.cells.size())
	if with_kerb: track.kerbs._strip(Vector2(-20,0),Vector2(20,0),Vector2(-20,.75),Vector2(20,.75),40,80,120)
	return track

func run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var audio := ObservedAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var track: NativeTrack = make_track(false)
	var input := DriveFrame.new()
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		audio.configure(id,VehicleCatalog.config(id))
		var state := VehicleState.new()
		state.velocity = Vector2(0,18)
		track.cells.fill(0)
		for frame: int in range(12): audio.present(state,input,track,1.0/60,false)
		track.cells.fill(1)
		audio.present(state,input,track,1.0/60,false)
		var first: float = float(audio.levels.grass)
		for frame: int in range(60): audio.present(state,input,track,1.0/60,false)
		var settled: float = float(audio.levels.grass)
		check(first>=settled*.85,"grass reaches audible level on first displayed contact: "+id)
		check(first>.35,"grass is clear against the engine immediately: "+id)
		rows.append({"car":id,"first":first,"settled":settled,"ratio":first/settled})
		track.cells.fill(0)
		audio.present(state,input,track,1.0/60,false)
		check(float(audio.levels.grass)==0,"return to asphalt clears grass immediately")
		await process_frame
	if not baseline:
		audio.configure("compact",VehicleCatalog.config("compact"))
		var onset := VehicleState.new()
		onset.velocity = Vector2(0,18)
		track.cells.fill(0)
		audio.present(onset,input,track,.016,false)
		track.cells.fill(1)
		var snapshot: Array = onset.snapshot()
		audio.begin_physics_feedback()
		audio.call("resolved_contact",onset,track,onset.velocity)
		check(float(audio.levels.grass)>.30,"grass starts on live wheel contact before the next render")
		check(onset.snapshot()==snapshot,"immediate grass observer does not alter driving")
		# Only the wheels actually over grass participate in the initial mix.
		track.cells.fill(0)
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if (x+.5)*track.cell_size-track.half_extent.x>=0: track.cells[y*track.grid_width+x] = 1
		audio.reset()
		audio.present(onset,input,track,1.0/60,false)
		check(audio.surface_model.grass==.5 and float(audio.levels.grass)>.25,"first two-wheel grass contact is audible without waiting for the car centre")
		await shoulder_contact(audio)
	var kerb_track: NativeTrack = make_track(true)
	check(audio.layers.has("kerb_roll"),"dedicated continuous tyre/body kerb rumble exists")
	if audio.layers.has("kerb_roll"):
		for id: String in VehicleCatalog.IDS:
			audio.configure(id,VehicleCatalog.config(id))
			var state := VehicleState.new()
			state.position = Vector2(0,.4+VehicleCatalog.config(id).track_width*.5)
			state.heading = PI*.5
			state.velocity = Vector2(18,0)
			for frame: int in range(12): audio.present(state,input,kerb_track,1.0/60,false)
			check(float(audio.levels.kerb_roll)>.25,"riding real kerb keeps rumble audible: "+id)
			for context: String in ["stationary","air","roll","deck","pause","countdown"]:
				audio.reset()
				state.velocity = Vector2.ZERO if context=="stationary" else Vector2(18,0)
				state.jump_height = 1.0 if context=="air" else 0.0
				state.roll_ticks = 1 if context=="roll" else 0
				state.track_elevated = context=="deck"
				audio.present(state,input,kerb_track,.016,context=="pause",context=="countdown")
				check(float(audio.levels.kerb_roll)==0,"no false kerb rumble: "+context)
			await process_frame
		# Actual canonical kerb crossings; event must start before presentation.
		for speed: float in [8.0,20.0,40.0]:
			audio.configure("compact",VehicleCatalog.config("compact"))
			audio.emitted.clear()
			var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
			var plain := VehicleSimulation.new(VehicleCatalog.config("compact"))
			sim.reset(Vector2(0,-4),0)
			plain.reset(Vector2(0,-4),0)
			sim.state.velocity = Vector2(0,speed)
			plain.state.velocity = sim.state.velocity
			var before_render: int = 0
			var equivalent: bool = true
			for tick: int in range(150):
				var previous: Vector2 = sim.state.position
				var heading: float = sim.state.heading
				var incoming: Vector2 = sim.state.velocity
				sim.step(input,kerb_track)
				plain.step(input,kerb_track)
				audio.begin_physics_feedback()
				audio.call("resolved_contact",sim.state,kerb_track,incoming,previous,heading)
				before_render = int(audio.get("kerb_count"))
				if tick%4==0: audio.present(sim.state,input,kerb_track,VehicleSimulation.STEP*4,false)
				equivalent = equivalent and sim.state.snapshot()==plain.state.snapshot()
				if tick%20==0: await process_frame
			check(before_render>0,"canonical axle crossing starts bump before render: "+str(speed))
			check(equivalent and sim.state.collision_count==0,"audio never changes kerb physics or creates crashes")
			var events: int = int(audio.get("kerb_count"))
			for tick: int in range(100):
				var previous: Vector2 = sim.state.position
				sim.step(input,kerb_track)
				audio.begin_physics_feedback()
				audio.call("resolved_contact",sim.state,kerb_track,sim.state.velocity,previous,sim.state.heading)
			check(int(audio.get("kerb_count"))==events,"no repeated kerb bumps after leaving kerb, including subsequent legal wall impacts")
	var report := FileAccess.open(OUT.path_join("baseline.json" if baseline else "grass-onset.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	if DisplayServer.get_name()!="headless" and not baseline and audio.layers.has("kerb_roll"): await capture(audio)
	if not baseline: await game_crossing(kerb_track)
	audio.free()
	await create_timer(.15).timeout
	print("GRASS_KERB_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func shoulder_contact(audio: ObservedAudio) -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "pine"
	doc.pieces = [RoadPieces.create("curve",Vector2.ZERO,0,12)]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var found: bool = false
	var before: float = 0
	var after: float = 0
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.cells[y*track.grid_width+x]!=5: continue
			var state := VehicleState.new()
			state.position = Vector2((x+.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+.5)*track.cell_size)
			state.velocity = Vector2(0,18)
			var original: Dictionary = track.metadata.creator_document
			track.metadata.erase("creator_document")
			audio.surface_model.sample(state,DriveFrame.new(),track,.016,true)
			before = audio.surface_model.grass
			track.metadata.creator_document = original
			audio.surface_model.sample(state,DriveFrame.new(),track,.016,true)
			after = audio.surface_model.grass
			if after>before:
				found = true
				break
		if found: break
	check(found,"actual creator grass-fringed raster shoulder begins off-road feedback before the entire metre-wide band is crossed")
	print("CREATOR_SHOULDER_AUDIO: ",JSON.stringify({"native_grass":before,"fringed_grass":after}))
	await process_frame

func game_crossing(track: NativeTrack) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = track
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.production_mode = false
	game.sim.reset(Vector2(0,-4),0)
	game.sim.state.velocity = Vector2(0,18)
	game.previous_position = game.sim.state.position
	game.previous_heading = 0
	var peak: float = 0
	for tick: int in range(100):
		game._physics_process(VehicleSimulation.STEP)
		if tick%4==0:
			game._process(VehicleSimulation.STEP*4)
			peak = maxf(peak,float(game.vehicle_audio.levels.kerb_roll))
		if tick%10==0: await process_frame
	check(game.vehicle_audio.kerb_count>0 and peak>.20,"actual Game callback dispatches crossing bumps and rumble with coarse rendering")
	check(game.sim.state.collision_count==0,"actual kerb feedback remains separate from a crash")
	print("GAME_KERB_AUDIO: ",JSON.stringify({"bumps":game.vehicle_audio.kerb_count,"rumble_peak":peak}))
	game.free()
	await process_frame

func capture(audio: ObservedAudio) -> void:
	var buses: Array[int] = [0]
	for name: String in ["GrassReview","KerbReview"]:
		var bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,name)
		AudioServer.set_bus_send(bus,"Vehicle")
		buses.append(bus)
	(audio.layers.grass as AudioStreamPlayer).bus = "GrassReview"
	(audio.layers.kerb_roll as AudioStreamPlayer).bus = "KerbReview"
	var records: Array[AudioEffectRecord] = []
	for bus: int in buses:
		var recorder := AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,recorder)
		records.append(recorder)
	var traces: Array[Dictionary] = []
	for kind: String in ["grass-entry","kerb-cross","kerb-ride"]:
		var track: NativeTrack = make_track(kind!="grass-entry")
		if kind=="grass-entry":
			for y: int in range(track.grid_height):
				for x: int in range(track.grid_width):
					if (x+.5)*track.cell_size-track.half_extent.x>=0: track.cells[y*track.grid_width+x] = 1
		audio.configure("compact",VehicleCatalog.config("compact"))
		await create_timer(.15).timeout
		for recorder: AudioEffectRecord in records: recorder.set_recording_active(true)
		var trace: Dictionary = {"case":kind,"first_grass_s":-1.0,"first_kerb_s":-1.0,"grass_first_level":0.0}
		var state := VehicleState.new()
		var last_position := Vector2(-6,0)
		var elapsed: float = 0
		var last_us: int = Time.get_ticks_usec()
		while elapsed<3.0:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var delta: float = minf(float(now-last_us)/1000000.0,.1)
			last_us = now
			elapsed += delta
			if kind=="grass-entry":
				state.heading = PI*.5
				state.velocity = Vector2(12,0)
				state.position = Vector2((elapsed-.8)*12,0)
			elif kind=="kerb-cross":
				state.heading = 0
				state.velocity = Vector2(0,12)
				state.position = Vector2(0,-5+elapsed*12)
			else:
				state.heading = PI*.5
				state.velocity = Vector2(12,0)
				state.position = Vector2(-15+elapsed*12,.4+VehicleCatalog.config("compact").track_width*.5)
			audio.begin_physics_feedback()
			audio.call("resolved_contact",state,track,state.velocity,last_position,state.heading)
			if audio.surface_model.grass>0.0 and float(trace.first_grass_s)<0:
				trace.first_grass_s = elapsed
				trace.grass_first_level = audio.levels.grass
			if audio.pending_kerb>0.0 and float(trace.first_kerb_s)<0: trace.first_kerb_s = elapsed
			audio.present(state,DriveFrame.new(),track,delta,elapsed>2.6)
			last_position = state.position
		for index: int in range(records.size()):
			records[index].set_recording_active(false)
			var sample: AudioStreamWAV = records[index].get_recording()
			var suffix: String = ["","-grass","-kerb"][index]
			check(sample.save_to_wav(OUT.path_join(kind+suffix+".wav"))==OK,"native mixed/isolated recording saved: "+kind+suffix)
		traces.append(trace)
	var report := FileAccess.open(OUT.path_join("native-contact-timing.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(traces,"\t"))
	report.close()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.remove_bus(buses[2])
	AudioServer.remove_bus(buses[1])
