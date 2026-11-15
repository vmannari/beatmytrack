extends SceneTree
## Refresh only electric pictures using the established native studio/camera recipes.
const Profile = preload("res://ui/profile_car.gd")
const SIZE := Vector2i(176,112)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var view: Control = Profile.make_preview("electric",VehicleLivery.defaults("electric"),VehicleCustomisation.defaults())
	view.size = Vector2(SIZE)
	canvas.add_child(view)
	Profile.apply_presentation(view)
	while view.get("car")==null or not view.get("car").model_ready: await process_frame
	for frame: int in range(7):
		await process_frame
		await RenderingServer.frame_post_draw
	var pixels: Image = canvas.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			var color: Color = pixels.get_pixel(x,y)
			if color.a > 0 and color.a < 1:
				pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
	assert(pixels.save_png("res://assets/menu/header_cars_v1/electric.png") == OK)
	canvas.queue_free()
	await process_frame
	var showroom := CarShowroom.new()
	showroom.vehicle_id = "electric"
	showroom.read_only = true
	showroom.garage_mode = true
	showroom.framing_scale = 0.84
	showroom.livery = VehicleLivery.for_car({},"electric")
	showroom.customisation = VehicleCustomisation.defaults()
	showroom.size = Vector2(2048,512)
	root.add_child(showroom)
	while not showroom.showroom_ready: await process_frame
	for frame: int in range(5):
		showroom.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		showroom.reflections.request_draw()
		await process_frame
		await RenderingServer.frame_post_draw
	assert(showroom.showroom_viewport.get_texture().get_image().save_png("res://assets/garage/previews_v1/electric.png") == OK)
	var path: String = "res://assets/garage/previews_v1/provenance.json"
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	provenance.hashes.electric = FileAccess.get_sha256("res://assets/garage/previews_v1/electric.png")
	for file: String in ["electric_car_model.gd","electric_reference_mesh.gd","electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_details.gd","electric_glass.gdshader"]:
		provenance.sources["game/vehicle/"+file] = FileAccess.get_sha256("res://vehicle/"+file)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(provenance,"\t")+"\n")
	showroom.queue_free()
	await process_frame
	print("ELECTRIC_DESIGN_ART: refreshed header and Garage electric pictures")
	quit()
