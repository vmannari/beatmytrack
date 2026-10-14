extends SceneTree
## Real showroom replacement, effect cancellation and zoom/condition regression.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-car-transition-2026-10-12"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await frame()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture " + name)
func materials(node: Node, result: Array[Material]) -> void:
	if node is MeshInstance3D:
		for index: int in range(node.mesh.get_surface_count()): result.append(node.get_active_material(index))
	for child: Node in node.get_children(): materials(child,result)
func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,540)
	var directory: String = "user://garage_transition_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	var wear: Dictionary = VehicleWeathering.new().snapshot()
	wear.dirt = 0.85
	check(VehicleCondition.save(app.records,"compact",wear) == OK,"seed local condition")
	app._show_screen("garage")
	await create_timer(0.3).timeout
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	var view: CarShowroom = page.showroom
	view.set_zoom(0.87)
	view.rotate_view(Vector2(15,-2))
	var camera_pose: Transform3D = view.camera.transform
	var tilt: float = view.elevation
	var yaw: float = view.yaw
	var room: Node = view.showroom_viewport.find_child("GarageArchitecture",true,false)
	var viewport: SubViewport = view.showroom_viewport
	await capture("before-switch")
	page.preview_car(1)
	check(view == page.showroom and viewport == view.showroom_viewport and room == viewport.find_child("GarageArchitecture",true,false),"replacement retains showroom, viewport and room")
	check(view.zoom == 0.87 and view.elevation == tilt and view.yaw == yaw and view.camera.transform.is_equal_approx(camera_pose),"preview preserves actual camera and zoom/tilt/rotation")
	check(view.incoming_reveal.visibility == 0 and view.outgoing_reveal.visibility == 1 and not view.turntable.visible,"outgoing car disappears before incoming car appears")
	view.car_motion.pause()
	view.car_motion.custom_step(0.09)
	check(view.outgoing_reveal.visibility > 0 and view.outgoing_reveal.visibility < 1,"outgoing effect has intermediate opacity")
	await capture("disappearing")
	view.car_motion.custom_step(0.091)
	check(view.turntable.visible and not view.outgoing_pedestal.visible and view.incoming_reveal.visibility < 0.01,"exchange occurs with incoming car fully dissolved")
	await capture("empty-pedestal")
	view.car_motion.custom_step(0.12)
	check(view.incoming_reveal.visibility > 0 and view.incoming_reveal.visibility < 1,"incoming effect has intermediate opacity")
	await capture("appearing")
	view.car_motion.custom_step(0.13)
	await frame()
	check(view.car_motion == null and view.outgoing_pedestal == null and view.incoming_reveal == null,"completed effect releases outgoing model and restores materials")
	var original: Array[Material] = []
	materials(view.car,original)
	var shared_before: Array[Material] = []
	materials((page.thumbnails.pickup as CarShowroom).car,shared_before)
	page._confirm_car()
	check(view.zoom == 0.87 and view.camera.transform.is_equal_approx(camera_pose) and VehicleCatalog.selected == "pickup","Select car confirms without resetting zoom or camera")
	check(view.car_motion == null,"confirming current preview does not replay replacement")
	page._show_section("cars")
	page.preview_car(2)
	page.preview_car(4)
	page._confirm_car()
	check(view.car.vehicle_id == "kart" and VehicleCatalog.selected == "kart" and view.zoom == 0.87,"rapid preview and confirmation retain last car and zoom")
	view.finish_car_transition()
	await frame()
	check(view.turntable.visible and view.car_motion == null and viewport.find_children("Turntable*","Node3D",true,false).size() == 1,"rapid cancellation leaves one visible car pedestal")
	var shared_after: Array[Material] = []
	materials((page.thumbnails.pickup as CarShowroom).car,shared_after)
	check(shared_before == shared_after,"transition never changes carousel/shared materials")
	check(VehicleCondition.read(app.records,"compact").dirt == 0.85 and float(VehicleCondition.read(app.records,"kart").get("dirt",0.0)) == 0,"per-car local condition survives replacement")
	page._show_section("cars")
	page.preview_car(0)
	page._show_section("trophies")
	check(view.car_motion == null and view.trophy_view,"trophy camera cancels car effect")
	page._show_section("care")
	await create_timer(0.75).timeout
	check(view.camera.transform.is_equal_approx(camera_pose) and view.zoom == 0.87,"trophy return retains pre-selection zoom and pose")
	page._show_section("cars")
	page.preview_car(1)
	page.hide()
	check(view.car_motion == null and view.turntable.visible,"hiding page settles effect")
	page.show()
	view.reset_view()
	check(view.zoom == 1 and view.garage_distance > 0,"explicit Reset still restores default framing")
	if "--capture-motion" in OS.get_cmdline_user_args():
		var frames: String = ProjectSettings.globalize_path("res://../build/garage-car-motion-2026-10-12")
		DirAccess.make_dir_recursive_absolute(frames)
		for index: int in range(120):
			if index == 12: page.preview_car(0)
			if index == 60: page.preview_car(2)
			if view.car_motion != null:
				view.car_motion.pause()
				view.car_motion.custom_step(1.0/30.0)
			await frame()
			check(root.get_texture().get_image().save_png(frames.path_join("turntable-%03d.png"%index)) == OK,"actual transition frame " + str(index))
	await capture("after-switch")
	app.queue_free()
	await process_frame
	print("GARAGE_CAR_TRANSITION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
