extends "res://tests/test_rivalry_custom_cars.gd"
## Native reflection ablation, front-facing pose and transparent-edge validation.
const Preview = preload("res://ui/rivalry_victory_car.gd")
var metrics: Dictionary = {}

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PODIUM_QUALITY: graphical renderer required")
		quit(0)
		return
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-podium-polish-2026-10-14/"+RenderingServer.get_current_rendering_method()+"/quality")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	var backdrop := ColorRect.new()
	backdrop.color = Color("15212c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	for id: String in VehicleCatalog.IDS:
		var value: Dictionary = appearance(0,id)
		value.livery.pattern = "plain"
		for panel: String in VehicleLivery.SURFACES: value.livery.stickers[panel].id = "none"
		var old: Control = make_preview(value,false,Vector2(30,155))
		var polished: Control = make_preview(value,true,Vector2(660,155))
		await draw()
		check(polished.car.simple_model and old.car.simple_model,id+" keeps simple geometry in both native comparisons")
		check(polished.car.livery == old.car.livery and polished.car.customisation == old.car.customisation,id+" retains exact local colour and fitted-part choices")
		check(is_equal_approx(polished.car.rotation.y,PI) and is_zero_approx(old.car.rotation.y),id+" applies the requested 180-degree turn only to the podium")
		var source: StandardMaterial3D = polished.car.paint_materials.body
		check(is_equal_approx(source.roughness,old.car.paint_materials.body.roughness) and source.specular_mode == old.car.paint_materials.body.specular_mode,id+" studio does not mutate source paint/cache roles")
		var environment: WorldEnvironment = polished.viewport.find_child("PodiumReflectionEnvironment",true,false)
		check(environment != null and environment.environment.sky != null,id+" owns actual reflection radiance")
		var with_reflection: Image = polished.viewport.get_texture().get_image()
		check(root.get_texture().get_image().save_png(evidence.path_join("pair-"+id+".png")) == OK,id+" native before/after capture saved")
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		polished._refresh()
		await draw()
		var without_reflection: Image = polished.viewport.get_texture().get_image()
		var opaque: int = 0
		var changed: int = 0
		var energy: float = 0.0
		for y: int in range(with_reflection.get_height()):
			for x: int in range(with_reflection.get_width()):
				var a: Color = with_reflection.get_pixel(x,y)
				var b: Color = without_reflection.get_pixel(x,y)
				if a.a < 0.99 or b.a < 0.99: continue
				opaque += 1
				var difference: float = (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))*255.0
				energy += difference
				if difference > 3.0: changed += 1
		check(changed > 20 and energy/maxi(1,opaque) > 0.2,id+" opaque paint/glazing pixels contain real environment reflections")
		metrics[id] = {"opaque_pixels":opaque,"reflection_pixels":changed,"mean_rgb_delta":energy/maxi(1,opaque),"raw_clear":with_reflection.get_pixel(0,0).to_html()}
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		polished._refresh()
		await draw()
		check(polished.viewport.render_target_update_mode <= SubViewport.UPDATE_ONCE,id+" polished reflection view settles after bounded draws")
		if id == "compact": await alpha_edges(polished)
		old.free()
		polished.free()
		await process_frame
	await garage_comparison()
	await display_density()
	var closed: Control = make_preview(appearance(0),true,Vector2.ZERO)
	closed.free()
	await draw()
	check(true,"closing a view during radiance preparation has no stale callback")
	var report := FileAccess.open(evidence.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"\t",true)+"\n")
	print("PODIUM_QUALITY_METRICS: ",JSON.stringify(metrics))
	print("PODIUM_QUALITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func make_preview(value: Dictionary, polished: bool, location: Vector2) -> Control:
	var preview: Control = Preview.new()
	preview.vehicle_id = value.vehicle_id
	preview.simple_model = true
	preview.podium_presentation = polished
	preview.livery = value.livery.duplicate(true)
	preview.customisation = value.customisation.duplicate(true)
	preview.position = location
	preview.size = Vector2(560,300)
	root.add_child(preview)
	return preview

func draw() -> void:
	for _frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw

func garage_comparison() -> void:
	var value: Dictionary = appearance(0)
	value.livery.colors.body = "b77b65"
	value.livery.colors.accent = "e0d5b5"
	value.livery.colors.detail = "e0d5b5"
	value.livery.pattern = "apex_twin"
	for panel: String in VehicleLivery.SURFACES: value.livery.stickers[panel].id = "none"
	value.customisation = VehicleCustomisation.defaults()
	value.customisation.aero = "wing"
	value.customisation.rims = "five"
	var podium: Control = make_preview(value,true,Vector2(660,155))
	var garage := CarShowroom.new()
	garage.garage_mode = true
	garage.livery = value.livery.duplicate(true)
	garage.customisation = value.customisation.duplicate(true)
	garage.position = Vector2(30,155)
	garage.size = Vector2(560,300)
	root.add_child(garage)
	var camera: Camera3D = podium.viewport.find_children("*","Camera3D",true,false)[0]
	garage.turntable.rotation.y = PI
	garage.camera.fov = camera.fov
	garage.camera.position = camera.position+Vector3.UP*GarageEnvironment.DECK_HEIGHT
	garage.camera.look_at(Vector3(0,0.65+GarageEnvironment.DECK_HEIGHT,0))
	garage.reflections.sync()
	await draw()
	var a: StandardMaterial3D = garage.car.paint_materials.body
	var b: StandardMaterial3D = podium.car.paint_materials.body
	check(a.albedo_color == b.albedo_color and a.roughness == b.roughness and a.metallic == b.metallic and a.metallic_specular == b.metallic_specular and a.clearcoat == b.clearcoat,"Compact podium retains the production Garage paint finish exactly")
	var left: WorldEnvironment = garage.showroom_viewport.find_child("GarageEnvironment",true,false)
	var right: WorldEnvironment = podium.viewport.find_child("PodiumReflectionEnvironment",true,false)
	check(left.environment.sky == right.environment.sky and left.environment.ambient_light_color == right.environment.ambient_light_color and left.environment.ambient_light_energy == right.environment.ambient_light_energy,"podium shares the exact Garage radiance and ambient lighting")
	for name: String in ["GarageKey","GarageFill","GarageRim"]:
		var old: Light3D = garage.showroom_viewport.find_child(name,true,false)
		var current: Light3D = podium.viewport.find_child(name,true,false)
		check(old.light_color == current.light_color and old.light_energy == current.light_energy and old.transform == current.transform and old.shadow_enabled == current.shadow_enabled,name+" uses the exact production Garage light")
	check(podium.viewport.msaa_3d == garage.showroom_viewport.msaa_3d,"podium retains Garage four-sample edge antialiasing")
	check(root.get_texture().get_image().save_png(evidence.path_join("garage-versus-podium.png")) == OK,"actual Garage and podium captured with the same finish and matched camera pose")
	garage.free()
	podium.free()
	await process_frame

func display_density() -> void:
	var scaled := Control.new()
	scaled.scale = Vector2.ONE*2.5
	root.add_child(scaled)
	var preview: Control = Preview.new()
	preview.simple_model = true
	preview.podium_presentation = true
	preview.size = Vector2(120,64)
	scaled.add_child(preview)
	await draw()
	check(preview.viewport.size.x >= 600 and preview.viewport.size.y >= 320,"podium accounts for display/canvas magnification instead of enlarging a low-resolution car")
	check(preview.viewport.size.x <= 1536 and preview.viewport.size.y <= 768,"scaled podium preserves bounded render-target dimensions")
	metrics.display_density = {"logical_size":[preview.size.x,preview.size.y],"scale":2.5,"target":[preview.viewport.size.x,preview.viewport.size.y]}
	scaled.free()
	await process_frame

func alpha_edges(preview: Control) -> void:
	preview.car.hide()
	var world: Node3D = preview.car.get_parent()
	for shadow: Node in world.get_children():
		if shadow is MeshInstance3D: shadow.hide()
	var ball := MeshInstance3D.new()
	var geometry := SphereMesh.new()
	geometry.radius = 0.65
	geometry.height = 1.3
	geometry.radial_segments = 64
	geometry.rings = 32
	ball.mesh = geometry
	ball.position.y = 0.8
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color("149938")
	ball.material_override = green
	world.add_child(ball)
	preview._refresh()
	await draw()
	var source: Image = preview.viewport.get_texture().get_image()
	var centre: Color = source.get_pixel(source.get_width()/2,source.get_height()/2)
	var composite: Image = root.get_texture().get_image().get_region(Rect2i(preview.get_global_rect()))
	var background: Color = composite.get_pixel(0,0)
	check(background.r < 0.15 and background.g < 0.2 and background.b < 0.25,"zero-alpha white renderer matte does not appear as a white box")
	var edge_pixels: int = 0
	var halo_pixels: int = 0
	for y: int in range(composite.get_height()):
		for x: int in range(composite.get_width()):
			var pixel: Color = composite.get_pixel(x,y)
			if pixel.g <= background.g+0.03 or pixel.g >= centre.g-0.03: continue
			edge_pixels += 1
			if pixel.r > maxf(centre.r,background.r)+0.035 or pixel.g > maxf(centre.g,background.g)+0.035 or pixel.b > maxf(centre.b,background.b)+0.035: halo_pixels += 1
	check(edge_pixels > 10 and halo_pixels == 0,"filtered silhouette contains coverage colours without a pale fringe")
	metrics.alpha = {"edge_pixels":edge_pixels,"halo_pixels":halo_pixels,"clear_rgb":source.get_pixel(0,0).to_html(),"composite_background":background.to_html()}
	check(composite.save_png(evidence.path_join("alpha-edge-fixture.png")) == OK,"native transparent-edge fixture captured")
	preview.hide()
	await process_frame
	check(preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden podium disables its reflection view")
