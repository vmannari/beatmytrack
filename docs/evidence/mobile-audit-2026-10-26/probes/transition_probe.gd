extends SceneTree
var rows: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene: PackedScene = load("res://core/game.tscn")
	for source: String in ["ellipse","storm_freight","storm_floodgate"]:
		for pass_index: int in range(3):
			var started: int = Time.get_ticks_usec()
			var track: NativeTrack = NativeTrack.read("res://resources/tracks/"+source+".json")
			var loaded: int = Time.get_ticks_usec()
			var game: Node = scene.instantiate()
			game.initial_track = track
			game.production_mode = true
			game.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(game)
			while not game.preparation_complete and Time.get_ticks_usec()-started < 60000000: await process_frame
			var row: Dictionary = {"track":source,"pass":pass_index,"source_ms":(loaded-started)/1000.0,"ready_ms":(Time.get_ticks_usec()-loaded)/1000.0,"complete":game.preparation_complete,"static_bytes_active":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"nodes_active":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"resources_active":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"tick":game.sim.state.tick}
			game.queue_free()
			track = null
			await process_frame
			await process_frame
			row.static_bytes_after = int(Performance.get_monitor(Performance.MEMORY_STATIC))
			row.nodes_after = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			row.resources_after = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
			rows.append(row)
			print("TRANSITION ",JSON.stringify(row))
	var output := FileAccess.open("res://../build/mobile-audit-2026-10-26/transition-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"))
	quit()
