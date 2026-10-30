extends SceneTree
## Every choice independently on the production Garage car, plus close-ups.
var output: String = "res://../docs/evidence/compact-kits-quality-2026-10-14/compatibility"
var showroom: CarShowroom
func _initialize() -> void: _run.call_deferred()
func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
func capture(path: String) -> void:
	await settle()
	assert(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join(path+".png"))==OK)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440,900)
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	showroom = CarShowroom.new()
	showroom.garage_mode = true
	showroom.livery = VehicleLivery.defaults("compact")
	host.add_child(showroom)
	MenuStyle.fill(showroom)
	await settle()
	var car: CarVisual = showroom.car
	var camera: Camera3D = showroom.camera
	var captures: int = 0
	for category: String in VehicleCustomisation.CATEGORIES:
		DirAccess.make_dir_recursive_absolute(output.path_join(category))
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var profile: Dictionary = VehicleCustomisation.defaults()
			profile[category] = option[0]
			showroom.apply_customisation(profile)
			assert(showroom.car==car and showroom.camera==camera)
			showroom.zoom = 0.57
			showroom.elevation = 0.25
			showroom.yaw = -0.68
			showroom._orbit()
			var prefix: String = category+"/"+str(option[0])
			await capture(prefix+"-front")
			showroom.yaw = PI-0.63
			showroom._orbit()
			await capture(prefix+"-rear")
			showroom.yaw = 0
			showroom._orbit()
			var target: Vector3
			var direction: Vector3
			match category:
				"hood":
					target = Vector3(0,1.04,-1.46)
					direction = Vector3(1.15,1.35,-1.35)
				"rims":
					target = Vector3(0.985,0.37,-1.28)
					direction = Vector3(0.87,0.09,-0.16)
				"aero":
					target = Vector3(0,1.34,1.95)
					direction = Vector3(1.8,0.55,1.8)
				_:
					target = Vector3(0.65,0.35,-1.10)
					direction = Vector3(1.65,0.30,-1.45)
			camera.look_at_from_position(showroom.car.body.global_transform*target+direction,showroom.car.body.global_transform*target)
			showroom.reflections.sync()
			await capture(prefix+"-detail")
			if category=="body":
				target = showroom.car.body.global_transform*Vector3(0,0.34,1.95)
				camera.look_at_from_position(target+Vector3(1.5,0.22,1.7),target)
				showroom.reflections.sync()
				await capture(prefix+"-diffuser")
			captures += 4 if category=="body" else 3
	print("COMPACT_KIT_REVIEW: ",captures," actual car views; all 43 choices")
	host.queue_free()
	await process_frame
	quit()
