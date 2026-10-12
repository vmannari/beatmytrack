extends "res://tests/analyze_shallow_collisions.gd"
## Real-time direct hits: normal rendering, actual Game callback, own-process capture.
const OUT: String = "res://../build/direct-collision-output-2026-10-09"
class NeutralInput extends DriverInput:
	func sample() -> DriveFrame:
		return DriveFrame.new()
var game: Node
var row: Dictionary = {}
var draw_outline := PackedVector2Array()

func _initialize() -> void:
	call_deferred("run")

func now_us() -> int:
	return int(Time.get_unix_time_from_system()*1000000.0)

func _record_render() -> void:
	if game==null or row.is_empty() or row.get("render_contact_us",0)!=0: return
	for point: Vector2 in draw_outline:
		var local := Vector3(point.x/game.car.scale.x,0,-point.y/game.car.scale.z)
		var world: Vector3 = game.car.global_transform*local
		if -world.z>=0.0:
			row.render_contact_us = now_us()
			row.render_contact_tick = game.sim.state.tick
			return

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ready_file: FileAccess = FileAccess.open(OUT.path_join("ready.json"),FileAccess.WRITE)
	ready_file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"rate":AudioServer.get_mix_rate()}))
	ready_file.close()
	var timeout: int = Time.get_ticks_msec()+60000
	while not FileAccess.file_exists(OUT.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>timeout:
			print("DIRECT_COLLISION_OUTPUT: capture not armed")
			quit(1)
			return
	game = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = make_wall(Vector2(0,-1),.5)
	root.add_child(game)
	game.set_physics_process(false)
	game.driver = NeutralInput.new()
	game.countdown_ticks = 0
	game.production_mode = false
	var audio: VehicleAudio = game.vehicle_audio
	draw_outline = audio.visible_contact.outline.duplicate()
	RenderingServer.frame_post_draw.connect(_record_render)
	for bus: int in range(1,AudioServer.bus_count):
		AudioServer.set_bus_mute(bus,AudioServer.get_bus_name(bus)!="Impacts")
	var front: float = 0.0
	for point: Vector2 in draw_outline: front = maxf(front,point.y)
	var rows: Array[Dictionary] = []
	for canonical_only: bool in [false,true]:
		for speed: float in [5.0,15.0,30.0]:
			row = {}
			var start := Vector2(0,-front-3.0)
			game.sim.reset(start,0)
			game.sim.state.velocity = Vector2(0,speed)
			game.previous_position = start
			game.previous_heading = 0.0
			audio.reset()
			audio.visible_contact.outline = PackedVector2Array() if canonical_only else draw_outline.duplicate()
			await create_timer(.7).timeout
			var native_before: Dictionary = audio.windows_impacts.stats()
			row = {"trial":rows.size(),"speed_mps":speed,"canonical_only":canonical_only,"render_contact_us":0,"render_contact_tick":-1,"cue_tick":-1,"physical_tick":-1,"physical_us":0,"unix_us":0,"route":"none"}
			for tick: int in range(400):
				await physics_frame
				var before_us: int = now_us()
				game._physics_process(VehicleSimulation.STEP)
				if row.unix_us==0 and audio.impact_count>0:
					row.unix_us = before_us
					row.cue_tick = game.sim.state.tick
					row.native = audio.windows_impacts.stats()
					row.route = "windows_raw" if int(row.native.get("submitted",0))>int(native_before.get("submitted",0)) else "godot"
					row.clip = VehicleAudio.IMPACTS[audio.impact_index]
				if game.sim.state.collision_impulse!=Vector2.ZERO:
					row.physical_tick = game.sim.state.tick
					row.physical_us = before_us
					break
			await create_timer(.4).timeout
			row.cue_count = audio.impact_count
			row.reported_latency_ms = AudioServer.get_output_latency()*1000.0
			row.next_mix_ms = AudioServer.get_time_to_next_mix()*1000.0
			assert(row.unix_us>0 and row.physical_us>0 and row.render_contact_us>0 and row.cue_count==1)
			if canonical_only: assert(row.cue_tick==row.physical_tick)
			rows.append(row.duplicate(true))
			print("DIRECT_COLLISION_TRIAL: ",JSON.stringify(row))
	row = {}
	RenderingServer.frame_post_draw.disconnect(_record_render)
	var file: FileAccess = FileAccess.open(OUT.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	game.free()
	game = null
	await create_timer(.2).timeout
	print("DIRECT_COLLISION_OUTPUT: ",JSON.stringify(rows))
	quit()
