extends SceneTree
## Native Garage lighting, actual room batching and isolated local preferences.
var output: String = "res://../docs/evidence/garage-plant-2026-10-15/final/gl_compatibility"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func capture(view: CarShowroom, label: String) -> void:
	for index: int in range(16): await process_frame
	await RenderingServer.frame_post_draw
	check(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"save "+label)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440,900)
	var records := LocalRecords.new("user://plant_inspection_"+TrackLibrary.unique_id()+".json")
	var page := GaragePage.new()
	page.records = records
	root.add_child(page)
	MenuStyle.fill(page)
	for index: int in range(20): await process_frame
	var view: CarShowroom = page.showroom
	var room: Node = view.showroom_viewport.find_child("GarageArchitecture",true,false)
	var plant: Node3D = room.find_child("GarageDisplayPlant",true,false)
	check(plant != null,"plant present in prepared architecture")
	check(plant.position == Vector3(-9.55,0,-2.1),"original placement retained")
	await capture(view,"garage")
	page._confirm_car()
	page._show_section("trophies")
	await create_timer(0.8).timeout
	await capture(view,"trophy-view")
	view.camera.position = Vector3(-6.5,2.45,-5.8)
	view.camera.look_at(Vector3(-9.55,1.12,-2.1))
	await capture(view,"plant-front")
	view.camera.position = Vector3(-8.2,2.5,0.8)
	view.camera.look_at(Vector3(-9.55,1.12,-2.1))
	await capture(view,"plant-reverse")
	view.camera.position = Vector3(-8.5,1.88,-3.2)
	view.camera.look_at(Vector3(-9.55,1.42,-2.1))
	await capture(view,"leaf-detail")
	view.camera.position = Vector3(-8.5,1.02,-3.2)
	view.camera.look_at(Vector3(-9.55,0.42,-2.1))
	await capture(view,"planter-detail")
	check(records.settings.get("vehicle_conditions",{}).is_empty(),"inspection does not write car condition")
	page.queue_free()
	await process_frame
	print("GARAGE_PLANT_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
