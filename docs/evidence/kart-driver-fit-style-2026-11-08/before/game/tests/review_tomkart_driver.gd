extends SceneTree
## Offline source/pose preview; never reads owner records or contacts the backend.
const OUT: String = "res://../docs/evidence/kart-tomkart-driver-2026-11-08"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var folder: String = "res://../build/kart-driver-tomkart-2026-11-08/candidate"
	var error: Error = document.append_from_file(ProjectSettings.globalize_path(folder+"/driver.gltf"),state)
	assert(error == OK)
	var imported: Node3D = document.generate_scene(state)
	assert(imported != null)
	var meshes: Array[Node] = imported.find_children("*","MeshInstance3D",true,false)
	if imported is MeshInstance3D: meshes.push_front(imported)
	assert(meshes.size() == 1)
	var driver: MeshInstance3D = meshes[0]
	if "--save" in OS.get_cmdline_user_args():
		var target: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
		assert(ResourceSaver.save(driver.mesh,target+"/driver.res",ResourceSaver.FLAG_COMPRESS) == OK)
		print("TOMKART_NATIVE_MESH_SAVED ",driver.mesh.get_faces().size()/3)
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
	car.simple_model = false
	car.batch_parts = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	world.add_child(car)
	while not car.model_ready: await process_frame
	# Preview the imported driver in the real kart before replacing production.
	for child: Node in car.body.get_children():
		var label: String = str(child.name)
		if label.begins_with("TailoredRaceSuit") or label.begins_with("Collar") or label.begins_with("Balaclava") or label.begins_with("Suit") or label.begins_with("ContinuousTrouser") or label.begins_with("RaceBoot") or label.begins_with("BootSole") or label.begins_with("UpperSleeve") or label.begins_with("Sleeve") or label.begins_with("RacingGlove") or label.begins_with("GloveGrip") or label.begins_with("TrouserKnee") or label == "HelmetMount" or label == "TomkartDriver":
			child.queue_free()
	car.body.add_child(imported)
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 32
	for shot: Array in [["front",Vector3(-1.8,1.35,-2.7),Vector3(0,.57,-.12)], ["side",Vector3(-2.3,.82,.15),Vector3(0,.53,-.12)], ["rear",Vector3(1.8,1.2,2.3),Vector3(0,.57,0)], ["overhead",Vector3(0,4.2,2.0),Vector3(0,.3,0)]]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for frame: int in range(6):
			await process_frame
			await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(OUT+"/draft-"+shot[0]+".png") == OK)
	viewport.free()
	quit()
