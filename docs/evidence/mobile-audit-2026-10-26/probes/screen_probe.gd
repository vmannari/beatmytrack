extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var started: int = Time.get_ticks_usec()
	var app: Node = load("res://core/app.tscn").instantiate()
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	print("SCREEN_STARTUP ",JSON.stringify({"ready":app.startup_complete,"milliseconds":(Time.get_ticks_usec()-started)/1000.0}))
	if not app.startup_complete: quit(1); return
	var folder: String = ProjectSettings.globalize_path("res://../build/mobile-audit-2026-10-26/screen-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	for screen: String in ["account","tracks","garage","settings","store","create"]:
		var before: int = Time.get_ticks_usec()
		app._show_screen(screen)
		for index: int in range(10): await process_frame
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png(folder.path_join(screen+".png"))
		print("SCREEN_CAPTURE ",JSON.stringify({"screen":screen,"actual":app.screen,"milliseconds":(Time.get_ticks_usec()-before)/1000.0,"error":error}))
	app.queue_free()
	await process_frame
	await process_frame
	quit()
