extends SceneTree
## Real prepared Compact and full Garage construction; ordinary guards stay active.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func fingerprint(car: Node3D) -> Dictionary:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	var meshes: int = 0
	var surfaces: int = 0
	for node: Node3D in car.find_children("*","Node3D",true,false):
		hash.update(var_to_bytes([str(car.get_path_to(node)),node.get_class(),node.transform,node.visible]))
		if node is MeshInstance3D and node.mesh != null:
			meshes += 1
			for index: int in range(node.mesh.get_surface_count()):
				surfaces += 1
				hash.update(var_to_bytes(node.mesh.surface_get_arrays(index)))
	return {"nodes":car.find_children("*","Node3D",true,false).size(),"meshes":meshes,"surfaces":surfaces,"geometry_sha256":hash.finish().hex_encode()}
func run() -> void:
	Engine.time_scale = 0.0
	root.size = Vector2i(960,540)
	var start: int = Time.get_ticks_usec()
	var showroom_script: Script = load("res://ui/car_showroom.gd")
	var graph_us: int = Time.get_ticks_usec()-start
	var bases: Script = load("res://vehicle/modular_car_base.gd")
	var garage: Script = load("res://ui/garage_car_cache.gd")
	var base_hits: int = bases.hits
	var car: Node3D = load("res://vehicle/car_visual.gd").new()
	car.vehicle_id = "compact"
	start = Time.get_ticks_usec()
	root.add_child(car)
	while not car.model_ready: await process_frame
	var base_us: int = Time.get_ticks_usec()-start
	check(bases.hits==base_hits+1,"Compact really restores its original prepared base under unchanged guards")
	check(car.model_ready and car.body!=null,"prepared Compact model completes")
	var base_shape: Dictionary = fingerprint(car)
	car.free()
	var garage_hits: int = garage.hits
	var view: Control = showroom_script.new()
	view.vehicle_id = "compact"
	view.garage_mode = true
	view.read_only = false
	view.size = Vector2(960,540)
	start = Time.get_ticks_usec()
	root.add_child(view)
	while not view.showroom_ready: await process_frame
	var garage_us: int = Time.get_ticks_usec()-start
	check(garage.hits==garage_hits+1,"full Garage really restores its original prepared car under unchanged guards")
	check(view.car.model_ready and view.showroom_ready,"full Garage and live model complete")
	check(view.camera!=null and view.reflections!=null and view.turntable!=null,"full Garage camera, reflections and turntable remain")
	var garage_shape: Dictionary = fingerprint(view.car)
	var native: bool = DisplayServer.get_name()!="headless"
	var pixels: String = ""
	if native:
		for frame: int in range(24): await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		capture.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("compact-garage.png"))
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(capture.get_data()); pixels = hash.finish().hex_encode()
	var world_loaded: bool = ResourceLoader.has_cached("res://track/native_track_visual.gd")
	if "--expect-world-unloaded" in OS.get_cmdline_user_args(): check(not world_loaded,"prepared car and full Garage do not import world builders")
	var result: Dictionary = {"checks":checks,"failures":failures,"graph_us":graph_us,"base_us":base_us,"garage_us":garage_us,"base":base_shape,"garage":garage_shape,"world_loaded":world_loaded,"native":native,"pixels_sha256":pixels}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	view.queue_free()
	for frame: int in range(6): await process_frame
	print("WORLD_TYPE_CONSTRUCTION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
