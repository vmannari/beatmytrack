extends SceneTree
## Original native photographs of the shipped chassis and its variant factory paint.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var canvas := SubViewport.new()
	canvas.size = Vector2i(640,400)
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var profile = preload("res://ui/profile_car.gd")
	var preview: Control = profile.make_preview("super_rally",VehicleLivery.defaults("super_rally"),VehicleCustomisation.defaults())
	preview.size = Vector2(canvas.size)
	canvas.add_child(preview)
	profile.apply_presentation(preview)
	for frame: int in range(12):
		await process_frame
		await RenderingServer.frame_post_draw
	var pixels: Image = canvas.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	for y: int in range(pixels.get_height()):
		for x: int in range(pixels.get_width()):
			var color: Color = pixels.get_pixel(x,y)
			if color.a > 0.0 and color.a < 1.0:
				pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
	assert(pixels.save_png("res://assets/menu/super_rally_illustration_v1.png") == OK)
	assert(pixels.save_png("res://assets/news/vehicles/super_rally.png") == OK)
	pixels.resize(176,112,Image.INTERPOLATE_LANCZOS)
	assert(pixels.save_png("res://assets/menu/header_cars_v1/super_rally.png") == OK)
	preview.free()
	canvas.free()
	print("SUPER_RALLY_ART: three native pictures saved")
	quit()
