extends SceneTree
## Compare complete deposited geometry to the original four scalar calls.

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var source: String = FileAccess.get_file_as_string("res://vehicle/skid_trails.gd").replace("\r\n","\n").replace("class_name SkidTrails\n","")
	var optimized: String = "\tvar strengths: PackedFloat64Array = _four_intensities(state, frame, left_kind, right_kind, front_left_kind, front_right_kind)\n\tvar left_strength: float = strengths[0]\n\tvar right_strength: float = strengths[1]\n\tvar front_left_strength: float = strengths[2]\n\tvar front_right_strength: float = strengths[3]"
	var original: String = "\tvar left_strength: float = physics_intensity(state, frame, left_kind, -1.0, -1.0)\n\tvar right_strength: float = physics_intensity(state, frame, right_kind, 1.0, -1.0)\n\tvar front_left_strength: float = physics_intensity(state, frame, front_left_kind, -1.0, 1.0)\n\tvar front_right_strength: float = physics_intensity(state, frame, front_right_kind, 1.0, 1.0)"
	if not source.contains(optimized):
		printerr("Could not construct original scalar control")
		quit(1)
		return
	var script := GDScript.new()
	script.source_code = source.replace(optimized,original)
	if script.reload() != OK:
		printerr("Original scalar control did not compile")
		quit(1)
		return
	var track := NativeTrack.read("res://resources/tracks/ellipse.json")
	var before: Node3D = script.new()
	var after := SkidTrails.new()
	root.add_child(before)
	root.add_child(after)
	var bridge := BridgePresentation.new(track)
	var state := VehicleState.new()
	state.velocity = Vector2(8,30)
	var frame := DriveFrame.new()
	frame.brake = 255
	var medians: Array[int] = []
	for effect: Node3D in [before,after]:
		var times: Array[int] = []
		for repeat: int in range(5):
			effect.clear()
			state.position = track.spawn
			state.route_index = track.nearest_route(state.position)
			var start: int = Time.get_ticks_usec()
			for index: int in range(2000):
				state.position = track.spawn + Vector2(sin(index*0.01)*3,index*0.04)
				state.route_index = track.nearest_route(state.position,state.route_index)
				effect.sample(state,frame,bridge,track)
			times.append(Time.get_ticks_usec()-start)
		times.sort()
		medians.append(times[2])
	var matches: bool = before.cursor == after.cursor and before.mark_colors == after.mark_colors and before.mark_custom == after.mark_custom and before.mark_transforms == after.mark_transforms
	print("trail sample exact scalar-control=%s, marks=%d; median scalar=%d us shared=%d us per 2000 samples" % [matches,after.cursor,medians[0],medians[1]])
	before.free()
	after.free()
	quit(0 if matches else 1)
