extends SceneTree
## Read-only source fixtures; disposable caches, no account/network/score writes.
const Cloud = preload("res://backend/cloud_tracks.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../build/repeat-race-load")
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	var rows: Array[Dictionary] = []
	for source: String in ["res://tests/fixtures/ajorata.json","res://tests/fixtures/star_spline_lap.json","res://../backend/tests/fixtures/verified_oval.json"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		if document.has("document"): document = document.document
		var body: String = JSON.stringify(document)
		var path: String = folder.path_join(source.get_file())
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(body)
		file.close()
		var entry: Dictionary = {"id":"load-"+document.id,"version_id":"version-"+document.id,"track_id":document.id,"name":document.name,"creator":"Fixture","content_hash":body.sha256_text(),"cache_path":path}
		for pass_index: int in range(3):
			var start: int = Time.get_ticks_usec()
			var track: NativeTrack = Cloud.compile_entry(entry)
			assert(track != null)
			var compiled: int = Time.get_ticks_usec()
			var game: Node = load("res://core/game.tscn").instantiate()
			game.initial_track = track
			game.production_mode = true
			game.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(game)
			var prepared: int = Time.get_ticks_usec()
			game._process(0.0)
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			var row: Dictionary = {"source":source.get_file(),"pass":pass_index,"compile_ms":(compiled-start)/1000.0,"scene_ms":(prepared-compiled)/1000.0,"total_ms":(Time.get_ticks_usec()-start)/1000.0}
			rows.append(row)
			print("REPEAT_LOAD ",JSON.stringify(row))
			assert(game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5)
			if DisplayServer.get_name() != "headless" and pass_index != 1:
				root.get_texture().get_image().save_png(folder.path_join(source.get_file()+"-"+str(pass_index)+".png"))
			root.remove_child(game)
			game.free()
			await process_frame
	var output := FileAccess.open(folder.path_join("timings.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"))
	quit()
