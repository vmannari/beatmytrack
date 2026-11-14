extends SceneTree
## Offline source/pose preview; never reads owner records or contacts the backend.
var OUT: String = "res://../docs/evidence/kart-driver-race-scale-2026-11-12"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): OUT = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	var imported := MeshInstance3D.new()
	var path: String = OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res" if before else "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
	imported.mesh = load(path)
	assert(imported.mesh != null)
	if imported.mesh.get_surface_count() == 2:
		var helmet := MeshInstance3D.new()
		helmet.name = "HelmetStatic"
		helmet.mesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res" if before else "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
		imported.add_child(helmet)
	if DisplayServer.get_name() == "headless":
		imported.free()
		quit()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "kart"
	car.simple_model = "--simple" in OS.get_cmdline_user_args()
	car.batch_parts = prepared
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	world.add_child(car)
	while not car.model_ready: await process_frame
	if not prepared:
		# Preview the imported driver in the real kart before replacing production.
		for child: Node in car.body.get_children():
			var label: String = str(child.name)
			if label.begins_with("TailoredRaceSuit") or label.begins_with("Collar") or label.begins_with("Balaclava") or label.begins_with("Suit") or label.begins_with("ContinuousTrouser") or label.begins_with("RaceBoot") or label.begins_with("BootSole") or label.begins_with("UpperSleeve") or label.begins_with("Sleeve") or label.begins_with("RacingGlove") or label.begins_with("GloveGrip") or label.begins_with("TrouserKnee") or label == "HelmetMount" or label == "TomkartDriver":
				child.queue_free()
		car.body.add_child(imported)
	else:
		imported.free()
		var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
		assert(driver != null and driver.mesh.get_blend_shape_count() == preload("res://vehicle/kart_steering.gd").STEPS*2)
		assert(preload("res://vehicle/modular_car_base.gd").hits > 0)
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 32
	for shot: Array in [["front",Vector3(-1.8,1.35,-2.7),Vector3(0,.57,-.12)], ["side",Vector3(-2.3,.82,.15),Vector3(0,.53,-.12)], ["side-right",Vector3(2.3,.82,.15),Vector3(0,.53,-.12)], ["rear",Vector3(1.8,1.2,2.3),Vector3(0,.57,0)], ["overhead",Vector3(0,4.2,2.0),Vector3(0,.3,0)], ["feet",Vector3(1.1,.63,-1.3),Vector3(0,.27,-.83)], ["body",Vector3(1.1,.87,-.9),Vector3(0,.68,-.015)], ["knees",Vector3(0,1.6,-1.2),Vector3(0,.44,-.43)], ["wrists",Vector3(1.0,.95,-.9),Vector3(0,.56,-.25)], ["backrest",Vector3(1.25,.70,.35),Vector3(0,.49,.22)], ["shoulders-front",Vector3(0,1.0,-1.7),Vector3(0,.72,.28)], ["shoulders-rear",Vector3(0,1.05,1.9),Vector3(0,.69,.28)]]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for frame: int in range(6):
			await process_frame
			await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(OUT+("/cached-" if prepared else "/before-" if before else "/after-")+shot[0]+".png") == OK)
	camera.current = false
	var race := FollowCamera.new()
	world.add_child(race)
	race.current = true
	race.speed_zoom_enabled = false
	race.follow(Vector2.ZERO,Vector2.ZERO,0,0,true)
	for frame: int in range(8): await process_frame; await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(OUT+("/before-" if before else "/cached-" if prepared else "/after-")+"race-camera.png")==OK)
	viewport.free()
	quit()
