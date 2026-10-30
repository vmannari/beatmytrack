extends SceneTree
## Two opposite close views of every actual kit in the retained Garage world.
var output: String = "res://../docs/evidence/kart-kit-surface-fix-2026-10-29/native"
var captures: int = 0
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var view := CarShowroom.new()
	view.vehicle_id = "kart"
	view.garage_mode = true
	view.livery = VehicleLivery.defaults("kart")
	root.add_child(view)
	MenuStyle.fill(view)
	while not view.showroom_ready: await process_frame
	await settle()
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.options(category,"kart"):
			if option[0]=="stock": continue
			var parts: Dictionary = VehicleCustomisation.defaults()
			parts[category] = option[0]
			view.apply_customisation(parts)
			view.yaw = 0
			view._orbit()
			for side: int in [-1,1]:
				var target: Vector3
				var direction: Vector3
				match category:
					"hood": target = Vector3(0,0.34,-1.06); direction = Vector3(side*1.35,0.95,-1.9)
					"body": target = Vector3(side*0.54,0.28,-0.08); direction = Vector3(side*1.6,0.50,-0.9)
					"rims": target = Vector3(side*0.65,0.22,-0.88); direction = Vector3(side*1.0,0.10,-0.18)
					"aero": target = Vector3(0,0.24,1.28); direction = Vector3(side*1.25,0.20,1.6)
				var at: Vector3 = view.car.body.global_transform*target
				view.camera.look_at_from_position(at+direction,at)
				view.invalidate_render()
				if view.reflections!=null: view.reflections.sync()
				await settle()
				var label: String = category+"-"+str(option[0])+("-left" if side<0 else "-right")
				assert(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
				captures += 1
	view.free()
	await process_frame
	print("KART_KIT_SURFACE_VIEWS: ",captures," native views")
	quit()
