extends SceneTree
## Real completed-race recording with staged side-by-side poses for visual inspection.
var output: String = "res://../docs/evidence/personal-ghosts-2026-10-03"
var captures: int = 0
func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var folder: String = "user://ghost_capture_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.preference_records = records
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.ai_enabled = true
	while not game.track_session.finished and game.sim.state.tick < 30000: game._physics_process(1.0 / 120.0)
	assert(game.track_session.finished)
	assert(records.record(game.native_track,game.handling,game.track_session.race_time_seconds(),game.track_session.lap_times) == OK)
	assert(game.save_personal_ghost() == OK)
	game.restart()
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.race_cues.hide()
	game.trails.clear()
	game.sand_dust.clear()
	for mode: String in ["race", "lap"]:
		game.set_ghost_mode(mode)
		var pose: Array = PersonalGhostRun.sample(game.ghost_bests[mode],360.0)
		var forward := Vector2(sin(pose[4]),cos(pose[4]))
		game.sim.state.position = Vector2(pose[1],pose[2]) - forward * 2.5 + forward.orthogonal()*1.3
		game.sim.state.heading = pose[4]
		game.sim.state.velocity = forward*14.0
		game.sim.state.tick = 360
		game.track_session.elapsed_ticks = 360
		game.track_session.lap_start_time = 0.0
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		game.camera.follow(game.sim.state.position,game.sim.state.velocity,game.sim.state.heading,0.0,true)
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			game._process(0.0)
			game._present_personal_ghost(1.0)
			assert(game.personal_ghost.visible)
			await capture("%s-ghost-%dx%d.png" % [mode,dimensions.x,dimensions.y])
	game.toggle_pause()
	game.hud.pause_menu._settings()
	var selector: OptionButton = game.hud.pause_menu.find_child("RaceGhostMode",true,false)
	assert(selector != null and selector.size.y >= 52)
	selector.select(2)
	selector.item_selected.emit(2)
	assert(game.ghost_mode == "race")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await capture("pause-ghost-settings-1280x720.png")
	game.queue_free()
	await process_frame
	for child: String in DirAccess.get_directories_at(folder):
		for file: String in DirAccess.get_files_at(folder.path_join(child)): DirAccess.remove_absolute(folder.path_join(child).path_join(file))
		DirAccess.remove_absolute(folder.path_join(child))
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("PERSONAL_GHOST_CAPTURE: %d screenshots, actual race recordings and pause selector passed" % captures)
	quit()

func capture(filename: String) -> void:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(filename))) == OK)
	captures += 1
