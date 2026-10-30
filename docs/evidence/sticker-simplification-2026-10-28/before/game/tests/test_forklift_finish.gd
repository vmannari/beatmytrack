extends SceneTree
## Closed body shells and an actually visible single rear sticker, including Garage.
var checks: int = 0
var failures: int = 0
var graphical: bool = false
var output: String
var metrics: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	for tick: int in range(10): await process_frame
	if graphical: await RenderingServer.frame_post_draw

func capture(label: String) -> Image:
	await settle()
	if not graphical: return null
	var pixels: Image = root.get_texture().get_image()
	check(pixels.save_png(output.path_join(label+".png")) == OK,"native capture "+label)
	return pixels

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	graphical = DisplayServer.get_name() != "headless"
	output = ProjectSettings.globalize_path("res://../docs/evidence/forklift-body-sticker-2026-10-25").path_join(RenderingServer.get_current_rendering_method() if graphical else "headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,720)
	var config: Dictionary = VehicleCatalog.config("forklift").snapshot()
	for simple: bool in [false,true]: await _geometry(simple)
	await _baseline()
	check(not LiveryCatalog.has_roof("forklift") and LiveryCatalog.sticker_label("forklift","hood") == "Rear","Forklift has one named rear location")
	check(LiveryCatalog.sticker_label("compact","hood") == "Hood" and LiveryCatalog.sticker_label("compact","roof") == "Roof","existing panel labels remain intact")
	var value: Dictionary = VehicleLivery.defaults("forklift")
	value.stickers.hood.id = "crest"
	check(VehicleLivery.valid(value) and VehicleLivery.normalize(value,"forklift") == value,"existing saved primary sticker maps to rear without data loss")
	var finish := ShaderMaterial.new()
	finish.shader = LiveryGraphics.FINISH
	LiveryGraphics.uniforms(finish,value,"forklift")
	check(finish.get_shader_parameter("rear_sticker") == true and finish.get_shader_parameter("roof_emblem") == -1,"rear projection is enabled and the unused roof slot is suppressed")
	LiveryGraphics.uniforms(finish,value,"compact")
	check(finish.get_shader_parameter("rear_sticker") == false,"other cars retain the original projection")
	await _other_cars()
	var previews_valid: bool = true
	var names: Array[String] = ["midnight"]
	for pattern: Dictionary in LiveryCatalog.patterns: names.append(pattern.id)
	for label: String in names:
		var photo: Texture2D = load("res://assets/liveries/previews_v2/forklift/"+label+".png")
		previews_valid = previews_valid and photo != null and photo.get_size() == Vector2(320,200) and photo.get_image().has_mipmaps()
	check(previews_valid,"all refreshed Forklift appearance photos are native, bounded and filtered")
	metrics.native_previews = names.size()
	if graphical: await _render()
	await _garage()
	check(config == VehicleCatalog.config("forklift").snapshot(),"finish correction cannot change Forklift handling")
	var report := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("FORKLIFT_FINISH_METRICS ",JSON.stringify(metrics))
	print("FORKLIFT_FINISH_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _topology(part: MeshInstance3D) -> Dictionary:
	var edges: Dictionary = {}
	var direction: Dictionary = {}
	var faces: PackedVector3Array = part.mesh.get_faces()
	var volume: float = 0.0
	for index: int in range(0,faces.size(),3):
		volume += faces[index].dot(faces[index+1].cross(faces[index+2]))/6.0
		for edge: int in range(3):
			var a: String = str(faces[index+edge].snapped(Vector3.ONE*0.000001))
			var b: String = str(faces[index+(edge+1)%3].snapped(Vector3.ONE*0.000001))
			var key: String = a+"/"+b if a<b else b+"/"+a
			edges[key] = int(edges.get(key,0))+1
			direction[key] = int(direction.get(key,0))+(1 if a<b else -1)
	var boundary: int = 0
	var inconsistent: int = 0
	for key: String in edges:
		if edges[key] != 2: boundary += 1
		if direction[key] != 0: inconsistent += 1
	return {"boundary_edges":boundary,"inconsistent_edges":inconsistent,"volume":absf(volume),"triangles":faces.size()/3}

func _geometry(simple: bool) -> void:
	var car := CarVisual.new()
	car.vehicle_id = "forklift"; car.batch_parts = false; car.simple_model = simple
	root.add_child(car)
	var shells: Array[Node] = car.find_children("FormedSideSkin*","MeshInstance3D",true,false)+car.find_children("RolledWheelArch*","MeshInstance3D",true,false)
	check(shells.size() == 6,"both sides and all four arches have independent solid shells")
	var data: Dictionary = {}
	for part: MeshInstance3D in shells:
		var topology: Dictionary = _topology(part)
		data[part.name] = topology
		check(topology.boundary_edges == 0 and topology.volume > 0.00001,"closed solid "+part.name)
		check(topology.inconsistent_edges == 0,"consistent outward winding "+part.name)
	metrics["racing_shells" if simple else "detailed_shells"] = data
	car.queue_free()
	await process_frame

func _baseline() -> void:
	# Rebuild the exact saved body in this isolated process, retaining the same wheels.
	var old_model: Variant = load("res://../docs/evidence/forklift-body-sticker-2026-10-25/before/game__vehicle__forklift_model.gd")
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "forklift"; car.batch_parts = false
	world.add_child(car)
	car.graphics.restore_originals()
	for child: Node in car.body.get_children(): child.free()
	old_model.build(car)
	car.graphics = LiveryGraphics.new()
	car.graphics.configure(car)
	var side: MeshInstance3D = car.find_child("FormedSideSkin",true,false)
	var topology: Dictionary = _topology(side)
	metrics.original_side = topology
	check(topology.boundary_edges>0,"actual task-start side reproduces the open sheet")
	if graphical:
		ShowroomStudio.build(world,car)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 32
		camera.look_at_from_position(Vector3(-4,2.2,4),Vector3(0,1.0,0))
		var value: Dictionary = VehicleLivery.defaults("forklift")
		value.stickers.hood.id = "crest"; value.stickers.hood.size = 0.95
		car.apply_livery(value)
		for binding: Dictionary in car.graphics.bindings:
			binding.finish.set_shader_parameter("rear_sticker",false)
			binding.finish.set_shader_parameter("hood_panel",Vector4(-0.63,0.64,1.26,0.79))
			binding.finish.set_shader_parameter("panel_levels",Vector2(1.49,10))
			binding.finish.set_shader_parameter("hood_sticker",Vector4(0.5,0.5,0.79*0.95,0))
		await capture("before-sides-sticker")
	world.queue_free()
	await process_frame

func _emblem(car: CarVisual, enabled: bool, wear: VehicleWeathering = null) -> void:
	if wear != null:
		for binding: Dictionary in wear.bindings:
			if binding.graphics: binding.finish.set_shader_parameter("hood_emblem",0 if enabled else -1)
	else:
		for binding: Dictionary in car.graphics.bindings: binding.finish.set_shader_parameter("hood_emblem",0 if enabled else -1)

func _other_cars() -> void:
	for id: String in VehicleCatalog.IDS:
		if id == "forklift": continue
		var car := CarVisual.new()
		car.vehicle_id = id; car.simple_model = true
		root.add_child(car)
		var meshes: int = car.find_children("*","MeshInstance3D",true,false).size()
		var projections_retained: bool = true
		for pattern: Dictionary in LiveryCatalog.patterns:
			var value: Dictionary = VehicleLivery.defaults(id)
			value.pattern = pattern.id
			value.stickers.hood.id = "crest"; value.stickers.roof.id = "compass"
			car.apply_livery(value)
			for binding: Dictionary in car.graphics.bindings:
				projections_retained = projections_retained and binding.finish.get_shader_parameter("rear_sticker") == false and binding.finish.get_shader_parameter("hood_emblem") == 0
				projections_retained = projections_retained and binding.finish.get_shader_parameter("roof_emblem") == (2 if LiveryCatalog.has_roof(id) else -1)
		check(projections_retained,id+" retains original panel mapping through every pattern")
		var wear := VehicleWeathering.new()
		wear.configure(car,"pine",VehicleCatalog.config(id))
		wear.dirt_amount = 0.2; wear._update_finish()
		var weathering_retained: bool = true
		for binding: Dictionary in wear.bindings:
			if binding.graphics: weathering_retained = weathering_retained and binding.finish.get_shader_parameter("rear_sticker") == false
		check(weathering_retained,id+" weathered paint retains its projection")
		check(car.find_children("*","MeshInstance3D",true,false).size() == meshes,id+" projection adds no geometry")
		car.queue_free()
		await process_frame

func _difference(a: Image, b: Image) -> int:
	var changed: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var p: Color = a.get_pixel(x,y)
			var q: Color = b.get_pixel(x,y)
			if maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))>0.04: changed += 1
	return changed

func _render() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	world.add_child(car)
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 32
	var value: Dictionary = VehicleLivery.defaults("forklift")
	value.stickers.hood.id = "crest"; value.stickers.hood.size = 0.95
	car.apply_livery(value)
	for pose: String in ["rear","front","side","top"]:
		var target := Vector3(0,1.02,0)*HandlingConfig.BODY_SCALE
		var offset: Vector3 = {"rear":Vector3(0,0.15,4),"front":Vector3(0,0.15,-5),"side":Vector3(5,0.15,0),"top":Vector3(0,6,0.01)}[pose]
		camera.look_at_from_position(target+offset,target)
		_emblem(car,false)
		var plain: Image = await capture(pose+"-without-sticker")
		_emblem(car,true)
		var sticker: Image = await capture(pose+"-sticker")
		var difference: int = _difference(plain,sticker)
		metrics[pose+"_sticker_pixels"] = difference
		check(difference>600 if pose=="rear" else difference<8,"sticker visible only on clear rear face: "+pose)
	camera.look_at_from_position(Vector3(-4,2.2,4),Vector3(0,1.0,0))
	await capture("solid-sides-rear")
	var wear := VehicleWeathering.new()
	wear.configure(car,"pine",VehicleCatalog.config("forklift"))
	wear.dirt_amount = 0.22
	wear._update_finish()
	camera.look_at_from_position(Vector3(0,1.05,4),Vector3(0,1.0,0))
	_emblem(car,false,wear)
	var dirty_plain: Image = await capture("weathered-without-sticker")
	_emblem(car,true,wear)
	var dirty_sticker: Image = await capture("weathered-sticker")
	metrics.weathered_sticker_pixels = _difference(dirty_plain,dirty_sticker)
	check(int(metrics.weathered_sticker_pixels)>300,"rear sticker survives normal weathering")
	world.queue_free()
	await process_frame

func _garage() -> void:
	root.size = Vector2i(1280,720)
	var directory: String = ProjectSettings.globalize_path("res://../build/forklift-finish/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page.preview_car(VehicleCatalog.IDS.find("forklift"))
	page._confirm_car()
	await create_timer(0.8).timeout
	page._set_customise_tab("stickers")
	await settle()
	var button: Button = page.livery_menu.active_control("StickerHood")
	check(button != null and button.text == "Rear" and page.livery_menu.active_control("StickerRoof") == null,"actual Garage offers only Rear")
	page._choose_sticker_surface("hood")
	page._choose_sticker(LiveryCatalog.sticker_index("zelvora")+1)
	await create_timer(0.6).timeout
	await settle()
	check(page.draft.stickers.hood.id == "zelvora" and page.draft.stickers.hood.rotation == 0.0,"new rear wordmark starts upright")
	var focused: Vector3 = page.showroom.car.to_local(page._customisation_camera.target)
	check(focused.z>1.2*HandlingConfig.BODY_SCALE,"actual Garage focuses the rear panel")
	await capture("garage-rear-sticker-1280")
	page._edit_sticker_position(true)
	await create_timer(0.5).timeout
	page._move_sticker(Vector2(0.47,0.51))
	page._sticker_property(0.91,"size")
	page._sticker_property(-8.0,"rotation")
	page._save()
	await settle()
	check(page._sticker_board.vehicle_id == "forklift" and page._sticker_board.surface == "hood","rear placement uses the compatible saved slot")
	check(page._customisation_camera.focused_category == "hood" and page.showroom.car.to_local(page._customisation_camera.target).z>1.2*HandlingConfig.BODY_SCALE,"placement retains a view of the actual rear sticker")
	var reopened := LocalRecords.new(app.records.path)
	reopened.load_records()
	var saved: Dictionary = VehicleLivery.for_car(reopened.settings,"forklift").stickers.hood
	var retained: bool = saved.id == page.draft.stickers.hood.id
	for property: String in ["x","y","size","rotation"]: retained = retained and is_equal_approx(float(saved[property]),float(page.draft.stickers.hood[property]))
	check(retained,"rear placement/size/rotation survive reload")
	root.size = Vector2i(960,540)
	await capture("garage-rear-placement-960")
	page._edit_sticker_position(false)
	page._choose_sticker(0)
	check(page.draft.stickers.hood.id == "none","rear sticker can be removed normally")
	app.queue_free()
	await process_frame
