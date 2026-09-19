extends SceneTree
## Review all vehicle skins in actual gameplay, plus mirrored/large touch layout.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var output: String = ProjectSettings.globalize_path("res://").path_join("../build/controls").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	for id: String in VehicleCatalog.IDS:
		VehicleCatalog.selected = id
		var game: Node = load("res://core/game.tscn").instantiate()
		game.set("production_mode",true)
		root.add_child(game)
		game.set_physics_process(false)
		var hud: PlaygroundHUD = game.get("hud")
		assert(hud.touch.vehicle_id == id)
		for scale_value: float in [0.8,1.0,1.3]:
			for mirrored: bool in [false,true]:
				hud.touch.control_scale = scale_value
				hud.touch.left_handed = mirrored
				for i: int in range(4):
					assert(hud.touch.action_at(hud.touch.zones()[i].get_center()) == TouchControls.ACTIONS[i])
			hud.touch.control_scale = 1.0
			hud.touch.left_handed = false
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK)
		hud.touch.driver.set_touch(90,&"steer_left")
		hud.touch.driver.set_touch(91,&"accelerate")
		hud.touch.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(id+"-pressed.png")) == OK)
		hud.touch.driver.release_touch(90)
		hud.touch.driver.release_touch(91)
		game.queue_free()
		await process_frame
	print("CONTROLS: 5 vehicle bindings, 120 scaled/mirrored action targets passed; 10 gameplay captures")
	quit()
