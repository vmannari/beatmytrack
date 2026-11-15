extends SceneTree
## Native photographs of the authored runtime asset, plus its one shadow proxy.
func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var canvas := SubViewport.new()
	canvas.size = Vector2i(640,400)
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var preview: Control = preload("res://ui/profile_car.gd").make_preview("hovercraft",VehicleLivery.defaults("hovercraft"),VehicleCustomisation.defaults())
	preview.size = Vector2(640,400)
	canvas.add_child(preview)
	preload("res://ui/profile_car.gd").apply_presentation(preview)
	await settle()
	var pixels: Image = canvas.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	for y: int in range(pixels.get_height()):
		for x: int in range(pixels.get_width()):
			var color: Color = pixels.get_pixel(x,y)
			if color.a > 0.0 and color.a < 1.0: pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
	assert(pixels.save_png("res://assets/menu/hovercraft_illustration_v1.png") == OK)
	pixels.resize(176,112,Image.INTERPOLATE_LANCZOS)
	assert(pixels.save_png("res://assets/menu/header_cars_v1/hovercraft.png") == OK)
	preview.free()
	canvas.free()
	var view := CarShowroom.new()
	view.vehicle_id = "hovercraft"
	view.read_only = true
	view.size = Vector2(640,400)
	view.livery = VehicleLivery.defaults("hovercraft")
	root.add_child(view)
	await settle()
	view.invalidate_render()
	await settle()
	pixels = view.showroom_viewport.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGB8)
	assert(pixels.save_png("res://assets/garage/previews_v1/hovercraft.png") == OK)
	view.free()
	# The simple body has one moving frame and no wheel frames.
	var car := CarVisual.new()
	car.vehicle_id = "hovercraft"
	car.simple_model = true
	root.add_child(car)
	while not car.model_ready: await process_frame
	var source: ArrayMesh = RacingCarModels.shadow_source(car.body)
	var arrays: Array = source.surface_get_arrays(0)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	importer.generate_lods(60.0,0.0,[])
	var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for lod: int in range(importer.get_surface_lod_count(0)):
		if chosen.size()/3 <= 1200: break
		var candidate: PackedInt32Array = importer.get_surface_lod_indices(0,lod)
		if candidate.size() < chosen.size(): chosen = candidate
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var compact := PackedVector3Array()
	var mapped := PackedInt32Array()
	var remap: Dictionary = {}
	for vertex: int in chosen:
		if not remap.has(vertex):
			remap[vertex] = compact.size()
			compact.append(vertices[vertex])
		mapped.append(remap[vertex])
	arrays[Mesh.ARRAY_VERTEX] = compact
	arrays[Mesh.ARRAY_INDEX] = mapped
	var shadow := ArrayMesh.new()
	shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	shadow.custom_aabb = source.get_aabb()
	assert(ResourceSaver.save(shadow,RacingCarModels.ASSET_ROOT.path_join("hovercraft_shadow_0.res"),ResourceSaver.FLAG_COMPRESS) == OK)
	print("HOVERCRAFT_ART: illustration, header, Garage; shadow triangles=",chosen.size()/3)
	car.free()
	await process_frame
	quit()
