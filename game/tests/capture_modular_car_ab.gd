extends SceneTree
## Unscored, isolated comparison of procedural and modular race presentation.
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Cache = preload("res://vehicle/prepared_car_cache.gd")
var stage: Node3D
var viewport: SubViewport
var output: String
var rows: Array = []
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func make_car(vehicle: String, parts: Dictionary, prepared: bool, decorated: bool = false) -> CarVisual:
	Cache.enabled = prepared
	Base.enabled = prepared
	Kits.enabled = prepared
	Cache.entries.clear()
	var car := CarVisual.new()
	car.vehicle_id = vehicle
	car.customisation = parts.duplicate(true)
	car.livery = VehicleLivery.defaults(vehicle)
	if decorated:
		car.livery.colors.body = "277ab1"
		car.livery.colors.accent = "f0d58b"
		car.livery.pattern = str(LiveryCatalog.patterns[0].id)
		car.livery.stickers.hood.id = str(LiveryCatalog.stickers[0].id)
		car.livery.stickers.hood.size = 0.8
		if LiveryCatalog.has_roof(vehicle): car.livery.stickers.roof.id = str(LiveryCatalog.stickers[0].id)
	stage.add_child(car)
	return car

func capture(car: CarVisual, filename: String, decorated: bool = false) -> Image:
	while not car.model_ready: await process_frame
	var weather: VehicleWeathering
	if decorated:
		weather = VehicleWeathering.new()
		weather.configure(car,"desert",VehicleCatalog.config(car.vehicle_id))
		weather.restore({"dirt":0.55,"slow_dirt":0.20,"color":"c7ae7c","mud":0.0,"smudge":0.25})
		if weather.materials.is_empty(): failures += 1
	for frame: int in range(5): await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image.save_png(output.path_join(filename)) != OK: failures += 1
	if weather != null: weather.reset()
	return image

func difference(a: Image, b: Image) -> Dictionary:
	if a.get_size() != b.get_size() or a.get_format() != b.get_format(): return {"invalid":true}
	var first: PackedByteArray = a.get_data()
	var second: PackedByteArray = b.get_data()
	var changed: int = 0
	var sum: int = 0
	var max_delta: int = 0
	for pixel: int in range(first.size()/4):
		var different: bool = false
		for channel: int in range(3):
			var index: int = pixel*4+channel
			var delta: int = absi(int(first[index])-int(second[index]))
			sum += delta
			max_delta = maxi(max_delta,delta)
			if delta != 0: different = true
		if different: changed += 1
	return {"changed_pixels":changed,"mean_rgb_delta":float(sum)/(first.size()/4*3),"max_channel_delta":max_delta}

func compare_case(vehicle: String, fitted: bool, selections: Dictionary, decorated: bool = false) -> void:
	var parts: Dictionary = VehicleCustomisation.defaults()
	if fitted: parts.merge(selections,true)
	var label: String = vehicle+("-fitted" if fitted else "-stock")+("-decorated" if decorated else "")
	var baseline: CarVisual = make_car(vehicle,parts,false,decorated)
	var before: Image = await capture(baseline,label+"-procedural.png",decorated)
	baseline.free()
	await process_frame
	var old_base: int = Base.hits
	var old_kits: int = Kits.hits
	var candidate: CarVisual = make_car(vehicle,parts,true,decorated)
	var after: Image = await capture(candidate,label+"-modular.png",decorated)
	var base_hits: int = Base.hits-old_base
	var kit_hits: int = Kits.hits-old_kits
	if base_hits != 1 or (fitted and kit_hits != 4):
		print("FAIL modular resource hits ",label," base=",base_hits," kits=",kit_hits)
		failures += 1
	candidate.free()
	await process_frame
	var control: CarVisual = make_car(vehicle,parts,false,decorated)
	var restored: Image = await capture(control,label+"-procedural-control.png",decorated)
	control.free()
	await process_frame
	var row: Dictionary = {"case":label,"base_hits":base_hits,"kit_hits":kit_hits,"difference":difference(before,after),"control_difference":difference(before,restored)}
	rows.append(row)
	print("MODULAR_VISUAL ",JSON.stringify(row))

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("A graphical renderer is required"); quit(1); return
	output = ProjectSettings.globalize_path("res://../build/modular-car-visual")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(5.4,3.8,-7.1)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-35,0)
	light.shadow_enabled = true
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("647158")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	stage.add_child(environment)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24,24)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.02
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("73796c")
	floor_mat.roughness = 1.0
	floor.material_override = floor_mat
	stage.add_child(floor)
	var cases: Dictionary = {
		"compact":{"hood":"scoop","aero":"wing","rims":"split","body":"rally"},
		"kart":{"hood":"sprint","aero":"loop","rims":"three","body":"sprint"},
		"hovercraft":{"hood":"hover_blade","aero":"hover_low","rims":"hover_turbine","body":"hover_sport"}}
	var decorated_only: bool = "--decorated-only" in OS.get_cmdline_user_args()
	for vehicle: String in cases:
		if not decorated_only: await compare_case(vehicle,false,cases[vehicle])
		await compare_case(vehicle,true,cases[vehicle],decorated_only)
	var file: FileAccess = FileAccess.open(output.path_join("report-decorated.json" if decorated_only else "report.json"),FileAccess.WRITE)
	if file == null: failures += 1
	else: file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"rows":rows,"failures":failures},"\t")); file.close()
	viewport.free()
	print("MODULAR_VISUAL_FAILURES ",failures)
	quit(1 if failures else 0)
