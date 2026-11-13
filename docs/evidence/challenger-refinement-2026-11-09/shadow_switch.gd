extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	root.size = Vector2i(1280,720)
	for initial: String in ["super_rally","compact"]:
		var view := CarShowroom.new(); view.vehicle_id = initial; view.garage_mode = true
		view.read_only = true; view.preview_live_lighting = true; view.size = Vector2(1280,720); view.livery = VehicleLivery.defaults(initial)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		var key: DirectionalLight3D = view.showroom_viewport.find_child("GarageKey",true,false)
		check(key != null and key.shadow_enabled,"real Garage shadows remain enabled from initial "+initial)
		check(is_equal_approx(key.shadow_normal_bias,8.0 if initial == "super_rally" else 2.0),"initial car selects its shadow profile "+initial)
		for id: String in ["super_rally","compact","super_rally","compact"]:
			view.replace_car(id,VehicleLivery.defaults(id),{},VehicleCustomisation.defaults())
			while not view.car.model_ready: await process_frame
			view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
			check(is_equal_approx(key.shadow_normal_bias,8.0 if id == "super_rally" else 2.0),"switch restores the correct profile "+initial+"/"+id)
			var casters: int = 0
			for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
				if part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: casters += 1
			check(casters > 0 and key.shadow_enabled,"car retains its geometry casters "+id)
		view.free(); await process_frame
	print("CHALLENGER_SHADOW_SWITCH: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
