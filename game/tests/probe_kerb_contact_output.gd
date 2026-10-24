extends "res://tests/test_grass_kerb_audio.gd"
## Actual Game wheel contacts and rendering; isolate the entry and rolling paths.
var capture_output: String = "res://../build/windows-contact-timing-2026-10-23/kerbs"
var game: Node
var timing_row: Dictionary = {}

class NeutralInput extends DriverInput:
	func sample() -> DriveFrame: return DriveFrame.new()

class ContactAudio extends VehicleAudio:
	var isolation: String = "bump"
	var observing: bool = false
	var in_contact_callback: bool = false
	var request_us: int = 0
	var callback_tick: int = -1
	var request_tick: int = -1
	var route: String = "none"
	func resolved_contact(state: VehicleState, track: NativeTrack, incoming: Vector2, previous_position: Vector2 = Vector2.INF, previous_heading: float = INF) -> void:
		in_contact_callback = true
		callback_tick = state.tick
		super.resolved_contact(state,track,incoming,previous_position,previous_heading)
		in_contact_callback = false
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		# Exclude unrelated gear/landing cues, and measure the entry separately.
		if not observing or not in_contact_callback or isolation!="bump" or clip!="chassis": return
		if request_us==0:
			request_us = int(Time.get_unix_time_from_system()*1000000.0)
			request_tick = callback_tick
		var before: int = int(windows_impacts.stats().get("submitted",0))
		super._event(clip,amplitude,pitch,debris)
		route = "windows_raw" if int(windows_impacts.stats().get("submitted",0))>before else "godot"
	func _layer(key: String, desired: float, pitch: float, delta: float, immediate_silence: bool) -> void:
		var keep: bool = key=="kerb_roll" and isolation=="roll"
		if keep and observing and in_contact_callback and desired>0.0 and request_us==0:
			request_us = int(Time.get_unix_time_from_system()*1000000.0)
			request_tick = callback_tick
			route = "windows_mix" if bool(GameSoundtrack.instance().windows_output.stats().get("ready",false)) else "godot"
		super._layer(key,desired if keep else 0.0,pitch,delta,immediate_silence or not keep)

func _record_render() -> void:
	if game==null or timing_row.is_empty() or int(timing_row.render_contact_us)>0: return
	for wheel: Node3D in game.car.rolling_wheels:
		var point: Vector3 = wheel.global_position
		if game.native_track.kerbs.height_at(Vector2(point.x,-point.z))>.004:
			timing_row.render_contact_us = int(Time.get_unix_time_from_system()*1000000.0)
			timing_row.render_contact_tick = game.sim.state.tick
			return

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): capture_output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_output))
	game = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = make_track(true)
	game.production_mode = false
	game.set_physics_process(false)
	root.add_child(game)
	var deadline: int = Time.get_ticks_msec()+30000
	while not game.preparation_complete and Time.get_ticks_msec()<deadline:
		await process_frame
	assert(game.preparation_complete,"The actual Game must finish preparing before kerb timing begins.")
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.driver = NeutralInput.new()
	game.vehicle_audio.free()
	var audio := ContactAudio.new()
	game.vehicle_audio = audio
	game.add_child(audio)
	audio.configure(game.vehicle_id,game.handling,game.car)
	# Nature and engine sounds cannot contaminate the contact onset measurement.
	var muted_bus: int = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(muted_bus,"ContactTimingMuted")
	AudioServer.set_bus_mute(muted_bus,true)
	for player: AudioStreamPlayer in game.find_children("*","AudioStreamPlayer",true,false):
		if not audio.is_ancestor_of(player): player.bus = "ContactTimingMuted"
	for label: String in ["Engine","Tires","Music","Interface"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(label),true)
	RenderingServer.frame_post_draw.connect(_record_render)
	var file := FileAccess.open(capture_output.path_join("ready.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"rate":AudioServer.get_mix_rate()}))
	file.close()
	deadline = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(capture_output.path_join("armed")):
		await process_frame
		assert(Time.get_ticks_msec()<deadline,"Capture must arm before the isolated trials.")
	var rows: Array[Dictionary] = []
	for isolation: String in ["bump","roll"]:
		for speed: float in [5.0,15.0,30.0]:
			timing_row = {}
			audio.observing = false
			audio.isolation = isolation
			var start := Vector2(0,-3.0)
			game.sim.reset(start,0.0)
			game.sim.state.velocity = Vector2(0,speed)
			game.previous_position = start
			game.previous_heading = 0.0
			audio.reset()
			audio.request_us = 0
			audio.request_tick = -1
			audio.route = "none"
			await create_timer(.65).timeout
			timing_row = {"trial":rows.size(),"clip":"kerb_entry" if isolation=="bump" else "kerb_roll","speed_mps":speed,"unix_us":0,"contact_us":0,"contact_tick":-1,"render_contact_us":0,"render_contact_tick":-1}
			audio.observing = true
			for tick: int in range(400):
				await physics_frame
				var before_us: int = int(Time.get_unix_time_from_system()*1000000.0)
				game._physics_process(VehicleSimulation.STEP)
				if audio.surface_model.kerb>0.0 and int(timing_row.contact_us)==0:
					timing_row.contact_us = before_us
					timing_row.contact_tick = game.sim.state.tick
				if int(timing_row.render_contact_us)>0 and audio.request_us>0: break
			assert(int(timing_row.contact_us)>0 and audio.request_us>0,"Wheel contact must request its isolated sound in the same callback.")
			timing_row.unix_us = audio.request_us
			timing_row.route = audio.route
			timing_row.request_tick = audio.request_tick
			timing_row.native = audio.windows_impacts.stats()
			timing_row.next_mix_ms = AudioServer.get_time_to_next_mix()*1000.0
			timing_row.reported_latency_ms = AudioServer.get_output_latency()*1000.0
			timing_row.kerb_count = audio.kerb_count
			await create_timer(.45).timeout
			assert(int(timing_row.render_contact_us)>0,"Normal rendering must show wheel contact.")
			assert(int(timing_row.request_tick)==int(timing_row.contact_tick),"Contact dispatch cannot wait for another physics tick.")
			assert(game.sim.state.collision_count==0,"Kerb feedback must remain separate from wall collisions.")
			rows.append(timing_row.duplicate(true))
			print("KERB_CONTACT_TRIAL: ",JSON.stringify(timing_row))
			audio.observing = false
	timing_row = {}
	RenderingServer.frame_post_draw.disconnect(_record_render)
	file = FileAccess.open(capture_output.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	file = FileAccess.open(capture_output.path_join("output-stats.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(GameSoundtrack.instance().windows_output.stats(),"\t"))
	file.close()
	game.free()
	game = null
	AudioServer.remove_bus(muted_bus)
	await create_timer(.2).timeout
	print("KERB_CONTACT_OUTPUT: %d actual contact trials"%rows.size())
	quit()
