extends SceneTree
## Three native views per cabin frame, using the shipped Garage model path.

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size=Vector2i(1280,960)
	root.content_scale_size=root.size
	var output: String="res://../docs/evidence/forklift-cabin-variation-2026-11-03"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var views: Dictionary={"native":Vector3(-2.70,1.80,2.80),"front":Vector3(-2.70,1.50,-2.80),"side":Vector3(-3.80,0.55,0.0)}
	for view: String in views: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join(view)))
	var showroom:=CarShowroom.new()
	showroom.vehicle_id="forklift"
	showroom.garage_mode=true
	showroom.livery=VehicleLivery.defaults("forklift")
	root.add_child(showroom)
	MenuStyle.fill(showroom)
	while not showroom.showroom_ready: await process_frame
	var count: int=0
	for choice: Array in VehicleCustomisation.options("body","forklift"):
		var parts: Dictionary=VehicleCustomisation.defaults()
		parts.body=choice[0]
		showroom.apply_customisation(parts)
		for view: String in views:
			var at: Vector3=showroom.car.body.global_transform*Vector3(0,2.02,0.10)
			showroom.camera.look_at_from_position(at+showroom.car.body.global_transform.basis*views[view],at)
			showroom.invalidate_render()
			if showroom.reflections!=null: showroom.reflections.sync()
			for i: int in range(5): await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image=showroom.showroom_viewport.get_texture().get_image()
			assert(pixels.save_png(output.path_join(view).path_join("body-"+str(choice[0])+".png"))==OK)
			count+=1
			print("FORKLIFT_CABIN_VIEW ",choice[0],"/",view)
	showroom.free()
	print("FORKLIFT_CABIN_VIEWS: ",count," captures")
	quit()
