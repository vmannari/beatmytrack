extends SceneTree
## Actual Garage: tire stance, rolled fender lips, wheelhouses and steering.
var output := "res://../docs/evidence/volt-fenders-2026-10-31/review"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var builder = preload("res://vehicle/electric_reference_mesh.gd")
	builder.use_baked = "--prepared" in OS.get_cmdline_user_args()
	builder.meshes.clear()
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440,900)
	var room := CarShowroom.new()
	room.vehicle_id = "electric"
	room.read_only = true
	room.garage_mode = true
	room.size = Vector2(root.size)
	room.livery = VehicleLivery.defaults("electric")
	room.customisation = VehicleCustomisation.defaults()
	root.add_child(room)
	while not room.showroom_ready: await process_frame
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"captures":[],"sources":{},"failures":0}
	for file: String in ["electric_reference_body.gd","electric_reference_details.gd","electric_reference_mesh.gd"]:
		report.sources[file] = FileAccess.get_sha256("res://vehicle/"+file)
	var shots: Array = [
		["front",Vector3(0,0.65,-6.8),Vector3(0,0.58,-0.2),0.0,0.0],
		["front-quarter",Vector3(-4.3,1.55,-5.2),Vector3(0,0.55,-0.2),0.0,0.0],
		["left-front-low",Vector3(-2.3,0.62,-2.25),Vector3(-0.78,0.5,-1.398),1.08,0.0],
		["right-front-low",Vector3(2.3,0.62,-2.25),Vector3(0.78,0.5,-1.398),1.08,0.0],
		["front-side",Vector3(-3.1,0.55,-1.398),Vector3(-0.78,0.5,-1.398),1.08,0.0],
		["rear-low",Vector3(-2.35,0.63,2.3),Vector3(-0.84,0.5,1.398),1.08,0.0],
		["under-front",Vector3(-2.2,0.18,-2.7),Vector3(-0.7,0.5,-1.398),1.15,0.0],
		["steer-left",Vector3(-2.3,0.62,-2.25),Vector3(-0.78,0.5,-1.398),1.08,-0.4],
		["steer-right",Vector3(-2.3,0.62,-2.25),Vector3(-0.78,0.5,-1.398),1.08,0.4]]
	for shot: Array in shots:
		for wheel: Node3D in room.car.front_wheels: wheel.rotation.y = shot[4]
		room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL if float(shot[3])>0 else Camera3D.PROJECTION_PERSPECTIVE
		room.camera.size = float(shot[3]) if float(shot[3])>0 else 2.35
		room.camera.fov = 32
		room.camera.global_position = room.car.body.to_global(shot[1])
		room.camera.look_at(room.car.body.to_global(shot[2]))
		for frame: int in range(6):
			room.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			room.reflections.request_draw()
			await process_frame
			await RenderingServer.frame_post_draw
		var saved: Error = room.showroom_viewport.get_texture().get_image().save_png(output.path_join(str(shot[0])+".png"))
		report.captures.append({"name":shot[0],"error":saved})
		if saved != OK: report.failures += 1
	room.queue_free()
	await process_frame
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_FENDER_REVIEW: ",JSON.stringify(report))
	quit(1 if report.failures else 0)
