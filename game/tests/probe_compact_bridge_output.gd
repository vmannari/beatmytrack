extends "res://tests/probe_direct_collision_output.gd"
## Interleaved original/current contact methods, actual Compact and cached bridge.
var document_path: String = "res://../docs/evidence/compact-bridge-impact-2026-10-23/knot.json"
var reference_points := PackedVector2Array()
var bridge: Dictionary = {}

func original_observer(car: CarVisual) -> VisibleContactAudio:
	var original: String = FileAccess.get_file_as_string("res://../docs/evidence/compact-bridge-impact-2026-10-23/before/game/vehicle/visible_contact_audio.gd")
	var method: String = original.substr(original.find("func sample("))
	method = method.substr(0,method.find("func _solid_at("))
	var script := GDScript.new()
	script.source_code = "extends VisibleContactAudio\n\n"+method
	assert(script.reload()==OK)
	var observer: VisibleContactAudio = script.new()
	observer.configure(car,true)
	return observer

func _record_render() -> void:
	if game==null or row.is_empty() or int(row.render_contact_us)>0: return
	var span: int = CreatorBridges.span_at(game.native_track.creator_bridges,game.sim.state.position) if game.sim.state.track_elevated else -1
	for point: Vector2 in reference_points:
		var local := Vector3(point.x/game.car.scale.x,0,-point.y/game.car.scale.z)
		var world: Vector3 = game.car.global_transform*local
		if game.vehicle_audio.visible_contact._solid_at(game.sim.state,game.native_track,Vector2(world.x,-world.z),span):
			row.render_contact_us = now_us()
			row.render_contact_tick = game.sim.state.tick
			return

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
		if argument.begins_with("--document="): document_path = argument.trim_prefix("--document=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(document_path))
	var track: NativeTrack = TrackCompiler.compile(document)
	assert(track!=null and not track.creator_bridges.is_empty())
	bridge = track.creator_bridges[0]
	game = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = track
	game.production_mode = false
	game.set_physics_process(false)
	root.add_child(game)
	var deadline: int = Time.get_ticks_msec()+30000
	while not game.preparation_complete and Time.get_ticks_msec()<deadline:
		await process_frame
	assert(game.preparation_complete)
	game.set_physics_process(false)
	game.driver = NeutralInput.new()
	game.countdown_ticks = 0
	var audio: VehicleAudio = game.vehicle_audio
	draw_outline = audio.visible_contact.outline.duplicate()
	var front: float = 0.0
	for index: int in range(draw_outline.size()-1):
		var a: Vector2 = draw_outline[index]
		var b: Vector2 = draw_outline[index+1]
		front = maxf(front,a.y)
		var steps: int = maxi(1,ceili(a.distance_to(b)/.05))
		for step: int in range(steps): reference_points.append(a.lerp(b,float(step)/steps))
	for bus: int in range(1,AudioServer.bus_count):
		AudioServer.set_bus_mute(bus,AudioServer.get_bus_name(bus)!="Impacts")
	RenderingServer.frame_post_draw.connect(_record_render)
	var file := FileAccess.open(output.path_join("ready.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"rate":AudioServer.get_mix_rate(),"track":document.get("name",""),"span":0,"side":1,"reverse":true,"offset":-.8}))
	file.close()
	deadline = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(output.path_join("armed")):
		await process_frame
		assert(Time.get_ticks_msec()<deadline)
	var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading)))
	var origin := Vector2(bridge.position[0],bridge.position[1])
	var direction: Vector2 = -axis
	var heading: float = atan2(direction.x,direction.y)
	var rows: Array[Dictionary] = []
	for speed: float in [5.0,15.0,30.0]:
		for baseline: bool in [true,false]:
			row = {}
			var start: Vector2 = origin+axis*(float(bridge.length)+front+.7)+axis.orthogonal()*(float(bridge.width)*.5-.8)
			game.sim.reset(start,heading)
			game.sim.state.velocity = direction*speed
			game.previous_position = start
			game.previous_heading = heading
			audio.reset()
			if baseline: audio.visible_contact = original_observer(game.car)
			else:
				audio.visible_contact = VisibleContactAudio.new()
				audio.visible_contact.configure(game.car,true)
			await create_timer(.7).timeout
			var native_before: int = int(audio.windows_impacts.stats().get("submitted",0))
			row = {"trial":rows.size(),"speed_mps":speed,"original_method":baseline,"render_contact_us":0,"render_contact_tick":-1,"cue_tick":-1,"physical_tick":-1,"physical_us":0,"unix_us":0,"route":"none"}
			for tick: int in range(400):
				await physics_frame
				var before_us: int = now_us()
				game._physics_process(VehicleSimulation.STEP)
				if int(row.unix_us)==0 and audio.impact_count>0:
					row.unix_us = before_us
					row.cue_tick = game.sim.state.tick
					row.native = audio.windows_impacts.stats()
					row.route = "windows_raw" if int(row.native.get("submitted",0))>native_before else "godot"
					row.clip = VehicleAudio.IMPACTS[audio.impact_index]
				if game.sim.state.collision_impulse!=Vector2.ZERO:
					row.physical_tick = game.sim.state.tick
					row.physical_us = before_us
					break
			await create_timer(.45).timeout
			row.cue_count = audio.impact_count
			row.reported_latency_ms = AudioServer.get_output_latency()*1000.0
			row.next_mix_ms = AudioServer.get_time_to_next_mix()*1000.0
			assert(int(row.unix_us)>0 and int(row.physical_us)>0 and int(row.render_contact_us)>0 and int(row.cue_count)==1)
			if baseline: assert(int(row.cue_tick)==int(row.physical_tick))
			else: assert(int(row.cue_tick)<int(row.physical_tick))
			rows.append(row.duplicate(true))
			print("COMPACT_BRIDGE_OUTPUT_TRIAL: ",JSON.stringify(row))
	row = {}
	RenderingServer.frame_post_draw.disconnect(_record_render)
	file = FileAccess.open(output.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output.path_join("bridge-contact.png"))
	game.free()
	game = null
	await create_timer(.2).timeout
	print("COMPACT_BRIDGE_OUTPUT: %d trials"%rows.size())
	quit()
