extends SceneTree
## KTD01-KTD04: licensed replacement, seated fit, both quality tiers and caches.
const OUT: String = "res://../docs/evidence/kart-tomkart-driver-2026-11-08"
const DRIVER: ArrayMesh = preload("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
const BASE = preload("res://vehicle/modular_car_base.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("TOMKART_FAIL ",label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check(DRIVER.get_faces().size()/3 == 1445,"complete source driver triangle count")
	check(DRIVER.get_surface_count() == 8,"all eight source material roles preserved")
	check(DRIVER.get_aabb().position.y > 0.15 and DRIVER.get_aabb().end.y < 1.15,"driver stays above floor and within believable seated height")
	check(DRIVER.get_aabb().size.x < 0.65 and DRIVER.get_aabb().size.z < 1.4,"driver fits within original kart cockpit")
	for surface: int in range(DRIVER.get_surface_count()):
		var arrays: Array = DRIVER.surface_get_arrays(surface)
		var finite: bool = true
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and vertex.is_finite()
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and normal.is_finite() and normal.length_squared() > 0.8
		check(finite,"finite seated mesh and normals "+str(surface))
		var material: StandardMaterial3D = DRIVER.surface_get_material(surface)
		check(material != null and material.albedo_texture != null,"textured source material "+str(surface))
		check(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size(),"source UV coordinates retained "+str(surface))
		var atlases: Dictionary = {"RT_DriverSuit":"RT_DriverSuit_baseColor.png","RT_Gloves":"RT_Gloves_baseColor.png","RT_Helemt":"RT_Helemt_trasparent_baseColor.png"}
		if atlases.has(material.resource_name):
			var expected: Image = Image.load_from_file("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/textures/"+atlases[material.resource_name])
			var actual: Image = material.albedo_texture.get_image()
			expected.convert(Image.FORMAT_RGBA8)
			actual.convert(Image.FORMAT_RGBA8)
			check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(),"shipping material embeds reviewed unbranded atlas "+material.resource_name)
	var credit: String = FileAccess.get_file_as_string("res://legal/kart_driver_notices.txt")
	check(credit.contains("tomkart") and credit.contains("CC-BY-4.0") and credit.contains("modifications"),"bundled creator credit, license and modifications")
	var listed: bool = false
	for entry: Dictionary in preload("res://legal/third_party_notices.gd").entries("Windows",false):
		if entry.id == "kart_driver": listed = preload("res://legal/third_party_notices.gd").text_for(entry) == credit
	check(listed,"creator credit reachable through existing Licences panel")
	preload("res://ui/garage_car_cache.gd").enabled = false
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").entries.clear()
	BASE.enabled = prepared
	for simple: bool in [false,true]:
		for editable: bool in [false,true]:
			var before_hits: int = BASE.hits
			var car := CarVisual.new()
			car.vehicle_id = "kart"
			car.simple_model = simple
			car.editable_kits = editable
			root.add_child(car)
			while not car.model_ready: await process_frame
			var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
			check(driver != null,"new driver in tier/kit mode %s/%s" % [simple,editable])
			if driver != null:
				check(driver.mesh.get_faces().size()/3 == 1445,"complete driver survives car batching")
				check(driver.get_parent() == car.body,"driver follows body suspension")
				check(driver.mesh.get_surface_count() == 8,"car batching retains all driver materials")
			check(car.find_child("TailoredRaceSuitV4",true,false) == null and car.find_child("HelmetMount",true,false) == null,"previous driver and helmet are absent")
			check(car.front_wheels.size() == 2 and car.rolling_wheels.size() == 4,"wheel articulation preserved")
			if prepared:
				check(BASE.hits == before_hits+1,"current prepared base actually restored")
				if BASE.hits != before_hits+1:
					var packed: PackedScene = load(BASE.path_for(car))
					var holder: Node3D = packed.instantiate()
					var data: Dictionary = holder.get_meta("modular_car_base",{})
					var actual: Dictionary = preload("res://vehicle/prepared_asset_sources.gd").runtime_hashes("kart")
					var differences: Array[String] = []
					for path: String in actual:
						if data.sources.get(path) != actual[path]: differences.append(path)
					print("TOMKART_CACHE_DIAGNOSTIC ",{"eligible":BASE._eligible(car),"key_matches":data.key == BASE.key_for(car),"valid_holder":BASE._valid_holder(holder,data),"source_differences":differences})
					holder.free()
			var original: Array = [driver.mesh,driver.transform] if driver != null else []
			var paint: Dictionary = VehicleLivery.defaults("kart")
			paint.colors.body = "#245577"
			car.apply_livery(paint)
			if driver != null: check([driver.mesh,driver.transform] == original,"paint changes leave the driver unchanged")
			if DisplayServer.get_name() != "headless" and not editable:
				await capture(car,simple)
			car.free()
			await process_frame
	if prepared:
		var garage = preload("res://ui/garage_car_cache.gd")
		garage.enabled = true
		var before_hits: int = garage.hits
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = false
		car.editable_kits = true
		car.garage_template = true
		root.add_child(car)
		while not car.model_ready: await process_frame
		var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
		check(garage.hits == before_hits+1,"full-detail Garage template actually restored")
		check(driver != null and driver.mesh.get_faces().size()/3 == 1445,"Garage template contains the complete replacement")
		check(car.rolling_wheels.size() == 4,"Garage template retains four articulated wheels")
		car.free()
	print("TOMKART_DRIVER ",checks," checks, ",failures," failures; prepared=",prepared)
	FileAccess.open(OUT+"/test-"+("prepared" if prepared else "direct")+"-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"prepared":prepared},"\t"))
	quit(1 if failures else 0)

func capture(car: CarVisual, simple: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	car.reparent(world)
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
		var path: String = OUT+"/"+("simple-" if simple else "full-")+shot[0]+"-"+RenderingServer.get_current_rendering_method()+".png"
		check(viewport.get_texture().get_image().save_png(path) == OK,"native production driver capture "+shot[0])
	car.reparent(root)
	viewport.free()
