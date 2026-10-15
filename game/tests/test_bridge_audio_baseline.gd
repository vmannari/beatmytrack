extends SceneTree
## Bridge mouth footprint/layer regression, with real native cars and clear driving.
var output: String = "res://../docs/evidence/bridge-contact-audio-2026-10-14/before"
var checks: int = 0
var failures: int = 0
var baseline: bool = false
var capture: bool = false
var capture_only: bool = false

class ObservedAudio extends "res://tests/fixtures/bridge_audio_before/vehicle_audio.gd":
	var emitted: Array[Dictionary] = []
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		emitted.append({"clip":clip,"gain":amplitude,"pitch":pitch})
		super._event(clip,amplitude,pitch,debris)

class CoastingInput extends DriverInput:
	func sample() -> DriveFrame: return DriveFrame.new()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output = argument.trim_prefix("--evidence-dir=")
		if argument=="--baseline": baseline = true
		if argument=="--capture": capture = true
		if argument=="--capture-only": capture_only = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	if capture_only:
		var car := CarVisual.new()
		car.vehicle_id = "compact"
		root.add_child(car)
		var audio := ObservedAudio.new()
		audio.use_windows_impacts = false
		root.add_child(audio)
		audio.configure("compact",VehicleCatalog.config("compact"),car)
		await record_mix(audio,track)
		audio.free()
		car.free()
		print("BRIDGE_NATIVE_CAPTURE: %d checks, %d failures"%[checks,failures])
		quit(1 if failures else 0)
		return
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var audio := ObservedAudio.new()
		audio.use_windows_impacts = false
		root.add_child(audio)
		audio.configure(id,config,car)
		for span_index: int in range(track.creator_bridges.size()):
			var span: Dictionary = track.creator_bridges[span_index]
			var origin := Vector2(span.position[0],span.position[1])
			var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
			for reverse: bool in [false,true]:
				for offset: float in [-1.0,0.0,1.0]:
					audio.reset()
					var state := VehicleState.new()
					state.heading = atan2(axis.x,axis.y)+(PI if reverse else 0)
					var direction: Vector2 = axis*(-1 if reverse else 1)
					state.position = origin+axis*(float(span.length)+4 if reverse else -4)+axis.orthogonal()*offset
					state.velocity = direction*18
					var sounds: Array[Dictionary] = []
					var physical: int = 0
					for step: int in range(ceili((float(span.length)+8)/.15)):
						var from: Vector2 = state.position
						state.position += direction*.15
						state.velocity = direction*18
						state.collision_impulse = Vector2.ZERO
						track.resolve(state,from,config)
						if state.collision_impulse!=Vector2.ZERO: physical += 1
						state.tick += 1
						var count: int = audio.impact_count
						var before: Array = state.snapshot()
						audio.begin_physics_feedback()
						audio.resolved_contact(state,track,direction*18,from,state.heading)
						check(before==state.snapshot(),"sound does not alter bridge state")
						if audio.impact_count>count:
							sounds.append({"u":CreatorBridges.local_point(span,state.position).x,"layer":state.track_elevated,"physical":state.collision_impulse.length(),"normal":[audio.visible_contact.normal.x,audio.visible_contact.normal.y]})
						if step%4==0: audio.present(state,DriveFrame.new(),track,1.0/30,false)
					rows.append({"car":id,"span":span_index,"reverse":reverse,"offset":offset,"physical_hits":physical,"crash_sounds":audio.impact_count,"bridge_cues":audio.get("bridge_count"),"sounds":sounds})
					check(physical==0,"bridge sweep stays physically clear")
					if not baseline:
						check(sounds.is_empty(),"clear bridge traversal has no glass/crash: "+id+str(span_index)+str(reverse)+str(offset))
						check(int(audio.get("bridge_count"))==2,"one soft entrance and exit contact: "+id+str(span_index)+str(reverse)+str(offset))
		if not baseline: await guards(audio,track)
		if id=="compact" and capture: await record_mix(audio,track)
		car.free()
		audio.free()
		await process_frame
	var report := FileAccess.open(output.path_join("bridge-sweeps.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	var false_sounds: int = 0
	for row: Dictionary in rows:
		if row.physical_hits==0: false_sounds += int(row.crash_sounds)
	print("BRIDGE_CONTACT_DIAG: ",JSON.stringify({"sweeps":rows.size(),"false_crash_sounds":false_sounds}))
	if not baseline: await game_crossing(track)
	await create_timer(.15).timeout
	print("BRIDGE_CONTACT_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func guards(audio: ObservedAudio, track: NativeTrack) -> void:
	var span: Dictionary = track.creator_bridges[0]
	var origin := Vector2(span.position[0],span.position[1])
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	for mode: String in ["plain","duplicate","air","roll","pause","countdown","underpass","rail","side","stationary"]:
		audio.reset()
		audio.emitted.clear()
		var state := VehicleState.new()
		state.heading = atan2(axis.x,axis.y)
		state.position = origin-axis*.2
		state.velocity = axis*12
		state.tick = 1
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity)
		var previous: Vector2 = state.position
		state.position = origin+axis*.2
		state.track_elevated = true
		state.tick = 2
		if mode=="air": state.jump_height = 1
		if mode=="roll": state.roll_ticks = 1
		if mode in ["pause","countdown"]: audio.present(state,DriveFrame.new(),track,.016,mode=="pause",mode=="countdown")
		else: audio.begin_physics_feedback()
		if mode=="underpass":
			state.position = origin+axis*float(span.length)*.5
			state.track_elevated = false
		if mode=="rail": state.collision_impulse = -axis*8
		if mode=="side":
			previous = origin+axis*float(span.length)*.5+axis.orthogonal()*(float(span.width)*.5+1)
			state.position = origin+axis*float(span.length)*.5
		if mode=="stationary": state.velocity = Vector2.ZERO
		audio.resolved_contact(state,track,state.velocity,previous,state.heading)
		if mode=="duplicate": audio.resolved_contact(state,track,state.velocity,previous,state.heading)
		if mode in ["plain","duplicate"]:
			check(int(audio.get("bridge_count"))==1 and audio.impact_count==0,"soft contact exactly once: "+mode)
			check(audio.emitted.size()==1 and audio.emitted[0].clip=="chassis" and float(audio.emitted[0].gain)<.23,"bridge uses recorded body movement with quiet bounded gain")
		else: check(int(audio.get("bridge_count"))==0,"bridge cue gate: "+mode)
		if mode=="rail": check(audio.impact_count==1,"actual bridge impact retains crash audio")
		audio.reset()
		check(int(audio.get("bridge_count"))==0 and not bool(audio.get("bridge_layer_known")),"retry clears bridge contact state")
	state_guard_rewind(audio,track,origin,axis)
	await process_frame

func state_guard_rewind(audio: ObservedAudio, track: NativeTrack, origin: Vector2, axis: Vector2) -> void:
	audio.reset()
	var state := VehicleState.new()
	state.tick = 100
	state.position = origin+axis
	state.track_elevated = true
	audio.present(state,DriveFrame.new(),track,.016,false)
	audio.begin_physics_feedback()
	audio.resolved_contact(state,track,Vector2.ZERO)
	state.tick = 20
	audio.present(state,DriveFrame.new(),track,.016,false)
	check(int(audio.get("bridge_count"))==0 and not bool(audio.get("bridge_layer_known")),"rewind clears bridge-layer history without a stale contact")

func game_crossing(track: NativeTrack) -> void:
	var span: Dictionary = track.creator_bridges[1]
	var origin := Vector2(span.position[0],span.position[1])
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	for reverse: bool in [false,true]:
		var direction: Vector2 = axis*(-1 if reverse else 1)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.vehicle_id = "compact"
		game.initial_track = track
		root.add_child(game)
		game.set_process(false)
		game.set_physics_process(false)
		game.set_process_input(false)
		game.set_process_unhandled_input(false)
		game.set_process_unhandled_key_input(false)
		game.countdown_ticks = 0
		game.production_mode = false
		game.driver = CoastingInput.new()
		game.hud.driver = game.driver
		game.vehicle_audio.use_windows_impacts = false
		game.sim.reset(origin+axis*(float(span.length)+4 if reverse else -4),atan2(direction.x,direction.y))
		game.sim.state.velocity = direction*24
		game.vehicle_audio.reset()
		for tick: int in range(400):
			game._physics_process(VehicleSimulation.STEP)
			if tick%4==0: game._process(VehicleSimulation.STEP*4)
			var u: float = CreatorBridges.local_point(span,game.sim.state.position).x
			if (u < -2 if reverse else u > float(span.length)+2): break
			if tick%30==0: await process_frame
		check(game.sim.state.collision_count==0 and game.vehicle_audio.impact_count==0,"actual Game clear bridge crossing never plays a crash")
		check(int(game.vehicle_audio.get("bridge_count"))==2,"actual Game dispatches both body contacts with coarse presentation")
		print("GAME_BRIDGE_CONTACT: ",JSON.stringify({"reverse":reverse,"cues":game.vehicle_audio.get("bridge_count"),"crashes":game.vehicle_audio.impact_count,"physical_hits":game.sim.state.collision_count,"tick":game.sim.state.tick,"u":CreatorBridges.local_point(span,game.sim.state.position).x,"velocity":[game.sim.state.velocity.x,game.sim.state.velocity.y],"heading":game.sim.state.heading,"paused":game.paused}))
		game.free()
		await process_frame

func record_mix(audio: ObservedAudio, track: NativeTrack) -> void:
	check(DisplayServer.get_name()!="headless","recording uses native desktop playback")
	var records: Array[AudioEffectRecord] = []
	var buses: Array[int] = [0]
	for label: String in ["BridgeBodyReview","BridgeCrashReview"]:
		var bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,label)
		AudioServer.set_bus_send(bus,"Vehicle" if label=="BridgeBodyReview" else "Impacts")
		buses.append(bus)
	for bus: int in buses:
		var recorder := AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,recorder)
		records.append(recorder)
	var span: Dictionary = track.creator_bridges[1]
	var origin := Vector2(span.position[0],span.position[1])
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
	audio.reset()
	audio.emitted.clear()
	var state := VehicleState.new()
	state.heading = atan2(axis.x,axis.y)
	state.position = origin-axis*1.0
	state.velocity = axis*8
	audio.begin_physics_feedback()
	audio.resolved_contact(state,track,state.velocity)
	audio.present(state,DriveFrame.new(),track,.1,false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await create_timer(.3).timeout
	for recorder: AudioEffectRecord in records: recorder.set_recording_active(true)
	# Audition the resolver's entrance/exit contacts separately. Rendering
	# stalls cannot skip both layer changes in a single long display frame.
	for u: float in [-.05,.2,float(span.length)-.2,float(span.length)+.2]:
		await create_timer(1.0).timeout
		var from: Vector2 = state.position
		state.position = origin+axis*u
		state.collision_impulse = Vector2.ZERO
		track.resolve(state,from,VehicleCatalog.config("compact"))
		state.tick += 1
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity,from,state.heading)
		# Assign the actual selected body/crash voices for same-clock capture.
		for player: AudioStreamPlayer in audio.events:
			var is_crash: bool = false
			for clip: String in VehicleAudio.IMPACTS:
				if audio.streams.has(clip) and player.stream==audio.streams[clip]: is_crash = true
			player.bus = "BridgeCrashReview" if is_crash else "BridgeBodyReview"
		audio.present(state,DriveFrame.new(),track,.1,false)
	await create_timer(1.0).timeout
	audio.present(state,DriveFrame.new(),track,.1,true)
	await create_timer(.5).timeout
	for i: int in range(records.size()):
		records[i].set_recording_active(false)
		check(records[i].get_recording().save_to_wav(output.path_join(["bridge-driving","bridge-body","bridge-crash"][i]+".wav"))==OK,"native contact audio saved")
	if not baseline:
		check(audio.impact_count==0 and int(audio.get("bridge_count"))==2,"native bridge crossing contains two body contacts and no crashes")
	var events := FileAccess.open(output.path_join("native-events.json"),FileAccess.WRITE)
	events.store_string(JSON.stringify(audio.emitted,"\t"))
	events.close()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	for i: int in range(buses.size()-1,0,-1): AudioServer.remove_bus(buses[i])
