extends "res://tests/analyze_shallow_collisions.gd"
const OUT: String = "res://../build/audio-output-2026-10-09"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var file: FileAccess = FileAccess.open(OUT.path_join("ready.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"rate":AudioServer.get_mix_rate()}))
	file.close()
	var timeout: int = Time.get_ticks_msec()+60000
	while not FileAccess.file_exists(OUT.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>timeout:
			print("WINDOWS_OUTPUT_PROBE: capture not armed")
			quit(1)
			return
	var audio: VehicleAudio
	var game: Node
	if OS.get_cmdline_user_args().has("--wall"):
		game = load("res://core/game.tscn").instantiate()
		game.vehicle_id = "compact"
		game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		root.add_child(game)
		game.set_process(false)
		game.set_physics_process(false)
		game.countdown_ticks = 0
		game.production_mode = false
		game.native_track = make_wall(Vector2(0,-1),.5)
		game.yard = game.native_track
		audio = game.vehicle_audio
	else:
		audio = VehicleAudio.new()
		audio.use_windows_impacts = not OS.get_cmdline_user_args().has("--godot-impacts")
		root.add_child(audio)
		audio.configure("compact",VehicleCatalog.config("compact"))
	# Isolate the actual impact even if Game startup activated music/chassis audio.
	for bus: int in range(1,AudioServer.bus_count):
		AudioServer.set_bus_mute(bus,AudioServer.get_bus_name(bus)!="Impacts")
	var rows: Array[Dictionary] = []
	for trial: int in range(6):
		audio.reset()
		await create_timer(1.0).timeout
		var event_us: int
		var wall_row: Dictionary = {}
		if game!=null:
			game.sim.reset(Vector2(0,-4),0)
			game.sim.state.velocity = Vector2(0,4)
			var front: float = 0.0
			for point: Vector2 in audio.visible_contact.outline: front = maxf(front,point.y)
			for tick: int in range(240):
				var before_us: int = int(Time.get_unix_time_from_system()*1000000.0)
				game._physics_process(VehicleSimulation.STEP)
				if audio.impact_count>0 and event_us==0:
					event_us = before_us
					wall_row.sound_tick = game.sim.state.tick
					wall_row.visible_touch = game.sim.state.position.y+front>=0.0
				if game.sim.state.collision_impulse!=Vector2.ZERO:
					wall_row.physical_tick = game.sim.state.tick
					break
			wall_row.cue_count = audio.impact_count
			assert(wall_row.sound_tick==62 and wall_row.physical_tick==81 and wall_row.cue_count==1 and wall_row.visible_touch)
		else:
			audio.begin_physics_feedback()
			event_us = int(Time.get_unix_time_from_system()*1000000.0)
			audio.collision(Vector2(20,0))
		rows.append({"trial":trial,"unix_us":event_us,"next_mix_ms":AudioServer.get_time_to_next_mix()*1000.0,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"native":audio.windows_impacts.stats(),"wall":wall_row})
		await create_timer(.4).timeout
	var events: FileAccess = FileAccess.open(OUT.path_join("events.json"),FileAccess.WRITE)
	events.store_string(JSON.stringify(rows,"\t"))
	events.close()
	if game!=null: game.free()
	else: audio.free()
	await create_timer(.2).timeout
	print("WINDOWS_OUTPUT_PROBE: ",JSON.stringify(rows))
	quit()
