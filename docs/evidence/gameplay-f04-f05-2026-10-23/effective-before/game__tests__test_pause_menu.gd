extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	for i: int in range(5): await RenderingServer.frame_post_draw
	var hud: PlaygroundHUD = game.hud
	hud.menu_button.pressed.emit()
	check(game.paused and hud.pause_menu.visible and not hud.touch.enabled,"hamburger pauses and blocks driving")
	game.open_rewind()
	check(not is_instance_valid(game.rewind_panel),"rewind shortcut cannot open behind pause drawer")
	var tick: int = game.sim.state.tick
	game._physics_process(1.0/120.0)
	check(game.sim.state.tick == tick,"paused simulation is frozen")
	for i: int in range(3): await RenderingServer.frame_post_draw
	for emitter: GPUParticles3D in game.sand_dust.dust_emitters:
		check(emitter.speed_scale == 0.0,"dust particles freeze")
	var path: String = ProjectSettings.globalize_path("res://../docs/evidence/pause-menu")
	DirAccess.make_dir_recursive_absolute(path)
	var first: Image = root.get_texture().get_image()
	check(first.save_png(path+"/1280x720.png") == OK,"capture saved")
	for i: int in range(20): await RenderingServer.frame_post_draw
	var second: Image = root.get_texture().get_image()
	check(first.get_data() == second.get_data(),"paused frame and drawer remain visually frozen")
	var pixel: Color = first.get_pixel(500,400)
	check(absf(pixel.r-pixel.g) < 0.02 and absf(pixel.g-pixel.b) < 0.02,"race view is monochrome")
	(hud.pause_menu.find_child("Settings",true,false) as Button).pressed.emit()
	check(game.paused,"settings keeps race paused")
	(hud.pause_menu.find_child("Back",true,false) as Button).pressed.emit()
	(hud.pause_menu.find_child("Resume",true,false) as Button).pressed.emit()
	check(not game.paused and not hud.pause_menu.visible and hud.touch.enabled,"resume restores driving")
	await process_frame
	for emitter: GPUParticles3D in game.sand_dust.dust_emitters:
		check(emitter.speed_scale == 1.0,"dust resumes")
	root.size = Vector2i(960,540)
	for i: int in range(4): await RenderingServer.frame_post_draw
	game.toggle_pause()
	for i: int in range(4): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path+"/960x540.png") == OK,"compact capture saved")
	game.toggle_pause()
	game.queue_free()
	await process_frame
	print("PAUSE_MENU_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
