extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="): source = argument.trim_prefix("--document=")
	assert(not source.is_empty())
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source)) as Dictionary
	var track: NativeTrack = TrackCompiler.compile(document)
	assert(track!=null)
	var car := CarVisual.new()
	root.add_child(car)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",config,car)
	var front: float = 0.0
	for point: Vector2 in audio.visible_contact.outline: front = maxf(front,point.y)
	var rows: Array[Dictionary] = []
	for heading: float in [0.0,PI*.5,PI,-PI*.5]:
		var direction := Vector2(sin(heading),cos(heading))
		for speed: float in [5.0,15.0,30.0]:
			var start := direction*(track.half_extent-Vector2.ONE*(front+4.0))
			var sim := VehicleSimulation.new(config)
			var plain := VehicleSimulation.new(config)
			sim.reset(start,heading)
			plain.reset(start,heading)
			sim.state.velocity = direction*speed
			plain.state.velocity = sim.state.velocity
			audio.reset()
			var touch: int = -1
			var cue: int = -1
			var physical: int = -1
			var equivalent: bool = true
			for tick: int in range(600):
				var incoming: Vector2 = sim.state.velocity
				var input := DriveFrame.new()
				sim.step(input,track)
				plain.step(input,track)
				audio.begin_physics_feedback()
				audio.resolved_contact(sim.state,track,incoming)
				if audio.visible_contact.touching and touch<0: touch = sim.state.tick
				if audio.impact_count>0 and cue<0: cue = sim.state.tick
				equivalent = equivalent and sim.state.snapshot()==plain.state.snapshot()
				if sim.state.collision_impulse!=Vector2.ZERO:
					physical = sim.state.tick
					break
			rows.append({"heading":heading,"initial_speed":speed,"touch":touch,"cue":cue,"physical":physical,"cue_count":audio.impact_count,"normal":[audio.visible_contact.normal.x,audio.visible_contact.normal.y],"snapshots_exact":equivalent})
	print("CACHED_DIRECT_WALLS: ",JSON.stringify({"track_name":document.get("name",""),"car":"compact","cell_size":track.cell_size,"rows":rows}))
	audio.free()
	car.free()
	await create_timer(.2).timeout
	quit()
