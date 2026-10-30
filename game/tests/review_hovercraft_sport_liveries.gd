extends SceneTree
## Native pixel comparisons of the actual model and the existing paint/sticker path.
## Each comparison uses the same livery shader with only the tested graphic disabled
## in the control, so changing from StandardMaterial to ShaderMaterial cannot
## produce a false positive. No player data or network is used.
const BASE_OUTPUT: String = "res://../docs/evidence/hovercraft-sport-redesign-2026-10-29"
const IMAGE_SIZE: Vector2i = Vector2i(1280,720)
const PIXEL_THRESHOLD: float = 0.035
var checks: int = 0
var failures: int = 0
var output: String
var viewport: SubViewport
var camera: Camera3D
var car: CarVisual

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for tick: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func picture(label: String) -> Image:
	await settle()
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	check(image.save_png(output.path_join(label+".png")) == OK,"saved "+label)
	return image

func panel_region(panel: Vector4, level: float) -> Rect2i:
	# Include a small range of possible panel heights so a sloped physical surface
	# projects into the same region; never infer success from the whole car.
	var rectangle := Rect2()
	var initialized: bool = false
	for x: float in [panel.x,panel.x+panel.z]:
		for z: float in [panel.y,panel.y+panel.w]:
			for y: float in [level,level+0.30]:
				var p: Vector2 = camera.unproject_position(car.body.to_global(Vector3(x,y,z)))
				if not initialized:
					rectangle = Rect2(p,Vector2.ZERO)
					initialized = true
				else:
					rectangle = rectangle.expand(p)
	rectangle = rectangle.grow(16.0).intersection(Rect2(Vector2.ZERO,Vector2(IMAGE_SIZE)))
	return Rect2i(floori(rectangle.position.x),floori(rectangle.position.y),ceili(rectangle.size.x),ceili(rectangle.size.y)).intersection(Rect2i(Vector2i.ZERO,IMAGE_SIZE))

func difference(a: Image, b: Image, area: Rect2i) -> Dictionary:
	var changed: int = 0
	var max_delta: float = 0.0
	var energy: float = 0.0
	var changed_bounds := Rect2i()
	var has_bounds: bool = false
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			var p: Color = a.get_pixel(x,y)
			var q: Color = b.get_pixel(x,y)
			var delta: float = maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
			if delta > PIXEL_THRESHOLD:
				changed += 1
				energy += delta
				max_delta = maxf(max_delta,delta)
				if not has_bounds:
					changed_bounds = Rect2i(x,y,1,1)
					has_bounds = true
				else: changed_bounds = changed_bounds.expand(Vector2i(x,y))
	return {"changed_pixels":changed,"max_channel_delta":max_delta,"total_delta":energy,
		"region":[area.position.x,area.position.y,area.size.x,area.size.y],
		"changed_bounds":[changed_bounds.position.x,changed_bounds.position.y,changed_bounds.size.x,changed_bounds.size.y]}

func disable_tested_graphic(kind: String) -> void:
	# The decorated material stays bound and every other uniform remains identical.
	for binding: Dictionary in car.graphics.bindings:
		var finish: ShaderMaterial = binding.finish
		if kind == "pattern": finish.set_shader_parameter("pattern_enabled",false)
		else: finish.set_shader_parameter(kind+"_emblem",-1)

func evaluate(kind: String, value: Dictionary, area: Rect2i, minimum: int) -> Dictionary:
	car.apply_livery(value)
	disable_tested_graphic(kind)
	var control: Image = await picture(kind+"-control")
	var repeat: Image = await picture(kind+"-control-repeat")
	car.apply_livery(value)
	var rendered: Image = await picture(kind)
	var noise: Dictionary = difference(control,repeat,area)
	var change: Dictionary = difference(control,rendered,area)
	check(area.size.x > 0 and area.size.y > 0,kind+" has a visible projection region")
	check(change.changed_pixels >= minimum and change.changed_pixels > noise.changed_pixels*3+20,
		kind+" visibly changes its intended physical region beyond render noise")
	return {"noise":noise,"change":change,"minimum_pixels":minimum}

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native rendering is required for the pixel review.")
		quit(2)
		return
	OS.set_environment("BMT_API_URL","")
	output = BASE_OUTPUT.path_join("liveries-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://ui/garage_car_cache.gd").enabled = false
	root.size = IMAGE_SIZE
	viewport = SubViewport.new()
	viewport.name = "LiveryReviewViewport"
	viewport.size = IMAGE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	car = CarVisual.new()
	car.vehicle_id = "hovercraft"
	car.cache_rest_pose = false
	car.livery = VehicleLivery.defaults("hovercraft")
	world.add_child(car)
	while not car.model_ready: await process_frame
	check(not car.graphics.bindings.is_empty(),"actual hovercraft paint is bound to livery graphics")
	check(LiveryCatalog.has_roof("hovercraft"),"hovercraft retains a roof sticker panel")
	var other := CarVisual.new()
	other.vehicle_id = "hovercraft"
	other.livery = VehicleLivery.defaults("hovercraft")
	other.visible = false
	other.cache_rest_pose = false
	world.add_child(other)
	while not other.model_ready: await process_frame
	var original_other: Color = other.paint_materials.body.albedo_color
	var temporary: Dictionary = VehicleLivery.defaults("hovercraft")
	temporary.colors.body = "245b8a"
	car.apply_livery(temporary)
	check(other.paint_materials.body.albedo_color == original_other,"livery paint remains independent between instances")
	other.free()
	car.apply_livery(VehicleLivery.defaults("hovercraft"))
	ShowroomStudio.build(world,car)
	camera = Camera3D.new()
	camera.name = "LiveryReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0*HandlingConfig.BODY_SCALE
	world.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(0,7.0,-2.4)*HandlingConfig.BODY_SCALE,Vector3(0,0.65,0)*HandlingConfig.BODY_SCALE)
	await picture("plain")
	var projection: Dictionary = LiveryCatalog.projection("hovercraft")
	var hood: Rect2i = panel_region(projection.hood,projection.levels.x)
	var roof: Rect2i = panel_region(projection.roof,projection.levels.y)
	var pattern: Dictionary = VehicleLivery.defaults("hovercraft")
	pattern.pattern = str(LiveryCatalog.patterns[0].id)
	var hood_sticker: Dictionary = VehicleLivery.defaults("hovercraft")
	hood_sticker.stickers.hood.id = str(LiveryCatalog.stickers[0].id)
	hood_sticker.stickers.hood.size = 0.95
	var roof_sticker: Dictionary = VehicleLivery.defaults("hovercraft")
	roof_sticker.stickers.roof.id = str(LiveryCatalog.stickers[0].id)
	roof_sticker.stickers.roof.size = 0.95
	var results: Dictionary = {}
	results.pattern = await evaluate("pattern",pattern,Rect2i(Vector2i.ZERO,IMAGE_SIZE),100)
	results.hood = await evaluate("hood",hood_sticker,hood,25)
	results.roof = await evaluate("roof",roof_sticker,roof,25)
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),
		"pattern_id":pattern.pattern,"sticker_id":hood_sticker.stickers.hood.id,"results":results},"\t"))
	file.close()
	world.free()
	viewport.free()
	await process_frame
	print("HOVERCRAFT_SPORT_LIVERIES: %d checks, %d failures; changed pixels pattern=%d hood=%d roof=%d" %
		[checks,failures,results.pattern.change.changed_pixels,results.hood.change.changed_pixels,results.roof.change.changed_pixels])
	quit(1 if failures else 0)
