extends SceneTree
## Scripted engine evidence, not a human driving session.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1672, 941)
	var scene: Node = load("res://core/game.tscn").instantiate()
	scene.set("production_mode", true)
	scene.set("initial_track", NativeTrack.read("res://resources/tracks/slicks_freeway_test.json"))
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.set("paused", true)
	var hud: PlaygroundHUD = scene.get("hud")
	hud.handling_button.show_popup()
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../build/handling-selector.png")
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Handling capture failed")
		quit(1)
		return
	print("CAPTURE_SAVED: ", path)
	scene.queue_free()
	await process_frame
	quit()
