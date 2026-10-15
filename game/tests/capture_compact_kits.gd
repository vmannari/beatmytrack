extends SceneTree
## Actual Garage models, close-up fit/shading, live rotation and render work.
var output: String = "res://../docs/evidence/compact-kits-2026-10-13/close-compatibility"
var checks: int = 0
var failures: int = 0
var showroom: CarShowroom
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for frame: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await settle()
	check(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,label)
func closeup(label: String, target: Vector3, direction: Vector3) -> void:
	var camera: Camera3D = showroom.camera
	camera.look_at_from_position(target+direction,target)
	showroom.reflections.sync()
	await capture(label)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	var control := Control.new()
	root.add_child(control)
	MenuStyle.fill(control)
	showroom = CarShowroom.new()
	showroom.garage_mode = true
	showroom.livery = VehicleLivery.defaults("compact")
	control.add_child(showroom)
	MenuStyle.fill(showroom)
	await settle()
	var profiles: Array[Dictionary] = []
	var labels: Array[String] = []
	for option_index: int in range(10):
		var profile: Dictionary = VehicleCustomisation.defaults()
		for category: String in VehicleCustomisation.CATEGORIES:
			profile[category] = VehicleCustomisation.OPTIONS[category][option_index][0]
		profiles.append(profile)
		labels.append(str(VehicleCustomisation.OPTIONS.body[option_index][0]))
	for index: int in range(profiles.size()):
		showroom.apply_customisation(profiles[index])
		showroom.zoom = 0.55
		showroom.elevation = 0.27
		showroom.yaw = -0.67
		showroom._orbit()
		await capture(labels[index]+"-front")
		showroom.yaw = PI-0.65
		showroom._orbit()
		await capture(labels[index]+"-rear")
		showroom.yaw = 0
		showroom._orbit()
		var body: Transform3D = showroom.car.body.global_transform
		await closeup(labels[index]+"-hood",body*Vector3(0,1.02,-1.50),Vector3(1.2,1.4,-1.4))
		await closeup(labels[index]+"-rim",body*Vector3(0.99,0.37,-1.28),Vector3(1.10,0.12,-0.28))
		await closeup(labels[index]+"-aero",body*Vector3(0,1.49,1.27),Vector3(1.4,0.65,1.50))
		await closeup(labels[index]+"-body",body*Vector3(0.85,0.45,-0.65),Vector3(2.1,0.65,-1.4))
		for node: MeshInstance3D in showroom.car.find_children("*","MeshInstance3D",true,false):
			check(node.layers==7,"kit meshes remain in floor/deck captures")
	showroom._orbit()
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var views: Array[SubViewport] = [showroom.showroom_viewport]
	views.append_array(showroom.reflections.views)
	for view: SubViewport in views: RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	for frame: int in range(120):
		showroom.yaw += 0.025
		showroom._orbit()
		await process_frame
		await RenderingServer.frame_post_draw
		var cpu_ms: float = 0
		var gpu_ms: float = 0
		for view: SubViewport in views:
			cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		cpu.append(cpu_ms)
		gpu.append(gpu_ms)
		if frame%24==0: await capture("club-motion-"+str(frame))
	cpu.sort()
	gpu.sort()
	var file := FileAccess.open(output.path_join("render-work.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"motion_frames":120,"cpu_median_ms":cpu[60],"gpu_median_ms":gpu[60],"main_pixels":showroom.showroom_viewport.size,"reflection_pixels":showroom.reflections.views[0].size,"scope":"aggregate desktop viewport render work, not phone FPS"},"\t"))
	file.close()
	control.queue_free()
	await process_frame
	print("KIT_CAPTURES: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
