extends SceneTree
## Use the actual showroom's lights, reflections and car-specific shadow policy.
const OUT = "res://../docs/evidence/car-model-review-2026-11-12"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1000,760)
	preload("res://ui/garage_car_cache.gd").enabled = false
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.livery = VehicleLivery.defaults(id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(1000,760)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		for shot: Array in [["front",-0.70,atan(0.32)],["rear",2.45,atan(0.32)],["side",-PI/2,0.15]]:
			view.yaw = shot[1]
			view.elevation = shot[2]
			view.zoom = 0.80
			view._orbit()
			view.invalidate_render()
			for frame: int in range(15):
				await process_frame
				await RenderingServer.frame_post_draw
			var path: String = OUT.path_join(id+"-showroom-"+RenderingServer.get_current_rendering_method()+"-"+shot[0]+".png")
			assert(view.showroom_viewport.get_texture().get_image().save_png(path)==OK)
		view.free()
		await process_frame
		print("CMR_SHOWROOM ",id)
	print("CMR_SHOWROOM_RESULT 18 captures")
	quit()
