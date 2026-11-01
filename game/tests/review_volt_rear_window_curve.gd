extends SceneTree
## Matched overhead and rear-quarter views of the marked glass/deck join.
var output := "res://../docs/evidence/volt-curved-rear-window-2026-10-31/review"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var builder = preload("res://vehicle/electric_reference_mesh.gd")
	builder.use_baked = "--prepared" in OS.get_cmdline_user_args()
	builder.meshes.clear()
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(720,960)
	var result: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"captures":[],"sources":{},"failures":0}
	for name_value: String in ["electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_mesh.gd"]:
		result.sources[name_value] = FileAccess.get_sha256("res://vehicle/"+name_value)
	for blue: bool in [false,true]:
		var room := CarShowroom.new()
		room.vehicle_id = "electric"
		room.read_only = true
		room.garage_mode = true
		room.size = Vector2(root.size)
		room.livery = VehicleLivery.defaults("electric")
		if blue:
			room.livery.colors.body = "345368"
			room.livery.colors.accent = "345368"
		room.customisation = VehicleCustomisation.defaults()
		root.add_child(room)
		while not room.showroom_ready: await process_frame
		if is_instance_valid(room.roof): room.roof.hide()
		for shot: Array in [
			["top",Vector3(0,7,0),Vector3(0,0.6,0),4.6],
			["top-rear",Vector3(0,7,1.3),Vector3(0,0.8,1.3),2.5],
			["rear-quarter",Vector3(-4.2,3.4,5.9),Vector3(0,0.65,0.45),0.0]]:
			room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL if float(shot[3])>0 else Camera3D.PROJECTION_PERSPECTIVE
			room.camera.size = float(shot[3]) if float(shot[3])>0 else 2.35
			room.camera.fov = 32
			room.camera.global_position = room.car.body.to_global(shot[1])
			room.camera.look_at(room.car.body.to_global(shot[2]),(room.car.body.global_basis*Vector3.FORWARD).normalized() if float(shot[3])>0 else Vector3.UP)
			for frame: int in range(8):
				room.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				room.reflections.request_draw()
				await process_frame
				await RenderingServer.frame_post_draw
			var label: String = str(shot[0])+("-blue" if blue else "-silver")
			var error: Error = room.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
			result.captures.append({"name":label,"error":error})
			if error!=OK: result.failures+=1
		room.queue_free()
		await process_frame
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("VOLT_REAR_CURVE_REVIEW: ",JSON.stringify(result))
	quit(1 if result.failures else 0)
