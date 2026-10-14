extends SceneTree
## Includes countdown and first-use costs; never saves scores or player settings.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var themes: Array[String] = []
	var probe_seconds: float = 12.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--themes="): themes.assign(argument.trim_prefix("--themes=").split(","))
		if argument.begins_with("--seconds="): probe_seconds = clampf(float(argument.trim_prefix("--seconds=")), 5.0, 30.0)
		if argument.begins_with("--track="):
			var document: Dictionary = TrackLibrary.new().load_document(argument.trim_prefix("--track=").trim_prefix("creator_"))
			if document.is_empty():
				push_error("Profile track not found")
				quit(1)
				return
			track = TrackCompiler.compile(document)
	var fields: Array[String] = ["sim","rules","ai","present","particles","trails","telemetry","weather","weathering","condition","audio","history","physics_total","process_total"]
	var run_index: int = 0
	var output: String = ProjectSettings.globalize_path("res://../build/race-hitch-profile")
	DirAccess.make_dir_recursive_absolute(output)
	# Drive first so a stationary pass cannot prewarm first-use race effects.
	var runs: Array[bool] = [true,false,true]
	if not themes.is_empty():
		runs.clear()
		for theme: String in themes: runs.append(true)
	for moving: bool in runs:
		if not themes.is_empty(): track.metadata.theme = themes[run_index]
		run_index += 1
		var game: Node = load("res://core/game.tscn").instantiate()
		game.set("initial_track",track)
		game.set("production_mode",true)
		game.set("ai_enabled",moving)
		game.set("profile_enabled",true)
		# Exercise the real five-second cosmetic persistence on disposable records.
		var records := LocalRecords.new(output.path_join("records-%d.json" % run_index))
		game.set("preference_records",records)
		root.add_child(game)
		game.get("hitch_diagnostics").directory = output
		game.get("hitch_diagnostics").log_path = output.path_join("race-%d-%d.json" % [OS.get_process_id(),run_index])
		var start: int = Time.get_ticks_usec()
		var last: int = start
		var rows: Array[Dictionary] = []
		var distance: float = 0.0
		var previous: Vector2 = game.get("sim").state.position
		var previous_costs: Dictionary = {}
		var deadline: int = start + int((probe_seconds + 20.0) * 1000000.0)
		# Cold shaders can delay countdown. Bound wall time, measure actual driving.
		while game.get("sim").state.tick < int(probe_seconds * 120.0) and Time.get_ticks_usec() < deadline:
			await process_frame
			# Other desktop windows must not silently turn a moving probe into a pause.
			game.set("paused",false)
			var position: Vector2 = game.get("sim").state.position
			distance += position.distance_to(previous)
			previous = position
			var now: int = Time.get_ticks_usec()
			var row: Dictionary = {"seconds":(now-start)/1000000.0,"ms":(now-last)/1000.0,"tick":game.get("sim").state.tick}
			for field: String in fields:
				var total: int = game.get("profile_"+field+"_us")
				row[field] = (total - int(previous_costs.get(field,0))) / 1000.0
				previous_costs[field] = total
			rows.append(row)
			last = now
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.ms > b.ms)
		var monitor: Node = game.get("hitch_diagnostics")
		print("RACE_START track=",track.identity," theme=",track.metadata.get("theme","pine")," moving=",moving," metres=",distance," ticks=",game.get("sim").state.tick," saves=",game.get("condition_save_count")," observer_mean_us=",monitor.observer_total_us / maxf(1.0,monitor.observed_frames)," worst=",JSON.stringify(rows.slice(0,12)))
		if game.get("sim").state.tick < int(probe_seconds * 120.0) or (moving and distance < 20.0):
			push_error("Race-start probe did not exercise sufficient live simulation")
			quit(1)
			return
		root.remove_child(game)
		game.queue_free()
		await process_frame
	quit()
