extends SceneTree
## Includes countdown and first-use costs; never saves scores or player settings.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			var document: Dictionary = TrackLibrary.new().load_document(argument.trim_prefix("--track=").trim_prefix("creator_"))
			if document.is_empty():
				push_error("Profile track not found")
				quit(1)
				return
			track = TrackCompiler.compile(document)
	var fields: Array[String] = ["sim","rules","ai","present","particles","trails","telemetry"]
	# Drive first so a stationary pass cannot prewarm first-use race effects.
	for moving: bool in [true,false,true]:
		var game: Node = load("res://core/game.tscn").instantiate()
		game.set("initial_track",track)
		game.set("production_mode",true)
		game.set("ai_enabled",moving)
		game.set("profile_enabled",true)
		root.add_child(game)
		var start: int = Time.get_ticks_usec()
		var last: int = start
		var rows: Array[Dictionary] = []
		var distance: float = 0.0
		var previous: Vector2 = game.get("sim").state.position
		while Time.get_ticks_usec()-start < 14000000:
			await process_frame
			# Other desktop windows must not silently turn a moving probe into a pause.
			game.set("paused",false)
			var position: Vector2 = game.get("sim").state.position
			distance += position.distance_to(previous)
			previous = position
			var now: int = Time.get_ticks_usec()
			var row: Dictionary = {"seconds":(now-start)/1000000.0,"ms":(now-last)/1000.0,"tick":game.get("sim").state.tick}
			for field: String in fields:
				row[field] = game.get("profile_"+field+"_us")/1000.0
				game.set("profile_"+field+"_us",0)
			rows.append(row)
			last = now
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.ms > b.ms)
		print("RACE_START track=",track.identity," moving=",moving," metres=",distance," ticks=",game.get("sim").state.tick," worst=",JSON.stringify(rows.slice(0,12)))
		if game.get("sim").state.tick < 1000 or (moving and distance < 20.0):
			push_error("Race-start probe did not exercise sufficient live simulation")
			quit(1)
			return
		root.remove_child(game)
		game.queue_free()
		await process_frame
	quit()
