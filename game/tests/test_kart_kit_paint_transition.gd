extends SceneTree
## KPT01-KPT03: kit sweeps retain paint, projection, stickers and wash uniforms.
var checks: int = 0
var failures: int = 0
var showroom: CarShowroom
var output: String = "res://../docs/evidence/kart-kit-paint-2026-11-17"
var metrics: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("KART_KIT_PAINT_FAIL: ",label)

func draw() -> void:
	showroom.invalidate_render()
	for tick: int in range(10): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func picture(label: String) -> Image:
	await draw()
	if DisplayServer.get_name() == "headless": return null
	var result: Image = showroom.showroom_viewport.get_texture().get_image()
	check(result.save_png(output.path_join(label+".png")) == OK,"capture "+label)
	return result

func differences(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in range(0,a.get_height(),2):
		for x: int in range(0,a.get_width(),2):
			var delta: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
			if Vector3(delta.r,delta.g,delta.b).length() > 0.04: count += 1
	return count

func uniforms(sweep: RefCounted, label: String) -> void:
	var compared: int = 0
	var mismatches: Array[String] = []
	for binding: Dictionary in sweep.bindings:
		var source: Material = binding.override
		if source == null: source = binding.surface
		if source == null: source = binding.node.mesh.surface_get_material(binding.index)
		if not source is ShaderMaterial: continue
		var active: ShaderMaterial = binding.node.get_active_material(binding.index) as ShaderMaterial
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			compared += 1
			if source.get_shader_parameter(uniform.name) != active.get_shader_parameter(uniform.name):
				if uniform.name not in mismatches: mismatches.append(uniform.name)
	if not label.begins_with("plain") and ("-hood" in label or "-body" in label):
		check(compared > 0,"paint shader bindings exercised: "+label)
	check(mismatches.is_empty(),"all original shader uniforms retained: "+label+" "+str(mismatches))

func matrix_copy() -> void:
	var source := ShaderMaterial.new()
	source.shader = preload("res://vehicle/livery_finish.gdshader")
	var frame := Transform3D(Basis(Vector3.UP,0.25),Vector3(0.535,0.02,-0.1))
	source.set_shader_parameter("mesh_to_body",frame)
	source.set_shader_parameter("paint_color",Color("247bc1"))
	var sweep = preload("res://ui/garage_kit_transition.gd").new()
	var copy: ShaderMaterial = sweep._copy(source,false)
	check(copy.get_shader_parameter("mesh_to_body") == frame,"transition retains a translated/rotated paint frame")
	check(source.get_shader_parameter("mesh_to_body") == frame,"copy leaves original paint frame unchanged")
	check(copy.get_shader_parameter("paint_color") == source.get_shader_parameter("paint_color"),"copy retains paint colour")
	copy.set_shader_parameter("paint_color",Color.RED)
	check(source.get_shader_parameter("paint_color") == Color("247bc1"),"transition uniform storage is independent")

func change(category: String, option: String, label: String, capture: bool) -> void:
	var before: Image
	if capture: before = await picture(label+"-before")
	var livery: Dictionary = showroom.car.livery.duplicate(true)
	var condition: Dictionary = showroom.weathering.snapshot()
	var value: Dictionary = showroom.customisation.duplicate(true)
	value[category] = option
	showroom.apply_customisation(value,true)
	check(showroom.kit_transition != null,"sweep active: "+label)
	if showroom.kit_transition == null: return
	showroom.kit_motion.pause()
	uniforms(showroom.kit_transition,label)
	if capture:
		showroom.kit_transition.set_progress(0.0)
		var start: Image = await picture(label+"-start")
		showroom.kit_transition.set_progress(0.5)
		await picture(label+"-middle")
		showroom.kit_transition.set_progress(1.0)
		var end: Image = await picture(label+"-end")
		showroom.finish_kit_transition()
		var exact: Image = await picture(label+"-finished")
		if before != null:
			var start_delta: int = differences(before,start)
			var end_delta: int = differences(end,exact)
			metrics.append({"label":label,"start_difference":start_delta,"end_difference":end_delta})
			check(start_delta <= 12,"initial sweep matches existing paint: "+label+" pixels="+str(start_delta))
			check(end_delta <= 12,"completed sweep matches finished paint: "+label+" pixels="+str(end_delta))
	else: showroom.finish_kit_transition()
	check(showroom.car.livery == livery,"livery unchanged: "+label)
	check(showroom.weathering.snapshot() == condition,"wash state unchanged: "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	matrix_copy()
	showroom = CarShowroom.new()
	showroom.vehicle_id = "kart"
	showroom.garage_mode = true
	showroom.customisation = VehicleCustomisation.defaults()
	showroom.livery = VehicleLivery.defaults("kart")
	root.add_child(showroom)
	MenuStyle.fill(showroom)
	while not showroom.showroom_ready: await process_frame
	showroom.yaw = -0.65
	showroom.elevation = 0.30
	showroom._orbit()
	for look: String in ["plain","stripes","weathered","premium"]:
		var paint: Dictionary = VehicleLivery.defaults("kart")
		paint.colors.body = "247bc1"
		paint.colors.accent = "e3a12b"
		if look != "plain":
			paint.pattern = "apex_twin"
			paint.stickers.hood.id = "crest"
		if look == "premium": paint.pattern = LiveryCatalog.premium_for("kart")[0].id
		check(VehicleLivery.valid(paint),"valid fixture livery: "+look)
		showroom.apply_livery(paint)
		showroom.finish_paint_transition()
		if look == "weathered":
			var film: Dictionary = showroom.weathering.snapshot()
			film.dirt = 0.12
			film.slow_dirt = 0.05
			film.wetness = 0.20
			showroom.weathering.restore(film)
		for category: String in VehicleCustomisation.CATEGORIES:
			var option: String = VehicleCustomisation.options(category,"kart")[1][0]
			await change(category,option,look+"-"+category,true)
			await change(category,"stock",look+"-"+category+"-stock",false)
			for index: int in range(2,VehicleCustomisation.options(category,"kart").size()):
				var other: String = VehicleCustomisation.options(category,"kart")[index][0]
				await change(category,other,look+"-"+category+"-"+other,false)
			await change(category,"stock",look+"-"+category+"-return",false)
	# Cancellation and natural completion must retain the same live material.
	var target: Dictionary = showroom.customisation.duplicate(true)
	target.hood = VehicleCustomisation.options("hood","kart")[2][0]
	showroom.apply_customisation(target,true)
	showroom.kit_motion.pause()
	showroom.kit_transition.set_progress(0.4)
	target.hood = VehicleCustomisation.options("hood","kart")[3][0]
	showroom.apply_customisation(target,true)
	uniforms(showroom.kit_transition,"weathered-interrupted")
	await create_timer(0.9).timeout
	check(showroom.kit_transition == null and showroom.kit_motion == null,"natural completion after interruption frees sweep")
	showroom.queue_free()
	await process_frame
	await process_frame
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("KART_KIT_PAINT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
