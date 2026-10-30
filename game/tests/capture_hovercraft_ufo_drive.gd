extends SceneTree
## Actual game presentation of deterministic turn, recovery and braking inputs.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/hovercraft-ufo-feel-2026-10-28/"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = output.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "hovercraft"
	game.free_drive_mode = true
	DirAccess.make_dir_recursive_absolute("user://hovercraft-ufo-native")
	game.preference_records = LocalRecords.new("user://hovercraft-ufo-native/records.json")
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.sim.reset(Vector2(0,-20),0.0)
	game.sim.state.velocity = Vector2(0,12)
	check(game.handling.version == "hovercraft-4" and game.handling.vector_thrust,"actual game installs the controlled UFO-style tune")
	var rows: Array = []
	for phase: Array in [["coast-turn",84,1.0,0.0,0.0],["power-catch",90,0.0,0.8,0.0],["correct",60,-0.5,0.7,0.0],["air-brake",180,0.0,0.0,0.8]]:
		game.frame = DriveFrame.sample(phase[2],phase[3],phase[4])
		for tick: int in range(phase[1]): game.sim.step(game.frame,game.yard)
		game.previous_position = game.sim.state.position
		game.previous_heading = game.sim.state.heading
		var before: Array = game.sim.state.snapshot()
		for frame: int in range(8):
			game._present_frame(1.0/60.0)
			await process_frame
			await RenderingServer.frame_post_draw
		check(absf(angle_difference(game.car.rotation.y,-game.sim.state.heading)) < 0.00001,"rendered hull follows actual simulated heading: "+phase[0])
		check(before == game.sim.state.snapshot(),"presentation cannot change momentum: "+phase[0])
		check(root.get_texture().get_image().save_png(output.path_join(phase[0]+".png")) == OK,"saved actual game "+phase[0])
		rows.append({"phase":phase[0],"heading_degrees":rad_to_deg(game.sim.state.heading),"velocity":str(game.sim.state.velocity),"contacts":game.sim.state.collision_count})
	check(not game.trails.visible and not game.sand_dust.visible,"hovercraft retains its no-wheel-effects presentation")
	var file := FileAccess.open(output.path_join("native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"phases":rows},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("HOVERCRAFT_UFO_NATIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
