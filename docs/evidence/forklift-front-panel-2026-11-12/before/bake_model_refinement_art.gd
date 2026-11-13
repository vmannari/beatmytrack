extends SceneTree
## Factory profile/header photographs for the five explicitly selected cars.
const Profile = preload("res://ui/profile_car.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640,400)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view: Control = Profile.make_preview(id,VehicleLivery.defaults(id),VehicleCustomisation.defaults())
		view.size = Vector2(640,400)
		viewport.add_child(view)
		Profile.apply_presentation(view)
		while view.get("car")==null or not view.get("car").model_ready: await process_frame
		for frame: int in range(12):
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var color: Color = image.get_pixel(x,y)
				if color.a>0 and color.a<1: image.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
		assert(image.save_png("res://assets/menu/"+id+"_illustration_v1.png")==OK)
		image.resize(176,112,Image.INTERPOLATE_LANCZOS)
		assert(image.save_png("res://assets/menu/header_cars_v1/"+id+".png")==OK)
		viewport.free()
		await process_frame
		print("MODEL_REFINEMENT_ART ",id)
	quit()
