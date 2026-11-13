extends SceneTree
## Identical studio views of the real factory cars, without prepared geometry.
var output: String = "res://../docs/evidence/challenger-panels-2026-11-12"
var stage: String = "after"
func _initialize() -> void: run.call_deferred()

func signature(car: CarVisual) -> String:
	var values: Array = [car.scale,car.wheel_radii,car.wheel_rest_positions]
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		values.append([car.get_path_to(part),part.transform,part.cast_shadow])
		for surface: int in range(part.mesh.get_surface_count()): values.append(part.mesh.surface_get_arrays(surface))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(values))
	return hash.finish().hex_encode()

func settle() -> void:
	for frame: int in range(6):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage = argument.trim_prefix("--stage=")
	var folder: String = output.path_join(stage).path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280,600)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var views: Array[CarShowroom] = []
	var result: Dictionary = {}
	for index: int in range(2):
		var id: String = ["compact","super_rally"][index]
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.livery = VehicleLivery.defaults(id)
		view.customisation = VehicleCustomisation.defaults()
		view.position = Vector2(index*640,40)
		view.size = Vector2(640,540)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		views.append(view)
		result[id] = {"geometry":signature(view.car)}
		var label := Label.new()
		label.text = VehicleCatalog.title(id)
		label.position = Vector2(index*640+24,4)
		label.add_theme_font_size_override("font_size",26)
		root.add_child(label)
	for angle: Array in [["front",-0.70,atan(0.32)],["rear",2.45,atan(0.32)],["side",-PI/2,0.15],["overhead",-0.40,1.02]]:
		for view: CarShowroom in views:
			view.yaw = angle[1]
			view.elevation = angle[2]
			view.zoom = 1.2
			view._orbit()
			view.invalidate_render()
		await settle()
		if DisplayServer.get_name() != "headless":
			assert(root.get_texture().get_image().save_png(folder.path_join(str(angle[0])+".png")) == OK)
	var file := FileAccess.open(folder.path_join("geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	for view: CarShowroom in views: view.free()
	print("SUPER_RALLY_DESIGN_REVIEW ",stage," ",JSON.stringify(result))
	quit()
