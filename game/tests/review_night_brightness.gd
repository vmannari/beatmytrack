extends SceneTree
## Native before/after review without player records or live services.

const OUTPUT: String = "res://../docs/evidence/night-brightness-2026-10-28/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var output: String = OUTPUT.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "night_city"
	doc["automatic_scenery"] = false
	for point: Vector2 in [Vector2(-29,-10), Vector2(-25,5), Vector2(-11,19)]:
		doc.objects.append({"kind":"light", "position":[point.x,point.y], "rotation":0.0, "scale":1.0})
	var track: NativeTrack = TrackCompiler.compile(doc)
	var canonical: PackedByteArray = var_to_bytes([track.content_hash, track.cells, track.route, track.metadata])
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.hitch_diagnostics.persist_enabled = false
	game.paused = true
	game._present_frame(0.0)
	game.race_cues.reset()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var state: Array = game.sim.state.snapshot()
	var failed: bool = false
	var rows: Array[Dictionary] = []
	for viewport: Vector2i in [Vector2i(1280,720), Vector2i(1280,800)]:
		root.size = viewport
		root.content_scale_size = viewport
		root.scaling_3d_scale = 0.667
		for focus: Vector2 in [game.sim.state.position, Vector2(-25,9)]:
			game.camera.follow(focus,Vector2.ZERO,0.0,0.0,true)
			var pose: Transform3D = game.camera.transform
			var size: float = game.camera.size
			for revision: String in ["before", "after"]:
				TrackTheme.apply_lighting("night_city",game.biome_environment,game.biome_light)
				if revision == "before":
					game.biome_environment.ambient_light_energy = 0.045
					game.biome_light.light_energy = 0.025
				for frame: int in range(8): await RenderingServer.frame_post_draw
				var tag: String = "%dx%d-view-%d-%s" % [viewport.x,viewport.y,0 if focus == game.sim.state.position else 1,revision]
				var error: Error = root.get_texture().get_image().save_png(output.path_join(tag+".png"))
				failed = failed or error != OK or game.camera.transform != pose or game.camera.size != size
				rows.append({"image":tag+".png", "ambient":game.biome_environment.ambient_light_energy, "moon":game.biome_light.light_energy})
	failed = failed or state != game.sim.state.snapshot()
	failed = failed or canonical != var_to_bytes([track.content_hash,track.cells,track.route,track.metadata])
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failed":failed,"views":rows,"viewport_3d_scale":root.scaling_3d_scale},"\t"))
	report.close()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("NIGHT_BRIGHTNESS_REVIEW: %d captures, failures=%s" % [rows.size(),failed])
	quit(1 if failed else 0)
